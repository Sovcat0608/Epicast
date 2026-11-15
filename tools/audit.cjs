const fs=require('fs'),path=require('path'),crypto=require('crypto'),parser=require('luaparse');
process.chdir(path.resolve(__dirname,'..'));
const toc=fs.readFileSync('Epicast.toc','utf8');const runtime=toc.split(/\r?\n/).map(x=>x.trim()).filter(x=>x&&!x.startsWith('#'));
if(new Set(runtime).size!==runtime.length)throw Error('Duplicate load entry');
const rootFiles=fs.readdirSync('.').filter(x=>/\.(lua|xml)$/.test(x));
if(rootFiles.some(x=>!runtime.includes(x)))throw Error('Unloaded runtime file');
const forbidden=/EndCapper|endCapper|Coldsnap|Combustion|frostbound|emberbound|Soulbound|soulbound|skycutter|zephyr|frostmourne|Moonwell|Banshee|Timelost|timekeeper|Bartender4|EditModeManager/;
for(const f of runtime){
 const s=fs.readFileSync(f,'utf8');if(forbidden.test(s))throw Error('Retired runtime reference in '+f);
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
const catalog=fs.readFileSync('EffectCatalog.lua','utf8').match(/^\d+;/gm)||[];if(catalog.length!==11)throw Error('Catalog scope changed');
console.log(`PASS: ${runtime.length} runtime entries, independent namespace, no retired art/effects/migrations, eleven models, ${files.length} exact approved RGBA assets`);
