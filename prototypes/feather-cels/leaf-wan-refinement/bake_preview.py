"""Composite the registered Wan leaves and their contacts for the desktop preview."""
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

from guides import HERE, OUTPUT, PREVIEW, leaf_sources, review_source
from bake_inner import crop_tile
from cheek_placement import composite, premult, registered_stack
from crown import leaf_contact


SLOT = (0, 0, 1125, 624)
COLUMNS = 4
DESTINATION = HERE / "preview"


def difference(before, after):
    return np.any(np.abs(before - premult(after)) > 2 / 255, axis=2)


def atlas_for(job, selection):
    job,folder = review_source(job,selection[f"{job['name']}/{job['state']}"])
    with Image.open(folder / "registered-cels.webp") as atlas:
        w, h = job["registered"][2:]
        cels = []
        for index in range(job["outputFrames"]):
            x = index % COLUMNS * w
            y = index // COLUMNS * h
            cels.append(atlas.crop((x, y, x+w, y+h)).convert("RGBA"))
        return cels


def compose(paints, fields, assets, count):
    for frame in range(count):
        for index, (slot, cels) in assets.items():
            paint = crop_tile(cels[frame], slot, SLOT)
            paints[index] = paint
            fields[index] = leaf_contact(paint.getchannel("A")).getchannel("A")
        yield composite(paints, fields, SLOT)


def bake(without_rejuvenation=False):
    destination = (PREVIEW/"resto-motion-refinement/preview/crown"
                   if without_rejuvenation else DESTINATION)
    destination.mkdir(parents=True,exist_ok=True)
    verification = json.loads((OUTPUT / "verification.json").read_text(encoding="utf-8"))
    jobs = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
    selection = json.loads((OUTPUT / "review-selection.json").read_text(encoding="utf-8"))
    assert len(verification) == len(jobs) == 12
    paints, fields = registered_stack(SLOT, hide_cheeks=True)
    for index in (0, 1):
        # The preview supplies the live feather tracks behind this patch.
        paints[index] = Image.new("RGBA", SLOT[2:])
    if without_rejuvenation:
        # The separately floating leaf and its cast are added by the compositor.
        paints[15] = Image.new("RGBA", SLOT[2:])
        fields[15] = Image.new("L", SLOT[2:])
    rest = premult(composite(paints, fields, SLOT))
    coverage = np.zeros(SLOT[2:][::-1], dtype=bool)
    for image in compose(paints.copy(), fields.copy(), leaf_sources(), 16):
        coverage |= difference(rest, image)
    states = {}
    for state in ("channel", "impact"):
        rows = [job for job in jobs if job["state"] == state]
        assets = {row["index"]: (row["registered"], atlas_for(row,selection)) for row in rows}
        period = 1000 * rows[0]["cycle"]
        count = rows[0]["outputFrames"]
        images = list(compose(paints.copy(), fields.copy(), assets, count))
        for image in images:
            coverage |= difference(rest, image)
        states[state] = (images, period)
    mask = Image.fromarray(255 * coverage.astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
    rect = mask.getbbox()
    assert rect and rect[3] < SLOT[3], "Leaf contact reached the edge of the preview patch"
    cropped_mask = mask.crop(rect)
    x, y, right, bottom = rect
    w, h = cropped_mask.size
    transparent = Image.new("RGBA", (w, h))
    coverage_texture = transparent.copy()
    coverage_texture.putalpha(cropped_mask)
    coverage_texture.save(destination/"coverage.webp", lossless=True)
    prefix = destination.relative_to(PREVIEW).as_posix()
    revisions = sorted({row["revision"] for row in selection.values() if row.get("revision")})
    version = "?revision="+"-".join(revisions) if revisions else ""
    tracks = {}
    for state, (images, period) in states.items():
        count = len(images)
        atlas = Image.new("RGBA", (COLUMNS*w, ((count+COLUMNS-1)//COLUMNS)*h))
        for frame, image in enumerate(images):
            tile = Image.composite(image.crop(rect), transparent, cropped_mask)
            atlas.paste(tile, (frame%COLUMNS*w, frame//COLUMNS*h))
        atlas.save(destination/f"{state}.webp", lossless=True)
        tracks[state] = dict(slot=[x,y,w,h], columns=COLUMNS, frames=count, period=period,
                             frameMs=period/count, sheet=f"{prefix}/{state}.webp{version}",
                             coverage=f"{prefix}/coverage.webp{version}", redrawFeathers=True)
    binding = "wanLeafUncovered" if without_rejuvenation else "wanLeafPreview"
    (destination/"tracks.js").write_text(
        f"const {binding} = " + json.dumps(tracks) + ";\n", encoding="utf-8")
    print(f"Built two Wan leaf tracks on a {w}×{h} shared contact patch.")


if __name__ == "__main__":
    bake("--without-rejuvenation" in sys.argv)
