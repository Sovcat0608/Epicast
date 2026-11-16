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
console.log('PASS: exact approved trio v8 source, eighteen 3:4 CAS textures, native-size fallback, alpha coverage and power-of-two padding');
