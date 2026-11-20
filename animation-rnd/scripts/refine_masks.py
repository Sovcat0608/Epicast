"""Recorded second segmentation pass; idempotent, only touches R&D inputs."""
from pathlib import Path
import json, shutil
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'rigs/regions.json'
cfg=json.loads(path.read_text())
if cfg['pass']==1:
    for eid in ['A-foliage','B-moss']:
        dst=ROOT/f'reports/pass-1-{eid}-mask.png'
        shutil.copyfile(ROOT/f'masks/{eid}/mask-preview.png',dst)
    (ROOT/'reports/pass-1-regions.json').write_text(json.dumps(cfg,indent=2)+'\n')
cfg['pass']=2
a,b,c=cfg['experiments']
a['layers']=[x for x in a['layers'] if x['id'] in ['bottom','front-left','front-right','front-middle']]
b['layers']=[
 {'id':'short-strand','anchor':[361,491],'tip':[364,518],'amplitude':1.7,'phase':0,
  'polygon':[[355,487],[364,487],[368,495],[366,503],[368,512],[364,520],[361,519],[361,511],[358,506],[360,499],[355,496]]},
 {'id':'left-strand','anchor':[383,493],'tip':[382,565],'amplitude':3.3,'phase':0.45,
  'polygon':[[374,489],[387,488],[394,498],[392,511],[389,518],[389,532],[386,546],[387,555],[383,567],[379,567],[379,557],[377,547],[377,537],[374,528],[375,517],[372,514],[376,505],[371,500]]},
 {'id':'long-strand','anchor':[413,486],'tip':[409,590],'amplitude':4.1,'phase':0.95,
  'polygon':[[405,481],[418,480],[422,489],[420,500],[418,509],[421,521],[419,535],[418,544],[415,550],[416,559],[412,566],[413,578],[412,589],[409,593],[406,586],[406,575],[404,568],[405,558],[401,551],[404,542],[401,533],[404,525],[401,517],[403,508],[399,502],[402,492]]}
]
path.write_text(json.dumps(cfg,indent=2)+'\n')
print('Recorded pass 2: four clear foliage leaves; corrected moss strand coordinates.')
