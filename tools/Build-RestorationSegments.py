"""Prepare independently playable Restoration paintings from the registered sources."""
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "prototypes/feather-cels"
OUT = ROOT / "artifacts/restoration-segments"
sys.path[:0] = [str(PREVIEW/name) for name in (
    "", "crest-motion-batch", "leaf-channel-study", "fabric-flag-study",
    "treant-study", "inner-leaf-study", "right-crown-study",
)]
from bake import MASTER, LAYERS, CLUSTERS
from cheek_placement import premult, rgba, registered_stack
from bake_batch import axes, remap, vine_motion
from bake_glow import leaf_sources
from bake_flag import CHANNEL_SLOTS, SLOTS, pose_for, symbol_light, motions_from_video, window, guide, model_direction
from restoration_shard_contacts import WRAPS, build_contacts


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, PREVIEW/path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


from rest_guides import APPROVED, OUT as JAW_REVIEW, STATES as JAW_STATES
from bake_rest import register as register_jaw
flag_impact = module("flag_impact", "fabric-flag-study/bake_impact.py")

FULL_ETCH = PREVIEW / "wood-channel-study/painted-reference/recess-glint-wan/midpoint-full-etch"
WAN_LEAVES = ROOT / "artifacts/restoration-leaf-wan-refinement"
FRONT = 18
def read(relative):
    return json.loads((PREVIEW/relative).read_text(encoding="utf-8-sig").split("=", 1)[1].strip().rstrip(";"))

def paint(index):
    row = LAYERS[index]
    return (row["x"], row["y"], row["w"], row["h"]), Image.open(MASTER/"registered"/f"{index:02}-paint.png").convert("RGBA")

def tile(sprite, origin, rect):
    x,y,w,h = rect
    return sprite.crop((x-origin[0],y-origin[1],x-origin[0]+w,y-origin[1]+h))

def atlas(name, slot, columns, count):
    w,h = slot[2:]
    with Image.open(PREVIEW/str(name).split("?")[0]) as source:
        return [source.crop((i%columns*w,i//columns*h,(i%columns+1)*w,(i//columns+1)*h)).convert("RGBA") for i in range(count)]

def union(rects):
    x,y=min(r[0] for r in rects),min(r[1] for r in rects)
    return x,y,max(r[0]+r[2] for r in rects)-x,max(r[1]+r[3] for r in rects)-y

def one(rect, images, period, envelope=None):
    return dict(rect=rect, images=images, period=period, envelope=envelope)


def feather(side, state):
    data = read({"idle":"tracks.js","channel":"channel.js","impact":"impact.js"}[state])
    cluster = data["clusters"][side]
    rect = tuple(cluster["slot"])
    first,second=cluster["tracks"]
    count=len(first["frames"])
    blades=[atlas(track["sheet"],rect,data["columns"],count) for track in (first,second)]
    duration=sum(frame["ms"] for frame in first["frames"])
    selected=[]
    world, source = paint(side)
    lip=Image.new("L",source.size)
    ImageDraw.Draw(lip).polygon(CLUSTERS[side].lip,fill=255)
    source.putalpha(Image.fromarray(np.minimum(np.asarray(source.getchannel("A")),np.asarray(lip))))
    attachment=tile(source,world,rect)
    for i in range(count):
        result=Image.new("RGBA",rect[2:])
        for j,track in enumerate((first,second)):
            # The authored stop/impact poses already include their delay.
            delay=math.ceil(track["delay"]/(duration/count)) if state!="impact" else 0
            result.alpha_composite(blades[j][(i-delay)%count])
        result.alpha_composite(attachment)
        selected.append(result)
    return one(rect,selected,duration)


def front_parts():
    rect, source=paint(FRONT)
    original=np.asarray(source)
    masks=[]
    for shape in WRAPS:
        mask=Image.new("1",source.size)
        ImageDraw.Draw(mask).polygon(shape,fill=1)
        masks.append(np.asarray(mask))
    face=tile(Image.open(PREVIEW/"treant-study/face.png"),(429,777),rect)
    masks.append(np.asarray(face.getchannel("A"))>0)
    assert not np.any(np.sum(masks,axis=0)>1)
    layers={}
    for name,mask in zip(("boughs","leftBanner","rightBanner","treant"),[~np.logical_or.reduce(masks),*masks]):
        rgba=original.copy()
        rgba[~mask]=0
        layers[name]=Image.fromarray(rgba)
    result=Image.new("RGBA",source.size)
    for part in layers.values():result.alpha_composite(part)
    assert np.array_equal(np.asarray(result)[original[:,:,3]>0],original[original[:,:,3]>0])
    return rect,layers


def move(rect, source_rect, source, count, period, pose, emit=None, deform=None, envelope=None):
    start=tile(source,source_rect,rect)
    x,y=axes(rect)
    frames=[]
    for index in range(count):
        if deform:
            im,_=deform(index,x,y,start,Image.new("L",start.size))
        else:
            dx,dy=pose(index,x,y,start,FRONT)
            im=remap(start,x,y,dx,dy)
        frames.append(emit(index,im,x,y) if emit else im)
    return one(rect,frames,period,envelope)


def treant_animation(fronts):
    origin, sprites = fronts
    clips = {}
    for name in JAW_STATES:
        _,approved = register_jaw(name,2,APPROVED)
        job,cels = register_jaw(name,2,JAW_REVIEW,approved)
        state = name.split("-")[1]
        rect = tuple(job["slot"])
        rest = tile(sprites["treant"],origin,rect)
        native = premult(rest)
        reference = premult(cels[0])
        frames = [rest]
        for cel in cels[1:-1]:
            delta = premult(cel)-reference
            changed = Image.fromarray(np.any(delta!=0,axis=2))
            frames.append(Image.composite(rgba(native+delta),rest,changed))
        frames.append(rest)
        clips[state] = one(rect,frames,job["duration"])
    clips["channel"].update(period=2000/3, stages={"holdFirst":9,"releaseFirst":25})
    return clips


def front_animation(shape, origin, sprites, vector):
    source=sprites[shape]
    side=0 if shape=="leftBanner" else 1
    chan=CHANNEL_SLOTS[side]
    strike=flag_impact.SLOTS[side]
    return {
        "idle":move(SLOTS[side],origin,source,32,4000,pose_for(side,SLOTS[side],vector)),
        "channel":move(chan,origin,source,6,500,pose_for(side,chan,vector,6,channel=True),symbol_light(side,chan,6)),
        "impact":move(strike,origin,source,12,1000,None,symbol_light(side,strike,12,flash=flag_impact.FLASH),
                      flag_impact.reverse_fold(side,strike)),
    }


def wan_leaf_actions():
    sources = json.loads((WAN_LEAVES/"manifest.json").read_text(encoding="utf-8"))
    validation = json.loads((WAN_LEAVES/"verification.json").read_text(encoding="utf-8"))
    selection = json.loads((WAN_LEAVES/"review-selection.json").read_text(encoding="utf-8"))
    validated = {(row["segment"],row["state"]): row for row in validation}
    clips = {}
    impact_mix = read("leaf-impact-study/track.js")["mix"]
    for row in sources:
        index, state = row["index"], row["state"]
        verified = validated[(row["name"],state)]
        frames = row["outputFrames"]
        rect = tuple(row["registered"])
        if frames != verified["registeredFrames"] or row["cycle"] != verified["duration"]:
            raise ValueError(f"Wan leaf timing differs from review: {row['name']} / {state}")
        review = selection[f"{row['name']}/{state}"]
        path = WAN_LEAVES/review.get("revision","")/row["name"]/state/"registered-cels.webp"
        with Image.open(path) as sheet:
            w,h = rect[2:]
            if sheet.mode != "RGBA" or sheet.size != (4*w,math.ceil(frames/4)*h):
                raise ValueError(f"Invalid registered leaf cel sheet: {path}")
        clips.setdefault(index,{})[state] = one(
            rect, atlas(path,rect,4,frames), 1000 * row["cycle"], impact_mix if state=="impact" else None)
    if set(clips) != set(range(8,14)) or any(set(states) != {"channel","impact"} for states in clips.values()):
        raise ValueError("Missing reviewed Channel or Impact leaf cels")
    return clips


def floating_art():
    leaf = read("resto-motion-refinement/preview/tracks.js")["rejuvenation"]
    leaf_clips = {state:one(tuple(leaf["slot"]),atlas(clip["paint"],leaf["slot"],clip["columns"],clip["frames"]),clip["period"])
                  for state,clip in leaf["clips"].items()}
    leaf_paints,_ = registered_stack(tuple(leaf["slot"]),hide_cheeks=True)
    leaf_receiver = Image.new("RGBA",tuple(leaf["slot"][2:]))
    for paint_layer in leaf_paints[:15]:
        leaf_receiver.alpha_composite(paint_layer)
    for state,clip in leaf["clips"].items():
        casts = atlas(clip["shadow"],leaf["slot"],clip["columns"],clip["frames"])
        frames = leaf_clips[state]["images"]
        for i,(paint_layer,shadow) in enumerate(zip(frames,casts)):
            shadow.putalpha(ImageChops.multiply(shadow.getchannel("A"),leaf_receiver.getchannel("A")))
            shadow.alpha_composite(paint_layer)
            frames[i] = shadow
    leaf_clips["channel"]["restRamp"] = leaf["clips"]["channel"]["restRamp"]
    leaf_clips["channel"]["startFrames"] = leaf["clips"]["channel"]["startFrames"]
    crown = read("crown-symbol/track.js")
    slot = tuple(crown["slot"])
    x,y = slot[:2]
    px,py = crown["pivot"]
    sx,sy,w,h = crown["sprite"]
    with Image.open(PREVIEW/crown["atlas"].split("?")[0]) as sheet:
        pieces = [[sheet.crop((col*w,row*h,(col+1)*w,(row+1)*h)).convert("RGBA")
                   for col in range(4)] for row in range(2)]
    paints,_ = registered_stack(slot,hide_cheeks=True)
    receiver = Image.new("RGBA",slot[2:])
    for paint_layer in paints[:14]:
        receiver.alpha_composite(paint_layer)

    def crown_cel(pose):
        c,s = math.cos(pose["rock"])/pose["scale"], math.sin(pose["rock"])/pose["scale"]
        u,v = px-x,py-y
        result = Image.new("RGBA",slot[2:])
        for col in (3,2,0):
            for i in (1,0):
                dx = pose["ballX"] if i==0 else 0
                dy = pose["ballY"] if i==0 else pose["moonY"]
                matrix=(c,s,px-sx-dx-c*u-s*v,-s,c,py-sy-dy+s*u-c*v)
                cell = pieces[i][col]
                if col==0:
                    cell = Image.blend(cell,pieces[i][1],min(1,pose["glow"]))
                cell = cell.convert("RGBa").transform(slot[2:],Image.Transform.AFFINE,matrix,Image.Resampling.BICUBIC).convert("RGBA")
                if col!=0:
                    opacity = .90 if col==3 else min(1,.74*pose["glow"])
                    alpha = cell.getchannel("A").point(lambda a: round(a*opacity))
                    cell.putalpha(ImageChops.multiply(alpha,receiver.getchannel("A")))
                result.alpha_composite(cell)
        return result

    samples = json.loads(subprocess.check_output(["node",str(ROOT/"tools/Sample-RestorationCrown.cjs")],cwd=ROOT))
    crown_clips = {state:one(slot,[crown_cel(pose) for pose in row["poses"]],row["period"])
                   for state,row in samples.items()}
    crown_clips["impact"]["envelope"] = [min(1,max(0,(40-i-1)/6)) for i in range(40)]
    return {"crownGlyph":crown_clips,"rejuvenation":leaf_clips}


def clips_for(item, leaves, actions, fronts, vectors, treant, floating):
    index,name=item["source"],item["id"]
    if name in floating:
        return floating[name]
    source_rect,original=paint(index)
    if index<2:
        return {state:feather(index,state) for state in ("idle","channel","impact")}
    if index in leaves:
        rect,cels=leaves[index]
        return {"idle":one(rect,cels,2000), **actions[index]}
    if index==3:
        rect,pose=vine_motion()
        frame_set=move(rect,source_rect,original,32,4000,lambda f,x,y,im,_:pose(f,x,y,im,3))
        return {"idle":frame_set}
    if index in (4,5):
        side=("left","right")[index-4]
        peak=Image.open(FULL_ETCH/f"{side}-midpoint.png").convert("RGBA")
        return {"idle":one(source_rect,[original],4000),"channel":one(source_rect,[peak],500)}
    if index==18:
        origin, sprites=fronts
        if name=="treant":
            return treant
        if name!="boughs":
            return front_animation(name,origin,sprites,vectors[name])
        original=sprites[name]
    if index==16:source_rect=(source_rect[0],source_rect[1]+30,*source_rect[2:])
    return {"idle":one(source_rect,[original],4000)}


def base_shadow(index, rect):
    _, fields=registered_stack(rect,hide_cheeks=True)
    row=LAYERS[index]
    light=np.ones(rect[2:][::-1],dtype=np.float32)
    for caster in row["casters"]:
        if caster in (14,15):
            continue
        strength=row["contactStrength"].get(LAYERS[caster]["name"],1)
        light*=1-strength*np.asarray(fields[caster],dtype=np.float32)/255
    return light


def export(item, clips, placement, fronts):
    rect=union([c["rect"] for c in clips.values()])
    # Cloth/treant source owns additional fixed paint outside the moving
    # corridor; restore those pixels by composing around each authored crop.
    if item["id"] in ("leftBanner","rightBanner","treant","roots"):
        source_rect, source=(fronts[0],fronts[1][item["id"]]) if item["source"]==18 else paint(3)
        box=source.getbbox()
        fixed_rect=(source_rect[0]+box[0],source_rect[1]+box[1],box[2]-box[0],box[3]-box[1])
        rect=union([rect,fixed_rect])
        fixed=tile(source,source_rect,rect)
    else:
        fixed=Image.new("RGBA",rect[2:])
    light=base_shadow(item["source"],rect) if item["source"] not in (0,1,18) else None
    entries={}
    raw={}
    bounds=None
    for state,clip in clips.items():
        x,y,w,h=clip["rect"]
        frames=[]
        for im in clip["images"]:
            cell=fixed.copy()
            cell.paste(im,(x-rect[0],y-rect[1]))
            if light is not None:
                rgba=np.asarray(cell).copy()
                rgba[:,:,:3]=np.rint(rgba[:,:,:3]*light[:,:,None]).astype(np.uint8)
                cell=Image.fromarray(rgba)
            frames.append(cell)
        for cel in frames:
            support=cel.getbbox()
            if not support:raise RuntimeError(f"Empty cel on {item['id']} / {state}")
            bbox=(support[0],support[1],support[2]-support[0],support[3]-support[1])
            bounds=union([bounds,bbox]) if bounds else bbox
        raw[state]=frames
        entries[state]=dict(period=clip["period"]/1000,frames=len(frames),envelope=clip["envelope"])
        if clip.get("stages"):
            entries[state]["stages"]=clip["stages"]
        if clip.get("restRamp"):
            entries[state]["restRamp"]=clip["restRamp"]
            entries[state]["startFrames"]=clip["startFrames"]
    if item["id"] in ("leftBanner","rightBanner"):
        side = int(item["id"]=="rightBanner")
        rest = flag_impact.IDLE_RETURN[side]
        raw["impact"][-1] = raw["idle"][rest]
        entries["impact"]["restIdleCel"] = rest+1
    scale,ox,oy=placement
    left,top,w,h=bounds
    origin_x,origin_y=rect[0]+left,rect[1]+top
    a=math.floor((origin_x+160)*scale+ox)-3
    b=math.floor(origin_y*scale+oy)-3
    c=math.ceil((origin_x+w+160)*scale+ox)+3
    d=math.ceil((origin_y+h)*scale+oy)+3
    size=(c-a,d-b)
    matrix=(1/scale,0,(a-ox)/scale-160-rect[0],0,1/scale,(b-oy)/scale-rect[1])
    for state,frames in raw.items():
        for index,cel in enumerate(frames):
            im=cel.convert("RGBa").transform(size,Image.Transform.AFFINE,matrix,Image.Resampling.BICUBIC).convert("RGBA")
            (OUT/f"{item['id']}-{state}-{index}.bgra").write_bytes(im.tobytes("raw","BGRA"))
    result = {**item,"rect":[a,b,*size],"clips":entries}
    hover = {"crownGlyph":(6.92,3.4,.710),"rejuvenation":(6.83,4.2,.670)}.get(item["id"])
    if hover:
        period,amplitude,phase = hover
        result["hover"] = [period,amplitude*scale/880,phase]
    return result


def build():
    OUT.mkdir(exist_ok=True,parents=True)
    source_path=ROOT/"artifacts/restoration-idle-cas-build/bake.json"
    placement=json.loads(source_path.read_text())["transform"]
    items=json.loads((ROOT/"tools/restoration-segments.json").read_text(encoding="utf-8-sig"))
    leaves=leaf_sources()
    actions=wan_leaf_actions()
    fronts=front_parts()
    treant=treant_animation(fronts)
    floating=floating_art()
    samples=motions_from_video("flags",[window(43,403,66,433),window(569,404,597,436)],
                               window(119,128,178,181),source=PREVIEW/"fabric-flag-study/wan.mp4")
    vectors={side:model_direction(guide(samples,i)[0],[(7.2,-2.5),(6.6,-2.2)][i],.22)
             for i,side in enumerate(("leftBanner","rightBanner"))}
    data=[]
    for item in items:
        data.append(export(item,clips_for(item,leaves,actions,fronts,vectors,treant,floating),placement,fronts))
        print(item["id"],flush=True)
    (OUT/"segments.json").write_text(json.dumps(data),encoding="utf-8")
    build_contacts(OUT, data, placement, treant)
    subprocess.run(["node",str(ROOT/"tools/Pack-RestorationSegments.cjs"),str(OUT)],cwd=ROOT,check=True)


if __name__=="__main__":
    build()
