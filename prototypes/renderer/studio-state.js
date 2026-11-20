(function(root){
 const copy=v=>JSON.parse(JSON.stringify(v));
 const fields=['fileID','name','animation','scale','originX','originY','originZ','azimuth','elevation','desaturation','trailSize','trailAngle','trailX','trailY','trailOpacity','behavior','effectLayer','layerID','enabled','followArtwork','binding'];
 class Store{
  constructor(data){this.definitions=data.crests;this.drafts=Object.fromEntries(data.crests.map(c=>[c.crest,copy(c)]));this.saved=copy(this.drafts);this.key='MAGE:arcane';this.listeners=[];}
  get crest(){return this.drafts[this.key];}get dirty(){return JSON.stringify(this.drafts)!==JSON.stringify(this.saved);}
  emit(){this.listeners.forEach(f=>f());}
  change(fn){fn(this.crest);this.emit();}
  select(key){if(!this.drafts[key])throw Error('Unknown crest');this.key=key;this.emit();}
  save(){this.saved=copy(this.drafts);this.emit();}discard(){this.drafts=copy(this.saved);this.emit();}
  export(){const c=this.crest;return{format:'epicast-crest-bake',version:2,crest:c.crest,effects:c.effects.map(r=>Object.fromEntries(fields.filter(k=>r[k]!==undefined).map(k=>[k,copy(r[k])]))),studio:copy(c.studio)};}
  row(id){return this.crest.effects.find(r=>r.layerID===id);}
  add(row){if(this.crest.effects.length>=32)throw Error('This crest already has 32 effect layers.');let n=1;while(this.row('fx'+n))n++;const r={...copy(row),layerID:'fx'+n,enabled:true};this.change(c=>{c.effects.push(r);c.studio.order.push(r.layerID);});return r.layerID;}
  remove(id){this.change(c=>{c.effects=c.effects.filter(r=>r.layerID!==id);c.studio.order=c.studio.order.filter(k=>k!==id);});}
  move(id,delta){this.change(c=>{const a=c.studio.order,i=a.indexOf(id),j=i+delta;if(i>=0&&j>=0&&j<a.length){a.splice(i,1);a.splice(j,0,id);}});}
  addSpell(value){const spell=value.trim();if(this.crest.class==='RESOURCE')throw Error('Resource crests cannot bind spells.');if(!spell||new TextEncoder().encode(spell).length>100||/[\x00-\x1f]/.test(spell))throw Error('Enter a spell name or exact ID (100 bytes maximum).');let found=this.crest.studio.spells.find(s=>s.spell.toLowerCase()===spell.toLowerCase());if(found)return found.id;
   if(this.crest.studio.spells.length>=64)throw Error('This crest already has 64 spells.');let n=1;while(this.crest.studio.spells.some(s=>s.id==='spell'+n))n++;found={id:'spell'+n,spell};this.change(c=>c.studio.spells.push(found));return found.id;}
  usage(spell){return this.crest.effects.filter(r=>r.binding?.spell.toLowerCase()===spell.toLowerCase()).length;}
  removeSpell(id){const s=this.crest.studio.spells.find(s=>s.id===id);if(s&&!this.usage(s.spell))this.change(c=>c.studio.spells=c.studio.spells.filter(s=>s.id!==id));}
  bind(id,spellID,kind){const row=this.row(id),s=this.crest.studio.spells.find(s=>s.id===spellID);if(!row||!s||this.crest.class==='RESOURCE')throw Error('Select an effect layer and a spell first.');if(!['cast','success','channel','pulse','buff','proc'].includes(kind))throw Error('Unknown signal');this.change(()=>{row.behavior='bound';row.binding={kind,spell:s.spell,duration:1,intro:false,outro:false,introDuration:.5,outroDuration:.5,...row.binding,kind,spell:s.spell};});}
  unbind(id){const row=this.row(id);if(row)this.change(()=>{row.behavior='static';delete row.binding;});}
 }
 const api={Store,copy};if(typeof module!=='undefined')module.exports=api;else root.EpicastStudioState=api;
})(globalThis);
