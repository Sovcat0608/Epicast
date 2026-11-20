// Read only shipped definitions in a fresh mocked Lua VM. Never load account data.
const fs=require('node:fs'),path=require('node:path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const root=path.resolve(__dirname,'../..');
function studioData(profile){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const crests=[],classes=[],presets={},geometry={};
 const read=f=>fs.readFileSync(path.join(root,f),'utf8');
 const run=s=>{if(lauxlib.luaL_dostring(L,to_luastring(s))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
 lua.lua_pushcfunction(L,L=>{const f=to_jsstring(lua.lua_tostring(L,1));if(!/^(?:[A-Za-z]+\.lua|tests\/mock\.lua)$/.test(f))throw Error('Only shipped Lua modules allowed');const s=to_luastring(read(f));if(lauxlib.luaL_loadbuffer(L,s,s.length,to_luastring('@'+f))!==lua.LUA_OK)return lua.lua_error(L);return 1;});lua.lua_setglobal(L,to_luastring('loadfile'));
 lua.lua_pushcfunction(L,L=>{const type=to_jsstring(lua.lua_tostring(L,1)),obj=JSON.parse(to_jsstring(lua.lua_tostring(L,2)));if(type==='crest')crests.push(obj);else if(type==='class')classes.push(obj);else Object.assign(type==='geometry'?geometry:presets,obj);return 0;});lua.lua_setglobal(L,to_luastring('emitStudio'));
 lua.lua_pushcfunction(L,L=>{
  const key=to_jsstring(lua.lua_tostring(L,1));
  const field=to_jsstring(lua.lua_tostring(L,2));
  const value=profile?.crests[key]?.[field];
  if(typeof value==='boolean')lua.lua_pushboolean(L,value);
  else if(typeof value==='number'&&Number.isFinite(value))lua.lua_pushnumber(L,value);
  else lua.lua_pushnil(L);
  return 1;
 });lua.lua_setglobal(L,to_luastring('readCrestPreference'));
 try{
  const modules=read('Epicast.toc').split(/\r?\n/).map(s=>s.trim()).filter(s=>s.endsWith('.lua'));
  run(`local M=assert(loadfile('tests/mock.lua'))();local E={}\n${modules.map(f=>`assert(loadfile('${f}'))('Epicast',E)`).join('\n')}
   EpicastDB=nil;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0);E.OpenOptions();E.SetDeveloperMode(true)
   local function emitCrest(c)
    local bake=E.GetCrestBakeKey(c)
    local shown=readCrestPreference(bake,'shown')
    if shown~=nil then
     local preferences={}
     for _,field in ipairs({'size','x','y','flip','effects'})do preferences[field]=readCrestPreference(bake,field)end
     c=E.NormalizeSide(preferences,'left','spells',c.art);E.CrestOwners[c]=bake
    end
    local w,h,x,y=E.GetCapGeometry(c,c.flip)
    local mage=E.MageRebootArtworks[c.art]
    local width=(mage and mage.width or 162)*c.size/100
    local height=(mage and mage.height or 216)*c.size/100
    local desaturation=E.DruidArtworks[c.art] and E.DruidArtworkDesaturation or 0
    local placement=''
    if shown~=nil then
     placement=',"game":{"size":'..c.size..',"x":'..c.x..',"y":'..c.y..',"flip":'..tostring(c.flip)..',"effects":'..tostring(c.effects)..',"shown":'..tostring(shown)..'}'
    end
    emitStudio('geometry','{"'..bake..'":{"bounds":['..table.concat({w,h,x,y,width,height,c.size/100},',')..'],"desaturation":'..desaturation..placement..'}}')
    E.EditStudioState(c);emitStudio('crest',E.ExportCrestBake(c))
   end
   for _,class in ipairs(E.ClassOrder) do
    emitStudio('class','{"id":"'..class..'","name":"'..E.ClassSpecs[class].name..'"}')
    for _,spec in ipairs(E.ClassSpecs[class].slots)do
     emitCrest(E.draft.content.classes[class].slots[spec[1]])
    end
   end
   for _,key in ipairs({'left','right'})do emitCrest(E.draft.content.resources[key])end
   for id,p in pairs(E.EffectLibrary.presets)do
    local o=p.origin or {0,0,0}
    emitStudio('preset','{"'..id..'":{"name":"'..p.name..'","scale":'..p.scale..',"origin":['..o[1]..','..o[2]..','..o[3]..'],"animation":'..(p.animation or 0)..',"angle":'..(p.angle or 0)..',"elevation":'..(p.elevation or 0)..',"desaturation":'..(p.desaturation or 0)..',"aliases":"'..(p.aliases or '')..'"}}')
   end`);
 }finally{lua.lua_close(L);}
 const title=s=>s.replace(/([a-z])([A-Z])/g,'$1 $2').replace(/^./,c=>c.toUpperCase());
 for(const c of crests){const [cl,spec]=c.crest.split(':');c.title=cl==='RESOURCE'?'Resource '+(spec==='left'?1:2):title(spec);c.class=cl;c.art=null;c.width=480;c.height=cl==='DRUID'?640:480;c.nativeWidth=cl==='MAGE'?216:162;
  c.geometry=geometry[c.crest].bounds;
  c.artworkDesaturation=geometry[c.crest].desaturation;
  c.game=geometry[c.crest].game;
  if(['DRUID','MAGE'].includes(cl))c.art='/art/'+(cl==='DRUID'?'Druid':'MageReboot')+title(spec)+'CASSize480.tga';
 }
 const catalog=read('EffectCatalog.lua').match(/Viewer\.catalog=\[=\[([\s\S]*?)\]=\]/)[1].trim().split(/\r?\n/).map(line=>{const [id,p]=line.split(';'),preset=presets[id];return{id:+id,path:p,name:preset?.name||title(path.basename(p,'.m2').replace(/[_-]/g,' ')),preset};}).sort((a,b)=>Number(!!b.preset)-Number(!!a.preset)||a.name.localeCompare(b.name)||a.id-b.id);
 return{crests,classes,catalog,gameSync:profile&&{savedAt:profile.savedAt,pixelsPerUnit:profile.pixelsPerUnit}};
}
module.exports={studioData};
if(require.main===module){const d=studioData();console.log(d.classes.length+' classes, '+d.crests.length+' crests, '+d.catalog.length+' effects');}
