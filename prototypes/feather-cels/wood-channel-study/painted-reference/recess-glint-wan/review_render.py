"""Measure how far the green glint travels in two otherwise identical Wan renders."""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from prepare import HERE, OLD, PATHS, SIZE, VIDEO_SCALE, VIDEO_XY, coverage

sys.path.insert(0, str(OLD["PROJECT"] / "animation-rnd/.deps"))
import cv2


def green(rgb):
    red, green, blue = np.moveaxis(rgb, 2, 0)
    return green - .65*red - .35*blue


def prepare_masks(clean):
    region_masks = []
    for contour, path in zip(OLD["SLATS"][0][3], PATHS[0]):
        cut, _ = coverage((325, 144), contour, path)
        region = Image.fromarray(np.rint(cut * 255).astype(np.uint8))
        region = region.filter(ImageFilter.MaxFilter(5))
        size = tuple(round(n * VIDEO_SCALE) for n in region.size)
        plate = Image.new("L", SIZE)
        plate.paste(region.resize(size, Image.Resampling.BILINEAR), VIDEO_XY)
        region_masks.append(np.asarray(plate) > 124)
    occupied = np.any(clean != clean[0,0], axis=2)
    wood = occupied & ~np.logical_or.reduce(region_masks)
    return region_masks, wood


def measure_clip(name, original, masks, wood):
    reader = cv2.VideoCapture(str(HERE / (name + ".mp4")))
    fps = reader.get(cv2.CAP_PROP_FPS)
    frames = []
    xs = np.arange(SIZE[0])[None, :]
    clean_chroma = green(original)
    samples = []
    while True:
        read, frame = reader.read()
        if not read:
            break
        frames.append(frame[:, :, ::-1].copy())
        rgb = frames[-1].astype(np.float32) / 255
        chroma = green(rgb) - clean_chroma
        signal = np.maximum(0, chroma - .035)
        zones = []
        for roi in masks:
            weight = signal * roi
            mass = float(weight.sum())
            center = float((weight * xs).sum() / max(mass, 1e-6))
            zones.append([round(center, 1), round(mass, 2)])
        samples.append(zones)
    reader.release()
    assert len(frames) == 49 and fps == 16
    opening = frames[0][wood].astype(np.float32) / 255
    drift = max(float(np.abs(frame[wood] / 255 - opening).mean()) for frame in frames)
    by_etch = np.asarray(samples).transpose(1, 0, 2)
    return frames, dict(frames=49, fps=fps, worst_off_mask_rgb_change=round(drift, 4),
        glints=[dict(start_x=float(zone[0, 0]), low_x=float(zone[:, 0].min()),
                     high_x=float(zone[:, 0].max()), end_x=float(zone[-1, 0]),
                     strength_start=float(zone[0, 1]), strength_end=float(zone[-1, 1]),
                     positions_and_strength=zone.tolist()) for zone in by_etch])


def compare():
    clean = np.asarray(Image.open(HERE / "left-clean.png")).astype(np.float32) / 255
    masks, wood = prepare_masks(clean)
    output = Image.new("RGB", (1200, 440), "#212729")
    label = ImageDraw.Draw(output)
    points = (0, 12, 24, 36, 48)
    results = {}
    for row, (name, title) in enumerate((("wan-travel", "Travel prompt"), ("wan-still", "Still prompt"))):
        frames, result = measure_clip(name, clean, masks, wood)
        results[name] = result
        label.text((9, 7 + row * 220), title, fill="white")
        for column, frame_id in enumerate(points):
            x, y = column * 240, row * 220
            region = Image.fromarray(frames[frame_id]).crop((355, 118, 730, 389))
            output.paste(region.resize((238, 176), Image.Resampling.LANCZOS), (x, y + 24))
            label.text((x + 8, y + 202), f"{frame_id / 16:.2f} s", fill="white")
    output.save(HERE / "wan-comparison.png")
    (HERE / "wan-comparison.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    for name, result in results.items():
        for zone in result["glints"]:
            del zone["positions_and_strength"]
        print(name, json.dumps(result))


if __name__ == "__main__":
    compare()
