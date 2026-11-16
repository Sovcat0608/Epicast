local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function clean(v)
 for k,x in pairs(v)do
  assert(k~='addedEffects'and k~='binding'and k~='nativeSmoke'and k~='authorDraft'and k~='authorSession'and k~='floatingScroll','Developer field in player settings: '..k)
  if type(x)=='table'then clean(x)end
 end
end
local defaults=E.Copy(E.AddedEffectDefaults.mageArcane)
local old=E.Normalize(nil);old.version=5
old.hideBlizzard=true;old.hideCooldownManager=true;old.classOnly=false
old.authorSession={malicious=true};old.content.spells={left={addedEffects={{fileID=166046}}}}
local c=old.content.classes.MAGE.slots.arcane
c.addedEffects={{fileID=166046}};c.nativeSmoke=false;c.size=143;c.x=-411;c.y=87;c.flip=true
old.content.classes.MAGE.active.fire=true;old.content.classes.MAGE.configured=true
old.content.resources.left.enabled=true;old.content.resources.left.resource='rage';old.content.resources.left.showMeter=false
EpicastDB=old;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
clean(EpicastDB);assert(EpicastDB.version==6 and EpicastDB.content.spells==nil)
c=EpicastDB.content.classes.MAGE.slots.arcane
assert(c.size==143 and c.x==-411 and c.y==87 and c.flip and EpicastDB.content.classes.MAGE.active.fire)
assert(EpicastDB.hideBlizzard and EpicastDB.hideCooldownManager and not EpicastDB.classOnly)
assert(EpicastDB.content.resources.left.enabled and EpicastDB.content.resources.left.resource=='rage'and not EpicastDB.content.resources.left.showMeter)
assert(equal(E.GetAddedEffects(c),defaults)and #E.GetEntry('spells','arcane').addedEffectSlots==12)
local saved=E.Copy(EpicastDB)
-- Simulate a new addon load with a newly shipped bake, without resetting saves.
E.CrestBakes['MAGE:arcane']=E.Copy(defaults);E.CrestBakes['MAGE:arcane'][1].trailOpacity=7
assert(loadfile('CrestEffects.lua'))('Epicast',E)
E.Apply();assert(E.GetAddedEffects(E.GetEntry('spells','arcane').config)[1].trailOpacity==7)
assert(E.GetEntry('spells','arcane').addedEffectSlots[1].resourceOpacity==.07)
assert(equal(EpicastDB,saved),'A new bake changed player preferences')
E.CrestBakes['MAGE:arcane']=nil;assert(loadfile('CrestEffects.lua'))('Epicast',E);E.Apply()
E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest('spells','arcane')
c=E.GetEffectLibraryTarget();local rows=E.EditAddedEffects(c)
assert(not E.HasChanges(),'Copying the bake without edits must stay clean')
rows[1].trailOpacity=9;rows[4].binding.duration=2.5;E.PreviewLibraryChange()
assert(E.HasChanges()and E.GetAddedEffects(E.GetEntry('spells','arcane').config)[1].trailOpacity==9)
assert(equal(E.AddedEffectDefaults.mageArcane,defaults)and equal(EpicastDB,saved))
E.panel.detailTabs.behavior:Click();assert(E.panel.exportBake:IsVisible());E.panel.exportBake:Click()
assert(E.bakeExport:IsVisible()and E.bakeExport.edit:HasFocus())
EpicastBakeTestExport=E.bakeExport.edit:GetText();assert(EpicastBakeTestExport==E.ExportCrestBake(c))
assert(not EpicastBakeTestExport:find('hideBlizzard',1,true)and not EpicastBakeTestExport:find('authorSession',1,true))
E.SaveEffectStudio();clean(EpicastDB);assert(equal(EpicastDB,saved)and not E.HasChanges())
E.EditAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity=10;E.CancelEffectStudio()
assert(E.GetAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity==9 and not E.HasChanges())
E.SetDeveloperMode(false);assert(not E.bakeExport:IsShown()and E.GetAddedEffects(E.GetEntry('spells','arcane').config)[1].trailOpacity==defaults[1].trailOpacity)
E.SetDeveloperMode(true);assert(E.GetAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity==9)
E.panel:Hide();assert(E.GetAddedEffects(E.GetEntry('spells','arcane').config)[1].trailOpacity==defaults[1].trailOpacity)
E.OpenOptions();assert(E.GetAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity==9)
-- Pending-art crests share an art ID, but never share developer layers.
E.SetAuthoringClass('WARRIOR');E.SelectCrest('spells','arms')
assert(E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166009})==1)
E.SelectCrest('spells','fury');assert(#E.GetAddedEffects(E.GetEffectLibraryTarget())==0)
E.SetAuthoringClass('PRIEST');E.SelectCrest('spells','holy');assert(#E.GetAddedEffects(E.GetEffectLibraryTarget())==0)
E.SelectCrest('resources','left');assert(not E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166009,behavior='bound'}))
assert(not E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166046}),'Placeholder accepted')
E.EditAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity=12
E.SelectCrest('resources','right');assert(E.GetAddedEffects(E.GetEffectLibraryTarget())[1].trailOpacity==35)
E.SaveEffectStudio();clean(EpicastDB)
-- Reload cannot recover developer RAM from a preference-only save.
E.panel:Hide();E.authorSession=nil;E.authorDraft=nil;E.devMode=false;Mock.event('ADDON_LOADED','Epicast')
E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest('spells','arcane')
assert(equal(E.GetAddedEffects(E.GetEffectLibraryTarget()),defaults));clean(EpicastDB)
for _,tabs in ipairs({E.panel.mainTabs,E.panel.tabs,E.panel.detailTabs})do
 local selected=0;for _,t in pairs(tabs)do assert(t.template=='PanelTopTabButtonTemplate'and t.height==32);if t.tabSelected then selected=selected+1;assert(not t.enabled)end end
 assert(selected==1)
end
Mock.combat=true;E.RefreshOptions();for _,t in pairs(E.panel.mainTabs)do assert(not t.enabled)end;Mock.combat=false
print('PASS: preference-only upgrade/new bake, exact Arcane defaults, session-only developer Save/Cancel/Close/reload, exports, cross-class/resource isolation and native tabs')
