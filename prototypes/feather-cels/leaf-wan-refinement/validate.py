"""Validate registered leaf review cels without using the installed addon."""
import json

import numpy as np
from PIL import Image

from guides import OUTPUT, ROOT, digest, review_source
from register_preview import IMPACT


def verify():
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    selection = json.loads((OUTPUT / "review-selection.json").read_text(encoding="utf-8"))
    assert len(jobs) == len(selection) == 12
    assert len({row["name"] for row in jobs}) == 6
    report = []
    for job in jobs:
        assert digest(ROOT / job["source"]) == job["source_sha256"]
        name, state = job["name"], job["state"]
        review = selection[f"{name}/{state}"]
        trial = review["trial"]
        assert 1 <= trial <= 5
        job,folder = review_source(job,review)
        run = json.loads((folder / f"trial-{trial:02}.json").read_text(encoding="utf-8"))
        assert run["encodes"] == run["masks"] == 1
        assert run["guideFrames"] == job["keys"]
        assert run["guideSha256"] == digest(folder / "guide.npz")
        with np.load(folder / "guide.npz") as data:
            reference = data["native"]
        w, h = job["registered"][2:]
        sheet = Image.open(folder / "registered-cels.webp")
        assert sheet.mode == "RGBA"
        assert sheet.size == (4*w, ((job["outputFrames"]+3)//4)*h)
        indices = list(range(0, 32, 2)) if state == "channel" else IMPACT
        yy, xx = np.mgrid[:h, :w]
        spine = job["direction"]
        along = (xx-job["stem"][0])*spine[0] + (yy-job["stem"][1])*spine[1]
        lock = along <= job["rootLength"]
        alpha_ratios = []
        fresh_pixels = []
        for slot, index in enumerate(indices):
            x, y = slot % 4 * w, slot // 4 * h
            cel = np.asarray(sheet.crop((x, y, x + w, y + h)))
            alpha = cel[:, :, 3]
            assert not np.any(alpha[[0,-1]]) and not np.any(alpha[:,[0,-1]])
            expected = reference[index]
            visible_lock = lock & ((expected[:,:,3] > 0) | (alpha > 0))
            assert np.array_equal(expected[visible_lock], cel[visible_lock]), f"Stems drifted: {name}/{state}"
            alpha_ratios.append(float(alpha.sum()/expected[:,:,3].sum()))
            fresh_pixels.append(int(np.count_nonzero(np.any(expected != cel, axis=2) &
                                                     (alpha > 220) & ~lock)))
            if index in (0, 32):
                visible = alpha > 0
                assert np.array_equal(cel[visible], expected[visible])
        if state == "channel":
            assert np.array_equal(reference[0], reference[-1])
        assert min(alpha_ratios) >= .87 and max(alpha_ratios) <= 1.16, (name, state, alpha_ratios)
        assert max(fresh_pixels) >= 100, f"No independent Wan paint detail for {name}/{state}"
        measurements = json.loads((folder / f"trial-{trial:02}-metrics.json").read_text(encoding="utf-8"))
        expected = measurements["guide"]["peakNormalExcursionPx"]
        motion = measurements["wan"]["peakNormalExcursionPx"]
        assert abs(motion - expected) <= max(.55, .18*expected), (name, state, motion, expected)
        report.append(dict(segment=name, state=state, passNumber=trial, duration=job["cycle"],
                           registeredFrames=len(indices), exactProtectedRoot=True,
                           noClippedAlpha=True, rawMotionTargetPx=expected, rawMotionMeasuredPx=motion,
                           rawPeakFrame=measurements["wan"]["peakFrame"],
                           alphaCoverageRatio=[round(min(alpha_ratios), 3), round(max(alpha_ratios), 3)]))
    (OUTPUT / "verification.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(f"Verified {len(report)} registered cel sheets, raw motion, fixed stems, clean borders and source hashes.")


if __name__ == "__main__":
    verify()
