"""Register Wan's moving paint and bake the three tracks over one static rest cel."""
import argparse
from hashlib import sha256
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from rest_guides import APPROVED, CHIN, HERE, OUT, PREVIEW, SOURCE, STATES, chin_translation, guide_inputs, jaw_edges, references
sys.path.insert(0,str(PREVIEW))
from bake import LAYERS, MASTER
from cheek_placement import composite, crest_path, premult, rgba, registered_stack

sys.path.insert(0,str(MASTER))
from contact_field import contact_field

DEST = HERE/"rigid-jaw"
SLOT = (374,769,396,510)
FRAMES = {
    "treant-idle": list(range(31))+[32],
    "treant-channel": list(range(33)),
    "treant-impact": [0,3,4,7,10,13,16,19,23,27,30,32],
}
COLUMNS = 4
REVISION = "treant-rigid-jaw"


def rect(slot):
    x,y,w,h = slot
    return x,y,x+w,y+h


def image_from_asset(paint, node, bounds):
    art = Image.new("RGBA",bounds[2:])
    art.paste(paint,(node[0]-bounds[0],node[1]-bounds[1]))
    return art


def pupils(art):
    px = np.array(art,dtype=np.int16)
    r,g,b,a = np.moveaxis(px,2,0)
    green = (g-r>30)&(g-b>35)&(g>100)&(a>200)
    return [int(green[83:123,left:right].sum()) for left,right in ((71,110),(174,217))]


def aperture(art):
    px = np.asarray(art)
    window = px[157:278,75:207]
    deep = (np.max(window[:,:,:3],axis=2)<57)&(window[:,:,3]>218)
    count,_,stats,_ = references.cv2.connectedComponentsWithStats(np.uint8(deep))
    assert count>1
    part = max(stats[1:],key=lambda row: row[references.cv2.CC_STAT_AREA])
    return [int(n) for n in part]


def register(name,trial,root,approved=None):
    folder = root/name
    folder.mkdir(exist_ok=True)
    job = json.loads((folder/"manifest.json").read_text(encoding="utf-8"))
    run = json.loads((folder/f"pass-{trial}.json").read_text(encoding="utf-8"))
    def digest(path):
        return sha256(path.read_bytes()).hexdigest()
    assert job["sourceHash"]==digest(SOURCE) and run["guideHash"]==digest(folder/"guide.npz")
    assert run["guideFrames"]==job["keys"]
    with np.load(folder/"guide.npz") as guides:
        native = guides["native"]
    with np.load(folder/f"pass-{trial}.npz") as video:
        raw = video["rgb"]
    box = rect(job["rect"])
    size = tuple(job["slot"][2:])
    initial = Image.fromarray(native[0])
    assert np.array_equal(native[0],native[-1])
    with Image.open(SOURCE) as source:
        assert np.array_equal(native[0,:source.height],np.asarray(source.convert("RGBA")))
    y,x = np.mgrid[:size[1],:size[0]]
    brow = (y>=38)&(y<=108)&(x>=29)&(x<=251)
    jaw = (y>=155)&(y<=361)&(x>77)&(x<204)
    region = jaw if approved is not None or name=="treant-idle" else (brow|jaw)
    lower_face = (y>=154)&(x>77)&(x<204)

    def decode(index):
        image = Image.fromarray(raw[index]).crop(box).resize(size,Image.Resampling.LANCZOS)
        return np.asarray(image,dtype=np.float32)

    original = native[0,:,:,:3].astype(np.float32)
    opening_bias = np.clip(decode(0)-original,-40,40)
    cels,details,travels = [],[],[]
    for cel_index,index in enumerate(FRAMES[name]):
        guide = native[index]
        jaw_amount = guide_inputs(name,index)[0]
        travel = chin_translation(jaw_amount)
        travels.append(travel)
        if index in (0,32):
            cels.append(initial.copy())
            continue
        # Keep the cavity and the eye opening registered. Transfer only
        # Wan's local carved planes and texture inside the permitted area.
        solid = np.asarray(Image.fromarray(guide[:,:,3]).filter(ImageFilter.MinFilter(7)))>248
        values = guide[:,:,:3].astype(np.float32)
        r,g,b = np.moveaxis(values,2,0)
        openings = (np.max(values,axis=2)<67)|((g-r>20)&(g-b>28)&(y<127))
        rim = np.asarray(Image.fromarray(np.uint8(openings)*255).filter(ImageFilter.MaxFilter(7)))>0
        strength = .55*np.minimum(1,min(index,32-index)/5)
        mask = solid&region&~rim
        if approved is not None:
            floor = jaw_edges(x,jaw_amount)[3]
            mask &= ~((x>=95)&(x<=186)&(y>=floor))
        correction = np.clip(decode(index)-values-opening_bias,-32,32)
        art = guide.copy()
        art[:,:,:3] = np.uint8(np.rint(np.clip(values+correction*(mask*strength)[:,:,None],0,255)))
        details.append(int(np.count_nonzero(np.any(art!=guide,axis=2))))
        assert np.array_equal(art[~region],guide[~region]) and np.array_equal(art[:,:,3],guide[:,:,3])
        if approved is not None:
            art[~lower_face] = np.asarray(approved[cel_index])[~lower_face]
            left,top,right,bottom = CHIN
            pinned = art[top+travel:bottom+travel,left:right]
            source = native[0,top:bottom,left:right]
            # Verify a pure translation of the opaque carving. Copy its
            # exact source including antialiasing where premultiplication rounded.
            solid_chin = source[:,:,3]==255
            assert np.array_equal(pinned[solid_chin],source[solid_chin]), (name,index,travel)
            assert np.array_equal(pinned[:,:,3],source[:,:,3]), (name,index,travel)
            pinned[:] = source
        cels.append(Image.fromarray(art))
    if name=="treant-channel":
        cels[24]=cels[8].copy()
    assert max(details)>200
    if approved is None:
        return job,cels

    key_frames = (0,4,8,12,16,20,24,28,32)
    board = Image.new("RGB",(130*len(key_frames),420),(30,35,42))
    text = ImageDraw.Draw(board)
    for col,index in enumerate(key_frames):
        x = col*130
        tagged = Image.fromarray(raw[index]).resize((126,126),Image.Resampling.LANCZOS)
        board.paste(tagged,(x,20))
        text.text((x+5,4),f"Wan {index}",fill="white")
        nearest = min(range(len(cels)),key=lambda k: abs(FRAMES[name][k]-index))
        cell = cels[nearest].copy()
        cell.thumbnail((126,247),Image.Resampling.LANCZOS)
        board.paste(cell,(x+(130-cell.width)//2,180),cell)
        text.text((x+5,158),f"Registered {FRAMES[name][nearest]}",fill="white")
    board.save(folder/"review.jpg",quality=95)
    selected = cels[16 if name=="treant-idle" else 12 if name=="treant-channel" else 2]
    base_open,active_open = aperture(initial),aperture(selected)
    base_eyes,active_eyes = pupils(initial),pupils(selected)
    peak = dict(restAperture=base_open,activeAperture=active_open,
                restEyePixels=base_eyes,activeEyePixels=active_eyes,wanPaintPixels=max(details),
                rigidChinBounds=CHIN,chinTravelPx=travels,unaffectedArtMatches=True)
    peak_index = 16 if name=="treant-idle" else 12 if name=="treant-channel" else 2
    assert pupils(selected)==pupils(approved[peak_index]), peak
    if name!="treant-idle":
        assert abs(base_open[0]-active_open[0])<=2 and abs(base_open[2]-active_open[2])<=2, peak
        assert active_open[3]>1.50*base_open[3], peak
        assert all(.35<a/b<.70 for a,b in zip(active_eyes,base_eyes)), peak
    else:
        assert active_open[4]<.45*base_open[4], peak
    print(name,peak,flush=True)
    (folder/"registration.json").write_text(json.dumps(peak,indent=2)+"\n",encoding="utf-8")
    return job,cels


def wood_overlaps(poses,rest):
    # The wood compositor redraws the upper branch over the moving receiver.
    # Export only the parts of that branch and its cast that can vary there.
    wood = PREVIEW/"wood-channel-study"
    track = json.loads((wood/"track.js").read_text(encoding="utf-8").split("=",1)[1].strip().rstrip(";"))
    changes = np.zeros((SLOT[3],SLOT[2]),dtype=bool)
    reference_paint,reference_shadow = premult(rest[0]),np.asarray(rest[1])
    for frames in poses.values():
        for paint,shadow in frames:
            changes |= np.any(np.abs(premult(paint)-reference_paint)>.5/255,axis=2)
            changes |= np.asarray(shadow)!=reference_shadow

    assets = []
    for (side,tile) in zip(("left","right"),track["tiles"]):
        tx,ty,tw,th = tile["slot"]
        offset_x,offset_y = SLOT[0]-tx,SLOT[1]-ty
        tile_changes = Image.new("L",(tw,th))
        tile_changes.paste(Image.fromarray(np.uint8(changes)*255),(offset_x,offset_y))
        with Image.open(PREVIEW/tile["mask"]) as support:
            allowed = np.asarray(support.getchannel("A"))>0
        box = Image.fromarray((np.asarray(tile_changes)>0)&allowed).getbbox()
        if box is None:
            assets.append(None)
            continue
        x,y,right,bottom = box
        w,h = right-x,bottom-y
        crop = x-offset_x,y-offset_y,right-offset_x,bottom-offset_y
        files = {}
        for key,frames in poses.items():
            state = key.split("-")[1]
            rows = (len(frames)+COLUMNS-1)//COLUMNS
            atlas = Image.new("RGBA",(COLUMNS*w,2*rows*h))
            for i,(paint,field) in enumerate(frames):
                at_x,at_y = i%COLUMNS*w,i//COLUMNS*(2*h)
                atlas.paste(paint.crop(crop),(at_x,at_y))
                shadow = Image.new("RGBA",(w,h))
                shadow.putalpha(field.crop(crop))
                atlas.paste(shadow,(at_x,at_y+h))
            path = DEST/f"{side}-wood-{state}.webp"
            atlas.save(path,lossless=True)
            files[state] = path.relative_to(PREVIEW).as_posix()+f"?v={REVISION}"
        assets.append(dict(rect=[x,y,w,h],files=files))
    return assets


def bake(trial):
    data = {}
    for name in STATES:
        _,approved = register(name,2,APPROVED)
        data[name] = register(name,trial,OUT,approved)
    DEST.mkdir(exist_ok=True)
    face_index = 18
    _,(rest_job,rest_cels) = next(iter(data.items()))
    place = lambda pose,job: image_from_asset(pose,job["slot"],SLOT)
    rest_face = premult(place(rest_cels[0],rest_job))
    art,fields = registered_stack(SLOT,hide_cheeks=True)
    front, field = premult(art[face_index]), np.asarray(fields[face_index],dtype=np.int16)
    row = LAYERS[face_index]

    def cast(alpha):
        return np.asarray(contact_field(alpha,row["name"],row["x"]-SLOT[0],row["y"]-SLOT[1]),dtype=np.int16)

    original = art[face_index],fields[face_index]
    old_cast = cast(original[0].getchannel("A"))
    poses = {}
    for name,(job,cels) in data.items():
        posed = [rgba(front+premult(place(cel,job))-rest_face) for cel in cels]
        poses[name] = [(image,Image.fromarray(np.uint8(np.clip(field+cast(image.getchannel("A"))-old_cast,0,255))))
                       for image in posed]
        poses[name][0] = poses[name][-1] = original
    changes = np.zeros((SLOT[3],SLOT[2]),dtype=bool)
    variants = {}
    for variant in ("hidden","shown"):
        hidden = variant=="hidden"
        art,fields = registered_stack(SLOT,hide_cheeks=hidden)
        rest = premult(composite(art,fields,SLOT))
        with Image.open(crest_path(hidden)) as master:
            ref = master.convert("RGBA").crop(rect(SLOT))
        variants[variant] = {}
        for name,frames in poses.items():
            results = []
            for image,shadow in frames:
                art[face_index],fields[face_index] = image,shadow
                delta = premult(composite(art,fields,SLOT))-rest
                changed = np.any(np.abs(delta)>.5/255,axis=2)
                changes |= changed
                results.append(Image.composite(rgba(premult(ref)+delta),ref,Image.fromarray(changed)))
            assert np.array_equal(results[0],ref) and np.array_equal(results[-1],ref)
            variants[variant][name.split("-")[1]] = results
    bounds = Image.fromarray(changes).getbbox()
    assert bounds and bounds[2]<SLOT[2]-2 and bounds[3]<SLOT[3]-2
    x,y,right,bottom = bounds
    w,h = right-x,bottom-y
    track = dict(slot=[SLOT[0]+x,SLOT[1]+y,w,h],columns=COLUMNS,idleFrames=32,idleMs=4000,impactFrames=12,
                 impactMs=1000,channelHoldMs=2000/3,files={},wood=wood_overlaps(poses,original))
    for variant,clips in variants.items():
        names = {}
        for name,cels in clips.items():
            sheet = Image.new("RGBA",(COLUMNS*w,((len(cels)+COLUMNS-1)//COLUMNS)*h))
            for i,cel in enumerate(cels):
                sheet.paste(cel.crop(bounds),(i%COLUMNS*w,i//COLUMNS*h))
            file = DEST/f"{variant}-{name}.webp"
            sheet.save(file,lossless=True)
            names[name] = file.relative_to(PREVIEW).as_posix()+f"?v={REVISION}"
        track["files"][variant]=names
    (DEST/"track.js").write_text("const treantRestCycle = "+json.dumps(track)+";\n",encoding="utf-8")
    print("Baked common rest and all three newly registered tracks.", track["slot"],flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pass",dest="trial",type=int,default=2)
    args=parser.parse_args()
    bake(args.trial)
