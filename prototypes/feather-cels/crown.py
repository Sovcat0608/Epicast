"""Bake registered crown Idle cels with fixed stems and receiver-clipped contact fields."""
import json

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

from bake import CLUSTERS, HERE, MASTER, LAYERS

OUT = HERE / "crown"
SIZE = (1125, 592)
# Index, attached end of the stem, phase delay, and last drawing used in Idle.
# The longer shoulder blades reach the desired idle bend earlier in their sheets.
TRACKS = [
    (8, "bottom-right", 0, 8), (9, "bottom-left", 3, 8),
    (10, "top-right", 2, 4), (11, "top-left", 5, 6),
    (12, "top-left", 4, 4), (13, "top-right", 7, 5),
]


def registered(index, kind, bounds):
    row = LAYERS[index]
    prefix = "s" if kind == "field" else ""
    tile = Image.new("RGBA", bounds[2:])
    with Image.open(MASTER / "registered" / f"{index:02}-{kind}.png") as art:
        tile.paste(art, (row[prefix+"x"]-bounds[0], row[prefix+"y"]-bounds[1]))
    return tile


def static_shading(index, bounds):
    transmission = np.ones((bounds[3], bounds[2]), dtype=np.float32)
    row = LAYERS[index]
    for j in row["casters"]:
        if 8 <= j <= 13:
            continue
        weight = row["contactStrength"].get(LAYERS[j]["name"], 1)
        alpha = registered(j, "field", bounds).getchannel("A")
        transmission *= 1 - weight*np.asarray(alpha, dtype=np.float32)/255
    return Image.fromarray(np.rint(transmission*255).astype(np.uint8)).convert("RGB")


def shade(art, light):
    result = ImageChops.multiply(art.convert("RGB"), light).convert("RGBA")
    result.putalpha(art.getchannel("A"))
    return result


def painted_cells(index):
    with Image.open(HERE/"crown-painted"/f"{index:02}.png") as source:
        w, h = source.width//3, source.height//3
        for k in range(9):
            x, y = k%3*w, k//3*h
            art = source.crop((x,y,x+w,y+h)).convert("RGBA")
            alpha = art.getchannel("A")
            # Isolate the contiguous drawing while retaining its antialiased contour.
            body = alpha.point(lambda a: 255 if a > 96 else 0)
            yy, xx = np.where(np.asarray(body) == 255)
            seed = np.argmin((xx-w/2)**2 + (yy-h/2)**2)
            ImageDraw.floodfill(body, (int(xx[seed]),int(yy[seed])), 128)
            body = body.point(lambda a: 255 if a == 128 else 0)
            art.putalpha(ImageChops.multiply(alpha,body.filter(ImageFilter.MaxFilter(7))))
            yield art


def stem_anchor(art, end):
    alpha = np.asarray(art.getchannel("A"))
    vertical, horizontal = end.split("-")
    ys, xs = np.where(alpha > 128)
    # Find the flat end on the stem side only. A curling blade on the
    # opposite side can reach the same scanline on the more bent drawings.
    lo, hi = xs.min(), xs.max()
    stem_side = xs < lo+.36*(hi-lo) if horizontal == "left" else xs > hi-.36*(hi-lo)
    ys, xs = ys[stem_side], xs[stem_side]
    y = int(ys.max()-2 if vertical == "bottom" else ys.min()+2)
    return int(np.median(xs[abs(ys-y)<=1])+0.5), y


def registered_drawings(index, end, original, pivot):
    if index == 8:
        # Krita exports the entire registered tile, including the transparent gutter.
        with Image.open(HERE/"crown-krita"/"registered-cels.webp") as atlas:
            w,h = original.size
            assert atlas.size == (4*w,4*h)
            for k in range(16):
                x,y = k%4*w,k//4*h
                yield atlas.crop((x,y,x+w,y+h)).convert("RGBA")
        return
    drawings = list(painted_cells(index))
    l,t,r,b = drawings[0].getchannel("A").point(lambda a:255 if a>96 else 0).getbbox()
    row = LAYERS[index]
    scale = min(row["w"]/(r-l), row["h"]/(b-t))
    for drawing in drawings:
        fitted = drawing.resize(tuple(round(n*scale) for n in drawing.size),Image.Resampling.LANCZOS)
        px,py = stem_anchor(fitted,end)
        cel = Image.new("RGBA",original.size)
        cel.paste(fitted,(pivot[0]-px,pivot[1]-py))
        yield cel


def leaf_contact(alpha):
    transmission = np.ones((alpha.height,alpha.width), dtype=np.float32)
    for dx,dy,blur,weight in ((1,3,2.3,.59),(3,7,6,.37),(4,12,12,.22)):
        band = Image.new("L",alpha.size)
        band.paste(alpha,(dx,dy))
        band = band.filter(ImageFilter.GaussianBlur(blur))
        transmission *= 1-weight*np.asarray(band,dtype=np.float32)/255
    field = Image.new("RGBA",alpha.size)
    field.putalpha(Image.fromarray(np.rint(255*(1-transmission)).astype(np.uint8)))
    return field


def build():
    OUT.mkdir(exist_ok=True)
    idle = json.loads((HERE/"tracks.js").read_text().split("=", 1)[1].strip().rstrip(";"))
    fps = idle["fps"]
    timings = [f["ms"] for f in idle["clusters"][0]["tracks"][0]["frames"]]
    assert len(timings) == 16 and all(ms == 1000/fps for ms in timings)
    full = (0, 0, *SIZE)
    master = Image.open(MASTER/"Figma crest.png").convert("RGBA").crop((0, 0, *SIZE))
    back = shade(registered(2, "paint", full), static_shading(2, full))
    back.save(OUT/"back.webp", lossless=True)
    front = Image.new("RGBA", SIZE)
    for i in range(14, len(LAYERS)):
        front.alpha_composite(registered(i, "paint", full))
    upper = master.copy()
    upper.putalpha(front.getchannel("A"))
    upper.save(OUT/"front.webp", lossless=True)
    nibs = Image.new("RGBA", SIZE)
    for c in CLUSTERS:
        row = LAYERS[c.index]
        nib = registered(c.index, "paint", full)
        lip = Image.new("L", SIZE)
        ImageDraw.Draw(lip).polygon([(row["x"]+x,row["y"]+y) for x,y in c.lip],fill=255)
        nib.putalpha(ImageChops.multiply(lip,nib.getchannel("A")))
        colored = master.copy()
        colored.putalpha(nib.getchannel("A"))
        nibs.alpha_composite(colored)
    nibs.save(OUT/"nibs.webp", lossless=True)

    active = Image.new("L", SIZE)
    tracks = []
    outward = list(range(9))
    sequence = outward + outward[-2:0:-1]
    for i, end, delay, last_idle_pose in TRACKS:
        row = LAYERS[i]
        pad = 52
        x,y = row["x"]-pad,row["y"]-pad
        w,h = row["w"]+2*pad,row["h"]+2*pad
        box = (x,y,w,h)
        original = registered(i,"paint",box)
        pivot = stem_anchor(original,end)
        light = static_shading(i,box)
        # Clear all the old static paint and contact even where new tips uncover it.
        for kind in ("paint","field"):
            active = ImageChops.lighter(active,registered(i,kind,full).getchannel("A"))
        cols = 4 if i == 8 else 3
        paint_sheet = Image.new("RGBA",(cols*w,cols*h))
        field_sheet = Image.new("RGBA",paint_sheet.size)
        for k,cel in enumerate(registered_drawings(i,end,original,pivot)):
            assert stem_anchor(cel,end) == pivot, (row["name"], k)
            contact = leaf_contact(cel.getchannel("A"))
            pos = ((k%cols)*w,(k//cols)*h)
            paint_sheet.paste(shade(cel,light),pos)
            field_sheet.paste(contact,pos)
            for tile in (cel,contact):
                alpha = tile.getchannel("A")
                l,t,r,b = alpha.getbbox()
                assert l>0 and t>0 and r<w and b<h, (row["name"],k)
                mask = Image.new("L",SIZE)
                mask.paste(alpha,(x,y))
                active = ImageChops.lighter(active,mask)
        prefix = f"leaf-{i}"
        paint_sheet.save(OUT/(prefix+".webp"),lossless=True,method=3)
        field_sheet.save(OUT/(prefix+"-contact.webp"),lossless=True,method=3)
        tracks.append(dict(name=row["name"],prefix=prefix,slot=list(box),pivot=list(pivot),
                           delay=delay,columns=cols,frames=(list(range(16)) if i == 8 else
                               [round(k*last_idle_pose/8) for k in sequence]),
                           casters=[j-8 for j in row["casters"] if 8<=j<=13]))
    mask = Image.new("RGBA",SIZE)
    mask.putalpha(active.point(lambda a: 255 if a else 0).filter(ImageFilter.MaxFilter(5)))
    mask.save(OUT/"region.webp",lossless=True)
    spec = dict(size=SIZE,fps=fps,frameMs=timings[0],period=sum(timings),tracks=tracks)
    (OUT/"idle.js").write_text("const crownIdle = "+json.dumps(spec,indent=2)+";\n")
    print(f"{len(tracks)} crown layers, {fps} fps, {sum(timings)} ms; all sprite gutters clear.")


if __name__ == "__main__":
    build()
