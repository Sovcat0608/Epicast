"""Bake a planted Treant roar from the approved carving."""
import json
import sys

import numpy as np
from PIL import Image

from bake_impact import FACE, HERE, MIX, ORIGIN, open_aperture
from bake_batch import axes, remap, smooth, straight_patch
from bake import LAYERS, MASTER
from cheek_placement import registered_stack

sys.path.insert(0, str(MASTER))
from contact_field import contact_field

OUTPUT = HERE / "roar"
SLOT = (374, 769, 396, 454)
ROAR = (.48, 1, 1, .97, .87, .73, .56, .40, .25, .11, .04, 0)
SCOWL = (.63, 1, 1, .97, .92, .79, .62, .46, .27, .12, .04, 0)


def displacement(cel, x, y):
    ox, oy = ORIGIN[0]-SLOT[0], ORIGIN[1]-SLOT[1]
    u, v = x-ox, y-oy
    radius = np.abs(u-140)

    # The brow ridge closes toward the nose. The forehead, pupils, nose,
    # silhouette above the jaw, and surrounding wood are planted.
    brow = (1-smooth(25, 71, radius))*smooth(6, 27, radius)
    brow *= smooth(43, 69, v)*(1-smooth(77, 90, v))
    brow_drop = 15*SCOWL[cel]*brow

    mouth = 1-smooth(49, 108, radius)
    band = smooth(143, 175, v)*(1-smooth(241, 310, v))
    sx = 140+(u-140)/(1+.25*ROAR[cel]*mouth*band)
    top, bottom = open_aperture(sx)
    core = 1-smooth(37, 83, np.abs(sx-140))
    roof = top - ROAR[cel]*(5+5*core)
    jaw = bottom + ROAR[cel]*(19+29*core)
    raised_lip = v+(top-roof)*smooth(147, roof, v)
    aperture = top+(v-roof)*(bottom-top)/np.maximum(1, jaw-roof)
    lowered_ridge = v+(bottom-jaw)*(1-smooth(271, 366, v))
    mapped = np.where(v<roof, raised_lip, np.where(v<jaw, aperture, lowered_ridge))
    sy = v+mouth*(mapped-v)-brow_drop
    return (u-sx).astype(np.float32), (v-sy).astype(np.float32)


def build():
    feather = json.loads((HERE.parent/"impact.js").read_text().split("=",1)[1].strip().rstrip(";"))
    times = [frame["ms"] for frame in feather["clusters"][0]["tracks"][0]["frames"]]
    assert len(times) == len(ROAR) == len(SCOWL) == len(MIX) == 12 and sum(times) == 1000
    OUTPUT.mkdir(exist_ok=True)
    row = LAYERS[FACE]

    def cast(alpha):
        return np.asarray(contact_field(alpha,row["name"],row["x"]-SLOT[0],row["y"]-SLOT[1]),dtype=np.int16)

    paints, _ = registered_stack(SLOT,hide_cheeks=True)
    old_cast = cast(paints[FACE].getchannel("A"))

    def deform(cel, x, y, art, field):
        frame = remap(art,x,y,*displacement(cel,x,y))
        shadow = np.asarray(field,dtype=np.int16)+cast(frame.getchannel("A"))-old_cast
        return frame, Image.fromarray(np.uint8(np.clip(shadow,0,255)))

    tracks = {}
    for label in ("shown","hidden"):
        target = OUTPUT/label
        target.mkdir(exist_ok=True)
        track = straight_patch(SLOT,[FACE],len(times),1000/len(times),None,"roar",hide_cheeks=label=="hidden",
                               output=target,loop=1,deform=deform)
        prefix = target.relative_to(HERE.parent).as_posix()+"/roar"
        tracks[label] = dict(slot=SLOT,columns=4,frames=len(times),frameMs=1000/len(times),
                             period=1000,durations=times,mix=MIX,sheet=prefix+"-scene.webp",
                             coverage=prefix+"-coverage.webp")
        if track:
            assert track["sheet"] == tracks[label]["sheet"]
    (OUTPUT/"track.js").write_text("const treantRoar = "+json.dumps(tracks)+";\n",encoding="utf-8")

    face = Image.new("RGBA", SLOT[2:])
    with Image.open(HERE/"face.png") as art:
        face.paste(art.convert("RGBA"),(ORIGIN[0]-SLOT[0],ORIGIN[1]-SLOT[1]))
    x,y = axes(SLOT)
    w,h = SLOT[2:]
    sheet = Image.new("RGBA",(4*w,3*h))
    for index in range(len(times)):
        dx,dy = displacement(index,x,y)
        stationary = (y<35) | ((y>=98)&(y<148))
        assert not np.any(dx[stationary]) and not np.any(dy[stationary])
        sheet.paste(remap(face,x,y,dx,dy),(index%4*w,index//4*h))
    sheet.save(OUTPUT/"face-cels.webp",lossless=True)


if __name__ == "__main__":
    build()
