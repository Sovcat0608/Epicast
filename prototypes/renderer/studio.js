const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)],copy=EpicastStudioState.copy;
let data,store,preview,tab='library',controls='placement',selected=null,spellID=null,filter='all',layerPage=0,spellPage=0,resultPage=0,resultRows=[],classID='MAGE',signalActive=false;
let library={generation:0,ready:false,zoom:0,angle:0,paused:false,animation:0},last=performance.now(),selectedData=null;
const say=text=>$('#notice').textContent=text;
function buttonRow(name,detail,id,active,click){const b=document.createElement('button');b.className='row';b.type='button';b.setAttribute('role','option');b.setAttribute('aria-selected',String(active));b.dataset.id=id;const title=document.createElement('span'),small=document.createElement('small');title.textContent=name;small.textContent=detail;b.append(title,small);b.onclick=click;return b;}
function empty(host,text){const p=document.createElement('p');p.className='empty';p.textContent=text;host.append(p);}
function pager(prefix,page,count,size){const pages=Math.max(1,Math.ceil(count/size));$('#'+prefix+'-prev').disabled=page<=0;$('#'+prefix+'-next').disabled=page>=pages-1;return pages;}
function stopTests(){preview?.stopTests();signalActive=false;}
function changeTab(value){if(tab!==value)stopTests();tab=value;for(const k of ['library','config']){$('#'+k).hidden=k!==tab;$('#tab-'+k).setAttribute('aria-selected',String(k===tab));}render();}
function changeControls(value){controls=value;for(const k of ['placement','playback']){$('#'+k).hidden=k!==controls;$('#tab-'+k).setAttribute('aria-selected',String(k===controls));}renderControls();}
function visibleLayers(){return [...store.crest.studio.order].reverse().filter(id=>filter==='all'||store.row(id)?.behavior===filter);}
function revealLayer(){layerPage=Math.floor(Math.max(0,visibleLayers().indexOf(selected))/10);}
function chooseLayer(id){
 const key=store.key;
 if(selected!==id)stopTests();
 selected=id;selectedData=null;revealLayer();
 const row=store.row(id);
 if(row?.behavior==='bound'&&row.binding){
  const index=store.crest.studio.spells.findIndex(s=>s.spell.toLowerCase()===row.binding.spell.toLowerCase());
  if(index>=0){spellID=store.crest.studio.spells[index].id;spellPage=Math.floor(index/7);}
  $('#signal').value=row.binding.kind;
 }
 render();
 if(row)EpicastPreview.modelData(row.fileID).then(d=>{if(store.key===key&&selected===id&&store.row(id)?.fileID===row.fileID){selectedData=d;renderControls();}}).catch(e=>say(e.message));
}
function selectCrest(key){
 stopTests();layerPage=spellPage=0;
 $('#signal').value='success';$('#spell-input').value='';
 selected=null;spellID=null;selectedData=null;
 store.select(key);
 spellID=store.crest.studio.spells[0]?.id??null;
 chooseLayer(visibleLayers()[0]??null);
}
function renderHeaders(){const options=data.crests.filter(c=>c.class===classID||c.class==='RESOURCE');$('#crest').replaceChildren(...options.map(c=>{const o=document.createElement('option');o.value=c.crest;o.textContent=(c.class==='RESOURCE'?'Resources · ':'Spellcasting · ')+c.title;return o;}));$('#crest').value=store.key;$('#class').value=classID;}
function renderResults(){const words=$('#search').value.toLowerCase().trim().split(/\s+/).filter(Boolean);resultRows=data.catalog.filter(e=>words.every(w=>(e.name+' '+e.path+' '+e.id+' '+(e.preset?.aliases||'')).toLowerCase().includes(w)));resultPage=Math.min(resultPage,Math.max(0,Math.ceil(resultRows.length/10)-1));const host=$('#results');host.replaceChildren();for(const e of resultRows.slice(resultPage*10,resultPage*10+10))host.append(buttonRow(e.name,'FileDataID '+e.id,e.id,library.id===e.id,()=>loadEffect(e.id)));if(!resultRows.length)empty(host,'No effects match. Try a shorter name or an exact FileDataID.');const pages=pager('result',resultPage,resultRows.length,10);$('#result-page').textContent=`${resultRows.length.toLocaleString()} effects · ${resultPage+1}/${pages}`;}
function renderLayers(){const c=store.crest,host=$('#layer-list');host.replaceChildren();const ids=[...c.studio.order].reverse().filter(id=>{const r=store.row(id);return filter==='all'||(r&&r.behavior===filter);});layerPage=Math.min(layerPage,Math.max(0,Math.ceil(ids.length/10)-1));for(const id of ids.slice(layerPage*10,layerPage*10+10)){const r=store.row(id),a=c.studio.artwork[id];host.append(buttonRow(r?.name||'Crest artwork',r?(r.enabled===false?'Hidden · ':r.behavior==='bound'?'Bound · ':'Static · ')+(r.binding?.spell||'always active'):(a?.enabled===false?'Hidden':'Artwork · six-second hover'),id,selected===id,()=>chooseLayer(id)));}if(!ids.length)empty(host,c.effects.length?'No layers in this filter.':'Add an effect from the library.');$('#layer-page').textContent=`${layerPage+1} / ${pager('layer',layerPage,ids.length,10)}`;$$('[data-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===filter)));const rank=c.studio.order.indexOf(selected);$('#forward').disabled=rank<0||rank===c.studio.order.length-1;$('#backward').disabled=rank<=0;}
const pendingInputs=new Map();
function setValue(input,value){
 if(pendingInputs.has(input))return;
 if(input.dataset.range){
  const field=$('[data-field='+input.dataset.range+']');
  if(pendingInputs.has(field))value=draftNumber(field)??value;
 }
 input.value=value??'';
}
function draftNumber(input){
 const value=input.valueAsNumber;
 return input.validity.valid&&Number.isFinite(value)?value:undefined;
}
function updateSessionButtons(){
 const dirty=store.dirty||pendingInputs.size>0;
 $('#save').disabled=!dirty;
 $('#discard').disabled=!dirty;
 $('#dirty-state').textContent=dirty?'Unsaved session changes':'All changes saved';
}
function flushInputs(){
 if(!pendingInputs.size)return true;
 const edits=[];
 for(const [input,edit] of pendingInputs){
  const value=draftNumber(input);
  if(value===undefined){input.focus();input.reportValidity();return false;}
  edits.push({...edit,value});
 }
 pendingInputs.clear();
 for(const edit of edits){
  if(edit.crest===store.key&&edit.layer===selected)edit.apply(edit.value);
 }
 renderControls();updateSessionButtons();
 return true;
}
function clearInputs(){pendingInputs.clear();renderControls();updateSessionButtons();}
function placementDraft(){
 const values={};
 for(const [input,edit] of pendingInputs){
  if(input.dataset.field&&edit.layer===selected&&edit.crest===store.key){
   const value=draftNumber(input);
   if(value!==undefined)values[input.dataset.field]=value;
  }
 }
 return values;
}
function renderControls(){if(!store)return;const c=store.crest,r=store.row(selected),a=c.studio.artwork[selected],art=!!a,exists=!!(r||a),b=r?.behavior==='bound'?r.binding:null;$('#layer-title').textContent=r?`${r.name} · ${r.fileID}`:art?'Crest artwork':'Choose a layer';
 $$('[data-field]').forEach(input=>{const field=input.dataset.field;input.disabled=!exists||(art&&field!=='trailOpacity');setValue(input,art&&field==='trailOpacity'?a.opacity:r?.[field]);});$$('[data-range]').forEach(input=>{const field=input.dataset.range;input.disabled=!exists||(art&&field!=='trailOpacity');setValue(input,art&&field==='trailOpacity'?a.opacity:r?.[field]);});
 $('#visible').disabled=!exists;$('#visible').checked=(r||a)?.enabled!==false;$('#follow').disabled=!r||!c.art;$('#follow').checked=!!r?.followArtwork;$('#motion-source').disabled=!r?.followArtwork||!c.art;
 $('#placement-help').textContent=art?'Complete approved artwork · six-second hover. Placement and size belong to the crest’s normal UI.':'Drag the preview or type to position the selected effect. Save session keeps a checkpoint.';
 $('#remove-effect').disabled=!r;$('#unbind').disabled=!b;$('#binding-summary').textContent=b?b.spell+' · '+b.kind:r?'Static · always active':'';
 $('#main-animation').disabled=!r;setValue($('#main-animation'),r?.animation);$$('[data-binding]').forEach(input=>{const key=input.dataset.binding;input.disabled=!b||(key==='duration'&&!['success','pulse'].includes(b.kind));setValue(input,b?.[key]??(key==='duration'?1:.25));});
 const seq=selectedData?.metadata.sequences.map(s=>s.id)||[];for(const key of ['intro','outro']){$('#'+key).disabled=!b||r?.fileID===166602||!seq.includes(key==='intro'?0:159);$('#'+key).checked=!!b?.[key];}
 const presets=$('#animation-presets');
 const choices=[[0,'Stand / intro (0)'],[158,'Hold (158)'],[159,'End (159)']];
 presets.replaceChildren(new Option('Animation presets',''),...choices.filter(([id])=>seq.includes(id)).map(([id,label])=>new Option(label,id)));
 presets.disabled=!r||presets.options.length===1;
 $('#playback-help').textContent=r?.fileID===166602?'166602 is Stand-only (0). Replay requests the sequence; existing particles may continue.':r?'Available sequence IDs: '+(seq.length?[...new Set(seq)].join(', '):'loading…')+'. Tests simulate the binding; they do not listen to the game.':'Artwork uses its built-in six-second hover.';
 updateTestButton();
 $('#crest-empty').textContent=c.art?'':c.effects.length?'':'No artwork is shipped for this crest yet. Effect layers can still be built and tested.';
 const placement=$('#game-placement');
 if(c.game){
  const number=new Intl.NumberFormat(undefined,{maximumFractionDigits:2});
  const {size,x,y,shown,flip,effects}=c.game;
  placement.textContent=`Saved in WoW · ${size}% · X ${number.format(x)} · Y ${number.format(y)} · ${shown?'Shown':'Hidden'}${flip?' · Mirrored':''}${effects?'':' · Effects off'}`;
  placement.title='The studio centers each crest, like the in-game Effect Studio. X and Y describe its position on the WoW screen.';
 }else placement.textContent='';
 $('#zoom-fit').textContent=(preview?.actual?'Game':'Fit')+' · '+Math.round((preview?.zoom||1)*100)+'%';
}
function updateTestButton(){
 const row=store.row(selected);
 $('#test-response').disabled=store.crest.game?.effects===false||row?.behavior!=='bound'||row.enabled===false||!preview?.layers.get(selected)?.ready;
}
function renderSpells(){const c=store.crest,host=$('#spell-list'),spells=c.studio.spells;host.replaceChildren();spellPage=Math.min(spellPage,Math.max(0,Math.ceil(spells.length/7)-1));for(const s of spells.slice(spellPage*7,spellPage*7+7))host.append(buttonRow(s.spell,s.spell+' · '+(store.usage(s.spell)?store.usage(s.spell)+' effect(s)':'Waiting · unbound'),s.id,spellID===s.id,()=>{if(!flushInputs())return;stopTests();spellID=s.id;renderSpells();}));if(!spells.length)empty(host,c.class==='RESOURCE'?'Resource crests use unbound effects.':'Keep spell names or IDs here, then bind them to one or more effect layers.');$('#spell-page').textContent=`${spells.length} spells · ${spellPage+1}/${pager('spell',spellPage,spells.length,7)}`;const spell=spells.find(s=>s.id===spellID),resource=c.class==='RESOURCE';$('#add-spell').disabled=resource;$('#spell-input').disabled=resource;$('#signal').disabled=resource;$('#bind').disabled=!store.row(selected)||!spell||resource;$('#remove-spell').disabled=!spell||!!store.usage(spell.spell);const matching=spell&&c.effects.some(r=>r.binding?.spell.toLowerCase()===spell.spell.toLowerCase()&&r.binding.kind===$('#signal').value);$('#simulate').disabled=!matching;$('#simulate').textContent=signalActive?'End simulated signal':'Simulate selected spell';$('#signal-help').textContent=$('#signal').value==='buff'?'Offline: simulate an active buff. In game, buff signals use the enabled native Cooldown Manager.':$('#signal').value==='proc'?'Proc means the spell-button glow signal. Use Buff active for Missile Barrage or Clearcasting buffs.':'Choose a signal, then bind. One spell can drive several effects.';}
function render(){if(!store)return;for(const id of ['pause','rotate','effect-fit','effect-minus','effect-plus','library-animation'])document.getElementById(id).disabled=!library.ready;renderHeaders();renderLayers();renderControls();renderSpells();$('#destination').textContent=`Destination: ${store.crest.title} · ${store.crest.effects.length}/32 effects`;updateSessionButtons();$('#add-effect').disabled=!library.ready||store.crest.effects.length>=32;}
async function loadEffect(id){const gen=library.generation+1;library={generation:gen,id,ready:false,zoom:0,angle:0,paused:false,animation:0};$('#effect-stage iframe')?.remove();$('#effect-overlay').textContent='Loading local game model…';$('#effect-status').textContent='Loading…';$('#add-effect').disabled=true;const entry=data.catalog.find(e=>e.id===id);$('#effect-name').textContent=entry?.name||String(id);$('#effect-path').textContent=entry?.path||'';renderResults();
 try{const d=await EpicastPreview.modelData(id);if(library.generation!==gen)return;library.data=d;library.animation=d.row.animation;library.angle=d.row.azimuth;const iframe=document.createElement('iframe');iframe.title='Selected game effect preview';iframe.src='/effect.html?id='+id;library.iframe=iframe;library.loadedAt=performance.now();$('#effect-stage').append(iframe);$('#library-animation').value=library.animation;$$('[data-segment]').forEach(b=>b.disabled=!d.metadata.sequences.some(s=>s.id===+b.dataset.segment));$('#segments').textContent='Available sequence IDs: '+[...new Set(d.metadata.sequences.map(s=>s.id))].join(', ')+'.';}
 catch(e){if(library.generation!==gen)return;library.error=e.message;$('#effect-overlay').textContent=e.message;$('#effect-status').textContent='Preview unavailable · addition blocked';say(e.message);}}
function zoomLibrary(delta){if(library.ready)library.zoom=Math.max(-8,Math.min(8,library.zoom+delta));}
function replayLibrary(id=library.animation){if(!library.ready)return;const ids=library.data.metadata.sequences.map(s=>s.id);if(!ids.includes(id)){say('This model does not contain animation '+id+'.');$('#library-animation').value=library.animation;return;}library.animation=id;$('#library-animation').value=id;library.iframe.contentWindow.replay(id);}
function tick(now){const dt=Math.min((now-last)/1000,.05);last=now;const w=library.iframe?.contentWindow;if(tab==='library'&&w?.engineReady){const stage=$('#effect-stage'),r={...library.data.row,scale:library.data.row.scale*2**library.zoom,azimuth:library.angle,trailY:20};const camera=EpicastProjection.camera(r,{width:stage.clientWidth,height:stage.clientHeight,artWidth:216*stage.clientHeight/864,kind:'arcane',follow:false});const changed=w.configure(camera,stage.clientWidth,stage.clientHeight);if(!library.paused)w.tick(dt);else if(changed)for(let i=0;i<4;i++)w.tick(0);
  if(!library.ready&&w.diagnostics.ready&&!library.error){library.ready=true;w.replay(library.animation);$('#effect-overlay').textContent='';$('#effect-status').textContent='Playing';render();}
  if(!library.ready&&!library.error&&now-library.loadedAt>25000){library.error='Model loading timed out. Select it again to retry.';$('#effect-overlay').textContent=library.error;$('#effect-status').textContent='Addition blocked';}
  if(library.ready&&w.diagnostics.errors.length){library.ready=false;library.error=w.diagnostics.errors.at(-1);$('#effect-overlay').textContent='Renderer error. Select this effect again to retry.';$('#effect-status').textContent=library.error;$('#add-effect').disabled=true;}
 }requestAnimationFrame(tick);}
function numeric(input,apply){
 input.required=true;
 input.oninput=()=>{
  pendingInputs.set(input,{crest:store.key,layer:selected,apply});
  const range=input.dataset.field&&$('[data-range='+input.dataset.field+']');
  const value=draftNumber(input);
  if(range&&value!==undefined)range.value=value;
  updateSessionButtons();
 };
 input.onblur=()=>{if(pendingInputs.has(input)&&draftNumber(input)!==undefined)flushInputs();};
 input.onkeydown=e=>{
  if(e.key==='Escape'){e.preventDefault();pendingInputs.delete(input);renderControls();updateSessionButtons();input.blur();}
  if(e.key==='Enter'){e.preventDefault();if(flushInputs())input.blur();}
 };
 input.addEventListener('wheel',e=>{
  if(document.activeElement!==input||input.disabled)return;
  e.preventDefault();
  if(!e.deltaY||!flushInputs())return;
  const step=(input.hasAttribute('data-binding') ? 0.1 : 1)*(e.shiftKey?10:1);
  input.value=Math.max(+input.min,Math.min(+input.max,Math.round((+input.value-Math.sign(e.deltaY)*step)*100)/100));
  input.oninput();flushInputs();
 },{passive:false});
}
function wire(){
 document.addEventListener('click',e=>{
  const button=e.target.closest('button');
  if(!button||!pendingInputs.size||button.matches('#discard,#remove-effect,.nudge'))return;
  if(!flushInputs()){e.preventDefault();e.stopImmediatePropagation();}
 },true);
 // Match the latest in-game whole-step sliders, including Size and Angle.
 for(const field of ['trailSize','trailAngle']){const input=$('[data-field='+field+']'),pair=document.createElement('span'),range=document.createElement('input');pair.className='range-pair';range.type='range';range.dataset.range=field;for(const attr of ['min','max','step'])range.setAttribute(attr,input.getAttribute(attr));input.before(pair);pair.append(range,input);}
 $$('[data-range]').forEach(range=>{for(const [direction,label]of [[-1,'Decrease'],[1,'Increase']]){const b=document.createElement('button');b.type='button';b.className='nudge';b.textContent=direction<0?'‹':'›';b.setAttribute('aria-label',label+' '+range.dataset.range);b.onclick=()=>{if(range.disabled)return;range.value=String(Math.max(+range.min,Math.min(+range.max,+range.value+direction)));range.dispatchEvent(new Event('input'));};if(direction<0)range.before(b);else range.after(b);}});
 const reload=document.createElement('button');reload.id='reload-preview';reload.textContent='Reload';reload.title='Recreate the offline preview if a model fails to render';reload.onclick=()=>preview.reload();$('#crest-pause').before(reload);
 for(const key of ['library','config'])$('#tab-'+key).onclick=()=>changeTab(key);for(const key of ['placement','playback'])$('#tab-'+key).onclick=()=>changeControls(key);
 $('#class').onchange=e=>{if(!flushInputs()){renderHeaders();return;}classID=e.target.value;const key=data.crests.find(c=>c.class===classID).crest;selectCrest(key);};$('#crest').onchange=e=>{if(flushInputs())selectCrest(e.target.value);else renderHeaders();};
 $('#search').oninput=()=>{
  resultPage=0;renderResults();
  if(library.id&&!resultRows.some(row=>row.id===library.id)){
   library={generation:library.generation+1,ready:false};$('#effect-stage iframe')?.remove();
   $('#effect-name').textContent=resultRows.length?'Select an effect to preview':'No matching Forever effects';
   for(const id of ['effect-path','effect-status','effect-overlay','segments'])$('#'+id).textContent='';
   $$('[data-segment]').forEach(b=>b.disabled=true);render();
  }
 };
 $('#search').onkeydown=e=>{if(e.key==='Enter'&&resultRows[resultPage*10])loadEffect(resultRows[resultPage*10].id);};
 $('#effect-stage').addEventListener('wheel',e=>{
  if(!library.ready||!e.deltaY)return;
  e.preventDefault();zoomLibrary(-Math.sign(e.deltaY)*.5);
 },{passive:false});
 $('#result-prev').onclick=()=>{resultPage--;renderResults();};$('#result-next').onclick=()=>{resultPage++;renderResults();};
 $('#layer-prev').onclick=()=>{layerPage--;renderLayers();};$('#layer-next').onclick=()=>{layerPage++;renderLayers();};$('#spell-prev').onclick=()=>{spellPage--;renderSpells();};$('#spell-next').onclick=()=>{spellPage++;renderSpells();};
 $$('[data-filter]').forEach(b=>b.onclick=()=>{filter=b.dataset.filter;const ids=visibleLayers();if(!ids.includes(selected))chooseLayer(ids[0]??null);else{revealLayer();renderLayers();}});
 for(const [id,delta] of [['forward',1],['backward',-1]])$('#'+id).onclick=()=>{store.move(selected,delta);revealLayer();renderLayers();};
 for(const [selector,prefix] of [['.catalog','result'],['.layers','layer'],['.spells','spell']]){
  $(selector).addEventListener('wheel',e=>{
   if(e.target.closest('input,select')||!e.deltaY)return;
   e.preventDefault();$('#'+prefix+(e.deltaY>0?'-next':'-prev')).click();
  },{passive:false});
 }
 $('#replay').onclick=()=>library.error?loadEffect(library.id):replayLibrary();$('#pause').onclick=()=>{library.paused=!library.paused;$('#pause').textContent=library.paused?'Resume':'Pause';$('#effect-status').textContent=library.paused?'Paused':'Playing';};$('#rotate').onclick=()=>library.angle=(library.angle+45)%360;$('#effect-fit').onclick=()=>library.zoom=0;$('#effect-minus').onclick=()=>zoomLibrary(-.5);$('#effect-plus').onclick=()=>zoomLibrary(.5);let background=0;$('#background').onclick=()=>{$('#effect-stage').style.background=['#0b0a12','#37333e','#b3b0b8'][++background%3];};$$('[data-segment]').forEach(b=>b.onclick=()=>replayLibrary(+b.dataset.segment));$('#library-animation').onchange=e=>{if(e.target.validity.valid)replayLibrary(+e.target.value);};
 $('#add-effect').onclick=()=>{try{const r={...library.data.row,scale:Math.max(.000001,Math.min(10000,library.data.row.scale*2**library.zoom)),azimuth:library.angle,animation:library.animation};selected=store.add(r);filter='all';layerPage=0;changeTab('config');changeControls('placement');chooseLayer(selected);say('Effect added as an unbound layer. Select a spell to bind it.');}catch(e){say(e.message);}};
 $$('[data-field]').forEach(input=>numeric(input,value=>{
  const field=input.dataset.field,row=store.row(selected),art=store.crest.studio.artwork[selected];
  if(row)row[field]=value;
  else if(art&&field==='trailOpacity')art.opacity=value;
 }));
 $$('[data-range]').forEach(range=>range.oninput=()=>{
  const input=$('[data-field='+range.dataset.range+']');
  input.value=range.value;input.oninput();
 });
 $('#visible').onchange=e=>{const checked=e.target.checked;if(flushInputs())store.change(c=>{(store.row(selected)||c.studio.artwork[selected]).enabled=checked;});else renderControls();};
 $('#follow').onchange=e=>{const checked=e.target.checked;if(flushInputs())store.change(()=>{const r=store.row(selected);if(checked)r.followArtwork='artwork';else delete r.followArtwork;});else renderControls();};
 numeric($('#main-animation'),value=>{
  const row=store.row(selected);
  if(!selectedData?.metadata.sequences.some(s=>s.id===value)){say('Animation '+value+' is not available for this model.');return;}
  stopTests();row.animation=value;
 });
 $('#animation-presets').onchange=e=>{
  const value=e.target.value;
  if(!value||!flushInputs())return;
  const input=$('#main-animation');input.value=value;input.oninput();flushInputs();
 };
 $$('[data-binding]').forEach(input=>numeric(input,value=>{const b=store.row(selected)?.binding;if(b){stopTests();b[input.dataset.binding]=value;}}));
 for(const key of ['intro','outro'])$('#'+key).onchange=e=>{
  const checked=e.target.checked;
  if(!flushInputs()){renderControls();return;}
  stopTests();store.change(()=>store.row(selected).binding[key]=checked);
 };
 $('#remove-effect').onclick=()=>{clearInputs();store.remove(selected);chooseLayer(visibleLayers()[0]??null);};
 $('#unbind').onclick=()=>{stopTests();store.unbind(selected);if(!visibleLayers().includes(selected))chooseLayer(visibleLayers()[0]??null);};
 $('#spell-form').onsubmit=e=>{e.preventDefault();try{spellID=store.addSpell($('#spell-input').value);$('#spell-input').value='';spellPage=Math.floor(store.crest.studio.spells.findIndex(s=>s.id===spellID)/7);renderSpells();}catch(err){say(err.message);}};
 $('#signal').onchange=()=>{stopTests();renderSpells();};$('#bind').onclick=()=>{try{store.bind(selected,spellID,$('#signal').value);changeControls('playback');say('Spell bound to the selected effect. Use Test response to preview it.');}catch(e){say(e.message);}};$('#remove-spell').onclick=()=>{store.removeSpell(spellID);spellID=store.crest.studio.spells[0]?.id;renderSpells();};
 $('#test-response').onclick=()=>preview.test(selected);$('#stop-test').onclick=()=>{stopTests();renderSpells();};$('#simulate').onclick=()=>{const spell=store.crest.studio.spells.find(s=>s.id===spellID),kind=$('#signal').value;const timed=['success','pulse'].includes(kind);signalActive=timed?false:!signalActive;preview.signal(spell.spell,kind,timed||signalActive);renderSpells();say('Simulated '+kind+' signal for '+spell.spell+'.');};
 $('#crest-pause').onclick=()=>{preview.paused=!preview.paused;$('#crest-pause').textContent=preview.paused?'Resume':'Pause';};$('#zoom-out').onclick=()=>{preview.zoom=Math.max(.5,preview.zoom-.1);renderControls();};$('#zoom-in').onclick=()=>{preview.zoom=Math.min(2,preview.zoom+.1);renderControls();};$('#zoom-fit').onclick=()=>{preview.zoom=1;preview.actual=false;renderControls();};$('#zoom-actual').onclick=()=>{preview.zoom=1;preview.actual=true;renderControls();};
 const stage=$('#crest-stage');let drag;stage.onpointerdown=e=>{const r=store.row(selected);if(!r||controls!=='placement'||e.button!==0||!flushInputs())return;drag={id:selected,x:e.clientX,y:e.clientY,rx:r.trailX,ry:r.trailY};stage.setPointerCapture(e.pointerId);};stage.onpointermove=e=>{if(!drag)return;const r=store.row(drag.id),factor=1.5*preview.factor;if(!r||!factor)return;store.change(()=>{r.trailX=Math.max(-150,Math.min(150,Math.round(drag.rx+(e.clientX-drag.x)/factor)));r.trailY=Math.max(-150,Math.min(150,Math.round(drag.ry-(e.clientY-drag.y)/factor)));});};stage.onpointerup=stage.onpointercancel=()=>drag=null;
 $('#save').onclick=()=>{store.save();say('Session checkpoint saved. Export JSON to keep it after closing the browser.');};$('#discard').onclick=()=>{clearInputs();stopTests();store.discard();chooseLayer(store.crest.studio.order.includes(selected)?selected:store.crest.studio.order.at(-1));say('Unsaved edits discarded across all crests.');};$('#find-effect').onclick=()=>{changeTab('library');$('#search').focus();};
 $('#export').onclick=()=>{$('#export-text').value=JSON.stringify(store.export(),null,2);$('#export-dialog').showModal();$('#export-text').focus();$('#export-text').select();};$('#copy-export').onclick=async()=>{try{await navigator.clipboard.writeText($('#export-text').value);say('Crest bake copied.');$('#copy-export').textContent='Copied';}catch{say('Select the JSON and press Ctrl+C to copy.');}};$('#download-export').onclick=()=>{const url=URL.createObjectURL(new Blob([$('#export-text').value+'\n'],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download='epicast-'+store.key.replace(':','-').toLowerCase()+'-bake.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};$$('[data-close-dialog]').forEach(b=>b.onclick=()=>$('#'+b.dataset.closeDialog).close());$('#close').onclick=()=>{stopTests();preview.paused=true;$('#close-dialog').showModal();};$('#resume').onclick=()=>{$('#close-dialog').close();preview.paused=false;$('#crest-pause').textContent='Pause';};$('#close-dialog').oncancel=()=>preview.paused=false;
 $$('[role=tablist]').forEach(nav=>nav.onkeydown=e=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;const tabs=[...nav.querySelectorAll('[role=tab]')],i=tabs.indexOf(document.activeElement);if(i<0)return;e.preventDefault();const n=e.key==='Home'?0:e.key==='End'?tabs.length-1:(i+(e.key==='ArrowRight'?1:tabs.length-1))%tabs.length;tabs[n].click();tabs[n].focus();});$$('[role=listbox]').forEach(host=>host.onkeydown=e=>{if(!['ArrowUp','ArrowDown'].includes(e.key))return;const rows=[...host.children],i=rows.indexOf(document.activeElement);if(i<0)return;e.preventDefault();const index=Math.max(0,Math.min(rows.length-1,i+(e.key==='ArrowDown'?1:-1)));rows[index].click();host.children[index]?.focus();});
 window.addEventListener('beforeunload',e=>{if(store.dirty){e.preventDefault();e.returnValue='';}});
}
(async()=>{data=await(await fetch('/api/studio')).json();store=new EpicastStudioState.Store(data);$('#class').replaceChildren(...data.classes.map(c=>{const o=document.createElement('option');o.value=c.id;o.textContent='Class: '+c.name;return o;}));$('#build').textContent='Offline studio · Forever '+data.build+' · local assets';preview=new EpicastPreview.CrestPreview($('#crest-stage'),()=>({crest:store.crest,tab,controls,selected,placement:controls==='placement'?placementDraft():{}}));preview.gamePixelsPerUnit=data.gameSync?.pixelsPerUnit?.y;
 if(data.gameSync){
  const saved=new Date(data.gameSync.savedAt);
  const scale=preview.gamePixelsPerUnit?'calibrated 1:1':'1 WoW UI unit = 1 CSS pixel';
  $('#build').textContent='WoW save · '+saved.toLocaleString()+' · '+scale;
  preview.actual=true;
 }
 store.listeners.push(render);wire();chooseLayer(store.crest.studio.order.at(-1));spellID=store.crest.studio.spells[0]?.id;render();renderResults();await loadEffect(166009);
 if(data.gameSync)changeTab('config');
 requestAnimationFrame(tick);
 setInterval(()=>{if(tab!=='config')return;const diag=preview.status(),ready=diag.layers.filter(l=>l.ready).length;const row=store.row(selected);$('#crest-status').textContent=diag.errors.length?diag.errors.at(-1):ready<store.crest.effects.length?`Loading effects · ${ready}/${store.crest.effects.length}`:row?.behavior==='bound'&&row.enabled!==false&&controls==='placement'?'Previewing selected bound layer':'Live crest · offline spell simulation';updateTestButton();},500);
 window.studio={store,preview,loadEffect,selectCrest,chooseLayer,changeTab,changeControls,diagnostics:()=>({tab,controls,selected,spellID,library:{id:library.id,ready:library.ready,error:library.error},preview:preview.diagnostics()})};
})().catch(e=>{say(e.message);console.error(e);});
