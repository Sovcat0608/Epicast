"""Bake a continuous slow ripple along each worn cloth end."""
from pathlib import Path
import json
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path.insert(0,str(PREVIEW/"crest-motion-batch"))
from PIL import Image
from bake_batch import (
    FRONT, TAU, cv2, guide, model_direction, motions_from_video, smooth, straight_patch, window,
)

SLOTS = ((132,620,233,317),(767,620,263,317))
CHANNEL_SLOTS = ((121,554,292,383),(726,554,300,383))
PRINT_BOUNDS = ((93,438,193,529),(608,429,742,542))
FRAMES = 32
FRAME_MS = 125
# Native coordinates along the falling hems. Keep the corridor away from the
# print and from the wood behind the torn diagonal edges.
HEIGHTS = [494,533,564,595,622,652,681,725,746]
INSIDE = [
    [99,104,105,95,86,83,77,71,69],
    [108,113,116,110,100,88,78,68,64],
]


def pose_for(side,slot,vector,frames=FRAMES,channel=False):
    def pose(frame,x,y,_,layer):
        u,v=x+slot[0]-164,y+slot[1]-150
        from_edge=u if side==0 else 817-u
        inside=np.interp(v,HEIGHTS,INSIDE[side])
        corridor=(1-smooth(inside-22,inside+4,from_edge))*smooth(-27,-9,from_edge)
        free=smooth(484,722,v)*(1-smooth(740,775,v))
        # Cross-sections move together. The phase arrives down the cloth,
        # with the two ends placed a little apart in the same breeze.
        along=np.clip((v-490)/237,0,1)
        clock=TAU*(frame/frames-.13*side-.24*along)
        wave=np.sin(clock)+.16*np.sin(2*clock-.62)
        travel=corridor*free*wave
        lift=corridor*free*(.74*wave+.26*np.cos(clock-.5))
        dx,dy=vector[0]*travel,vector[1]*lift
        if channel:
            # The attached fabric leads the wave while the free tips curl
            # a little farther outward and lift during their follow-through.
            tail=corridor*smooth(619,734,v)*(1-smooth(742,774,v))
            curl=tail*(.48+.52*np.sin(clock-.78))
            dx=1.58*dx+(-1 if side==0 else 1)*4.4*curl
            dy=1.34*dy-4.0*curl
        return dx,dy
    return pose


def symbol_light(side,slot,frames,flash=None):
    left,top,right,bottom=PRINT_BOUNDS[side]

    def glow(frame,art,x,y):
        u,v=x+slot[0]-164,y+slot[1]-150
        selection=(smooth(left,left+6,u)*(1-smooth(right-6,right,u)) *
                   smooth(top,top+6,v)*(1-smooth(bottom-6,bottom,v)))
        data=np.asarray(art,dtype=np.float32)/255
        paint=data[:,:,:3]
        light_ink=smooth(.34,.68,paint.min(axis=2))
        low_saturation=1-smooth(.23,.39,paint.max(axis=2)-paint.min(axis=2))
        symbol=selection*light_ink*low_saturation
        inner=cv2.GaussianBlur(symbol,(0,0),3.4)
        falloff=cv2.GaussianBlur(symbol,(0,0),10.5)
        pulse=.75+.25*np.sin(TAU*(frame/frames-.13*side)+.54) if flash is None else flash[frame]
        if not pulse:
            return art
        spread=pulse*(.38*inner+.72*falloff)
        ink=.72*pulse*symbol
        if flash is not None:
            spread=np.minimum(spread,.92)
            ink=np.minimum(ink,.96)
        tinted=np.array([.84,.50,1.],dtype=np.float32)
        ivory=np.array([1.,.92,1.],dtype=np.float32)
        lit=1-(1-paint)*(1-spread[:,:,None]*tinted)
        data[:,:,:3]=np.clip(lit+(ivory-lit)*ink[:,:,None],0,1)
        return Image.fromarray(np.rint(data*255).astype(np.uint8))
    return glow


def feather_channel_timing():
    script=(PREVIEW/"channel.js").read_text()
    channel=json.loads(script.split("=",1)[1].strip().rstrip(";"))
    timing=[frame["ms"] for frame in channel["clusters"][0]["tracks"][0]["frames"]]
    return channel["fps"],timing


def build_channel(reference):
    fps,timing=feather_channel_timing()
    count,period=len(timing),sum(timing)
    result=[]
    for side,slot in enumerate(CHANNEL_SLOTS):
        drift,_=guide(reference,side)
        vector=model_direction(drift,[(7.2,-2.5),(6.6,-2.2)][side],.22)
        name=("left" if side==0 else "right")+"-channel"
        track=straight_patch(slot,[FRONT],count,period/count,
                             pose_for(side,slot,vector,count,channel=True),name,
                             halo=symbol_light(side,slot,count),output=HERE,redraw_feathers=True)
        track.update(fps=fps,period=period,durations=timing)
        result.append(track)
    (HERE/"channel-track.js").write_text("const fabricFlagChannel = "+json.dumps(result)+";\n")


def build():
    reference=motions_from_video("flags",
        [window(43,403,66,433),window(569,404,597,436)],window(119,128,178,181),source=HERE/"wan.mp4")
    if "--channel" in sys.argv:
        build_channel(reference)
        return
    result=[]
    for side,slot in enumerate(SLOTS):
        drift,strength=guide(reference,side)
        # The source only guides direction. A fixed cap keeps the new motion
        # gentle and avoids carrying model repaint into the original cloth.
        vector=model_direction(drift,[(7.2,-2.5),(6.6,-2.2)][side],.22)
        name="left" if side==0 else "right"
        result.append(straight_patch(slot,[FRONT],FRAMES,FRAME_MS,pose_for(side,slot,vector),
                                     name,output=HERE,redraw_feathers=True))
        print(name,{"sourceMotionPx":round(strength,2),"horizontalPx":round(float(vector[0]),2)})
    (HERE/"track.js").write_text("const fabricFlagIdle = "+json.dumps(result)+";\n")


if __name__=="__main__":
    build()

