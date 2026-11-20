"""Final foliage pass (3) and emblem pass (2), from inspected bitmap evidence."""
from pathlib import Path
import json, shutil
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'rigs/regions.json'; cfg=json.loads(path.read_text())
for eid,number in [('A-foliage',2),('C-leaf',1)]:
    for suffix in ['contact.png','validation.json']:
        src=ROOT/(f'previews/{eid}-{suffix}' if suffix.endswith('.png') else f'reports/{eid}-{suffix}')
        dst=ROOT/f'reports/pass-{number}-{eid}-{suffix}'
        if not dst.exists(): shutil.copyfile(src,dst)
cfg['pass']=3
a,b,c=cfg['experiments']
a['refinement_passes']=3; b['refinement_passes']=2; c['refinement_passes']=2
bottom=next(x for x in a['layers'] if x['id']=='bottom')
bottom.update({'amplitude':8.0,'mask_mode':'polygon','anchor':[539,1185],
 'polygon':[[529,1185],[543,1178],[553,1188],[559,1204],[562,1220],[566,1239],[579,1265],[582,1275],[575,1289],[566,1307],[555,1322],[542,1336],[533,1338],[531,1330],[533,1324],[531,1307],[521,1287],[514,1267],[508,1257],[504,1238],[506,1216],[516,1198]]})
c['layers'][0]['mask_dilate']=3
path.write_text(json.dumps(cfg,indent=2)+'\n')
print('Recorded final foliage contour and emblem outline/endpoint refinement.')
