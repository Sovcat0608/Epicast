"""Measure the existing clips and build fresh Wan poses from isolated master paint."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
ROOT = HERE.parents[2]
OUTPUT = ROOT / "artifacts/restoration-leaf-wan-refinement"
sys.path[:0] = [str(ROOT / "animation-rnd/.deps"), str(PREVIEW),
                str(PREVIEW / "leaf-channel-study"), str(PREVIEW / "leaf-impact-study")]

import cv2
from bake import MASTER, LAYERS
from bake_impact import FANS, FLASH
from bake_glow import emission, leaf_sources
from bake_inner import config, inverse_bend, remap

COUNT = 33
MATTE = (46, 66, 91)
STATES = ("channel", "impact")
KEYS = {"channel": (0, 8, 16, 24, 32), "impact": (0, 4, 8, 16, 24, 32)}
SIZE = (384, 384)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def review_source(job, review):
    revision = review.get("revision")
    root = OUTPUT
    if revision:
        root /= revision
        rows = json.loads((root/"manifest.json").read_text(encoding="utf-8"))
        refined = next(row for row in rows if (row["name"],row["state"]) == (job["name"],job["state"]))
        for key in ("source_sha256","index","registered","cycle","outputFrames"):
            if refined[key] != job[key]:
                raise ValueError(f"A revised clip changed the {key} contract: {job['name']}/{job['state']}")
        job = refined
    return job, root/job["name"]/job["state"]


def gray(image):
    return cv2.cvtColor(np.asarray(plate(image)), cv2.COLOR_RGB2GRAY)


def plate(image):
    matte = Image.new("RGBA", image.size, (*MATTE, 255))
    matte.alpha_composite(image)
    return matte.convert("RGB")


def channel_baseline(cels, slot, pivot, normal, spine, anchor):
    first = gray(cels[0])
    alpha = np.asarray(cels[0].getchannel("A"))
    y, x = np.mgrid[:alpha.shape[0], :alpha.shape[1]]
    along = (x + slot[0] - pivot[0]) * spine[0] + (y + slot[1] - pivot[1]) * spine[1]
    far = (alpha > 220) & (along > anchor)
    assert np.count_nonzero(far) > 100
    samples = [cv2.calcOpticalFlowFarneback(first, gray(cel), None, .5, 3, 17, 4, 5, 1.15, 0)[far] @ normal
               for cel in cels]
    spread = np.ptp(samples, axis=0)
    extremes = sorted(samples, key=lambda value: np.median(value))
    signed = float(np.median(extremes[-1]) + np.median(extremes[0]))
    return float(np.percentile(spread, 90)), -1 if signed < 0 else 1


def rgb_light(paint, index, pulse):
    alpha = paint.getchannel("A")
    visible = np.ones((paint.height, paint.width), dtype=np.float32)
    glow = emission(paint, visible, 0, index, pulse=pulse)
    lit = Image.composite(glow.convert("RGB"), paint.convert("RGB"), glow.getchannel("A"))
    lit.putalpha(alpha)
    return lit


def paint_pose(source, mx, my, width):
    # Fresh geometric pose guides use the approved isolated painting.
    y, x = np.mgrid[:source.height, :source.width]
    return remap(source, (x + (mx - x) * width).astype("float32"),
                 (y + (my - y) * width).astype("float32"))


def build():
    cv2.setNumThreads(2)
    OUTPUT.mkdir(exist_ok=True, parents=True)
    all_cels = leaf_sources()
    tracks = config("crown/idle.js")["tracks"]
    manifest = []
    for index,(direction,anchor,old_impact) in FANS.items():
        row = LAYERS[index]
        name = ("left-autumn","right-crown","left-shoulder","right-autumn",
                "left-inner","right-inner")[index-8]
        track = tracks[index-8]
        pivot = tuple(a+b for a,b in zip(track["slot"], track["pivot"]))
        spine = np.array(direction)/np.linalg.norm(direction)
        normal = np.array([-spine[1],spine[0]])
        old_channel, channel_side = channel_baseline(all_cels[index][1], all_cels[index][0],
                                                      pivot, normal, spine, anchor)
        original = MASTER/"registered"/f"{index:02}-paint.png"
        original_art = Image.open(original).convert("RGBA")
        clip = Image.new("RGBA", (original_art.width+128,original_art.height+128))
        clip.alpha_composite(original_art, (64,64))
        origin = row["x"]-64,row["y"]-64
        stem = tuple(a-b for a,b in zip(pivot,origin))
        y,x = np.mgrid[:clip.height,:clip.width].astype(np.float64)
        alpha = np.asarray(clip.getchannel("A"))
        along = (x-stem[0])*spine[0] + (y-stem[1])*spine[1]
        across = (x-stem[0])*normal[0] + (y-stem[1])*normal[1]
        distal = (alpha>220)&(along>anchor)
        span = along[alpha>220].max()-anchor
        metric = np.percentile(((along[distal]-anchor)/span)**2,90)
        offsets = np.clip(across/max(1, np.max(np.abs(across[distal]))),-.95,.95)
        width = min((SIZE[0]-16)/clip.width,(SIZE[1]-16)/clip.height)
        dims = tuple(round(value*width) for value in clip.size)
        position = tuple((value-size)//2 for value,size in zip(SIZE,dims))

        def to_model(image):
            canvas = Image.new("RGBA", SIZE)
            canvas.alpha_composite(image.resize(dims, Image.Resampling.LANCZOS), position)
            return canvas

        for state in STATES:
            location = OUTPUT/name/state
            location.mkdir(exist_ok=True,parents=True)
            time = np.linspace(0,1,COUNT)
            if state=="channel":
                # Drive a full midrib bow with a short cross-fan delay.
                tip = channel_side * 1.5 * old_channel / float(metric)
                # Normalize the global peak even with the side-to-side stagger.
                def pose(t):
                    delay = offsets*.075
                    return np.sin(np.pi*np.clip((t-delay*np.sin(np.pi*t)),0,1))**2
                pulses = 1.2*(.83+.17*np.sin(2*np.pi*(time-.073*(index-8))))
            else:
                tip = old_impact * 2
                def pose(t):
                    return float(np.interp(t,[0,.075,.125,.25,.5,.75,1],
                                           [0,.84,1,.90,.38,.08,0]))
                pulses = 1.3*np.interp(time,[0,.075,.125,.25,.42,.65,1],
                                      [0,1.08,max(FLASH),.68,.16,0,0])
            native, rgb = [], []
            for frame,(t,pulse) in enumerate(zip(time,pulses)):
                mx,my = inverse_bend(x,y,2*tip/span**2,stem,spine,anchor)
                bent = paint_pose(clip,mx,my,pose(t))
                lit = rgb_light(bent,index,pulse) if pulse else bent
                native.append(np.asarray(lit))
                model = to_model(lit)
                rgb.append(np.asarray(plate(model)))
                if frame in KEYS[state]:
                    model.save(location/f"pose-{frame:02}.png")
                    plate(model).save(location/f"wan-reference-{frame:02}.png")
            np.savez_compressed(location/"guide.npz", native=np.stack(native), rgb=np.stack(rgb))
            manifest.append(dict(name=name,title=row["name"],state=state,index=index,
                                 source=original.relative_to(ROOT).as_posix(),
                                 source_sha256=digest(original),registered=list(origin)+list(clip.size),
                                 modelRect=list(position)+list(dims),canvas=SIZE,stem=stem,direction=spine.tolist(),
                                 rootLength=anchor,tipTargetPx=tip,baselineChannelP90Px=old_channel,
                                 baselineImpactTipPx=old_impact,cycle=1/3 if state=="channel" else 1,
                                 outputFrames=16 if state=="channel" else 12,keys=KEYS[state]))
            print(f"{name:16} {state:7} guide {tip:+.2f}px at the tip",flush=True)
    (OUTPUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")


if __name__ == "__main__":
    build()
