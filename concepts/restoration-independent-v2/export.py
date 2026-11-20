"""Export the editable study, native Figma contact setup, and review plates."""
import base64
import hashlib
import json
import zipfile
from xml.etree import ElementTree as ET

from PIL import ImageDraw, ImageFont
from register import ROOT, SRC, SIZE, ORDER, LABELS, GROUP_NAMES, LAYOUT, pieces, clear, dark, encode, fields, paint, render, Image, np

def sha(data):
    return hashlib.sha256(data).hexdigest()

def sprite(im):
    bounds = im.getchannel('A').getbbox()
    if bounds is None:
        return None
    x, y, right, bottom = bounds
    return dict(x=x, y=y, w=right-x, h=bottom-y,
                png=base64.b64encode(encode(im.crop(bounds))).decode('ascii'))

def image_node(group, name, data):
    if data:
        ET.SubElement(group, 'image', {
            'id': name, 'x': str(data['x']), 'y': str(data['y']), 'width': str(data['w']), 'height': str(data['h']),
            'xlink:href': 'data:image/png;base64,' + data['png']})

layers = ROOT/'PNG layers'
layers.mkdir(exist_ok=True)
svg = ET.Element('svg', {'xmlns':'http://www.w3.org/2000/svg','xmlns:xlink':'http://www.w3.org/1999/xlink',
                         'width':'660','height':'880','viewBox':'0 0 660 880'})
crest, stamps = render(export_stamps=True)
crest.save(ROOT/'Restoration.png', optimize=True)
assets = []
for key in ORDER:
    name = GROUP_NAMES[key]
    paint[key].save(layers/(name+'.png'), optimize=True)
    if len(pieces[key]) > 1:
        individuals = ROOT/'Individual pieces'/name
        individuals.mkdir(exist_ok=True, parents=True)
        for j, (isolated, registration) in enumerate(zip(pieces[key], LAYOUT[key]),1):
            sheet, tile = registration[:2]
            isolated.save(individuals/f'{j:02} - {sheet} {tile+1}.png', optimize=True)
    layer = ET.SubElement(svg, 'g', {'id':name.replace(' ','-').replace(',',''),'data-name':name})
    ET.SubElement(layer,'title').text = name
    image_node(layer, key+'-contact', sprite(stamps[key]))
    p = sprite(paint[key])
    image_node(layer, key+'-paint', p)
    assets.append(dict(name=name, paint=p, field=sprite(dark(np.asarray(fields[key])/255))))
ET.ElementTree(svg).write(ROOT/'Restoration-layers.svg',encoding='utf-8',xml_declaration=True)

native = ROOT/'Figma contact shadows'
native.mkdir(exist_ok=True)
manifest = {'name':'Epicast Restoration · layered repaint','id':'1853074561971348820','api':'1.0.0',
            'main':'build.js','editorType':['figma'],'documentAccess':'dynamic-page','networkAccess':{'allowedDomains':['none']}}
(native/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
(native/'build.js').write_text((SRC/'figma-build.js').read_text(encoding='utf8') +
    '\nconst assets = ' + json.dumps(assets,separators=(',',':')) +
    ';\nfigma.skipInvisibleInstanceChildren = false;\nbuildReview(assets);\nfigma.closePlugin("Restoration created. Move the Pose frame inside a source component.");\n',encoding='utf8')

def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/'+('segoeuib.ttf' if bold else 'segoeui.ttf'),size)

def photo(im, size, bg='#797773', region=None):
    if region:
        im = im.crop(region)
    flat = Image.new('RGBA',im.size,bg)
    flat.alpha_composite(im)
    return flat.convert('RGB').resize(size,Image.Resampling.LANCZOS)
def caption(draw, xy, message, size=19):
    draw.text(xy,message,font=font(size,True),fill='#f5eadb')
board = Image.new('RGB',(1284,774),'#1c2326')
d = ImageDraw.Draw(board)
off = render(shadows=False)
for i, (title, im) in enumerate([('Paint only',off),('Contact shadows',crest)]):
    x=18+i*375
    caption(d,(x,15),title)
    board.paste(photo(im,(358,477)),(x,55))
    board.paste(photo(im,(358,149),region=(439,207,637,289)),(x,560))
    d.text((x,725),'Shoulder over foliage',font=font(16),fill='#d5cabc')
for i,(title,region) in enumerate([('Carved fork and gold eyelets',(182,342,492,550)),('Feather and understory',(62,410,282,608)),('Painted linen and moss',(366,192,593,395))]):
    y=16+i*247
    caption(d,(782,y),title,17)
    thumb=photo(crest,(int((region[2]-region[0])*202/(region[3]-region[1])),202),region=region)
    board.paste(thumb,(782,y+35))
board=board.crop((0,0,1110,774))
board.save(ROOT/'Restoration-shadow-comparison.png',optimize=True)

live=Image.open(SRC/'references'/'live-restoration.png').convert('RGBA')
pair=Image.new('RGB',(880,626),'#1c2326');pd=ImageDraw.Draw(pair)
for i,(title,im) in enumerate([('Live Restoration',live),('Layered repaint',crest)]):
    x=14+440*i
    caption(pd,(x,12),title)
    pair.paste(photo(im,(410,547)),(x,50))
pair.save(ROOT/'Restoration-live-comparison.png',optimize=True)

guide=Image.new('RGB',(1176,750),'#1c2326'); d=ImageDraw.Draw(guide)
short=LABELS
for i, (key,label) in enumerate(zip(ORDER,short)):
    col=i%3; row=i//3; x=12+col*389; y=12+row*246
    d.rounded_rectangle((x,y,x+375,y+229),radius=8,fill='#353c3b')
    obj=paint[key].crop(paint[key].getchannel('A').getbbox())
    obj.thumbnail((351,183),Image.Resampling.LANCZOS)
    guide.paste(obj,(x+(375-obj.width)//2,y+8+(183-obj.height)//2),obj)
    caption(d,(x+12,y+191),label,17)
guide.save(ROOT/'Restoration-layer-guide.png',optimize=True)

pose={'canopy':(-5,-3), 'purple':(6,-4), 'sprout':(3,-3), 'feathers':(-5,3), 'glyph':(0,-2)}
states=[('Rest',{},()),('Foliage offset',pose,()),('Opposite offset',{k:(-x,-y) for k,(x,y) in pose.items()},()),
        ('Roots offset',{'roots':(12,6)},()),('Boughs and jewelry hidden',{},('front',))]
sheet=Image.new('RGB',(1250,363),'#1c2326');sd=ImageDraw.Draw(sheet)
for i,(label,offsets,hidden) in enumerate(states):
    pic=render(offsets,hidden)
    assert np.array_equal(np.asarray(pic.getchannel('A')),np.asarray(render(offsets,hidden,shadows=False).getchannel('A')))
    sheet.paste(photo(pic,(229,305)),(10+250*i,10))
    caption(sd,(11+250*i,326),label,16)
sheet.save(ROOT/'Restoration-pose-check.png',optimize=True)

# Read back the actual SVG and compare on opaque and transparent areas.
reconstructed=clear()
doc=ET.parse(ROOT/'Restoration-layers.svg')
ns={'s':'http://www.w3.org/2000/svg'}
groups=doc.findall('s:g',ns)
assert len(groups)==len(ORDER)
from io import BytesIO
for group in groups:
    for bitmap in group.findall('s:image',ns):
        embedded=base64.b64decode(bitmap.get('{http://www.w3.org/1999/xlink}href').split(',')[1],validate=True)
        reconstructed.alpha_composite(Image.open(BytesIO(embedded)),(int(bitmap.get('x')),int(bitmap.get('y'))))
actual=np.asarray(crest).astype(float)/255
svg_rgba=np.asarray(reconstructed).astype(float)/255
assert not np.any(svg_rgba[:,:,3][actual[:,:,3]==0])
def on_gray(a):
    return a[:,:,:3]*a[:,:,3,None]+.46*(1-a[:,:,3,None])
svg_mae=float(np.mean(np.abs(on_gray(actual)-on_gray(svg_rgba)))*255)
assert svg_mae<.5,svg_mae
for k in ORDER:
    assert np.array_equal(np.asarray(render(hidden=set(ORDER)-{k})),np.asarray(paint[k]))
    f=layers/(GROUP_NAMES[k]+'.png')
    assert np.array_equal(np.asarray(Image.open(f)),np.asarray(paint[k]))
    assert f.stat().st_size>1000
assert len(pieces['roots'])==len(pieces['base'])==len(pieces['front'])==1
assert len(pieces['feathers'])==2
root_only=render(hidden=set(ORDER)-{'roots'})
base_only=render(hidden=set(ORDER)-{'base'})
assert root_only.getbbox()[3]>base_only.getbbox()[3]+100
# A single generated sprite supplies all the wood and wraps above the purple fans.
assert len(pieces['front'])==1
carrier = np.asarray(paint['front'].getchannel('A')) > 160
for leaf in (pieces['purple'][0],pieces['purple'][2]):
    assert np.count_nonzero(carrier & (np.asarray(leaf.getchannel('A')) > 160)) > 100
lightdiff=np.asarray(off).astype('int16')[:,:,:3]-np.asarray(crest).astype('int16')[:,:,:3]
shoulder=lightdiff[175:285,497:608].mean(axis=2)
assert (shoulder>12).sum()>350
assert (lightdiff[280:630].max(axis=2)>5).any()
stats={'canvas':SIZE,'layer_order':LABELS,'generated_source_sheets':len(list(SRC.glob('*.png'))),
       'whole_registered_sprites':sum(len(x) for x in LAYOUT.values()),
       'registration_scale':'Uniform per piece, with transparent fractional bottom padding',
       'contact_field_only_on_painted_receivers':True,'all_solo_layers_match_clean_png':True,
       'test_poses':[s[0] for s in states],'offset_pose':pose,
       'independent_root_layer':True,'single_branch_and_jewelry_paint':True,'shoulder_pixels_darkened_by_12_or_more':int((shoulder>12).sum()),
       'resting_svg_mean_difference_on_gray_8bit':round(svg_mae,4),'native_Figma_visual_test':'pending',
       'source_sha256':{p.name:sha(p.read_bytes()) for p in sorted(SRC.glob('*.png'))}}
(SRC/'verification.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
print(json.dumps({k:v for k,v in stats.items() if k not in ('source_sha256','offset_pose')},indent=2))

