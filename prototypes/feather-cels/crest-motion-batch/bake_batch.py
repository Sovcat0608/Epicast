"""Bake the batch references into registered Restoration track patches."""
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(HERE.parent), str(HERE.parents[2]/"animation-rnd/.deps")]
import cv2
import numpy as np
from PIL import Image, ImageFilter
from bake import LAYERS
from cheek_placement import HIDDEN, OFFSETS, composite, crest_path, registered_stack

FRONT = 18
ROOTS = 3
TAU = math.tau


def smooth(lo, hi, x):
    x = np.clip((x-lo)/(hi-lo),0,1)
    return x*x*(3-2*x)


def axes(slot):
    h,w=slot[3],slot[2]
    y,x=np.mgrid[:h,:w].astype(np.float32)
    return x,y


def premult(image):
    result=np.asarray(image,dtype=np.float32)/255
    result[:,:,:3]*=result[:,:,3:4]
    return result


def rgba(pixels):
    a=np.clip(pixels[:,:,3:4],0,1)
    channels=np.clip(pixels[:,:,:3],0,a)
    color=np.divide(channels,a,out=np.zeros_like(channels),where=a>0)
    return Image.fromarray(np.rint(255*np.concatenate((color,a),axis=2)).astype(np.uint8))


def remap(image, x, y, dx, dy):
    data=premult(image) if image.mode=="RGBA" else np.asarray(image)
    output=cv2.remap(data,(x-dx).astype("float32"),(y-dy).astype("float32"),cv2.INTER_LINEAR)
    return rgba(output) if image.mode=="RGBA" else Image.fromarray(output)


def motions_from_video(name, samples, anchor, source=None):
    """Subtract motion at the attachment and measure motion in each visible end."""
    c=cv2.VideoCapture(str(source or HERE/(name+".mp4")))
    solver=cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    time_series=[]
    origin=None
    try:
        while (item:=c.read())[0]:
            gray=cv2.cvtColor(item[1],cv2.COLOR_BGR2GRAY)
            if origin is None:
                origin=gray
            flow=solver.calc(origin,gray,None)
            pinned=np.median(flow[anchor],axis=(0,1))
            time_series.append([np.median(flow[region],axis=(0,1))-pinned for region in samples])
    finally:
        c.release()
    if len(time_series)<12:
        raise ValueError(f"The {name} reference is incomplete")
    return np.asarray(time_series)


def window(x1,y1,x2,y2):
    return np.s_[y1:y2,x1:x2]


def guide(samples, index):
    """Take a coherent movement direction with the strongest off-axis sample."""
    median=cv2.GaussianBlur(samples[:,index,:],(1,7),1.6)
    largest=median[np.argmax(np.linalg.norm(median,axis=1))]
    return largest, float(np.linalg.norm(largest))


def model_direction(sample, authored, mix=.30):
    """Keep the observed drift direction, with a stable cap for the game sprite."""
    amplitude=float(np.linalg.norm(sample))
    own=np.asarray(authored,dtype=np.float32)
    if amplitude<.4:
        return own
    measured=sample*np.linalg.norm(own)/amplitude
    if own@measured<0:
        measured=-measured
    return (1-mix)*own+mix*measured


def straight_patch(slot, layers, count, step, pose, name, halo=None, hide_cheeks=False,
                   output=None, redraw_feathers=False, extra_coverage=None, loop=0, deform=None):
    output=output or (HIDDEN if hide_cheeks else HERE)
    x,y=axes(slot)
    extent=slot[2:]
    paints,fields=registered_stack(slot,hide_cheeks=hide_cheeks)
    originals={layer:(paints[layer],fields[layer]) for layer in layers}
    with Image.open(crest_path(hide_cheeks)) as crest:
        reference_image=crest.crop((slot[0],slot[1],slot[0]+slot[2],slot[1]+slot[3])).convert("RGBA")
    rest=premult(composite(paints,fields,slot))
    if redraw_feathers:
        for index in (0,1):
            paints[index]=Image.new("RGBA",extent)
        featherless=premult(composite(paints,fields,slot))
        exposed=np.any(np.abs(featherless-rest)>.45/255,axis=2)
        reference_image=Image.composite(rgba(featherless),reference_image,
                                        Image.fromarray(exposed.astype(np.uint8)*255))
        rest=featherless
    reference=premult(reference_image)
    mask=np.zeros(reference.shape[:2],bool)
    cels=[]
    for i in range(count):
        for layer,(original,field) in originals.items():
            if deform is None:
                dx,dy=pose(i,x,y,original,layer)
                paints[layer]=remap(original,x,y,dx,dy)
                fields[layer]=remap(field,x,y,dx,dy)
            else:
                paints[layer],fields[layer]=deform(i,x,y,original,field)
            if halo:
                paints[layer]=halo(i,paints[layer],x,y)
        diff=premult(composite(paints,fields,slot))-rest
        changed=np.any(np.abs(diff)>.45/255,axis=2)
        mask |= changed
        pixels=rgba(reference+diff)
        selection=Image.fromarray(changed.astype(np.uint8)*255)
        cels.append(Image.composite(pixels,reference_image,selection))
    # A solid support mask replaces changed pixels, including transparent
    # regions that the animated silhouette exposes on the assembled canvas.
    alpha=Image.fromarray(mask.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(3))
    if extra_coverage is not None:
        alpha=Image.fromarray(np.maximum(np.asarray(alpha),np.asarray(extra_coverage)))
    empty=Image.new("RGBA",extent)
    coverage=empty.copy()
    coverage.putalpha(alpha)
    coverage.save(output/(name+"-coverage.webp"),lossless=True)
    columns=4
    sheet=Image.new("RGBA",(slot[2]*columns,slot[3]*math.ceil(count/columns)))
    clips=[]
    for i,frame in enumerate(cels):
        at=(i%columns*slot[2],i//columns*slot[3])
        sheet.paste(Image.composite(frame,empty,alpha),at)
        clips.append(frame)
    sheet.save(output/(name+"-scene.webp"),lossless=True)
    if hide_cheeks:
        return
    timing=[round((i+1)*step)-round(i*step) for i in range(count)]
    clips[0].save(output/(name+".webp"),save_all=True,append_images=clips[1:],duration=timing,loop=loop,lossless=True)
    root=output.relative_to(HERE.parent).as_posix()+"/"+name
    result=dict(slot=slot,frames=count,columns=columns,frameMs=step,
                sheet=root+"-scene.webp",coverage=root+"-coverage.webp")
    if redraw_feathers:
        result["redrawFeathers"]=True
    return result


def vine_motion():
    samples=motions_from_video("vines",[window(147,374,180,437),window(441,368,474,433)],
                               window(270,299,342,373))
    observed=[guide(samples,i)[0] for i in range(2)]
    left,right=[model_direction(sample,authored) for sample,authored in
                zip(observed,[(7.0,-1.7),(6.6,1.4)])]
    slot=(230,977,676,414)
    def pose(frame,x,y,_,layer):
        if layer in (6,7):
            dy=y+slot[1]-LAYERS[layer]["y"]-OFFSETS[layer][1]
            free_end=smooth(175,321,dy)
            offset=.39 if layer==6 else .68
            phase=TAU*(frame/32-offset)-.74*free_end
            swing=free_end*(np.sin(phase)+.17*np.sin(2*phase))
            return swing*(4.8 if layer==6 else 4.2),swing*(1.5 if layer==6 else -1.2)
        u,v=x+slot[0]-375,y+slot[1]-930
        # The roots between these isolated outer tails retain their exact pose.
        left_mask=1-smooth(91,128,u)
        right_mask=smooth(283,323,u)
        hinge=smooth(125,305,v)
        left_phase=TAU*(frame/32-.08)-.80*hinge
        right_phase=TAU*(frame/32-.33)-.66*hinge
        a=left_mask*hinge*np.sin(left_phase)
        b=right_mask*hinge*(np.sin(right_phase)+.13*np.sin(2*right_phase))
        return a*left[0]+b*right[0],a*left[1]+b*right[1]
    return slot, pose


def vine_track(hide_cheeks=False):
    slot, pose = vine_motion()
    moving=[ROOTS] if hide_cheeks else [ROOTS,6,7]
    return straight_patch(slot,moving,32,125,pose,"vines-idle",hide_cheeks=hide_cheeks)


def fabric_tracks():
    samples=motions_from_video("fabric",[window(93,400,129,433),window(526,392,554,437)],
                               window(130,176,169,209))
    slots=[(144,657,263,218),(732,657,279,218)]
    tracks=[]
    for side,slot in enumerate(slots):
        drift=guide(samples,side)[0]
        vector=model_direction(drift,[(2.0,-4.4),(-1.8,-4.7)][side],.32)

        def pose(frame,x,y,layer,_):
            u,v=x+slot[0]-164,y+slot[1]-150
            # Follow the slope of the worn hem. The purple cloth, print and
            # anchored upper folds stay fixed above this narrow moving band.
            edge = (657-(u-22)*.67) if side==0 else (550+(u-650)*.68)
            fringe=smooth(550,636,v)*(1-smooth(13,42,np.abs(v-edge)))
            motion=TAU*(frame/24+.17*side)-.016*(u-[75,748][side])
            amount=fringe*(.65*np.sin(motion)+.28*np.sin(2*motion-.8))
            rgb=np.asarray(layer,dtype=np.float32)
            purple=smooth(9,40,rgb[:,:,2]-rgb[:,:,1])*(rgb[:,:,3]/255)
            # Widen the motion slightly beyond the silhouette so a curled edge
            # samples the clean original paint on both sides of the hem.
            influence=cv2.GaussianBlur(cv2.dilate(purple,np.ones((13,13),np.uint8)),(0,0),2.3)
            amount*=influence
            return vector[0]*amount,vector[1]*amount
        tracks.append(straight_patch(slot,[FRONT],24,125,pose,["fabric-left","fabric-right"][side]))
    return tracks


def treant_channel_animation():
    slot=(412,769,320,390)
    c=cv2.VideoCapture(str(HERE/"treant.mp4"))
    jaw=[]
    try:
        while (sample:=c.read())[0]:
            patch=sample[1][333:550,190:421]
            dark=np.where(np.max(patch,axis=2)<52)[0]
            if len(dark):
                jaw.append(float(np.percentile(dark,97)))
    finally:
        c.release()
    if len(jaw)<12:
        raise ValueError("Missing mouth motion in the treant reference")
    channel_open=float(np.clip((np.percentile(jaw,85)-jaw[0])*.57,18,27))
    breathing=float(np.clip((np.percentile(jaw,88)-np.percentile(jaw,24))*.24,4,7))

    def pose(frame,x,y,_,layer):
        center=574-slot[0]
        phase=TAU*frame/12
        breath=.5-.5*np.cos(phase)+.10*(1-np.cos(2*phase))
        interior=1-smooth(81,140,np.abs(x-center))
        lower=smooth(159,247,y)*(1-smooth(305,380,y))
        lift=smooth(53,107,y)*(1-smooth(153,218,y))
        scowl=np.exp(-.5*((y-99)/17)**2)*(1-smooth(23,62,np.abs(x-center)))
        open_amount=channel_open+breathing*breath
        spread=np.clip((x-center)/61,-1,1)*np.exp(-.5*((y-203)/34)**2)*3.3
        return spread*interior,interior*(open_amount*lower-4.2*lift+6.3*scowl)

    def eyes(frame,art,x,y):
        data=np.asarray(art,dtype=np.float32)/255
        lobe=np.maximum(np.exp(-.5*(((x-110)/28)**2+((y-120)/22)**2)),
                        np.exp(-.5*(((x-208)/28)**2+((y-120)/22)**2)))
        green=smooth(.095,.40,data[:,:,1]-data[:,:,0])*lobe
        aura=cv2.GaussianBlur(green,(0,0),6.5)
        intensity=.82+.18*(.5+.5*np.sin(TAU*frame/12))
        light=np.array([.23,1.,.08],dtype=np.float32)
        core=np.array([.43,1.,.20],dtype=np.float32)
        data[:,:,:3]=np.clip(data[:,:,:3]+.46*intensity*aura[:,:,None]*light
                             +(core-data[:,:,:3])*.58*intensity*green[:,:,None],0,1)
        return Image.fromarray(np.rint(data*255).astype(np.uint8))
    stats=dict(channelOpeningPx=channel_open,breathingPx=breathing)
    return slot,pose,eyes,stats


def treant_track(hide_cheeks=False):
    slot,pose,eyes,stats=treant_channel_animation()
    (HERE/"treant-motion.json").write_text(json.dumps(stats,indent=2))
    return straight_patch(slot,[FRONT],12,1000/12,pose,"treant-channel",eyes,hide_cheeks=hide_cheeks)


def build():
    if "--hide-cheeks" in sys.argv:
        treant_track(hide_cheeks=True)
        vine_track(hide_cheeks=True)
        return
    tracks=dict(treant=treant_track(),vines=vine_track())
    if "--cheeks" in sys.argv:
        old=json.loads((HERE/"track.js").read_text().split("=",1)[1].strip().rstrip(";"))
        tracks["fabric"]=old["fabric"]
    else:
        tracks["fabric"]=fabric_tracks()
    (HERE/"track.js").write_text("const crestMotionBatch = "+json.dumps(tracks,separators=(",",":"))+";\n")


if __name__=="__main__":
    build()

