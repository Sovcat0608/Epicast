const fs=require('fs'),path=require('path');
const map=JSON.parse(fs.readFileSync(path.join(__dirname,'../vendor/build_packed/project.wasm.map'))),alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
let generated=0,source=0,line=0,column=0;const mappings=[];
for(const segment of map.mappings.split(/[;,]/)){let values=[],value=0,shift=0;for(const c of segment){const v=alphabet.indexOf(c);value+=(v&31)*2**shift;if(v&32)shift+=5;else{values.push(value&1?-(value>>1):value>>1);value=shift=0;}}generated+=values[0]||0;if(values.length>=4){source+=values[1];line+=values[2];column+=values[3];mappings.push({offset:generated,file:map.sources[source],line:line+1,column});}}
for(const address of process.argv.slice(2)){const target=parseInt(address,16);console.log(address,mappings.findLast(m=>m.offset<=target));}
