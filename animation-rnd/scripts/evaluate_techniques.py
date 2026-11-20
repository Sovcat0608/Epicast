"""One-pose technique comparison; does not change any animation deliverable."""
import time, statistics
import pipeline as p
import numpy as np
from scipy.interpolate import RBFInterpolator

exp=p.CONFIG['experiments'][2]
prepared=p.prepare(exp); layer=prepared['layers'][0]
pts=layer['points']; tau=10/23
dst=p.displaced(pts,layer['spec'],exp,tau)
timings=[]
for i in range(3):
    start=time.perf_counter()
    p.warp_mesh(layer['texture'],pts,dst,layer['triangles'],exp['crop'])
    timings.append((time.perf_counter()-start)*1000)
x0,y0,x1,y1=exp['crop']; yy,xx=np.mgrid[y0:y1,x0:x1]
query=np.column_stack((xx.ravel(),yy.ravel())).astype(float)
start=time.perf_counter()
inverse=RBFInterpolator(dst,pts,kernel='thin_plate_spline',smoothing=0)
mapping=inverse(query).reshape(y1-y0,x1-x0,2)
tps=p.cv2.remap(layer['texture'],(mapping[...,0]-x0).astype(np.float32),(mapping[...,1]-y0).astype(np.float32),p.cv2.INTER_LINEAR,borderMode=p.cv2.BORDER_CONSTANT)
tps_ms=(time.perf_counter()-start)*1000
landmark_error=float(np.abs(inverse(dst)-pts).max())
result={'scope':'One native-resolution central-leaf pose, same control points and source pixels; not a full visual TPS animation comparison.',
 'piecewise_affine_median_ms':statistics.median(timings),'thin_plate_spline_setup_and_remap_ms':tps_ms,
 'vertices':len(pts),'triangles':len(layer['triangles']),'crop_size':[x1-x0,y1-y0],
 'tps_max_landmark_error_px':landmark_error,
 'decision':'Use explicit triangular meshes: local, inspectable connectivity, simple pinned anchors and per-triangle fold checks. TPS also preserves landmarks but its global support and larger solve/evaluation are not needed for this restrained motion.',
 'not_executed':['Spine/Blender authoring','SAM model inference'],
 'other_assessments':{'skeletal':'Useful control abstraction for many assets; weighted meshes still required for flexing leaves. A rigid transform alone cannot reproduce local bending.',
 'ai_segmentation':'Potential mask starting point, not used. Tiny moss strands and flattened leaf overlaps needed authored constraints and review; no reliable hidden-surface recovery can be inferred from this single image.',
 'reconstruction':'Telea inpainting tested on exposed narrow strips; terminal foliage has an explicit transparent exterior. Hidden artwork remains an estimate.',
 'interpolation':'Deterministic easing, per-strand phase lag and a quintic endpoint window; no temporal optical-flow estimation or per-frame redraw.'}}
p.write_json('reports/technique-benchmark.json',result)
print({k:v for k,v in result.items() if isinstance(v,(int,float))})
