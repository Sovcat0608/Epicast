const fs=require('fs'),path=require('path'),parser=require('luaparse');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
process.chdir(path.resolve(__dirname,'..'));
const files=fs.readFileSync('Epicast.toc','utf8').split(/\r?\n/).filter(x=>x.endsWith('.lua'));
for(const f of files)parser.parse(fs.readFileSync(f,'utf8'),{luaVersion:'5.1'});
const historicalFiles=JSON.parse(fs.readFileSync('tests/fixtures/schema4/load-order.json','utf8'));
function run(selected,tail,legacyPair=true,historical=true){
 if(historical)selected=historicalFiles.filter(f=>f!=='CooldownBuffs.lua'||selected.includes(f));
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 lua.lua_pushcfunction(L,L=>{const f=to_jsstring(lua.lua_tostring(L,1)),s=to_luastring(fs.readFileSync(f,'utf8'));if(lauxlib.luaL_loadbuffer(L,s,s.length,to_luastring('@'+f))!==lua.LUA_OK)return lua.lua_error(L);return 1});lua.lua_setglobal(L,to_luastring('loadfile'));
 const script=`local M=assert(loadfile('tests/mock.lua'))()\nlocal E={}\n`+selected.map(f=>`assert(loadfile('${historical&&fs.existsSync('tests/fixtures/schema4/'+f)?'tests/fixtures/schema4/'+f:f}'))('Epicast',E)`).join('\n')+(legacyPair?`\nassert(loadfile('tests/legacy-pair.lua'))(E)`:'')+tail;
 try{if(lauxlib.luaL_dostring(L,to_luastring(script))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));}finally{lua.lua_close(L);}
}
console.log('Schema-4 compatibility fixtures with current shared effect/animation/reader modules:');
run(files,`\nassert(loadfile('tests/integration.lua'))(E)\nassert(loadfile('tests/buff-retrigger.lua'))(E)\nassert(loadfile('tests/cooldown-buff.lua'))(E)`);
run(files,`\nassert(loadfile('tests/options-tabs.lua'))(E)`);
run(files,`\nassert(loadfile('tests/druid-sisters.lua'))(E)`);
run(files,`\nassert(loadfile('tests/effect-library.lua'))(E)`);
run(files,`\nassert(loadfile('tests/druid-clearcasting.lua'))(E)`);
run(files,`\nassert(loadfile('tests/class-crests.lua'))(E)`,false);
run(files,`\nassert(loadfile('tests/mage-crests.lua'))(E)`,false);
run(files,`\nassert(loadfile('tests/playback-segments.lua'))(E)`);
run(files,`\nassert(loadfile('tests/barrage-migration.lua'))(E)`);
for(const mode of ['missing-module','missing-reader','reader-error','binding-error']){
 run(files.filter(f=>mode!=='missing-module'||f!=='CooldownBuffs.lua'),`\nassert(loadfile('tests/trigger-isolation.lua'))(E,'${mode}')`);
}
console.log('Current independent-crest runtime, without fixture overrides:');
run(files,`\nassert(loadfile('tests/independent-crests.lua'))(E)\nassert(loadfile('tests/mage-reset.lua'))(E)\nassert(loadfile('tests/mage-reboot.lua'))(E)`,false,false);
console.log(`PASS: ${files.length} current modules parsed as Lua 5.1 and loaded in TOC order`);
run(files,`\nassert(loadfile('tests/arcane-preset.lua'))(E)`,false,false);
run(files,`\nassert(loadfile('tests/cooldown-visibility.lua'))(E)`,false,false);
require('./test-arcane-preset.cjs');
require('./test-druid-assets.cjs');
require('./test-mage-reset.cjs');
require('./test-mage-reboot.cjs');
require('./test-casc-reader.cjs');
