local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function close(a,b)assert(math.abs(a-b)<1e-7,tostring(a)..' ~= '..tostring(b))end
local legacy=E.Normalize(nil);legacy.version=3;legacy.content.classes.MAGE=nil
local l,r=legacy.content.spells.left,legacy.content.spells.right
l.addedEffects[1].trailX=71;l.addedEffects[1].trailY=-44;l.addedEffects[1].effectLayer='back'
l.addedEffects[1].trailSize=180;l.addedEffects[1].trailAngle=-30;l.addedEffects[1].trailOpacity=12
l.addedEffects[5].binding.kind='proc';l.addedEffects[5].binding.spell='400588'
r.addedEffects[1].fileID=l.addedEffects[1].fileID -- duplicates must survive
local original=E.Copy(legacy);local db=E.Normalize(legacy);local bank=db.content.classes.MAGE
assert(equal(legacy,original),'Migration mutated its input')
assert(db.version==4 and #bank.slots.arcane.addedEffects==13)
assert(bank.active.arcane and not bank.active.fire and not bank.active.frost)
assert(#bank.slots.fire.addedEffects==0 and #bank.slots.frost.addedEffects==0)
local n=0
for _,source in ipairs({l,r})do for _,row in ipairs(source.addedEffects)do
 n=n+1;local migrated=bank.slots.arcane.addedEffects[n]
 assert(migrated.fileID==row.fileID and migrated.behavior==row.behavior)
 for _,k in ipairs({'scale','originX','originY','originZ','azimuth','elevation','animation'})do assert(migrated[k]==row[k],k)end
 assert(migrated.trailSize==100 and migrated.trailAngle==90 and migrated.trailX==0 and migrated.trailY==0 and migrated.trailOpacity==70 and migrated.effectLayer=='front')
end end
assert(bank.slots.arcane.addedEffects[5].binding.kind=='buff'and bank.slots.arcane.addedEffects[5].binding.spell=='400589')
assert(equal(db.content.resources,original.content.resources)and equal(db.content.classes.DRUID,original.content.classes.DRUID))
assert(equal(db,E.Normalize(db)))
bank.slots.arcane.addedEffects[1].trailX=23;bank.slots.arcane.floatingScroll={size=117,x=12,y=-101}
local again=E.Normalize(db)
assert(#again.content.classes.MAGE.slots.arcane.addedEffects==13 and again.content.classes.MAGE.slots.arcane.addedEffects[1].trailX==23)
assert(equal(again.content.classes.MAGE.slots.arcane.floatingScroll,bank.slots.arcane.floatingScroll))
local full=E.Copy(legacy)
for _,side in ipairs({'left','right'})do full.content.spells[side].addedEffects={};for i=1,16 do
 full.content.spells[side].addedEffects[i]={fileID=166009,name=side..i,behavior=i%2==0 and'bound'or'static',binding=i%2==0 and{kind='success',spell=tostring(i)}or nil}
end end
local all=E.Normalize(full).content.classes.MAGE.slots.arcane.addedEffects
assert(#all==32 and all[16].name=='left16'and all[17].name=='right1'and all[32].name=='right16')
for _,side in ipairs({'left','right'})do full.content.spells[side].addedEffects={}end
assert(#E.Normalize(full).content.classes.MAGE.slots.arcane.addedEffects==0)
print('PASS: real Mage schema-3 migration, all static/bound rows and duplicates, 32-layer capacity, centered reset, model fit/bindings, explicit empties and idempotence')

EpicastDB=E.Normalize(legacy);Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
local p=E.panel;local entries=E.instances.central;local entry=entries.left;local state=entry.mageCrest
assert(p:IsShown()and p.pages.central.crests[1].label:GetText()=='Fire')
assert(entry.config.art=='mageArcane'and not entries.middle.frame:IsShown()and not entries.right.frame:IsShown())
assert(#entry.addedEffectSlots==13 and state.book.host:IsVisible()and state.scroll.host:IsVisible())
assert(not entry.mageBooks and not entry.mageSigils)
assert(state.book.host.parent==entry.frame and state.scroll.host.parent==entry.frame)
assert(state.scroll.host.level>state.book.host.level and not state.scroll.host.scripts.OnUpdate)
for _,layer in ipairs({state.book,state.scroll})do
 assert(layer.hover.playing and layer.legs[1].SetDurationArgs[1]==3 and layer.legs[2].SetDurationArgs[1]==3)
 assert(layer.legs[1].SetSmoothingArgs[1]=='IN_OUT'and layer.texture.SetSnapToPixelGridArgs[1]==false and layer.texture.SetTexelSnappingBiasArgs[1]==0)
end
close(state.book.legs[1].SetOffsetArgs[2],state.scroll.legs[1].SetOffsetArgs[2])
close((state.book.hover.elapsed-state.scroll.hover.elapsed)%6,1)
assert(state.book.textureSize==288 and state.scroll.textureSize==192)
close(state.book.texture.uv[7],288/512);close(state.book.texture.uv[8],384/512)
Mock.advance(1.7);E.Apply();close(state.book.hover.elapsed,1.7);close(state.scroll.hover.elapsed,.7)
entry.frame:Hide();local phase=state.elapsed;Mock.advance(2);entry.frame:Show()
close(state.book.hover.elapsed,phase);close((state.book.hover.elapsed-state.scroll.hover.elapsed)%6,1)
p.save:Click();p:Hide();assert(entry.frame:IsVisible()and state.scroll.host:IsVisible())

-- The actual merged default stack must retain both sides' cast/channel paths.
local fx=entry.addedEffectSlots
assert(fx[1].nativeSmoke.slots[1].scene:IsVisible()and fx[7].nativeSmoke.slots[1].scene:IsVisible())
Mock.event('UNIT_SPELLCAST_START','player','blast',30451);assert(fx[4].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','blast',30451);assert(fx[10].castVisible)
Mock.event('UNIT_SPELLCAST_STOP','player','blast',30451);assert(not fx[4].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','explosion',1449);assert(fx[11].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_START','player','missiles',5143);assert(fx[13].castVisible)
Mock.advance(.5);Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','pulse',7268);assert(fx[12].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_STOP','player','missiles',5143);assert(not fx[13].castVisible)
C_UnitAuras={GetPlayerAuraBySpellID=function()error('restricted')end,GetAuraDataBySpellName=function()error('restricted')end}
local icon={cooldownID=71,isActive=false}
C_CooldownViewer={GetCooldownViewerCooldownInfo=function()return{spellID=400588,linkedSpellIDs={400589},selfAura=false}end}
BuffIconCooldownViewer={IsShown=function()return true end,IsVisible=function()return true end,GetItemFrames=function()return{icon}end}
Mock.combat=true
for i=1,4 do
 icon.isActive=true;Mock.advance(.11);assert(fx[5].castVisible and fx[6].castVisible)
 Mock.event('UNIT_SPELLCAST_START','player','clear-'..i,30451)
 icon.isActive=false;Mock.event('UNIT_AURA','player');Mock.advance(.11);assert(not fx[5].castVisible and not fx[6].castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','clear-'..i,30451)
end
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0)
print('PASS: merged Arcane static/cast/success/channel/pulse effects and repeated native Missile Barrage clears in combat')

E.devMode=true;E.OpenOptions();assert(p.custom.scroll:IsVisible()and not p.custom.seal:IsShown())
local c=E.GetSide(E.draft,'central','left');local scroll=p.custom.scrollSliders
local beforePoint=E.Copy(entry.art.point);local beforeWidth=entry.frame:GetWidth()
scroll.size:SetValue(140);scroll.x:SetValue(25);scroll.y:SetValue(-110)
assert(c.floatingScroll.size==140 and c.floatingScroll.x==25 and c.floatingScroll.y==-110 and E.HasChanges())
close(entry.frame:GetWidth(),beforeWidth);close(entry.art.point[4],beforePoint[4]);close(entry.art.point[5],beforePoint[5])
close(state.scroll.host.point[4],25);close(state.scroll.host.width,162*.82*1.4)
close((state.book.hover.elapsed-state.scroll.hover.elapsed)%6,1)
p.flip:Click();close(state.scroll.host.point[4],-25)
p.sliders.size:SetValue(200);close(state.scroll.host.point[4],-50)
assert(state.book.textureSize==480 and state.scroll.textureSize==576)
p.motion:Click();assert(not state.book.hover.playing and not state.scroll.hover.playing and state.scroll.host:IsVisible())
close(state.scroll.host.point[5],-220);close(state.book.host.point[5],0)
p.motion:Click();assert(state.book.hover.playing);close((state.book.hover.elapsed-state.scroll.hover.elapsed)%6,1)
p.save:Click();local saved=E.Copy(EpicastDB)
scroll.x:SetValue(90);E.CancelEffectStudio();assert(equal(EpicastDB,saved)and E.GetSide(E.draft,'central','left').floatingScroll.x==25)
p.custom.scrollReset:Click();local reset=E.GetFloatingScrollConfig(E.GetSide(E.draft,'central','left'))
assert(reset.size==100 and reset.x==0 and reset.y==-95 and E.HasChanges())
E.CancelEffectStudio()
local invalid=E.NormalizeSide({floatingScroll={size=999,x=-999,y=0/0}},'left','spells','mageFire')
assert(invalid.floatingScroll.size==200 and invalid.floatingScroll.x==-200 and invalid.floatingScroll.y==-95)
E.devMode=false;E.SetFloatingScroll(invalid,'x',100);assert(invalid.floatingScroll.x==-200);E.devMode=true
Mock.combat=true;scroll.x:SetValue(100);p.custom.scrollReset:Click();assert(E.GetSide(E.draft,'central','left').floatingScroll.x==25);Mock.combat=false
print('PASS: native six-second independent hover, one-second phase lag across updates/hide/resize, UV/flip/static rendering and transactional bounded scroll controls')

p.pages.central.crests[1]:Click();p.pages.central.crests[2]:Click()
assert(entries.left.config.art=='mageFire'and entries.middle.config.art=='mageFrost'and entries.right.config.art=='mageArcane')
assert(entries.middle.mageCrest.scroll.host:IsVisible()and entries.right.mageCrest.scroll.host:IsVisible())
assert(E.GetSide(E.draft,'central','left').floatingScroll.x==0 and E.GetSide(E.draft,'central','right').floatingScroll.x==25)
E.EffectLibrary.Open();Mock.advance(0);local w=E.EffectLibrary.window
w.layerControls.middle:Click();assert(E.editorSide=='middle'and E.GetEffectLibraryTarget().art=='mageFrost')
w.custom:Click();assert(p.custom.scroll:IsVisible());scroll.x:SetValue(33)
assert(E.draft.content.classes.MAGE.slots.frost.floatingScroll.x==33 and E.draft.content.classes.MAGE.slots.fire.floatingScroll.x==0)
for _,class in ipairs(E.ClassOrder)do
 w.authorClass:Click();assert(#Mock.menu==9)
 local choose;for _,option in ipairs(Mock.menu)do if option.name==E.ClassSpecs[class].name then choose=option.choose end end
 assert(choose);choose();assert(E.ActiveClass()==class and E.ClassBank(E.draft))
 E.EffectLibrary.Open();Mock.advance(0)
 if class~='MAGE'then assert(not p.custom.scroll:IsVisible())end
end
w.authorClass:Click();local delayed=Mock.menu[3].choose;Mock.combat=true;delayed();assert(E.ActiveClass()=='WARRIOR');Mock.combat=false
E.SetAuthoringClass('MAGE');E.SaveEffectStudio();p:Hide()
assert(E.ActiveClass()=='MAGE'and E.previewClass==nil and #E.DisplaySides(EpicastDB,'central')==3)
Mock.class='DRUID';E.Apply();assert(entries.left.config.art=='druidBalance'and not entries.left.mageCrest.scroll.host:IsShown())
Mock.class='MAGE';E.Apply();assert(entries.left.config.art=='mageFire'and entries.left.mageCrest.scroll.host:IsVisible())
local screen=GetPhysicalScreenSize;GetPhysicalScreenSize=nil;E.Apply();assert(entries.left.mageCrest.book.textureSize==660 and entries.left.mageCrest.scroll.textureSize==768);GetPhysicalScreenSize=screen
print('PASS: all three Mage crests, isolated scroll tuning, real studio middle selector and all-nine-class menus, temporary preview/combat guards and artwork reuse')
