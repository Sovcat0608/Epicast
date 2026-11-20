"""Bake a small, coherent spine bend from the original green fan artwork."""
import json
from pathlib import Path

import numpy as np

from bake_wave import FRAMES, H, LEAF, SLOT, W, bake_poses, registered

OUTPUT = Path(__file__).resolve().parent / "spine-bend"
STEM = (719-SLOT[0],343-SLOT[1])
# The central direction of the fan, from the hidden stem into its long blades.
SPINE = np.array([.61,-.79],dtype=np.float64)
SPINE /= np.linalg.norm(SPINE)
NORMAL = np.array([-SPINE[1],SPINE[0]])
ANCHOR_LENGTH = 57
MAX_CURVATURE = .00017


def inverse_bend(x,y,curvature,stem=STEM,spine=SPINE,anchor_length=ANCHOR_LENGTH):
    """Map the bent fan back to straight material coordinates for sampling.

    A circular centerline preserves its length. Cross sections follow the
    normal to that line and keep their width, so the painted vein and its
    nearby serrations travel together. The attached section stays fixed.
    """
    normal = np.array([-spine[1],spine[0]])
    dx,dy = x-stem[0],y-stem[1]
    along = dx*spine[0]+dy*spine[1]-anchor_length
    across = dx*normal[0]+dy*normal[1]
    if abs(curvature)<1e-10:
        return x.astype("float32"),y.astype("float32")
    projected_tangent = 1-curvature*across
    projected_normal = curvature*along
    radius_ratio = np.hypot(projected_tangent,projected_normal)
    source_along = np.where(along>0,np.arctan2(projected_normal,projected_tangent)/curvature,along)
    # This rational form remains stable as the curvature approaches zero.
    source_across = np.where(
        along>0,(2*across-curvature*(along*along+across*across))/(1+radius_ratio),across,
    )
    d_along,d_across = source_along-along,source_across-across
    mx = x+d_along*spine[0]+d_across*normal[0]
    my = y+d_along*spine[1]+d_across*normal[1]
    return mx.astype("float32"),my.astype("float32")


def build():
    y,x = np.mgrid[:H,:W]
    x,y = x.astype(np.float64),y.astype(np.float64)
    alpha = np.asarray(registered(LEAF,"paint",SLOT).getchannel("A")) >= 192
    # One continuous gust. The smaller second harmonic eases the settle.
    phase=np.arange(FRAMES)*2*np.pi/FRAMES
    gust=.48-.48*np.cos(phase)+.09*np.sin(2*phase)
    curvature=MAX_CURVATURE*gust
    poses=[inverse_bend(x,y,k) for k in curvature]
    bake_poses(poses,OUTPUT)
    transverse=(x-STEM[0])*NORMAL[0]+(y-STEM[1])*NORMAL[1]
    max_strain=float(np.max(np.abs(curvature))*np.max(np.abs(transverse[alpha])))
    movement=np.stack([np.hypot(mx-x,my-y)[alpha] for mx,my in poses])
    peak=np.max(movement,axis=0)
    stats=dict(maximumDisplacementPx=float(peak.max()),displacementP90Px=float(np.percentile(peak,90)),
               maximumLengthChangePercent=100*max_strain,crossSectionWidthChangePercent=0)
    (OUTPUT/"motion.json").write_text(json.dumps(stats,indent=2)+"\n")
    print(json.dumps(stats))


if __name__=="__main__":
    build()

