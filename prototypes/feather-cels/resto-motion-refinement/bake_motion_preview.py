"""Bake the review clips, with receiver-clipped contact and separate leaf hover."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageChops, ImageFilter

from motion_guides import HERE, OUT, PREVIEW, ROOT, LEAF, channel_bend, leaf_pose, cv2
sys.path[:0] = [str(PREVIEW),str(ROOT/"concepts/restoration-frame146")]
from cheek_placement import LAYERS, composite, crest_path, premult, rgba, registered_stack
from contact_field import contact_field

DEST = HERE/"preview"
LEAF_SLOT = (365,320,419,440)
FACE_SLOT = (412,769,320,423)
COLUMNS = 4


def crop_rect(slot):
    x,y,w,h=slot
    return (x,y,x+w,y+h)


def rgba_alpha(mask, color=(0,0,0)):
    art=Image.new("RGBA",mask.size,color+(0,))
    art.putalpha(mask)
    return art


def asset(name, art):
    art.save(DEST/name,lossless=True)
    return (DEST/name).relative_to(PREVIEW).as_posix()


def frames(name):
    folder=OUT/name
    data=json.loads((folder/"manifest.json").read_text(encoding="utf-8"))
    atlas=Image.open(folder/"registered-cels.webp")
    w,h=data["slot"][2:]
    cels=[atlas.crop(crop_rect((i%COLUMNS*w,i//COLUMNS*h,w,h))).convert("RGBA")
          for i in range(data["exportedFrames"])]
    return data,cels


def atlas(name, cels):
    w,h=cels[0].size
    art=Image.new("RGBA",(COLUMNS*w,((len(cels)+COLUMNS-1)//COLUMNS)*h))
    for i,cel in enumerate(cels):
        art.paste(cel,(i%COLUMNS*w,i//COLUMNS*h))
    return asset(name,art)


def on_cel(cel, src_slot, target_slot):
    out=Image.new("RGBA",target_slot[2:])
    out.paste(cel,(src_slot[0]-target_slot[0],src_slot[1]-target_slot[1]))
    return out


def shade_delta(old, old_procedural, newest):
    return Image.fromarray(np.clip(old+np.asarray(newest,dtype=np.int16)-old_procedural,0,255).astype(np.uint8))


def cast(alpha, layer, slot):
    row=LAYERS[layer]
    return contact_field(alpha,row["name"],row["x"]-slot[0],row["y"]-slot[1])


def treant():
    metadata,cels=frames("treant-idle")
    fixed = on_cel(cels[0],metadata["slot"],FACE_SLOT)
    stack = registered_stack(FACE_SLOT,hide_cheeks=True)
    front = premult(stack[0][18])
    reference_field=np.asarray(stack[1][18],dtype=np.int16)
    old_cast=np.asarray(cast(stack[0][18].getchannel("A"),18,FACE_SLOT),dtype=np.int16)
    clean_face,present_fields=[],[]
    max_under_chin=0
    yy,xx=np.mgrid[:FACE_SLOT[3],:FACE_SLOT[2]]
    bottom_guard=np.clip((FACE_SLOT[3]-yy-2)/18,0,1)*np.clip((FACE_SLOT[2]-xx-2)/12,0,1)*np.clip((xx-1)/12,0,1)
    fixed_pixels=premult(fixed)
    for cel in cels:
        posed = on_cel(cel,metadata["slot"],FACE_SLOT)
        front_cel = rgba(front+premult(posed)-fixed_pixels)
        clean_face.append(front_cel)
        field = shade_delta(reference_field,old_cast,cast(front_cel.getchannel("A"),18,FACE_SLOT))
        difference=(np.asarray(field,dtype=np.int16)-reference_field)*bottom_guard
        max_under_chin=max(max_under_chin,int(np.max(np.abs(difference[302:]))))
        present_fields.append(Image.fromarray(np.uint8(np.rint(reference_field+difference))))
    settings={}
    for hidden in (True,False):
        paints,fields=registered_stack(FACE_SLOT,hide_cheeks=hidden)
        rest = premult(composite(paints,fields,FACE_SLOT))
        original=premult(Image.open(crest_path(hidden)).convert("RGBA").crop(crop_rect(FACE_SLOT)))
        posed=[]
        for art,field in zip(clean_face,present_fields):
            paints[18]=art
            fields[18]=field
            result=premult(composite(paints,fields,FACE_SLOT))
            posed.append(rgba(original+result-rest))
        settings["hidden" if hidden else "shown"]=atlas(f"treant-{'hidden' if hidden else 'shown'}.webp",posed)
    settings.update(slot=FACE_SLOT,columns=COLUMNS,frames=len(cels),period=metadata["duration"],
                    frameMs=metadata["duration"]/len(cels))
    return settings,max_under_chin


def channel_entry(rest, lit_poses, data):
    # The Start spans 500 ms of the approved wave. Register the unlit painting
    # to each matching Wan silhouette so light can build while the fan bends.
    count = round(500*len(lit_poses)/data["duration"])
    original = Image.open(LEAF).convert("RGBA")
    padded = Image.new("RGBA", data["slot"][2:])
    padded.paste(original, (64,64))
    entry = [rest]
    for i in range(1,count):
        turn,bend = channel_bend(i/len(lit_poses))
        unlit = leaf_pose(padded,turn,bend,0)
        lit = lit_poses[i]
        assert unlit.getchannel("A").tobytes() == lit.getchannel("A").tobytes()
        t = i/(count-1)
        entry.append(on_cel(Image.blend(unlit,lit,t*t*(3-2*t)),data["slot"],LEAF_SLOT))
    return entry


def leaf():
    slot=LEAF_SLOT
    paint,fields=registered_stack(slot,hide_cheeks=True)
    normal=premult(composite(paint,fields,slot))
    # Remove the old fixed paint and its baked shadow before drawing the moving layer.
    paint[15]=Image.new("RGBA",slot[2:])
    fields[15]=Image.new("L",slot[2:])
    clean=premult(composite(paint,fields,slot))
    ref=premult(Image.open(crest_path(True)).convert("RGBA").crop(crop_rect(slot)))
    under=rgba(ref+clean-normal)
    coverage=Image.fromarray(np.uint8((np.max(np.abs(clean-normal),axis=2)>1/255)*255))
    coverage=coverage.filter(ImageFilter.MaxFilter(5))
    upper, incoming = Image.new("RGBA",slot[2:]), Image.new("L",slot[2:])
    for index in (16,17,18):
        upper.alpha_composite(paint[index])
        incoming=ImageChops.screen(incoming,fields[index])
    profiles={
        "slot":slot,
        "receiver":asset("leaf-clean-receiver.webp",Image.composite(under,Image.new("RGBA",under.size),coverage)),
        "coverage":asset("leaf-old-coverage.webp",rgba_alpha(coverage)),
        "occlusion":asset("leaf-front-occlusion.webp",rgba_alpha(upper.getchannel("A"))),
        "incoming":asset("leaf-incoming-shadow.webp",rgba_alpha(incoming)),
        "float":dict(period=6830,amplitude=4.2,offset=670),
        "clips":{},
    }
    for state in ("idle","channel","impact"):
        data,source=frames(f"rejuvenation-{state}")
        local=[on_cel(cel,data["slot"],slot) for cel in source]
        if state == "idle":
            rest = local[0]
        if state == "impact":
            local[-1] = rest
        hold_frames = len(local)
        if state == "channel":
            # At both upright crossings turn is zero in the registered guide.
            # Align the two paint samples by their known horizontal fan bend
            # before interpolating light, keeping a single edge and fixed stem.
            y,x = np.indices((slot[3],slot[2]),dtype=np.float32)
            lever = np.maximum(0, (410+203-slot[1]-y)/204)**2
            rest_bend = 2.8*np.sin(-.27)
            for crossing in (0, hold_frames//2):
                bend = 10.5*np.sin(2*np.pi*crossing/hold_frames-.36)
                lit = local[crossing]
                for i in range(7):
                    t = i/6
                    t = t*t*(3-2*t)
                    if i in (0,6):
                        local.append(lit if i == 0 else rest)
                        continue
                    def aligned(image, dx):
                        return cv2.remap(np.asarray(image.convert("RGBa")), (x+dx*lever).astype("float32"),
                                         y,cv2.INTER_LINEAR)
                    delta = rest_bend-bend
                    pixels = np.rint((1-t)*aligned(lit,-t*delta)+t*aligned(rest,(1-t)*delta)).astype(np.uint8)
                    local.append(Image.frombytes("RGBa",rest.size,pixels.tobytes()).convert("RGBA"))
            entry = channel_entry(rest,source,data)
            local.extend(entry)
        active_cast=[]
        for index,cel in enumerate(local):
            alpha=cel.getchannel("A")
            field=rgba_alpha(cast(alpha,15,slot))
            if state!="idle":
                pixels=np.asarray(cel,dtype=np.float32)/255
                # Derive spill from purple pixels and precombine it with the
                # shadow. Both use the same receiver clip at playback.
                rim=np.clip((pixels[:,:,2]-pixels[:,:,1])*.92-.07,0,.56)*pixels[:,:,3]
                soft=Image.fromarray(np.uint8(np.rint(rim*255))).filter(ImageFilter.GaussianBlur(6))
                field.alpha_composite(rgba_alpha(soft,(168,49,229)))
            active_cast.append(field)
        assert all(im.getchannel("A").getextrema()[1] for im in active_cast)
        def track(key, images):
            return atlas(f"leaf-{state}-{key}.webp",images)
        clips=dict(paint=track("paint",local),shadow=track("shadow",active_cast),
                   frames=len(local),period=data["duration"],frameMs=data["duration"]/hold_frames,
                   columns=COLUMNS)
        if state == "channel":
            clips.update(holdFrames=hold_frames, restRamp=7, startFrames=len(entry))
        profiles["clips"][state]=clips
    return profiles,int(np.count_nonzero(np.asarray(coverage)))


def main():
    DEST.mkdir(exist_ok=True)
    face,shadow_variation=treant()
    leaf_art,receiver_region=leaf()
    (DEST/"tracks.js").write_text("const restorationMotion = "+json.dumps(dict(
        treant=face,rejuvenation=leaf_art))+";\n",encoding="utf-8")
    audit=dict(jawShadowPeakChange=shadow_variation,leafRestReceiverPixels=receiver_region,
               leafSpill="Soft purple spill sampled from coloured edges and clipped under the foreground",
               leafShadow="Each cel follows the leaf and is clipped to the existing crest alpha",
               scope="Desktop compositor")
    (OUT/"hbao-audit.json").write_text(json.dumps(audit,indent=2)+"\n",encoding="utf-8")
    print(audit)


if __name__=="__main__":
    main()
