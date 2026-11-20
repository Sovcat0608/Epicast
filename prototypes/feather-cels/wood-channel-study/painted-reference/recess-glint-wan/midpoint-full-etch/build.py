"""Create a pixel-registered full-etch emission reference for the existing wood shards."""
import hashlib
import json
from pathlib import Path
import runpy

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
TRIAL = runpy.run_path(str(HERE.parent / "midpoint/generate.py"))
PREVIEW = next(p for p in HERE.parents if (p / "index.html").is_file())
TRACK = PREVIEW / "wood-channel-study/track.js"
linear = TRIAL["PREVIOUS"]["linear"]
srgb = TRIAL["PREVIOUS"]["srgb"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def etch_coverage(size, contour):
    scale = 4
    sheet = Image.new("L", (size[0] * scale, size[1] * scale))
    ImageDraw.Draw(sheet).polygon([(x * scale, y * scale) for x, y in contour], fill=255)
    return sheet.resize(size, Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(.36))


def cut_relief(coverage):
    """Light the full cut, grading from the far wall to the facing bevel."""
    inside = np.asarray(coverage) > 70
    depth = np.full(inside.shape, .5)
    for x, column in enumerate(inside.T):
        covered = np.flatnonzero(column)
        breaks = np.flatnonzero(np.diff(covered) > 1) + 1
        runs = np.split(covered, breaks)
        for ys in runs:
            if len(ys) > 1:
                depth[ys, x] = np.linspace(.04, .96, len(ys))
    return depth


def reflected_light(source, solar):
    direct = Image.fromarray(np.rint(255 * source * solar).astype(np.uint8))
    soft = direct.filter(ImageFilter.GaussianBlur(1.3))
    offset = Image.new("L", soft.size)
    offset.paste(soft, (0, 1))
    return np.asarray(offset, dtype=np.float64) / 255


def full_etch(unlit, contours):
    rgba = np.asarray(unlit)
    wood = linear(rgba[:, :, :3] / 255)
    original_value = wood @ np.array((.2126, .7152, .0722))
    texture = .84 + .22 * np.clip((np.sqrt(original_value) - .12) / .28, 0, 1)
    addition = np.zeros(wood.shape, dtype=np.float64)
    changed = np.zeros(rgba.shape[:2], dtype=bool)
    for contour in contours:
        coverage = etch_coverage(unlit.size, contour)
        depth = cut_relief(coverage)
        cut = np.asarray(coverage, dtype=np.float64) / 255
        # The inner wall stays shaded. The light rises across the real cut
        # width to a yellow-lime ridge, then turns back into the original wood.
        ridge = np.exp(-.5 * ((depth - .76) / .23)**2)
        interior = .06 + .49 * depth**1.7 + .45 * ridge
        red = .033 + .66 * ridge**1.75 + .08 * depth
        green = .05 + .94 * interior
        blue = .004 + .035 * ridge
        emission = (cut * texture)[:, :, None] * np.stack((red, green, blue), axis=-1)
        bounce = reflected_light(cut, ridge)
        face = np.clip((np.sqrt(original_value) - .115) / .36, .25, 1)
        spill = (bounce * face)[:, :, None] * np.array((.072, .12, .004))
        permitted = ((cut > .025) | (bounce > .027)) & (rgba[:, :, 3] >= 240)
        addition[permitted] += (emission + spill)[permitted]
        changed |= permitted
    result = rgba.copy()
    lit = srgb(np.clip(wood + addition, 0, 1))
    result[changed, :3] = np.rint(lit[changed] * 255).astype(np.uint8)
    assert np.array_equal(result[:, :, 3], rgba[:, :, 3])
    assert np.array_equal(result[~changed], rgba[~changed])
    return Image.fromarray(result), Image.fromarray(255 * changed.astype(np.uint8))


def build():
    track = json.loads(TRACK.read_text(encoding="utf-8").split(" = ", 1)[1].strip().removesuffix(";"))
    peak = Image.new("RGBA", tuple(TRIAL["SIZE"]), "#30363b")
    control = peak.copy()
    entries = []
    for tile, (side, _, video_y, contours) in zip(track["tiles"], TRIAL["SLATS"], strict=True):
        source = PREVIEW / tile["paint"]
        unlit = Image.open(source).convert("RGBA")
        lit, mask = full_etch(unlit, contours)
        output = HERE / f"{side}-midpoint.png"
        lit.save(output)
        mask.save(HERE / f"{side}-etch-and-reflection-mask.png")
        dx, dy, w, h = tile["paintBox"]
        x, y = tile["slot"][:2]
        assert (w, h) == unlit.size
        for plate, sprite in ((control, unlit), (peak, lit)):
            plate.alpha_composite(sprite.resize((w*2,h*2), Image.Resampling.LANCZOS), (27,video_y))
        entries.append(dict(side=side, source=source.relative_to(PREVIEW).as_posix(),
                            source_sha256=digest(source), peak_sha256=digest(output),
                            native_size=[w,h], preview_static_xy=[x+dx,y+dy],
                            preview_hold_xy=[x+dx+tile["travel"],y+dy],
                            video_box=[27,video_y,w*2,h*2], lit_pixels=int(np.count_nonzero(mask))))
    assert control.convert("RGB").tobytes() == Image.open(HERE.parent / "midpoint/opening.png").convert("RGB").tobytes()
    plate = HERE / "midpoint.png"
    peak.convert("RGB").save(plate)
    (HERE / "registration.json").write_text(json.dumps(
        dict(midpoint_sha256=digest(plate), sprites=entries), indent=2
    ) + "\n", encoding="utf-8")


if __name__ == "__main__":
    build()
