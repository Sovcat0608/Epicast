"""Bake registered contact variants for the two independently sliding shards."""
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "prototypes/feather-cels"
sys.path[:0] = [str(PREVIEW), str(ROOT / "concepts/restoration-frame146")]
from contact_field import contact_field
from cheek_placement import LAYERS, registered_stack

MASTER_RECT = (0, 0, 1125, 1400)
FULL_ETCH = PREVIEW / "wood-channel-study/painted-reference/recess-glint-wan/midpoint-full-etch"
FRONT = 18
TRAVEL = 28
STEPS = 7
FABRIC_LEVELS = 2
SHARDS = {"leftSlats": (4, -1), "rightSlats": (5, 1)}
RECEIVERS = {"backboard": 2, "roots": 3}
WRAPS = (
    [(128,290),(203,303),(237,337),(245,376),(233,423),(235,473),(246,500),(268,613),
     (241,602),(196,563),(168,570),(138,588),(112,622),(85,673),(65,650),(47,696),
     (54,753),(21,755),(0,707),(0,656),(20,590),(38,510),(25,496),(9,454),(27,420),
     (58,411),(58,389),(92,365),(141,317)],
    [(557,312),(615,294),(669,286),(697,338),(752,384),(798,420),(808,459),(779,493),
     (771,531),(786,568),(808,628),(818,675),(812,719),(782,755),(767,741),(775,692),
     (752,650),(728,668),(714,636),(696,595),(663,564),(620,563),(574,580),(534,621),
     (539,563),(548,517),(559,465),(565,428),(551,385),(550,348)],
)


def translate(image, dx):
    moved = Image.new(image.mode, image.size)
    moved.paste(image, (dx, 0))
    return moved


def shade(paint, receiver, fields, offsets, source=None):
    pixels = np.array(paint.crop(source) if source else paint)
    light = np.ones(pixels.shape[:2], dtype=np.float32)
    row = LAYERS[receiver]
    for caster in row["casters"]:
        shift = offsets.get(caster, 0)
        if shift is not None:
            field = fields[caster]
            if source:
                left, top, right, bottom = source
                field = field.crop((left-shift, top, right-shift, bottom))
            elif shift:
                field = translate(field, shift)
            strength = row["contactStrength"].get(LAYERS[caster]["name"], 1)
            light *= 1 - strength * np.asarray(field, dtype=np.float32) / 255
    pixels[:, :, :3] = np.rint(pixels[:, :, :3] * light[:, :, None]).astype(np.uint8)
    return Image.fromarray(pixels)


def project(image, source, rect, placement):
    return project_crop(image.crop(source), source[:2], rect, placement)


def project_crop(image, origin, rect, placement):
    x, y, w, h = rect
    scale, ox, oy = placement
    left, top = origin
    matrix = (1 / scale, 0, (x - ox) / scale - 160 - left, 0, 1 / scale, (y - oy) / scale - top)
    return image.convert("RGBa").transform(
        (w, h), Image.Transform.AFFINE, matrix, Image.Resampling.BICUBIC).convert("RGBA")


def source_box(index):
    row = LAYERS[index]
    return (row["x"], row["y"], row["x"] + row["w"], row["y"] + row["h"])


def read_cel(out, item, state, n=0):
    return Image.frombytes("RGBA", tuple(item["rect"][2:]),
                           (out / f"{item['id']}-{state}-{n}.bgra").read_bytes(), "raw", "BGRA")


def write_cel(out, name, image):
    (out / f"{name}.bgra").write_bytes(image.tobytes("raw", "BGRA"))


def fabric_fields(out, banner, side, front, registered, placement):
    sx, sy, rx, by = source_box(FRONT)
    mask = Image.new("L", (rx-sx, by-sy))
    ImageDraw.Draw(mask).polygon(WRAPS[side], fill=255)
    silhouette = front.getchannel("A")
    resting = Image.new("L", silhouette.size)
    resting.paste(silhouette.crop((sx, sy, rx, by)), (sx, sy), mask)
    fixed = ImageChops.subtract(silhouette, resting)
    painted = Image.new("RGBA", silhouette.size)
    painted.putalpha(resting)
    rect = banner["rect"]
    raw_rest = np.asarray(project(painted, source_box(FRONT), rect, placement).getchannel("A"), dtype=np.float32)
    x, y = rect[:2]
    scale, ox, oy = placement
    to_world = (scale, 0, scale*160+ox-x, 0, scale, oy-y)
    name = LAYERS[FRONT]["name"]
    baseline = np.asarray(contact_field(silhouette, name, sx, sy), dtype=np.int16)
    approved = np.asarray(registered, dtype=np.int16)
    rest_alpha = np.asarray(resting, dtype=np.float32)

    def cast(alpha):
        combined = ImageChops.screen(fixed, alpha)
        computed = np.asarray(contact_field(combined, name, sx, sy), dtype=np.int16)
        return Image.fromarray(np.clip(approved+computed-baseline, 0, 255).astype(np.uint8))

    def poses(state, weight):
        clip = banner["clips"][state]
        for cel in range(clip["frames"]):
            raw = np.asarray(read_cel(out, banner, state, cel).getchannel("A"), dtype=np.float32)
            delta = Image.fromarray(raw-raw_rest).transform(
                silhouette.size, Image.Transform.AFFINE, to_world, Image.Resampling.BILINEAR)
            posed = Image.fromarray(np.rint(np.clip(rest_alpha+np.asarray(delta), 0, 255)).astype(np.uint8))
            yield cast(Image.blend(resting, posed, weight))

    idle = list(poses("idle", 1))
    channel = [cel for level in range(1, FABRIC_LEVELS+1)
               for cel in poses("channel", level/FABRIC_LEVELS)]
    impact = list(poses("impact", 1))
    offsets = {"channel": len(idle), "impact": len(idle)+len(channel), "hidden": len(idle)+len(channel)+len(impact)+1}
    return idle+channel+impact+[cast(Image.new("L", silhouette.size))], offsets


def build_fabric_contacts(out, item, index, side, direction, materials, paints, fields, banner, placement):
    source = source_box(index)
    rect = item["rect"]
    support = np.zeros(rect[2:][::-1], dtype=bool)
    variants, offsets = fabric_fields(out, banner, side, paints[FRONT], fields[FRONT], placement)
    for state, paint in materials:
        base = read_cel(out, item, state)
        alpha = base.getchannel("A").tobytes()
        for step in range(STEPS+1):
            distance = direction*step*TRAVEL//STEPS
            shifts = dict.fromkeys(LAYERS[index]["casters"], -distance)
            static = project_crop(shade(paint, index, fields, shifts, source), source[:2], rect, placement)
            expected = (out / f"contact-{item['id']}-{state}-{step}.bgra").read_bytes() if step else base.tobytes("raw", "BGRA")
            assert static.tobytes("raw", "BGRA") == expected
            for frame, pose in enumerate(variants, 1):
                moving = fields.copy()
                moving[FRONT] = pose
                shaded = shade(paint, index, moving, shifts, source)
                cel = project_crop(shaded, source[:2], rect, placement)
                assert cel.getchannel("A").tobytes() == alpha
                if frame != offsets["hidden"]:
                    pixels = np.asarray(cel).astype(np.int32)
                    delta = np.max(np.abs(pixels[:, :, :3]-np.asarray(static)[:, :, :3]), axis=2)
                    support |= delta*pixels[:, :, 3] > 255
                write_cel(out, f"fabric-{item['id']}-{state}-{step}-{frame}", cel)
    columns = np.flatnonzero(support.any(axis=0))
    # Clear sub-byte changes outside the motion corridor. Give the interior cut
    # another 16 reference pixels for the smallest bank's resampling and CAS.
    start, end = int(columns[0]), int(columns[-1])+1
    split = min(end+16, rect[2]) if direction < 0 else max(start-16, 0)
    for state, _ in materials:
        for step in range(STEPS+1):
            static = (read_cel(out, item, state).tobytes("raw","BGRA") if step==0 else
                      (out / f"contact-{item['id']}-{state}-{step}.bgra").read_bytes())
            base = np.frombuffer(static,dtype=np.uint8).reshape(*rect[2:][::-1],4)
            for frame in range(1, offsets["hidden"]):
                file = out / f"fabric-{item['id']}-{state}-{step}-{frame}.bgra"
                cel = np.frombuffer(file.read_bytes(),dtype=np.uint8).copy().reshape(base.shape)
                cel[:, :start] = base[:, :start]
                cel[:, end:] = base[:, end:]
                file.write_bytes(cel.tobytes())
    return {"split": split, "left": direction < 0, "levels": FABRIC_LEVELS,
            "channelFrames": banner["clips"]["channel"]["frames"], "poseCount": len(variants),
            "offsets": offsets, "banner": banner["id"]}


def treant_receiver(out, roots, band, clips, paints, fields, placement):
    # Keep the cast on the rigid centre braid. This corridor lies below
    # the sliding-shard band and between the two independently moving vines.
    slot = (374, 769, 396, 510)
    x,y,w,h = slot
    box = x,y,x+w,y+h
    front = np.asarray(paints[FRONT].getchannel("A").crop(box),dtype=np.int16)
    registered = np.asarray(fields[FRONT].crop(box),dtype=np.int16)
    name = LAYERS[FRONT]["name"]
    sx,sy = source_box(FRONT)[:2]
    old = np.asarray(contact_field(Image.fromarray(np.uint8(front)),name,sx-x,sy-y),dtype=np.int16)
    root = read_cel(out, roots, "idle")
    source = (0, paints[3].getbbox()[1], *MASTER_RECT[2:])
    baseline = np.asarray(project(shade(paints[3],3,fields,{}),source,roots["rect"],placement),dtype=np.int16)
    rest = np.asarray(root,dtype=np.int16)
    support = np.zeros(rest.shape[:2],dtype=bool)
    variants = {}
    for state,clip in clips.items():
        ox,oy = clip["rect"][:2]
        size = clip["rect"][2:]
        assert size == clip["images"][0].size and x<=ox and y<=oy and ox+size[0]<=x+w and oy+size[1]<=y+h
        bounds = np.s_[oy-y:oy-y+size[1],ox-x:ox-x+size[0]]
        resting = np.asarray(clip["images"][0].getchannel("A"),dtype=np.int16)
        variants[state] = []
        for cel in clip["images"]:
            silhouette = front.copy()
            silhouette[bounds] = np.clip(silhouette[bounds]+np.asarray(cel.getchannel("A"))-resting,0,255)
            computed = np.asarray(contact_field(Image.fromarray(np.uint8(silhouette)),name,sx-x,sy-y),dtype=np.int16)
            changed_fields = fields.copy()
            changed_fields[FRONT] = fields[FRONT].copy()
            changed_fields[FRONT].paste(Image.fromarray(np.uint8(np.clip(registered+computed-old,0,255))),(x,y))
            shaded = np.asarray(project(shade(paints[3],3,changed_fields,{}),source,roots["rect"],placement),dtype=np.int16)
            delta = shaded-baseline
            assert not np.any(delta[:,:,3])
            support |= (np.max(np.abs(delta[:,:,:3]),axis=2)>1)&(rest[:,:,3]>0)
            variants[state].append(delta)
    rx,_,rw,rh = roots["rect"]
    scale,ox,_ = placement
    # The motion authoring holds this span entirely still. Extra source
    # pixels on each side keep the smallest bank's CAS edge continuous.
    left_limit = math.ceil((508+160)*scale+ox)-rx
    right_limit = math.floor((652+160)*scale+ox)-rx
    inside = np.zeros(support.shape,dtype=bool)
    inside[band["bottom"]:,left_limit:right_limit] = True
    rows,columns = np.nonzero(support&inside)
    left = max(left_limit,int(columns.min())-6)
    right = min(right_limit,int(columns.max())+7)
    top = max(band["bottom"],int(rows.min())-6)
    bottom = min(rh,int(rows.max())+7)
    region = np.s_[top:bottom,left:right]
    def fade_edges(length, radius):
        positions = np.arange(length)
        ratio = np.minimum(np.minimum(positions,length-1-positions)/radius,1)
        return ratio*ratio*(3-2*ratio)
    falloff = np.outer(fade_edges(bottom-top,8),fade_edges(right-left,10))[:,:,None]
    for frame in range(1,roots["clips"]["idle"]["frames"]):
        assert np.array_equal(np.asarray(read_cel(out,roots,"idle",frame))[region],rest[region])
    for state,frames in variants.items():
        for i,delta in enumerate(frames):
            paint = rest.copy()
            paint[region] = np.rint(np.clip(rest[region]+delta[region]*falloff,0,255))
            write_cel(out,f"treant-contact-{state}-{i}",Image.fromarray(np.uint8(paint)))
    return [left,top,right,bottom]


def build_contacts(out, items, placement, treant=None):
    items = {item["id"]: item for item in items}
    paints, fields = registered_stack(MASTER_RECT, hide_cheeks=True)
    for index in (14,15):
        fields[index] = Image.new("L",MASTER_RECT[2:])
    data = {"steps": STEPS, "travel": TRAVEL * placement[0] / 660, "receivers": {}, "fabric": {}}
    for side, (name, (index, direction)) in enumerate(SHARDS.items()):
        row = LAYERS[index]
        peak = Image.new("RGBA", MASTER_RECT[2:])
        peak.paste(Image.open(FULL_ETCH / f"{('left', 'right')[side]}-midpoint.png"), (row["x"], row["y"]))
        materials = (("idle", paints[index]), ("channel", peak))
        for state, paint in materials:
            base = read_cel(out, items[name], state)
            for step in range(1, STEPS + 1):
                distance = direction * step * TRAVEL // STEPS
                # In the moving shard's local coordinates, fixed casters move opposite the shard.
                offsets = dict.fromkeys(row["casters"], -distance)
                cel = project(shade(paint, index, fields, offsets), source_box(index), items[name]["rect"], placement)
                assert cel.getchannel("A").tobytes() == base.getchannel("A").tobytes()
                write_cel(out, f"contact-{name}-{state}-{step}", cel)
        banner = ("leftBanner", "rightBanner")[side]
        data["fabric"][name] = build_fabric_contacts(out, items[name], index, side, direction,
                                                       materials, paints, fields, items[banner], placement)

    for name, index in RECEIVERS.items():
        item = items[name]
        x, _, w, h = item["rect"]
        scale, ox, _ = placement
        split = math.floor((MASTER_RECT[2] / 2 + 160) * scale + ox) - x
        base = read_cel(out, item, "idle")
        source = source_box(index)
        if name == "roots":
            source = (0, paints[index].getbbox()[1], *MASTER_RECT[2:])
        reference = np.asarray(project(shade(paints[index], index, fields, {}), source, item["rect"], placement))
        variants = []
        for shard_name, (caster, direction) in SHARDS.items():
            opposite = slice(split, w) if direction < 0 else slice(0, split)
            changes = np.zeros((h, w), dtype=bool)
            for step in range(1, STEPS + 2):
                distance = direction * step * TRAVEL // STEPS if step <= STEPS else None
                image = project(shade(paints[index], index, fields, {caster: distance}), source, item["rect"], placement)
                pixels = np.asarray(image)
                changes |= np.any(pixels != reference, axis=2)
                assert np.array_equal(pixels[:, :, 3], reference[:, :, 3])
                write_cel(out, f"contact-{name}-{shard_name}-{step}", image)
            assert not changes[:, opposite].any()
            variants.append(changes)
        affected = np.logical_or(*variants)
        rows = np.where(affected.any(axis=1))[0]
        # The contact band stays on rigid paint, even while the lower vines sway.
        top, bottom = max(0, int(rows[0]) - 6), min(h, int(rows[-1]) + 7)
        region = slice(top, bottom)
        assert np.array_equal(np.asarray(base)[region], reference[region])
        for frame in range(1, item["clips"]["idle"]["frames"]):
            assert np.array_equal(np.asarray(read_cel(out, item, "idle", frame))[region], reference[region])
        data["receivers"][name] = {"split": split, "top": top, "bottom": bottom}
    if treant:
        receiver = data["receivers"]["roots"]
        receiver["treant"] = treant_receiver(out,items["roots"],receiver,treant,paints,fields,placement)
    (out / "shard-contacts.json").write_text(json.dumps(data), encoding="utf-8")


if __name__ == "__main__":
    out = ROOT / "artifacts/restoration-segments"
    placement = json.loads((ROOT / "artifacts/restoration-idle-cas-build/bake.json").read_text())["transform"]
    build_contacts(out, json.loads((out / "segments.json").read_text()), placement)
