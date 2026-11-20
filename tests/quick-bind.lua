local E=...
-- Exercise adding the first binding to an empty test crest, independent of today's art bake.
E.CrestBakes["DRUID:balance"]={effects={}}
Mock.class="DRUID"
Mock.event("ADDON_LOADED","Epicast");Mock.advance(0)
E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest("spells","balance");E.EffectLibrary.Open()
local p=E.EffectLibrary.window;local s=p.layerControls
p.tabs.config:Click()
local c=E.GetEffectLibraryTarget()
local rows=E.GetAddedEffects(c);assert(#rows==0)
E.EditStudioState(c)
local swift=E.AddStudioSpell(c,"18562")
local touch=E.AddStudioSpell(c,"5185")
local regrowth=E.AddStudioSpell(c,"8936")
for i,id in ipairs({166602,166009,1519919})do
 assert(E.AddLibraryEffect(c,{fileID=id,name="Layer "..i})==i)
end
E.SetCrestEnabled(E.draft,"spells","balance",true)
E.PreviewLibraryChange();p.RefreshTarget();Mock.advance(0)
rows=E.GetAddedEffects(c)
local function findRow(items,key,id)
 for _,row in ipairs(items)do if row:IsShown()and row[key]==id then return row end end
 error("Missing visible row "..id)
end
local function layer(id)return findRow(s.rows,"layerID",id)end
local function spell(id)return findRow(s.spells.rows,"spellID",id)end
local function openMapping(id)
 if s.spells.mappingID~=id then findRow(s.spells.gears,"spellID",id):Click()end
 assert(s.spells.mapping:IsVisible())
end
local function mapping(layerID)return findRow(s.spells.mappingRows,"layerID",layerID)end
local function setTrigger(id,layerID,kind)
 openMapping(id)
 s.spells.triggers[kind]:Click();mapping(layerID).native:Click()
end
local function noSpellSelection()
 assert(not s.spells.selected)
 for _,row in ipairs(s.spells.rows)do if row:IsShown()then assert(not row.selected)end end
end
local function stageSpell(id)
 spell(id):Click()
 assert(spell(id).selected and not spell(id).relationship)
end

assert(s.filter=="artwork"and layer("artwork") and not s.rows[2]:IsShown())
s.filters.static:Click();layer("fx1"):Click()
assert(not s.quick and s.selectedID=="fx1"and not s.spells.saveBinding:IsShown())
spell(swift):Click();assert(s.spells.selected==swift and not s.selectedID and not s.quick)
layer("fx1"):Click();noSpellSelection()
assert(s.selectedID=="fx1"and not s.quick)
s.filters.artwork:Click();s.spells.enterBinding:Click()
assert(s.quick and not s.quick.anchor and s.filter=="static")
layer("fx1"):Click()
assert(s.quick.direction=="layer"and s.selectedID=="fx1")
stageSpell(swift);stageSpell(touch)
spell(touch):Click();assert(not spell(touch).selected and s.spells.saveBinding.enabled)
stageSpell(touch)
assert(rows[1].behavior=="static"and not rows[1].bindings)
s.spells.saveBinding:Click()
assert(not s.quick and not s.spells.saveBinding.enabled and #rows==3)
assert(rows[1].fileID==166602 and #E.GetEffectBindings(rows[1])==2)
assert(rows[1].bindings[1].spell=="18562"and rows[1].bindings[2].spell=="5185")
assert(layer("fx1").selected and not layer("fx1").relationship)
noSpellSelection()
assert(spell(swift).relationship=="blue"and spell(touch).relationship=="blue"and not spell(regrowth).relationship)

s.spells.enterBinding:Click();stageSpell(regrowth)
assert(not spell(swift).relationship and not spell(touch).relationship)
s.spells.cancelBinding:Click();noSpellSelection()
assert(not s.quick and not E.EffectHasSpell(rows[1],"8936"))
s.spells.enterBinding:Click();stageSpell(swift);spell(swift):Click()
assert(not spell(swift).selected and spell(swift).relationship=="blue"and not s.spells.saveBinding.enabled)
layer("fx1"):Click();assert(s.quick and not s.quick.anchor and not s.selectedID and not spell(touch).relationship)
s.spells.cancelBinding:Click()

-- Selecting a linked spell makes its effects visible, without choosing any layer.
s.filters.static:Click();spell(swift):Click()
assert(s.filter=="bound"and not s.quick and not s.selectedID)
assert(spell(swift).selected and not spell(swift).relationship)
assert(not layer("fx1").selected and layer("fx1").relationship=="green")
s.spells.enterBinding:Click();assert(s.quick.direction=="spell")
layer("fx1"):Click();assert(layer("fx1").selected and not layer("fx1").relationship)
layer("fx1"):Click();assert(not layer("fx1").selected and layer("fx1").relationship=="green")
s.filters.static:Click();layer("fx2"):Click();layer("fx3"):Click()
assert(layer("fx2").selected and layer("fx3").selected)
layer("fx3"):Click();assert(not layer("fx3").selected and E.StudioSpellUsage(c,"18562")==1)
s.spells.saveBinding:Click()
assert(not s.quick and s.spells.selected==swift and not s.selectedID and rows[3].behavior=="static")
assert(layer("fx1").relationship=="green"and layer("fx2").relationship=="green")
assert(not layer("fx1").selected and not layer("fx2").selected and not spell(touch).relationship)
assert(not s.spells.mapping:IsShown())
openMapping(swift)
assert(mapping("fx1").detail:GetText()=="Cast succeeds"and mapping("fx2").detail:GetText()=="Cast succeeds")
findRow(s.spells.gears,"spellID",swift):Click();assert(not s.spells.mapping:IsShown())
setTrigger(swift,"fx2","channel")
assert(mapping("fx1").detail:GetText()=="Cast succeeds"and mapping("fx2").detail:GetText()=="While channeling")
assert(rows[1].bindings[1].kind=="success"and rows[2].binding.kind=="channel")
s.spells.enterBinding:Click();layer("fx2"):Click();s.spells.saveBinding:Click()
assert(not s.spells.mapping:IsShown()and s.spells.gears[1]:IsShown())
assert(rows[2].binding.kind=="channel","Rebinding a link must preserve its trigger")
s.spells.enterBinding:Click();layer("fx1"):Click()
assert(layer("fx1").selected and not layer("fx2").relationship)
s.spells.cancelBinding:Click()
assert(layer("fx1").relationship=="green"and layer("fx2").relationship=="green")
spell(swift):Click()
assert(not s.quick and not s.spells.selected and not layer("fx1").relationship)

-- Both spells trigger one live 166602 ModelScene, including successive casts at
-- the same timestamp. Selecting a trigger also exposes its own playback controls.
layer("fx1"):Click();s.tabs.playback:Click()
s.playbackBinding:Click();assert(#Mock.menu==2);Mock.menu[2].choose()
s.test:Click()
local preview=p.crestPreview.addedEffectSlots[1]
assert(preview.boundTest and preview.boundDriver.spell=="5185")
s.stop:Click()
local live=E.GetEntry("spells","balance").addedEffectSlots[1]
local channelEffect=E.GetEntry("spells","balance").addedEffectSlots[2]
Mock.event("UNIT_SPELLCAST_CHANNEL_START","player","channel",18562)
assert(channelEffect.castVisible and not live.castVisible)
Mock.event("UNIT_SPELLCAST_SUCCEEDED","player","channel",18562)
assert(channelEffect.castVisible and live.castVisible)
Mock.event("UNIT_SPELLCAST_CHANNEL_STOP","player","channel",18562)
assert(not channelEffect.castVisible and live.castVisible)
Mock.advance(1.1)
local slot=live.nativeSmoke.slots[1]
local count=#Mock.frames
local starts=live.boundStarts or 0
local load=slot.actor.SetModelByFileID;local reloads=0
slot.actor.SetModelByFileID=function(...)reloads=reloads+1;return load(...)end
for i,id in ipairs({18562,5185,18562,5185})do
 Mock.event("UNIT_SPELLCAST_SUCCEEDED","player","cast"..i,id)
 assert(live.boundDriver.spell==tostring(id)and live.castVisible and live.boundStarts==starts+i)
 assert(live.nativeSmoke.slots[1]==slot and slot.scene:IsShown())
 if i%2==0 then Mock.advance(1.1);assert(not slot.scene:IsShown())end
end
assert(reloads==0 and #Mock.frames==count)

-- For overlapping sustained bindings, ending one cannot stop the shared effect.
setTrigger(swift,"fx1","buff")
setTrigger(touch,"fx1","buff")
assert(rows[2].binding.kind=="channel")
local auras={}
C_UnitAuras.GetPlayerAuraBySpellID=function(id)return auras[id]end
local function aura(id,on)
 auras[id]=on and {spellId=id} or nil
 Mock.event("UNIT_AURA","player")
end
aura(18562,true);assert(live.castVisible and live.boundDriver.spell=="18562")
local heldStarts=live.boundStarts
aura(5185,true);aura(18562,false)
assert(live.castVisible and live.boundDriver.spell=="5185"and live.boundStarts==heldStarts)
aura(5185,false);assert(not live.castVisible)

EpicastMultiBindingTestExport=E.ExportCrestBake(c)
assert(EpicastMultiBindingTestExport:find('"version":3',1,true))
local shipped=E.Copy(E.GetAddedEffects(c));local studio=shipped.studio;shipped.studio=nil
layer("fx1"):Click();s.tabs.placement:Click();s.unbind:Click();assert(#Mock.menu==2);Mock.menu[1].choose()
assert(rows[1].binding.spell=="5185"and not rows[1].bindings and #E.GetStudioState(c).spells==3)
s.unbind:Click();assert(rows[1].behavior=="static"and not E.GetEffectBindings(rows[1])[1])
E.SetDeveloperMode(false);E.panel:Hide()
E.CrestBakes["DRUID:balance"]={effects=shipped,studio=studio}
assert(loadfile("CrestEffects.lua"))("Epicast",E)
E.SetCrestEnabled(EpicastDB,"spells","balance",true);E.Apply();Mock.advance(0)
local installed=E.GetEntry("spells","balance")
assert(not E.devMode and #E.GetEffectBindings(E.GetAddedEffects(installed.config)[1])==2)
local installedEffect=installed.addedEffectSlots[1]
aura(5185,true);assert(installedEffect.castVisible and installedEffect.boundDriver.spell=="5185")
aura(5185,false);assert(not installedEffect.castVisible)
print("PASS: idle highlights, opt-in bind mode, spell mapping sidebar, distinct per-effect signals, rebind safety and independent scene playback")
