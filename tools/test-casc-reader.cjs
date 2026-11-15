const assert=require('node:assert/strict'),zlib=require('node:zlib'),crypto=require('node:crypto');
const {LocalCASC,decode}=require('./casc-local.cjs');
const md5=b=>crypto.createHash('md5').update(b).digest('hex');
const original=Buffer.from('Forever asset checksum fixture'),chunk=Buffer.concat([Buffer.from('Z'),zlib.deflateSync(original)]);
const header=Buffer.alloc(36);header.write('BLTE');header.writeUInt32BE(36,4);header[8]=15;header.writeUIntBE(1,9,3);header.writeUInt32BE(chunk.length,12);header.writeUInt32BE(original.length,16);Buffer.from(md5(chunk),'hex').copy(header,20);
const encoded=Buffer.concat([header,chunk]),key=md5(header);
assert.deepEqual(decode(encoded,key),original);
const corrupted=Buffer.from(encoded);corrupted[corrupted.length-1]^=1;
assert.throws(()=>decode(corrupted,key),/checksum/);
assert.throws(()=>decode(encoded,'0'.repeat(32)),/key mismatch/);
// A valid resident texture variant must work when the first root variant is absent.
const fixture={keys:()=>['high','low'],readContent:key=>{if(key==='high')throw Error('Not locally available');return original;}};
assert.deepEqual(LocalCASC.prototype.read.call(fixture,1),original);
assert.throws(()=>LocalCASC.prototype.read.call({keys:()=>[]},1),/Absent from Forever/);
console.log('PASS: CASC content integrity rejection and resident texture-variant fallback');
