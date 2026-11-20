"""Third and final emblem pass: include the actual pale cyan painted contour."""
from pathlib import Path
import json, shutil
ROOT=Path(__file__).resolve().parents[1]
for suffix in ['contact.png','validation.json']:
    src=ROOT/(f'previews/C-leaf-{suffix}' if suffix.endswith('.png') else f'reports/C-leaf-{suffix}')
    dst=ROOT/f'reports/pass-2-C-leaf-{suffix}'
    if not dst.exists(): shutil.copyfile(src,dst)
path=ROOT/'rigs/regions.json'; cfg=json.loads(path.read_text())
c=cfg['experiments'][2]; c['refinement_passes']=3
c['layers'][0]['mask_mode']='leaf-color'; c['layers'][0]['mask_dilate']=1
path.write_text(json.dumps(cfg,indent=2)+'\n')
path=ROOT/'animations/motion.json'; motion=json.loads(path.read_text())
motion['C-leaf']['curl_keyframes']=[[0,0],[.25,.018],[.43,.045],[.65,-.016],[.82,.005],[1,0]]
motion['C-leaf']['ripple_pixels']=.35
path.write_text(json.dumps(motion,indent=2)+'\n')
print('Final emblem pass: whole painted contour, 4.5% curl, 0.35 px ripple.')
