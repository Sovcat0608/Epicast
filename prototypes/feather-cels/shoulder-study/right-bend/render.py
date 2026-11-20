"""Fit the Wan motion to a single shallow, shape-preserving arc."""
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parents[1]
sys.path[:0] = [str(PREVIEW), str(PREVIEW/"right-crown-study")]
from bake_spine_bend import inverse_bend
from bake_wave import FRAME_MS, FRAMES, cv2, remap
import numpy as np
from PIL import Image

STEM = (64,55)
SPINE = np.array([.67,.74], dtype=np.float64)
SPINE /= np.linalg.norm(SPINE)
ANCHOR = 31


def model_bow(rest, video=None, crop=(2,0,606,608), stem=STEM, spine=SPINE, anchor=ANCHOR):
    width,height=rest.size
    grid_y,grid_x=np.mgrid[:height,:width]
    dx,dy=grid_x-stem[0],grid_y-stem[1]
    normal=np.array([-spine[1],spine[0]])
    along=dx*spine[0]+dy*spine[1]-anchor
    across=dx*normal[0]+dy*normal[1]
    opaque=np.asarray(rest.getchannel("A"))>224
    fit=opaque&(along>18)&(abs(across)<112)
    # Jointly fit rotation and curvature. Only the curved term drives the
    # painted frames. High-frequency displacement stays in the guide video.
    radius=along[fit].astype(np.float64)
    design=np.column_stack((np.ones_like(radius),radius,radius**2/2))
    player=cv2.VideoCapture(str(video or HERE/"wan.mp4"))
    left,top,right,bottom=crop
    solver=cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    measurements=[]
    ref=None
    try:
        while (sample:=player.read())[0]:
            image=cv2.cvtColor(sample[1],cv2.COLOR_BGR2GRAY)
            gray=cv2.resize(image[top:bottom,left:right],(width,height),interpolation=cv2.INTER_AREA)
            if ref is None:
                ref=gray
            flow=solver.calc(ref,gray,None)
            normal_motion=flow[fit,0]*normal[0]+flow[fit,1]*normal[1]
            fit_values, *_ = np.linalg.lstsq(design,normal_motion,rcond=None)
            measurements.append(float(fit_values[2]))
    finally:
        player.release()
    if len(measurements)<16:
        raise ValueError("Wan did not return a complete motion reference")
    broad=cv2.GaussianBlur(np.asarray(measurements,np.float64)[:,None],(1,9),1.8).ravel()
    peak=int(np.argmax(np.abs(broad)))
    return peak,float(broad[peak]),float(along[opaque].max())


def build():
    leaf=Image.open(HERE/"rest.png").convert("RGBA")
    w,h=leaf.size
    y,x=np.mgrid[:h,:w].astype(np.float64)
    peak_frame,estimated,free_length=model_bow(leaf)
    # Set a narrow travel range suitable for an idle. The clip guides
    # direction and peak timing but the original art drives every pixel.
    tip_travel=float(np.clip(abs(estimated)*free_length**2/2,6.6,8.2))
    curvature=float(np.copysign(2*tip_travel/(free_length**2),estimated))
    peak_time=float(np.clip(peak_frame/48,.39,.59))
    phase=np.arange(FRAMES)/FRAMES
    stage=np.interp(phase,[0,peak_time,1],[0,np.pi,2*np.pi])
    gust=(1-np.cos(stage))*.5
    atlas=Image.new("RGBA",(4*w,4*h))
    for cel,strength in enumerate(gust):
        mx,my=inverse_bend(x,y,curvature*strength,STEM,SPINE,ANCHOR)
        atlas.paste(remap(leaf,mx,my),(cel%4*w,cel//4*h))
    atlas.save(HERE/"quiet.webp",lossless=True)
    recipe=dict(layer=11,sheet="quiet.webp",columns=4,rows=4,registeredSize=True,registeredPivot=True,
                variable="rightShoulderStudy",frames=list(range(FRAMES)))
    (HERE/"exposures.json").write_text(json.dumps(recipe,indent=2)+"\n")
    stats=dict(sourcePeakFrame=peak_frame,fittedCurvature=estimated,curvature=curvature,
               tipTravelPx=tip_travel,frames=FRAMES,frameMs=FRAME_MS)
    (HERE/"motion.json").write_text(json.dumps(stats,indent=2)+"\n")
    print(json.dumps(stats))


if __name__=="__main__":
    build()

