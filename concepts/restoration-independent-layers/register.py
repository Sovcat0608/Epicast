from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageDraw, ImageFont
import numpy as np, json, hashlib, base64, zipfile
from io import BytesIO

ROOT=Path(__file__).resolve().parent
OUT=ROOT
SOURCE=ROOT/'sources'
LAYERS=ROOT/'PNG layers'
LAYERS.mkdir(exist_ok=True)
SIZE=(660,880)
# Each crop is a transparent gutter on a sprite sheet. No object contours are traced or masked.
ORDER=['core','canopy','ivory','purple','sprout','glyph','front']
NAMES=['Static wood backdrop','Upper green leaves','Lower ivory leaves','Purple leaves','Central sprout','Crown glyph','Static front']
PIECES={
 'core':[(0,0,1,1,150,72,386,775)],
 'canopy':[(0,0,.5,.5,49,40,199,124),(.5,0,1,.5,436,39,151,127),(0,.5,.5,1,16,175,166,216),(.5,.5,1,1,494,176,151,200),
           (.5,.5,1,1,162,168,148,92),(0,.5,.5,1,379,171,145,93),(0,0,.5,.5,265,408,82,57),(.5,0,1,.5,346,409,81,59)],
 'bridges':[(0,0,.35,1,64,111,188,236),(.35,0,.65,1,240,315,207,193),(.65,0,1,1,425,110,174,231)],
 'ivory':[(0,0,.50,1,119,358,83,279),(.50,0,1,1,494,353,78,280)],
 'purple':[(0,0,.355,1,24,350,185,244),(.36,0,.647,1,299,592,101,166),(.65,0,1,1,477,346,165,240)],
 'sprout':[(0,0,1,1,251,260,188,147)],
 'glyph':[(0,0,1,1,309,122,74,61)],
 'front':[(0,0,.29,1,112,286,126,127),(.29,0,.70,1,214,469,260,183),(.70,0,1,1,443,282,122,127)]}
def png_bytes(im):
    f=BytesIO();im.save(f,'PNG',optimize=True);return f.getvalue()
def transparent():return Image.new('RGBA',SIZE)
def prepare(im):
    # Mimic the game's modest Druid desaturation uniformly across the new assets.
    p=np.asarray(im).copy();rgb=p[:,:,:3].astype(float)
    luma=rgb@np.array([.299,.587,.114]);p[:,:,:3]=np.uint8(np.round(.93*rgb+.07*luma[:,:,None]))
    p[p[:,:,3]==0,:3]=0
    return Image.fromarray(p)
def whole_piece(im, frac):
    x,y,r,b=frac
    tile=im.crop((round(x*im.width),round(y*im.height),round(r*im.width),round(b*im.height)))
    alpha=tile.getchannel('A')
    box=alpha.point(lambda p:255 if p>=12 else 0).getbbox();assert box
    if len(PIECES[name])>1:
        # Insist the registration crop through the contact sheet never touches a painted shape.
        for axis,v,inner in [(0,0,x>0),(0,tile.width-1,r<1),(1,0,y>0),(1,tile.height-1,b<1)]:
            if inner:
                line=alpha.crop((v,0,v+1,tile.height) if axis==0 else (0,v,tile.width,v+1))
                assert line.getextrema()[1]<=12,(name,frac,axis,v,line.getextrema())
    # Add a small gutter to keep generated antialiasing. Source originals stay untouched.
    return tile.crop((max(0,box[0]-3),max(0,box[1]-3),min(tile.width,box[2]+3),min(tile.height,box[3]+3)))
paints={};pieces={}
for name in ORDER+['bridges']:
    source_key='bridges-grooved' if name=='bridges' else name
    im=Image.open(SOURCE/(source_key+'.png')).convert('RGBA');lay=transparent();pieces[name]=[]
    for spec in PIECES[name]:
        tile=whole_piece(im,spec[:4]);x,y,w,h=spec[4:]
        tile=prepare(tile.resize((w,h),Image.Resampling.LANCZOS));piece=transparent();piece.alpha_composite(tile,(x,y))
        pieces[name].append(piece);lay=Image.alpha_composite(lay,piece)
    paints[name]=lay
# The front is one independently movable assembly. The arms cover sprig stems
# and the central fork covers the sprout foot; the fittings sit on those carvings.
paints['front']=Image.alpha_composite(paints['bridges'],paints['front'])
def pose_layer(im,dx,dy):
    surface=transparent();surface.alpha_composite(im,(dx,dy));return surface
# Local contact occlusion: darken only already-painted receiver pixels, leaving receiver alpha untouched.
# A subsequent source-over draw of the caster obscures all shading under the caster's solid paint.
OFFSET=(1,3);BLUR=2.35;OPACITY=.27
def blur_caster(im):
    mask=Image.new('L',SIZE)
    mask.paste(im.getchannel('A'),OFFSET)
    return mask.filter(ImageFilter.GaussianBlur(BLUR)).point(lambda a:round(a*OPACITY))
def render(pose={},hidden=(),shadow=True):
    surface=transparent()
    for key in ORDER:
        if key in hidden:continue
        caster=pose_layer(paints[key],*pose.get(key,(0,0)))
        if shadow:
            mask=blur_caster(caster)
            # Black contact literally only modulates RGB of existing material; no coverage is added outside it.
            tinted=ImageChops.multiply(surface.convert('RGB'),ImageChops.invert(mask).convert('RGB')).convert('RGBA')
            tinted.putalpha(surface.getchannel('A'));surface=tinted
        surface=Image.alpha_composite(surface,caster)
    return surface
def dump():
    for i,(key,label) in enumerate(zip(ORDER,NAMES)):
        (LAYERS/(f'{i+1:02d} - {label}.png')).write_bytes(png_bytes(paints[key]))
    for label,img in [('Restoration-assembled',render()),('Restoration-paint-only',render(shadow=False))]:
        img.save(OUT/(label+'.png'),optimize=True)
if __name__=='__main__':dump()

