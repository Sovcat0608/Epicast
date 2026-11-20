const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
process.env.PLAYWRIGHT_BROWSERS_PATH=path.join(__dirname,'.browsers');
const {chromium}=require('playwright');
const {createServer}=require('./server.cjs');
const out=path.join(__dirname,'results');fs.mkdirSync(out,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const repo=path.resolve(__dirname,'../..'),installed='D:/World of Warcraft/_forever_/Interface/AddOns/Epicast';
const files=['Epicast.toc','README.md','CHANGELOG.md','LICENSE','THIRD-PARTY-CAS.txt',...fs.readFileSync(path.join(repo,'Epicast.toc'),'utf8').split(/\r?\n/).map(s=>s.trim()).filter(s=>s&&!s.startsWith('#')),...Object.keys(JSON.parse(fs.readFileSync(path.join(repo,'tools/media-manifest.json'))))];
function payloadHashes(dir){return Object.fromEntries(files.map(f=>[f,hash(fs.readFileSync(path.join(dir,f)))]));}
async function imageDifference(page,a,b){return page.evaluate(async([a,b])=>{async function pixels(base64){const image=new Image();image.src='data:image/png;base64,'+base64;await image.decode();const c=document.createElement('canvas');c.width=image.width;c.height=image.height;const x=c.getContext('2d');x.drawImage(image,0,0);return x.getImageData(0,0,c.width,c.height).data;}const x=await pixels(a),y=await pixels(b);let changed=0,total=0;for(let i=0;i<x.length;i+=4){const d=Math.abs(x[i]-y[i])+Math.abs(x[i+1]-y[i+1])+Math.abs(x[i+2]-y[i+2]);if(d>6)changed++;total+=d;}return {changed,total};},[a.toString('base64'),b.toString('base64')]);}
(async()=>{
 const before={source:payloadHashes(repo),installed:payloadHashes(installed)};
 const app=createServer({port:4319});await app.listen();let browser,context;
 const report={started:new Date().toISOString(),build:app.config.build,checks:[],screenshots:[],cycles:[],errors:[],externalRequests:[],assetRequests:[]};
 const check=(name,value=true)=>{assert.ok(value,name);report.checks.push(name);console.log('PASS '+name);};
 try{
  assert.deepEqual(app.config.metadata[166602].sequences,[{id:0,variation:0,duration:1000}]);check('166602 is Stand-only in actual Forever data');
  browser=await chromium.launch({headless:true,args:['--enable-unsafe-swiftshader']});
  context=await browser.newContext({viewport:{width:1440,height:1050},recordVideo:{dir:out,size:{width:1440,height:1050}}});
  await context.route('**/*',route=>{const u=new URL(route.request().url());if(u.origin!=='http://127.0.0.1:4319'){report.externalRequests.push(u.href);route.abort();}else route.continue();});
  const page=await context.newPage();page.on('pageerror',e=>report.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
  page.on('request',r=>{if(r.url().includes('/asset?'))report.assetRequests.push(r.url());});
  const base='http://127.0.0.1:4319';
  await page.goto(base+'/lab.html');await page.waitForFunction(()=>lab.diagnostics().layers.length===3&&lab.diagnostics().layers.every(l=>l.ready));
  await page.waitForTimeout(2000);
  check('All three Restoration models render', (await page.evaluate(()=>lab.diagnostics())).layers.every(l=>l.pixels.rgb>100&&l.pixels.error===0));
  await page.evaluate(()=>lab.setPaused(true));await page.waitForTimeout(100);
  const stage=page.locator('#stage'),all=await stage.screenshot();
  await page.evaluate(()=>lab.frames().forEach(f=>f.enabled=false));await page.waitForTimeout(100);
  const bare=await stage.screenshot();report.compositeDifference=await imageDifference(page,all,bare);check('Rendered effects visibly change full crest pixels',report.compositeDifference.changed>100);
  for(let i=0;i<3;i++){
   await page.evaluate(i=>lab.frames().forEach((f,j)=>f.enabled=i===j),i);await page.waitForTimeout(100);const image=await stage.screenshot();const diff=await imageDifference(page,bare,image);report.checks.push({name:'Individual layer contributes to composite',id:app.config.presets[0].layers[i].fileID,...diff});assert.ok(diff.changed>20,'Layer must actually appear on crest');
  }
  await page.evaluate(()=>lab.frames().forEach(f=>f.enabled=true));await page.waitForTimeout(100);
  const front=await stage.screenshot();await page.evaluate(()=>lab.frames().forEach(f=>f.iframe.style.zIndex='0'));await page.waitForTimeout(100);const behind=await stage.screenshot();report.depthDifference=await imageDifference(page,front,behind);check('Effects can render behind or above opaque artwork',report.depthDifference.changed>20);
  await page.evaluate(()=>lab.frames().forEach((f,i)=>f.iframe.style.zIndex=String(i+2)));
  async function geometry(t,follow=true){await page.evaluate(({t,follow})=>{lab.setTime(t);document.querySelector('#follow').checked=follow;},{t,follow});await page.waitForTimeout(100);return page.evaluate(()=>{const art=document.querySelector('.art').getBoundingClientRect();return {art:art.y,effects:lab.frames().map(f=>f.camera.anchor[1])}});}
  const a=await geometry(0),b=await geometry(3),c=await geometry(6);check('Hover moves 2.4% of artwork height over three seconds',Math.abs(Math.abs(b.art-a.art)-640*.024)<.05);check('Hover returns after six seconds',Math.abs(c.art-a.art)<.05);check('Attached effect layers remain registered',b.effects.every((v,i)=>Math.abs((v-a.effects[i])-(b.art-a.art))<.05));
  const d=await geometry(0,false),e=await geometry(3,false);check('Unattached effect layers stay stationary',e.effects.every((v,i)=>Math.abs(v-d.effects[i])<.05));await geometry(0,true);
  await page.screenshot({path:path.join(out,'restoration.png')});report.screenshots.push('restoration.png');
  const requests=report.assetRequests.length,loads=(await page.evaluate(()=>lab.diagnostics())).layers.map(l=>l.sceneLoads);
  await page.locator('#cycle').click();
  for(let n=1;n<=5;n++){
   await page.waitForFunction(n=>lab.diagnostics().replays>=n,n,{timeout:45000});await page.waitForTimeout(350);
   const sample=await page.evaluate(()=>lab.diagnostics());report.cycles.push(sample);check('Replay '+n+' keeps 166602 visibly rendering',sample.layers.find(l=>l.id===166602).pixels.rgb>100);
   await page.waitForFunction(()=>lab.diagnostics().layers.every(l=>!l.active),null,{timeout:45000});
   check('Cycle '+n+' hides the rendered layers',await page.evaluate(()=>lab.frames().every(f=>f.iframe.style.opacity==='0')));
  }
  await page.waitForFunction(()=>lab.diagnostics().events.some(e=>e.message==='Five cycles complete'),null,{timeout:45000});
  const warm=await page.evaluate(()=>lab.diagnostics());assert.deepEqual(warm.layers.map(l=>l.sceneLoads),loads);check('Five replay cycles reuse all loaded scenes');check('Five cycles issue no additional game-asset requests',report.assetRequests.length===requests);check('166602 changes across replay samples',new Set(report.cycles.map(c=>c.layers.find(l=>l.id===166602).pixels.signature)).size>1);
  await page.locator('#cold').click();await page.waitForFunction(()=>lab.diagnostics().layers.every(l=>l.ready&&l.sceneLoads===2));await page.waitForTimeout(600);report.coldReload=await page.evaluate(()=>lab.diagnostics());check('Cold scene recreation still renders 166602',report.coldReload.layers.find(l=>l.id===166602).pixels.rgb>100);
  await page.selectOption('#preset','arcane');await page.waitForFunction(()=>lab.diagnostics().scene==='arcane'&&lab.diagnostics().layers.length===3&&lab.diagnostics().layers.every(l=>l.ready));await page.waitForTimeout(2000);
  report.arcaneSamples=[];await page.click('#replay');for(let i=0;i<12;i++){await page.waitForTimeout(200);report.arcaneSamples.push(await page.evaluate(()=>lab.diagnostics()));}
  report.arcane=report.arcaneSamples.at(-1);check('Arcane Glow and Blast produce pixels during playback',report.arcane.layers.filter(l=>l.id!==5054328).every(l=>report.arcaneSamples.some(s=>s.layers.find(x=>x.id===l.id).pixels.rgb>100)&&l.pixels.error===0));
  const barrage=report.arcaneSamples.map(s=>s.layers.find(l=>l.id===5054328));
  check('5054328 remains visible in every sampled Hold frame',barrage.filter(l=>l.phase==='main').length>4&&barrage.filter(l=>l.phase==='main').every(l=>l.pixels.rgb>100&&l.pixels.debug[2]===158));
  report.compatibility={arcaneBarrage:{id:5054328,passed:true,visibleSamples:barrage.filter(l=>l.pixels.rgb>100).length,blankMainSamples:barrage.filter(l=>l.phase==='main'&&l.pixels.rgb===0).length},nativeCameraMapping:'Installed Lua camera/scale/origin/projection checked independently; visual material parity remains manual',particleRewind:'Not guaranteed by sequence reselection'};
  await page.screenshot({path:path.join(out,'arcane.png')});report.screenshots.push('arcane.png');
  report.barrageCycles=[];
  const arcaneRequests=report.assetRequests.length;
  await page.click('#cycle');
  for(let i=0;i<5;i++){
   await page.waitForFunction(n=>lab.diagnostics().replays>=n,2+i,{timeout:45000});
   await page.waitForFunction(()=>lab.diagnostics().layers.find(l=>l.id===5054328).phase==='main',null,{timeout:45000});
   const d=await page.evaluate(()=>lab.diagnostics());report.barrageCycles.push(d);
   check('Barrage cycle '+(i+1)+' renders Hold',d.layers.find(l=>l.id===5054328).pixels.rgb>100);
   await page.waitForFunction(()=>lab.diagnostics().layers.every(l=>!l.active),null,{timeout:45000});
  }
  await page.waitForFunction(()=>lab.diagnostics().replays>=6&&lab.diagnostics().layers.find(l=>l.id===5054328).phase==='main',null,{timeout:45000});
  check('Barrage repeat cycles require no asset reloads',report.assetRequests.length===arcaneRequests);
  await page.click('#cold');await page.waitForFunction(()=>lab.diagnostics().layers.every(l=>l.ready&&l.sceneLoads===2));
  await page.waitForFunction(()=>lab.diagnostics().layers.find(l=>l.id===5054328).phase==='main');await page.waitForTimeout(600);
  check('Barrage Hold also survives cold model recreation',(await page.evaluate(()=>lab.diagnostics())).layers.find(l=>l.id===5054328).pixels.rgb>100);
  await page.evaluate(()=>lab.setPaused(true));
  report.viewport=(await page.evaluate(()=>lab.diagnostics())).layers.map(l=>l.viewport);
  check('Every effect uses the entire preview viewport',report.viewport.every(v=>v.cssWidth===935&&v.cssHeight===660));
  // Stress an extended effect, then compare with the old 384px local scissor.
  await page.evaluate(()=>{const f=lab.frames().find(f=>f.row.fileID===5054328);f.row.scale*=2;f.row.trailX=0;f.row.trailY=20;lab.frames().forEach(x=>x.enabled=x===f);});
  await page.evaluate(()=>lab.setPaused(false));await page.waitForTimeout(800);await page.evaluate(()=>lab.setPaused(true));
  const open=await stage.screenshot();
  await page.evaluate(()=>{for(const f of lab.frames())f.iframe.style.clipPath='inset(138px 275.5px)';});await page.waitForTimeout(100);
  const cropped=await stage.screenshot();report.clippingDifference=await imageDifference(page,open,cropped);
  check('Effect pixels beyond the former local square survive',report.clippingDifference.changed>100);
  await page.evaluate(()=>lab.frames().forEach(f=>f.iframe.style.clipPath='none'));
  await page.setViewportSize({width:1280,height:1050});await page.waitForTimeout(150);
  await page.evaluate(()=>lab.setPaused(false));await page.waitForTimeout(100);await page.evaluate(()=>lab.setPaused(true));
  check('Resizing updates all framebuffers without reloading models',(await page.evaluate(()=>lab.diagnostics())).layers.every(l=>l.viewport.cssWidth===775&&l.sceneLoads===2));report.arcaneRepeated=await page.evaluate(()=>lab.diagnostics());check('Repeated playback and one deliberate reload have expected scene counts',report.arcaneRepeated.layers.every(l=>l.sceneLoads===2&&l.replays>=6));
  check('No outgoing network needed during rendering',report.externalRequests.length===0);
  check('No browser runtime errors',report.errors.length===0);
  report.server=await(await page.request.get(base+'/api/status')).json();check('Every renderer asset dependency resolved',report.server.failures.length===0);
  check('Unknown game asset cannot be read',(await page.request.get(base+'/asset?id=1')).status()===403);
  check('HTTP writes are rejected',(await page.request.post(base+'/api/config',{data:{}})).status()===405);
  check('Foreign origins rejected',(await page.request.get(base+'/api/config',{headers:{Origin:'https://example.com'}})).status()===403);
  report.video=path.basename(await page.video().path());
 }catch(e){report.failure=e.stack;throw e;}finally{
  if(context)await context.close();if(browser)await browser.close();await new Promise(r=>app.server.close(r));
  const after={source:payloadHashes(repo),installed:payloadHashes(installed)};
  const changed=kind=>files.filter(f=>after[kind][f]!==before[kind][f]);
  report.preservation={sourcePayloads:files.length,installedPayloads:files.length,allInstalledHashesUnchanged:changed('installed').length===0,sourceChangesDuringRun:changed('source'),savedVariablesAccessed:false,before,after};
  // Other chats may edit addon source concurrently. Record those observations;
  // installation preservation remains a strict assertion, not an exemption.
  if(changed('installed').length)report.failure=(report.failure||'')+'\nInstalled payload changed during test: '+changed('installed').join(', ');
  report.finished=new Date().toISOString();report.outcome=report.failure?'test-failure':'renderer-camera-clipping-and-playback-checks-passed';fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log('Evidence: '+path.join(out,'verification.json'));
  assert.deepEqual(after.installed,before.installed,'Installed addon payload must remain unchanged');
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
