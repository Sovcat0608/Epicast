const $=s=>document.querySelector(s);let config,scene,frames=[],art,clock=0,paused=false,last=performance.now(),replays=0,cycleStart=null,cycleNumber=0,generation=0;
const events=[];const note=s=>{events.push({time:+clock.toFixed(3),message:s});$('#log').textContent=events.slice(-15).map(e=>e.time.toFixed(1)+'s  '+e.message).join('\n');};
async function tga(url,w,h){const b=new Uint8Array(await(await fetch(url)).arrayBuffer()),d=new DataView(b.buffer),width=d.getUint16(12,true),height=d.getUint16(14,true);if(b[2]!==2||b[16]!==32)throw Error('Unsupported artwork TGA');const c=document.createElement('canvas');c.width=w;c.height=h;const ctx=c.getContext('2d'),out=ctx.createImageData(w,h),base=18+b[0];for(let y=0;y<h;y++)for(let x=0;x<w;x++){const sy=b[17]&32?y:height-1-y,sx=b[17]&16?width-1-x:x,p=base+(sy*width+sx)*4,q=(y*w+x)*4;out.data[q]=b[p+2];out.data[q+1]=b[p+1];out.data[q+2]=b[p];out.data[q+3]=b[p+3];}ctx.putImageData(out,0,0);return c;}
async function load(key){const gen=++generation;cycleStart=null;frames=[];replays=0;$('#cycles').textContent='0';document.querySelectorAll('iframe.fx').forEach(f=>f.remove());$('#composition').replaceChildren();$('#layers').replaceChildren();scene=config.presets.find(p=>p.key===key);$('#title').textContent=scene.title;$('.callout').textContent=key==='restoration'?'166602 contains Stand only. Replay requests sequence 0; ongoing particles/global animation are not guaranteed to rewind.':'Native camera calibration applied. 5054328 Hold stays visible through repeated playback; effects use the full preview area.';art=await tga(scene.art,scene.width,scene.height);if(gen!==generation)return;art.className='art';art.style.height=scene.height+'px';art.style.setProperty('--art-half',-scene.height/2+'px');art.style.zIndex='1';$('#composition').append(art);const layer=document.createElement('div');layer.className='layer';layer.textContent='◆  Complete crest artwork';$('#layers').append(layer);
 for(const [i,row]of scene.layers.entries()){const iframe=document.createElement('iframe');iframe.className='fx';iframe.src='/effect.html?id='+row.fileID;iframe.title=row.name;iframe.style.zIndex=String(i+2);$('#stage').append(iframe);const entry={iframe,row,enabled:true,active:true,started:false};frames.push(entry);const item=document.createElement('div');item.className='layer';const label=document.createElement('label');label.className='check';const input=document.createElement('input');input.type='checkbox';input.checked=true;input.onchange=()=>entry.enabled=input.checked;label.append(input,document.createTextNode(row.name.replace(/cfx druid /i,'')));const small=document.createElement('small');small.textContent=row.fileID+' · '+row.metadata.particles+' particle emitters';const depth=document.createElement('select');depth.setAttribute('aria-label',row.fileID+' layer depth');for(const [value,text]of [['front','Above artwork'],['back','Behind artwork']]){const option=document.createElement('option');option.value=value;option.textContent=text;depth.append(option);}depth.style.fontSize='10px';depth.style.padding='4px';depth.onchange=()=>iframe.style.zIndex=depth.value==='front'?String(i+2):'0';item.append(label,small,depth);$('#layers').append(item);}
 note('Loaded '+scene.title+' prototype');}
function requestSegment(f,id,phase){f.phase=phase;f.phaseAt=clock;f.segment=id;f.iframe.contentWindow.replay(id);}
function begin(f){f.active=true;const intro=f.row.binding?.intro&&f.row.animation!==0&&f.iframe.contentWindow.diagnostics.animations.includes(0);requestSegment(f,intro?0:f.row.animation,intro?'intro':'main');}
function release(f){if(!f.active||f.phase==='outro')return;const outro=f.row.binding?.outro&&f.iframe.contentWindow.diagnostics.animations.includes(159);if(outro)requestSegment(f,159,'outro');else {f.active=false;f.phase='hidden';}}
function replay(){replays++;for(const f of frames)if(f.started)begin(f);$('#cycles').textContent=replays;note('Replay '+replays+' · existing scenes');}
function diagnostics(){return {build:config?.build,renderer:config?.renderer,scene:scene?.key,clock,replays,hover:$('#hover').checked,follow:$('#follow').checked,events,layers:frames.map(f=>({id:f.row.fileID,enabled:f.enabled,active:f.active,phase:f.phase,segment:f.segment,camera:f.camera,...f.iframe.contentWindow.diagnostics,pixels:f.iframe.contentWindow.engineReady?f.iframe.contentWindow.inspectPixels():null}))};}
function setPaused(value){paused=value;$('#pause').textContent=paused?'Resume':'Pause';}
window.lab={diagnostics,replay,load,frames:()=>frames,setTime:t=>clock=t,setPaused};
function configure(f){
 const stage=$('#stage'),hover=$('#hover').checked?-Math.cos(clock*Math.PI/3)*scene.height*.012:0;
 const c=EpicastProjection.camera(f.row,{width:stage.clientWidth,height:stage.clientHeight,artWidth:scene.width,kind:scene.key,zoom:Number($('#scale').value),hover,follow:$('#follow').checked});
 f.camera=c;const w=f.iframe.contentWindow,changed=w.configure?.(c,stage.clientWidth,stage.clientHeight);
 if(changed&&paused&&w.engineReady)for(let i=0;i<3;i++)w.tick(0);
}
function draw(now){
 const dt=Math.min((now-last)/1000,.05);last=now;
 if(!paused){
  clock+=dt;
  for(const f of frames){const w=f.iframe.contentWindow;if(w.tick){configure(f);w.tick(dt);if(w.diagnostics.ready&&!f.started){f.started=true;begin(f);note(f.row.fileID+' ready · sequences '+w.diagnostics.animations.join(','));}if(f.phase==='intro'&&clock-f.phaseAt>=f.row.binding.introDuration)requestSegment(f,f.row.animation,'main');if(f.phase==='outro'&&clock-f.phaseAt>=f.row.binding.outroDuration){f.active=false;f.phase='hidden';}}}
 }
 if(cycleStart!==null&&!paused){
  const t=clock-cycleStart,n=Math.floor(t/3);
  if(n>=5){cycleStart=null;for(const f of frames)if(f.started)begin(f);note('Five cycles complete');}
  else {if(n!==cycleNumber){cycleNumber=n;replay();}if(t%3>=1.5)for(const f of frames)release(f);}
 }
 const hover=$('#hover').checked?-Math.cos(clock*Math.PI/3)*(scene?.height||640)*.012:0,zoom=Number($('#scale').value);
 $('#composition').style.transform=`scale(${zoom})`;if(art)art.style.transform=`translateY(${-hover}px)`;
 for(const f of frames){configure(f);f.iframe.style.opacity=f.enabled&&f.active?String(f.row.trailOpacity/100):'0';}
 const loaded=frames.filter(f=>f.iframe.contentWindow.diagnostics?.ready).length;
 $('#loaded').textContent=loaded+' / '+frames.length;$('#status').textContent=paused?'Paused':loaded===frames.length?'Live · '+scene?.title:'Loading real models…';
 for(const id of ['replay','cycle','cold'])$('#'+id).disabled=loaded!==frames.length||!loaded;
 requestAnimationFrame(draw);
}
$('#preset').onchange=e=>load(e.target.value);$('#replay').onclick=replay;$('#pause').onclick=()=>setPaused(!paused);$('#cycle').onclick=()=>{setPaused(false);cycleStart=clock;cycleNumber=0;replay();};$('#cold').onclick=()=>{for(const f of frames){f.iframe.contentWindow.coldReload();f.started=false;}note('Models recreated · cold-load comparison');};$('#download').onclick=()=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(diagnostics(),null,2)],{type:'application/json'}));a.download='epicast-renderer-diagnostics.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};
(async()=>{config=await(await fetch('/api/config')).json();$('#build').textContent='Forever '+config.build+' · local assets';for(const p of config.presets){const o=document.createElement('option');o.value=p.key;o.textContent=p.title;$('#preset').append(o);}await load('restoration');requestAnimationFrame(draw);})().catch(e=>{$('#status').textContent=e.message;console.error(e);});
