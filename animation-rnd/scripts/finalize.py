"""Refresh combined previews, annotate uncertainty and inventory final artifacts."""
import hashlib, json, shutil
import pipeline as p
from PIL import Image, ImageDraw, ImageFont
import numpy as np

root=p.ROOT
allpatches={}
for exp in p.CONFIG['experiments']:
    x0,y0,x1,y1=exp['crop']
    allpatches[exp['id']]=[np.asarray(Image.open(root/f'frames/{exp["id"]}/patch/{i:03d}.png').convert('RGBA'))[y0:y1,x0:x1].copy() for i in range(exp['frames'])]
p.combined(allpatches)

# Retain early segmentation evidence outside the active deliverable directories.
for name in ['rear-left','rear-right','lower-left','lower-right']:
    for location,suffix in [('source/layers','.png'),('masks','.png'),('rigs','.json')]:
        src=(root/f'{location}/A-foliage/{name}{suffix}').resolve()
        dest=(root/f'reports/retired-pass-1/{location}/A-foliage/{name}{suffix}').resolve()
        assert src.is_relative_to(root) and dest.is_relative_to(root)
        if src.exists():
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(str(src),str(dest))

canvas=Image.new('RGB',(p.W+400,p.H),(24,30,35))
canvas.paste(Image.fromarray(p.checker(p.SRC)),(0,0))
d=ImageDraw.Draw(canvas)
try:
    font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',22)
    small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
except OSError:
    font=small=ImageFont.load_default()
notes=[
 ((340,450,435,602),'MOSS: review fine edges', 'Three strands selected.\nSmall edge estimates remain;\nthe hidden wood is reconstructed.\nThe broad moss mat stays still.',(244,197,96)),
 ((439,533,640,750),'EMBLEM: painted rim included','The cyan rim moves with the leaf.\nStone and blue recess remain fixed.\nKeep the curl restrained.',(119,207,218)),
 ((365,975,690,1345),'FOLIAGE: review occlusion','Four clear leaves animated.\nObscured rear leaves stay still.\nWooden curls remain foreground.\nHidden leaf edges are estimates.',(151,211,147))]
for (box,title,body,color),y in zip(notes,[350,650,1030]):
    d.rectangle(box,outline=color,width=3)
    d.line((box[2],box[1],p.W+15,y),fill=color,width=2)
    d.text((p.W+20,y),title,font=font,fill=color)
    d.multiline_text((p.W+20,y+38),body,font=small,fill=(220,227,224),spacing=8)
d.text((p.W+20,45),'Manual review notes',font=font,fill='white')
d.multiline_text((p.W+20,90),'The source is flattened.\nHidden surfaces cannot be\nrecovered as original pixels.\nNo blur or glow was added\nto conceal those limits.',font=small,fill=(220,227,224),spacing=8)
canvas.save(root/'reports/manual-review.png')

files=[]
for f in sorted(root.rglob('*')):
    if not f.is_file() or '.deps' in f.parts or '__pycache__' in f.parts or f.name=='artifact-manifest.json': continue
    files.append({'path':f.relative_to(root).as_posix(),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
p.write_json('reports/artifact-manifest.json',{'files':files,'total_files':len(files),'total_bytes':sum(f['bytes'] for f in files),'excluded':['.deps','__pycache__','artifact-manifest.json']})
print(json.dumps({'files':len(files),'bytes':sum(f['bytes'] for f in files),'combined_preview':'previews/all-motifs-full.mp4'}))
