"""Use local light on the original crest paint and isolate one slat pair for Wan."""
import hashlib
import json
from pathlib import Path
import runpy

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
OLD = runpy.run_path(str(HERE.parent / "original-crest-wan/prepare.py"))
CREST, SLATS, linear, srgb = (OLD[key] for key in ("CREST", "SLATS", "linear", "srgb"))
SIZE = (960, 448)
VIDEO_XY = (25, 22)
VIDEO_SCALE = 2.8
PATHS = (
    (
        ((131,43),(139,45),(150,43),(157,47),(167,53),(176,49),(186,55),
         (195,49),(207,52),(218,53),(229,55),(236,54)),
        ((177,126),(189,115),(194,108),(190,103),(198,106),(207,105),
         (216,105),(211,111),(200,116),(184,126)),
    ),
    (
        ((91,66),(104,58),(116,59),(128,57),(144,53),(151,58),(161,54),
         (171,45),(186,55),(196,51),(217,49)),
        ((79,113),(96,110),(113,102),(106,109),(121,106),(133,100),
         (127,109),(120,111),(130,115),(136,119)),
    ),
)
SETTINGS = {
    "model": "wan2.2-ti2v-5b-native", "size": f"{SIZE[0]}x{SIZE[1]}", "fps": 16,
    "num_frames": 49, "steps": 36, "guidance": 6.5, "seed": 509429,
}
SCENE = ("Locked close-up of the exact stationary carved wood in the first image. "
         "Two dark zigzag incisions with pin-thin pale mint specular highlights. ")
PROMPTS = {
    "wan-travel": SCENE + ("In both incisions a pinpoint pale highlight visibly sweeps from "
        "left to right, tracing the bends like a passing reflection on a cut edge. "
        "It reaches the right end and vanishes. Only the two highlights move."),
    "wan-still": SCENE + ("The two small highlights remain stationary in their starting "
        "positions for the entire clip. The scene is a still photograph."),
}
NEGATIVE = ("warping, camera motion, new shape, extra cuts, green liquid, colored coating, "
            "solid green fill, glowing wood grain, sparks, fog, defocus")


def coverage(size, contour, path):
    width, height = size
    scale = 4
    bounds = Image.new("L", (width * scale, height * scale))
    ImageDraw.Draw(bounds).polygon([(x * scale, y * scale) for x, y in contour], fill=255)
    curve = Image.new("L", bounds.size)
    ImageDraw.Draw(curve).line([(x * scale, y * scale) for x, y in path],
                               fill=255, width=4, joint="curve")
    cut = np.asarray(bounds.resize(size, Image.Resampling.LANCZOS), dtype=np.float32) / 255
    line = np.asarray(curve.resize(size, Image.Resampling.LANCZOS), dtype=np.float32) / 255
    return cut, line


def measure_line(width, height, path):
    yy, xx = np.mgrid[:height, :width]
    segments = np.diff(path, axis=0)
    lengths = np.linalg.norm(segments, axis=1)
    distance = np.full((height, width), np.inf)
    progress = np.zeros_like(distance)
    for (x, y), (dx, dy), length, walked in zip(
            path, segments, lengths, np.r_[0, np.cumsum(lengths)[:-1]]):
        t = np.clip(((xx - x) * dx + (yy - y) * dy) / length**2, 0, 1)
        sample = (xx - x - dx*t)**2 + (yy - y - dy*t)**2
        near = sample < distance
        distance[near] = sample[near]
        progress[near] = (walked + t[near] * length) / lengths.sum()
    return progress


def paint_lights(paint, contours, paths, input_pose):
    base = np.asarray(paint)
    rgb = linear(base[:, :, :3] / 255)
    additions = np.zeros_like(rgb)
    mask = np.zeros(base.shape[:2], dtype=bool)
    for contour, path in zip(contours, paths):
        cut, line = coverage(paint.size, contour, path)
        t = measure_line(*paint.size, path)
        fine = (.40 + .6 * (np.sin(np.pi*t)**.7))
        if input_pose:
            # A small visible cue for Wan's description of the first frame.
            fine = .25 + 1.6 * np.exp(-.5 * ((t - .19) / .075)**2)
        glow = Image.fromarray(np.rint(line * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
        bounce = (np.asarray(glow, dtype=np.float32) / 255) * (.15 + .85*cut)
        emission = np.clip(.64*cut + .06, 0, 1) * line * fine
        local = ((emission > .006) | (bounce > .018)) & (base[:, :, 3] > 220)
        mint = emission[:, :, None] * np.array((.24, .38, .19))
        reflected = (bounce * fine)[:, :, None] * np.array((.013, .034, .010))
        additions[local] += (mint + reflected)[local]
        mask |= local
    result = base.copy()
    value = srgb(np.clip(rgb + additions, 0, 1))
    result[mask, :3] = np.rint(value[mask] * 255).astype(np.uint8)
    assert np.array_equal(result[:, :, 3], base[:, :, 3])
    assert np.array_equal(result[~mask], base[~mask])
    return Image.fromarray(result), Image.fromarray(mask.astype(np.uint8) * 255)


def video_plate(paint):
    plate = Image.new("RGBA", SIZE, "#30363b")
    fit = tuple(round(edge * VIDEO_SCALE) for edge in paint.size)
    plate.alpha_composite(paint.resize(fit, Image.Resampling.LANCZOS), VIDEO_XY)
    return plate.convert("RGB")


def prepare():
    registration = json.loads((CREST / "registration.json").read_text(encoding="utf-8"))
    manifest = []
    for (side, index, _, contours), paths in zip(SLATS, PATHS):
        source = CREST / "registered" / f"{index:02}-paint.png"
        paint = Image.open(source).convert("RGBA")
        place = registration[index]
        assert paint.size == (place["w"], place["h"])
        result, mask = paint_lights(paint, contours, paths, input_pose=False)
        result.save(HERE / f"{side}-glint.png")
        mask.save(HERE / f"{side}-glint-mask.png")
        if side == "left":
            cue, _ = paint_lights(paint, contours, paths, input_pose=True)
            video_plate(cue).save(HERE / "left-input.png")
            video_plate(paint).save(HERE / "left-clean.png")
        manifest.append(dict(side=side, source=source.name,
                             sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                             box=[place[k] for k in ("x", "y", "w", "h")],
                             mask_pixels=int(np.count_nonzero(np.asarray(mask)))))
    (HERE / "reference.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    prepare()
