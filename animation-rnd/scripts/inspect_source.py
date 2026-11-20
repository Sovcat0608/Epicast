from pathlib import Path
import hashlib, json, subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
repo = ROOT.parent
source = ROOT / 'source/Groveheart-restoration-v4.png'
im = Image.open(source).convert('RGBA')
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=repo).decode().split('\0')
snapshot = {p: hashlib.sha256((repo/p).read_bytes()).hexdigest() for p in tracked if p and (repo/p).is_file()}
snapshot['concepts/groveheart-restoration/Groveheart-restoration-v4.png'] = hashlib.sha256(source.read_bytes()).hexdigest()
dst = ROOT / 'reports/protected-inputs.json'
if not dst.exists():
    dst.write_text(json.dumps(snapshot, indent=2)+'\n')
for name, box in [('A-foliage', (330,930,780,1370)), ('B-moss',(270,300,770,760)), ('C-leaf',(410,490,680,790))]:
    crop = im.crop(box)
    bg = Image.new('RGBA', crop.size, (31,35,40,255)); bg.alpha_composite(crop)
    d = ImageDraw.Draw(bg)
    for x in range((box[0]//50+1)*50, box[2], 50):
        d.line((x-box[0],0,x-box[0],crop.height),fill=(255,255,255,70),width=1)
        d.text((x-box[0]+2,2),str(x),fill='white',stroke_width=1,stroke_fill='black')
    for y in range((box[1]//50+1)*50,box[3],50):
        d.line((0,y-box[1],crop.width,y-box[1]),fill=(255,255,255,70),width=1)
        d.text((2,y-box[1]+2),str(y),fill='white',stroke_width=1,stroke_fill='black')
    bg.save(ROOT/f'masks/inspection-{name}.png')
print(json.dumps({'source_size': im.size, 'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'protected_files':len(snapshot)}))
