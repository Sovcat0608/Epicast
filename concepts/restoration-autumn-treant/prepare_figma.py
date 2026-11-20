"""Register the autumn paintings to Frame 145 and rebuild silhouette contact fields."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE.parent / 'restoration-rejuvenation'))
from prepare_pose import contact_field

BASE = ROOT / 'artifacts/restoration-rejuvenation-pose'
OUT = ROOT / 'artifacts/autumn-figma'
NAMES = {1: 'autumn-rosette', 2: 'smooth-maple-right', 6: 'autumn-crown',
         7: 'autumn-shoulder', 10: 'smooth-maple-left', 17: 'autumn-shoot', 18: 'treant-face'}


def silhouette(image):
    return image.getchannel('A').point(lambda a: 255 if a > 10 else 0).getbbox()


def fit_asset(source, box, anchor):
    l, t, r, b = box
    art = source.crop(silhouette(source))
    scale = min((r-l) / art.width, (b-t) / art.height)
    art = art.resize((round(art.width*scale), round(art.height*scale)), Image.Resampling.LANCZOS)
    return art, (round(l+(r-l-art.width)*anchor[0]), round(t+(b-t-art.height)*anchor[1]))


def replace_pendant(tile, face):
    # Trace only the old plaque at its junction with the boughs. The charms
    # and upper bough remain original clean paint, including their underlap.
    points = [(54,176),(62,156),(77,136),(98,114),(121,98),(145,88),
              (175,70),(192,53),(208,49),(250,49),(275,53),(303,75),
              (337,94),(361,114),(384,146),(397,170),(418,185),
              (418,405),(42,405),(42,187)]
    mask = Image.new('L', tile.size)
    ImageDraw.Draw(mask).polygon([(355+x,780+y) for x,y in points],fill=255)
    tile.putalpha(ImageChops.subtract(tile.getchannel('A'),mask))
    face, origin = fit_asset(face,(408,822,763,1176),(.5,.5))
    tile.alpha_composite(face,origin)
    for name, x in [('Moon',150),('Tree',782)]:
        swatch = Image.open(HERE / (name + ' wrap registered.png')).convert('RGBA')
        tile.paste(swatch, (x,500))
    return tile


def build():
    OUT.mkdir(exist_ok=True,parents=True)
    layout = json.loads((HERE/'pose.json').read_text())
    report = []
    result = Image.new('RGBA',(879,1093))
    union = Image.new('RGBA',result.size)
    for i,p in enumerate(layout):
        tile = Image.open(BASE/f'{i}-paint.png').convert('RGBA')
        if i in NAMES:
            source = Image.open(HERE/(NAMES[i]+'.png')).convert('RGBA')
            if i == 18:
                tile = replace_pendant(tile, source)
            else:
                anchor = {1:(.5,0),2:(0,0),6:(1,1),7:(0,0),10:(1,0),17:(1,1)}[i]
                art, pos = fit_asset(source,silhouette(tile),anchor)
                tile = Image.new('RGBA',tile.size)
                tile.alpha_composite(art,pos)
            tile.save(OUT/f'{i}-paint.png')
        inverse = np.linalg.inv(np.vstack((p['pose'],[0,0,1])))[:2]
        paint = tile.transform(result.size,Image.Transform.AFFINE,tuple((tile.width/p['w']*inverse).flat),Image.Resampling.BICUBIC)
        field = contact_field(paint.getchannel('A'), p['name'])
        if i == 18:
            # The projecting chin sits directly above the rosette. Concentrate
            # its wider contact there, leaving the outside of the crest transparent.
            chin = np.asarray(p['pose']) @ np.array([290, 563, 1])
            yy, xx = np.ogrid[:result.height, :result.width]
            focus = np.exp(-.5*(((xx-chin[0])/56)**2 + ((yy-chin[1])/29)**2))
            falloff = Image.new('L', result.size)
            falloff.paste(paint.getchannel('A'),(1,5))
            extra = .28 * focus * np.asarray(falloff.filter(ImageFilter.GaussianBlur(8))) / 255
            field = Image.fromarray(np.rint(255-(255.-np.asarray(field))*(1-extra)).astype('uint8'))
        box = field.getbbox()
        if i in NAMES:
            shade = Image.new('RGBA',(box[2]-box[0],box[3]-box[1]))
            shade.putalpha(field.crop(box))
            shade.save(OUT/f'{i}-field.png')
            shift = np.eye(3)
            shift[:2,2] = box[:2]
            report.append(dict(index=i,size=shade.size,m=(inverse@shift).tolist()))
        shaded = ImageChops.multiply(result.convert('RGB'),ImageChops.invert(field).convert('RGB')).convert('RGBA')
        shaded.putalpha(result.getchannel('A'))
        result = Image.alpha_composite(shaded,paint)
        union.alpha_composite(paint)
    assert result.getchannel('A').tobytes()==union.getchannel('A').tobytes()
    result.save(OUT/'crest.png')
    (OUT/'fields.json').write_text(json.dumps(report))


if __name__ == '__main__':
    build()
