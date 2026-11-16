local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function near(a,b)assert(math.abs(a-b)<.00001,tostring(a)..' ~= '..tostring(b))end
EpicastDB=nil;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
local p=E.panel
local function typeValue(key,text)
 local input=p.inputs[key];assert(input:IsVisible(),'Typing into hidden input')
 input:SetFocus();input:SetText(tostring(text));input:emit('OnTextChanged',true);return input
end
local function enter(key,text)local input=typeValue(key,text);input:emit('OnEnterPressed')end
local function current()return E.GetSide(E.draft,E.editorSet,E.editorSide)end
assert(p.crests:IsVisible()and p.placement:IsVisible()and not p.settings:IsVisible()and not p.behavior:IsVisible())
assert(p.save:IsVisible()and p.save.enabled and p.choiceHint:GetText():find('any combination',1,true))
assert(p.crestRows[3].preview.texture:find('MageRebootArcaneCASSize192.tga',1,true))
near(p.crestRows[3].preview.uv[7],.75);near(p.crestRows[3].preview.uv[8],.75)
local original=E.Copy(EpicastDB)
p.mainTabs.settings:Click();assert(p.settings:IsVisible()and not p.crests:IsVisible()and p.save:IsVisible())
p.mainTabs.crests:Click();p.detailTabs.behavior:Click();p.detailTabs.placement:Click()
assert(equal(original,EpicastDB)and not E.HasChanges(),'Navigation changed settings')
p.save:Click();assert(not p.save.enabled and not E.HasPendingSetup())
p.detailTabs.behavior:Click();assert(p.responses:GetText():find('Missile Barrage',1,true)and p.responses:GetText():find('While buff active',1,true))
assert(p.responses:GetText():find('Arcane Missiles',1,true));p.detailTabs.placement:Click()
local aura=E.GetAddedEffects(current())[4].binding;local spell=aura.spell;local getName=C_Spell.GetSpellName
aura.spell='400589';C_Spell.GetSpellName=function()error('unavailable')end;E.RefreshOptions()
assert(p.responses:GetText():find('400589',1,true),'Failed spell lookup must retain the configured ID')
local secret={};local isSecret=issecretvalue
issecretvalue=function(v)return v==secret end;C_Spell.GetSpellName=function()return secret end;E.RefreshOptions()
assert(p.responses:GetText():find('400589',1,true),'Restricted spell name escaped into UI text')
issecretvalue=isSecret;C_Spell.GetSpellName=getName;aura.spell=spell;E.RefreshOptions();assert(not E.HasChanges())

-- Selection does not toggle visibility; show/hide does not change the editor.
local neighbor=E.Copy(E.draft.content.classes.MAGE.slots.arcane)
p.crestRows[1].choose:Click();assert(E.editorSide=='fire'and not E.IsCrestEnabled(E.draft,'spells','fire'))
assert(p.detailMeta:GetText():find('Hidden',1,true))
p.crestRows[3].active:Click();assert(E.editorSide=='fire'and not E.IsCrestEnabled(E.draft,'spells','arcane'))
p.crestRows[1].active:Click();assert(E.editorSide=='fire'and E.GetEntry('spells','fire').handle:IsVisible())
typeValue('x','-413.5');assert(current().x~=-413.5 and p.save.enabled)
p.crestRows[2].choose:Click();near(E.draft.content.classes.MAGE.slots.fire.x,-413.5)
assert(current().x~=-413.5,'Text was committed to the next crest')
typeValue('size','132.5');p.mainTabs.settings:Click();near(E.draft.content.classes.MAGE.slots.frost.size,132.5)
p.hide:Click();p.mainTabs.crests:Click();p.crestRows[1].choose:Click()
enter('y','-17.25');p.save:Click()
near(EpicastDB.content.classes.MAGE.slots.fire.y,-17.25);assert(EpicastDB.hideBlizzard and not E.HasChanges())
assert(equal(neighbor,EpicastDB.content.classes.MAGE.slots.arcane),'Neighbor configuration changed')
print('PASS: first-use multi-selection, pure navigation, selection/visibility separation, typed edits stay with their crest, cross-tab Save and unchanged neighbors')

-- Precise input, limits, keyboard traversal, nudging and scoped alignment/reset.
enter('x','-8001');assert(current().x==-8000)
enter('x','8001');assert(current().x==8000)
enter('size','999');assert(current().size==400)
enter('size','0');assert(current().size==25)
enter('x','-413.5');local x=current().x
for _,invalid in ipairs({'','-','abc','1e999'})do enter('x',invalid);near(current().x,x);assert(p.inputNotice:GetText():find('valid number',1,true))end
typeValue('x','777'):emit('OnEscapePressed');near(current().x,x);near(tonumber(p.inputs.x:GetText()),x)
typeValue('x','12.75'):ClearFocus();near(current().x,12.75)
typeValue('x','17'):emit('OnTabPressed');assert(p.inputs.y:HasFocus());near(current().x,17)
IsShiftKeyDown=function()return true end;p.inputs.y:emit('OnTabPressed');assert(p.inputs.x:HasFocus())
p.placementButtons[2]:Click();near(current().x,27)
IsShiftKeyDown=function()return false end;p.placementButtons[1]:Click();near(current().x,26)
p.center:Click();near(current().x,0);p.bottom:Click();near(current().y,0)
local effects=E.Copy(E.GetAddedEffects(current()));p.flip:Click();local flipped=current().flip
p.reset:Click();assert(current().size==100 and current().x==E.DefaultCrestX('spells','fire')and current().y==0 and current().flip==flipped and equal(effects,E.GetAddedEffects(current())))
p.save:Click();local committed=E.Copy(EpicastDB)
typeValue('x','404');assert(p.close:GetText()=='Discard & close');p.close:Click()
assert(not p:IsShown()and equal(committed,EpicastDB),'Close saved unfinished text')
E.OpenOptions();assert(p.close:GetText()=='Close');typeValue('y','111');p.cancel:Click();assert(equal(committed,EpicastDB))
E.OpenOptions();typeValue('x','456');p.save:Click();assert(EpicastDB.content.classes.MAGE.slots.fire.x==456)
print('PASS: exact signed/decimal input, bounds, invalid values, Escape/focus/Tab/Shift, 1/10 nudges, per-crest alignment/reset, pending-text Save and Cancel/Close rollback')

-- Main navigation controls placement handles, not runtime crest visibility.
local entry=E.GetEntry('spells','fire');assert(entry.handle:IsVisible())
p.detailTabs.behavior:Click();assert(not entry.handle:IsShown()and entry.frame:IsVisible())
p.motion:Click();assert(not current().effects and p.responses:GetText():find('currently off',1,true));p.motion:Click()
p.mainTabs.settings:Click();assert(not entry.handle:IsShown()and entry.frame:IsVisible())
p.developer:Click();assert(E.devMode and not E.HasChanges(),'Session-only developer toggle dirtied saved settings')
p.mainTabs.crests:Click();p.authorClass:Click();assert(#Mock.menu==9)
for _,choice in ipairs(Mock.menu)do if choice.name=='Druid'then choice.choose();break end end
assert(E.ActiveClass()=='DRUID'and p.context:GetText():find('Druid preview',1,true))
assert(p.crestRows[1].preview.texture:find('DruidBalanceCASSize192.tga',1,true))
near(p.crestRows[1].preview.uv[7],.75);near(p.crestRows[1].preview.uv[8],1)
near(p.crestRows[1].preview.width,42);near(p.crestRows[1].preview.height,56)
assert(p.openEffects:IsVisible());p.openEffects:Click();assert(E.EffectLibrary.window:IsVisible())
E.EffectLibrary.window.layerControls.crest:Click();Mock.menu[2].choose();assert(E.editorSide=='feral')
p.mainTabs.settings:Click();p.developer:Click()
assert(not E.devMode and E.ActiveClass()=='MAGE'and not E.EffectLibrary.window:IsVisible())
p.mainTabs.crests:Click();p.detailTabs.placement:Click();assert(E.CanDragCrests())
-- A real drag is cancelled immediately when leaving placement.
E.SelectCrest('spells','fire');Mock.cursorX=0;Mock.cursorY=0;entry.handle:emit('OnDragStart')
assert(entry.handle.scripts.OnUpdate);p.mainTabs.settings:Click();assert(not entry.handle.scripts.OnUpdate)
print('PASS: drag handles only in Placement, foreign class previews/return, correct artwork thumbnail aspect/UV, discoverable developer toggle and unchanged library handoff')

-- Resource preview restrictions are explained beside the selected config.
Mock.class='DRUID';E.SelectCrest('resources','left');p.crestRows[1].active:Click()
assert(current().enabled and p.detailMeta:GetText():find('Preview only',1,true))
assert(p.crestRows[1].placeholder:IsShown()and not p.crestRows[1].preview:IsShown())
p.detailTabs.behavior:Click();assert(p.resource:IsVisible()and p.resourceHelp:GetText():find('Mage-only',1,true))
p.resource:Click();Mock.menu[7].choose();assert(p.resource:GetText()=='Resource: Current power  v')
p.mainTabs.settings:Click();p.class:Click();p.mainTabs.crests:Click()
assert(p.detailMeta:GetText():find('Shown in game',1,true)and not p.resourceHelp:GetText():find('Mage-only',1,true))
assert(not p.crestRows[3]:IsShown());p.cancel:Click();Mock.class='MAGE'
E.OpenOptions();E.SelectCrest('spells','fire');E.SelectCrestPage('placement')
local beforeCombat=E.Copy(E.draft);typeValue('x','999');Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED')
assert(not p.inputs.x.enabled and not p.save.enabled and not p.mainTabs.settings.enabled and not entry.handle:IsShown())
p.mainTabs.settings:Click();p.placementButtons[1]:Click();p.save:Click()
assert(equal(beforeCombat,E.draft)and not p.inputs.x.dirty)
p.close:Click();assert(not p:IsShown()and E.draft==nil)
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0);E.OpenOptions()
print('PASS: contextual resource filter/meter controls, pending-art state, combat rejects edits and clears unfinished text, Close remains available')

-- Layout bounds and persistent action bar on every page, at narrow/short sizes.
local function descendant(frame,ancestor)
 while frame do if frame==ancestor then return true end;frame=frame.parent end
 return false
end
local function bounds(frame)
 if frame==p then return 0,0,frame.width,frame.height end
 local x,y=bounds(frame.parent);local point=frame.point or{'TOPLEFT',0,0}
 assert(point[1]=='TOPLEFT','Unexpected interactive anchor')
 return x+(point[2]or 0),y-(point[3]or 0),frame.width,frame.height
end
local function checkLayout()
 assert(p.save:IsVisible()and p.cancel:IsVisible()and p.close:IsVisible())
 local widgets={}
 for _,frame in ipairs(Mock.frames)do
  if descendant(frame,p)and frame:IsVisible()and frame.point and(frame.kind=='Button'or frame.kind=='CheckButton'or frame.kind=='EditBox')then
   local x,y,w,h=bounds(frame);assert(x>=0 and y>=0 and x+w<=p.width and y+h<=p.height,'Control escapes panel: '..frame:GetText())
   for _,other in ipairs(widgets)do local a,b,c,d=bounds(other)
    assert(x+w<=a or a+c<=x or y+h<=b or b+d<=y,'Overlapping hit areas: '..frame:GetText()..' / '..other:GetText())
   end
   widgets[#widgets+1]=frame
  end
 end
end
for _,size in ipairs({{1920,1080},{1280,720},{800,600}})do
 UIParent:SetSize(size[1],size[2]);E.RefreshOptions()
 assert(p.width*p.scale<=size[1]-30+.01 and p.height*p.scale<=size[2]-30+.01)
 E.SelectOptionsPage('settings');checkLayout();E.SelectOptionsPage('crests');E.SelectCrestPage('placement');checkLayout();E.SelectCrestPage('behavior');checkLayout()
end
UIParent:SetSize(1920,1080)
print('PASS: main UI action targets stay inside the panel without overlap; footer survives all pages and 1080p/720p/800x600 scaling')
