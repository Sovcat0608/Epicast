"""Compare the current addon's fixed crown cast with the approved moved cels."""
import json
import sys

import numpy as np
from PIL import Image

from motion_guides import OUT, PREVIEW, ROOT
sys.path.insert(0,str(PREVIEW))
from cheek_placement import registered_stack
from crown import leaf_contact

AUDIT_SLOT = (0,0,1125,624)
SOURCE = ROOT/"artifacts/restoration-leaf-wan-refinement"


def compare():
    spec = json.loads((SOURCE/"manifest.json").read_text(encoding="utf-8"))
    paints,fields = registered_stack(AUDIT_SLOT,hide_cheeks=True)
    result={}
    for state,cel in (("channel",8),("impact",1)):
        receiver = np.asarray(paints[2].getchannel("A"),dtype=np.float32)/255
        original=np.ones_like(receiver)
        posed=np.ones_like(receiver)
        visible=np.ones_like(receiver)
        for job in (row for row in spec if row["state"]==state):
            x,y,w,h=job["registered"]
            rect=((cel%4)*w,(cel//4)*h,(cel%4+1)*w,(cel//4+1)*h)
            sheet=SOURCE/job["name"]/state/"registered-cels.webp"
            with Image.open(sheet) as atlas:
                full=Image.new("L",AUDIT_SLOT[2:])
                full.paste(atlas.crop(rect).getchannel("A"),(x,y))
            visible *= 1-np.asarray(full,dtype=np.float32)/255
            shadow=leaf_contact(full).getchannel("A")
            original *= 1-np.asarray(fields[job["index"]],dtype=np.float32)/255
            posed *= 1-np.asarray(shadow,dtype=np.float32)/255
        for i in range(14,len(paints)):
            visible *= 1-np.asarray(paints[i].getchannel("A"),dtype=np.float32)/255
        difference = np.abs(original-posed)*receiver*visible
        result[state]=dict(representativeCel=cel+1, maxVisibleOpacityDelta=round(float(difference.max()),4),
                           pixelsWithOver5PercentDelta=int(np.count_nonzero(difference>.05)),
                           approximatePixelsAt162px=int(np.count_nonzero(difference>.05)*(162/1125)**2))
    (OUT/"installed-crown-contact-audit.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(result)


if __name__=="__main__":
    compare()
