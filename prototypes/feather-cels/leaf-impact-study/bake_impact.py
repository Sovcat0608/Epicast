"""Bake the six leaf Impact tracks and their registered preview composite."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path[:0] = [str(PREVIEW), str(PREVIEW / "leaf-channel-study")]
from bake_glow import TINTS, emission, leaf_sources
from bake_inner import config, crop_tile, inverse_bend, remap
from cheek_placement import composite, premult, registered_stack
from crown import leaf_contact

SLOT = (0, 0, 1125, 592)
COLUMNS = 4
# Strike in the first drawing and reach full curl in the second (~83 ms).
CURL = (.61, 1, .97, .90, .79, .65, .51, .37, .24, .13, .05, 0)
FLASH = (.58, 1.25, .82, .48, .24, .09, .03, 0, 0, 0, 0, 0)
MIX = (1, 1, 1, 1, 1, 1, 1, .97, .80, .54, .23, 0)

# Direction down each fan's spine, the fixed stem length, and signed tip travel.
# The signed bend opens the existing C-shaped curl, back against its sweep.
FANS = {
    8: ((-.56, -.83), 100, 9),
    9: ((.61, -.79), 57, -15),
    10: ((-.73, .68), 72, -7),
    11: ((.67, .74), 34, 12),
    12: ((.72, .69), 23, -8),
    13: ((-.72, .69), 23, 8),
}
# These painted idle tracks sit differently from their static registrations.
USE_IDLE_PAINT = (8, 10)


def changed(before, after):
    return np.any(np.abs(before - after) > 1.5 / 255, axis=2)


def with_emission(paint, index, strength):
    if not strength:
        return paint
    alpha = paint.getchannel("A")
    visible = np.ones((paint.height, paint.width), dtype=np.float32)
    light = emission(paint, visible, 0, index, pulse=strength)
    lit = Image.composite(light.convert("RGB"), paint.convert("RGB"), light.getchannel("A"))
    lit.putalpha(alpha)
    return lit


def sheets(slot, count):
    w, h = slot[2:]
    return Image.new("RGBA", (w * COLUMNS, h * ((count + COLUMNS - 1) // COLUMNS)))


def place(atlas, tile, frame):
    atlas.paste(tile, (frame % COLUMNS * tile.width, frame // COLUMNS * tile.height))


def representative_idle_pose(frames):
    alphas = np.stack([np.asarray(frame.getchannel("A"), dtype=np.float32) for frame in frames])
    median = np.median(alphas, axis=0)
    distance = np.abs(alphas - median).sum(axis=(1, 2))
    return frames[int(distance.argmin())]


def fan_cels(index, track, paint, field, field_grid):
    x, y, w, h = slot = track["slot"]
    pivot = tuple(track["pivot"])
    direction, anchor, travel = FANS[index]
    spine = np.array(direction, dtype=np.float64)
    spine /= np.linalg.norm(spine)
    sy, sx = np.mgrid[:h, :w].astype(np.float64)
    full_y, full_x = field_grid
    source = crop_tile(paint, SLOT, slot)
    ys, xs = np.where(np.asarray(source.getchannel("A")) > 128)
    span = ((xs - pivot[0]) * spine[0] + (ys - pivot[1]) * spine[1]).max() - anchor
    curvature = 2 * travel / span**2
    assert abs(curvature) * span < .16
    atlas = sheets(slot, len(CURL))
    for frame, (curl, flash) in enumerate(zip(CURL, FLASH)):
        # Treat each loaded painting as a continuous blade, keeping the hidden
        # stem fixed and carrying the existing veins with the cross section.
        mx, my = inverse_bend(sx, sy, curl * curvature, pivot, spine, anchor)
        cel = with_emission(remap(source, mx, my), index, flash)
        assert cel.getbbox() and min(cel.getbbox()[:2]) > 0
        assert cel.getbbox()[2] < w and cel.getbbox()[3] < h
        place(atlas, cel, frame)
        # Remap in the full patch so the soft contact field has room to fall off.
        fx, fy = inverse_bend(full_x, full_y, curl * curvature, (x + pivot[0], y + pivot[1]), spine, anchor)
        yield crop_tile(cel, slot, SLOT), remap(field, fx, fy)
    atlas.save(HERE / f"{index:02}.webp", lossless=True)
    print(track["name"], f"{abs(travel)} px nominal tip excursion", flush=True)


def build():
    feather = config("impact.js")
    durations = [frame["ms"] for frame in feather["clusters"][0]["tracks"][0]["frames"]]
    assert len(durations) == len(CURL) == len(FLASH) == len(MIX) == feather["fps"] == 12
    assert sum(durations) == 1000 and set(FANS) == set(TINTS)
    idle_sources = leaf_sources()
    source_tracks = config("crown/idle.js")["tracks"]
    paints, fields = registered_stack(SLOT, hide_cheeks=True)
    # The live preview draws animated feathers behind this region.
    for i in (0, 1):
        paints[i] = Image.new("RGBA", SLOT[2:])
    baseline = premult(composite(paints, fields, SLOT))
    support = np.zeros((SLOT[3], SLOT[2]), dtype=bool)
    for index, (origin, frames) in idle_sources.items():
        crest_alpha = paints[index].getchannel("A")
        for cel in frames:
            idle_alpha = crop_tile(cel, origin, SLOT).getchannel("A")
            support |= np.abs(np.asarray(idle_alpha, dtype=np.int16) - np.asarray(crest_alpha)) > 3

    for index in USE_IDLE_PAINT:
        origin, frames = idle_sources[index]
        paint = representative_idle_pose(frames)
        paints[index] = crop_tile(paint, origin, SLOT)
        fields[index] = leaf_contact(paints[index].getchannel("A")).getchannel("A")

    field_grid = np.mgrid[:SLOT[3], :SLOT[2]].astype(np.float64)
    segments = [
        fan_cels(i, source_tracks[i - 8], paints[i], fields[i], field_grid)
        for i in FANS
    ]
    cels = []
    for _ in CURL:
        moving_paints, moving_fields = paints.copy(), fields.copy()
        for index, track in zip(FANS, segments):
            moving_paints[index], moving_fields[index] = next(track)
        scene = composite(moving_paints, moving_fields, SLOT)
        support |= changed(baseline, premult(scene))
        cels.append(scene)
    # Finish each segment generator so it writes its separately reusable atlas.
    for track in segments:
        assert next(track, None) is None

    mask = Image.fromarray(support.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(11))
    coverage = Image.new("RGBA", mask.size)
    coverage.putalpha(mask)
    coverage.save(HERE / "coverage.webp", lossless=True)
    atlas = sheets(SLOT, len(cels))
    empty = Image.new("RGBA", mask.size)
    for frame, cel in enumerate(cels):
        place(atlas, Image.composite(cel, empty, mask), frame)
    atlas.save(HERE / "scene.webp", lossless=True)

    folder = HERE.name
    track = dict(slot=SLOT, columns=COLUMNS, frames=len(cels), fps=feather["fps"], period=sum(durations),
                 durations=durations, mix=MIX, redrawFeathers=True,
                 sheet=f"{folder}/scene.webp", coverage=f"{folder}/coverage.webp",
                 segments=[dict(layer=i, name=source_tracks[i - 8]["name"], slot=source_tracks[i - 8]["slot"],
                                pivot=source_tracks[i - 8]["pivot"], sheet=f"{folder}/{i:02}.webp")
                           for i in FANS])
    (HERE / "track.js").write_text("const leafImpact = " + json.dumps(track) + ";\n", encoding="utf-8")


if __name__ == "__main__":
    build()
