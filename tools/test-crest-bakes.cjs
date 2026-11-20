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
const smallest=structuredClone(exported);smallest.effects[0].trailSize=5;validateBake(smallest);
reject(c=>c.effects[0].trailSize=4);
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
const recovered=JSON.parse(fs.readFileSync('tests/fixtures/restoration-recovered.json','utf8'));
validateBake(recovered);assert.equal(recovered.effects.length,9);
assert.ok(manifest['DRUID:restoration'],'Missing shipped Restoration bake');
assert.equal(fs.readFileSync('CrestBakes.lua','utf8'),render(manifest),'Generated bake source is stale');
console.log('PASS: real in-game JSON export, exact field preservation, data-only compiler/round-trip, 29 valid crest identities and invalid/placeholder/private-data rejection');
const studio=JSON.parse(fs.readFileSync('artifacts/crest-bakes/studio-export.json','utf8'));
validateBake(studio);assert.equal(studio.version,2);assert.equal(studio.crest,'MAGE:fire');
assert.deepEqual(studio.studio.spells.map(s=>s.spell),['1449','Regrowth']);assert.equal(studio.studio.artwork.artwork.opacity,43);
assert.equal(studio.effects.length,1);assert.equal(studio.effects[0].layerID,'fx2');assert.deepEqual(studio.studio.order,['artwork','fx2']);
assert.equal(studio.effects[0].followArtwork,'artwork');
const rejectStudio=mutate=>{const c=structuredClone(studio);mutate(c);assert.throws(()=>validateBake(c));};
rejectStudio(c=>c.studio.order=['fx2','fx2']);rejectStudio(c=>c.studio.order=['fx2']);rejectStudio(c=>c.effects[0].layerID='artwork');
rejectStudio(c=>c.effects[0].followArtwork='missing');rejectStudio(c=>c.studio.spells.push(c.studio.spells[0]));
rejectStudio(c=>c.studio.artwork.artwork.opacity=101);rejectStudio(c=>c.studio.artwork.artwork.x=99);
rejectStudio(c=>c.crest='WARRIOR:arms');rejectStudio(c=>c.crest='RESOURCE:left');rejectStudio(c=>c.studio.player={});
rejectStudio(c=>c.studio.spells[0].spell='');rejectStudio(c=>c.studio.spells[0].id='unknown');rejectStudio(c=>c.effects[0].enabled=1);
const v2source=render({'MAGE:fire':{effects:studio.effects,studio:studio.studio}});parser.parse(v2source,{luaVersion:'5.1'});
const live=lauxlib.luaL_newstate();lualib.luaL_openlibs(live);
try{
 const program=`local E={};assert(load(${JSON.stringify(v2source)}))('Epicast',E);local b=E.CrestBakes['MAGE:fire'];assert(b.effects[1].layerID=='fx2' and b.studio.order[2]=='fx2' and b.studio.artwork.artwork.opacity==43 and b.studio.spells[2].spell=='Regrowth')`;
 if(lauxlib.luaL_dostring(live,to_luastring(program))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(live,-1)));
}finally{lua.lua_close(live);}
console.log('PASS: v2 studio export/compiler round-trip, unbound waiting spells, stable order/artwork opacity and invalid identities/targets/private fields rejected');
const multi=JSON.parse(fs.readFileSync('artifacts/crest-bakes/multi-export.json','utf8'));
validateBake(multi);
assert.equal(multi.version,3);
assert.equal(multi.crest,'DRUID:balance');
assert.equal(multi.effects[0].fileID,166602);
assert.deepEqual(multi.effects[0].bindings.map(({spell,kind})=>[spell,kind]),[['18562','buff'],['5185','buff']]);
assert.equal(multi.effects[1].binding.spell,'18562');
assert.equal(multi.effects[1].binding.kind,'channel');
const rejectMulti=mutate=>{const c=structuredClone(multi);mutate(c);assert.throws(()=>validateBake(c));};
rejectMulti(c=>c.version=2);
rejectMulti(c=>c.effects[0].bindings[1].spell=c.effects[0].bindings[0].spell);
rejectMulti(c=>c.effects[0].binding=c.effects[0].bindings[0]);
rejectMulti(c=>c.effects[0].bindings.pop());
rejectMulti(c=>c.effects[0].bindings[1].outro=true);
rejectMulti(c=>c.studio.spells.splice(1,1));
rejectMulti(c=>c.crest='RESOURCE:left');
const multiSource=render({'DRUID:balance':{effects:multi.effects,studio:multi.studio}});
parser.parse(multiSource,{luaVersion:'5.1'});
const multiVM=lauxlib.luaL_newstate();lualib.luaL_openlibs(multiVM);
try{
 const program=`local E={};assert(load(${JSON.stringify(multiSource)}))('Epicast',E);local b=E.CrestBakes['DRUID:balance'];assert(b.effects[1].bindings[2].spell=='5185' and b.effects[2].binding.spell=='18562' and b.studio.order[2]=='fx1')`;
 if(lauxlib.luaL_dostring(multiVM,to_luastring(program))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(multiVM,-1)));
}finally{lua.lua_close(multiVM);}
console.log('PASS: v3 multi-binding export and compiler round-trip, waiting-room validation, Stand-only checks and singular legacy rows');

const segmented=JSON.parse(fs.readFileSync('artifacts/crest-bakes/segment-export.json','utf8'));
assert.equal(segmented.version,5);
validateBake(segmented);
assert.equal(segmented.crest,'DRUID:restoration');
assert.deepEqual(segmented.studio.artworkBindings.leftFeathers.find(b=>b.spell==='16870').mappings,
 [{state:'channel',kind:'buff'}]);
assert.deepEqual(segmented.studio.artworkBindings.treant,
 [{spell:'5185',mappings:[{state:'channel',kind:'channel'},{state:'impact',kind:'success'},{state:'channel',kind:'cast'}]}]);
assert.deepEqual(segmented.studio.artworkBindings.rightSlats,[{spell:'16870',mappings:[]}]);
const legacySegmented=structuredClone(segmented);
legacySegmented.version=4;
legacySegmented.studio.artworkBindings={treant:[{spell:'5185',kind:'channel'},{spell:'5185',kind:'impact'}]};
validateBake(legacySegmented);
const waiting=structuredClone(segmented);
waiting.studio.artworkBindings.treant[0].mappings=[];
validateBake(waiting);
const rejectSegment=mutate=>{const c=structuredClone(segmented);mutate(c);assert.throws(()=>validateBake(c));};
rejectSegment(c=>c.studio.order.reverse());
rejectSegment(c=>c.studio.artworkBindings.leftSlats[0].mappings[0].state='impact');
rejectSegment(c=>c.studio.artworkBindings.backboard=[{spell:'5185',mappings:[]}]);
rejectSegment(c=>c.studio.artworkBindings.treant[0].mappings.push({state:'impact',kind:'success'}));
rejectSegment(c=>c.studio.artworkBindings.treant[0].mappings[0].kind='unlisted');
rejectSegment(c=>c.studio.artworkBindings.treant.push({spell:'5185',mappings:[]}));
rejectSegment(c=>c.studio.artworkBindings.leftFeathers[0].spell='unlisted');
rejectSegment(c=>c.studio.artwork.contactShadow={enabled:true,opacity:100});
const segmentSource=render({'DRUID:restoration':{effects:segmented.effects,studio:segmented.studio}});
parser.parse(segmentSource,{luaVersion:'5.1'});
const segmentVM=lauxlib.luaL_newstate();lualib.luaL_openlibs(segmentVM);
try{
 const program=`local E={};assert(load(${JSON.stringify(segmentSource)}))('Epicast',E);local b=E.CrestBakes['DRUID:restoration'];assert(b.studio.artworkBindings.treant[1].mappings[1].kind=='channel' and b.studio.artworkBindings.treant[1].mappings[2].state=='impact' and b.studio.artwork.leftCheek.enabled==false)`;
 if(lauxlib.luaL_dostring(segmentVM,to_luastring(program))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(segmentVM,-1)));
}finally{lua.lua_close(segmentVM);}
console.log('PASS: v5 mapped artwork, legacy v4 bindings, mixed z-order, and invalid mapping rejection');
