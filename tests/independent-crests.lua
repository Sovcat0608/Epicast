local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function near(a,b)assert(math.abs(a-b)<1e-6,tostring(a)..' ~= '..tostring(b))end
local Old={AddedEffectDefaults=E.AddedEffectDefaults,MageBookBounds=E.MageBookBounds}
assert(loadfile('tests/fixtures/schema4/MageCrestData.lua'))('Epicast',Old)
assert(loadfile('tests/fixtures/schema4/ClassSpecs.lua'))('Epicast',Old)
assert(loadfile('tests/fixtures/schema4/Model.lua'))('Epicast',Old)
local legacy=Old.Normalize(nil);local s=legacy.sets.central
s.x=70;s.y=35;s.gap=210;s.size=125;s.swapped=true;s.leftX=12;s.rightX=-18;s.leftY=10;s.rightY=-7
local oldDruid=legacy.content.classes.DRUID
oldDruid.slots.balance.size=80;oldDruid.slots.restoration.size=130
oldDruid.slots.restoration.addedEffects={{fileID=166009,behavior='bound',trailX=41,trailOpacity=23,binding={kind='buff',spell='16870'}}}
legacy.sets.edge.enabled=true;legacy.sets.edge.size=150;legacy.sets.edge.x=33;legacy.sets.edge.leftX=8
local before=E.Copy(legacy);local db=E.Normalize(legacy);local d=db.content.classes.DRUID
assert(equal(legacy,before)and db.version==6 and db.sets==nil and E.SwapRoles==nil and E.DisplaySides==nil)
near(d.slots.balance.size,100);near(d.slots.restoration.size,162.5)
local wb=E.GetCapGeometry(d.slots.balance,false);local wr=E.GetCapGeometry(d.slots.restoration,false)
near(d.slots.restoration.x,70-wb/2-105+12);near(d.slots.balance.x,70+wr/2+105-18)
near(d.slots.restoration.y,45);near(d.slots.balance.y,28)
local freshDruid=E.Normalize(nil).content.classes.DRUID.slots
assert(d.slots.restoration.addedEffects==nil and equal(E.GetAddedEffects(d.slots.restoration),E.GetAddedEffects(freshDruid.restoration)))
local res=db.content.resources.left;assert(res.enabled and res.flip and res.size==150)
near(res.x,-960+E.GetLegacyCapGeometry(res,res.flip)/2+33+8)
assert(equal(db,E.Normalize(db)),'Independent normalization repeats legacy placement')
-- Frozen positions survive active-list changes, including three/zero selections.
local positions=E.Copy(d.slots);d.active.feral=true;d.active.balance=false
assert(equal(E.Normalize(db).content.classes.DRUID.slots,positions))
local disabled=E.Copy(legacy);disabled.sets.central.enabled=false;disabled.sets.edge.enabled=false
local hidden=E.Normalize(disabled);assert(not hidden.content.classes.DRUID.active.balance and not hidden.content.classes.MAGE.active.arcane and not hidden.content.resources.left.enabled)
local edge=E.Copy(legacy);edge.sets.edge.role='spells';edge.sets.central.role='resources';edge.content.classes.DRUID.active.feral=true;edge.sets.edge.middleX=47;edge.sets.edge.middleY=19
local moved=E.Normalize(edge);near(moved.content.classes.DRUID.slots.feral.x,47);near(moved.content.classes.DRUID.slots.feral.y,19)
local older={version=2,content={spells={left={addedEffects={{fileID=166009,behavior='bound',binding={kind='proc',spell='400588'}}}},right={addedEffects={}}},druid={left={art='moonwarden',addedEffects={}},right={art='groveheart',addedEffects={}}}}}
local migrated=E.Normalize(older);local arc=migrated.content.classes.MAGE.slots.arcane
assert(#E.GetAddedEffects(arc)==12 and E.GetAddedEffects(arc)[4].binding.kind=='buff')
for _,spec in ipairs({"balance","restoration"})do
 assert(equal(E.GetAddedEffects(migrated.content.classes.DRUID.slots[spec]),E.GetAddedEffects(freshDruid[spec])))
end
local max=Old.Normalize(nil);max.sets.central.size=200;max.content.classes.MAGE.slots.arcane.size=200
assert(E.Normalize(max).content.classes.MAGE.slots.arcane.size==400)
local extreme=Old.Normalize(nil);extreme.sets.central.x=2000;extreme.sets.central.rightX=2000;extreme.sets.central.gap=1800
extreme.content.classes.MAGE.active.fire=true;extreme.content.classes.MAGE.active.frost=true
local ext=E.Normalize(extreme);assert(ext.content.classes.MAGE.slots.arcane.x>4000,'Valid old placement must not clamp to 4000')
print('PASS: schema-1/2/4 independent placement migration, mixed sizes/gaps/edge geometry, disabled flags, shipped bindings, source immutability and idempotence')

-- Old paired saves now use the shipped crest definition in the live renderer.
EpicastDB={version=2,content={spells={left={},right={}}}};Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
local p=E.panel;assert(p:IsShown()and p.save.enabled and E.editorSet=='spells'and E.editorSide=='arcane')
local function number(key,value)local input=p.inputs[key];input:SetFocus();input:SetText(tostring(value));input:emit('OnTextChanged',true);input:emit('OnEnterPressed')end
assert(p.tabs.spells:GetText()=='Spellcasting'and p.tabs.resources:GetText()=='Resources'and not p.sliders.gap and not p.swapArt and not p.swapRoles)
local arcane=E.GetEntry('spells','arcane');assert(arcane.frame:IsVisible()and #arcane.addedEffectSlots==12)
assert(not E.GetEntry('spells','fire').frame:IsShown())
local oldPoint={arcane.frame.point[4],arcane.frame.point[5],arcane.frame.width,arcane.frame.height}
p.crestRows[1].active:Click();p.crestRows[2].active:Click()
for i,n in ipairs({'fire','frost','arcane'})do assert(E.GetEntry('spells',n).frame:IsVisible())end
near(arcane.frame.point[4],oldPoint[1]);near(arcane.frame.point[5],oldPoint[2])
p.crestRows[1].choose:Click();assert(E.editorSide=='fire')
p.sliders.size:SetValue(175);number('x',-417);number('y',208)
local fire=E.GetEntry('spells','fire');assert(fire.config.size==175 and fire.config.x==-417 and fire.config.y==208)
near(fire.frame.point[4],-417);near(fire.frame.point[5],208+fire.frame.height/2)
near(arcane.frame.point[4],oldPoint[1]);near(arcane.frame.point[5],oldPoint[2]);near(arcane.frame.width,oldPoint[3]);near(arcane.frame.height,oldPoint[4])
assert(p.crestRows[1].summary:GetText():find('175%%'))
p.crestRows[2].active:Click();assert(not E.GetEntry('spells','frost').frame:IsShown());near(fire.frame.point[4],-417);near(arcane.frame.point[4],oldPoint[1])
p.crestRows[2].choose:Click();p.sliders.size:SetValue(133);assert(not E.GetEntry('spells','frost').frame:IsShown()and E.draft.content.classes.MAGE.slots.frost.size==133)
p.crestRows[2].active:Click();assert(E.GetEntry('spells','frost').config.size==133)
p.crestRows[1].choose:Click();Mock.cursorX=100;Mock.cursorY=100;fire.handle:emit('OnDragStart');Mock.cursorX=130;Mock.cursorY=87;fire.handle:emit('OnUpdate');fire.handle:emit('OnDragStop')
assert(E.draft.content.classes.MAGE.slots.fire.x==-387 and E.draft.content.classes.MAGE.slots.fire.y==195);near(arcane.frame.point[4],oldPoint[1])
p.save:Click();local committed=E.Copy(EpicastDB);assert(not E.HasChanges())
p.reset:Click();assert(E.draft.content.classes.MAGE.slots.fire.size==100 and E.draft.content.classes.MAGE.slots.arcane.size==100)
p.cancel:Click();assert(equal(committed,EpicastDB)and fire.config.size==175 and not p:IsShown())
E.OpenOptions();p.tabs.resources:Click();assert(E.editorSet=='resources'and #E.CrestChoices('resources')==2 and not p.crestRows[3]:IsShown())
p.crestRows[1].active:Click();local resource=E.GetEntry('resources','left');assert(resource.frame:IsVisible()and not E.GetEntry('resources','right').frame:IsShown())
p.sliders.size:SetValue(82);number('x',612);number('y',64)
assert(resource.config.size==82 and resource.config.x==612 and resource.config.y==64 and fire.config.size==175)
p.detailTabs.behavior:Click();p.resource:Click();Mock.menu[2].choose();assert(resource.config.resource=='mana');p.detailTabs.placement:Click()
p.crestRows[2].active:Click();p.crestRows[2].choose:Click();p.sliders.size:SetValue(140);assert(resource.config.size==82)
p.save:Click();assert(EpicastDB.content.resources.left.enabled and EpicastDB.content.resources.right.enabled)
print('PASS: real crest-name UI, independent show/hide/size/X/Y/drag/reset, inactive editing, stable neighbors, separate Resources and Save/Cancel')

E.devMode=true;E.SelectCrest('spells','arcane');assert(p.custom==nil and not E.HasCustomArtwork(arcane.config))
p.flip:Click();p.detailTabs.behavior:Click();p.motion:Click();p.motion:Click();p.detailTabs.placement:Click()
E.EffectLibrary.Open();Mock.advance(0);local studio=E.EffectLibrary.window
studio.layerControls.crest:Click();assert(#Mock.menu==5);Mock.menu[1].choose();assert(E.editorSide=='fire')
assert(E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166009,behavior='bound',binding={kind='success',spell='1449',duration=.3}})==1)
E.PreviewLibraryChange();Mock.advance(0);assert(E.TestBoundEffect('fire','mageFire',1))
assert(fire.addedEffectSlots[1].boundTest)
studio.layerControls.crest:Click();Mock.menu[3].choose();assert(E.editorSide=='arcane'and not fire.addedEffectSlots[1].boundTest)
for _,class in ipairs(E.ClassOrder)do
 studio.authorClass:Click();assert(#Mock.menu==9)
 for _,choice in ipairs(Mock.menu)do if choice.name==E.ClassSpecs[class].name then choice.choose();break end end
 assert(E.ActiveClass()==class and #E.CrestChoices('spells')==3)
 for _,spec in ipairs(E.ClassSpecs[class].slots)do E.SetCrestEnabled(E.draft,'spells',spec[1],true)end
 E.Apply();E.RefreshOptions();for _,spec in ipairs(E.ClassSpecs[class].slots)do assert(E.GetEntry('spells',spec[1]).frame:IsVisible())end
end
assert(not arcane.frame:IsShown(),'Foreign class frame remained visible')
E.SetAuthoringClass('MAGE');E.SelectCrest('spells','arcane');assert(arcane.frame:IsVisible())
local savedX=arcane.config.x;Mock.combat=true;number('x',555);E.SetAuthoringClass('DRUID');assert(E.ActiveClass()=='MAGE'and arcane.config.x==savedX);Mock.combat=false
E.SaveEffectStudio();E.SetAuthoringClass('DRUID');Mock.combat=true;p:Hide();assert(E.ActiveClass()=='MAGE'and not E.GetEntry('spells','balance','DRUID').frame:IsShown()and E.pending)
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0);assert(arcane.frame:IsVisible())
print('PASS: pending-art native editing, named studio selection/tests, all nine isolated class banks, pooled identity, combat guards and temporary preview restoration')

-- Live routes use the shipped Arcane instance, not a physical-side fixture.
local fx=arcane.addedEffectSlots
assert(fx[1].nativeSmoke.slots[1].scene:IsVisible()and fx[5].nativeSmoke.slots[1].scene:IsVisible())
Mock.event('UNIT_SPELLCAST_START','player','blast',30451);assert(fx[3].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','blast',30451);assert(fx[7].castVisible)
Mock.event('UNIT_SPELLCAST_STOP','player','blast',30451);assert(not fx[3].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','explosion',1449);assert(fx[8].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_START','player','missiles',5143);assert(fx[10].castVisible)
Mock.advance(.5);Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','pulse',7268);assert(fx[9].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_STOP','player','missiles',5143);assert(not fx[10].castVisible)
C_UnitAuras={GetPlayerAuraBySpellID=function()error('restricted')end,GetAuraDataBySpellName=function()error('restricted')end}
local icon={cooldownID=71,isActive=false}
C_CooldownViewer={GetCooldownViewerCooldownInfo=function()return{spellID=400588,linkedSpellIDs={400589},selfAura=false}end}
BuffIconCooldownViewer={IsShown=function()return true end,IsVisible=function()return true end,GetItemFrames=function()return{icon}end}
Mock.combat=true
for i=1,4 do icon.isActive=true;Mock.advance(.11);assert(fx[4].castVisible)
 icon.isActive=false;Mock.event('UNIT_AURA','player');Mock.advance(.34);assert(not fx[4].castVisible)
end
Mock.combat=false;E.devMode=true;E.OpenOptions();E.SelectCrest('spells','arcane');p.crestRows[3].active:Click();assert(not arcane.frame:IsShown())
icon.isActive=true;Mock.advance(.11);assert(not fx[4].castVisible)
p.crestRows[3].active:Click();Mock.advance(.11);assert(arcane.frame:IsVisible()and fx[4].castVisible)
local report={};local message=E.Message;E.Message=function(line)report[#report+1]=line end;E.PrintBoundStatus();E.Message=message
assert(table.concat(report,'\n'):find('spells/arcane',1,true))
p.save:Click();local normalized=E.Normalize(EpicastDB);assert(equal(normalized,E.Normalize(normalized)))
print('PASS: current independent runtime static/cast/success/channel/pulse routes, repeated Missile Barrage clears, disabled-crest isolation, report routing and persistence')
