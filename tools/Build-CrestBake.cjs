// Consume an effect-only developer export. Never reads account settings.
const fs=require('fs'),path=require('path'),parser=require('luaparse');
const root=path.resolve(__dirname,'..');
const segments=JSON.parse(fs.readFileSync(path.join(root,'tools/restoration-segments.json'),'utf8').replace(/^\uFEFF/,''));
const allowed=new Set(JSON.parse(fs.readFileSync(path.join(root,'tools/forever-effects.json'),'utf8')).allowed);
const ast=parser.parse(fs.readFileSync(path.join(root,'ClassSpecs.lua'),'utf8'));
const specs=ast.body.find(n=>n.type==='AssignmentStatement'&&n.variables[0].identifier?.name==='ClassSpecs').init[0];
const crests=new Set(['RESOURCE:left','RESOURCE:right']);
for(const c of specs.fields){
 const slots=c.value.fields.find(f=>f.key.name==='slots').value.fields;
 for(const s of slots)crests.add(c.key.name+':'+s.value.fields[0].value.raw.slice(1,-1));
}
const limits={fileID:[1,4294967295,true],animation:[0,65535,true],scale:[.000001,10000],originX:[-100000,100000],originY:[-100000,100000],originZ:[-100000,100000],azimuth:[-360,360],elevation:[-90,90],desaturation:[0,1],trailSize:[5,200],trailAngle:[-180,180],trailX:[-150,150],trailY:[-150,150],trailOpacity:[0,100]};
const signals=['cast','success','channel','pulse','buff','proc'];
function object(v){if(!v||typeof v!=='object'||Array.isArray(v))throw Error('Expected object');}
function keys(v,expected){object(v);if(Object.keys(v).some(k=>!expected.includes(k)))throw Error('Unexpected field');}
function number(v,[min,max,integer]){if(!Number.isFinite(v)||v<min||v>max||integer&&!Number.isInteger(v))throw Error('Invalid numeric field');}
function string(v){if(typeof v!=='string'||Buffer.byteLength(v,'utf8')>100||/[\x00-\x1f]/.test(v))throw Error('Invalid text field');}
function one(v,choices){if(!choices.includes(v))throw Error('Invalid enum');}
function validateBake(input){
 keys(input,['format','version','crest','effects','studio']);
 if(input.format!=='epicast-crest-bake'||![1,2,3,4,5].includes(input.version)||!crests.has(input.crest))throw Error('Unknown export format or crest');
 const segmented=input.version>=4;
 if(segmented&&input.crest!=='DRUID:restoration')throw Error('No segmented artwork for this crest');
 const artworkIDs=segmented?segments.map(segment=>segment.id):
  /^(MAGE:(fire|frost|arcane)|DRUID:(balance|feral|restoration))$/.test(input.crest)?['artwork']:[];
 if(input.version===1&&input.studio)throw Error('Studio requires v2');
 if(!Array.isArray(input.effects)||input.effects.length>32)throw Error('Invalid layer count');
 for(const row of input.effects){
  keys(row,[...Object.keys(limits),'name','behavior','effectLayer','binding',...(input.version>=2?['layerID','enabled','followArtwork']:[]),...(input.version>=3?['bindings']:[])]);
  if(row.enabled!==undefined)one(row.enabled,[true,false]);
  if(row.followArtwork!==undefined&&artworkIDs.length)one(row.followArtwork,['artwork',...artworkIDs]);
  for(const [key,range]of Object.entries(limits))number(row[key],range);
  if(!allowed.has(row.fileID))throw Error('Model is unavailable in Forever');
  string(row.name);one(row.behavior,['static','bound']);one(row.effectLayer,['front','back']);
  if(row.bindings!==undefined&&(row.binding!==undefined||row.behavior!=='bound'||!Array.isArray(row.bindings)||row.bindings.length<2||row.bindings.length>64))throw Error('Invalid multiple bindings');
  if(row.behavior==='bound'&&!row.binding&&!row.bindings)throw Error('Missing binding');
  if(input.crest.startsWith('RESOURCE:')&&(row.behavior!=='static'||row.binding||row.bindings))throw Error('Resources cannot have bindings');
  const bindings=row.bindings||(row.binding?[row.binding]:[]),seen=new Set();
  for(const b of bindings){
   keys(b,['kind','spell','duration','intro','outro','introDuration','outroDuration']);
   one(b.kind,signals);string(b.spell);
   const name=b.spell.toLowerCase();
   if(row.bindings&&(!name.trim()||name!==name.trim()||seen.has(name)))throw Error('Duplicate or invalid binding spell');
   seen.add(name);
   number(b.duration,[.05,60]);number(b.introDuration,[.05,10]);number(b.outroDuration,[.05,10]);
   one(b.intro,[true,false]);one(b.outro,[true,false]);
  }
  if(row.fileID===166602&&(row.animation!==0||bindings.some(b=>b.intro||b.outro)))throw Error('166602 supports Stand only');
 }
 if(input.version>=2){
  const s=input.studio;keys(s,['order','artwork','spells',...(segmented?['artworkBindings']:[])]);
  const hasArt=artworkIDs.length>0;
  const ids=input.effects.map(r=>r.layerID);
  if(ids.some(id=>typeof id!=='string'||!/^fx\d{1,6}$/.test(id))||new Set(ids).size!==ids.length)throw Error('Invalid effect identity');
  ids.push(...artworkIDs);
  if(!Array.isArray(s.order)||s.order.length!==ids.length||new Set(s.order).size!==ids.length||s.order.some(id=>!ids.includes(id)))throw Error('Incomplete layer order');
  keys(s.artwork,artworkIDs);
  for(const id of artworkIDs){
   const art=s.artwork[id];keys(art,['enabled','opacity']);one(art.enabled,[true,false]);number(art.opacity,[0,100]);
  }
  if(segmented&&s.order.filter(id=>artworkIDs.includes(id)).some((id,index)=>id!==artworkIDs[index]))throw Error('Artwork layer positions are locked');
  if(!hasArt&&input.effects.some(r=>r.followArtwork))throw Error('Missing artwork motion source');
  if(!Array.isArray(s.spells)||s.spells.length>64||input.crest.startsWith('RESOURCE:')&&s.spells.length)throw Error('Invalid spell waiting room');
  const spellIDs=new Set(),spellNames=new Set();
  for(const spell of s.spells){
   keys(spell,['id','spell']);string(spell.spell);
   if(!/^spell\d{1,6}$/.test(spell.id)||spellIDs.has(spell.id)||!spell.spell.trim()||spell.spell!==spell.spell.trim()||spellNames.has(spell.spell.toLowerCase()))throw Error('Invalid spell identity');
   spellIDs.add(spell.id);spellNames.add(spell.spell.toLowerCase());
  }
  for(const row of input.effects){
   if(row.behavior!=='bound')continue;
   for(const binding of row.bindings||[row.binding]){
    if(binding.spell&&!spellNames.has(binding.spell.toLowerCase()))throw Error('Bound spell missing from waiting room');
   }
  }
  if(segmented){
   keys(s.artworkBindings,segments.filter(segment=>segment.states.length).map(segment=>segment.id));
   for(const [id,bindings] of Object.entries(s.artworkBindings)){
    const {states}=segments.find(segment=>segment.id===id);
    const mapped=input.version===5;
    if(!Array.isArray(bindings)||!bindings.length||bindings.length>spellNames.size*(mapped?1:states.length))throw Error('Invalid artwork bindings');
    const seen=new Set();
    for(const binding of bindings){
     keys(binding,mapped?['spell','mappings']:['spell','kind']);string(binding.spell);
     const name=binding.spell.toLowerCase();
     const response=mapped?name:JSON.stringify([name,binding.kind]);
     if(!spellNames.has(name)||seen.has(response))throw Error('Unknown spell or duplicate artwork response');
     seen.add(response);
     if(!mapped){one(binding.kind,states);continue;}
     if(!Array.isArray(binding.mappings)||binding.mappings.length>states.length*signals.length)throw Error('Invalid artwork mappings');
     const pairs=new Set();
     for(const mapping of binding.mappings){
      keys(mapping,['state','kind']);one(mapping.state,states);one(mapping.kind,signals);
      const pair=JSON.stringify([mapping.state,mapping.kind]);
      if(pairs.has(pair))throw Error('Duplicate artwork signal mapping');
      pairs.add(pair);
     }
    }
   }
  }
 }
 return input;
}
function literal(v){
 if(typeof v==='string')return '"'+v.replace(/[\\"\x00-\x1f]/g,c=>c==='"'?'\\"':c==='\\'?'\\\\':'\\'+c.charCodeAt(0).toString().padStart(3,'0'))+'"';
 if(typeof v==='number'||typeof v==='boolean')return String(v);
 const entries=Array.isArray(v)?v.map((x,i)=>[i+1,x]):Object.entries(v).sort(([a],[b])=>a.localeCompare(b));
 return'{'+entries.map(([k,x])=>'['+literal(k)+']='+literal(x)).join(',')+'}';
}
function render(bakes){
 object(bakes);
 for(const [crest,data] of Object.entries(bakes)){
  if(Array.isArray(data))validateBake({format:'epicast-crest-bake',version:1,crest,effects:data});
  else {
   const artwork=data.studio?.artworkBindings;
   const mapped=artwork&&Object.values(artwork).some(links=>Array.isArray(links)&&links.some(link=>link?.mappings!==undefined));
   validateBake({format:'epicast-crest-bake',
    version:artwork?(mapped?5:4):data.effects?.some(row=>row?.bindings!==undefined)?3:2,crest,...data});
  }
 }
 return 'local _,E=...\n-- Generated by tools/Build-CrestBake.cjs. Shipped per-crest overrides only.\nE.CrestBakes='+literal(bakes)+'\n';
}
function writeBakeFiles(manifest, json, lua){
 const directory=fs.mkdtempSync(path.join(root,'.crest-bake-'));
 const nextManifest=path.join(directory,'manifest.json');
 const previousManifest=path.join(directory,'previous.json');
 const nextLua=path.join(directory,'bakes.lua');
 let keepBackup=false;
 try{
  fs.copyFileSync(manifest,previousManifest);
  fs.writeFileSync(nextManifest,json);
  fs.writeFileSync(nextLua,lua);
  fs.renameSync(nextManifest,manifest);
  try{fs.renameSync(nextLua,path.join(root,'CrestBakes.lua'));}
  catch(error){
   try{fs.renameSync(previousManifest,manifest);}
   catch{keepBackup=true;throw Error(`Could not restore crest-bakes.json. Its previous copy is at ${previousManifest}.`);}
   throw error;
  }
 }finally{
  for(const file of [nextManifest,nextLua])fs.rmSync(file,{force:true});
  if(!keepBackup){fs.rmSync(previousManifest,{force:true});fs.rmdirSync(directory);}
 }
}
if(require.main===module){
 try{
  const source=process.argv[2];if(!source)throw Error('Usage: node tools/Build-CrestBake.cjs path/to/export.json (or - for stdin)');
  const text=fs.readFileSync(source==='-'?0:path.resolve(source),'utf8').replace(/^\uFEFF/,'');
  let data;
  try{data=JSON.parse(text);}catch{throw Error('Paste the complete JSON from Copy crest bake.');}
  const input=validateBake(data);
  const manifest=path.join(root,'tools/crest-bakes.json'),bakes=JSON.parse(fs.readFileSync(manifest,'utf8'));
  bakes[input.crest]=input.version===1?input.effects:{effects:input.effects,studio:input.studio};const lua=render(bakes);parser.parse(lua,{luaVersion:'5.1'});
  writeBakeFiles(manifest,JSON.stringify(bakes,null,2)+'\n',lua);
  const summary=`Baked ${input.crest} (${input.effects.length} layers).`;
  console.log(source==='-'?summary:summary+' Run npm test, npm run audit, then build the release.');
 }catch(error){
  console.error(error.message);
  process.exitCode=1;
 }
}
module.exports={validateBake,render,crests};
