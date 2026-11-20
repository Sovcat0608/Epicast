// Execute the installed addon's actual camera/actor/viewport code in Lua,
// capture its native API calls, then compare independent projected points.
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('../../node_modules/fengari');
const {camera,project}=require('./projection.js');
const installed='D:/World of Warcraft/_forever_/Interface/AddOns/Epicast';
const rows=[...require('../../tools/crest-bakes.json')['DRUID:restoration'],...require('../../tests/fixtures/arcane-beta13.json')];
function native(row,size,flip){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const capture={};
 lua.lua_pushcfunction(L,L=>{const key=to_jsstring(lua.lua_tostring(L,1));capture[key]=[];for(let i=2;i<=lua.lua_gettop(L);i++)capture[key].push(lua.lua_tonumber(L,i));return 0;});lua.lua_setglobal(L,to_luastring('capture'));
 const load=(s,name)=>{if(lauxlib.luaL_loadbuffer(L,to_luastring(s),null,to_luastring(name))!==lua.LUA_OK||lua.lua_pcall(L,0,0,0)!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));};
 try{
  load(fs.readFileSync(path.resolve(__dirname,'../../tests/mock.lua'),'utf8'),'mock');
  load(`E={Schedule=function()end};local old=CreateFrame
   function CreateFrame(...) local f=old(...)
    if f.kind=='ModelScene' then
     for _,k in ipairs({'SetCameraPosition','SetCameraOrientationByAxisVectors','SetCameraNearClip','SetCameraFarClip','SetCameraFieldOfView'}) do f[k]=function(self,...)capture(k,...)end end
     local actor=f.CreateActor;f.CreateActor=function(self,...)local a=actor(self,...);a.SetPosition=function(self,...)capture('actorPosition',...)end;a.SetScale=function(self,...)capture('actorScale',...)end;return a end
     f.SetPoint=function(self,point,relative,relativePoint,x,y)capture('anchor',x,y)end
     f.SetSize=function(self,w,h)capture('viewport',w,h)end
    end;return f
   end`,'capture');
  for(const file of ['Effects.lua','NativeEffects.lua'])load(`(function(...)\n${fs.readFileSync(path.join(installed,file),'utf8')}\nend)('Epicast',E)`,file);
  const p={fileID:row.fileID,animation:row.animation,modelScale:row.scale,emitterX:row.originX,emitterY:row.originY,emitterZ:row.originZ,cameraAzimuth:row.azimuth,cameraElevation:row.elevation,opacity:1};
  const table=o=>'{'+Object.entries(o).map(([k,v])=>k+'='+v).join(',')+'}';
  load(`local p=${table(p)};p.centered=true
   local c=${table({trailSize:row.trailSize,trailX:row.trailX,trailY:row.trailY,trailAngle:row.trailAngle})};c.flip=${flip}
   local entry={art=CreateFrame('Frame'),frame=CreateFrame('Frame'),libraryProfile=p,nativeWanted=true,effectsEnabled=true,alpha=1,resourceOpacity=1}
   entry.art:SetSize(${225*size},${225*size});assert(E.UpdateNativeSmoke(entry,c))`,'fixture');
  return capture;
 }finally{lua.lua_close(L);}
}
const dot=(a,b)=>a.reduce((s,x,i)=>s+x*b[i],0);
let comparisons=0;
for(const row of rows)for(const flip of [false,true])for(const size of [.65,1.4]){
 const n=native(row,size,flip),width=935,height=660,artWidth=480,kind='restoration';
 const c=camera(row,{width,height,artWidth,kind,flip,follow:false});
 const ratio=artWidth/(162*size),eye=n.SetCameraPosition,basis=n.SetCameraOrientationByAxisVectors,forward=basis.slice(0,3),right=basis.slice(3,6),up=basis.slice(6,9);
 const anchor=[width/2+(n.anchor[0]-225*size/2)*ratio,height/2-(n.anchor[1]+225*size/2-30*size)*ratio];
 for(const p of [[row.originX,row.originY,row.originZ],[.2,-.1,.3],[-.3,.25,-.2]]){
  const actor=p.map((v,i)=>v*n.actorScale[0]+n.actorPosition[i]-eye[i]),depth=dot(actor,forward);
  const pixelsPerUnit=n.viewport[1]*ratio/(2*Math.tan(n.SetCameraFieldOfView[0]/2)*depth);
  const expected=[anchor[0]+dot(actor,right)*pixelsPerUnit,anchor[1]-dot(actor,up)*pixelsPerUnit];
  const actual=project(p,c,width,height);for(let i=0;i<2;i++)assert.ok(Math.abs(actual[i]-expected[i])<1e-6,`${row.fileID} projection ${i}: ${actual[i]} != ${expected[i]}`);comparisons++;
 }
}
// Off-centre projection must preserve registration when the panel/aspect,
// density-independent zoom and attachment position change.
for(const kind of ['restoration','arcane'])for(const zoom of [.6,1,1.5])for(const [width,height]of [[460,660],[1200,800]]){
 const row=rows[0],c=camera(row,{width,height,artWidth:480,kind,zoom,hover:12});
 const p=project([row.originX,row.originY,row.originZ],c,width,height);
 assert.ok(Math.abs(p[0]-c.anchor[0])<1e-7&&Math.abs(p[1]-c.anchor[1])<1e-7);comparisons++;
}
console.log(`PASS ${comparisons} projection cases against installed native Lua and viewport invariants (read-only).`);
