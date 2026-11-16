const assert=require('assert/strict'),fs=require('fs'),parser=require('luaparse');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {validateBake,render,crests}=require('./Build-CrestBake.cjs');
const exported=JSON.parse(fs.readFileSync('artifacts/crest-bakes/test-export.json','utf8'));
validateBake(exported);assert.equal(exported.crest,'MAGE:arcane');assert.equal(exported.effects.length,12);
assert.equal(exported.effects[0].trailOpacity,9);assert.equal(exported.effects[3].binding.duration,2.5);
const approved=JSON.parse(fs.readFileSync('tests/fixtures/arcane-beta13.json','utf8'));
approved[0].trailOpacity=9;approved[3].binding.duration=2.5;assert.deepEqual(exported.effects,approved);
assert.equal(crests.size,29);
const reject=mutate=>{const c=structuredClone(exported);mutate(c);assert.throws(()=>validateBake(c));};
reject(c=>c.effects[0].fileID=166046);reject(c=>c.effects[0].fileID=4294967295);
reject(c=>c.effects[0].trailOpacity=101);reject(c=>c.effects[0].scale=Infinity);reject(c=>c.effects[0].animation=1.5);
reject(c=>c.crest='PRIEST:arcane');reject(c=>c.crest='RESOURCE:left');reject(c=>c.version=2);
reject(c=>c.effects[0].x=42);reject(c=>c.player='Account');reject(c=>delete c.effects[3].binding);
reject(c=>c.effects[3].binding.kind='unknown');reject(c=>c.effects[3].binding.duration=0);
reject(c=>c.effects[0].name='bad\ntext');reject(c=>c.effects[0].name='界'.repeat(34));
reject(c=>{c.effects[0].fileID=166602;c.effects[0].animation=158;});reject(c=>c.effects=Array(33).fill(c.effects[0]));
const bakes={'MAGE:arcane':exported.effects,'MAGE:fire':[]};
const source=render(bakes);parser.parse(source,{luaVersion:'5.1'});
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
try{
 const program=`local E={};assert(load(${JSON.stringify(source)}))('Epicast',E);assert(#E.CrestBakes['MAGE:arcane']==12 and E.CrestBakes['MAGE:arcane'][1].trailOpacity==9 and #E.CrestBakes['MAGE:fire']==0)`;
 if(lauxlib.luaL_dostring(L,to_luastring(program))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
}finally{lua.lua_close(L);}
const manifest=JSON.parse(fs.readFileSync('tools/crest-bakes.json','utf8'));
assert.equal(fs.readFileSync('CrestBakes.lua','utf8'),render(manifest),'Generated bake source is stale');
console.log('PASS: real in-game JSON export, exact field preservation, data-only compiler/round-trip, 29 valid crest identities and invalid/placeholder/private-data rejection');
