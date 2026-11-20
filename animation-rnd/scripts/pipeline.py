"""Offline, deterministic bitmap R&D. All writes stay under animation-rnd.

No game API, production media, SavedVariables, or image generation is used.
"""
from __future__ import annotations
import argparse, hashlib, json, math, os, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.deps'))
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
from scipy.spatial import Delaunay
from scipy.interpolate import PchipInterpolator
import imageio_ffmpeg

cv2.setNumThreads(1)
cv2.ocl.setUseOpenCL(False)
cv2.setRNGSeed(147)
CONFIG = json.loads((ROOT/'rigs/regions.json').read_text())
MOTION = json.loads((ROOT/'animations/motion.json').read_text())
SOURCE = ROOT / CONFIG['source']
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == CONFIG['source_sha256']
SRC = np.asarray(Image.open(SOURCE).convert('RGBA'))
H, W = SRC.shape[:2]


def write_json(path, obj):
    path = ROOT/path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, allow_nan=False)+'\n', encoding='utf-8')


def save_png(path, a):
    path = ROOT/path
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.asarray(a, dtype=np.uint8)).save(path, compress_level=6)


def to_pm(a):
    a = a.astype(np.float32)/255
    rgb = np.where(a[...,:3] <= .04045, a[...,:3]/12.92, ((a[...,:3]+.055)/1.055)**2.4)
    return np.concatenate((rgb*a[...,3:4], a[...,3:4]),axis=2)


def from_pm(a):
    alpha = np.clip(a[...,3:4],0,1)
    rgb = np.clip(a[...,:3]/np.maximum(alpha,1e-8),0,1)
    rgb = np.where(rgb <= .0031308,rgb*12.92,1.055*rgb**(1/2.4)-.055)
    return np.rint(np.concatenate((rgb,alpha),axis=2)*255).clip(0,255).astype(np.uint8)


def over(fg,bg):
    return fg + bg*(1-fg[...,3:4])


def checker(a, step=24):
    yy,xx=np.indices(a.shape[:2]); c=np.where((xx//step+yy//step)%2,34,43).astype(np.uint8)
    bg=np.stack((c,c+3,c+6,np.full_like(c,255)),axis=2)
    return from_pm(over(to_pm(a),to_pm(bg)))[...,:3]


def polygon_mask(points):
    im=Image.new('L',(W*4,H*4)); d=ImageDraw.Draw(im)
    d.polygon([(x*4,y*4) for x,y in points],fill=255)
    return np.asarray(im.resize((W,H),Image.Resampling.LANCZOS))


def segment_layer(layer, exp):
    poly=polygon_mask(layer['polygon'])
    if layer.get('mask_mode')=='polygon':
        return poly.astype(np.float32)/255
    x0,y0,x1,y1=exp['crop']
    rgb=SRC[y0:y1,x0:x1,:3].copy()
    p=poly[y0:y1,x0:x1]>127
    hsv=cv2.cvtColor(rgb,cv2.COLOR_RGB2HSV)
    if layer.get('mask_mode')=='leaf-color':
        # The pale cyan paint is part of the emblem, not stationary stone.
        # Direct source colour evidence separates it from the darker blue recess.
        bound=cv2.dilate(p.astype(np.uint8),np.ones((29,29),np.uint8)).astype(bool)
        binary=bound&(hsv[...,0]>=20)&(hsv[...,0]<=94)&(hsv[...,1]>30)
        binary=ndimage.binary_fill_holes(binary)
        cc,n=ndimage.label(binary); sizes=np.bincount(cc.ravel()); sizes[0]=0
        binary=cc==int(sizes.argmax())
        binary=cv2.dilate(binary.astype(np.uint8),np.ones((3,3),np.uint8)).astype(bool)
        signed=ndimage.distance_transform_edt(binary)-ndimage.distance_transform_edt(~binary)
        mask=np.zeros((H,W),np.float32)
        mask[y0:y1,x0:x1]=np.clip(.5+signed*.5,0,1)
        return mask
    green=(hsv[...,0]>=25)&(hsv[...,0]<=100)&(hsv[...,1]>35)
    labels=np.zeros(p.shape,np.uint8)
    band=cv2.dilate(p.astype(np.uint8),np.ones((5,5),np.uint8)).astype(bool)
    labels[band]=cv2.GC_PR_BGD; labels[p]=cv2.GC_PR_FGD
    inner=cv2.erode(p.astype(np.uint8),np.ones((5,5),np.uint8)).astype(bool)
    labels[inner&green]=cv2.GC_FGD
    labels[SRC[y0:y1,x0:x1,3]<8]=cv2.GC_BGD
    if exp['id']=='A-foliage':
        brown=(rgb[...,0].astype(float)>rgb[...,1]*1.10)&(hsv[...,0]<29)
        labels[brown]=cv2.GC_BGD
    cv2.setRNGSeed(147)
    cv2.grabCut(rgb,labels,None,np.zeros((1,65)),np.zeros((1,65)),4,cv2.GC_INIT_WITH_MASK)
    binary=((labels==cv2.GC_FGD)|(labels==cv2.GC_PR_FGD))&band
    binary=ndimage.binary_fill_holes(binary)
    cc,n=ndimage.label(binary)
    sizes=np.bincount(cc.ravel())
    keep=sizes>= (4 if exp['id']=='B-moss' else 25); keep[0]=False
    binary=keep[cc]
    if layer.get('mask_dilate'):
        n=layer['mask_dilate']*2+1
        binary=cv2.dilate(binary.astype(np.uint8),cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(n,n))).astype(bool)
    # Subpixel coverage only: no texture blur.
    signed=ndimage.distance_transform_edt(binary)-ndimage.distance_transform_edt(~binary)
    soft=np.clip(.5+signed*.5,0,1).astype(np.float32)
    mask=np.zeros((H,W),np.float32); mask[y0:y1,x0:x1]=soft
    return mask


def make_mesh(mask, layer, exp):
    ys,xs=np.where(mask>.01)
    spacing=exp['mesh_spacing']
    xx=np.unique(np.append(np.arange(xs.min()-3,xs.max()+4,spacing),xs.max()+3))
    yy=np.unique(np.append(np.arange(ys.min()-3,ys.max()+4,spacing),ys.max()+3))
    gx,gy=np.meshgrid(xx,yy)
    pts=np.column_stack((gx.ravel(),gy.ravel())).astype(np.float64)
    pts=np.unique(np.concatenate((pts,[layer['anchor'],layer['tip']])),axis=0)
    triangles=Delaunay(pts).simplices
    return pts,triangles


def displaced(points, layer, exp, tau):
    if tau<=0 or tau>=1: return points.copy()
    anchor=np.array(layer['anchor'],float); tip=np.array(layer['tip'],float)
    axis=tip-anchor; length=np.linalg.norm(axis); axis/=length
    normal=np.array([-axis[1],axis[0]])
    rel=points-anchor
    s=(rel@axis)/length
    fall=np.clip(s,0,1)**MOTION[exp['id']].get('tip_falloff',1.5)
    phase=layer['phase']; env=math.sin(math.pi*tau)**2
    out=points.copy()
    if exp['id']=='C-leaf':
        keys=np.array(MOTION['C-leaf']['curl_keyframes'])
        curl=float(PchipInterpolator(keys[:,0],keys[:,1])(tau))
        edge=min(1,tau/.18,(1-tau)/.18)
        curl*=edge**3*(10-15*edge+6*edge**2)
        lateral=rel@normal
        pin=np.clip(s/.18,0,1); pin=pin*pin*(3-2*pin)
        # A modest transverse curl, with the stem pinned and veins on the same surface.
        shift=-lateral*curl*pin
        ripple=MOTION['C-leaf']['ripple_pixels']*env*np.sin(2*math.pi*(tau*1.15-s*.8))*np.sin(np.pi*np.clip(s,0,1))**2*pin
        out+=(shift+ripple)[:,None]*normal
        out+=(-.6*curl*fall)[:,None]*axis
    else:
        settings=MOTION[exp['id']]
        travel=.75*s if exp['id']=='B-moss' else .28*s
        angle=2*math.pi*settings['cycles']*tau-phase-travel
        primary=np.sin(angle)
        secondary=settings['secondary_ratio']*np.sin(angle*1.65+.4)*env
        amount=layer['amplitude']*env*fall*(primary+secondary)
        out[:,0]+=amount
        out[:,1]+=layer['amplitude']*settings['vertical_ratio']*env*fall*np.sin(angle+.65)
    return out


def warp_mesh(texture, pts, dst, triangles, crop):
    if np.array_equal(pts,dst): return texture.copy(),1.0,1.0
    x0,y0,x1,y1=crop; hh,ww=texture.shape[:2]
    mapx=np.full((hh,ww),-100,np.float32); mapy=mapx.copy()
    ratios=[]
    for tri in triangles:
        p=pts[tri]; q=dst[tri]
        d=np.column_stack((q[1]-q[0],q[2]-q[0]))
        orig=np.column_stack((p[1]-p[0],p[2]-p[0]))
        ratio=float(np.linalg.det(d)/np.linalg.det(orig)); ratios.append(ratio)
        if ratio<=0: raise ValueError('Folded mesh triangle')
        lo=np.maximum(np.floor(q.min(axis=0)).astype(int),[x0,y0])
        hi=np.minimum(np.ceil(q.max(axis=0)).astype(int),[x1-1,y1-1])
        if np.any(hi<lo): continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        delta=np.stack((xx-q[0,0],yy-q[0,1]),axis=-1)
        uv=delta@np.linalg.inv(d).T
        inside=(uv[...,0]>=-1e-6)&(uv[...,1]>=-1e-6)&(uv.sum(axis=2)<=1.000001)
        source=p[0]+uv@orig.T
        targetx=mapx[lo[1]-y0:hi[1]-y0+1,lo[0]-x0:hi[0]-x0+1]
        targety=mapy[lo[1]-y0:hi[1]-y0+1,lo[0]-x0:hi[0]-x0+1]
        targetx[inside]=source[...,0][inside]-x0
        targety[inside]=source[...,1][inside]-y0
    warped=cv2.remap(texture,mapx,mapy,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT,borderValue=0)
    return warped,min(ratios),max(ratios)


def prepare(exp):
    eid=exp['id']; x0,y0,x1,y1=exp['crop']; raw=SRC[y0:y1,x0:x1].copy()
    hsv=cv2.cvtColor(raw[...,:3],cv2.COLOR_RGB2HSV)
    protect=np.zeros(raw.shape[:2],bool)
    if eid=='A-foliage':
        # Preserve the wooden curls/metal in front of the leaf cluster.
        protect=(raw[...,0].astype(float)>raw[...,1]*1.10)&(hsv[...,0]<29)&(raw[...,3]>10)
        protect=cv2.dilate(protect.astype(np.uint8),np.ones((3,3),np.uint8)).astype(bool)
        yy,xx=np.mgrid[y0:y1,x0:x1]
        # The dark terminal-leaf border is painted olive/brown, not a wooden curl.
        # An explicit front-root contour preserves its occlusion without pinning
        # the leaf's own dark rim and producing a tear.
        protect[(yy>=1180)&(xx>=504)&(xx<=583)]=False
        root=polygon_mask([[555,1192],[568,1202],[575,1220],[596,1235],[610,1259],[613,1279],[603,1290],[585,1282],[570,1269],[561,1250],[552,1232],[550,1212]])
        protect|=root[y0:y1,x0:x1]>127
        protect|=((xx-540)**2+(yy-903)**2<105**2)
    layers=[]; union=np.zeros((H,W),np.float32)
    mask_preview=Image.fromarray(checker(SRC)).convert('RGBA')
    mesh_preview=mask_preview.copy(); md=ImageDraw.Draw(mesh_preview)
    colors=[(72,220,155),(255,177,65),(105,160,255),(231,103,189),(238,217,90),(145,110,246),(91,229,230),(253,135,112)]
    # Frontmost polygons own any overlap in the original image.
    masks=[segment_layer(layer,exp) for layer in exp['layers']]
    occupied=np.zeros((H,W),np.float32)
    for i in reversed(range(len(masks))):
        masks[i]*=1-occupied
        occupied=np.maximum(occupied,masks[i])
    for i,(spec,mask) in enumerate(zip(exp['layers'],masks)):
        mask[y0:y1,x0:x1][protect]=0
        if mask.sum()<8: raise ValueError(f'Empty mask {eid}/{spec["id"]}')
        union=np.maximum(union,mask)
        local=mask[y0:y1,x0:x1]
        texture=to_pm(raw)*local[...,None]
        pts,tri=make_mesh(mask,spec,exp)
        layers.append({'spec':spec,'mask':local,'texture':texture,'points':pts,'triangles':tri})
        save_png(f'masks/{eid}/{spec["id"]}.png',np.rint(mask*255))
        full=np.zeros_like(SRC); full[y0:y1,x0:x1]=from_pm(texture)
        save_png(f'source/layers/{eid}/{spec["id"]}.png',full)
        overlay=np.zeros_like(SRC); overlay[...,:3]=colors[i%len(colors)]; overlay[...,3]=np.rint(mask*135)
        mask_preview=Image.alpha_composite(mask_preview,Image.fromarray(overlay))
        for t in tri:
            ps=[tuple(pts[j]) for j in t]
            md.line(ps+[ps[0]], fill=(*colors[i%len(colors)],180),width=1)
        ax,ay=spec['anchor']; tx,ty=spec['tip']
        md.ellipse((ax-4,ay-4,ax+4,ay+4),fill='white',outline='black',width=2)
        md.line((ax,ay,tx,ty),fill=(*colors[i%len(colors)],255),width=2)
        md.text((ax+6,ay),spec['id'],fill='white',stroke_width=1,stroke_fill='black')
        write_json(f'rigs/{eid}/{spec["id"]}.json',{'anchor':spec['anchor'],'tip':spec['tip'],'vertices':pts.tolist(),'triangles':tri.tolist(),'root_pinning':'zero displacement for projected axis t<=0','mask':f'masks/{eid}/{spec["id"]}.png'})
    save_png(f'masks/{eid}/union.png',np.rint(union*255))
    fullprotect=np.zeros((H,W),np.uint8); fullprotect[y0:y1,x0:x1]=protect*255
    save_png(f'masks/{eid}/protected.png',fullprotect)
    remove=(union[y0:y1,x0:x1]>.01).astype(np.uint8)*255
    remove=cv2.dilate(remove,np.ones((3,3),np.uint8)); remove[protect]=0
    plate=raw.copy()
    plate[...,:3]=cv2.inpaint(raw[...,:3],remove,3,cv2.INPAINT_TELEA)
    plate[...,3]=cv2.inpaint(raw[...,3],remove,3,cv2.INPAINT_TELEA)
    if eid=='A-foliage':
        yy,xx=np.mgrid[y0:y1,x0:x1]
        # Below the short curls the terminal leaf is against empty transparency.
        empty=(yy>=1250)&(remove>0)&~protect
        plate[empty]=0
    plate[protect]=raw[protect]
    save_png(f'source/plates/{eid}.png',plate)
    save_png(f'masks/{eid}/reconstruction-region.png',remove)
    pmplate=to_pm(plate); rest=pmplate.copy(); isolated=np.zeros_like(rest)
    for layer in layers:
        rest=over(layer['texture'],rest)
        isolated=over(layer['texture'],isolated)
    # A calibrated difference composite retains the exact original rest pose and
    # its partially transparent painted edges. We export ordinary RGBA replacement
    # patches, so playback itself needs only normal alpha composition, never subtraction.
    sourcepm=to_pm(raw)
    mask_preview.crop((max(0,x0-25),max(0,y0-25),min(W,x1+25),min(H,y1+25))).save(ROOT/f'masks/{eid}/mask-preview.png')
    mesh_preview.crop((max(0,x0-25),max(0,y0-25),min(W,x1+25),min(H,y1+25))).save(ROOT/f'rigs/{eid}/mesh-preview.png')
    write_json(f'reports/{eid}-segmentation.json',{'mask_pixels':int(np.count_nonzero(union)), 'components':len(layers),'protected_pixels':int(protect.sum()),'method':'authored polygon constraints + seeded deterministic GrabCut; subpixel coverage; manual occlusion protection','reconstruction':'OpenCV Telea, local source only; terminal leaf exterior transparent','rest_residual_max_pm':float(np.abs(sourcepm-rest).max()),'review_required': 'Fine moss and hidden overlapping foliage boundaries are estimated from a flattened source.'})
    return {'exp':exp,'raw':raw,'layers':layers,'plate':pmplate,'rest':rest,'sourcepm':sourcepm,'protect':protect,'union':union,'isolated_rest':isolated}


def render_frame(prepared, frame):
    exp=prepared['exp']; tau=frame/(exp['frames']-1)
    animated=prepared['plate'].copy(); isolated=np.zeros_like(animated)
    minratio=1.; maxratio=1.; maxdisp=0.
    for layer in prepared['layers']:
        pts=layer['points']; dst=displaced(pts,layer['spec'],exp,tau)
        texture,lo,hi=warp_mesh(layer['texture'],pts,dst,layer['triangles'],exp['crop'])
        animated=over(texture,animated); isolated=over(texture,isolated)
        minratio=min(minratio,lo); maxratio=max(maxratio,hi)
        maxdisp=max(maxdisp,float(np.linalg.norm(dst-pts,axis=1).max()))
    difference=animated-prepared['rest']
    patch=from_pm(prepared['sourcepm']+difference)
    unchanged=np.max(np.abs(difference),axis=2)<1e-8
    patch[unchanged]=prepared['raw'][unchanged]
    patch[prepared['protect']]=prepared['raw'][prepared['protect']]
    if frame in (0,exp['frames']-1): patch=prepared['raw'].copy()
    isolated[prepared['protect']]=0
    return patch,from_pm(isolated),{'frame':frame,'time_seconds':frame/20,'max_vertex_displacement_px':maxdisp,'minimum_triangle_area_ratio':minratio,'maximum_triangle_area_ratio':maxratio}


def full_patch(patch,crop):
    a=np.zeros_like(SRC); x0,y0,x1,y1=crop; a[y0:y1,x0:x1]=patch; return a


def composite(patch,crop):
    a=SRC.copy(); x0,y0,x1,y1=crop; a[y0:y1,x0:x1]=patch; return a


def video(path, images, fps=20):
    h,w=images[0].shape[:2]
    # Pad odd preview dimensions, never rescale source pixels for video encoding.
    if h%2 or w%2:
        images=[np.pad(x,((0,h%2),(0,w%2),(0,0)),mode='edge') for x in images]
        h,w=images[0].shape[:2]
    out=ROOT/path; out.parent.mkdir(parents=True,exist_ok=True)
    writer=imageio_ffmpeg.write_frames(str(out),(w,h),fps=fps,codec='libx264',pix_fmt_in='rgb24',pix_fmt_out='yuv420p',macro_block_size=2,quality=None,output_params=['-crf','16','-preset','medium','-movflags','+faststart','-metadata','creation_time=2026-11-16T00:00:00Z','-threads','1'])
    writer.send(None)
    for frame in images: writer.send(np.ascontiguousarray(frame))
    writer.close()


def gif(path, images, width):
    originals=[Image.fromarray(x).convert('RGB') for x in images]
    resized=[x.resize((width,round(x.height*width/x.width)),Image.Resampling.LANCZOS) for x in originals]
    # One palette for the entire loop avoids temporal palette flicker.
    sample=Image.new('RGB',(width,resized[0].height*4))
    for j,i in enumerate(np.linspace(0,len(resized)-1,4).astype(int)): sample.paste(resized[i],(0,j*resized[0].height))
    palette=sample.quantize(colors=255,method=Image.Quantize.MEDIANCUT)
    quant=[x.quantize(palette=palette,dither=Image.Dither.NONE) for x in resized]
    quant[0].save(ROOT/path,save_all=True,append_images=quant[1:],duration=50,loop=0,optimize=False,disposal=2)


def contact(path, patches, crop, title):
    indices=np.linspace(0,len(patches)-1,6).round().astype(int)
    ww,hh=patches[0].shape[1],patches[0].shape[0]
    out=Image.new('RGB',(ww*3,(hh+30)*2),(24,28,34)); d=ImageDraw.Draw(out)
    for j,i in enumerate(indices):
        x=(j%3)*ww; y=(j//3)*(hh+30)
        out.paste(Image.fromarray(checker(patches[i])),(x,y+30))
        d.text((x+5,y+8),f'f{i:02d}  {i/20:.2f}s',fill='white')
    out.save(ROOT/path)


def pack(exp, patches, isolated):
    eid=exp['id']; x0,y0,x1,y1=exp['crop']; cw=x1-x0; ch=y1-y0; gutter=3
    tw=2**math.ceil(math.log2(cw+gutter*2)); th=2**math.ceil(math.log2(ch+gutter*2))
    count=(2048//tw)*(2048//th)
    manifest={'experiment':eid,'fps':20,'duration_seconds':exp['frames']/20,'frame_count':exp['frames'],'source_size':[W,H],'crop':exp['crop'],'anchor_top_left':[x0,y0],'content_size':[cw,ch],'tile_size':[tw,th],'gutter':gutter,'alpha':'straight RGBA; interpolation performed in linear-light premultiplied alpha','playback':'Draw source/static-base.png plus frame-zero patches of all three motifs; independently replace each patch with its selected frame. No WoW integration included.','variants':{}}
    for variant,seq in [('patch',patches),('isolated',isolated)]:
        entries=[]
        for start in range(0,len(seq),count):
            pageframes=seq[start:start+count]
            sizes=[(aw,ah) for aw in [128,256,512,1024,2048] for ah in [128,256,512,1024,2048] if (aw//tw)*(ah//th)>=len(pageframes)]
            aw,ah=min(sizes,key=lambda size:(size[0]*size[1],max(size),-size[0]))
            columns=aw//tw
            atlas=np.zeros((ah,aw,4),np.uint8); page=start//count
            for j,a in enumerate(pageframes):
                u=(j%columns)*tw+gutter; v=(j//columns)*th+gutter
                atlas[v:v+ch,u:u+cw]=a
                # Edge extrusion isolates each frame during ordinary UV sampling.
                atlas[v-gutter:v,u:u+cw]=a[0:1]
                atlas[v+ch:v+ch+gutter,u:u+cw]=a[-1:]
                atlas[v-gutter:v+ch+gutter,u-gutter:u]=atlas[v-gutter:v+ch+gutter,u:u+1]
                atlas[v-gutter:v+ch+gutter,u+cw:u+cw+gutter]=atlas[v-gutter:v+ch+gutter,u+cw-1:u+cw]
                entries.append({'frame':start+j,'page':page,'atlas_size':[aw,ah],'rect':[u,v,cw,ch],'uv':[u/aw,(u+cw)/aw,v/ah,(v+ch)/ah]})
            name=f'atlases/{eid}-{variant}-{page:02d}.png'; save_png(name,atlas)
            # Uncompressed BGRA TGA is supplied as a WoW-oriented portable bitmap.
            Image.fromarray(atlas).save(ROOT/f'atlases/{eid}-{variant}-{page:02d}.tga')
        manifest['variants'][variant]=entries
    write_json(f'atlases/{eid}.json',manifest)


def render(exp,prepared):
    eid=exp['id']; patches=[]; isolated=[]; stats=[]
    for i in range(exp['frames']):
        patch,layer,metrics=render_frame(prepared,i)
        patches.append(patch); isolated.append(layer); stats.append(metrics)
        save_png(f'frames/{eid}/patch/{i:03d}.png',full_patch(patch,exp['crop']))
        save_png(f'frames/{eid}/isolated/{i:03d}.png',full_patch(layer,exp['crop']))
    pack(exp,patches,isolated)
    composite_images=[checker(composite(x,exp['crop'])) for x in patches]
    side=[np.concatenate((checker(SRC),x),axis=1) for x in composite_images]
    close=[np.concatenate((checker(prepared['raw']),checker(x)),axis=1) for x in patches]
    video(f'previews/{eid}-full.mp4',composite_images)
    video(f'previews/{eid}-comparison.mp4',side)
    video(f'previews/{eid}-close.mp4',close)
    gif(f'previews/{eid}-comparison.gif',side,814)
    gif(f'previews/{eid}-close.gif',close,min(1000,close[0].shape[1]))
    contact(f'previews/{eid}-contact.png',patches,exp['crop'],eid)
    peak=max(range(len(stats)),key=lambda i:stats[i]['max_vertex_displacement_px'])
    save_png(f'previews/{eid}-peak-full.png',composite(patches[peak],exp['crop']))
    save_png(f'previews/{eid}-peak-difference.png',np.clip(np.abs(patches[peak].astype(int)-prepared['raw'].astype(int))*5,0,255))
    delta=np.stack([p.astype(np.float32)-prepared['raw'] for p in patches])
    step=np.diff(delta,axis=0)
    mask=prepared['union'][exp['crop'][1]:exp['crop'][3],exp['crop'][0]:exp['crop'][2]]>.01
    stats_summary={'experiment':eid,'frames':len(patches),'fps':20,'duration_seconds':len(patches)/20,'first_exact':bool(np.array_equal(patches[0],prepared['raw'])),'last_exact':bool(np.array_equal(patches[-1],prepared['raw'])),'protected_pixels_changed':int(sum(np.count_nonzero(np.any(p!=prepared['raw'],axis=2)&prepared['protect']) for p in patches)),'max_step_mean_absolute_channel_change':float(np.abs(step[:,mask]).mean(axis=(1,2)).max()),'first_step_mean_absolute_channel_change':float(np.abs(step[0,mask]).mean()),'last_step_mean_absolute_channel_change':float(np.abs(step[-1,mask]).mean()),'peak_frame':peak,'frame_metrics':stats}
    write_json(f'reports/{eid}-validation.json',stats_summary)
    key_indices=sorted(set([0,exp['frames']-1,*np.linspace(0,exp['frames']-1,7).round().astype(int).tolist()]))
    write_json(f'animations/{eid}-keyposes.json',{'coordinate_system':'original image pixels','poses':[{'frame':int(i),'time_seconds':i/20,'layers':{l['spec']['id']:displaced(l['points'],l['spec'],exp,i/(exp['frames']-1)).tolist() for l in prepared['layers']}} for i in key_indices]})
    print(json.dumps({k:v for k,v in stats_summary.items() if k!='frame_metrics'}),flush=True)
    return patches


def combined(allpatches):
    base=SRC.copy()
    for exp in CONFIG['experiments']:
        x0,y0,x1,y1=exp['crop']; base[y0:y1,x0:x1]=0
    save_png('source/static-base.png',base)
    images=[]
    starts=[0,5,10]
    for f in range(64):
        out=base.copy()
        for exp,start in zip(CONFIG['experiments'],starts):
            i=f-start
            patch=allpatches[exp['id']][i] if 0<=i<exp['frames'] else allpatches[exp['id']][0]
            x0,y0,x1,y1=exp['crop']; out[y0:y1,x0:x1]=patch
        images.append(checker(out))
    video('previews/all-motifs-full.mp4',images)
    gif('previews/all-motifs-full.gif',images,543)
    write_json('animations/combined-preview.json',{'fps':20,'frame_count':64,'duration_seconds':3.2,'starts_in_frames':dict(zip([e['id'] for e in CONFIG['experiments']],starts)),'note':'Independent once-through plays, followed by a still interval; motifs do not share one deformation field.'})


def verify_protected():
    baseline=json.loads((ROOT/'reports/protected-inputs.json').read_text())
    changed=[p for p,h in baseline.items() if hashlib.sha256((ROOT.parent/p).read_bytes()).hexdigest()!=h]
    assert not changed,changed
    write_json('reports/protected-verification.json',{'unchanged_files':len(baseline),'changed_files':changed,'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'saved_variables_accessed':False,'runtime_integrated':False})


def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--prepare-only',action='store_true'); ap.add_argument('--experiment',choices=[e['id'] for e in CONFIG['experiments']]); args=ap.parse_args()
    allpatches={}
    for exp in CONFIG['experiments']:
        if args.experiment and exp['id']!=args.experiment: continue
        print('Preparing '+exp['id'],flush=True)
        prepared=prepare(exp)
        if not args.prepare_only:
            print('Rendering '+exp['id'],flush=True); allpatches[exp['id']]=render(exp,prepared)
    if not args.prepare_only and not args.experiment: combined(allpatches)
    verify_protected()
    write_json('reports/environment.json',{'python':sys.version,'numpy':np.__version__,'opencv':cv2.__version__,'pillow':Image.__version__,'ffmpeg':imageio_ffmpeg.__version__,'opencv_threads':1,'random_seed':147,'source_dimensions':[W,H]})


if __name__=='__main__': main()
