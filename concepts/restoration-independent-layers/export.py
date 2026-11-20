from register import *
from xml.etree import ElementTree as ET
from html import escape

dump()
def sha(b): return hashlib.sha256(b).hexdigest()
svg=['<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="660" height="880" viewBox="0 0 660 880">']
assets=[]; hashes={}
for i,(name,title) in enumerate(zip(ORDER,NAMES)):
    im=paints[name]
    bbox=im.getchannel('A').getbbox()
    raw=png_bytes(im.crop(bbox))
    encoded=base64.b64encode(raw).decode('ascii')
    x,y,r,b=bbox
    svg.append(f'<g id="L{i+1}-{title.replace(" ","-")}" data-name="{escape(title)}"><title>{escape(title)}</title><image x="{x}" y="{y}" width="{r-x}" height="{b-y}" xlink:href="data:image/png;base64,{encoded}"/></g>')
    assets.append({'name':title,'x':x,'y':y,'width':r-x,'height':b-y,'png':encoded})
    hashes[title]=sha(png_bytes(im))
svg.append('</svg>')
svgfile=OUT/'Restoration-layers.svg'
svgfile.write_text('\n'.join(svg),encoding='utf8')
# Verify actual embedded PNGs, coordinates, Normal blend and seven independent groups.
roundtrip=transparent();doc=ET.parse(svgfile);ns={'s':'http://www.w3.org/2000/svg'}
for g in doc.getroot().findall('s:g',ns):
    image=g.find('s:image',ns)
    data=base64.b64decode(image.get('{http://www.w3.org/1999/xlink}href').split(',')[1],validate=True)
    patch=Image.open(BytesIO(data));roundtrip.alpha_composite(patch,(int(image.get('x')),int(image.get('y'))))
assert len(doc.getroot().findall('s:g',ns))==7
assert np.array_equal(np.asarray(roundtrip),np.asarray(render(shadow=False)))
native=OUT/'Figma contact shadows';native.mkdir(exist_ok=True)
(native/'manifest.json').write_text(json.dumps({'name':'Epicast Restoration layer study','id':'1853068826673417709','api':'1.0.0','main':'build.js','editorType':['figma'],'documentAccess':'dynamic-page','networkAccess':{'allowedDomains':['none']}},indent=2),encoding='utf8')
builder=(SOURCE/'figma-build.js').read_text(encoding='utf8')
(native/'build.js').write_text(builder+'\nconst assets = '+json.dumps(assets,separators=(',',':'))+';\nbuildReview(assets);\nfigma.closePlugin("Restoration created. Pose the Paint child inside each source component.");\n',encoding='utf8')

poseA={'canopy':(-8,-6),'purple':(8,-6),'ivory':(-7,6),'sprout':(6,5),'glyph':(0,-3)}
poseB={n:(-x,-y) for n,(x,y) in poseA.items()}
ends={'canopy':['bottom','bottom','top','top','top','top','bottom','bottom'],'purple':['top']*3,'ivory':['top']*2,'sprout':['bottom']}
front=np.asarray(paints['front'])[:,:,3];anchor_report=[]
for key,end in ends.items():
    for i,side in enumerate(end):
        mask=np.asarray(pieces[key][i])[:,:,3];ys,xs=np.where(mask>180)
        y=int(ys.min()+3 if side=='top' else ys.max()-3);x=int(np.median(xs[ys==y]))
        footprint=front[y-6:y+7,x-8:x+9]
        v=int(footprint.min())
        anchor_report.append({'group':key,'whole_piece':i+1,'attachment_xy':[x,y],'minimum_front_alpha':v})
assert all(a['minimum_front_alpha']>=170 for a in anchor_report),anchor_report
# A moving or hidden receiver can never cast a stationary outline into transparency.
for pos in [{},poseA,poseB]:
    ca=render(pos).getchannel('A');na=render(pos,shadow=False).getchannel('A')
    assert np.array_equal(np.asarray(ca),np.asarray(na))
for key in ORDER:
    solo=render(hidden=set(ORDER)-{key});assert np.array_equal(np.asarray(solo),np.asarray(paints[key]))
    assert np.any(np.asarray(render(hidden={key}))!=np.asarray(render()))
# Guide panels use the actual registered files. Miniatures fit their own cell.
def font(size,bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/'+('segoeuib.ttf' if bold else 'segoeui.ttf'),size)
def draw_element(board,im,box,trim=False):
    if trim:
        bbox=im.getchannel('A').point(lambda a:255 if a>=30 else 0).getbbox();im=im.crop(bbox)
    im=im.copy();im.thumbnail((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
    x=(box[0]+box[2]-im.width)//2;y=(box[1]+box[3]-im.height)//2
    board.paste(im,(x,y),im)
bg='#161c24';panel='#232c36';muted='#adbbc3';light='#f4e8d5'
board=Image.new('RGB',(1254,720),bg);ink=ImageDraw.Draw(board)
ink.text((24,18),'Restoration',font=font(29,True),fill=light)
ink.text((25,58),'Independent crest layers',font=font(16),fill=muted)
draw_element(board,render(),(8,90,471,699),True)
items=[('core','Wood backdrop'),('front','Static front'),('purple','Purple leaves'),('sprout','Central sprout'),('canopy','Upper green leaves'),('ivory','Lower ivory leaves'),('glyph','Crown glyph')]
for i,(key,label) in enumerate(items):
    row,col=divmod(i,4);left=482+col*189;top=26+row*337
    ink.rounded_rectangle((left,top,left+179,top+315),8,fill=panel)
    draw_element(board,paints[key],(left+9,top+17,left+170,top+258),True)
    ink.text((left+9,top+275),label,font=font(15,True),fill=light)
left=482+3*189;top=363
ink.rounded_rectangle((left,top,left+179,top+315),8,fill=panel)
mini=render().resize((162,216),Image.Resampling.LANCZOS)
board.paste(mini,(left+8,top+35),mini)
ink.text((left+9,top+275),'At 162 × 216',font=font(15,True),fill=light)
board.save(OUT/'Restoration-layer-guide.png',optimize=True)
pose_board=Image.new('RGB',(1300,454),bg);d=ImageDraw.Draw(pose_board)
for i,(title,pic) in enumerate([('Rest',render()),('Offset A',render(poseA)),('Offset B',render(poseB)),('Purple hidden',render(hidden={'purple'})),('Static front hidden',render(hidden={'front'}))]):
    x=6+i*259;d.rounded_rectangle((x,10,x+251,442),8,fill=panel)
    draw_element(pose_board,pic,(x+6,20,x+245,397))
    d.text((x+11,408),title,font=font(16,True),fill=light)
pose_board.save(OUT/'Restoration-pose-check.png',optimize=True)
verification={'canvas':SIZE,'reference_file_sha256':'6773d3a98b5ad09f00e2fe73e419890f8ff8c612205d2f90bcd48fd61798459a','png_hashes':hashes,'native_source_hashes':{f.name:sha(f.read_bytes()) for f in sorted(SOURCE.glob('*.png'))},'attachment_window':{'x':[-8,8],'y':[-6,6],'alpha_threshold':170,'checks':anchor_report},'offset_A':poseA,'offset_B':poseB,'all_7_solo_clean':True,'receiver_alpha_unchanged_across_all_3_poses':True,'svg_paint_roundtrip':'identical','native_Figma_visual_review':'pending'}
(SOURCE/'verification.json').write_text(json.dumps(verification,indent=2),encoding='utf8')
print('Verified',len(anchor_report),'attachment points at all 221 translations in the motion window. Seven solo poses and SVG registration passed.')

