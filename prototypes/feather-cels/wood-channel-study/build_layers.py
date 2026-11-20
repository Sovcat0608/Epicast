"""Prepare layered slat textures, lit grooves, and the overlapping animated foreground."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path[:0] = [str(PREVIEW), str(PREVIEW / "fabric-flag-study"), str(PREVIEW / "treant-study")]
from bake_flag import CHANNEL_SLOTS, SLOTS, guide, model_direction, motions_from_video, pose_for, symbol_light, window
from bake_batch import axes, remap, treant_channel_animation
from bake import MASTER
from cheek_placement import LAYERS, composite, premult, registered_stack
from paired_lighting import hold_response, registered_light
from prepare import SLOT as FACE_SLOT, breath_motion, sampler, warp

TRAVEL = 28
TILES = ((58, 744, 445, 241), (612, 744, 469, 241))
NAMES = ("left", "right")
COLUMNS = 4
PULSE_REFERENCE = HERE / "painted-reference/strong-glow"
FULL_ETCH = HERE / "painted-reference/recess-glint-wan/midpoint-full-etch"
FRONT = 18


def image_alpha(alpha, color=(0, 0, 0)):
    out = Image.new("RGBA", alpha.size, (*color, 0))
    out.putalpha(alpha)
    return out


def save(image, name):
    image.save(HERE / (name + ".webp"), lossless=True)
    return f"wood-channel-study/{name}.webp"


def atlas(cels):
    w, h = cels[0].size
    result = Image.new("RGBA", (COLUMNS*w, (len(cels)+COLUMNS-1)//COLUMNS*h))
    for i, cel in enumerate(cels):
        result.paste(cel, (i%COLUMNS*w, i//COLUMNS*h))
    return result


def section(paints, fields, slot, indexes):
    empty = Image.new("RGBA", slot[2:])
    selected = [paint if i in indexes else empty for i, paint in enumerate(paints)]
    return composite(selected, fields, slot)


def translate(image, dx):
    result = Image.new(image.mode, image.size)
    result.paste(image, (dx, 0))
    return result


def fixed_contact(index, fields):
    light = np.ones((fields[index].height, fields[index].width), dtype=np.float32)
    row = LAYERS[index]
    for caster in row["casters"]:
        if caster == FRONT:
            continue
        weight = row["contactStrength"].get(LAYERS[caster]["name"], 1)
        light *= 1 - weight * np.asarray(fields[caster], dtype=np.float32) / 255
    return image_alpha(Image.fromarray(np.rint(255*(1-light)).astype(np.uint8)))


def make_tile(side, slot, light_matte):
    name, index = NAMES[side], side + 4
    row = LAYERS[index]
    paints, fields = registered_stack(slot)
    baseline = premult(composite(paints, fields, slot))
    direction = -1 if side == 0 else 1
    support = np.zeros(baseline.shape[:2], dtype=bool)
    source, shadow = paints[index], fields[index]
    for step in range(4, TRAVEL+1, 4):
        paints[index], fields[index] = translate(source, direction*step), translate(shadow, direction*step)
        moved = premult(composite(paints, fields, slot))
        support |= np.any(np.abs(moved - baseline) > 2/255, axis=2)
    glow_support = Image.new("L", slot[2:])
    glow_support.paste(light_matte,(row["x"]-slot[0], row["y"]-slot[1]))
    for step in range(TRAVEL+1):
        support |= np.asarray(translate(glow_support,direction*step)) > 1
    # A narrow falloff outside the real movement support avoids rectangular seams.
    core = Image.fromarray(support.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(9))
    edge = core.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    mask = ImageChops.lighter(core, edge)
    paints[index], fields[index] = source, shadow
    clean_fields = fields.copy()
    for i in (4, 5):
        clean_fields[i] = Image.new("L", slot[2:])
    lower = section(paints, clean_fields, slot, (2, 3))
    upper = section(paints, fields, slot, range(6, FRONT))
    hidden_paint, hidden_fields = registered_stack(slot, hide_cheeks=True)
    hidden_upper = section(hidden_paint, hidden_fields, slot, range(6, FRONT))
    paint_box = (row["x"]-slot[0], row["y"]-slot[1], row["w"], row["h"])
    wood = source.crop((paint_box[0], paint_box[1], paint_box[0]+paint_box[2], paint_box[1]+paint_box[3]))
    # Keep the wood, its contact field and the glow independently translatable.
    return dict(
        slot=slot, travel=direction*TRAVEL, paintBox=paint_box,
        mask=save(image_alpha(mask), name+"-mask"), lower=save(lower, name+"-lower"),
        paint=save(wood, name+"-wood"), front=save(paints[FRONT], name+"-front"),
        shadow=save(image_alpha(shadow), name+"-shadow"),
        shade=save(fixed_contact(index, fields), name+"-shade"),
        hiddenShade=save(fixed_contact(index, hidden_fields), name+"-shade-hidden"),
        frontCast=save(image_alpha(fields[FRONT]), name+"-front-cast"),
        upper=save(upper, name+"-upper"), hiddenUpper=save(hidden_upper, name+"-upper-hidden"),
    )


def source_frames(slot, count, pose, light=None, cast_shadow=False):
    paints, fields = registered_stack(slot)
    art = paints[FRONT]
    x, y = axes(slot)
    frames = []
    cast = [] if cast_shadow else None
    for frame in range(count):
        dx, dy = pose(frame, x, y, art, FRONT)
        cel = remap(art, x, y, dx, dy)
        frames.append(cel if light is None else light(frame, cel, x, y))
        if cast is not None:
            cast.append(image_alpha(remap(fields[FRONT], x, y, dx, dy)))
    return slot, frames, cast


def animation_sources():
    x, y, pitch, jaw, corners = sampler()
    breath = breath_motion()
    dx = breath["cornerSpreadPx"] * corners
    dy = breath["jawDropPx"] * jaw - breath["faceLiftPx"] * pitch
    fixed_face = registered_stack(FACE_SLOT)[0][FRONT]
    face_idle = []
    for frame in range(32):
        amount = .5 - .5*np.cos(2*np.pi*frame/32)
        mx, my = (x-amount*dx).astype(np.float32), (y-amount*dy).astype(np.float32)
        face_idle.append(warp(fixed_face, mx, my))
    face_slot, pose, eye_light, _ = treant_channel_animation()
    faces = dict(idle=(FACE_SLOT, face_idle, None), channel=source_frames(face_slot, 12, pose, eye_light))
    footage = motions_from_video("flags", [window(43,403,66,433), window(569,404,597,436)],
                                 window(119,128,178,181), source=PREVIEW/"fabric-flag-study"/"wan.mp4")
    fabrics = []
    for side, (idle, channel) in enumerate(zip(SLOTS, CHANNEL_SLOTS)):
        drift,_ = guide(footage, side)
        vector = model_direction(drift, [(7.2,-2.5),(6.6,-2.2)][side], .22)
        fabrics.append(dict(
            idle=source_frames(idle, 32, pose_for(side, idle, vector), cast_shadow=True),
            channel=source_frames(channel, 6, pose_for(side, channel, vector, 6, channel=True),
                                  symbol_light(side, channel, 6), cast_shadow=True),
        ))
    return faces, fabrics


def make_front_track(tile, source, label):
    x,y,w,h = tile
    (sx,sy,sw,sh), frames, cast = source
    left,top,right,bottom = max(x,sx),max(y,sy),min(x+w,sx+sw),min(y+h,sy+sh)
    if left>=right or top>=bottom:
        return None
    box = (left-sx,top-sy,right-sx,bottom-sy)
    track = dict(rect=(left-x,top-y,right-left,bottom-top),
                 sheet=save(atlas([frame.crop(box) for frame in frames]), label))
    if cast is not None:
        track["cast"] = save(atlas([frame.crop(box) for frame in cast]), label+"-cast")
    return track


def build():
    faces, fabrics = animation_sources()
    tiles = []
    for side, (name, slot) in enumerate(zip(NAMES, TILES)):
        with Image.open(FULL_ETCH / f"{name}-etch-and-reflection-mask.png") as source:
            matte = source.copy()
        if side == 0:
            with Image.open(MASTER / "registered/04-paint.png") as source:
                _, pulse_mask, pulse_size = registered_light(source.convert("RGBA"), PULSE_REFERENCE, name)
            pulse = hold_response(pulse_mask, pulse_size, PULSE_REFERENCE / "wan.mp4")
        tile = make_tile(side, slot, matte)
        tile["paintedGlow"] = (FULL_ETCH / f"{name}-midpoint.png").relative_to(PREVIEW).as_posix()
        for state in ("idle", "channel"):
            tile[state] = [
                make_front_track(slot, faces[state], f"{name}-face-{state}"),
                make_front_track(slot, fabric[state], f"{name}-fabric-{state}"),
            ]
        tiles.append(tile)
    data = dict(tiles=tiles, columns=COLUMNS, paintedHold=pulse)
    (HERE/"track.js").write_text("const woodChannel = " + json.dumps(data) + ";\n")


if __name__ == "__main__":
    build()
