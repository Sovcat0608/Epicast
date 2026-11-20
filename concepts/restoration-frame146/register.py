from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageChops
from contact_field import contact_field

HERE = Path(__file__).resolve().parent
SIZE = (1125, 1400)
OUT = HERE / 'registered'
OUT.mkdir(exist_ok=True)
# All positions measured in the target export. Width drives a uniform scale.
# Sheet rectangles slice clear gutters around independently painted pieces.
entries = [
 ('Gabled purple backboard','foundation',None,215,92,706),
 ('Converging roots and hanging vines','roots',None,375,930,410),
 ('Left split slats','side-pieces',(0,800,635,1247),125,784,325),
 ('Right split slats','side-pieces',(635,800,1261,1247),680,784,325),
 ('Left cheek foliage','cheeks',(0,0,887,887),294,873,237),
 ('Right cheek foliage','cheeks',(887,0,1774,887),622,875,221),
 ('Left autumn crown','upper-foliage',(0,0,519,512),96,17,367),
 ('Right green crown','upper-foliage',(519,0,1024,512),673,45,315),
 ('Left green shoulder','upper-foliage',(0,512,512,1033),28,248,272),
 ('Right autumn shoulder','upper-foliage',(512,512,1024,1033),883,309,198),
 ('Left inner crown','upper-foliage',(0,1033,512,1536),299,284,172),
 ('Right inner crown','upper-foliage',(512,1033,1024,1536),661,281,176),
 ('Ivory crown glyph','center-pieces',(670,645,1312,1199),509,198,122),
 ('Left bound feathers','side-pieces',(0,0,640,800),39,446,196),
 ('Right bound feathers','side-pieces',(640,0,1261,800),895,446,190),
 ('Rejuvenation leaf','center-pieces',(0,0,664,646),453,410,230),
 ('Carved sprout fork','center-pieces',(0,646,675,1199),382,575,376),
 ('Forehead shoot','center-pieces',(664,0,1312,645),533,725,153),
 ('Boughs, printed wraps, charms and treant','front',None,164,150,817)
]

feathers = [e for e in entries if 'bound feathers' in e[0]]
entries = feathers + [e for e in entries if e not in feathers]
result = Image.new('RGBA',SIZE)
union = Image.new('RGBA',SIZE)
paints,shades,rows=[],[],[]
for i,(name,file,box,x,y,width) in enumerate(entries):
    im = Image.open(HERE/'sources'/(file+'.png')).convert('RGBA')
    if box: im=im.crop(box)
    box=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
    im=im.crop(box)
    w,h=width,round(width*im.height/im.width)
    art=im.resize((w,h),Image.Resampling.LANCZOS)
    art.save(OUT/f'{i:02}-paint.png')
    full=Image.new('RGBA',SIZE)
    full.alpha_composite(art,(x,y))
    alpha=full.getchannel('A')
    field = contact_field(alpha, name, x, y)
    bounds=field.getbbox()
    shade=Image.new('RGBA',(bounds[2]-bounds[0],bounds[3]-bounds[1]))
    shade.putalpha(field.crop(bounds));shade.save(OUT/f'{i:02}-field.png')
    union.alpha_composite(full)
    rows.append(dict(name=name,x=x,y=y,w=w,h=h,sx=bounds[0],sy=bounds[1],sw=shade.width,sh=shade.height,casters=[]))
    paints.append(alpha);shades.append(field)
# Link every higher caster with an overlap or a possible contact within a short motion.
for i,row in enumerate(rows):
    rx,ry,rw,rh=row['x'],row['y'],row['w'],row['h']
    for j in range(i+1,len(rows)):
        s=rows[j]
        if rx+rw+32>s['sx'] and s['sx']+s['sw']+32>rx and ry+rh+32>s['sy'] and s['sy']+s['sh']+32>ry:
            row['casters'].append(j)
# Inner blades face the key light and the right quills sit clear of the cuff.
# Set strength on the receiver's linked instance so moving the bough still
# displaces every contact from the same source field.
front = 'Boughs, printed wraps, charms and treant'
relief = {'Left inner crown': .65, 'Right inner crown': .70, 'Right bound feathers': .85}
for i,row in enumerate(rows):
    art = Image.open(OUT/f'{i:02}-paint.png').convert('RGBA')
    x,y = row['x'],row['y']
    box = (x,y,x+art.width,y+art.height)
    transmission = np.ones((art.height, art.width), np.float32)
    row['contactStrength'] = {}
    for j in row['casters']:
        weight = relief.get(row['name'], 1.) if rows[j]['name']==front else 1.
        if weight!=1.:
            row['contactStrength'][rows[j]['name']] = weight
        transmission *= 1. - weight*np.asarray(shades[j].crop(box),dtype=np.float32)/255
    light = Image.fromarray(np.rint(255*transmission).astype(np.uint8)).convert('RGB')
    shaded = ImageChops.multiply(art.convert('RGB'), light).convert('RGBA')
    shaded.putalpha(art.getchannel('A'))
    result.alpha_composite(shaded,(x,y))
assert union.getchannel('A').tobytes()==result.getchannel('A').tobytes()
result.save(HERE/'Restoration.png')
result.thumbnail((162,216),Image.Resampling.LANCZOS);result.save(HERE/'interface-size.png')
(HERE/'registration.json').write_text(json.dumps(rows,indent=2))

