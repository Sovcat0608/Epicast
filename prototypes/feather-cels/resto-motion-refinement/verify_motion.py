"""Validate selected Wan provenance, registered loops and review contact textures."""
import json

import numpy as np
from PIL import Image

from motion_guides import OUT, ROOT
from bake_motion_preview import DEST, frames
from review_motion import JOBS


def validate():
    report={}
    for name in JOBS:
        folder=OUT/name
        job,cels=frames(name)
        raw=json.loads((folder/"review.json").read_text(encoding="utf-8"))
        selected=raw["chosen"]
        receipt=json.loads((folder/f"pass-{selected}.json").read_text(encoding="utf-8"))
        from hashlib import sha256
        assert receipt["guideHash"]==sha256((folder/"guide.npz").read_bytes()).hexdigest()
        assert job["sourceHash"]==sha256((ROOT/job["source"]).read_bytes()).hexdigest()
        assert receipt["encodes"]==receipt["masks"]==1
        with np.load(folder/"guide.npz") as files:
            originals=files["native"]
        assert np.array_equal(originals[0],originals[-1]),name
        report[name]={"selectedPass":selected,"frames":job["exportedFrames"],"durationMs":job["duration"]}
        if name=="treant-idle":
            def gap(cel):
                area=np.asarray(cel)[165:220,82:204]
                return int(np.count_nonzero((area[:,:,:3].max(axis=2)<84)&(area[:,:,3]>230)))
            ratio=1-gap(cels[16])/gap(cels[0])
            assert .68 < ratio < .99
            report[name]["visibleMouthAreaReduction"]=round(ratio,3)
        else:
            for cel in cels:
                alpha=np.asarray(cel.getchannel("A"))
                assert not np.any(alpha[[0,-1]]) and not np.any(alpha[:,[0,-1]]),name
                assert np.array_equal(alpha[351:],np.asarray(cels[-1].getchannel("A"))[351:]),name
        if name=="rejuvenation-impact":
            def width(image):
                columns=np.where(np.asarray(image.getchannel("A"))>127)[1]
                return int(columns.max()-columns.min()+1)
            growth=width(cels[1])/width(cels[-1])
            assert 1.27 < growth < 1.33
            report[name]["peakFanWidthScale"]=round(growth,3)
    assert report["rejuvenation-idle"]["durationMs"]/report["rejuvenation-channel"]["durationMs"]==3
    for file in ("leaf-old-coverage.webp","leaf-front-occlusion.webp","leaf-incoming-shadow.webp"):
        assert Image.open(DEST/file).getchannel("A").getextrema()[0]==0
    audit=json.loads((OUT/"hbao-audit.json").read_text(encoding="utf-8"))
    assert audit["jawShadowPeakChange"]>0
    (OUT/"verification.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(report)


if __name__=="__main__":
    validate()
