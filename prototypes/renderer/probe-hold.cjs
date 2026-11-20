const fs=require('fs'),path=require('path');process.env.PLAYWRIGHT_BROWSERS_PATH=path.join(__dirname,'.browsers');
const {chromium}=require('playwright'),{createServer}=require('./server.cjs');
(async()=>{const app=createServer({port:4320});await app.listen();const browser=await chromium.launch({headless:true,args:['--enable-unsafe-swiftshader']});
try{const page=await browser.newPage({viewport:{width:1440,height:1050}});page.on('pageerror',e=>console.log('ERROR',e.message));page.on('console',m=>{if(m.type()==='error')console.log(m.text());});
await page.goto('http://127.0.0.1:4320');await page.waitForFunction(()=>lab.diagnostics().layers.length===3&&lab.diagnostics().layers.every(l=>l.ready));
await page.waitForTimeout(1500);await page.screenshot({path:'results/new-restoration.png'});console.log('RESTO',JSON.stringify((await page.evaluate(()=>lab.diagnostics())).layers.map(l=>({id:l.id,p:l.pixels}))));
await page.selectOption('#preset','arcane');await page.waitForFunction(()=>lab.diagnostics().scene==='arcane'&&lab.diagnostics().layers.length===3&&lab.diagnostics().layers.every(l=>l.ready));
const samples=[];for(let i=0;i<24;i++){await page.waitForTimeout(250);const d=await page.evaluate(()=>lab.diagnostics());samples.push(d);console.log(i,JSON.stringify(d.layers.map(l=>({id:l.id,phase:l.phase,rgb:l.pixels.rgb,debug:l.pixels.debug,errors:l.errors}))));}
await page.screenshot({path:'results/new-arcane.png'});fs.writeFileSync('results/hold-probe.json',JSON.stringify(samples,null,2));
}finally{await browser.close();await new Promise(r=>app.server.close(r));}})().catch(e=>{console.error(e);process.exitCode=1;});
