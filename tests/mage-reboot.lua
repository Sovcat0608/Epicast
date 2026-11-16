local E=...
local function near(a,b)assert(math.abs(a-b)<1e-8,tostring(a)..' ~= '..tostring(b))end
E.devMode=true;E.SetAuthoringClass('MAGE')
local bank=E.ClassBank(E.draft)
for _,key in ipairs({'fire','frost','arcane'})do
 local c=bank.slots[key];c.size=100;c.flip=false;c.effects=true;E.SetCrestEnabled(E.draft,'spells',key,true)
end
E.Apply();E.SelectCrest('spells','arcane')
assert(not E.panel.subject:GetText():find('pending',1,true))
local instances={}
for _,key in ipairs({'fire','frost','arcane'})do
 local entry=E.GetEntry('spells',key);instances[key]=entry
 local s=entry.mageReboot;local c=entry.config;local art=E.MageRebootArtworks[c.art]
 assert(s and s.host:IsVisible()and s.hover.playing and s.art==c.art)
 assert(s.texture.texture=='Interface\\AddOns\\Epicast\\Media\\'..art.name..'CASSize384.tga')
 assert(s.textureSize==384 and s.texture.uv[7]==384/512 and s.texture.uv[8]==384/512)
 assert(s.texture.SetSnapToPixelGridArgs[1]==false and s.texture.SetTexelSnappingBiasArgs[1]==0)
 assert(#s.hover.animations==2 and #s.host.groups==1 and not s.host.scripts.OnUpdate)
 near(s.host:GetWidth(),216);near(s.host:GetHeight(),216)
 for i,leg in ipairs(s.legs)do assert(leg.SetDurationArgs[1]==3 and leg.SetSmoothingArgs[1]=='IN_OUT');near(leg.SetOffsetArgs[2],(i==1 and 1 or -1)*216*.024)end
 near(s.host.point[5],30-216*.012)
 local w,h,cx,cy=E.GetCapGeometry(c,false)
 near(w,216*(art.bounds[3]-art.bounds[1])/768)
 near(h,216*(art.bounds[4]-art.bounds[2])/768+2*216*.012)
 local _,_,flippedX,flippedY=E.GetCapGeometry(c,true);near(flippedX,-cx);near(flippedY,cy)
end
local fire=instances.fire;local s=fire.mageReboot;local initial=s.elapsed
Mock.advance(1.25);E.Apply();near(s.elapsed,(initial+1.25)%6);near(s.hover.elapsed,s.elapsed)
fire.frame:Hide();local phase=s.elapsed;assert(not s.hover.playing);Mock.advance(2);fire.frame:Show();near(s.hover.elapsed,phase)
local frostTexture=instances.frost.mageReboot.texture.texture
bank.slots.fire.size=200;bank.slots.fire.flip=true;E.Apply()
assert(s.textureSize==768 and s.texture.uv[1]==768/1024 and s.texture.uv[5]==0)
assert(instances.frost.mageReboot.texture.texture==frostTexture and instances.frost.mageReboot.host.width==216)
near(s.elapsed,phase);near(s.host:GetWidth(),432)
bank.slots.fire.effects=false;E.Apply();assert(s.host:IsVisible()and not s.hover.playing);near(s.host.point[5],60)
local metrics=GetPhysicalScreenSize;GetPhysicalScreenSize=nil;bank.slots.fire.size=25;E.Apply();assert(s.textureSize==768);GetPhysicalScreenSize=metrics
E.SetCrestEnabled(E.draft,'spells','fire',false);E.Apply();assert(not fire.frame:IsVisible()and not s.host:IsShown()and not s.hover.playing)
E.SetCrestEnabled(E.draft,'spells','fire',true);bank.slots.fire.effects=true;E.Apply();assert(s.hover.playing)
local arc=instances.arcane;local effects=E.GetAddedEffects(bank.slots.arcane)
E.SetAuthoringClass('DRUID');assert(not arc.frame:IsVisible()and not arc.mageReboot.host:IsShown())
E.SetAuthoringClass('MAGE');assert(arc==E.GetEntry('spells','arcane')and arc.mageReboot.host:IsVisible()and effects==E.GetAddedEffects(E.ClassBank(E.draft).slots.arcane))
assert(E.GetEntry('resources','left').mageReboot==nil,'Resources must not reuse the new Mage art')
print('PASS: exact Mage slot mapping, real render/geometry, square aspect, texture sizing/UV/flip, six-second native phase/static/hide recovery, independent tuning and class isolation')
