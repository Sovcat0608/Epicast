"""Render the left shoulder from its live Idle pose with a fixed branch contact."""
import argparse
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

import generate
import inspect_trial
from validate import verify
from bake_impact import representative_idle_pose
from bake_inner import crop_tile, inverse_bend
from crown import registered
from guides import COUNT, OUTPUT, PREVIEW, ROOT, SIZE, cv2, digest, leaf_sources, paint_pose, plate, rgb_light
from cheek_placement import registered_stack
from register_preview import IMPACT, extract, smoothstep


STUDY = OUTPUT / "left-shoulder-strong-bend"
SEGMENT = "left-shoulder"
PIXEL_GUARD = 88
X_WEIGHT = .22
Y_WEIGHT = 1.02
BEND_GAIN = {"channel": 1.85, "impact": 2.0}
IDLE_SOURCE = PREVIEW / "shoulder-study/griffin-quiet/leaf.webp"


def contact_weight(job):
    # The visible interface extends past the stem into the bough's lower curve.
    # Keep the paint within six pixels of the wood fixed, with a soft motion ramp.
    wood = np.asarray(registered(18, "paint", job["registered"]).getchannel("A"))
    distance = cv2.distanceTransform(np.uint8(wood < 128), cv2.DIST_L2, cv2.DIST_MASK_PRECISE)
    return smoothstep((distance - 6) / 20)


def guides():
    approved = json.loads((OUTPUT/"manifest.json").read_text(encoding="utf-8"))
    entries = [row for row in approved if row["name"] == SEGMENT]
    idle_slot, idle_frames = leaf_sources()[10]
    for job in entries:
        state = job["state"]
        folder = STUDY / SEGMENT / state
        folder.mkdir(parents=True,exist_ok=True)
        original = ROOT/job["source"]
        if digest(original) != job["source_sha256"]:
            raise ValueError("The shoulder source differs from the approved painting")
        idle = [crop_tile(frame, idle_slot, job["registered"]) for frame in idle_frames]
        art = representative_idle_pose(idle)
        art.save(folder/"live-idle-reference.png")
        x0,y0,w,h = job["modelRect"]
        stem = np.asarray(job["stem"])
        spine = np.asarray(job["direction"])
        normal = np.array([-spine[1],spine[0]])
        yy,xx = np.mgrid[:art.height,:art.width]
        along = (xx-stem[0])*spine[0]+(yy-stem[1])*spine[1]
        across = (xx-stem[0])*normal[0]+(yy-stem[1])*normal[1]
        active = np.asarray(art.getchannel("A"))>220
        span = along[active].max()-PIXEL_GUARD
        delay = np.clip(across/145,-1,1)*.053
        strength = job["tipTargetPx"]
        mx,my = inverse_bend(xx,yy,2*strength/span**2,stem,spine,PIXEL_GUARD)
        dx = np.clip((mx-xx)*X_WEIGHT,-3,3)
        dy = (my-yy)*Y_WEIGHT*BEND_GAIN[state]
        region = smoothstep((along-PIXEL_GUARD)/18)*contact_weight(job)
        dx *= region
        dy *= region
        native, rgb, alpha = [],[],[]
        for i,t in enumerate(np.linspace(0,1,COUNT)):
            if state=="channel":
                amount = np.sin(np.pi*np.clip(t-delay*np.sin(np.pi*t),0,1))**2
                pulse = 1.2*(.83+.17*np.sin(2*np.pi*(t-.073*(job["index"]-8))))
            else:
                # Establish the bend in the first cel and recover over the rest of the second.
                amount = np.interp(t,[0,.075,.125,.25,.5,.75,1],[0,.84,1,.90,.38,.08,0])
                pulse = 1.3*np.interp(t,[0,.075,.125,.25,.42,.65,1],[0,1.08,1.25,.68,.16,0,0])
            posed = paint_pose(art,xx+dx,yy+dy,amount)
            lit = rgb_light(posed,job["index"],pulse) if pulse else posed
            native.append(np.asarray(lit))
            model = Image.new("RGBA",SIZE)
            model.alpha_composite(lit.resize((w,h),Image.Resampling.LANCZOS),(x0,y0))
            alpha.append(np.asarray(model.getchannel("A")))
            rgb.append(np.asarray(plate(model)))
            if i in job["keys"]:
                model.save(folder/f"pose-{i:02}.png")
                plate(model).save(folder/f"wan-reference-{i:02}.png")
        np.savez_compressed(folder/"guide.npz",native=np.stack(native),rgb=np.stack(rgb),alpha=np.stack(alpha))
        job.update(rootLength=PIXEL_GUARD, liveIdleSource=IDLE_SOURCE.relative_to(ROOT).as_posix(),
                   liveIdleSha256=digest(IDLE_SOURCE), liveIdleFrame=idle.index(art),
                   lateralGuideLimitPx=round(float(np.max(np.abs(dx[active]))),2),
                   verticalGuideLimitPx=round(float(np.max(np.abs(dy[active]))),2),
                   bendGain=BEND_GAIN[state], revision="strong-bend-fixed-branch")
        print(state, "fresh lateral/vertical guide limits",
              job["lateralGuideLimitPx"],job["verticalGuideLimitPx"],flush=True)
    (STUDY/"manifest.json").write_text(json.dumps(entries,indent=2)+"\n",encoding="utf-8")


def render(passes):
    generate.OUTPUT = STUDY
    generate.PROMPT = ("Exact isolated hand-painted green shoulder leaf cluster from the supplied keys. "
                       "Front camera locked. The full inner shoulder and attachment are planted at their key "
                       "coordinates. Individual blades flex from each midrib, with distributed downward "
                       "or backward curvature through the fan and tiny stagger between groups. "
                       "No side-to-side fan shift, no bodily translation or rotation. "
                       "Preserve every leaf, the vein paths and broad warm green paint.")
    generate.DIRECTIONS.update(
        channel="A fast anchored flutter. The blades flex visibly from the middle through the tips, "
                "curling downward and releasing in a smooth "
                "loop, keeping the bulk of the fan centered. Match the green and yellow glow in the supplied keys.",
        impact="One quick full-blade outward fold in place with the early shockwave glow, then an eased recovery. "
               "No shift at the stem or out across the side. Preserve the supplied silhouette and pulse.",
    )
    for trial in passes:
        sys.argv = [sys.argv[0],"--trial",str(trial),"--steps","32"]
        generate.main()


def centroid(alpha):
    row = np.arange(alpha.shape[2])
    return (alpha*row).sum(axis=(1,2))/alpha.sum(axis=(1,2))


def register(job, trial):
    state = job["state"]
    folder = STUDY / SEGMENT / state
    run = json.loads((folder/f"trial-{trial:02}.json").read_text(encoding="utf-8"))
    assert run["guideSha256"] == digest(folder/"guide.npz")
    with np.load(folder/"guide.npz") as guide:
        native,rgb,alpha = (guide[name] for name in ("native","rgb","alpha"))
    with np.load(folder/f"trial-{trial:02}.npz") as movie:
        raw = movie["rgb"]
    x,y,w,h = job["modelRect"]
    canvas = np.zeros(SIZE[::-1],dtype=bool)
    canvas[y:y+h,x:x+w] = True
    width,height = job["registered"][2:]
    yy,xx = np.mgrid[:height,:width]
    along = (xx-job["stem"][0])*job["direction"][0]+(yy-job["stem"][1])*job["direction"][1]
    contact = contact_weight(job)
    motion = smoothstep((along-PIXEL_GUARD)/35)*contact
    locked = (along<=PIXEL_GUARD) | (contact==0)
    assert digest(ROOT/job["liveIdleSource"]) == job["liveIdleSha256"]
    with Image.open(folder/"live-idle-reference.png") as idle:
        idle_alpha = np.asarray(idle.getchannel("A"))
    cels=[]
    chosen = list(range(0,32,2)) if state=="channel" else IMPACT
    for n in chosen:
        target=Image.fromarray(native[n])
        candidate=extract(raw[n],rgb[n],alpha[n],canvas).crop((x,y,x+w,y+h))
        candidate=candidate.resize((width,height),Image.Resampling.LANCZOS)
        solid=np.asarray(target.getchannel("A").filter(ImageFilter.MinFilter(7)),dtype=np.float32)/255
        limit=np.asarray(candidate.getchannel("A"),dtype=np.float32)/255
        seam=smoothstep(min(n,32-n)/6) if state=="channel" else smoothstep((32-n)/6)
        mask=Image.fromarray(np.uint8(np.rint(255*.73*solid*limit*motion*seam)))
        # Preserve the guide outline and fixed underlap. Wan contributes
        # surface/facet changes only where the individual blades actually bend.
        art=Image.composite(candidate.convert("RGB"),target.convert("RGB"),mask)
        art.putalpha(target.getchannel("A"))
        pixels=np.asarray(art)
        assert np.array_equal(pixels[locked],native[n][locked])
        assert np.array_equal(pixels[:,:,3][locked],idle_alpha[locked])
        cels.append(art)

    source=OUTPUT/SEGMENT/state/"registered-cels.webp"
    old_image=Image.open(source).convert("RGBA")
    columns=4
    atlas=Image.new("RGBA",(width*columns,height*((len(cels)+3)//4)))
    old=[]
    for i,cel in enumerate(cels):
        ox,oy=i%columns*width,i//columns*height
        atlas.paste(cel,(ox,oy))
        old.append(np.asarray(old_image.crop((ox,oy,ox+width,oy+height)).getchannel("A")))
    before=float(np.ptp(centroid(np.asarray(old,dtype=np.float32))))
    active_alpha=np.asarray([cel.getchannel("A") for cel in cels],dtype=np.float32)
    after=float(np.ptp(centroid(active_alpha)))
    assert after<before*.65, (state,before,after)

    # Test the state change in crest space with the foreground included.
    # A stable centroid within each isolated clip can hide a jump between clips.
    origin, idle_frames=leaf_sources()[job["index"]]
    idle_alpha_frames=np.asarray([crop_tile(frame,origin,job["registered"]).getchannel("A")
                                  for frame in idle_frames],dtype=np.float32)
    paints,_=registered_stack(job["registered"],hide_cheeks=True)
    exposed=np.ones((height,width),dtype=np.float32)
    for paint in paints[job["index"]+1:]:
        exposed *= 1-np.asarray(paint.getchannel("A"),dtype=np.float32)/255
    idle_centres=centroid(idle_alpha_frames*exposed)
    live_centres=centroid(active_alpha*exposed)
    maximum_shift=float(np.max(np.abs(live_centres[:,None]-idle_centres)))
    assert maximum_shift<.65, (state,maximum_shift)

    atlas.save(folder/"registered-cels.webp",lossless=True)
    info=dict(trial=trial, oldHorizontalCentroidSweepPx=round(before,3),
              newHorizontalCentroidSweepPx=round(after,3), sourceHash=digest(source),
              exactProtectedRoot=True, exactLiveIdleContactAlpha=True,
              liveIdleFrame=job["liveIdleFrame"], liveIdleHash=job["liveIdleSha256"],
              maximumExposedShiftFromAnyIdleFramePx=round(maximum_shift,3),
              frames=len(cels), periodSeconds=job["cycle"])
    (folder/"registration-review.json").write_text(json.dumps(info,indent=2)+"\n",encoding="utf-8")
    print(state,info,flush=True)
    inspect_trial.OUTPUT=STUDY
    inspect_trial.inspect(job,trial)


def select(trial):
    path=OUTPUT/"review-selection.json"
    previous=path.read_bytes()
    selection=json.loads(previous)
    for state in ("channel","impact"):
        folder=STUDY/SEGMENT/state
        review=json.loads((folder/"registration-review.json").read_text(encoding="utf-8"))
        if review["trial"]!=trial or not review["exactLiveIdleContactAlpha"]:
            raise ValueError(f"No reviewed anchored {state} cels for trial {trial}")
        selection[f"{SEGMENT}/{state}"]=dict(trial=trial,revision=STUDY.name,
            note="Stronger blade bend with the approved live Idle branch contact locked")
    path.write_text(json.dumps(selection,indent=2)+"\n",encoding="utf-8")
    try:
        verify()
    except Exception:
        path.write_bytes(previous)
        raise


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=("guides","render","register","select"))
    parser.add_argument("--passes",type=int,nargs="+",default=[2])
    args=parser.parse_args()
    cv2.setNumThreads(2)
    if args.action=="guides":
        guides()
    elif args.action=="render":
        render(args.passes)
    elif args.action=="register":
        for row in json.loads((STUDY/"manifest.json").read_text(encoding="utf-8")):
            register(row,args.passes[0])
    else:
        select(args.passes[0])
