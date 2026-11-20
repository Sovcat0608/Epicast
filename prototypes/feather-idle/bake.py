"""Bake the registered left feather into an idle flipbook and a crest review strip."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
MASTER = HERE.parents[1] / "concepts/restoration-frame146"
REG = MASTER / "registered"
LAYERS = json.loads((MASTER / "registration.json").read_text())
# Four equal time steps into the breath, then four back to rest across the seam.
ANGLES = (0, 0.5, 1.65, 2.8, 3.3, 2.8, 1.65, 0.5)
FRAMES = len(ANGLES)
FPS = 4
COLUMNS, ROWS = 4, 2
# Design pixels. Each native atlas cell represents this rectangle at half resolution.
X, Y, W, H = 8, 368, 256, 512
BOX = X, Y, X + W, Y + H
LEFT = LAYERS[0]
assert LEFT["name"] == "Left bound feathers"


def tile(index, field=False):
    layer = LAYERS[index]
    kind, prefix = ("field", "s") if field else ("paint", "")
    img = Image.open(REG / f"{index:02}-{kind}.png").convert("RGBA")
    result = Image.new("RGBA", (W, H))
    result.paste(img, (layer[prefix + "x"] - X, layer[prefix + "y"] - Y))
    return np.asarray(result).astype(np.float32) / 255


def premultiply(rgba):
    return np.concatenate((rgba[..., :3] * rgba[..., 3:], rgba[..., 3:]), axis=2)


def image(pixels):
    alpha = np.clip(pixels[..., 3:], 0, 1)
    rgb = np.divide(pixels[..., :3], alpha, out=np.zeros_like(pixels[..., :3]), where=alpha > .0001)
    rgba = np.concatenate((rgb, alpha), axis=2)
    return Image.fromarray(np.uint8(np.rint(255 * np.clip(rgba, 0, 1))))


yy, xx = np.indices((H, W), dtype=np.float32)
local_y = yy + Y - LEFT["y"]
local_x = xx + X - LEFT["x"]
# Seat the hinge on the quill just below the fitting. Only this short neck flexes.
neck = np.clip((local_y - 78) / 38, 0, 1)
hinge = neck * neck * (3 - 2 * neck)
pivot_x, pivot_y = 133, 78


def pose(paint, frame):
    angle = np.deg2rad(ANGLES[frame]) * hinge
    # Inverse rotation preserves the shape of the entire fan below the neck.
    rx, ry = local_x - pivot_x, local_y - pivot_y
    cosine, sine = np.cos(angle), np.sin(angle)
    u = np.clip(xx + (cosine - 1) * rx - sine * ry, 0, W - 1)
    v = np.clip(yy + sine * rx + (cosine - 1) * ry, 0, H - 1)
    x0, y0 = u.astype(int), v.astype(int)
    x1, y1 = np.minimum(x0 + 1, W - 1), np.minimum(y0 + 1, H - 1)
    fx, fy = (u - x0)[..., None], (v - y0)[..., None]
    return ((1 - fy) * ((1 - fx) * paint[y0, x0] + fx * paint[y0, x1])
            + fy * ((1 - fx) * paint[y1, x0] + fx * paint[y1, x1]))


def build():
    full = Image.open(MASTER / "Figma crest.png").convert("RGBA")
    static = np.asarray(full.crop(BOX)).astype(np.float32) / 255
    feather = tile(0)
    reveal = np.ones((H, W, 1), dtype=np.float32)
    for i in range(1, len(LAYERS)):
        reveal *= 1 - tile(i)[..., 3:]
    light = np.ones_like(reveal)
    for caster in LEFT["casters"]:
        weight = LEFT["contactStrength"].get(LAYERS[caster]["name"], 1)
        light *= 1 - weight * tile(caster, True)[..., 3:]

    # Recover the master's feather grade from exposed feather pixels. Shadow fields
    # stay in crest space and are evaluated against the new pose at every frame.
    exposed = (reveal[..., 0] > .996) & (feather[..., 3] > .98) & (light[..., 0] > .35)
    raw = feather[..., :3]
    target = static[..., :3] / np.maximum(light, .01)
    for c in range(3):
        fit = np.polyfit(raw[..., c][exposed], target[..., c][exposed], 2)
        raw[..., c] = np.clip(np.polyval(fit, raw[..., c]), 0, 1)
    known = (reveal[..., 0] > .9999) & (feather[..., 3] > .001) & (light[..., 0] > .12)
    raw[known] = np.clip(target[known], 0, 1)
    rest = premultiply(feather)
    original = premultiply(static)
    transmit = np.concatenate((np.repeat(light, 3, axis=2), np.ones_like(light)), axis=2)
    cell_w, cell_h = 128, 256
    atlas = Image.new("RGBA", (COLUMNS * cell_w, ROWS * cell_h))
    # Review patch only covers the flexible portion. The remaining crest is the
    # approved full-resolution export, including its foreground and fixed shadows.
    crop = (0, 150, W, 448)
    pw, ph = W, crop[3] - crop[1]
    review = Image.new("RGBA", (COLUMNS * pw, ROWS * ph))
    for i in range(FRAMES):
        moved = pose(rest, i)
        assert np.allclose(moved[local_y <= 78], rest[local_y <= 78], atol=1e-6)
        alpha = moved[..., 3]
        assert not (alpha[0].any() or alpha[-1].any() or alpha[:, 0].any() or alpha[:, -1].any())
        current = original + (moved - rest) * reveal * transmit
        inside_patch = image(current).crop(crop)
        if not i:
            approved = full.crop((X, Y + crop[1], X + W, Y + crop[3]))
            inside_patch = approved
        # This receiver is compared against the same stationary casters in game.
        cel = image(moved * transmit).resize((cell_w, cell_h), Image.Resampling.LANCZOS)
        col, row = i % COLUMNS, i // COLUMNS
        atlas.paste(cel, (col * cell_w, row * cell_h))
        review.paste(inside_patch, (col * pw, row * ph))
    atlas.save(HERE / "FeatherIdle.tga")
    review.save(HERE / "review.png")
    data = dict(frames=FRAMES, fps=FPS, columns=COLUMNS, rows=ROWS, cell=[cell_w, cell_h],
                crest=list(full.size), slot=[X,Y,W,H], patch=[X,Y+crop[1],pw,ph],
                state="idle", segment=LEFT["name"])
    (HERE / "clip.js").write_text("const clip = " + json.dumps(data) + ";\n")
    print(f"{FRAMES} poses, {FRAMES/FPS:.3f}s, pinned socket and transparent gutters verified.")


if __name__ == "__main__":
    build()

