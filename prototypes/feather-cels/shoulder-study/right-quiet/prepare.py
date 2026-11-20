"""Register the right fan and play a shallow, staggered sweep of its painted cels."""
from pathlib import Path
import json
import math
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent))
from crown import stem_anchor

def aligned(sheet, columns, count, rest):
    cw, ch = sheet.width // columns, sheet.height // columns
    scale = None
    pivot = stem_anchor(rest, "top-left")
    rest_mask = np.asarray(rest.getchannel("A")) > 128
    for k in range(count):
        x, y = k % columns * cw, k // columns * ch
        cel = sheet.crop((x, y, x+cw, y+ch))
        if scale is None:
            a, b, c, d = cel.getchannel("A").point(lambda v: 255 if v > 96 else 0).getbbox()
            l, t, r, u = rest.getbbox()
            scale = min((r-l)/(c-a), (u-t)/(d-b))
        cel = cel.resize((round(cw*scale), round(ch*scale)), Image.Resampling.LANCZOS)
        sx, sy = stem_anchor(cel, "top-left")
        frame = Image.new("RGBA", rest.size)
        frame.paste(cel, (pivot[0]-sx, pivot[1]-sy))
        alpha = frame.getchannel("A")
        def error(angle):
            rotated = alpha.rotate(float(angle), Image.Resampling.BILINEAR, center=pivot)
            return np.count_nonzero((np.asarray(rotated) > 128) != rest_mask)
        coarse = min(range(-16, 17, 2), key=error)
        angle = min(np.arange(coarse-1, coarse+1.01, .25), key=error)
        yield np.array(frame.convert("RGBa").rotate(float(angle), Image.Resampling.BICUBIC, center=pivot), dtype=np.float32)

def smooth(v):
    v = np.clip(v, 0, 1)
    return v*v*(3-2*v)

def build():
    recipe = json.loads((HERE / "exposures.json").read_text(encoding="utf-8-sig"))
    rest = Image.open(HERE/"rest.png").convert("RGBA")
    sheet = Image.open(HERE/recipe["source"]).convert("RGBA")
    poses = list(aligned(sheet, recipe["sourceColumns"], recipe["sweep"][1]+1, rest))
    poses = poses[recipe["sweep"][0]:]
    width, height = rest.size
    y, x = np.mgrid[:height,:width]
    px, py = stem_anchor(rest, "top-left")
    distance = np.hypot(x-px, y-py)
    # These seams follow the upper and lower edges of the long ochre blade.
    upper = np.interp(x,[64,100,145,183,215,240],[55,77,92,100,108,117])
    lower = np.interp(x,[64,98,138,170,201,230],[55,92,127,151,174,214])
    delay = (.9*smooth((y-upper+5)/10) + 1.15*smooth((y-lower+6)/12))*smooth((distance-16)/48)
    arc = np.r_[0,np.cumsum([np.abs(b-a).mean() for a,b in zip(poses,poses[1:])])]
    assert arc[-1] > 0
    atlas = Image.new("RGBA", (4*width,4*height))
    for beat in range(16):
        t = (1-np.cos((beat-delay)*math.tau/16))*.5
        exposure = np.interp(t*arc[-1],arc,np.arange(len(poses)))
        mixed = sum(p*np.maximum(1-np.abs(exposure-i),0)[:,:,None] for i,p in enumerate(poses))
        # The concealed stem keeps its original paint through the entire cycle.
        weight = smooth((distance-10)/17)[:,:,None]
        mixed = np.array(rest.convert("RGBa"))*(1-weight) + mixed*weight
        cel = Image.frombytes("RGBa", rest.size, np.rint(mixed).astype("uint8").tobytes()).convert("RGBA")
        atlas.paste(cel, ((beat%4)*width, (beat//4)*height))
    atlas.save(HERE/"quiet.webp", lossless=True)

if __name__ == "__main__":
    build()
