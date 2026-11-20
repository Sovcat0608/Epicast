"""Bake paired inner fans with the neighboring crown and shoulder poses in register."""
from pathlib import Path
import json
import sys

HERE=Path(__file__).resolve().parent
PREVIEW=HERE.parent
sys.path[:0]=[str(PREVIEW),str(PREVIEW/"right-crown-study"),str(PREVIEW/"shoulder-study/right-bend")]
import numpy as np
from PIL import Image, ImageFilter

from bake import LAYERS, MASTER
from crown import leaf_contact, registered
from bake_spine_bend import inverse_bend
from bake_wave import composite, premultiply, remap, rgba
from render import model_bow

FRAMES=16
FRAME_MS=125
COLUMNS=4
ORIGINAL=Image.open(MASTER/"Figma crest.png").convert("RGBA")


def config(name):
    return json.loads((PREVIEW/name).read_text(encoding="utf-8-sig").split("=",1)[1].strip().rstrip(";"))


def crop_tile(image, origin, slot):
    x,y,w,h=slot
    return image.crop((x-origin[0],y-origin[1],x-origin[0]+w,y-origin[1]+h))


def atlas_frames(path, slot):
    w,h=slot[2:]
    with Image.open(PREVIEW/path) as source:
        return [source.crop((i%COLUMNS*w,i//COLUMNS*h,(i%COLUMNS+1)*w,(i//COLUMNS+1)*h)).convert("RGBA")
                for i in range(FRAMES)]


def animated_frames(path):
    with Image.open(PREVIEW/path) as source:
        assert source.n_frames==FRAMES
        frames=[]
        for i in range(FRAMES):
            source.seek(i)
            frames.append(source.convert("RGBA"))
        return frames


def prepare_neighbor(track_path, scene_key, paint_path, phase=0, paint_atlas=False, field_path=None):
    track=config(track_path)
    box=track["slot"]
    paint=atlas_frames(paint_path,box) if paint_atlas else animated_frames(paint_path)
    cover = None
    if "coverage" in track:
        cover=Image.open(PREVIEW/track["coverage"]).convert("RGBA").getchannel("A")
    fields=None
    if field_path:
        fields=[im.getchannel("A") for im in atlas_frames(field_path,box)]
    return box,phase,atlas_frames(track[scene_key],box),paint,cover,fields


def existing_fans():
    # Draw order and phase match the default preview. These source cels
    # contain the underlying paintings, while the previews include shadows.
    return {
        8:prepare_neighbor("crown-ludo/autumn-track.js","sheet","crown-ludo/idle.webp",2,
                           field_path="crown-ludo/contact.webp"),
        10:prepare_neighbor("shoulder-study/griffin-quiet/track.js","pairedSheet","shoulder-study/griffin-quiet/leaf.webp"),
        11:prepare_neighbor("shoulder-study/right-bend/track.js","pairedSheet","shoulder-study/right-bend/leaf.webp"),
        9:prepare_neighbor("right-crown-study/spine-bend/track.js","sheet","right-crown-study/spine-bend/leaves.webp",6,
                           paint_atlas=True),
    }


def build_side(side,index,delay,neighbors):
    track=config("crown/idle.js")["tracks"][index-8]
    slot=track["slot"]
    pivot=tuple(track["pivot"])
    x,y,w,h=slot
    row=LAYERS[index]
    art_origin=(row["x"]-x,row["y"]-y)
    native=Image.open(MASTER/"registered"/f"{index:02}-paint.png").convert("RGBA")
    stem=tuple(p-r for p,r in zip(pivot,art_origin))
    direction=np.array([.72 if side=="left" else -.72,.69],dtype=np.float64)
    direction/=np.linalg.norm(direction)
    anchor=23
    keyframe,measured,length=model_bow(
        native,HERE/(side+".mp4"),(81,85,81+2*row["w"],85+2*row["h"]),stem,direction,anchor,
    )
    tip=float(np.clip(abs(measured)*length**2/2,3.9,5.2))
    strength=float(np.copysign(2*tip/(length**2),measured))
    peak=float(np.clip(keyframe/32,.43,.57))
    time=(np.arange(FRAMES)-delay)%FRAMES/FRAMES
    phase=np.interp(time,[0,peak,1],[0,np.pi,2*np.pi])
    gust=(1-np.cos(phase))*.5
    sy,sx=np.mgrid[:h,:w].astype(np.float64)
    static_paint=[registered(i,"paint",slot) for i in range(len(LAYERS))]
    static_shadows=[registered(i,"field",slot).getchannel("A") for i in range(len(LAYERS))]
    leaf=static_paint[index]
    shadow=static_shadows[index]
    cels,paintings=[],[]
    changed=np.zeros((h,w),dtype=bool)
    for frame,bend in enumerate(gust):
        reference=ORIGINAL.crop((x,y,x+w,y+h))
        paints,shadows=static_paint.copy(),static_shadows.copy()
        for layer,(box,offset,scenes,paint,cover,fields) in neighbors.items():
            play=(frame+offset)%FRAMES
            tile=crop_tile(scenes[play],box,slot)
            # Pasting a transparent scene normally replaces its whole tile.
            # The upper green fan instead has its own coverage mask.
            if cover is None:
                mask=Image.new("L",box[2:],255)
            else:
                mask=cover
            reference.paste(tile,(0,0),crop_tile(mask,box,slot))
            paints[layer]=crop_tile(paint[play],box,slot)
            field=fields[play] if fields else leaf_contact(paint[play].getchannel("A")).getchannel("A")
            shadows[layer]=crop_tile(field,box,slot)
        before=premultiply(composite(paints,shadows))
        mx,my=inverse_bend(sx,sy,bend*strength,pivot,direction,anchor)
        paints[index]=remap(leaf,mx,my)
        shadows[index]=remap(shadow,mx,my)
        delta=premultiply(composite(paints,shadows))-before
        affected=np.any(np.abs(delta)>.48/255,axis=2)
        changed |= affected
        new=rgba(premultiply(reference)+delta)
        cels.append(new)
        paintings.append(paints[index])

    mask=Image.fromarray(changed.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(3))
    assert mask.getbbox() is not None
    coverage=Image.new("RGBA",(w,h))
    coverage.putalpha(mask)
    coverage.save(HERE/(side+"-coverage.webp"),lossless=True)
    atlas=Image.new("RGBA",(COLUMNS*w,COLUMNS*h))
    for i,cel in enumerate(cels):
        atlas.paste(Image.composite(cel,Image.new("RGBA",(w,h)),mask),(i%COLUMNS*w,i//COLUMNS*h))
    atlas.save(HERE/(side+"-scene.webp"),lossless=True)
    paintings[0].save(HERE/(side+".webp"),save_all=True,append_images=paintings[1:],
                      duration=FRAME_MS,loop=0,lossless=True)
    print(side,{"peakSourceFrame":keyframe,"tipTravelPx":round(tip,2),"phaseDelayCels":delay})
    return dict(slot=slot,columns=COLUMNS,frames=FRAMES,frameMs=FRAME_MS,
                sheet=f"inner-leaf-study/{side}-scene.webp",coverage=f"inner-leaf-study/{side}-coverage.webp")


def build():
    neighbors=existing_fans()
    tracks=[build_side("left",12,0,neighbors),build_side("right",13,4,neighbors)]
    (HERE/"track.js").write_text("const innerLeafIdle = "+json.dumps(tracks)+";\n")


if __name__=="__main__":
    build()

