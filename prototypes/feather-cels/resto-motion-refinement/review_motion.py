"""Review Wan candidates and export registered RGBA motion for the crest compositor."""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from motion_guides import OUT, PREVIEW, SIZE, ease
sys.path.insert(0, str(PREVIEW/"leaf-wan-refinement"))
from register_preview import extract

JOBS=("treant-idle","rejuvenation-idle","rejuvenation-channel","rejuvenation-impact")
IMPACT_CELS = [3,4,7,10,13,16,19,22,25,28,30,32]


def darkest_mouth(rgb, alpha, rect):
    x,y,w,h=rect
    cx,cy=rgb.shape[:2]
    box=rgb[y+round(h*.505):y+round(h*.66),x+round(w*.318):x+round(w*.70)]
    matte=alpha[y+round(h*.505):y+round(h*.66),x+round(w*.318):x+round(w*.70)]
    assert box.shape[:2] == matte.shape and cx == cy
    return int(np.count_nonzero((box.max(axis=2)<84)&(matte>210)))


def measure(job, rendered, guide):
    original, support = guide["rgb"], guide["alpha"]
    interior = support>238
    delta = np.abs(rendered.astype(np.int16)-original.astype(np.int16)).mean(axis=3)
    exposure = np.array([np.mean(delta[i][interior[i]]) for i in range(len(delta))])
    closure = None
    merit = float(exposure.mean() + .15*np.max(exposure))
    if job["name"]=="treant-idle":
        open_mouth=darkest_mouth(rendered[0],support[0],job["rect"])
        closed=darkest_mouth(rendered[16],support[16],job["rect"])
        closure=1-closed/max(1,open_mouth)
        expected=1-darkest_mouth(original[16],support[16],job["rect"])/max(
            1,darkest_mouth(original[0],support[0],job["rect"]))
        merit += 30*abs(closure-expected)
    return dict(meanInteriorRGBError=round(float(exposure.mean()),3), worstFrameRGBError=round(
        float(np.max(exposure)),3), mouthDarkAreaReduction=closure, score=round(merit,3))


def capture(job, folder, guide, runs):
    phase=(0,4,8,16,24,32)
    step=158
    canvas=Image.new("RGB",(step*len(phase), (step+24)*(1+len(runs))),(26,30,34))
    label=ImageDraw.Draw(canvas)
    for index,(name,seq) in enumerate([("Registered guide",guide["rgb"]), *runs]):
        y=index*(step+24)
        label.text((9,y+4),f"{job['name']} · {name}",fill=(236,239,236))
        for col,frame in enumerate(phase):
            tile=Image.fromarray(seq[frame]).resize((step-4,step-4),Image.Resampling.LANCZOS)
            canvas.paste(tile,(col*step+2,y+23))
    canvas.save(folder/"review.jpg",quality=94)


def recover(job, frames, guide):
    x,y,w,h=job["rect"]
    native=guide["native"]
    alpha=guide["alpha"]
    nominal=guide["rgb"]
    samples=IMPACT_CELS if job["name"].endswith("impact") else list(range(32))
    bounds=np.zeros((SIZE,SIZE),dtype=bool)
    bounds[y:y+h,x:x+w]=True
    height,width=native.shape[1:3]
    yy,xx=np.mgrid[:height,:width]
    face=job["name"]=="treant-idle"
    editable=(ease((yy-154)/20)*np.exp(-((xx-141)/61)**6)) if face else (1-ease((yy-256)/36))
    result=[]
    for n in samples:
        reference=Image.fromarray(native[n])
        if n in (0,32):
            result.append(reference)
            continue
        color=extract(frames[n],nominal[n],alpha[n],bounds)
        paint=color.crop((x,y,x+w,y+h)).resize(reference.size,Image.Resampling.LANCZOS)
        opaque=np.asarray(paint.getchannel("A"),dtype=np.float32)/255
        interior=np.asarray(reference.getchannel("A").filter(ImageFilter.MinFilter(5)),dtype=np.float32)/255
        closeness=min(n,32-n)
        blend=editable*opaque*interior*ease(closeness/5)*(.88 if face else .58)
        merged=Image.composite(paint.convert("RGB"),reference.convert("RGB"),
                               Image.fromarray(np.uint8(np.rint(blend*255))))
        merged.putalpha(reference.getchannel("A"))
        result.append(merged)
    return result


def save(job, requested=None):
    folder=OUT/job["name"]
    with np.load(folder/"guide.npz") as archive:
        guide={key:archive[key] for key in archive.files}
    passes={}
    metrics={}
    for receipt in sorted(folder.glob("pass-*.json")):
        take=int(receipt.stem.split("-")[1])
        with np.load(receipt.with_suffix(".npz")) as archive:
            passes[take]=archive["rgb"]
        metrics[take]=measure(job,passes[take],guide)
    if not metrics:
        raise ValueError(f"No Wan runs yet for {folder}")
    chosen=requested or min(metrics,key=lambda key:metrics[key]["score"])
    capture(job,folder,guide,[(f"Wan pass {key}",frame) for key,frame in passes.items()])
    cels=recover(job,passes[chosen],guide)
    assert len(cels)==job["exportedFrames"]
    width,height=cels[0].size
    atlas=Image.new("RGBA",(width*4, height*((len(cels)+3)//4)))
    for i,cel in enumerate(cels):
        atlas.paste(cel,(i%4*width,i//4*height))
    atlas.save(folder/"registered-cels.webp",lossless=True)
    (folder/"review.json").write_text(json.dumps(dict(chosen=chosen,passes=metrics),indent=2)+"\n",encoding="utf-8")
    print(job["name"],chosen,metrics[chosen],flush=True)


if __name__=="__main__":
    for name in sys.argv[1:] or JOBS:
        folder=OUT/name
        save(json.loads((folder/"manifest.json").read_text(encoding="utf-8")))
