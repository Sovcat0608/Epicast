"""Rebuild the clean Figma layers, their contact fields and the registered game source."""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
import csv
import json
import numpy as np
from PIL import Image, ImageChops, ImageFilter

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / 'artifacts/restoration-maple-pose'
OUT.mkdir(parents=True, exist_ok=True)
pose = json.loads((HERE / 'preferred-pose.json').read_text())
canvas = tuple(pose['size'])
parts = pose['parts']
updates = {'Purple fan - left': 'maple-left', 'Purple fan - right': 'maple-right',
           'Basal purple leaf': 'maple-basal', 'Feather cluster - right': 'feather-right'}
clean_layers = []
fields = []

def rgba(size):
    return Image.new('RGBA', size)

def source_tile(archive, part, row):
    image = Image.open(BytesIO(archive.read(f"Paint/{int(row['back_to_front']):02d} - {part}.png"))).convert('RGBA')
    if part in updates:
        revised = Image.open(HERE / (updates[part] + '-paint.png')).convert('RGBA')
        # The revised file retained the original paint rectangle inside the shadow-padded tile.
        x, y, r, b = image.getbbox()
        assert revised.size == (r-x, b-y)
        tile = rgba(image.size)
        tile.paste(revised, (x,y))
        image = tile
    return image

with ZipFile(HERE.parent / 'restoration-shadow-playground/Restoration-contact-shadow-assets.zip') as archive:
    rows = {r['part']:r for r in csv.DictReader(archive.read('Rest positions.csv').decode().splitlines()) if r['part']}
    for i, p in enumerate(parts):
        tile = source_tile(archive, p['part'], rows[p['part']])
        size = (p['w'],p['h'])
        # Match Figma FIT, including subpixel aspect differences after the user's resize.
        ratio = min(size[0]/tile.width,size[1]/tile.height)
        scaled = tile.resize((round(ratio*tile.width),round(ratio*tile.height)),Image.Resampling.LANCZOS)
        paint = rgba(size)
        paint.alpha_composite(scaled,((size[0]-scaled.width)//2,(size[1]-scaled.height)//2))
        paint.save(OUT/f'{i}-paint.png')
        full = rgba(canvas)
        full.alpha_composite(paint,(p['x'],p['y']))
        clean_layers.append(full)
        alpha = full.getchannel('A')
        def falloff(dx, dy, radius):
            shifted = Image.new('L', canvas)
            shifted.paste(alpha,(dx,dy))
            return np.asarray(shifted.filter(ImageFilter.GaussianBlur(radius)),dtype=float)/255
        # At the approved pose the cuffs sit over the leaves and the maples over the quills.
        # Build in frame pixels so the larger leaf does not cast an inflated blur.
        tight = .36 * falloff(1,3,2.5)
        soft = .22 * falloff(2,6,7)
        boughs = p['part'] == 'Boughs, wraps and jewelry'
        if boughs or p['part'] in ('Purple fan - left','Purple fan - right','Basal purple leaf'):
            yy,xx = np.ogrid[:canvas[1],:canvas[0]]
            centers = ((255,526),(620,526),(440,755)) if boughs else ((p['x']+.52*p['w'],p['y']+.61*p['h']),)
            focus = np.maximum.reduce([np.exp(-.5*(((xx-x)/77)**2+((yy-y)/55)**2)) for x,y in centers])
            soft = (.22+.42*focus)*falloff(2,7,8)
        field = Image.fromarray(np.rint(255*(1-(1-tight)*(1-soft))).astype('uint8'))
        fields.append(field)
        box = field.getbbox()
        shadow = rgba((box[2]-box[0],box[3]-box[1]))
        shadow.putalpha(field.crop(box))
        shadow.save(OUT/f'{i}-field.png')
        p['field'] = list(box)

result = rgba(canvas)
coverage = rgba(canvas)
for i, paint in enumerate(clean_layers):
    # Darken lower paint only. Its alpha, including gaps between blades, is invariant.
    shaded = ImageChops.multiply(result.convert('RGB'), ImageChops.invert(fields[i]).convert('RGB')).convert('RGBA')
    shaded.putalpha(result.getchannel('A'))
    result = Image.alpha_composite(shaded,paint)
    coverage.alpha_composite(paint)
assert result.getchannel('A').tobytes()==coverage.getchannel('A').tobytes()
for a,b in ((12,11),(13,10),(19,12),(19,13),(19,14)):
    contact = ImageChops.multiply(fields[a],clean_layers[b].getchannel('A'))
    assert contact.getextrema()[1]>50 and contact.getbbox(), (a,b)
result.save(OUT/'preferred-pose.png')
(OUT/'layers.json').write_text(json.dumps(parts))

# Same visible width and optical center as the previous Restoration texture,
# preserving the Figma aspect ratio and all vine/leaf tips.
box = result.getbbox()
assert box[0]>0 and box[1]>0 and box[2]<canvas[0] and box[3]<canvas[1]
art = result.crop(box)
art.thumbnail((628,805),Image.Resampling.LANCZOS)
registered = rgba((660,880))
registered.alpha_composite(art,((660-art.width)//2, round(444.5-art.height/2)))
registered.save(HERE/'Restoration preferred pose.png',optimize=True)
(OUT/'restoration.bgra').write_bytes(registered.tobytes('raw','BGRA'))
print('Visible bounds:', registered.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox())
