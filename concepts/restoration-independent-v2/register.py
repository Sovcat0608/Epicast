from pathlib import Path
from io import BytesIO
import numpy as np
from PIL import Image, ImageChops, ImageFilter
ROOT=Path(__file__).resolve().parent
SRC=ROOT/'sources'
SIZE=(660,880)
GROUP_LABELS={
    'roots':'Dangling roots',
    'canopy':'Crown and understory foliage',
    'sprout':'Central sprout',
    'support':'Carved sprout fork',
    'feathers':'Striped white feather clusters',
    'purple':'Purple leaves',
    'glyph':'Crown glyph',
    'base':'Leaf and moss backboard',
    'front':'Night elf boughs, medallion and charms'
}
GROUP_NAMES={key:f'{i:02} - {label}' for i,(key,label) in enumerate(GROUP_LABELS.items(),1)}
ORDER=['roots','base','canopy','sprout','feathers','purple','support','front','glyph']
LABELS=[GROUP_LABELS[key] for key in ORDER]
# These rectangles follow the empty gutters between independently painted sprites.
ATLAS={
'core':[(0,0,929,1692)],'wood':[(0,0,460,1024),(460,0,1050,1024),(1050,0,1536,1024)],
'green':[(0,0,534,510),(534,0,1030,510),(1030,0,1536,510),(0,510,534,1024),(534,510,1030,1024),(1030,510,1536,1024)],
'understory':[(0,0,620,570),(620,0,1246,570),(0,570,620,1263),(620,570,1246,1263)],
'feathers':[(0,0,802,1024),(802,0,1536,1024)],'purple':[(0,0,744,809),(744,0,1248,809),(1248,0,1942,809)],
'fittings':[(0,0,505,724),(505,0,805,724),(805,0,1352,724),(1352,0,1650,724),(1650,0,2172,724)],
'pine':[(0,0,887,887),(887,0,1774,887)],'pendants':[(0,0,768,1024),(768,0,1536,1024)],
'yoke':[(0,0,2172,724)],'sprout':[(0,0,1457,1080)],'glyph':[(0,0,1536,1024)]}
# Back to front within each group. Each entry specifies x, y, and width in canvas
# pixels. Height follows from the source aspect ratio.
LAYOUT={
'roots':[('roots',0,178,591,333)],
'base':[('moss-backboard',0,144,65,401)],
'canopy':[('understory',2,112,441,144),('understory',3,441,444,132),
 ('green',0,65,31,193),('green',1,406,35,158),('green',3,22,179,181),('green',4,453,184,195),
 ('green',2,171,150,125),('green',5,385,152,109),
 ('understory',0,218,395,76),('understory',1,380,398,74)],
'support':[('wood',1,244,350,198)],
'feathers':[('striped-feather-clusters',0,60,392,181),('striped-feather-clusters',1,454,388,165)],
'purple':[('purple',0,24,371,184),('purple',1,290,598,115),('purple',2,468,367,173)],
'sprout':[('sprout',0,246,239,192)],'glyph':[('glyph',0,305,119,80)],
'front':[('night-elf-boughs',0,82,91,513)]}
def clear():return Image.new('RGBA',SIZE)
def encode(im):
    out=BytesIO();im.save(out,'PNG',optimize=True);return out.getvalue()
def alpha(im):return np.asarray(im.getchannel('A'),dtype=np.float32)/255
def lmask(a):return Image.fromarray(np.uint8(np.clip(a,0,1)*255+.5))
def dark(a):
    im=Image.new('RGBA',SIZE,(0,0,0,0));im.putalpha(lmask(a));return im
def place(im,xy):
    result=clear();result.alpha_composite(im,xy);return result
def tilemap():
    tiles={}
    for key,rects in ATLAS.items():
        source_name='yoke-bracer-branches' if key=='yoke' else key
        source=Image.open(SRC/(source_name+'.png')).convert('RGBA')
        # Isolated images occasionally carry a low-alpha generator matte in their empty gutter.
        # A uniform alpha ramp removes it; no silhouettes are taken from the assembled crest.
        floor={'fittings':211,'feathers':111,'glyph':13,'wood':10,'green':10}.get(key,5)
        p=np.array(source);opacity=p[:,:,3].astype(float)
        p[:,:,3]=np.rint(255*np.clip((opacity-floor)/(249-floor),0,1)).astype('uint8')
        rgb=p[:,:,:3].astype(np.float32);grey=rgb@np.array([.299,.587,.114],np.float32)
        if key=='pine':
            luminance=grey[:,:,None]
            rgb=.42*rgb+.58*luminance+(255-luminance)*np.array([.06,.075,.09])
        p[:,:,:3]=np.rint(np.clip(.93*rgb+.07*grey[:,:,None],0,255)).astype('uint8')
        p[p[:,:,3]==0,:3]=0
        source=Image.fromarray(p)
        for i,rect in enumerate(rects):
            tile=source.crop(rect);a=np.asarray(tile)[:,:,3]
            assert max(a[0,:].max(),a[-1,:].max(),a[:,0].max(),a[:,-1].max())<15,(key,i)
            bounds=tile.getchannel('A').point(lambda v:255 if v>18 else 0).getbbox()
            assert bounds
            x,y,r,b=bounds
            tiles[key,i]=tile.crop((max(0,x-2),max(0,y-2),min(tile.width,r+2),min(tile.height,b+2)))
    sheet=Image.open(SRC/'converging-boughs.png').convert('RGBA')
    def revised(sheet,box):
        im=sheet.crop(box)
        im.putalpha(im.getchannel('A').point(lambda a:max(0,min(255,(a-32)*255/217))))
        return im.crop(im.getchannel('A').getbbox())
    for key,i,box in [('wood',1,(520,384,1008,650)),('purple',0,(0,650,548,1024)),
                      ('purple',1,(555,650,958,1024)),('purple',2,(991,650,1536,1024))]:
        tiles[key,i]=revised(sheet,box)
    for name in ['night-elf-boughs','moss-backboard']:
        sheet=Image.open(SRC/(name+'.png')).convert('RGBA')
        tiles[name,0]=revised(sheet,(0,0,*sheet.size))
    feathers=Image.open(SRC/'striped-feather-clusters.png').convert('RGBA')
    for i in range(2):
        tiles['striped-feather-clusters',i]=revised(feathers,(i*feathers.width//2,0,(i+1)*feathers.width//2,feathers.height))
    roots=Image.open(SRC/'vines-and-foliar-rosette.png').convert('RGBA')
    tiles['roots',0]=revised(roots,(0,0,*roots.size))
    return tiles
TILES=tilemap()

def scale_piece(source,width):
    scale=width/source.width
    height=int(np.ceil(scale*source.height))
    sample_height=height/scale
    # Include the fractional last output pixel in transparent space so Lanczos
    # samples both axes at the same scale.
    padded=Image.new('RGBA',(source.width,int(np.ceil(sample_height))))
    padded.paste(source,(0,0))
    return padded.resize((width,height),Image.Resampling.LANCZOS,
                         box=(0,0,source.width,sample_height))

paint={};pieces={}
for key,items in LAYOUT.items():
    paint[key]=clear();pieces[key]=[]
    for sheet,idx,x,y,width in items:
        obj=scale_piece(TILES[sheet,idx],width)
        assert x>=0 and y>=0 and x+obj.width<=SIZE[0] and y+obj.height<=SIZE[1]
        whole=place(obj,(x,y));pieces[key].append(whole);paint[key]=Image.alpha_composite(paint[key],whole)
# A tight contact edge plus a wider soft penumbra, weighted at the actual expected receivers.
# Tuple fields: center x,y; horizontal and vertical standard deviation; outward x,y shift; peak strength.
ZONES={
'front':[(112,250,43,48,-13,10,.77),(570,245,48,52,16,10,.80),
 (210,187,49,25,0,10,.64),(480,188,47,27,1,12,.64),
 (173,393,50,27,0,11,.69),(512,388,50,29,1,12,.68),
 (174,432,48,33,-4,10,.68),(507,429,48,33,5,10,.68),
 (247,475,33,24,3,7,.52),(441,476,32,24,3,7,.52),(350,486,62,19,1,7,.44),
 (348,633,61,30,2,9,.62),(245,562,22,53,4,7,.47),(441,561,23,49,4,6,.44)],
'support':[(302,389,35,40,-8,9,.48),(404,386,34,41,7,9,.46)],
'base':[(346,582,90,50,2,8,.50)],
'purple':[(158,500,45,70,7,9,.55),(528,498,43,67,-4,10,.53),(349,696,44,40,2,7,.34)],
'canopy':[(209,174,56,35,2,6,.32),(479,179,54,34,2,6,.31),(211,565,46,57,2,7,.35),(475,567,48,55,2,7,.34)],
'feathers':[(168,564,31,58,3,6,.28),(528,558,30,54,4,5,.28)],
'sprout':[(345,330,82,75,2,6,.45)],'glyph':[(346,153,43,35,1,4,.35)],'roots':[]}
Y,X=np.ogrid[0:SIZE[1],0:SIZE[0]]
def piece_shadow(key, image):
    a=image.getchannel('A')
    def press(dx,dy,blur):
        relocated=Image.new('L',SIZE);relocated.paste(a,(dx,dy))
        return np.asarray(relocated.filter(ImageFilter.GaussianBlur(blur)),np.float32)/255
    close=press(1,3,2.5)*(.46 if key=='front' else .33)
    pen=np.zeros(close.shape,np.float32)
    for cx,cy,rx,ry,dx,dy,gain in ZONES[key]:
        focus=np.exp(-.5*(((X-cx)/rx)**2+((Y-cy)/ry)**2))
        pen=np.maximum(pen,focus*press(dx,dy,10 if key in ('front','purple') else 6)*gain)
    return lmask(1-(1-close)*(1-pen))
fields={k:piece_shadow(k,paint[k]) if k!='roots' else Image.new('L',SIZE) for k in ORDER}
def move_l(im,xy):
    out=Image.new('L',SIZE);out.paste(im,xy);return out
def render(pose=None,hidden=(),shadows=True,export_stamps=False):
    canvas=clear();stamps={};pose=pose or {}
    for k in ORDER:
        if k in hidden:continue
        xy=pose.get(k,(0,0));img=place(paint[k],xy);shade=move_l(fields[k],xy)
        if shadows:
            stamps[k]=dark((np.asarray(shade)/255)*alpha(canvas))
            rgb=ImageChops.multiply(canvas.convert('RGB'),ImageChops.invert(shade).convert('RGB')).convert('RGBA');rgb.putalpha(canvas.getchannel('A'));canvas=rgb
        canvas=Image.alpha_composite(canvas,img)
    return (canvas,stamps) if export_stamps else canvas
if __name__=='__main__':render().save(ROOT/'Restoration.png')

