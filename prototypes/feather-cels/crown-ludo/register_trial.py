"""Register the generated leaf cels by their stem and preserve the shaded crest stack."""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parent))
from crown import LAYERS, SIZE, TRACKS, leaf_contact, shade, static_shading, stem_anchor


def register(sheet, columns, rows, count, index=8, sweep=(7, 11), region=None):
    spec = json.loads((OUT.parent / "crown/idle.js").read_text().split("=", 1)[1].strip().rstrip(";"))
    track = spec["tracks"][index - 8]
    end = next(end for layer, end, _, _ in TRACKS if layer == index)
    slot = track["slot"]
    pivot = track["pivot"]
    x, y, w, h = slot
    cell_w, cell_h = sheet.width // columns, sheet.height // rows
    assert sheet.size == (columns * cell_w, rows * cell_h)
    assert 0 <= sweep[0] < sweep[1] < count <= columns * rows
    frames = []
    for i in range(count):
        left, top = i % columns * cell_w, i // columns * cell_h
        frames.append(sheet.crop((left, top, left + cell_w, top + cell_h)))
    # One scale across the cycle keeps genuine changes of silhouette intact.
    first = frames[0].getchannel("A").point(lambda a: 255 if a > 96 else 0).getbbox()
    scale = min(LAYERS[index]["w"] / (first[2] - first[0]), LAYERS[index]["h"] / (first[3] - first[1]))
    target = tuple(round(n * scale) for n in frames[0].size)
    light = static_shading(index, slot)
    atlas = Image.new("RGBA", (4 * w, 4 * h))
    shadows = Image.new("RGBA", atlas.size)
    if region is None:
        region = Image.open(OUT.parent / "crown/region.webp").convert("RGBA").getchannel("A")
    review = []
    registered_frames = []
    for i, frame in enumerate(frames):
        art = frame.resize(target, Image.Resampling.LANCZOS)
        px, py = stem_anchor(art, end)
        position = pivot[0] - px, pivot[1] - py
        l, t, r, b = art.getchannel("A").point(lambda a: 255 if a > 32 else 0).getbbox()
        if not (0 <= l + position[0] and r + position[0] <= w and 0 <= t + position[1] and b + position[1] <= h):
            raise ValueError(f"Visible paint extends outside registration tile on cel {i}")
        cel = Image.new("RGBA", (w, h))
        cel.paste(art, position)
        assert stem_anchor(cel, end) == tuple(pivot)
        registered_frames.append(cel.convert("RGBa"))

    # Use one continuous sweep in both directions. Easing matches the approved
    # autumn fan; premultiplied blending keeps the gaps between blades clean.
    start, stop = sweep
    for i in range(16):
        phase = 2 * math.pi * i / 16
        exposure = start + (stop - start) / 2 * (1 - math.cos(phase))
        lower = math.floor(exposure)
        upper = min(lower + 1, stop)
        cel = Image.blend(registered_frames[lower], registered_frames[upper],
                          exposure - lower).convert("RGBA")
        review.append(cel)
        contact = leaf_contact(cel.getchannel("A"))
        at = i % 4 * w, i // 4 * h
        atlas.paste(shade(cel, light), at)
        shadows.paste(contact, at)
        covered = Image.new("L", SIZE)
        covered.paste(ImageChops.lighter(contact.getchannel("A"), cel.getchannel("A")), (x, y))
        region = ImageChops.lighter(region, covered.point(lambda a: 255 if a else 0).filter(ImageFilter.MaxFilter(5)))
    prefix = "" if index == 8 else f"leaf-{index}-"
    atlas.save(OUT / (prefix + "paint.webp"), lossless=True)
    shadows.save(OUT / (prefix + "contact.webp"), lossless=True)
    if index == 8:
        review[0].save(OUT / "idle.webp", save_all=True, append_images=review[1:], duration=125, loop=0, lossless=True)
    return region


def save_region(alpha, name):
    mask = Image.new("RGBA", SIZE)
    mask.putalpha(alpha)
    mask.save(OUT / name, lossless=True)


if __name__ == "__main__":
    if sys.argv[1:] == ["--remaining"]:
        region = Image.open(OUT / "region.webp").convert("RGBA").getchannel("A")
        sweeps = {9: (8, 14), 10: (3, 8), 11: (3, 8), 12: (0, 5), 13: (3, 6)}
        for index, sweep in sweeps.items():
            with Image.open(OUT / f"result/{index}/leaf-{index}-1.png") as sheet:
                region = register(sheet.convert("RGBA"), 4, 4, 16, index, sweep, region)
        save_region(region, "all-region.webp")
    else:
        save_region(register(Image.open(sys.argv[1]).convert("RGBA"), *(int(n) for n in sys.argv[2:])), "region.webp")
