"""Registered pose and light guides for the Treant and Rejuvenation leaf."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
ROOT = HERE.parents[2]
OUT = ROOT / "artifacts/restoration-motion-refinement"
SOURCE = ROOT / "concepts/restoration-frame146/registered"
sys.path.insert(0, str(ROOT / "animation-rnd/.deps"))
import cv2

MATTE = (46, 66, 91)
SIZE = 384
COUNT = 33
FACE = PREVIEW / "treant-study/face.png"
LEAF = SOURCE / "15-paint.png"


def ease(value):
    t = np.clip(value, 0, 1)
    return t*t*(3-2*t)


def remap(image, x, y):
    mapped = cv2.remap(np.asarray(image.convert("RGBa")), x.astype("float32"), y.astype("float32"),
                       cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT)
    return Image.frombytes("RGBa", image.size, mapped.tobytes()).convert("RGBA")


def soften_layer(rgb, alpha, color, power):
    colored = np.asarray(color, dtype=np.float32)/255
    amount = power[:, :, None]
    # Screen lifts the existing broad planes while keeping their paint variation.
    RGB = 1-(1-rgb)*(1-colored*amount)
    return RGB*alpha + rgb*(1-alpha)


def leaf_motifs(image, theme, palette):
    raw = np.asarray(image, dtype=np.float32)/255
    alpha = raw[:, :, 3]
    yy, xx = np.mgrid[:image.height,:image.width]
    blade = (1-ease((yy-190)/22))*alpha
    inside = cv2.distanceTransform((alpha>.45).astype(np.uint8), cv2.DIST_L2, 5)
    boundary = np.exp(-.5*((inside-1.2)/1.45)**2)*blade
    refraction = np.exp(-inside/5)*blade
    paths = [[(119,196),(118,157),(118,106),(118,49),(118,5)],
             [(118,166),(105,147),(83,128),(64,114),(40,96),(8,75)],
             [(118,196),(107,181),(89,171),(68,164),(39,162),(9,162)],
             [(119,165),(138,140),(158,124),(177,109),(196,94),(219,77)],
             [(119,195),(131,180),(148,172),(168,165),(192,162),(219,162)],
             [(117,113),(108,100),(96,91),(81,72)],
             [(118,103),(133,83),(149,62),(158,47)]]
    ink = Image.new("L", image.size)
    drawing = ImageDraw.Draw(ink)
    for i,path in enumerate(paths):
        drawing.line(path, fill=245 if i == 0 else 218, width=3 if i == 0 else 2, joint="curve")
    veins = np.asarray(ink.filter(ImageFilter.GaussianBlur(.65)), dtype=np.float32)/255 * blade
    spread = cv2.GaussianBlur(veins, (0,0), 3)
    broad, rim, emissive = palette
    rgb = soften_layer(raw[:,:,:3], blade[:,:,None], broad,
                       .30 + .14 * np.exp(-((xx-116)/95)**2) if theme == "impact"
                       else .18 + .08 * np.exp(-((xx-116)/76)**2))
    # Light travels through the carved-in veins, with a thin pale core and coloured spread.
    rgb = soften_layer(rgb, blade[:,:,None], emissive, np.clip(spread*2.0,0,.7))
    intensity = np.clip(veins*1.33,0,1)[:,:,None]
    light = (np.asarray(emissive)/255)*.58 + np.array([.97,1,.94])*.42
    rgb = rgb*(1-intensity) + light*intensity
    rgb = soften_layer(rgb, blade[:,:,None], rim, refraction*.47)
    fringe = np.clip(boundary*.96,0,1)[:,:,None]
    edge_light = np.asarray(rim)/255*.78 + np.array([1,.91,1])*.22
    rgb = rgb*(1-fringe)+edge_light*fringe
    # Soft outside light is added in the compositor, with a receiver mask.
    return Image.fromarray(np.uint8(np.rint(255*np.dstack((rgb, alpha)))))


def face_pose(image, amount, inhale):
    # Mouth corners are roughly x=82–204. At exhale raise the lower lip
    # about 35 px around the midline and retain a thin dark opening.
    y,x = np.mgrid[:image.height,:image.width]
    width = np.exp(-((x-141)/61)**4)
    influence = ease((y-165)/47)*(1-.73*ease((y-219)/110))
    pitch = ease((y-32)/57)*(1-ease((y-123)/71))
    target = (y + (-34*amount*influence + inhale*(4.22*influence-4.36*pitch))*width).astype("float32")
    source_y = np.arange(image.height)
    inverse = np.column_stack([np.interp(source_y, target[:,i], source_y) for i in range(image.width)])
    return remap(image,x,inverse)


def leaf_pose(image, turn, bend, grow):
    # Keep the base of the S-stalk fixed while the broad blade flexes.
    cx, cy = 116, 203
    y,x = np.mgrid[:image.height,:image.width]
    # Caller supplies padded art coordinates so the enlarged blades fit.
    cx += 64
    cy += 64
    fan = 1-ease((y-cy+5)/73)
    sx,sy = (x-cx)/(1+grow*fan), (y-cy)/(1+grow*fan)
    theta = turn*fan
    original_x = cx + sx*np.cos(theta) + sy*np.sin(theta) - bend*(np.maximum(0, -sy)/204)**2
    original_y = cy - sx*np.sin(theta) + sy*np.cos(theta)
    return remap(image, original_x, original_y)


def painted_palette(image, state):
    rgb = np.asarray(image.convert("RGBA"), dtype=np.int16)
    r,g,b,a = rgb.transpose(2,0,1)
    purple = (r > 100) & (b > 140) & (b-g > 35) & (a>150)
    green = (g > 150) & (g-r > 10) & (g-b > 15) & (a>150)
    def sample(region, target, fraction=.32):
        ref = np.asarray(target, dtype=float)
        if np.count_nonzero(region) > 30:
            ref = ref*(1-fraction) + np.median(rgb[:,:,:3][region],axis=0)*fraction
        return tuple(np.uint8(ref))
    return (
        sample(green,(115,255,39) if state=="channel" else (130,255,41)),
        sample(purple,(242,48,255)),
        sample(green,(169,255,83)) if state=="channel" else sample(purple,(221,147,255),.20),
    )


def save_job(name, source, frames, slot, keys, duration, count):
    here = OUT / name
    here.mkdir(parents=True, exist_ok=True)
    w,h = frames[0].size
    factor=(SIZE-16)/max(w,h)
    width,height=round(w*factor),round(h*factor)
    x,y=(SIZE-width)//2,(SIZE-height)//2
    native,rgb,alpha = [],[],[]
    for i,cel in enumerate(frames):
        layer=Image.new("RGBA",(SIZE,SIZE))
        layer.paste(cel.resize((width,height),Image.Resampling.LANCZOS),(x,y))
        plate=Image.new("RGBA",(SIZE,SIZE),(*MATTE,255))
        plate.alpha_composite(layer)
        rgb.append(np.asarray(plate.convert("RGB")))
        alpha.append(np.asarray(layer.getchannel("A")))
        native.append(np.asarray(cel))
        if i in keys:
            cel.save(here/f"pose-{i:02d}.png")
            plate.convert("RGB").save(here/f"wan-anchor-{i:02d}.png")
    np.savez_compressed(here/"guide.npz",native=np.stack(native),rgb=np.stack(rgb),alpha=np.stack(alpha))
    job=dict(name=name,source=source.relative_to(ROOT).as_posix(),sourceHash=hashlib.sha256(source.read_bytes()).hexdigest(),
             slot=slot, rect=[x,y,width,height], keys=keys, duration=duration, exportedFrames=count)
    (here/"manifest.json").write_text(json.dumps(job,indent=2)+"\n",encoding="utf-8")
    print(f"Prepared {name} with keyframes {keys}",flush=True)


def treant():
    src=Image.open(FACE).convert("RGBA")
    poses=[]
    for frame in range(COUNT):
        t=frame/(COUNT-1)
        inhale=np.sin(np.pi*min(t/.42,1))**2
        exhale=ease((t-.235)/.265)*(1-ease((t-.55)/.45))
        pose = face_pose(src,exhale,inhale)
        poses.append(pose)
    save_job("treant-idle",FACE,poses,[429,777,*src.size],[0,8,16,24,32],4000,32)


def channel_bend(t):
    return .065*np.sin(2*np.pi*t), 10.5*np.sin(2*np.pi*t-.36)


def leaf(state):
    src=Image.open(LEAF).convert("RGBA")
    glow=None
    if state != "idle":
        painted = OUT/f"{state}-paint.png"
        if not painted.is_file():
            raise FileNotFoundError(f"Missing painted lighting reference {painted}")
        glow=leaf_motifs(src,state,painted_palette(Image.open(painted),state))
        glow.save(OUT/f"{state}-registered-midpoint-light.png")
    poses=[]
    for frame in range(COUNT):
        t=frame/(COUNT-1)
        wave=np.sin(2*np.pi*t)
        if state=="idle":
            turn,bend,grow,light = .027*wave,2.8*np.sin(2*np.pi*t-.27),0,0
        elif state=="channel":
            turn,bend = channel_bend(t)
            grow,light = 0,.90+.10*np.sin(2*np.pi*t)
        else:
            progress=float(np.interp(t,[0,.125,.25,.48,.75,1],[0,1,.92,.43,.11,0]))
            turn,bend,grow,light = .035*progress,10*progress,.30*progress,progress
        cel=Image.blend(src,glow,light) if light else src
        padded=Image.new("RGBA",(src.width+128,src.height+128))
        padded.paste(cel,(64,64))
        poses.append(leaf_pose(padded,turn,bend,grow))
    poses[-1]=poses[0].copy()
    settings={"idle":(4000,32,[0,8,16,24,32]),"channel":(4000/3,32,[0,8,16,24,32]),
              "impact":(1000,12,[0,4,8,16,24,32])}
    duration,count,keys=settings[state]
    save_job(f"rejuvenation-{state}", LEAF,poses,[453-64,410-64,*poses[0].size],keys,duration,count)


if __name__=="__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    for item in sys.argv[1:]:
        if item=="treant":
            treant()
        else:
            leaf(item)
