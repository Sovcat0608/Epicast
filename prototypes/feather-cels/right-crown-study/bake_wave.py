"""Bake a traveling bend from distinct Wan poses onto the approved crest art."""
import json
import numpy as np
from PIL import Image, ImageFilter

from prepare import COLUMNS, FRAME_MS, FRAMES, H, LEAF, LAYERS, MASTER, SLOT, W
from prepare import composite, cv2, registered, smoothstep
from wave_motion import OUTPUT, extract

# This sequence includes the wind-up, the first bend, the opposing curl
# during release, and the settle observed in the reference video.
CELS = (0, 3, 6, 9, 12, 14, 16)
SOURCE_FRAMES = (16, 20, 24, 30, 36, 44, 16)
GAIN = 1.85


def sample_motion(fields, phase):
    result = np.zeros((*phase.shape,2),dtype=np.float32)
    for i,(start,stop) in enumerate(zip(CELS,CELS[1:])):
        inside = (phase>=start)&(phase<stop)
        t = smoothstep(start,stop,phase[inside])[:,None]
        start_pose = fields[SOURCE_FRAMES[i]//2,inside]
        end_pose = fields[SOURCE_FRAMES[i+1]//2,inside]
        result[inside] = start_pose*(1-t) + end_pose*t
    # Use the pre-gust keyframe as the registered rest state.
    return result-fields[SOURCE_FRAMES[0]//2]


def premultiply(image):
    data = np.asarray(image,dtype=np.float32)/255
    data[:,:,0:3] *= data[:,:,3:4]
    return data


def rgba(pixels):
    alpha = np.clip(pixels[:,:,3:4],0,1)
    color = np.clip(pixels[:,:,:3],0,alpha)
    color = np.divide(color,alpha,out=np.zeros_like(color),where=alpha>0)
    return Image.fromarray(np.rint(255*np.concatenate((color,alpha),axis=2)).astype("uint8"))


def remap(image, mx, my):
    if image.mode == "L":
        return Image.fromarray(cv2.remap(np.asarray(image),mx,my,cv2.INTER_LINEAR))
    return rgba(cv2.remap(premultiply(image),mx,my,cv2.INTER_LINEAR))


def pose_maps():
    x,y,alpha,fields = extract()
    stem_x,stem_y = 719-SLOT[0],343
    span = np.hypot(x-stem_x,y-stem_y)
    fan_angle = np.arctan2(x-stem_x,np.maximum(stem_y-y,15))
    across_fan = smoothstep(.28,1.06,fan_angle)
    lag = 2.1*across_fan + 1.5*smoothstep(58,310,span)
    motions = []
    poses = []
    # Start at the slow part of the curl, and ease sampling noise on either
    # side of each exposure using its cyclic neighbors.
    for cel in range(FRAMES):
        frame = (cel+7)%FRAMES
        phase = (frame-lag)%FRAMES
        motion = GAIN * (
            .16*sample_motion(fields,(phase-1)%FRAMES)
            + .68*sample_motion(fields,phase)
            + .16*sample_motion(fields,(phase+1)%FRAMES)
        )
        size = np.linalg.norm(motion,axis=2)
        motion *= np.minimum(1,15/np.maximum(size,.001))[:,:,None]
        motions.append(motion)
        poses.append(((x-motion[:,:,0]).astype("float32"),(y-motion[:,:,1]).astype("float32")))
    return poses, motions, alpha


def bake_poses(poses, output):
    output.mkdir(exist_ok=True)
    paints = [registered(i,"paint",SLOT) for i in range(len(LAYERS))]
    shadows = [registered(i,"field",SLOT).getchannel("A") for i in range(len(LAYERS))]
    leaf,shadow = paints[LEAF],shadows[LEAF]
    base = premultiply(composite(paints,shadows))
    left,top=SLOT[:2]
    original = Image.open(MASTER/"Figma crest.png").convert("RGBA").crop((left,top,left+W,top+H))
    reference = premultiply(original)
    sprites, scenes = [], []
    changes=np.zeros((H,W),dtype=bool)
    for mx,my in poses:
        paints[LEAF],shadows[LEAF] = remap(leaf,mx,my),remap(shadow,mx,my)
        scene=rgba(reference+premultiply(composite(paints,shadows))-base)
        changes |= np.any(np.asarray(scene)!=np.asarray(original),axis=2)
        sprites.append(paints[LEAF])
        scenes.append(scene)

    # Protect every pose of the neighboring orange shoulder while composing
    # the green fan's own alpha edges and receiver shadows.
    mask = Image.fromarray(changes.astype("uint8")*255).filter(ImageFilter.MaxFilter(3))
    cover = np.array(mask,dtype=bool)
    shoulder = Image.open(output.parents[1]/"shoulder-study/right-quiet/leaf.webp")
    for index in range(shoulder.n_frames):
        shoulder.seek(index)
        alpha_mask = Image.new("L",(W,H))
        alpha_mask.paste(shoulder.convert("RGBA").getchannel("A"),(831-left,257-top))
        cover &= np.asarray(alpha_mask)<=8
    mask=Image.fromarray(cover.astype("uint8")*255)
    coverage=Image.new("RGBA",(W,H))
    coverage.putalpha(mask)
    coverage.save(output/"coverage.webp",lossless=True)
    sheet_size=(W*COLUMNS,H*(FRAMES//COLUMNS))
    atlas=Image.new("RGBA",sheet_size)
    sprite_atlas=Image.new("RGBA",sheet_size)
    for frame,(scene,sprite) in enumerate(zip(scenes,sprites)):
        offset=(frame%COLUMNS*W,frame//COLUMNS*H)
        atlas.paste(Image.composite(scene,Image.new("RGBA",(W,H)),mask),offset)
        sprite_atlas.paste(sprite,offset)
    atlas.save(output/"scene.webp",lossless=True)
    sprite_atlas.save(output/"leaves.webp",lossless=True)
    sprites[0].save(output/"bend.webp",save_all=True,append_images=sprites[1:],
                    duration=FRAME_MS,loop=0,lossless=True)
    paths=f"right-crown-study/{output.name}/"
    track=dict(slot=SLOT,frames=FRAMES,columns=COLUMNS,frameMs=FRAME_MS,
               sheet=paths+"scene.webp",coverage=paths+"coverage.webp")
    (output/"track.js").write_text("const rightCrownIdle = "+json.dumps(track)+";\n")


def build():
    poses,motions,alpha = pose_maps()
    bake_poses(poses, OUTPUT)
    visible=alpha>.9
    span_motion=np.max(np.stack(motions),axis=0)-np.min(np.stack(motions),axis=0)
    stats = dict(sourceFrames=SOURCE_FRAMES, targetCels=CELS, gain=GAIN,
                 crestPixelDisplacementP90=float(np.percentile(np.linalg.norm(span_motion[visible],axis=1),90)))
    (OUTPUT/"motion.json").write_text(json.dumps(stats,indent=2)+"\n")
    print(json.dumps(stats))


if __name__=="__main__":
    build()

