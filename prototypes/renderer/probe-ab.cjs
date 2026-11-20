const fs=require('fs'),path=require('path'),assert=require('assert/strict');process.env.PLAYWRIGHT_BROWSERS_PATH=path.join(__dirname,'.browsers');
const {chromium}=require('playwright'),{createServer}=require('./server.cjs'),projection=require('./projection.js');
(async()=>{const app=createServer({port:4320});await app.listen();const browser=await chromium.launch({headless:true,args:['--enable-unsafe-swiftshader']});const report=[];
try{for(const mode of ['upstream','autofit','calibrated']){const page=await browser.newPage({viewport:{width:768,height:768}});page.on('pageerror',e=>console.log('ERROR',e.message));
await page.goto('http://127.0.0.1:4320/effect.html?id=5054328&'+mode);await page.waitForFunction(()=>engineReady);
const row=app.config.presets[1].layers.find(r=>r.fileID===5054328);const cam=projection.camera(row,{width:768,height:768,artWidth:480,kind:'arcane',follow:false});
await page.evaluate(c=>{if(!location.search.includes('upstream')&&!location.search.includes('autofit'))configure(c,768,768);window.step=n=>{for(let i=0;i<n;i++)tick(1/60);};window.timer=setInterval(()=>tick(1/60),16);},cam);
await page.waitForFunction(()=>diagnostics.ready);await page.waitForTimeout(700);await page.evaluate(()=>clearInterval(timer));
const position=await page.evaluate(()=>{const p=Module._malloc(12);Module._getScenePos(p);const a=[...new Float32Array(Module.HEAPU8.buffer,p,3)];Module._free(p);return a;});
const samples=[];for(let cycle=0;cycle<3;cycle++){await page.evaluate(()=>{replay(0);step(30);replay(158);});for(let i=0;i<25;i++){const p=await page.evaluate(()=>{step(30);return inspectPixels();});samples.push({cycle,t:(i+1)/2,...p});}await page.evaluate(()=>{replay(159);step(30);});}
await page.screenshot({path:'results/ab-'+mode+'.png'});report.push({mode,position,samples});console.log(mode,JSON.stringify({blank:samples.filter(p=>!p.rgb).length,min:Math.min(...samples.map(p=>p.rgb)),max:Math.max(...samples.map(p=>p.rgb)),position,debug:samples.at(-1).debug}));await page.close();}
fs.writeFileSync('results/ab-probe.json',JSON.stringify(report,null,2));
assert.ok(report.find(r=>r.mode==='upstream').samples.some(p=>p.rgb===0),'Negative control reproduces blank Hold');
assert.ok(report.find(r=>r.mode==='autofit').samples.some(p=>p.rgb===0&&p.debug[2]===158&&p.debug[4]>0&&p.debug[5]>0),'Same engine with old camera blanks while Hold and particles remain active');
assert.ok(report.find(r=>r.mode==='calibrated').samples.every(p=>p.rgb>100&&p.debug[2]===158&&p.error===0),'Calibrated camera renders all 75 sustained Hold samples');
}finally{await browser.close();await new Promise(r=>app.server.close(r));}})().catch(e=>{console.error(e);process.exitCode=1;});
