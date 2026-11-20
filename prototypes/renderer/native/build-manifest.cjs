const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),hash=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const binaries=['js','wasm','data'].map(ext=>'vendor/build_packed/project.'+ext);
const inputs=['native/EpicastCamera.h','native/EpicastStudio.h','native/patch-source.cjs','vendor/project.data','vendor/project.js'];
function verify(){
 const m=JSON.parse(fs.readFileSync(path.join(root,'vendor/build_packed/manifest.json')));
 for(const [file,digest]of Object.entries(m.hashes))if(hash(file)!==digest)throw Error('Renderer build is stale or changed: '+file+'; run Build-Renderer.ps1');
 return m;
}
if(require.main===module){if(process.argv.includes('--verify'))verify();else{const m={source:'Marlamin/WebWowViewerCpp',revision:'4017528a7edf10a06714643716cf4a5fc56854cf',compiler:'Emscripten 6.0.11',built:new Date().toISOString(),hashes:Object.fromEntries([...binaries,...inputs].map(f=>[f,hash(f)]))};fs.writeFileSync(path.join(root,'vendor/build_packed/manifest.json'),JSON.stringify(m,null,2)+'\n');}}
module.exports={verify};
