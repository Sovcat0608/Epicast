"""Build a portable set of 1:1 paint, caster fields and alpha masks for Restoration."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import csv
import io
import json
import sys
from PIL import Image
import numpy as np

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parent / 'restoration-independent-v2'))
from register import ORDER, SIZE, pieces, piece_shadow, encode, render

NAMES = {
    'roots': ['Outer vines and leaf rosette'],
    'base': ['Leaf and moss backboard'],
    'canopy': ['Lower foliage - left', 'Lower foliage - right', 'Crown leaves - left',
               'Crown leaves - right', 'Shoulder leaves - left', 'Shoulder leaves - right',
               'Inner crown - left', 'Inner crown - right', 'Inner shoots - left', 'Inner shoots - right'],
    'sprout': ['Central sprout'],
    'feathers': ['Feather cluster - left', 'Feather cluster - right'],
    'purple': ['Purple fan - left', 'Basal purple leaf', 'Purple fan - right'],
    'support': ['Carved sprout fork'],
    'front': ['Boughs, wraps and jewelry'],
    'glyph': ['Crown glyph'],
}

def build(staging=None):
    rows = []
    manifest = io.StringIO(newline='')
    writer = csv.writer(manifest)
    writer.writerow(['back_to_front','part','x','y','width','height'])
    archive = OUT/'Restoration-contact-shadow-assets.zip'
    with ZipFile(archive,'w',ZIP_DEFLATED) as z:
        z.write(OUT/'README.md','README.md')
        z.writestr('Assembled reference.png', encode(render()))
        for key in ORDER:
            for name,paint in zip(NAMES[key],pieces[key],strict=True):
                i = len(rows)+1
                field = piece_shadow(key,paint)
                rect = Image.fromarray(np.maximum(np.array(paint.getchannel('A')),np.array(field))).getbbox()
                x,y,r,b = rect
                clean = paint.crop(rect)
                shadow = Image.new('RGBA',clean.size); shadow.putalpha(field.crop(rect))
                mask = Image.new('RGBA',clean.size,'white'); mask.putalpha(clean.getchannel('A'))
                assert shadow.getchannel('A').getextrema()[1] > 10
                assert mask.getchannel('A').tobytes()==clean.getchannel('A').tobytes()
                assert paint.crop(rect).getbbox() and 0<=x<r<=SIZE[0] and 0<=y<b<=SIZE[1]
                writer.writerow([i,name,x,y,r-x,b-y])
                row = dict(name=name,x=x,y=y,w=r-x,h=b-y)
                for folder,im in [('Paint',clean),('Contact shadows',shadow),('Receiver masks',mask)]:
                    data = encode(im)
                    z.writestr(f'{folder}/{i:02d} - {name}.png',data)
                    if staging and folder!='Receiver masks':
                        path=staging/f'{i:02d}-{folder}.png'
                        path.write_bytes(data)
                        row['paint' if folder=='Paint' else 'shadow']=str(path)
                rows.append(row)
        z.writestr('Rest positions.csv',manifest.getvalue())
    with ZipFile(archive) as z:
        assert z.testzip() is None and len(z.namelist())==3*len(rows)+3
    return rows

if __name__=='__main__':
    target=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else None
    if target: target.mkdir(parents=True,exist_ok=True)
    print(json.dumps(build(target)))

