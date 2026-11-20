"""Register a single downward nod and closed-mouth scowl on the carved treant."""
import json
import sys

import numpy as np
from PIL import Image

from prepare import FACE, HERE, HIDDEN

sys.path.insert(0, str(HERE.parent / "crest-motion-batch"))
from bake_batch import axes, smooth, straight_patch, remap

OUTPUT = HERE / "impact"
SLOT = (374, 769, 396, 390)
ORIGIN = (429, 777)
NOD = (.48, .87, 1, .97, .88, .73, .55, .38, .23, .11, .035, 0)
CLENCH = (.65, .94, 1, 1, .96, .86, .72, .55, .35, .17, .055, 0)
MIX = (1, 1, 1, 1, 1, 1, .96, .86, .68, .45, .20, 0)
# Trace the curved upper aperture and the jagged ridge of the lower jaw
# in face.png. The closed seam is higher in the centre than at its corners.
MOUTH_X = (77, 86, 96, 107, 114, 124, 139, 153, 166, 174, 184, 192, 200, 204)
OPEN_TOP = (215, 198, 184, 174, 170, 178, 179, 178, 170, 173, 181, 192, 206, 216)
OPEN_BOTTOM = (216, 214, 209, 215, 219, 211, 208, 209, 213, 219, 214, 208, 214, 217)


def open_aperture(x):
    top = np.interp(x, MOUTH_X, OPEN_TOP).astype(np.float32)
    bottom = np.interp(x, MOUTH_X, OPEN_BOTTOM).astype(np.float32)
    return top, bottom


def map_face(cel, x, y):
    u, v = x + SLOT[0] - ORIGIN[0], y + SLOT[1] - ORIGIN[1]
    radial_x = np.abs(u - 140)
    mask = (1 - smooth(102, 153, radial_x)) * (1 - smooth(314, 369, v))
    lower_face = smooth(30, 107, v) * (1 - .45 * smooth(204, 302, v))
    advance = NOD[cel]
    # The forehead hangs in place while the face pitches towards the viewer.
    # The eyes and nose lead down, with a slight perspective widening at the ridge.
    mx = x - advance * .034 * (u - 140) * mask * lower_face
    v -= advance * 13 * mask * lower_face

    # Lower the inner ends of the carved brows without moving the green pupils.
    brow = (1 - smooth(22, 82, radial_x)) * smooth(44, 77, v) * (1 - smooth(91, 112, v))
    v -= advance * 8.5 * brow
    top, bottom = open_aperture(mx + SLOT[0] - ORIGIN[0])
    mouth = smooth(68, 94, u) * (1 - smooth(192, 215, u))
    crescent = 182 + 28 * np.clip(radial_x / 67, 0, 1.1)**1.65
    grit = CLENCH[cel]
    lip = top + grit * (crescent - top)
    jaw = bottom + grit * (crescent + 2.5 - bottom)

    # Keep the carved planes on each side of the opening. When it closes,
    # map the dark cavity into a narrow seam and carry the lower ridge up.
    upper = v + (top - lip) * smooth(133, lip, v)
    gap = top + (v - lip) * (bottom - top) / np.maximum(1, jaw - lip)
    shifted = v + (bottom - jaw) * (1 - smooth(318, 366, v))
    closed = np.where(v < lip, upper, np.where(v < jaw, gap, shifted))
    v += mouth * (closed - v)
    return (x - mx).astype(np.float32), (y - (v + ORIGIN[1] - SLOT[1])).astype(np.float32)


def pose(cel, x, y, _art, _layer):
    return map_face(cel, x, y)


def build():
    feather = json.loads((HERE.parent / "impact.js").read_text().split("=", 1)[1].strip().rstrip(";"))
    times = [frame["ms"] for frame in feather["clusters"][0]["tracks"][0]["frames"]]
    assert len(times) == len(NOD) == len(CLENCH) == len(MIX) == 12 and sum(times) == 1000
    OUTPUT.mkdir(exist_ok=True)
    for hidden in (False, True):
        track = straight_patch(
            SLOT, [FACE], len(times), sum(times) / len(times), pose, "treant-impact",
            hide_cheeks=hidden, output=HIDDEN if hidden else OUTPUT, loop=1,
        )
        if not hidden:
            track.update(period=sum(times), durations=times, fps=feather["fps"], mix=MIX)
            (OUTPUT / "track.js").write_text("const treantImpact = " + json.dumps(track) + ";\n")

    face = Image.new("RGBA", SLOT[2:])
    face.paste(Image.open(HERE / "face.png").convert("RGBA"), (ORIGIN[0] - SLOT[0], ORIGIN[1] - SLOT[1]))
    x, y = axes(SLOT)
    w, h = SLOT[2:]
    atlas = Image.new("RGBA", (4 * w, 3 * h))
    for cel in range(len(times)):
        frame = remap(face, x, y, *map_face(cel, x, y))
        atlas.paste(frame, (cel % 4 * w, cel // 4 * h))
    atlas.save(OUTPUT / "face-cels.webp", lossless=True)


if __name__ == "__main__":
    build()
