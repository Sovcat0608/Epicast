// Real local game models; one native GPU context for the complete layer stack.
const modelCache=new Map(),artCache=new Map();
async function modelData(id){if(!modelCache.has(id))modelCache.set(id,fetch('/api/model?id='+id).then(async r=>{const value=await r.json();if(!r.ok)throw Error(value.error||'Model unavailable');return value;}).catch(e=>{modelCache.delete(id);throw e;}));return modelCache.get(id);}
async function artworkData(crest){if(!artCache.has(crest.art))artCache.set(crest.art,(async()=>{const b=new Uint8Array(await(await fetch(crest.art)).arrayBuffer()),d=new DataView(b.buffer),w=d.getUint16(12,true),h=d.getUint16(14,true),out=new Uint8Array(crest.width*crest.height*4);if(b[2]!==2||b[16]!==32)throw Error('Unsupported artwork');for(let y=0;y<crest.height;y++)for(let x=0;x<crest.width;x++){const sy=b[17]&32?y:h-1-y,sx=b[17]&16?w-1-x:x,p=18+b[0]+(sy*w+sx)*4,q=(y*crest.width+x)*4;out[q]=b[p+2];out[q+1]=b[p+1];out[q+2]=b[p];out[q+3]=b[p+3];}return out;})());return artCache.get(crest.art);}
class CrestPreview{
 constructor(host,read){this.host=host;this.read=read;this.iframe=document.createElement('iframe');this.iframe.src='/studio-engine.html';this.iframe.title='Live crest renderer';host.append(this.iframe);this.layers=new Map();this.clock=0;this.zoom=1;this.hover=true;this.paused=false;this.generation=0;this.errors=[];this.last=performance.now();requestAnimationFrame(t=>this.draw(t));}
 get engine(){return this.iframe.contentWindow;}
 sync(crest){if(!this.engine.engineReady)return;const e=this.engine;
  if(this.key!==crest.crest){this.key=crest.crest;this.generation++;for(const l of this.layers.values())if(l.handle)e.remove(l.handle);this.layers.clear();this.errors=[];this.artReady=false;const gen=this.generation;if(crest.art)artworkData(crest).then(b=>{if(gen===this.generation){e.artwork(b,crest.width,crest.height,crest.artworkDesaturation,crest.game?.flip);this.artReady=true;}}).catch(err=>this.errors.push(err.message));}
  for(const [id,l]of this.layers)if(!crest.effects.some(r=>r.layerID===id&&r.fileID===l.fileID)){if(l.handle)e.remove(l.handle);this.layers.delete(id);}
  for(const r of crest.effects)if(!this.layers.has(r.layerID)){const l={fileID:r.fileID,handle:0,phase:'hidden',ready:false};this.layers.set(r.layerID,l);const gen=this.generation;modelData(r.fileID).then(data=>{if(gen!==this.generation||this.layers.get(r.layerID)!==l)return;l.data=data;l.handle=e.create(r.fileID);if(!l.handle)throw Error('Native layer limit reached');}).catch(err=>{l.error=err.message;this.errors.push(r.fileID+': '+err.message);});}
 }
 sequence(l,id,phase){if(!l.ready)return;l.phase=phase;l.at=this.clock;l.sequence=id;this.engine.animation(l.handle,id);}
 begin(id,seconds=Infinity,placement=false){
  const r=this.read().crest.effects.find(r=>r.layerID===id),l=this.layers.get(id);
  if(!r||!l?.ready||r.enabled===false||this.read().crest.game?.effects===false)return false;
  const intro=!placement&&r.behavior==='bound'&&r.binding?.intro&&l.data.metadata.sequences.some(s=>s.id===0);
  l.until=this.clock+seconds+(intro?r.binding.introDuration:0);
  this.sequence(l,intro?0:r.animation,intro?'intro':'main');
  return true;
 }
 stop(id){const r=this.read().crest.effects.find(r=>r.layerID===id),l=this.layers.get(id);if(!l?.ready)return;if(r?.binding?.outro&&l.data.metadata.sequences.some(s=>s.id===159))this.sequence(l,159,'outro');else l.phase='hidden';l.testing=false;}
 stopTests(){for(const l of this.layers.values())if(l.testing){l.testing=false;l.phase='hidden';}}
 test(id){
  const r=this.read().crest.effects.find(r=>r.layerID===id);
  if(r?.behavior!=='bound'||!r.binding)return;
  this.stopTests();
  if(this.begin(id,['success','pulse'].includes(r.binding.kind)?r.binding.duration:3))this.layers.get(id).testing=true;
 }
 signal(spell,kind,active=true){
  for(const r of this.read().crest.effects){
   if(r.behavior!=='bound'||r.binding?.spell.toLowerCase()!==spell.toLowerCase()||r.binding.kind!==kind)continue;
   if(!active){this.stop(r.layerID);continue;}
   if(this.begin(r.layerID,['success','pulse'].includes(kind)?r.binding.duration:Infinity))this.layers.get(r.layerID).testing=true;
  }
 }
 draw(now){try{if(!this.fatal)this.drawFrame(now);}catch(e){this.fatal=e.message;this.errors.push('Renderer stopped: '+e.message+'. Use Reload preview.');}requestAnimationFrame(t=>this.draw(t));}
 reload(){this.generation++;this.layers.clear();this.key=null;this.artReady=false;this.fatal=null;this.errors=[];const frame=document.createElement('iframe');frame.title='Live crest renderer';frame.src='/studio-engine.html';this.iframe.replaceWith(frame);this.iframe=frame;}
 drawFrame(now){const dt=Math.min((now-this.last)/1000,.05);this.last=now;const state=this.read(),c=state.crest,e=this.engine;if(c&&e.engineReady&&this.host.clientWidth&&this.host.clientHeight){this.sync(c);if(!this.paused)this.clock+=dt;
   const w=this.host.clientWidth,h=this.host.clientHeight;
   const [boundsWidth,boundsHeight,offsetX,offsetY,artWidth,artHeight,defaultSize]=c.geometry;
   const actualScale=c.game&&this.gamePixelsPerUnit?this.gamePixelsPerUnit/devicePixelRatio:1;
   const scale=(this.actual?actualScale:Math.max(.05,Math.min((w-50)/boundsWidth,(h-40)/boundsHeight)))*this.zoom;
   this.factor=scale*defaultSize;
   const aw=artWidth*scale,ah=artHeight*scale,center=[w/2-offsetX*scale,h/2+offsetY*scale];
   const leg=(this.clock%3)/3,progress=leg*leg*(3-2*leg);
   const effects=c.game?.effects!==false;
   const hover=this.hover&&c.art&&effects?ah*.012*(this.clock%6<3?2*progress-1:1-2*progress):0;
   for(const r of c.effects){const l=this.layers.get(r.layerID);if(!l?.handle)continue;l.debug=e.debug(l.handle);if(!l.ready&&l.debug[0]>=0){l.ready=true;if(r.behavior==='static')this.begin(r.layerID);}
    const placement=state.tab==='config'&&state.controls==='placement'&&state.selected===r.layerID;
    if(l.ready){
     if(l.main!==r.animation||l.placement!==placement||l.behavior!==r.behavior||l.enabled!==r.enabled){
      Object.assign(l,{main:r.animation,placement,behavior:r.behavior,enabled:r.enabled});
      if(r.behavior==='static'||placement)this.begin(r.layerID,Infinity,true);
      else if(!l.testing)l.phase='hidden';
     }
     if(l.phase==='intro'&&this.clock-l.at>=(r.binding?.introDuration||.25))this.sequence(l,r.animation,'main');
     if(l.phase==='main'&&this.clock>=l.until)this.stop(r.layerID);
     if(l.phase==='outro'&&this.clock-l.at>=(r.binding?.outroDuration||.25))l.phase='hidden';}
    const tuning=r.layerID===state.selected?{...r,...state.placement}:r;
    const camera=EpicastProjection.camera(tuning,{width:w,height:h,frameScale:this.factor,center,hover,follow:!!r.followArtwork,flip:!!c.game?.flip});l.camera=camera;
    e.configure(l.handle,camera,effects&&r.enabled!==false&&l.phase!=='hidden'?tuning.trailOpacity/100:0,r.desaturation);
   }
   const a=c.studio.artwork.artwork;
   const opacity=state.selected==='artwork'?state.placement?.trailOpacity??a?.opacity:a?.opacity;
   e.artRect((2*center[0]-aw)/w-1,1-(2*(center[1]-30*this.factor-hover)+ah)/h,2*aw/w,2*ah/h,this.artReady&&a?.enabled!==false?(opacity??100)/100:0);
   e.order(c.studio.order.map(id=>id==='artwork'?0:(this.layers.get(id)?.handle||undefined)).filter(id=>id!==undefined));e.frame(this.paused?0:dt,w,h);
  }}
 status(){return{key:this.key,clock:this.clock,errors:this.errors,layers:[...this.layers].map(([id,l])=>({id,fileID:l.fileID,handle:l.handle,ready:l.ready,phase:l.phase,sequence:l.sequence,error:l.error,debug:l.debug})),engine:this.engine.diagnostics};}
 diagnostics(){return{...this.status(),pixels:this.engine.engineReady?this.engine.inspect():null};}
}
window.EpicastPreview={CrestPreview,modelData};
