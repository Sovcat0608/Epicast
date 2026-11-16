// Reproducible read-only Forever research. Outputs metadata, never native bytes.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {LocalCASC}=require('./casc-local.cjs');
const c=new LocalCASC(process.argv[2]||'D:/World of Warcraft');
try{
 const raw=c.read(166602);let b;
 for(let p=0;p<raw.length;){const tag=raw.toString('ascii',p,p+4),n=raw.readUInt32LE(p+4);if(tag==='MD21')b=raw.subarray(p+8,p+8+n);p+=8+n;}
 if(!b||b.toString('ascii',0,4)!=='MD20'||b.readUInt32LE(4)!==272)throw Error('Expected inspected MD20/v272');
 const u=o=>b.readUInt32LE(o),f=o=>b.readFloatLE(o);
 const array=(count,offset,size,read)=>{if(count>10000||offset+count*size>b.length)throw Error('Invalid array');return Array.from({length:count},(_,i)=>read(offset+i*size));};
 const values=o=>array(u(o+12),u(o+16),8,p=>array(u(p),u(p+4),4,f));
 const report={fileID:166602,build:c.build.Version,root:c.config.root,sha256:crypto.createHash('sha256').update(raw).digest('hex'),
  sequences:array(u(28),u(32),64,p=>({id:b.readUInt16LE(p),variation:b.readUInt16LE(p+2),durationMs:u(p+4),flags:u(p+12)})),
  globalPeriodsMs:array(u(20),u(24),4,u),
  boneTracks:array(u(44),u(48),88,p=>({translationGlobal:b.readInt16LE(p+18),rotationGlobal:b.readInt16LE(p+38),scaleGlobal:b.readInt16LE(p+58)})),
  particles:array(u(296),u(300),492,p=>({bone:b.readUInt16LE(p+20),rate:values(p+176),lifespan:values(p+152)}))};
 fs.writeFileSync(path.join(__dirname,'../docs/166602-playback.json'),JSON.stringify(report,null,2)+'\n');
 console.log('Inspected '+report.fileID+' on '+report.build+': '+report.sequences.length+' sequence, '+report.globalPeriodsMs.length+' global loops, '+report.particles.length+' emitters.');
}finally{c.close();}
