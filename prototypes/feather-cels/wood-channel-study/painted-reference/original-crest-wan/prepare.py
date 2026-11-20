"""Prepare the original Crest 146 shard paintings for a local Wan light trial."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
PROJECT = next(p for p in HERE.parents if (p / "concepts/restoration-frame146").is_dir())
CREST = PROJECT / "concepts/restoration-frame146"
SLATS = (
    ("left", 4, 38, (
        ((113,42),(124,42),(131,35),(130,43),(139,44),(150,40),(157,42),(170,48),
         (180,44),(188,40),(195,42),(207,49),(219,50),(230,50),(240,51),(243,54),
         (229,59),(223,58),(218,55),(208,54),(201,53),(195,49),(199,55),(187,61),
         (181,57),(176,53),(167,57),(157,52),(152,47),(147,50),(138,47),(124,45)),
        ((170,130),(185,116),(191,108),(186,103),(184,100),(194,101),(198,105),
         (201,105),(209,101),(220,106),(215,111),(203,118),(188,126),(177,132),
         (189,122),(206,112),(211,105),(202,107),(195,115),(184,121)),
    )),
    ("right", 5, 370, (
        ((79,75),(94,62),(103,56),(113,59),(126,56),(144,49),(148,47),(146,53),
         (150,56),(158,53),(164,48),(170,42),(177,45),(183,49),(188,45),(196,48),
         (211,48),(228,46),(217,51),(199,54),(188,60),(181,58),(172,53),(167,57),
         (154,63),(146,70),(134,78),(129,79),(141,68),(149,59),(140,60),(127,58),
         (117,63),(107,61),(100,61),(91,66)),
        ((72,114),(85,109),(94,107),(105,102),(115,97),(119,100),(109,104),
         (108,107),(126,103),(132,98),(140,95),(135,101),(131,105),(122,108),
         (125,112),(132,115),(140,120),(136,124),(124,120),(116,120),(107,118),
         (96,117),(88,115),(82,115)),
    )),
)
SETTINGS = {
    "model": "wan2.2-ti2v-5b-native", "size": "704x704", "fps": 16,
    "num_frames": 65, "steps": 34, "guidance": 5, "seed": 509429,
    "prompt": ("Fixed orthographic shot of the original two painted wooden ornaments. "
               "The four existing narrow green recesses brighten smoothly together, "
               "briefly hold, then fade to their starting intensity. The faint green "
               "reflection hugs the adjacent carved bevels. The camera, wood, brushwork, "
               "silhouettes, grooves and background stay still for the entire shot."),
    "negative_prompt": ("moving wood, breathing geometry, widened recesses, new cracks, "
                        "growing light, edge lighting, green stain, smoke, particles, "
                        "camera movement, repaint, blur, flicker"),
}


def linear(rgb):
    return np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)


def srgb(rgb):
    return np.where(rgb <= .0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - .055)


def render_reference(paint, interiors, intensity):
    w, h = paint.size
    trace = Image.new("L", (w * 4, h * 4))
    draw = ImageDraw.Draw(trace)
    for contour in interiors:
        draw.polygon([(x * 4, y * 4) for x, y in contour], fill=255)
    trace = trace.resize(paint.size, Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(.45))
    bounce = trace.filter(ImageFilter.GaussianBlur(1.8))
    rgb = np.asarray(paint).copy()
    core = np.asarray(trace, dtype=np.float32) / 255
    halo = np.asarray(bounce, dtype=np.float32) / 255
    alpha = rgb[:, :, 3] / 255
    # Restrict reflected light to a small surface neighborhood and opaque wood.
    edit = ((core > .012) | (halo > .015)) & (alpha > .75)
    original = linear(rgb[:, :, :3] / 255)
    floor_bounce = halo[:, :, None] * np.array((.018, .055, .005))
    floor_luminance = np.sqrt(original[:, :, 0])
    relief = np.clip((floor_luminance - .12) / .52, 0, 1)
    deep_light = core * (.31 + .49 * relief)
    lip_light = core * np.maximum(0, core - halo) * (.25 + .75 * relief)
    cut_light = deep_light[:, :, None] * np.array((.033, .39, .008))
    cut_light += lip_light[:, :, None] * np.array((.16, .55, .024))
    value = srgb(np.clip(original + intensity * (floor_bounce + cut_light), 0, 1))
    result = rgb.copy()
    result[edit, :3] = np.rint(value[edit] * 255).astype(np.uint8)
    assert np.array_equal(result[:, :, 3], rgb[:, :, 3])
    assert np.array_equal(result[~edit], rgb[~edit])
    return Image.fromarray(result), Image.fromarray(edit.astype(np.uint8) * 255)


def prepare():
    registration = json.loads((CREST / "registration.json").read_text(encoding="utf-8"))
    poses = {name: Image.new("RGBA", (704, 704), "#30363b") for name in ("opening", "peak")}
    manifest = []
    for side, index, y, contours in SLATS:
        path = CREST / "registered" / f"{index:02}-paint.png"
        paint = Image.open(path).convert("RGBA")
        position = registration[index]
        assert paint.size == (position["w"], position["h"])
        for pose_name, intensity in (("opening", .32), ("peak", .92)):
            lit, mask = render_reference(paint, contours, intensity)
            lit.save(HERE / f"{side}-{pose_name}.png")
            poses[pose_name].alpha_composite(lit.resize((lit.width * 2, lit.height * 2),
                                                        Image.Resampling.NEAREST), (27, y))
        mask.save(HERE / f"{side}-light-mask.png")
        manifest.append(dict(side=side, source=path.relative_to(PROJECT).as_posix(),
                             sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                             crest_box=[position[key] for key in ("x", "y", "w", "h")],
                             video_box=[27, y, paint.width * 2, paint.height * 2],
                             edited_pixels=int(np.count_nonzero(np.asarray(mask)))))
    for name, frame in poses.items():
        frame.convert("RGB").save(HERE / f"{name}.png")
    (HERE / "reference.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    prepare()

