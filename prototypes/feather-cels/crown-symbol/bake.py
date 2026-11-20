"""Extract the original ball and crescent and prepare their light and contact layers."""
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
PREVIEW = HERE.parent
sys.path[:0] = [str(PREVIEW), str(PREVIEW.parents[1]/"animation-rnd/.deps")]
import cv2
from scipy.ndimage import distance_transform_edt
from cheek_placement import MASTER, composite, premult, rgba, registered_stack

LAYER = 14
SLOT = (424, 100, 292, 300)
GLYPH = (509, 198, 122, 109)
PIVOT = (570, 251)
PADDING = 30


def alpha_tint(mask, colour):
    paint = Image.new("RGBA",mask.size,(*colour,0))
    paint.putalpha(mask)
    return paint


def separate(glyph):
    alpha = np.asarray(glyph.getchannel("A"))
    count, labels, stats, centers = cv2.connectedComponentsWithStats(np.uint8(alpha>24))
    groups = sorted(range(1,count),key=lambda n: stats[n,cv2.CC_STAT_AREA],reverse=True)[:2]
    assert len(groups)==2 and np.count_nonzero((labels>0)&~np.isin(labels,groups))<20
    ball,moon = sorted(groups,key=lambda n: centers[n][1])
    nearest = distance_transform_edt(~np.isin(labels,groups),return_distances=False,return_indices=True)
    assigned = labels[tuple(nearest)]
    images = []
    for group in (ball,moon):
        art=glyph.copy()
        art.putalpha(Image.fromarray(np.where(assigned==group,alpha,0).astype(np.uint8)))
        images.append(art)
    assert np.array_equal(np.asarray(images[0].getchannel("A"))+np.asarray(images[1].getchannel("A")),alpha)
    return images


def lit_paint(art):
    paint = np.asarray(art,dtype=np.float32)/255
    value = np.max(paint[:,:,:3],axis=2)**.88
    palette = ([34,68,146],[62,153,251],[217,243,255])
    blue = np.stack([np.interp(value,[.13,.64,.99],channel) for channel in zip(*palette)],axis=2)
    result = Image.fromarray(np.uint8(np.rint(blue))).convert("RGBA")
    result.putalpha(art.getchannel("A"))
    return result


def glows(art):
    alpha = art.getchannel("A")
    close = alpha.filter(ImageFilter.GaussianBlur(4.6)).point(lambda v: min(255,round(v*.66)))
    wide = alpha.filter(ImageFilter.GaussianBlur(13)).point(lambda v: round(v*.73))
    glow = alpha_tint(wide,(32,113,254))
    glow.alpha_composite(alpha_tint(close,(80,179,255)))
    shade = Image.new("L",alpha.size)
    shade.paste(alpha,(2,4))
    cast = ImageChops.screen(shade.filter(ImageFilter.GaussianBlur(3.3)).point(lambda v: round(v*.33)),
                             shade.filter(ImageFilter.GaussianBlur(8.5)).point(lambda v: round(v*.18)))
    return glow,alpha_tint(cast,(13,8,24))


def contact_gap(ball,moon):
    upper = np.asarray(ball.getchannel("A"))>170
    lower = np.asarray(moon.getchannel("A"))>170
    gaps = [np.flatnonzero(b)[0]-np.flatnonzero(a)[-1]-1 for a,b in zip(upper.T,lower.T) if a.any() and b.any()]
    gap = min(gaps)
    assert gap > 0
    return int(gap)


def save(name, image):
    image.save(HERE/name,lossless=True)
    return f"crown-symbol/{name}?v=floating-crown"


def build():
    source = MASTER/"registered"/"14-paint.png"
    with Image.open(source) as glyph:
        assert glyph.size==GLYPH[2:]
        parts = separate(glyph.convert("RGBA"))
    width,height = GLYPH[2]+2*PADDING,GLYPH[3]+2*PADDING
    atlas = Image.new("RGBA",(4*width,2*height))
    for row,part in enumerate(parts):
        art = Image.new("RGBA",(width,height))
        art.paste(part,(PADDING,PADDING))
        for col,cell in enumerate((art,lit_paint(art),*glows(art))):
            atlas.paste(cell,(col*width,row*height))

    paints,fields = registered_stack(SLOT,hide_cheeks=True)
    fixed = premult(composite(paints,fields,SLOT))
    paints[LAYER] = Image.new("RGBA",SLOT[2:])
    fields[LAYER] = Image.new("L",SLOT[2:])
    bare = premult(composite(paints,fields,SLOT))
    change = np.max(np.abs(fixed-bare),axis=2)
    coverage = Image.fromarray(np.uint8((change>1/255)*255)).filter(ImageFilter.MaxFilter(5))
    # Once the fixed emblem and its field are erased, use the clean
    # recomposite at those exact pixels. Surrounding live poses stay intact.
    receiver = rgba(bare)
    receiver.putalpha(ImageChops.multiply(receiver.getchannel("A"),coverage))
    foreground = Image.new("RGBA",SLOT[2:])
    for paint in paints[LAYER+1:]:
        foreground.alpha_composite(paint)
    spec = dict(slot=SLOT,pivot=PIVOT,sprite=[GLYPH[0]-PADDING,GLYPH[1]-PADDING,width,height],
                gap=contact_gap(*parts),atlas=save("pieces.webp",atlas),
                receiver=save("receiver.webp",receiver),coverage=save("coverage.webp",alpha_tint(coverage,(0,0,0))),
                front=save("foreground.webp",alpha_tint(foreground.getchannel("A"),(0,0,0))),
                sourceSha256=hashlib.sha256(source.read_bytes()).hexdigest())
    (HERE/"track.js").write_text("const restorationCrownSymbol = "+json.dumps(spec)+";\n",encoding="utf-8")
    print("Registered both crown pieces and their contact and light. Rest gap:", spec["gap"])


if __name__ == "__main__":
    build()
