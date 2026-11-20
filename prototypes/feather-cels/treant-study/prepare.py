"""Register the breathing face at the brow and bake model-guided motion over the original paint."""
from pathlib import Path
import json
import math
import sys

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent), str(HERE.parents[2] / "animation-rnd/.deps")]
import cv2
import numpy as np
from PIL import Image, ImageChops, ImageFilter
from bake import LAYERS
from cheek_placement import HIDDEN, composite, crest_path, premult, rgba, registered_stack

SLOT = (412, 769, 320, 390)
WIDTH, HEIGHT = SLOT[2:]
FACE = len(LAYERS) - 1
FPS, PERIOD, COLUMNS = 8, 4, 8

def smoothstep(a, b, t):
    x = np.clip((t-a)/(b-a), 0, 1)
    return x*x*(3-2*x)

def sampler():
    y, x = np.mgrid[:HEIGHT,:WIDTH].astype("float32")
    center = 574-SLOT[0]
    # The upper brow and surrounding boughs are the attachment. The lift
    # is strongest near the eye/nose ridge, fading into the upper lip.
    inside = 1-smoothstep(81, 141, abs(x-center))
    fixed_brow = smoothstep(23, 100, y)
    pitch = fixed_brow * (1-smoothstep(142, 208, y)) * inside
    # Separate travel of the lower rim, with a slight spread at the corners.
    lower_jaw = smoothstep(175, 229, y) * (1-smoothstep(337, 381, y)) * inside
    corners = np.clip((x-center)/64, -1, 1) * np.exp(-.5*((y-203)/29)**2) * inside
    return x,y,pitch,lower_jaw,corners

def warp(art, mx, my):
    mode = "RGBa" if art.mode == "RGBA" else art.mode
    channels = cv2.remap(np.asarray(art.convert(mode)), mx, my, cv2.INTER_LINEAR)
    if mode == "RGBa":
        return Image.frombytes(mode, art.size, channels.tobytes()).convert("RGBA")
    return Image.fromarray(channels)

def landmarks(video, frame):
    capture = cv2.VideoCapture(str(video))
    try:
        capture.set(cv2.CAP_PROP_POS_FRAMES, frame)
        ok, image = capture.read()
    finally:
        capture.release()
    if not ok:
        raise ValueError(f"Cannot read motion reference frame {frame}")
    rgb = image[:,:,::-1].astype("int16")
    eyes = []
    for left, right in [(171,261),(360,441)]:
        eye = rgb[194:285,left:right]
        rows, _ = np.where((eye[:,:,1]-eye[:,:,0]>30) & (eye[:,:,1]>90))
        eyes.append(float(rows.mean()+194))
    mouth, _ = np.where(rgb[329:510,190:420].max(axis=2)<58)
    return float(np.mean(eyes)), float(np.quantile(mouth,.98)+329)

def breath_motion():
    source = HERE/"wan-breath.mp4"
    rest, inhale = landmarks(source, 0), landmarks(source, 8)
    # Attenuate the model's measured pose in the crest's native pixel scale.
    strength = .55 * 332/586
    return {
        "video": source.name, "sourceFrames": [0,8],
        "eyeLiftInVideoPx": rest[0]-inhale[0], "jawDropInVideoPx": inhale[1]-rest[1],
        "faceLiftPx": np.clip((rest[0]-inhale[0])*strength, 0, 6),
        "jawDropPx": np.clip((inhale[1]-rest[1])*strength, 0, 6),
        "cornerSpreadPx": 1.25, "frameCount": FPS*PERIOD,
    }

def build(hide_cheeks=False):
    settings = breath_motion()
    (HERE/"motion.json").write_text(json.dumps(settings,indent=2)+"\n")
    x,y,pitch,jaw,corners = sampler()
    shift_x = settings["cornerSpreadPx"]*corners
    shift_y = settings["jawDropPx"]*jaw - settings["faceLiftPx"]*pitch
    paint,fields = registered_stack(SLOT,hide_cheeks=hide_cheeks)
    fixed_face, fixed_field = paint[FACE],fields[FACE]
    sx,sy = SLOT[:2]
    rect=(sx,sy,sx+WIDTH,sy+HEIGHT)
    reference=Image.open(crest_path(hide_cheeks)).convert("RGBA").crop(rect)
    changed=Image.fromarray(np.rint(np.clip(np.hypot(shift_x,shift_y),0,1)*255).astype("uint8"))
    matte=changed.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(3))
    count=FPS*PERIOD
    atlas=Image.new("RGBA",(COLUMNS*WIDTH,(count//COLUMNS)*HEIGHT))
    sprite_atlas=Image.new("RGBA",atlas.size)
    registered_face = Image.new("RGBA",(WIDTH,HEIGHT))
    registered_face.paste(Image.open(HERE/"face.png"),(429-sx,777-sy))
    base = premult(composite(paint,fields,SLOT))
    original = premult(reference)
    samples=[]
    for cel in range(count):
        breath=.5-.5*math.cos(math.tau*cel/count)
        mx,my=(x-breath*shift_x).astype("float32"),(y-breath*shift_y).astype("float32")
        paint[FACE]=warp(fixed_face,mx,my)
        fields[FACE]=warp(fixed_field,mx,my)
        moving = premult(composite(paint,fields,SLOT))
        frame = rgba(original + moving - base)
        frame = Image.composite(frame, reference, matte)
        at=(cel%COLUMNS*WIDTH,cel//COLUMNS*HEIGHT)
        atlas.paste(frame,at)
        sprite_atlas.paste(warp(registered_face,mx,my),at)
        samples.append(frame)
    if hide_cheeks:
        atlas.save(HIDDEN/"treant-idle.webp",lossless=True)
        return
    atlas.save(HERE/"scene.webp",lossless=True)
    sprite_atlas.save(HERE/"face-cels.webp",lossless=True)
    samples[0].save(HERE/"breath.webp",save_all=True,append_images=samples[1:],duration=125,loop=0,lossless=True)
    track=dict(slot=SLOT,frames=count,columns=COLUMNS,frameMs=1000//FPS,sheet="treant-study/scene.webp")
    (HERE/"track.js").write_text("const treantIdle = "+json.dumps(track)+";\n")

if __name__ == "__main__":
    build("--hide-cheeks" in sys.argv)
