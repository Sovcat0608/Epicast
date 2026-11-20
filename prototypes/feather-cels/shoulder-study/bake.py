"""Register the shoulder sprite sheet and render its contact on the static crest."""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parent))
from crown import CLUSTERS, LAYERS, MASTER, leaf_contact, registered, shade, stem_anchor

def composite_layers(art, fields, size):
    w, h = size
    patch = Image.new("RGBA", size)
    for i, row in enumerate(LAYERS):
        if not art[i].getbbox():
            continue
        light = np.ones((h, w), dtype=np.float32)
        for j in row["casters"]:
            weight = row["contactStrength"].get(LAYERS[j]["name"], 1)
            light *= 1 - weight * np.asarray(fields[j], dtype=np.float32) / 255
        patch.alpha_composite(shade(art[i], Image.fromarray(np.rint(light*255).astype("uint8")).convert("RGB")))
    return patch


def build(source, output, columns, rows, beats, registered_size=False, idle_beats=None, variable="shoulderStudy", registered_pivot=False, index=10):
    assert index in (10, 11)
    end = "top-right" if index == 10 else "top-left"
    track = json.loads((OUT.parent / "crown/idle.js").read_text().split("=", 1)[1].strip().rstrip(";"))["tracks"][index - 8]
    assert track["name"] == LAYERS[index]["name"]
    x, y, w, h = box = track["slot"]
    sheet = Image.open(source).convert("RGBA")
    cw, ch = sheet.width // columns, sheet.height // rows
    art = [registered(i, "paint", box) for i in range(len(LAYERS))]
    fields = [registered(i, "field", box).getchannel("A") for i in range(len(LAYERS))]
    original = Image.open(MASTER / "Figma crest.png").convert("RGBA")
    # The feather on this side passes behind the tile. Keep its fixed metal nib in
    # the foreground and let the player draw the current feather cels below.
    feather = CLUSTERS[index - 10]
    feather_art = art[feather.index]
    feather_area = feather_art.getchannel("A").point(lambda a: 255 if a else 0).filter(ImageFilter.MaxFilter(3))
    nib_mask = Image.new("L", (4*w, 4*h))
    origin = LAYERS[feather.index]
    ImageDraw.Draw(nib_mask).polygon([
        (4*(origin["x"]-x+dx), 4*(origin["y"]-y+dy)) for dx, dy in feather.lip
    ], fill=255)
    nib = feather_art.copy()
    nib.putalpha(ImageChops.multiply(feather_art.getchannel("A"), nib_mask.resize((w,h), Image.Resampling.LANCZOS)))
    static_patch = original.crop((x, y, x+w, y+h))
    old_area = ImageChops.lighter(art[index].getchannel("A"), fields[index])
    selected = sorted(set(beats))
    atlas = Image.new("RGBA", (columns*w, math.ceil(len(selected)/columns)*h))
    poses, assembled = [], []
    for slot, k in enumerate(selected):
        left, top = k % columns * cw, k // columns * ch
        cel = sheet.crop((left, top, left+cw, top+ch))
        cel.putalpha(cel.getchannel("A").point(lambda a: 0 if a < 8 else a))
        if registered_size:
            assert cel.size == (w, h), "True Size export must match the registered keyframe"
        elif slot == 0:
            l, u, r, b = cel.getbbox()
            scale = min(LAYERS[index]["w"]/(r-l), LAYERS[index]["h"]/(b-u))
            size = round(cw*scale), round(ch*scale)
        if not registered_size:
            cel = cel.resize(size, Image.Resampling.LANCZOS)
        if registered_pivot:
            assert registered_size and cel.size == (w, h)
            layer = cel
        else:
            px, py = stem_anchor(cel, end)
            layer = Image.new("RGBA", (w, h))
            layer.paste(cel, (track["pivot"][0]-px, track["pivot"][1]-py))
            assert stem_anchor(layer, end) == tuple(track["pivot"])
        art[index] = layer
        poses.append(layer)
        fields[index] = leaf_contact(layer.getchannel("A")).getchannel("A")
        patch = composite_layers(art, fields, (w,h))
        affected = ImageChops.lighter(old_area, ImageChops.lighter(layer.getchannel("A"), fields[index]))
        mask = affected.point(lambda a: 255 if a else 0).filter(ImageFilter.MaxFilter(3))
        patch = Image.composite(patch, static_patch, mask)
        atlas.paste(patch, (slot % columns * w, slot // columns * h))
        scene = original.copy()
        scene.paste(patch, (x, y))
        scene.thumbnail((162, 216), Image.Resampling.LANCZOS)
        assembled.append(scene)
    atlas.save(output / "scene.webp", lossless=True)
    sequence = [selected.index(k) for k in beats]
    idle = [selected.index(k) for k in idle_beats] if idle_beats else sequence
    for name, drawings in [("leaf", poses), ("crest", assembled)]:
        exposures = [drawings[k] for k in idle]
        exposures[0].save(output / (name+".webp"), save_all=True, append_images=exposures[1:],
                          duration=125, loop=0, lossless=True)
    data = dict(slot=box, frames=sequence, frameMs=125, columns=columns,
                sheet=(output/"scene.webp").relative_to(OUT.parent).as_posix())
    if idle_beats:
        data["idleFrames"] = idle
    # Both tracks have a two-second period. Composite each beat together because
    # their tiles intersect and the shoulder casts a moving shadow on the autumn fan.
    autumn = OUT.parent / "crown-ludo"
    autumn_track = json.loads((autumn / "autumn-track.js").read_text().split("=", 1)[1].strip().rstrip(";"))
    ax, ay, aw, ah = autumn_track["slot"]
    autumn_scene = Image.open(OUT.parent / autumn_track["sheet"]).convert("RGBA")
    autumn_field = Image.open(autumn / "contact.webp").convert("RGBA")
    autumn_paint = Image.open(autumn / "idle.webp")
    for key, playback in [("pairedSheet", idle), ("fullPairedSheet", sequence)]:
        if key == "fullPairedSheet" and idle == sequence:
            continue
        paired = Image.new("RGBA", (4*w, 4*h))
        thumbnails = []
        for beat, pose_id in enumerate(playback):
            # Two beats of separation keep the fans breathing independently.
            autumn_frame = (beat + 2) % 16
            autumn_paint.seek(autumn_frame)
            left, top = autumn_frame % 4 * aw, autumn_frame // 4 * ah
            rect = (left, top, left+aw, top+ah)
            def in_slot(tile):
                return tile.crop((x-ax, y-ay, x-ax+w, y-ay+h))
            art[8] = in_slot(autumn_paint.convert("RGBA"))
            fields[8] = in_slot(autumn_field.crop(rect)).getchannel("A")
            art[index] = poses[pose_id]
            fields[index] = leaf_contact(art[index].getchannel("A")).getchannel("A")
            scene = original.copy()
            scene.paste(autumn_scene.crop(rect), (ax, ay))
            patch = composite_layers(art, fields, (w,h))
            affected = ImageChops.lighter(old_area, ImageChops.lighter(art[index].getchannel("A"), fields[index]))
            mask = affected.point(lambda a: 255 if a else 0).filter(ImageFilter.MaxFilter(3))
            patch = Image.composite(patch, scene.crop((x,y,x+w,y+h)), mask)
            foreground = art.copy()
            foreground[feather.index] = nib
            front = Image.composite(composite_layers(foreground, fields, (w,h)), patch, feather_area)
            paired.paste(front, (beat % 4*w, beat // 4*h))
            if key == "pairedSheet":
                scene.paste(patch, (x,y))
                scene.thumbnail((162,216),Image.Resampling.LANCZOS)
                thumbnails.append(scene)
        path = output / (key + ".webp")
        paired.save(path, lossless=True)
        data[key] = path.relative_to(OUT.parent).as_posix()
        if thumbnails:
            thumbnails[0].save(output / "paired-crest.webp", save_all=True, append_images=thumbnails[1:],
                               duration=125, loop=0, lossless=True)
    (output / "track.js").write_text(f"const {variable} = "+json.dumps(data)+";\n")


if __name__ == "__main__":
    directory = OUT / (sys.argv[1] if len(sys.argv) > 1 else "breeze")
    recipe = json.loads((directory / "exposures.json").read_text())
    build(directory / recipe["sheet"], directory, recipe["columns"], recipe["rows"], recipe["frames"],
          recipe.get("registeredSize", False), recipe.get("idleFrames"),
          recipe.get("variable", "ignisShoulderStudy" if directory.name == "ignis-keyframes" else "shoulderStudy"),
          recipe.get("registeredPivot", False), recipe.get("layer", 10))
