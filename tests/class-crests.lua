local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function layer(id,spell)return {fileID=id,animation=0,behavior='bound',trailX=41,trailY=-27,trailOpacity=23,scale=.37,binding={kind='cast',spell=spell,intro=false,outro=false}}end
-- Actual schema-2 shape; deliberately reverse its artwork IDs to prove migration
-- follows the artwork rather than assuming a particular physical side.
local legacy={version=2,sets={central={x=117,size=121,swapped=true},edge={role='resources',enabled=true}},content={
 spells={left={addedEffects={layer(166009,'Arcane Blast')}}},
 resources={right={resource='energy',addedEffects={layer(166011,'unused')}}},
 druid={left={art='groveheart',flip=true,size=113,addedEffects={layer(166602,'Regrowth')}},right={art='moonwarden',effects=false,addedEffects={layer(166009,'16870')}}}}}
local old=E.Copy(legacy);local db=E.Normalize(legacy);local bank=db.content.classes.DRUID
assert(equal(legacy,old),'Migration must not mutate its input')
assert(db.version==4 and db.sets.central.x==117 and db.sets.central.size==121 and db.sets.central.swapped)
assert(bank.slots.restoration.art=='druidRestoration'and bank.slots.balance.art=='druidBalance')
assert(bank.slots.restoration.flip and bank.slots.restoration.size==113 and not bank.slots.balance.effects)
assert(bank.slots.restoration.addedEffects[1].trailX==41 and bank.slots.restoration.addedEffects[1].scale==.37)
assert(bank.slots.restoration.addedEffects[1].binding.spell=='Regrowth'and bank.slots.balance.addedEffects[1].binding.spell=='16870')
assert(#bank.slots.feral.addedEffects==0 and bank.active.balance and bank.active.restoration and not bank.active.feral)
assert(db.content.spells.left.addedEffects[1].binding.spell=='Arcane Blast'and db.content.resources.right.resource=='energy')
assert(db.content.resources.right.addedEffects[1].behavior=='static'and not db.content.resources.right.addedEffects[1].binding)
assert(equal(db,E.Normalize(db)),'Schema-3 normalization must be idempotent')
local empty=E.Normalize({version=2,content={druid={left={art='moonwarden',addedEffects={}},right={art='groveheart',addedEffects={}}}}})
assert(#empty.content.classes.DRUID.slots.balance.addedEffects==0 and #empty.content.classes.DRUID.slots.restoration.addedEffects==0)
print('PASS: schema-2 artwork-aware effect migration, exact tuning/empty banks, Arcane/Resources preservation and idempotence')

Mock.class='DRUID';EpicastDB=db;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
assert(E.panel:IsShown(),'First use must offer the crest chooser')
assert(E.panel.save.enabled,'First-use defaults must be confirmable without toggling a setting')
local p=E.panel;E.draft.sets.central.swapped=false;E.Apply();E.RefreshOptions()
assert(#p.pages.central.crests==3 and p.pages.central.crests[1].label:GetText()=='Balance')
local originals=E.Copy(E.draft.content.classes.DRUID.slots)
p.pages.central.crests[2]:Click();Mock.advance(0)
assert(#E.DisplaySides(E.draft,'central')==3)
local instances=E.instances.central
assert(instances.left.config.art=='druidBalance'and instances.middle.config.art=='druidFeral'and instances.right.config.art=='druidRestoration')
assert(instances.middle.frame:IsVisible()and instances.middle.druidSister.host:IsVisible())
local x1,x2,x3=instances.left.frame.point[4],instances.middle.frame.point[4],instances.right.frame.point[4]
assert(x1<x2 and x2<x3)
assert(math.abs(x2-x1-(instances.left.frame:GetWidth()+instances.middle.frame:GetWidth())/2-E.draft.sets.central.gap)<1e-6)
p.middle:Click();assert(E.editorSide=='middle'and E.GetSide(E.draft,'central','middle').art=='druidFeral')
p.flip:Click();assert(E.draft.content.classes.DRUID.slots.feral.flip)
p.swapArt:Click();assert(instances.left.config.art=='druidRestoration'and instances.middle.config.art=='druidFeral')
p.swapArt:Click();p.pages.central.crests[1]:Click();p.pages.central.crests[3]:Click()
assert(#E.DisplaySides(E.draft,'central')==1 and instances.left.config.art=='druidFeral')
assert(not instances.middle.frame:IsShown()and not instances.right.frame:IsShown())
assert(math.abs(instances.left.frame.point[4]-(UIParent:GetWidth()/2+117))<1e-6)
p.pages.central.crests[2]:Click();assert(#E.DisplaySides(E.draft,'central')==0 and not instances.left.frame:IsShown())
assert(not p.openEffects.enabled and not p.flip.enabled)
p.pages.central.crests[1]:Click();p.pages.central.crests[2]:Click();p.pages.central.crests[3]:Click()
p.save:Click();assert(EpicastDB.content.classes.DRUID.configured)
local saved=E.Copy(EpicastDB)
p.pages.central.crests[2]:Click();p.cancel:Click();assert(equal(EpicastDB,saved)and instances.middle.frame:IsShown())
print('PASS: first-use multi-selection, one/two/three/zero crest layout, middle editing, swaps and transactional Save/Cancel')

E.devMode=true;E.OpenOptions();p.authorClass:Click();assert(#Mock.menu==#E.ClassOrder)
for _,class in ipairs(E.ClassOrder)do
 E.SetAuthoringClass(class);assert(E.ActiveClass()==class)
 do
  local b=E.ClassBank(E.draft);local definition=E.ClassSpecs[class];assert(#definition.slots==3)
  for _,spec in ipairs(definition.slots)do E.SelectSpec(E.draft,class,spec[1],true)end
  E.Apply();E.RefreshOptions()
  for _,side in ipairs(E.PhysicalSides)do assert(E.GetSide(E.draft,'central',side))end
 end
end
E.SetAuthoringClass('WARRIOR');p.middle:Click()
assert(E.GetEffectLibraryTarget().art=='none')
assert(E.AddLibraryEffect(E.GetEffectLibraryTarget(),layer(166009,'12345'))==1)
E.PreviewLibraryChange();Mock.advance(0)
assert(E.TestBoundEffect('middle','none',1),'Dev testing must work on an unbuilt class slot')
assert(E.instances.central.middle.addedEffectSlots[1].boundTest)
E.SetAuthoringClass('DRUID');assert(not E.instances.central.middle.addedEffectSlots[1].boundTest)
assert(equal(E.draft.content.classes.DRUID.slots,saved.content.classes.DRUID.slots))
E.SetAuthoringClass('WARRIOR');E.SaveEffectStudio()
assert(#EpicastDB.content.classes.WARRIOR.slots.fury.addedEffects==1)
Mock.combat=true;E.SetAuthoringClass('MAGE');assert(E.ActiveClass()=='WARRIOR');Mock.combat=false
p:Hide();assert(E.ActiveClass()=='DRUID'and E.previewClass==nil and instances.middle.config.art=='druidFeral')
E.OpenOptions();E.SetAuthoringClass('WARRIOR');Mock.combat=true;p:Hide()
assert(E.ActiveClass()=='DRUID'and not instances.left.frame:IsShown()and E.pending)
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0)
assert(instances.middle.config.art=='druidFeral'and instances.middle.frame:IsShown())
E.OpenOptions();E.SetAuthoringClass('MAGE');E.devMode=false;E.previewClass=nil;E.Apply();E.RefreshOptions()
assert(E.ActiveClass()=='DRUID'and not p.authorClass:IsShown())
p:Hide();Mock.class='WARRIOR';E.Apply();assert(instances.left.config.art=='none'and not instances.left.druidSister.host:IsShown())
assert(EpicastDB.previewClass==nil)
Mock.class='DRUID';E.devMode=true;E.OpenOptions();p.swapRoles:Click();p.tabs.edge:Click()
assert(E.draft.sets.edge.role=='spells'and #E.DisplaySides(E.draft,'edge')==3)
local edge=E.instances.edge
assert(edge.left.frame:IsVisible()and edge.middle.frame:IsVisible()and edge.right.frame:IsVisible())
assert(edge.middle.frame.point[4]==UIParent:GetWidth()/2)
assert(edge.left.frame.point[4]<edge.middle.frame.point[4]and edge.middle.frame.point[4]<edge.right.frame.point[4])
assert(E.instances.central.middle.config==nil and not E.instances.central.middle.frame:IsShown(),'Resources must stay a pair')
p.middle:Click();assert(E.GetEffectLibraryTarget().art=='druidFeral')
Mock.cursorX=200;Mock.cursorY=300;edge.middle.handle:emit('OnDragStart');Mock.cursorX=235;Mock.cursorY=317;edge.middle.handle:emit('OnUpdate');edge.middle.handle:emit('OnDragStop')
assert(E.draft.sets.edge.middleX==35 and E.draft.sets.edge.middleY==17)
p.cancel:Click();assert(EpicastDB.sets.central.role=='spells'and EpicastDB.sets.edge.middleX==0)
print('PASS: every class has isolated authoring slots, middle-slot tests, combat guard, temporary dev override and class-restricted restoration')
