"""Compare actual decoded Wan frames to the registered targets."""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw

from guides import MATTE, OUTPUT, cv2


def gray(frames):
    return [cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY) for frame in frames]


def flow(first, current):
    return cv2.calcOpticalFlowFarneback(first, current, None, .55, 4, 23, 6, 7, 1.5, 0)


def measure(job, actual, guide, opening):
    x, y, w, h = job["modelRect"]
    source_width, source_height = job["registered"][2:]
    scale = (w / source_width + h / source_height) / 2
    stem_x = x + job["stem"][0] * w / source_width
    stem_y = y + job["stem"][1] * h / source_height
    yy, xx = np.mgrid[:actual.shape[1], :actual.shape[2]]
    spine = np.asarray(job["direction"])
    normal = np.array([-spine[1], spine[0]])
    along = (xx - stem_x) * spine[0] + (yy - stem_y) * spine[1]
    mask = cv2.erode((opening[:, :, 3] >= 235).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
    anchor = job["rootLength"] * scale
    root = mask & (along < anchor - 4)
    distal = mask & (along > anchor + (along[mask].max() - anchor) * .32)
    opened = guide[0]
    backdrop = np.max(np.abs(guide.astype(np.int16) - np.array(MATTE)), axis=(0, 3)) < 6
    for key, frames in (("guide", guide), ("wan", actual)):
        luminance = gray(frames)
        displacements = [flow(luminance[0], frame) for frame in luminance]
        spread = [item[distal] @ normal / scale for item in displacements]
        motion = [round(float(np.percentile(np.abs(item), 90)), 2) for item in spread]
        drift = [float(np.median(np.linalg.norm(item[root], axis=1))) / scale
                 for item in displacements] if np.any(root) else []
        luma = np.array(luminance, np.float32)
        start = np.mean(luma[0][mask])
        peak = np.mean(luma[:, mask], axis=1)
        yield key, {
            "normalExcursionPx": motion,
            "peakNormalExcursionPx": max(motion),
            "peakFrame": int(np.argmax(motion)),
            "rootDriftPx": round(max(drift), 2) if drift else None,
            "peakLumaChange": round(float(np.max(peak) - start), 2),
            "meanOpeningError": round(float(np.mean(np.abs(frames[0][mask].astype(float) - opened[mask]))), 2),
            "meanSeamError": round(float(np.mean(np.abs(frames[-1][mask].astype(float) - frames[0][mask]))), 2),
            "meanBackdropError": round(float(np.mean(np.abs(frames[:, backdrop].astype(float) - MATTE))), 2),
        }


def inspect(job, trial):
    folder = OUTPUT / job["name"] / job["state"]
    actual_path = folder / f"trial-{trial:02}.npz"
    receipt = actual_path.with_suffix(".json")
    if not receipt.exists() or not actual_path.exists():
        return
    if (folder / f"trial-{trial:02}-metrics.json").exists() and (folder / f"trial-{trial:02}-review.jpg").exists():
        return
    with np.load(actual_path) as data:
        actual = data["rgb"]
    with np.load(folder / "guide.npz") as data:
        guide = data["rgb"]
    opening = np.asarray(Image.open(folder / "pose-00.png"))
    indices = (0, 4, 8, 12, 16, 24, 32)
    board = Image.new("RGB", (len(indices) * 152 + 24, 368), (25, 29, 36))
    label = ImageDraw.Draw(board)
    for row, (name, sequence) in enumerate((("Fresh guide", guide), ("Wan output", actual))):
        top = 14 + row * 178
        label.text((12, top), f"{job['name']} / {job['state']} / {name}", fill=(234, 235, 239))
        for col, frame in enumerate(indices):
            left = 12 + 152 * col
            image = Image.fromarray(sequence[frame]).resize((148, 148), Image.Resampling.LANCZOS)
            board.paste(image, (left, top + 21))
            label.text((left+5, top+27), str(frame), fill=(240, 240, 244))
    board.save(folder / f"trial-{trial:02}-review.jpg", quality=93)
    measurements = dict(measure(job, actual, guide, opening))
    (folder / f"trial-{trial:02}-metrics.json").write_text(
        json.dumps(measurements, indent=2) + "\n", encoding="utf-8")
    print(job["name"], job["state"], *(f"{name}: {data['peakNormalExcursionPx']} px at {data['peakFrame']}"
          for name, data in measurements.items()), flush=True)


if __name__ == "__main__":
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--trial", type=int, default=1)
    args.add_argument("--segment")
    options = args.parse_args()
    cv2.setNumThreads(2)
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    for job in jobs:
        if options.segment in (None, job["name"]):
            inspect(job, options.trial)
