"""Bake an outward cloth snap from the registered banner artwork."""
import json
import sys

import numpy as np
from PIL import Image

from bake_flag import HERE, PREVIEW, FRONT, HEIGHTS, INSIDE, cv2, smooth, straight_patch, symbol_light
from bake_batch import premult, rgba

sys.path.insert(0, str(PREVIEW / "right-crown-study"))
from bake_spine_bend import inverse_bend

SLOTS = ((40, 542, 375, 463), (725, 542, 390, 463))
# World-space hinge and the direction through the attached part of each hem.
HINGES = ((221, 692), (930, 691))
DIRECTIONS = ((-.10, 1.), (.11, 1.))
CURVATURES = (.00185, -.00178)
TIP_HINGES = ((192, 786), (956, 787))
TIP_DIRECTIONS = ((.10, 1.), (-.11, 1.))
TIP_CURVATURES = (.0262, -.0262)
STRIKE = (.68, 1, .93, .81, .68, .55, .42, .30, .19, .10, .04, 0)
# Closest idle silhouettes to the relaxed hems, measured on registered RGBA.
IDLE_RETURN = (21, 25)
FLASH = (.58, 2.3, 1.36, .67, .23, .05, 0, 0, 0, 0, 0, 0)


def read_track(path):
    return json.loads(path.read_text(encoding="utf-8-sig").split("=", 1)[1].strip().rstrip(";"))


def impact_pose(side, slot):
    pivot = tuple(point - origin for point, origin in zip(HINGES[side], slot[:2]))
    direction = np.array(DIRECTIONS[side])
    direction /= np.linalg.norm(direction)

    def pose(frame, x, y, _art, _layer):
        u, v = x + slot[0] - 164, y + slot[1] - 150
        from_edge = u if side == 0 else 817 - u
        inside = np.interp(v, HEIGHTS, INSIDE[side])
        # Limit motion to the outer cloth. The bound wrap, inner fold and
        # printed glyphs stay fixed. Leave space for the silhouette to sweep.
        outer_cloth = (1 - smooth(inside - 25, inside + 7, from_edge)) * smooth(-68, -48, from_edge)
        outer_cloth *= 1 - smooth(751, 782, v)
        sx, sy = inverse_bend(x, y, STRIKE[frame] * CURVATURES[side], pivot, direction, 0)
        return (x - sx) * outer_cloth, (y - sy) * outer_cloth

    return pose


def reverse_fold(side, slot, tip_curve=STRIKE):
    base_pose = impact_pose(side, slot)
    pivot = tuple(point - origin for point, origin in zip(TIP_HINGES[side], slot[:2]))
    direction = np.array(TIP_DIRECTIONS[side])
    direction /= np.linalg.norm(direction)

    def deform(frame, x, y, paint, field):
        dx, dy = base_pose(frame, x, y, paint, FRONT)
        base_x, base_y = (x - dx).astype(np.float32), (y - dy).astype(np.float32)
        curvature = tip_curve[frame] * TIP_CURVATURES[side]
        if not curvature:
            return paint, field
        tip_x, tip_y = inverse_bend(base_x, base_y, curvature, pivot, direction, 0)

        # Split only the physical tail away from the hanging tears and wood.
        # The split lies above the curl, so the two samples still meet there.
        world_x, world_y = x + slot[0], y + slot[1]
        if side == 0:
            outer = (world_x >= 155) & (world_x < 241)
            shadow_width = smooth(140, 158, world_x) * (1 - smooth(236, 250, world_x))
        else:
            outer = (world_x > 898) & (world_x <= 988)
            shadow_width = smooth(884, 903, world_x) * (1 - smooth(980, 1000, world_x))
        tail = (outer & (world_y >= 778) & (world_y < 910)).astype(np.float32)
        tail_shadow = shadow_width * smooth(775, 781, world_y) * (1 - smooth(910, 938, world_y))

        def split_sample(data, selection, shade=False):
            still = cv2.remap(data * (1 - selection), base_x, base_y, cv2.INTER_LINEAR)
            curl = cv2.remap(data * selection, tip_x, tip_y, cv2.INTER_LINEAR)
            if shade:
                along = (tip_x - pivot[0]) * direction[0] + (tip_y - pivot[1]) * direction[1]
                turn = smooth(1.45, 2.55, along * abs(curvature))
                curl[:, :, :3] *= (1 - .22 * turn[:, :, None])
            return still + curl

        shaded_paint = rgba(split_sample(premult(paint), tail[:, :, None], shade=True))
        shadow = split_sample(np.asarray(field, dtype=np.float32), tail_shadow)
        return shaded_paint, Image.fromarray(np.rint(np.clip(shadow, 0, 255)).astype(np.uint8))

    return deform


def idle_coverage(idle, slot):
    coverage = Image.new("L", slot[2:])
    with Image.open(PREVIEW / idle["coverage"]) as source:
        coverage.paste(source.getchannel("A"), (idle["slot"][0] - slot[0], idle["slot"][1] - slot[1]))
    return coverage


def build():
    feather = read_track(PREVIEW / "impact.js")
    durations = [cel["ms"] for cel in feather["clusters"][0]["tracks"][0]["frames"]]
    assert len(durations) == len(STRIKE) == len(FLASH) == feather["fps"] == 12
    assert sum(durations) == 1000
    idle = read_track(HERE / "track.js")
    tracks = []
    for side, slot in enumerate(SLOTS):
        name = ("left", "right")[side] + "-impact"
        track = straight_patch(
            slot, [FRONT], len(durations), sum(durations) / len(durations),
            None, name, halo=symbol_light(side, slot, len(durations), flash=FLASH),
            output=HERE, redraw_feathers=True,
            extra_coverage=idle_coverage(idle[side], slot), loop=1, deform=reverse_fold(side, slot),
        )
        track.update(fps=feather["fps"], period=sum(durations), durations=durations)
        tracks.append(track)
    data = {"idleReturn": IDLE_RETURN, "tracks": tracks}
    (HERE / "impact-track.js").write_text("const fabricFlagImpact = " + json.dumps(data) + ";\n")


if __name__ == "__main__":
    build()
