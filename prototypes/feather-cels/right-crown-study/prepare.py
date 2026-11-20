"""Transfer Wan's green crown bend to the registered original painted leaves."""
from pathlib import Path
import json
import math
import sys

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent), str(HERE.parents[2]/"animation-rnd/.deps")]
import cv2
import numpy as np
from PIL import Image
from bake import LAYERS, MASTER
from crown import registered, shade

LEAF = 9
SLOT = (620, 0, 415, 399)
W, H = SLOT[2:]
FRAMES, COLUMNS, FRAME_MS = 16, 4, 125
VIDEO_CROP = (84, 78, 472, 451)


def smoothstep(start, end, value):
    fraction = np.clip((value-start)/(end-start), 0, 1)
    return fraction*fraction*(3-2*fraction)


def optical_motion():
    video = HERE/"wan-bend.mp4"
    capture = cv2.VideoCapture(str(video))
    try:
        frames = []
        while (sample := capture.read())[0]:
            frames.append(cv2.cvtColor(sample[1], cv2.COLOR_BGR2GRAY))
    finally:
        capture.release()
    if len(frames) < 16:
        raise ValueError("The Wan motion reference is incomplete")

    flow = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    rest = np.asarray(Image.open(HERE/"input.png").convert("RGB"), dtype=np.int16)
    leaf_pixels = rest[:,:,0]-rest[:,:,2] > 35
    candidates = []
    for frame in range(5, len(frames)-2):
        motion = flow.calc(frames[0], frames[frame], None)
        anchor = np.median(motion[485:527,137:169], axis=(0,1))
        motion = cv2.GaussianBlur(motion-anchor, (0,0), 8)
        bulk = np.percentile(np.linalg.norm(motion[leaf_pixels],axis=1), 70)
        candidates.append((float(bulk), frame, motion))
    _, frame, motion = max(candidates, key=lambda candidate: candidate[0])
    x,y,width,height = VIDEO_CROP
    row = LAYERS[LEAF]
    region = motion[y:y+height,x:x+width]
    native = cv2.resize(region, (row["w"],row["h"]), interpolation=cv2.INTER_LINEAR)
    native *= (row["w"]/width, row["h"]/height)
    return frame, native


def coordinate_field(native):
    y,x = np.mgrid[:H,:W].astype("float32")
    origin = LAYERS[LEAF]
    local_x,local_y = origin["x"]-SLOT[0],origin["y"]-SLOT[1]
    # Extend across a small gutter so the anti-aliased edges can move.
    vectors = cv2.remap(native, x-local_x, y-local_y, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    radius = np.hypot(x-(719-SLOT[0]), y-343)
    weight = smoothstep(18, 110, radius)
    weight *= (1-smoothstep(0,24,np.maximum(np.maximum(local_x-x,x-local_x-origin["w"]),
                                            np.maximum(local_y-y,y-local_y-origin["h"]))))
    vectors *= weight[:,:,None]
    # Preserve full-blade variation, with a fixed stem and small excursion.
    amount = np.linalg.norm(vectors,axis=2)
    opaque = np.asarray(registered(LEAF,"paint",SLOT).getchannel("A")) > 128
    scale = min(2.5, 3.7/max(float(np.percentile(amount[opaque],90)),.1))
    vectors *= scale
    magnitude = np.maximum(np.linalg.norm(vectors,axis=2),.1)
    vectors *= np.minimum(1,9/magnitude)[:,:,None]
    return x,y,vectors,scale


def remap(img, mx, my):
    mode = "RGBa" if img.mode == "RGBA" else img.mode
    result = cv2.remap(np.asarray(img.convert(mode)),mx,my,cv2.INTER_LINEAR)
    return Image.frombytes(mode,img.size,result.tobytes()).convert(img.mode)


def composite(paints, fields):
    w,h = paints[0].size
    result = Image.new("RGBA",(w,h))
    for index,row in enumerate(LAYERS):
        if paints[index].getbbox() is None:
            continue
        light = np.ones((h,w),dtype=np.float32)
        for caster in row["casters"]:
            strength = row["contactStrength"].get(LAYERS[caster]["name"],1)
            light *= 1-strength*np.asarray(fields[caster],dtype=np.float32)/255
        painted = shade(paints[index], Image.fromarray(np.rint(light*255).astype("uint8")).convert("RGB"))
        result.alpha_composite(painted)
    return np.asarray(result,dtype=np.int16)


def build():
    keyframe, native = optical_motion()
    x,y,motion,gain = coordinate_field(native)
    paint = [registered(i,"paint",SLOT) for i in range(len(LAYERS))]
    fields = [registered(i,"field",SLOT).getchannel("A") for i in range(len(LAYERS))]
    leaf, field = paint[LEAF],fields[LEAF]
    base = composite(paint,fields)
    reference = Image.open(MASTER/"Figma crest.png").convert("RGBA").crop(
        (SLOT[0],SLOT[1],SLOT[0]+W,SLOT[1]+H))
    reference_pixels = np.asarray(reference,dtype=np.int16)
    scenes, sprites = [], []
    cover = np.zeros((H,W),dtype=bool)
    delay = 1.3*smoothstep(166,321,y)*smoothstep(110,337,x)
    for frame in range(FRAMES):
        breath = .5-.5*np.cos((frame-delay)*math.tau/FRAMES)
        mx = (x-breath*motion[:,:,0]).astype("float32")
        my = (y-breath*motion[:,:,1]).astype("float32")
        paint[LEAF] = remap(leaf,mx,my)
        fields[LEAF] = remap(field,mx,my)
        result = np.clip(reference_pixels+composite(paint,fields)-base,0,255).astype("uint8")
        changed = np.any(result != reference_pixels,axis=2)
        cover |= changed
        scenes.append(result)
        sprites.append(paint[LEAF])

    # The adjacent orange shoulder and moving feathers already have their own
    # tiles. Replace only these changed pixels over the existing preview.
    shoulder = Image.open(HERE.parent/"shoulder-study/right-quiet/leaf.webp")
    shoulder_slot = (831-SLOT[0], 257-SLOT[1])
    for frame in range(shoulder.n_frames):
        shoulder.seek(frame)
        alpha = Image.new("L",(W,H))
        alpha.paste(shoulder.convert("RGBA").getchannel("A"),shoulder_slot)
        cover &= np.asarray(alpha) <= 8
    cover_image = Image.new("RGBA",(W,H))
    cover_image.putalpha(Image.fromarray(cover.astype("uint8")*255))
    cover_image.save(HERE/"coverage.webp",lossless=True)
    atlas = Image.new("RGBA",(W*COLUMNS,H*(FRAMES//COLUMNS)))
    sprite_sheet = Image.new("RGBA",atlas.size)
    for frame,(scene,sprite) in enumerate(zip(scenes,sprites)):
        origin = (frame%COLUMNS*W, frame//COLUMNS*H)
        scene[~cover] = 0
        atlas.paste(Image.fromarray(scene),origin)
        sprite_sheet.paste(sprite,origin)
    atlas.save(HERE/"scene.webp",lossless=True)
    sprite_sheet.save(HERE/"leaves.webp",lossless=True)
    sprites[0].save(HERE/"bend.webp",save_all=True,append_images=sprites[1:],duration=FRAME_MS,loop=0,lossless=True)
    track = dict(slot=SLOT,frames=FRAMES,columns=COLUMNS,frameMs=FRAME_MS,sheet="right-crown-study/scene.webp",
                 coverage="right-crown-study/coverage.webp")
    (HERE/"track.js").write_text("const rightCrownIdle = "+json.dumps(track)+";\n")
    report = dict(source="wan-bend.mp4", keyframe=keyframe, flowGain=gain,
                  maxDisplacementPx=float(np.linalg.norm(motion,axis=2)[np.asarray(leaf.getchannel("A"))>128].max()),
                  changedPixels=int(cover.sum()))
    (HERE/"motion.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report))


if __name__ == "__main__":
    build()

