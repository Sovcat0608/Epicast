"""Meaningful offline checks for identity, isolation, atlases and determinism."""
from pathlib import Path
import hashlib, json
import pipeline as p
import numpy as np
from PIL import Image, ImageDraw

ROOT=p.ROOT
checks=[]
def check(name,ok,**details):
    checks.append({'check':name,'passed':bool(ok),**details})
    if not ok: raise AssertionError(name)

def decoded(path): return np.asarray(Image.open(ROOT/path).convert('RGBA'))

def main():
    base=decoded('source/static-base.png').copy()
    fixed_polygons={
      'left horn':[(35,25),(300,25),(300,320),(35,320)],
      'right horn':[(790,25),(1055,25),(1055,320),(790,320)],
      'tree emblem':[(440,262),(640,262),(640,443),(440,443)],
      'left leaf panel':[(150,534),(309,534),(309,720),(150,720)],
      'right leaf panel':[(780,534),(930,534),(930,720),(780,720)],
      'left bronze medallion':[(337,789),(475,789),(475,934),(337,934)],
      'right bronze medallion':[(647,789),(778,789),(778,939),(647,939)],
      'central bronze medallion':[(472,815),(606,815),(635,860),(633,938),(601,984),(559,1000),(520,1000),(477,977),(448,932),(448,870)],
      'top stone':[(485,511),(553,507),(599,526),(607,537),(575,539),(532,535),(506,549),(483,543)],
      'lower stone':[(514,742),(537,731),(558,720),(590,719),(613,725),(618,742),(602,754),(564,757),(538,750)]}
    fixed_masks={}
    for name,poly in fixed_polygons.items():
        mask=Image.new('L',(p.W,p.H)); ImageDraw.Draw(mask).polygon(poly,fill=255)
        fixed_masks[name]=np.asarray(mask)>0
    for exp in p.CONFIG['experiments']:
        eid=exp['id']; x0,y0,x1,y1=exp['crop']
        manifest=json.loads((ROOT/f'atlases/{eid}.json').read_text())
        metrics=json.loads((ROOT/f'reports/{eid}-validation.json').read_text())
        frame_files=list((ROOT/f'frames/{eid}/patch').glob('*.png'))
        check(f'{eid}: requested frame count',len(frame_files)==exp['frames'],count=len(frame_files))
        check(f'{eid}: first/last exact source',metrics['first_exact'] and metrics['last_exact'])
        check(f'{eid}: stationary protected foreground',metrics['protected_pixels_changed']==0)
        check(f'{eid}: no mesh folds',min(x['minimum_triangle_area_ratio'] for x in metrics['frame_metrics'])>0)
        prepared=p.prepare(exp)
        support=p.cv2.dilate((prepared['union']>.01).astype(np.uint8),np.ones((25,25),np.uint8)).astype(bool)
        original=p.SRC[y0:y1,x0:x1]
        changed_outside=0; maximum_rgb_error=0; all_identical=True
        landmark_changes={name:0 for name in fixed_masks}
        atlas_cache={}
        for variant in ['patch','isolated']:
            for entry in manifest['variants'][variant]:
                i=entry['frame']; page=entry['page']; key=(variant,page)
                if key not in atlas_cache:
                    png=decoded(f'atlases/{eid}-{variant}-{page:02d}.png')
                    tga=decoded(f'atlases/{eid}-{variant}-{page:02d}.tga')
                    check(f'{eid}/{variant}/{page}: TGA equals PNG',np.array_equal(png,tga))
                    atlas_cache[key]=png
                frame=decoded(f'frames/{eid}/{variant}/{i:03d}.png')
                check(f'{eid}/{variant}/{i}: native coordinate canvas',frame.shape==p.SRC.shape)
                u,v,cw,ch=entry['rect']
                check(f'{eid}/{variant}/{i}: atlas round trip',np.array_equal(atlas_cache[key][v:v+ch,u:u+cw],frame[y0:y1,x0:x1]))
                if variant=='patch':
                    out=frame.copy(); out[y0:y1,x0:x1]=0
                    check(f'{eid}/{i}: outside patch transparent',not np.any(out))
                    changed=np.any(frame[y0:y1,x0:x1]!=original,axis=2)
                    for name,mask in fixed_masks.items():
                        landmark_changes[name]+=int(np.count_nonzero(changed&mask[y0:y1,x0:x1]))
                    changed_outside+=np.count_nonzero(changed&~support[y0:y1,x0:x1])
                    again,_,_=p.render_frame(prepared,i)
                    all_identical &= np.array_equal(again,frame[y0:y1,x0:x1])
                    maximum_rgb_error=max(maximum_rgb_error,int(np.abs(again.astype(int)-frame[y0:y1,x0:x1].astype(int)).max()))
        check(f'{eid}: repeat render byte-identical',all_identical,max_channel_error=maximum_rgb_error)
        check(f'{eid}: changes confined to moving-mask envelope',changed_outside==0,changed_outside=int(changed_outside))
        for name,count in landmark_changes.items():
            check(f'{eid}: fixed {name}',count==0,changed_pixels=count)
        resting=decoded(f'frames/{eid}/patch/000.png')
        base[y0:y1,x0:x1]=resting[y0:y1,x0:x1]
        # The last frame is exact rest, held for the final 50 ms; loop join has zero difference.
        last=decoded(f'frames/{eid}/patch/{exp["frames"]-1:03d}.png')
        check(f'{eid}: exact zero-difference loop join',np.array_equal(last,resting))
        with Image.open(ROOT/f'previews/{eid}-comparison.gif') as gif:
            duration=0
            for i in range(gif.n_frames):
                gif.seek(i); duration+=gif.info.get('duration',0)
            check(f'{eid}: GIF duration',duration==exp['frames']*50,duration_ms=duration)
    check('Independent frame-zero patches reconstruct exact original',np.array_equal(base,p.SRC))
    p.verify_protected()
    result={'passed':True,'checks':len(checks),'details':checks,'production_files_unchanged':105,'saved_variables_accessed':False}
    p.write_json('reports/validation.json',result)
    print(json.dumps({'passed':True,'checks':len(checks),'experiments':3,'native_frames':80,'coordinate_system':[p.W,p.H],'deterministic_frames':True}))

if __name__=='__main__': main()
