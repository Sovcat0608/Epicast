"""Build a new peak-light reference from the exact sprites the desktop preview uses."""
import hashlib
import json
from pathlib import Path
import runpy

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent
TRIAL = runpy.run_path(str(HERE.parent / "midpoint/generate.py"))
PREVIEW = next(p for p in HERE.parents if (p / "index.html").is_file())
TRACK = PREVIEW / "wood-channel-study/track.js"
linear = TRIAL["PREVIOUS"]["linear"]
srgb = TRIAL["PREVIOUS"]["srgb"]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def paint_peak(unlit, live, light_mask):
    original = np.asarray(unlit)
    current = np.asarray(live)
    allowed = np.asarray(light_mask) > 0
    assert unlit.size == live.size == light_mask.size
    assert np.array_equal(original[:, :, 3], current[:, :, 3])
    assert np.array_equal(original[~allowed & (original[:, :, 3] > 0)],
                          current[~allowed & (current[:, :, 3] > 0)])
    wood = linear(original[:, :, :3] / 255)
    current_light = np.maximum(0, linear(current[:, :, :3] / 255) - wood)
    current_light[~allowed] = 0
    intensity = current_light[:, :, 1]
    # Build off the existing thin line. Keep the brightest light paler than
    # its fringe and put a trace of reflected light only on the closest bevel.
    core = np.clip(intensity / .20, 0, 1) ** 1.4
    core_add = core[:, :, None] * np.array((.085, .072, .059))
    halo_image = Image.fromarray(np.rint(np.clip(intensity * 800, 0, 255)).astype(np.uint8))
    halo_image = halo_image.filter(ImageFilter.GaussianBlur(.85))
    halo = np.asarray(halo_image, dtype=np.float64) / 255
    reflected = halo[:, :, None] * np.array((.014, .031, .008))
    addition = current_light * np.array((2.35, 2.03, 2.1)) + core_add + reflected
    result = original.copy()
    response = srgb(np.clip(wood + addition, 0, 1))
    result[allowed, :3] = np.rint(255 * response[allowed]).astype(np.uint8)
    assert np.array_equal(result[:, :, 3], original[:, :, 3])
    assert np.array_equal(result[~allowed], original[~allowed])
    return Image.fromarray(result)


def build():
    track = json.loads(TRACK.read_text(encoding="utf-8").split(" = ", 1)[1].strip().removesuffix(";"))
    guide = Image.new("RGBA", tuple(TRIAL["SIZE"]), "#30363b")
    control = guide.copy()
    manifests = []
    for tile, (side, _, video_y, _) in zip(track["tiles"], TRIAL["SLATS"], strict=True):
        unlit_path, live_path = (PREVIEW / tile[name] for name in ("paint", "paintedGlow"))
        # Resolve the light mask next to the very sprite loaded by the live preview.
        mask = live_path.with_name(f"{side}-glint-mask.png")
        unlit = Image.open(unlit_path).convert("RGBA")
        live = Image.open(live_path).convert("RGBA")
        peak = paint_peak(unlit, live, Image.open(mask).convert("L"))
        peak_file = HERE / f"{side}-midpoint.png"
        peak.save(peak_file)
        dx, dy, w, h = tile["paintBox"]
        stage_x, stage_y = tile["slot"][:2]
        assert unlit.size == (w, h)
        for plate, im in ((guide, peak), (control, unlit)):
            plate.alpha_composite(im.resize((2*w, 2*h), Image.Resampling.LANCZOS), (27, video_y))
        changed = np.any(np.asarray(peak) != np.asarray(unlit), axis=2)
        manifests.append(dict(side=side, source=str(unlit_path.relative_to(PREVIEW)),
                              source_sha256=sha256(unlit_path), live_glow=str(live_path.relative_to(PREVIEW)),
                              live_glow_sha256=sha256(live_path), midpoint_sha256=sha256(peak_file),
                              canvas=[w, h], affected_native_pixels=int(changed.sum()),
                              first_pose=[stage_x+dx, stage_y+dy], held_pose=[stage_x+dx+tile["travel"], stage_y+dy],
                              wan_box=[27, video_y, 2*w, 2*h]))
    old_pose = Image.open(HERE.parent / "midpoint/opening.png").convert("RGB")
    assert old_pose.tobytes() == control.convert("RGB").tobytes()
    plate = HERE / "midpoint.png"
    guide.convert("RGB").save(plate)
    (HERE / "registration.json").write_text(
        json.dumps(dict(midpoint_sha256=sha256(plate), sprites=manifests), indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    build()
