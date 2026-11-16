const fs=require('fs'),assert=require('assert'),crypto=require('crypto');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const png=fs.readFileSync('concepts/mage-reboot/Mage-reboot-trio-v3-initial.png');
assert.equal(hash(png),'5dd9d15c1d72c67efb83dfa664e235e450b36c8b8c1c3bbc7cc017b2a2d3f5ac','Must bake uncorrected option 1, not a later edit');
assert.equal(png.readUInt32BE(16),2172);assert.equal(png.readUInt32BE(20),724);assert.equal(png[25],6);
for(const spec of ['Fire','Frost','Arcane'])for(const size of [192,288,384,480,576,768]){
 const t=fs.readFileSync(`Media/MageReboot${spec}CASSize${size}.tga`),back=2**Math.ceil(Math.log2(size));
 assert.equal(t[2],2);assert.equal(t[16],32);assert.equal(t[17],40);
 assert.equal(t.readUInt16LE(12),back);assert.equal(t.readUInt16LE(14),back);assert.equal(t.length,18+back*back*4);
 let opaque=0,clear=0;
 for(let y=0;y<back;y++)for(let x=0;x<back;x++){
  const a=t[18+(y*back+x)*4+3];
  if(x>=size||y>=size||x==0||y==0||x==size-1||y==size-1)assert.equal(a,0,'Source margins and backing stay transparent');
  if(x<size&&y<size){if(a>=240)opaque++;if(!a)clear++;}
 }
 assert(opaque>size*size*.4&&clear>size*size*.12,'Full crest including floating accents retains solid pixels and transparency');
}
console.log('PASS: approved uncorrected Mage option 1 source, eighteen square CAS textures, alpha coverage, transparent borders/backing and native-size fallback');
