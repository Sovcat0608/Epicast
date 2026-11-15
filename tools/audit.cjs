const fs=require('fs'),path=require('path'),crypto=require('crypto'),parser=require('luaparse');
process.chdir(path.resolve(__dirname,'..'));
const toc=fs.readFileSync('Epicast.toc','utf8');const runtime=toc.split(/\r?\n/).map(x=>x.trim()).filter(x=>x&&!x.startsWith('#'));
if(new Set(runtime).size!==runtime.length)throw Error('Duplicate load entry');
const rootFiles=fs.readdirSync('.').filter(x=>/\.(lua|xml)$/.test(x));
if(rootFiles.some(x=>!runtime.includes(x)))throw Error('Unloaded runtime file');
const forbidden=/EndCapper|endCapper|Coldsnap|Combustion|frostbound|emberbound|Soulbound|soulbound|skycutter|zephyr|frostmourne|Moonwell|Banshee|Timelost|timekeeper|Bartender4|EditModeManager/;
for(const f of runtime){
 const s=fs.readFileSync(f,'utf8');
 // Native model paths can legitimately contain names also used by retired art.
 // Exclude only the generated long-string data, never executable Lua code.
 const code=f==='EffectCatalog.lua'?s.replace(/^Viewer\.catalog=\[=\[[\s\S]*\]=\]\s*$/m,'Viewer.catalog=""'):s;
 if(forbidden.test(code))throw Error('Retired runtime reference in '+f);
 if(f.endsWith('.lua'))parser.parse(s,{luaVersion:'5.1'});
 if(/loadstring|RunScript|RunMacroText/.test(s))throw Error('Unexpected dynamic/game execution in '+f);
}
if(!toc.includes('## SavedVariables: EpicastDB')||/Dependencies:/.test(toc))throw Error('Namespace/dependency mismatch');
const expected=JSON.parse(fs.readFileSync('tools/media-manifest.json','utf8'));
const files=fs.readdirSync('Media').map(x=>'Media/'+x).sort();
if(JSON.stringify(files)!==JSON.stringify(Object.keys(expected).sort()))throw Error('Unexpected or missing media');
for(const f of files){const b=fs.readFileSync(f);if(crypto.createHash('sha256').update(b).digest('hex')!==expected[f].sha256)throw Error('Media changed: '+f);
 if(b[2]!==2||b[16]!==32||b.length!==18+b.readUInt16LE(12)*b.readUInt16LE(14)*4)throw Error('Invalid RGBA TGA '+f);
}
const catalogText=fs.readFileSync('EffectCatalog.lua','utf8'),catalog=[...catalogText.matchAll(/^(\d+);([^\r\n]+)$/gm)];
const catalogManifest=JSON.parse(fs.readFileSync('tools/effect-catalog-manifest.json','utf8'));
const availabilityBytes=fs.readFileSync('tools/forever-effects.json'),availability=JSON.parse(availabilityBytes),available=new Set(availability.allowed);
if(availability.product!=='wowf'||catalogManifest.foreverBuild!==availability.version||catalogManifest.foreverRoot!==availability.rootKey)throw Error('Missing Forever provenance');
if(crypto.createHash('sha256').update(availabilityBytes).digest('hex')!==catalogManifest.availabilitySHA256)throw Error('Forever inspection changed');
if(catalog.length!==catalogManifest.models||catalog.length!==available.size||catalog.some(m=>!available.has(Number(m[1])))||new Set(catalog.map(m=>m[1])).size!==catalog.length)throw Error('Incomplete, unavailable or duplicate catalog');
if(available.has(166046)||catalog.some(m=>/errorcube/i.test(m[2])))throw Error('Placeholder in catalog');
for(const ids of Object.values(availability.rejected))for(const id of ids)if(available.has(id))throw Error('Rejected effect in catalog');
if(crypto.createHash('sha256').update(catalogText).digest('hex')!==catalogManifest.catalogSHA256)throw Error('Catalog differs from generated manifest');
for(const[,id,file]of catalog)if(!Number.isInteger(Number(id))||Number(id)<1||Number(id)>0xffffffff||!file.endsWith('.m2'))throw Error('Invalid native model entry');
console.log(`PASS: ${runtime.length} runtime entries, independent namespace, ${catalog.length} catalog models, ${files.length} exact approved RGBA assets`);
