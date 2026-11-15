const fs=require('fs'),path=require('path'),parser=require('luaparse');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
process.chdir(path.resolve(__dirname,'..'));
const files=fs.readFileSync('Epicast.toc','utf8').split(/\r?\n/).filter(x=>x.endsWith('.lua'));
for(const f of files)parser.parse(fs.readFileSync(f,'utf8'),{luaVersion:'5.1'});
function run(selected,tail){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 lua.lua_pushcfunction(L,L=>{const f=to_jsstring(lua.lua_tostring(L,1)),s=to_luastring(fs.readFileSync(f,'utf8'));if(lauxlib.luaL_loadbuffer(L,s,s.length,to_luastring('@'+f))!==lua.LUA_OK)return lua.lua_error(L);return 1});lua.lua_setglobal(L,to_luastring('loadfile'));
 const script=`local M=assert(loadfile('tests/mock.lua'))()\nlocal E={}\n`+selected.map(f=>`assert(loadfile('${f}'))('Epicast',E)`).join('\n')+tail;
 try{if(lauxlib.luaL_dostring(L,to_luastring(script))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));}finally{lua.lua_close(L);}
}
run(files,`\nassert(loadfile('tests/integration.lua'))(E)\nassert(loadfile('tests/buff-retrigger.lua'))(E)\nassert(loadfile('tests/cooldown-buff.lua'))(E)`);
run(files,`\nassert(loadfile('tests/options-tabs.lua'))(E)`);
run(files,`\nassert(loadfile('tests/druid-sisters.lua'))(E)`);
run(files,`\nassert(loadfile('tests/effect-library.lua'))(E)`);
run(files,`\nassert(loadfile('tests/druid-clearcasting.lua'))(E)`);
for(const mode of ['missing-module','missing-reader','reader-error','binding-error']){
 run(files.filter(f=>mode!=='missing-module'||f!=='CooldownBuffs.lua'),`\nassert(loadfile('tests/trigger-isolation.lua'))(E,'${mode}')`);
}
console.log(`PASS: ${files.length} modules parsed as Lua 5.1 and loaded in TOC order`);
require('./test-druid-assets.cjs');
require('./test-casc-reader.cjs');
