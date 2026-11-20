"""Make registered Wan key poses for the static-rest Treant cycle."""
import argparse
from pathlib import Path
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path.insert(0,str(PREVIEW/"resto-motion-refinement"))
import motion_guides as references

SOURCE = HERE/"face.png"
APPROVED = references.OUT/"treant-rest-cycle"
OUT = references.OUT/"treant-rigid-jaw"
ORIGIN = (429,777)
CHIN = (101,222,182,340)
STATES = {
    "treant-idle": ([0,8,16,24,32],4000,32),
    "treant-channel": ([0,8,12,16,20,24,28,32],1667,33),
    "treant-impact": ([0,4,8,16,24,32],1000,12),
}


def smoothstep(lo,hi,value):
    return references.ease((value-lo)/(hi-lo))


def jaw_edges(x,jaw):
    x_trace = [77,86,96,107,114,124,139,153,166,174,184,192,200,204]
    roof = np.interp(x,x_trace,[215,198,184,174,170,178,179,178,170,173,181,192,206,216])
    floor = np.interp(x,x_trace,[216,214,209,215,219,211,208,209,213,219,214,208,214,217])
    opening = smoothstep(0,18,x-77)*smoothstep(0,18,204-x)
    travel = chin_translation(jaw)*opening
    # Only the cheeks near the fixed mouth corners ease into the moving jaw.
    # Through the carved chin, every row travels by the same amount.
    travel = np.maximum(travel,-np.maximum(0,floor-roof-2))
    lip = roof-np.maximum(jaw,0)*7*opening
    return roof,floor,lip,floor+travel


def shape(x,y,jaw,scowl):
    radius = np.abs(x-140)
    roof,floor,lip,chin = jaw_edges(x,jaw)
    raise_lip = y+(roof-lip)*smoothstep(154,lip,y)
    cavity = roof+(y-lip)*(floor-roof)/np.maximum(1,chin-lip)
    lower_jaw = y+floor-chin
    mouth_y = np.where(y<lip,raise_lip,np.where(y<chin,cavity,lower_jaw))
    # Use the same x coordinate for all points, including the mouth corners.
    mouth_y = np.where((x>77)&(x<204),mouth_y,y)

    # Follow each carved brow from the temple to the nose. Drag its full
    # lower border over the eye. Below that border, retain the fixed pupil.
    brow_edge = np.interp(x,[28,48,70,90,108,128,140,152,173,194,214,235,254],
                            [69,74,82,91,96,90,86,90,96,90,82,74,69])
    brow_span = smoothstep(4,27,radius)*(1-smoothstep(84,117,radius))
    drop = 13.4*scowl*brow_span
    upper_brow = smoothstep(34,brow_edge-6,y)
    lower_brow = 1-smoothstep(brow_edge+drop-.8,brow_edge+drop+1.3,y)
    return (mouth_y-drop*upper_brow*lower_brow).astype(np.float32)


def guide_inputs(name,index):
    t = index/(references.COUNT-1)
    e = references.ease
    if name == "treant-idle":
        jaw = .18*np.sin(np.pi*min(t/.41,1))**2
        jaw -= .97*e((t-.27)/.25)*(1-e((t-.54)/.46))
        return jaw,0,0
    if name == "treant-channel":
        if index<8:
            power = e(index/8)
            return .58*power,.98*power,.33*power
        if index<=24:
            breath = np.sin(2*np.pi*(index-8)/16)
            return .58+.19*breath,.98,.33+.055*breath
        power = 1-e((index-24)/8)
        return .58*power,.98*power,.33*power
    strike = np.interp(index,[0,3,4,7,12,17,22,26,32],[0,.80,1,1,.84,.57,.28,.095,0])
    return strike,strike,0


def paint(src,x,y,name,index):
    jaw,frown,glow = guide_inputs(name,index)
    if index in (0,32):
        return src.copy()
    if name=="treant-channel" and index in (16,24):
        return paint(src,x,y,name,8)
    art = references.remap(src,x,shape(x,y,jaw,frown))
    if glow:
        pixels = np.array(art)
        r,g,b,a = np.moveaxis(pixels.astype(np.float32),2,0)
        saturation = np.clip((g-np.maximum(r,b)-16)/59,0,1)
        pupil = saturation*smoothstep(87,96,y)*(1-smoothstep(113,124,y))
        power = pupil*glow
        pixels[:,:,0] = np.uint8(np.rint(r+(185-r)*power*.35))
        pixels[:,:,1] = np.uint8(np.rint(g+(255-g)*power))
        pixels[:,:,2] = np.uint8(np.rint(b+(87-b)*power*.42))
        art = Image.fromarray(pixels)
    return art


def chin_translation(jaw):
    return round(jaw*(46 if jaw>=0 else 27))


def guides():
    references.OUT = OUT
    with Image.open(SOURCE) as opened:
        # Reserve space below the jaw. The stored rest paint keeps the
        # original origin and is copied without scaling into the larger cel.
        src = Image.new("RGBA",(opened.width,opened.height+54))
        src.paste(opened.convert("RGBA"))
    y,x = np.mgrid[:src.height,:src.width].astype(np.float32)
    for name,(keys,duration,count) in STATES.items():
        frames = [paint(src,x,y,name,i) for i in range(references.COUNT)]
        references.save_job(name,SOURCE,frames,[*ORIGIN,*src.size],keys,duration,count)
        folder = OUT/name
        assert (folder/"wan-anchor-00.png").read_bytes()==(folder/"wan-anchor-32.png").read_bytes()
        assert all(frame.getbbox()[3] <= frame.height-8 for frame in frames)


def render(passes):
    import render_motion as engine
    engine.OUT=OUT
    engine.PROMPTS={
        "treant-idle": ("Quiet inhale and close to a narrow slit during exhale, then gently reopen into the exact "
                        "rest position. All motion is vertical in the hinged jaw. The brow and head stay still."),
        "treant-channel": ("The full left and right brows aggressively lower over half of the green eyes. "
                           "The jaw drops straight down, with the mouth corners fixed at the same x coordinates. "
                           "During the center beats, breathe rapidly in the open shape and brighten the remaining "
                           "green slits. Then the jaw eases upwards and the full brows lift back to the exact supplied rest."),
        "treant-impact": ("An aggressive planted roar. The jaw drops sharply straight down, with identical mouth "
                          "width and fixed mouth corner x positions. Both full brows descend over the eyes until "
                          "half closed, then release with the jaw to the identical static reference at the final key."),
    }
    engine.LOCK = (" Keep the static face at start and end. Front-facing exact original painted wood, head remains "
                   "planted and upright. The whole lower carved chin, its teeth, bevels and pointed end are one "
                   "rigid piece moving vertically together. No stretching, shrinking, or reshaping the chin grain. "
                   "Keep the same brow, mouth width, and fixed mouth corners.")
    sys.argv = [sys.argv[0],*STATES,"--passes",*map(str,passes)]
    engine.main()


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action",choices=("guides","render"))
    parser.add_argument("--passes",nargs="+",type=int,default=[2])
    args=parser.parse_args()
    if args.action=="guides":
        guides()
    else:
        render(args.passes)
