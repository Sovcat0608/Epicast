"""Check whether the raw Wan clip preserved the registered shard paintings."""
from pathlib import Path
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

from prepare import CREST, HERE, PROJECT, SLATS

sys.path.insert(0, str(PROJECT / "animation-rnd/.deps"))
import cv2


def green(rgb):
    return rgb[:, :, 1] - .65 * rgb[:, :, 0] - .35 * rgb[:, :, 2]


def edges(rgb, keep):
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    return cv2.Laplacian(gray, cv2.CV_32F) * keep


def regions():
    outside = np.zeros((704, 704), dtype=bool)
    contours = []
    for side, index, y, designs in SLATS:
        x = 27
        alpha = Image.open(CREST / "registered" / f"{index:02}-paint.png").getchannel("A")
        exact_mask = Image.open(HERE / f"{side}-light-mask.png")
        size = (alpha.width * 2, alpha.height * 2)
        solid = np.asarray(alpha.resize(size, Image.Resampling.NEAREST)) > 250
        light = np.asarray(exact_mask.resize(size, Image.Resampling.NEAREST)) > 0
        outside[y:y+size[1], x:x+size[0]] = solid & ~light
        for number, design in enumerate(designs, 1):
            mask = Image.new("L", outside.shape[::-1])
            ImageDraw.Draw(mask).polygon([(x + 2 * px, y + 2 * py) for px, py in design], fill=255)
            core = cv2.erode(np.asarray(mask), np.ones((5, 5), dtype=np.uint8)) > 0
            contours.append((f"{side}-{number}", core))
    return outside, contours


def evaluate(name):
    video = cv2.VideoCapture(str(HERE / f"{name}.mp4"))
    if not video.isOpened():
        raise RuntimeError("Wan video could not be opened")
    fps = video.get(cv2.CAP_PROP_FPS)
    frames = []
    while True:
        ok, frame = video.read()
        if not ok:
            break
        frames.append(frame[:, :, ::-1].copy())
    video.release()
    assert len(frames) == 65
    outside, masks = regions()
    anchor = frames[0].astype(np.float32) / 255
    neutral = green(anchor)
    values = {name: [] for name, _ in masks}
    off_mask_diff = []
    off_mask_green = []
    movement = []
    anchor_edges = edges(anchor, outside)
    window = cv2.createHanningWindow(outside.shape[::-1], cv2.CV_32F)
    for frame in frames:
        rgb = frame.astype(np.float32) / 255
        excess = green(rgb)
        for name, mask in masks:
            values[name].append(round(float(excess[mask].mean()), 4))
        off_mask_diff.append(round(float(np.abs(rgb[outside] - anchor[outside]).mean()), 4))
        off_mask_green.append(round(float(((excess - neutral)[outside] > .09).mean()), 5))
        shift, _ = cv2.phaseCorrelate(anchor_edges.copy(), edges(rgb, outside), window)
        movement.append(round(float(np.hypot(*shift)), 4))
    summary = {
        name: dict(open=seq[0], peak=max(seq), peak_seconds=seq.index(max(seq)) / fps, end=seq[-1])
        for name, seq in values.items()
    }
    data = dict(fps=fps, frames=len(frames), contours=summary,
                worst_off_mask_rgb_change=max(off_mask_diff),
                worst_off_mask_green_spread=max(off_mask_green),
                max_global_shift_video_pixels=max(movement),
                per_frame_green=values)
    (HERE / f"{name}-quality.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    samples = (0, 12, 24, 40, 52, 64)
    sheet = Image.new("RGB", (3 * 352, 2 * (352 + 30)), "#1B2226")
    draw = ImageDraw.Draw(sheet)
    for column, i in enumerate(samples):
        x, y = column % 3 * 352, column // 3 * 382
        sheet.paste(Image.fromarray(frames[i]).resize((352, 352), Image.Resampling.LANCZOS), (x, y + 30))
        draw.text((x + 12, y + 8), f"{i / fps:.2f} s", fill="#ecf0e8")
    sheet.save(HERE / f"{name}-samples.png")
    print(json.dumps({key: val for key, val in data.items() if key != "per_frame_green"}, indent=2))


if __name__ == "__main__":
    evaluate(sys.argv[1] if len(sys.argv) > 1 else "wan")

