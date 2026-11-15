// Read-only CASC reader for build-time inspection. No network or game writes.
// Format references: wowdev.wiki/CASC and Kruithne/wow.export src/js/casc.
const fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto');
const md5=b=>crypto.createHash('md5').update(b).digest('hex');
function decode(b,key){
 if(b.toString('ascii',0,4)!=='BLTE')throw Error('Missing BLTE');
 const h=b.readUInt32BE(4),parts=[];
 if(md5(h?b.subarray(0,h):b)!==key)throw Error('BLTE key mismatch');
 const n=h?b.readUIntBE(9,3):1;let offset=h||8;
 if(h&&(b[8]!==15||h!==12+n*24))throw Error('Invalid BLTE header');
 for(let i=0;i<n;i++){
  const size=h?b.readUInt32BE(12+i*24):b.length-8,chunk=b.subarray(offset,offset+size);offset+=size;
  if(h&&md5(chunk)!==b.toString('hex',20+i*24,36+i*24))throw Error('BLTE chunk checksum');
  const raw=chunk[0]===78?chunk.subarray(1):chunk[0]===90?zlib.inflateSync(chunk.subarray(1)):null;
  if(!raw)throw Error('Unsupported/encrypted BLTE block');
  if(h&&raw.length!==b.readUInt32BE(16+i*24))throw Error('BLTE chunk size');
  parts.push(raw);
 }
 return Buffer.concat(parts);
}
class LocalCASC{
 constructor(game){
  this.game=path.resolve(game);this.index=new Map();this.handles=new Map();
  const lines=fs.readFileSync(path.join(this.game,'.build.info'),'utf8').trim().split(/\r?\n/),headers=lines.shift().split('|').map(x=>x.split('!')[0]);
  this.build=lines.map(line=>Object.fromEntries(line.split('|').map((v,i)=>[headers[i],v]))).find(x=>x.Product==='wowf'&&x.Active==='1');
  if(!this.build)throw Error('Active Forever build not found');
  const key=this.build['Build Key'];this.config=Object.fromEntries(fs.readFileSync(path.join(this.game,'Data/config',key.slice(0,2),key.slice(2,4),key),'utf8').split(/\r?\n/).filter(x=>/^\S+ = /.test(x)).map(x=>x.split(' = ')));
  const dir=path.join(this.game,'Data/data'),latest=new Map();
  for(const f of fs.readdirSync(dir).filter(f=>/^[a-f\d]{10}\.idx$/i.test(f)).sort())latest.set(f.slice(0,2),f);
  for(const f of latest.values()){
   const b=fs.readFileSync(path.join(dir,f)),p=(8+b.readUInt32LE(0)+15)&~15,end=p+8+b.readUInt32LE(p);
   for(let j=p+8;j<end;j+=18){const location=b.readUIntBE(j+9,5);this.index.set(b.toString('hex',j,j+9),{index:Math.floor(location/0x40000000),offset:location%0x40000000,size:b.readUInt32LE(j+14)});}
  }
  this.encoding=this.readEncoded(this.config.encoding.split(' ')[1]);const b=this.encoding;
  if(b.toString('ascii',0,2)!=='EN'||b[3]!==16||b[4]!==16)throw Error('Unsupported encoding');
  this.pageSize=b.readUInt16BE(5)*1024;this.pages=b.readUInt32BE(9);this.pageIndex=22+b.readUInt32BE(18);this.pageStart=this.pageIndex+this.pages*32;
  this.root=this.readContent(this.config.root);this.groups=[];
  const r=this.root;if(r.toString('ascii',0,4)!=='TSFM')throw Error('Unsupported root');
  const version=r.readUInt32LE(4)===24?r.readUInt32LE(8):0;let p=version?24:12;
  if(version>2)throw Error('Unsupported root version '+version);
  while(p<r.length){
   const n=r.readUInt32LE(p);p+=4;let flags,locale;
   if(version===2){locale=r.readUInt32LE(p);flags=r.readUInt32LE(p+4)|r.readUInt32LE(p+8)|(r[p+12]<<17);p+=13;}
   else{flags=r.readUInt32LE(p);locale=r.readUInt32LE(p+4);p+=8;}
   const ids=new Uint32Array(n);let id=0;
   for(let i=0;i<n;i++){id+=r.readInt32LE(p);p+=4;ids[i]=id++;}
   if((locale&2)&&!(flags&128))this.groups.push({ids,keyOffset:p});
   p+=16*n;if(!(flags&0x10000000))p+=8*n;
  }
  if(p!==r.length)throw Error('Root length mismatch');
 }
 readEncoded(key){
  const entry=this.index.get(key.slice(0,18));if(!entry)throw Error('Not locally available');
  let fd=this.handles.get(entry.index);
  if(fd===undefined){fd=fs.openSync(path.join(this.game,'Data/data','data.'+String(entry.index).padStart(3,'0')),'r');this.handles.set(entry.index,fd);}
  const b=Buffer.alloc(entry.size-30);if(fs.readSync(fd,b,0,b.length,entry.offset+30)!==b.length)throw Error('Truncated archive');
  return decode(b,key);
 }
 encodingKey(key){
  const b=this.encoding,target=Buffer.from(key,'hex');let lo=0,hi=this.pages-1,best=-1;
  while(lo<=hi){const m=(lo+hi)>>>1,cmp=Buffer.compare(b.subarray(this.pageIndex+m*32,this.pageIndex+m*32+16),target);if(cmp<=0){best=m;lo=m+1;}else hi=m-1;}
  if(best<0)throw Error('Missing encoding key');
  const end=this.pageStart+(best+1)*this.pageSize;
  for(let p=end-this.pageSize;p<end&&b[p];){const count=b[p],ckey=b.toString('hex',p+6,p+22);if(ckey===key)return b.toString('hex',p+22,p+38);p+=22+16*count;}
  throw Error('Missing encoding key');
 }
 readContent(key){const b=this.readEncoded(this.encodingKey(key));if(md5(b)!==key)throw Error('Content checksum mismatch');return b;}
 keys(id){
  const keys=[];
  for(const g of this.groups){let lo=0,hi=g.ids.length-1;while(lo<=hi){const m=(lo+hi)>>>1,v=g.ids[m];if(v===id){keys.push(this.root.toString('hex',g.keyOffset+m*16,g.keyOffset+(m+1)*16));break;}if(v<id)lo=m+1;else hi=m-1;}}
  return keys;
 }
 key(id){return this.keys(id)[0];}
 read(id){
  const keys=this.keys(id);if(!keys.length)throw Error('Absent from Forever root');let failure;
  // Texture-quality variants can share an ID; only one variant need be resident.
  for(const key of keys)try{return this.readContent(key);}catch(e){failure=e;}
  throw failure;
 }
 close(){for(const fd of this.handles.values())fs.closeSync(fd);this.handles.clear();}
}
module.exports={LocalCASC,decode};
if(require.main===module){const c=new LocalCASC(process.argv[2]);console.log({build:c.build.Version,index:c.index.size,groups:c.groups.length,rootMD5:md5(c.root),errorCube:c.key(166046)});c.close();}
