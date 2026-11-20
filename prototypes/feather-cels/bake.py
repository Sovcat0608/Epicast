"""Register two rows of independently painted feather cels for the Restoration idle study."""
import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
MASTER = HERE.parents[1] / "concepts/restoration-frame146"
LAYERS = json.loads((MASTER / "registration.json").read_text())
W, H = 256, 512


@dataclass(frozen=True)
class Cluster:
    index: int
    slot: tuple
    anchor: tuple
    tips: tuple  # rear, front in registered paint coordinates
    lip: tuple
    nib_orientation: int
    prefix: str
    sheet: str
    crops: tuple  # rear, front on the source sheet

    @property
    def pivot(self):
        paint = LAYERS[self.index]
        return (paint["x"] + self.anchor[0] - self.slot[0],
                paint["y"] + self.anchor[1] - self.slot[1])


CLUSTERS = (
    Cluster(0, (8,368), (149,49), ((105,306),(12,351)),
            ((0,0),(196,0),(196,79),(162,79),(160,74),(154,67),
             (148,63),(142,61),(137,62),(127,68),(0,68)), 1, "",
            "painted-poses.png", ((869,404,1303,724),(869,0,1303,404))),
    Cluster(1, (861,368), (41,48), ((83,280),(177,331)),
            ((0,0),(190,0),(190,62),(60,62),(52,60),(46,60),
             (40,62),(34,66),(30,73),(28,79),(0,79)), -1, "right-",
            "right-painted-blades.png", ((770,0,1254,1254),(0,0,770,1254))),
)
FPS, FRAMES = 8, 16
TRACKS = [
    dict(name="rear", swing=1.5, curl=.75, delay=125, gain=.80),
    dict(name="front", swing=1.75, curl=.9, delay=0, gain=.94),
]


def layer(cluster, index, field=False):
    X, Y = cluster.slot
    p, kind = ("s", "field") if field else ("", "paint")
    im = Image.open(MASTER / "registered" / f"{index:02}-{kind}.png").convert("RGBA")
    tile = Image.new("RGBA", (W, H))
    row = LAYERS[index]
    tile.paste(im, (row[p+"x"]-X, row[p+"y"]-Y))
    return tile


def field_opacity(im):
    return np.asarray(im.getchannel("A"), dtype=np.float32) / 255


def contact_light(cluster):
    light = np.ones((H, W), dtype=np.float32)
    for caster in LAYERS[cluster.index]["casters"]:
        strength = LAYERS[cluster.index]["contactStrength"].get(LAYERS[caster]["name"], 1)
        light *= 1 - strength * field_opacity(layer(cluster, caster, True))
    return light


def fixed_front(cluster):
    X, Y = cluster.slot
    feather = layer(cluster, cluster.index)
    paint = LAYERS[cluster.index]
    offset_x, offset_y = paint["x"]-X, paint["y"]-Y
    mask = Image.new("L", (W*4,H*4))
    ImageDraw.Draw(mask).polygon([((offset_x+x)*4,(offset_y+y)*4) for x,y in cluster.lip], fill=255)
    alpha = field_opacity(feather) * np.asarray(mask.resize((W,H),Image.Resampling.LANCZOS)) / 255
    for i in range(cluster.index+1, len(LAYERS)):
        coverage = field_opacity(layer(cluster, i))
        alpha += (1-alpha)*coverage
    # Take the upper layers' exact approved color from the assembled crest.
    front = Image.open(MASTER / "Figma crest.png").convert("RGBA").crop((X,Y,X+W,Y+H))
    front.putalpha(Image.fromarray(np.uint8(np.rint(255*np.clip(alpha,0,1)))))
    return front


def register(art, cluster, tip):
    # Use one painted model per blade so its notches and highlight stay consistent.
    alpha = art.getchannel("A")
    support = alpha.point(lambda v: 255 if v > 16 else 0).filter(ImageFilter.MaxFilter(5))
    art.putalpha(ImageChops.multiply(alpha, support))
    yy, xx = np.where(field_opacity(art) > .5)
    top, bottom = yy.min(), yy.max()
    p = np.array([xx[yy < top+5].mean(), top+1])
    end = np.array([xx[yy > bottom-5].mean(), bottom-1])
    source = end - p
    target = np.array(tip, dtype=float) - cluster.anchor
    relative = complex(*source) / complex(*target)
    a, b = relative.real, relative.imag
    cx, cy = cluster.pivot
    matrix = (a,-b,p[0]-a*cx+b*cy, b,a,p[1]-b*cx-a*cy)
    return art.convert("RGBa").transform((W,H), Image.Transform.AFFINE, matrix,
                                         Image.Resampling.BICUBIC)


def wind_cel(model, cluster, tip, track, frame, light, *, swing=None, canvas_offset=(0, 0)):
    cx, cy = cluster.pivot
    cx += canvas_offset[0]
    cy += canvas_offset[1]
    width, height = model.size
    # Both clusters lean screen-right during the gust and relax together.
    # The curl follows the wind in the same screen coordinates as the swing.
    if swing is None:
        swing = -np.cos(2 * np.pi * frame / FRAMES)
    angle = -np.deg2rad(track["swing"] * swing)
    axis = np.array(tip, dtype=float) - cluster.anchor
    length = np.linalg.norm(axis)
    dx, dy = axis / length
    curvature = -np.deg2rad(track["curl"]) * max(0.0, swing)**2 / length
    yy, xx = np.indices((height, width), dtype=float)
    x, y = xx - cx, yy - cy
    # Inverse swing, then inverse circular arc in shaft coordinates. Curvature
    # has a single sign along the full blade, and is zero on the inward swing.
    u = np.cos(angle)*x + np.sin(angle)*y
    v = -np.sin(angle)*x + np.cos(angle)*y
    along, across = dx*u + dy*v, -dy*u + dx*v
    if abs(curvature) > 1e-10:
        ku, kv = curvature*along, curvature*across
        radius = np.hypot(ku, 1-kv)
        arc = np.arctan2(ku, 1-kv) / curvature
        offset = (2*across - curvature*(along**2 + across**2)) / (1+radius)
        along, across = arc, offset
    # Bake into fixed-size transparent cels. Interpolate premultiplied paint.
    sx = np.clip(cx + dx*along - dy*across, 0, width-1)
    sy = np.clip(cy + dy*along + dx*across, 0, height-1)
    x0, y0 = sx.astype(int), sy.astype(int)
    x1, y1 = np.minimum(x0+1, width-1), np.minimum(y0+1, height-1)
    fx, fy = (sx-x0)[...,None], (sy-y0)[...,None]
    p = np.asarray(model)
    sample = ((1-fy)*((1-fx)*p[y0,x0]+fx*p[y0,x1])
              + fy*((1-fx)*p[y1,x0]+fx*p[y1,x1]))
    rgba = np.array(Image.frombytes("RGBa", (width,height), np.uint8(np.rint(sample)).tobytes()).convert("RGBA"))
    rgba[..., :3] = np.rint(rgba[..., :3]*light[...,None]*track["gain"]).astype(np.uint8)
    return Image.fromarray(rgba)


def build_cluster(cluster):
    sheet = Image.open(HERE/cluster.sheet).convert("RGBA")
    light = contact_light(cluster)
    cover = cluster.prefix + "fixed-front.png"
    fixed_front(cluster).save(HERE/cover)
    clips = []
    cx, cy = cluster.pivot
    for track, tip, crop in zip(TRACKS, cluster.tips, cluster.crops):
        atlas = Image.new("RGBA", (4*W,4*H))
        game = Image.new("RGBA", (512,1024))
        model = register(sheet.crop(crop), cluster, tip)
        for i in range(FRAMES):
            cel = wind_cel(model, cluster, tip, track, i, light)
            bounds = cel.getchannel("A").getbbox()
            assert bounds and 0 < bounds[0] and bounds[2] < W and bounds[3] < H
            assert cel.getpixel(cluster.pivot)[3] > 200
            # Verify an opaque shaft from inside the nib to beyond its mouth.
            for depth in range(3, 19):
                assert cel.getpixel((cx-cluster.nib_orientation*round(depth*.25), cy+depth))[3] > 200
            col,row = i%4,i//4
            atlas.paste(cel,(col*W,row*H))
            game.paste(cel.resize((128,256),Image.Resampling.LANCZOS),(col*128,row*256))
        name = cluster.prefix + track["name"]
        atlas.save(HERE/f"{name}.png")
        game.save(HERE/f"{name}.tga")
        clips.append(dict(sheet=f"{name}.png",delay=track["delay"],
                     frames=[dict(cel=i,ms=1000//FPS) for i in range(FRAMES)]))
    return dict(slot=[*cluster.slot,W,H],pivot=cluster.pivot,cover=cover,tracks=clips)


def build():
    metadata = dict(columns=4,fps=FPS,clusters=[build_cluster(c) for c in CLUSTERS])
    (HERE/"tracks.js").write_text("const animation = "+json.dumps(metadata,indent=2)+";\n")
    print("Verified 16 cels per blade at 8 fps, transparent gutters and continuous nib overlap.")


if __name__ == "__main__":
    build()

