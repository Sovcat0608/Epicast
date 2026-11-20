const fs=require('fs'),assert=require('assert'),crypto=require('crypto');
const source=fs.readFileSync('concepts/druid-sisters/Moonwarden-Groveheart-review.png');
assert.equal(crypto.createHash('sha256').update(source).digest('hex'),'926c6cc974fcd6015a1ae576e52123c7c4f2a157decadd3f0cb5f92dca157034');
assert.equal(source.readUInt32BE(16),1536);assert.equal(source.readUInt32BE(20),1024);assert.equal(source[25],6);
for(const art of ['Moonwarden','Groveheart'])for(const w of [192,288,384,480,576,768]){
 const t=fs.readFileSync(`Media/${art}CASSize${w}.tga`),tw=t.readUInt16LE(12),th=t.readUInt16LE(14),h=w*4/3;
 assert.equal(t[2],2);assert.equal(t[16],32);assert.equal(t[17],40);
 assert.equal(tw,2**Math.ceil(Math.log2(w)));assert.equal(th,2**Math.ceil(Math.log2(h)));
 assert.equal(t.length,18+tw*th*4);
 let coverage=0,transparent=0;
 for(let y=0;y<th;y++)for(let x=0;x<tw;x++){
  const a=t[18+(y*tw+x)*4+3];
  if(x>=w||y>=h)assert.equal(a,0,'Power-of-two padding must stay transparent');
  else {if(a>=240)coverage++;if(!a)transparent++;}
 }
 assert(coverage>w*h*.25&&transparent>w*h*.25,'Both a solid ornament and genuine transparency must survive');
}
console.log('PASS: approved Druid source hash, twelve 3:4 textures, RGBA headers, transparent padding and silhouette coverage');
const trio=fs.readFileSync('concepts/druid-specialization-trio/Druid-specializations-review-v8.png');
assert.equal(crypto.createHash('sha256').update(trio).digest('hex'),'4d592a779782dd20fa9b0bcbd38ce7b018613397ea53a53e0abc77e4c76cbfc8');
assert.equal(trio.readUInt32BE(16),1882);assert.equal(trio.readUInt32BE(20),836);assert.equal(trio[25],6);
for(const art of ['DruidRestoration','DruidBalance','DruidFeral'])for(const w of [192,288,384,480,576,660]){
 const t=fs.readFileSync(`Media/${art}CASSize${w}.tga`),tw=t.readUInt16LE(12),th=t.readUInt16LE(14),h=w*4/3;
 assert.equal(t[2],2);assert.equal(t[16],32);assert.equal(t[17],40);
 assert.equal(tw,2**Math.ceil(Math.log2(w)));assert.equal(th,2**Math.ceil(Math.log2(h)));
 assert.equal(t.length,18+tw*th*4);let solid=0,transparent=0;
 for(let y=0;y<th;y++)for(let x=0;x<tw;x++){
  const a=t[18+(y*tw+x)*4+3];
  if(x>=w||y>=h)assert.equal(a,0);
  else {if(a>=240)solid++;if(a<8)transparent++;}
 }
 assert(solid>w*h*.4&&transparent>w*h*.25,'A solid crest and genuine transparency must survive');
}
const restoration=fs.readFileSync('concepts/restoration-autumn-treant/Restoration registered.png');
assert.equal(crypto.createHash('sha256').update(restoration).digest('hex'),'196ee273be9359041f9e811d1b84b54d8fa3d85a33d709e298d7db71cc74a682');
const native=fs.readFileSync('Media/DruidRestorationCASSize660.tga');
const stride=native.readUInt16LE(12);
let bounds=[660,880,0,0];
for(let y=0;y<880;y++)for(let x=0;x<660;x++)if(native[18+4*(y*stride+x)+3]>=8){
 bounds=[Math.min(bounds[0],x),Math.min(bounds[1],y),Math.max(bounds[2],x+1),Math.max(bounds[3],y+1)];
}
assert.deepEqual(bounds,[17,86,642,802]);
console.log('PASS: registered Restoration pose and native bounds, Druid source provenance, 18 size-specific textures and transparent padding');

for (const width of [192,288,384,480,576,660]) {
 const height=width*4/3,stem=width===384?'RestorationIdle':`RestorationIdleCASSize${width}Page`;
 const files=fs.readdirSync('Media').filter(name=>new RegExp(`^${stem}\\d{2}\\.tga$`).test(name)).sort();
 const frames=new Set();
 let remaining=32;
 for(const file of files){
  assert(remaining>0,'Unexpected extra atlas page');
  const t=fs.readFileSync(`Media/${file}`),tw=t.readUInt16LE(12),th=t.readUInt16LE(14);
  assert.deepEqual([t[2],t[16],t[17]],[2,32,40]);
  assert(tw<=1024&&th<=1024&&tw>=width&&th>=height);
  const columns=Math.floor(tw/width),cells=Math.min(remaining,columns*Math.floor(th/height));
  for(let cell=0;cell<cells;cell++){
   const x=cell%columns*width,y=Math.floor(cell/columns)*height,digest=crypto.createHash('sha256');
   for(let row=0;row<height;row++){
    const start=18+4*((y+row)*tw+x),data=t.subarray(start,start+width*4);
    assert.equal(data[3]+data[width*4-1],0,'Transparent cel side guard');
    if(row===0||row===height-1)assert(data.every((value,i)=>i%4!==3||value===0),'Transparent cel top/bottom guard');
    digest.update(data);
   }
   frames.add(digest.digest('hex'));
  }
  remaining-=cells;
 }
 assert.equal(remaining,0);
 assert.equal(frames.size,32);
}
console.log('PASS: six size-specific Restoration Idle banks, 32 distinct RGBA frames per size and transparent atlas guards');
