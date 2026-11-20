// Isolated read-only asset server. Never imports addon/account configuration.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {LocalCASC}=require('../../tools/casc-local.cjs');
const root=path.resolve(__dirname,'../..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
function chunks(b){const out=new Map();for(let p=0;p<b.length;){if(p+8>b.length)throw Error('Truncated chunk');const tag=b.toString('ascii',p,p+4),n=b.readUInt32LE(p+4);p+=8;if(p+n>b.length)throw Error('Invalid chunk');out.set(tag,b.subarray(p,p+n));p+=n;}return out;}
function describe(raw){const c=chunks(raw),b=c.get('MD21');if(!b||b.toString('ascii',0,4)!=='MD20')throw Error('Expected M2');const sequences=[];for(let i=0,n=b.readUInt32LE(28),p=b.readUInt32LE(32);i<n;i++,p+=64)sequences.push({id:b.readUInt16LE(p),variation:b.readUInt16LE(p+2),duration:b.readUInt32LE(p+4)});return {sha256:hash(raw),version:b.readUInt32LE(4),vertices:b.readUInt32LE(60),ribbons:b.readUInt32LE(288),particles:b.readUInt32LE(296),sequences,bounds:[160,164,168,172,176,180].map(o=>b.readFloatLE(o))};}
function createServer({game=process.env.EPICAST_GAME_ROOT||'D:/World of Warcraft',port=4318,profile}={}){
 const renderer=require('./native/build-manifest.cjs').verify();
 const casc=new LocalCASC(game),catalog=JSON.parse(fs.readFileSync(path.join(root,'tools/forever-effects.json')));
 const studio=require('./studio-data.cjs').studioData(profile),allowed=new Set(catalog.allowed),entries=new Map(studio.catalog.map(e=>[e.id,e]));
 if(casc.build.Version!==catalog.version||casc.config.root!==catalog.rootKey){casc.close();throw Error('Local client build differs from inspected Epicast catalogue; inspect before testing.');}
 const restoration=JSON.parse(fs.readFileSync(path.join(root,'tools/crest-bakes.json')))['DRUID:restoration'];
 const arcane=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/arcane-beta13.json')));
 const testIDs=new Set([166694,166602,1519919,166009,5054328,1699091]);
 const models=new Map([...restoration,...arcane].filter(row=>testIDs.has(row.fileID)).map(row=>[row.fileID,row]));
 const permitted=new Set(),cache=new Map(),assetLog=[],failures=[],metadata={};
 let cacheBytes=0;
 function read(id){if(cache.has(id)){const b=cache.get(id);cache.delete(id);cache.set(id,b);return b;}const b=casc.read(id);if(b.length>128*1024*1024)throw Error('Asset exceeds local preview memory limit');while(cacheBytes+b.length>128*1024*1024&&cache.size){const key=cache.keys().next().value;cacheBytes-=cache.get(key).length;cache.delete(key);}cache.set(id,b);cacheBytes+=b.length;assetLog.push({id,bytes:b.length,sha256:hash(b)});if(assetLog.length>2000)assetLog.shift();return b;}
 function dependencies(id){
  // Register a complete dependency closure atomically. Failed loads must not
  // leave a partly permitted model that appears valid on the next attempt.
  const pending=new Set();
  function visit(key){if(!key||permitted.has(key)||pending.has(key))return;pending.add(key);const b=read(key);if(!['MD21','SKL1'].includes(b.toString('ascii',0,4)))return;const c=chunks(b);for(const tag of ['SFID','TXID','BFID','SKID']){const a=c.get(tag);if(a)for(let p=0;p<a.length;p+=4)visit(a.readUInt32LE(p));}const a=c.get('AFID');if(a)for(let p=4;p<a.length;p+=8)visit(a.readUInt32LE(p));const parent=c.get('SKPD');if(parent)visit(parent.readUInt32LE(8));}
  visit(id);for(const key of pending)permitted.add(key);
 }
 for(const [id,row]of models){if(!catalog.allowed.includes(id))throw Error('Effect not in Forever allowlist: '+id);dependencies(id);metadata[id]={...describe(read(id)),name:row.name};}
 function model(id){
  if(!allowed.has(id)||!entries.has(id)||id===166046)throw Error('Effect unavailable in Forever');
  const entry=entries.get(id),m=metadata[id]||describe(read(id));
  if(!m.bounds.every(Number.isFinite))throw Error('Model bounds cannot be calibrated for this preview');
  if(m.bounds.every(v=>Math.abs(Math.abs(v)-.1388888955116272)<.000001))throw Error('Missing-model placeholder blocked');
  dependencies(id);metadata[id]=m;const b=m.bounds,span=Math.max(b[3]-b[0],b[4]-b[1],b[5]-b[2]);
  const p=entry.preset||{},origin=p.origin||[0,1,2].map(i=>(b[i]+b[i+3])/2);
  return{...entry,metadata:m,row:{fileID:id,name:entry.name,animation:p.animation||0,scale:p.scale||(span>.001&&span<100000?2.5/span:1),originX:origin[0],originY:origin[1],originZ:origin[2],azimuth:p.angle||0,elevation:p.elevation||0,desaturation:p.desaturation||0,trailSize:100,trailAngle:90,trailX:0,trailY:0,trailOpacity:70,behavior:'static',effectLayer:'front'}};
 }
 const preset=(key,title,rows,ids,art,w,h)=>({key,title,art:'/art/'+art,width:w,height:h,layers:ids.map(id=>({...rows.find(r=>r.fileID===id),metadata:metadata[id]}))});
 const config={build:casc.build.Version,root:casc.config.root,renderer,metadata,presets:[
  preset('restoration','Restoration',restoration,[166694,166602,1519919],'DruidRestorationCASSize480.tga',480,640),
  preset('arcane','Arcane',arcane,[166009,5054328,1699091],'MageRebootArcaneCASSize480.tga',480,480)
 ]};
 const publicFiles=new Map(['index.html','lab.html','app.js','style.css','studio.css','studio.js','studio-state.js','studio-preview.js','studio-engine.html','studio-engine.js','projection.js','effect.html','effect.js','vendor/project.js','vendor/project.wasm','vendor/project.data'].map(p=>['/'+p,path.join(__dirname,p)]));
 for(const ext of ['js','wasm','data'])publicFiles.set('/vendor/project.'+ext,path.join(__dirname,'vendor/build_packed/project.'+ext));
 publicFiles.set('/studio.html',path.join(__dirname,'studio.html'));
 for(const ext of ['js','wasm','data'])publicFiles.set('/vendor/upstream/project.'+ext,path.join(__dirname,'vendor/project.'+ext));
 const artFiles=new Map(studio.crests.filter(p=>p.art).map(p=>[p.art,path.join(root,'Media',p.art.split('/').pop())]));
 const types={'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.tga':'application/octet-stream'};
 const server=http.createServer((req,res)=>{
  res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Cache-Control','no-store');res.setHeader('Cross-Origin-Resource-Policy','same-origin');
  if(!['127.0.0.1:'+port,'localhost:'+port].includes(req.headers.host)){res.writeHead(403).end('Localhost only');return;}
  if(req.headers.origin&&!['http://127.0.0.1:'+port,'http://localhost:'+port].includes(req.headers.origin)){res.writeHead(403).end('Same origin only');return;}
  if(req.method!=='GET'){res.writeHead(405).end('Read only');return;}
  const u=new URL(req.url,'http://127.0.0.1:'+port);
  try{
   if(u.pathname==='/api/config'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(config));return;}
   if(u.pathname==='/api/studio'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({...studio,build:casc.build.Version}));return;}
   if(u.pathname==='/api/model'){const id=Number(u.searchParams.get('id'));if(!Number.isSafeInteger(id)||!allowed.has(id)){res.writeHead(403).end('Outside Forever catalogue');return;}res.setHeader('Content-Type','application/json');try{res.end(JSON.stringify(model(id)));}catch(e){res.writeHead(422).end(JSON.stringify({error:e.message}));}return;}
   if(u.pathname==='/api/status'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({build:casc.build.Version,assets:assetLog,failures}));return;}
   if(u.pathname==='/asset'){const id=Number(u.searchParams.get('id'));if(!Number.isSafeInteger(id)||!permitted.has(id)){res.writeHead(403).end('Outside prototype dependency set');return;}res.setHeader('Content-Type','application/octet-stream');res.end(read(id));return;}
   const file=publicFiles.get(u.pathname==='/'?'/studio.html':u.pathname)||artFiles.get(u.pathname);
   if(file){res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));return;}
   if(u.pathname!=='/favicon.ico')failures.push({url:u.pathname+u.search,error:'Not in route allowlist'});
   res.writeHead(404).end('Not found');
  }catch(e){failures.push({url:u.pathname,error:e.message});res.writeHead(500).end(e.message);}
 });
 server.on('close',()=>casc.close());
 return {server,config,port,listen:()=>new Promise(resolve=>server.listen(port,'127.0.0.1',resolve))};
}
module.exports={createServer,chunks,describe};
if(require.main===module){
 const profilePath=require('./sync-game-config.cjs').cache;
 const profile=fs.existsSync(profilePath)?JSON.parse(fs.readFileSync(profilePath,'utf8')):undefined;
 const app=createServer({profile});
 app.listen().then(()=>console.log('Epicast renderer prototype: http://127.0.0.1:'+app.port+' (read-only Forever '+app.config.build+')'));
 for(const s of ['SIGINT','SIGTERM'])process.on(s,()=>app.server.close(()=>process.exit(0)));
}
