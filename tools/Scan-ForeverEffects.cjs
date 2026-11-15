// Checks actual Forever CASC contents. Native files stay in the game archives.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {LocalCASC}=require('./casc-local.cjs');
const root=path.resolve(__dirname,'..'),c=new LocalCASC(process.argv[2]||'D:/World of Warcraft');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const entries=new Map();
for(const part of ['spells','misc'])for(const line of fs.readFileSync(path.join(root,'artifacts/catalog-source',part+'.csv'),'utf8').split(/\r?\n/)){
 const m=/^(\d+);((?:spells|particles)\/.*\.m2)$/i.exec(line);if(m)entries.set(+m[1],m[2]);
}
for(const [id,p]of Object.entries(JSON.parse(fs.readFileSync(path.join(__dirname,'effect-preview-presets.json'),'utf8'))))entries.set(+id,p.path);
function chunks(raw){
 const result=new Map();for(let p=0;p<raw.length;){if(p+8>raw.length)throw Error('Invalid chunk header');const tag=raw.toString('ascii',p,p+4),n=raw.readUInt32LE(p+4);p+=8;if(p+n>raw.length)throw Error('Invalid chunk length');result.set(tag,raw.subarray(p,p+n));p+=n;}return result;
}
function cubeBounds(b){return [160,164,168,172,176,180].every((o,i)=>Math.abs(b.readFloatLE(o)-(i<3?-1:1)*0.1388888955116272)<0.000001);}
const dependencies=new Map(),allowed=[],rejected={},inspections=[],modelCache=new Map();
function dependency(id,kind){
 if(!id)return;
 const key=kind+':'+id;if(dependencies.has(key)){const error=dependencies.get(key);if(error)throw Error(error);return;}
 dependencies.set(key,null);
 try{
  const b=c.read(id),magic=b.toString('ascii',0,4);
  if(kind==='skin'&&magic!=='SKIN'||kind==='texture'&&!['BLP1','BLP2'].includes(magic))throw Error('Invalid '+kind+' header');
  if(kind==='skeleton')checkReferences(chunks(b));
 }catch(e){const error='Dependency '+id+': '+e.message;dependencies.set(key,error);throw Error(error);}
}
function checkReferences(parts){
 for(const [tag,kind]of [['SFID','skin'],['TXID','texture'],['BFID','bone'],['SKID','skeleton']]){
  const b=parts.get(tag);if(b){if(b.length%4)throw Error('Invalid '+tag);for(let p=0;p<b.length;p+=4)dependency(b.readUInt32LE(p),kind);}
 }
 const anim=parts.get('AFID');if(anim){if(anim.length%8)throw Error('Invalid AFID');for(let p=4;p<anim.length;p+=8)dependency(anim.readUInt32LE(p),'animation');}
 const parent=parts.get('SKPD');if(parent&&parent.length>=12)dependency(parent.readUInt32LE(8),'skeleton');
}
function inspect(id){
 const key=c.key(id);if(!key)return {reason:'absent'};
 if(key===c.key(166046))return {reason:'placeholder'};
 if(modelCache.has(key))return modelCache.get(key);
 let result;
 try{
  const raw=c.read(id),parts=chunks(raw),b=parts.get('MD21');
  if(!b||b.length<304||b.toString('ascii',0,4)!=='MD20'||![272,274].includes(b.readUInt32LE(4)))throw Error('Unsupported model header');
  const n=b.readUInt32LE(8),o=b.readUInt32LE(12);if(o+n>b.length)throw Error('Invalid internal name');
  const name=b.toString('utf8',o,o+n).replace(/\0/g,'');
  if(/errorcube/i.test(name)||cubeBounds(b))result={reason:'placeholder',name};
  else if(!b.readUInt32LE(60)&&!b.readUInt32LE(288)&&!b.readUInt32LE(296))result={reason:'empty',name};
  else{
   if(b.readUInt32LE(68)&&!parts.has('SFID'))throw Error('Missing skin references');
   if(b.readUInt32LE(80)&&!parts.has('TXID'))throw Error('Missing texture references');
   checkReferences(parts);result={reason:'available',name,sha256:hash(raw)};
  }
 }catch(e){result={reason:'unavailable',detail:e.message};}
 modelCache.set(key,result);return result;
}
try{
 for(const [id,file]of entries){const result=inspect(id);if(result.reason==='available')allowed.push(id);else (rejected[result.reason]??=[]).push(id);inspections.push({id,path:file,...result});if(inspections.length%1000===0)console.log('Checked '+inspections.length+' models');}
 const report=JSON.stringify(inspections,null,2)+'\n';fs.writeFileSync(path.join(root,'artifacts/forever-source/inspection.json'),report);
 const manifest={product:'wowf',version:c.build.Version,buildKey:c.build['Build Key'],rootKey:c.config.root,locale:'enUS',sourceModels:entries.size,models:allowed.length,dependencyFiles:dependencies.size,inspectionSHA256:hash(report),allowed:allowed.sort((a,b)=>a-b),rejected};
 fs.writeFileSync(path.join(__dirname,'forever-effects.json'),JSON.stringify(manifest,null,2)+'\n');
 console.log(JSON.stringify({...manifest,allowed:allowed.length,rejected:Object.fromEntries(Object.entries(rejected).map(([k,v])=>[k,v.length]))},null,2));
}finally{c.close();}
