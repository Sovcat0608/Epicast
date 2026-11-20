"""Batch the six registered idle fans into independently addressable Channel glow atlases."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path[:0] = [str(PREVIEW),str(PREVIEW/"inner-leaf-study")]
from bake import LAYERS
from crown import registered
from bake_inner import COLUMNS, FRAMES, FRAME_MS, animated_frames, config, crop_tile, existing_fans

AMBER = (255,214,114)
GREEN = (231,255,147)
TINTS = {8:AMBER,9:GREEN,10:GREEN,11:AMBER,12:GREEN,13:GREEN}
SPEED = 3
PERIOD = FRAMES * FRAME_MS / SPEED


def leaf_sources():
    poses = {
        i:(slot, [frames[(frame+phase)%FRAMES] for frame in range(FRAMES)])
        for i,(slot,phase,_,frames,_,_) in existing_fans().items()
    }
    for index,side in [(12,"left"),(13,"right")]:
        track = config("inner-leaf-study/track.js")[index-12]
        poses[index] = (track["slot"],animated_frames(f"inner-leaf-study/{side}.webp"))
    return poses


def transparency_in_front(index,slot,poses):
    static = np.ones(slot[2:][::-1],dtype=np.float32)
    for i in range(index+1,len(LAYERS)):
        if i in poses:
            continue
        alpha = registered(i,"paint",slot).getchannel("A")
        static *= 1-np.asarray(alpha,dtype=np.float32)/255
    for frame in range(FRAMES):
        visible = static.copy()
        for i,(origin,cels) in poses.items():
            if i>index:
                alpha=crop_tile(cels[frame],origin,slot).getchannel("A")
                visible *= 1-np.asarray(alpha,dtype=np.float32)/255
        yield visible


def emission(leaf, visible, frame, index, pulse=None):
    paint=np.asarray(leaf,dtype=np.float32)/255
    alpha=paint[:,:,3]
    luma=paint[:,:,:3]@np.array([.2126,.7152,.0722],dtype=np.float32)
    # Lift the planes and pick out the existing raised veins and ridges.
    # Filter in premultiplied alpha so transparent margins do not outline.
    softened=Image.fromarray(np.rint(255*luma*alpha).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3.1))
    density=leaf.getchannel("A").filter(ImageFilter.GaussianBlur(3.1))
    normalizer=np.asarray(density,dtype=np.float32)
    broad=np.asarray(softened,dtype=np.float32)/np.maximum(1,normalizer)
    raised=np.clip((luma-broad-.025)*3.2,0,.31)
    if pulse is None:
        pulse=.83+.17*np.sin(2*np.pi*(frame/FRAMES-.073*(index-8)))
    intensity=np.clip(.12+.33*luma+raised,0,.59)*pulse
    mask=np.rint(255*intensity*alpha*visible).astype(np.uint8)
    glow=Image.new("RGBA",leaf.size,TINTS[index]+(0,))
    glow.putalpha(Image.fromarray(mask))
    return glow


def bake():
    poses=leaf_sources()
    assert set(poses)==set(TINTS)
    tracks=[]
    for index in sorted(poses):
        slot,frames=poses[index]
        w,h=slot[2:]
        sheet=Image.new("RGBA",(COLUMNS*w,FRAMES//COLUMNS*h))
        for frame,(leaf,visible) in enumerate(zip(frames,transparency_in_front(index,slot,poses))):
            glow=emission(leaf,visible,frame,index)
            if not glow.getbbox():
                raise ValueError(f"Leaf {index} is completely occluded on frame {frame}")
            sheet.paste(glow,(frame%COLUMNS*w,frame//COLUMNS*h))
        asset=f"{index:02}-glow.webp"
        sheet.save(HERE/asset,lossless=True)
        tracks.append(dict(layer=index,name=LAYERS[index]["name"],slot=slot,columns=COLUMNS,frames=FRAMES,
                           frameMs=FRAME_MS/SPEED,period=PERIOD,fps=1000*SPEED/FRAME_MS,
                           sheet=f"leaf-channel-study/{asset}"))
        print(LAYERS[index]["name"],"ready",flush=True)
    (HERE/"track.js").write_text("const leafChannel = "+json.dumps(tracks)+";\n")


if __name__=="__main__":
    bake()

