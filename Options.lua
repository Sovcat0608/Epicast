local _,E=...
local WIDTH,HEIGHT=840,632
local WHITE="Interface\\Buttons\\WHITE8X8"
local function label(parent,text,x,y,width,font)
 local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
 t:SetPoint("TOPLEFT",x,y);t:SetWidth(width or 460);t:SetJustifyH("LEFT");t:SetText(text);return t
end
local function box(parent,x,y,w,h,name)
 local f=CreateFrame("Frame",name,parent,"BackdropTemplate");f:SetPoint("TOPLEFT",x,y);f:SetSize(w,h)
 f:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1});f:SetBackdropColor(.055,.05,.085,.95);f:SetBackdropBorderColor(.23,.21,.3,1);return f
end
local function button(parent,text,x,y,width,fn,allowCombat)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width,26);b:SetPoint("TOPLEFT",x,y);b:SetText(text)
 b:SetScript("OnClick",function()if allowCombat or not InCombatLockdown()then fn()end end);return b
end
local function checkbox(parent,text,x,y,width,fn)
 local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetSize(28,28);b:SetPoint("TOPLEFT",x,y)
 b.label=label(b,text,32,-7,width);b:SetScript("OnClick",function(self)if not InCombatLockdown()then fn(self:GetChecked()==true)end end);return b
end
local function tab(parent,text,x,y,w,fn)
 local b=CreateFrame("Button",nil,parent,"PanelTopTabButtonTemplate")
 b:SetText(text);b:SetPoint("TOPLEFT",x,y);PanelTemplates_TabResize(b,0,w)
 b:SetScript("OnClick",function()if not InCombatLockdown()then fn()end end);return b
end
local function target()return E.draft and E.GetSide(E.draft,E.editorSet,E.editorSide)end
local function change()E.Apply();E.RefreshOptions()end
local function pendingInput()
 for _,input in pairs(E.panel and E.panel.inputs or{})do if input.dirty then return true end end
 return false
end
function E.HasPendingSetup()local b=E.draft and E.ClassBank(E.draft);return b and not b.configured end
function E.CanSave()return not InCombatLockdown()and(E.HasChanges()or E.HasPendingSetup()or pendingInput())end
function E.UpdateSaveButton()
 local enabled=E.CanSave();local p=E.panel
 if p then
  local dirty=E.HasChanges()or pendingInput()
  p.save:SetEnabled(enabled)
  p.pending:SetText(InCombatLockdown()and "Editing paused during combat" or(E.HasPendingSetup()and "Choose your crests, then Save" or(dirty and "Unsaved changes across tabs" or "All changes saved")))
  p.close:SetText(dirty and "Discard & close" or "Close")
 end
 local w=E.EffectLibrary and E.EffectLibrary.window;if w and w.saveAll then w.saveAll:SetEnabled(enabled)end
end
function E.GetEffectLibraryTarget()
 if not E.devMode or not E.draft or not E.panel or not E.panel:IsShown()then return end
 return target(),E.editorSide,E.editorSet
end
function E.CanDragCrests()return E.optionsPage=="crests"and E.crestPage=="placement"end
E.editorKeys={};E.optionsPage="crests";E.crestPage="placement"
local function selectionID(group)return E.ActiveClass()..":"..group end
local function displayNumber(value)return (string.format("%.2f",value):gsub("%.?0+$",""))end
local function discardInputs()
 for key,input in pairs(E.panel and E.panel.inputs or{})do
  input.dirty=false;input.owner=nil;input:ClearFocus()
  if target()then input:SetText(displayNumber(target()[key]))end
 end
end
function E.FlushPlacementInputs()
 local valid=true;local changed=false
 for key,input in pairs(E.panel and E.panel.inputs or{})do
  if input.dirty then
   local c=target();local value=tonumber(input:GetText())
   if c and input.owner==c and not InCombatLockdown()then
    if value and value==value and value~=math.huge and value~=-math.huge then
     value=E.Number(value,c[key],input.minimum,input.maximum);changed=changed or c[key]~=value;c[key]=value
    else valid=false end
   end
   input.dirty=false;input.owner=nil;input:ClearFocus()
   if c then input:SetText(displayNumber(c[key]))end
  end
 end
 if changed then E.Apply()end
 if E.panel then E.panel.inputNotice:SetText(valid and "Use +/- to nudge by 1. Hold Shift for 10." or "Enter a valid number. The previous value was kept.")end
 return valid
end
function E.SelectOptionsPage(page)
 if InCombatLockdown()or not E.draft or(page~="crests"and page~="settings")then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.optionsPage=page;change()
end
function E.SelectCrestPage(page)
 if InCombatLockdown()or not E.draft or(page~="placement"and page~="behavior")then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.crestPage=page;change()
end
function E.SelectCrest(group,key)
 if InCombatLockdown()or not E.draft or not E.SetLabels[group]then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.StopBoundTests();E.optionsPage="crests";E.editorSet=group;E.editorSide=key or E.editorKeys[selectionID(group)];E.RefreshOptions();E.Apply()
end
function E.OpenCrestMenu(owner)
 if InCombatLockdown()or not E.draft then return end
 if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner,function(_,root)
  for _,group in ipairs({"spells","resources"})do for _,choice in ipairs(E.CrestChoices(group))do local key=choice[1]
   root:CreateRadio(E.SetLabels[group].." · "..E.CrestLabel(E.draft,group,key),function()return E.editorSet==group and E.editorSide==key end,function()E.SelectCrest(group,key)end)
  end end
 end)end
end
function E.SetAuthoringClass(class)
 if not E.devMode or InCombatLockdown()or not E.ClassSpecs[class]or not E.draft then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.StopBoundTests();E.previewClass=class;E.editorSide=E.editorKeys[selectionID(E.editorSet)];change()
end
function E.OpenAuthoringClassMenu(owner)
 if not E.devMode or InCombatLockdown()or not E.draft then return end
 if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(owner,function(_,root)
  for _,class in ipairs(E.ClassOrder)do root:CreateRadio(E.ClassSpecs[class].name,function()return E.ActiveClass()==class end,function()E.SetAuthoringClass(class)end)end
 end)end
end
function E.ClearAuthoringClass()
 local previous=E.previewClass;E.previewClass=nil
 if previous and previous~=E.PlayerClass()then for _,entries in pairs(E.instances)do for _,entry in pairs(entries)do entry.frame:Hide()end end end
end
function E.SetDeveloperMode(enabled)
 if InCombatLockdown()then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.devMode=enabled==true;E.StopBoundTests()
 if not E.devMode then E.ClearAuthoringClass();if E.EffectLibrary then E.EffectLibrary.Close()end;if E.bakeExport then E.bakeExport:Hide()end end
 change()
end
function E.PreviewLibraryChange()if E.GetEffectLibraryTarget()and not InCombatLockdown()then E.Apply();E.UpdateSaveButton()end end
function E.SaveEffectStudio()
 if not E.draft or InCombatLockdown()then return end
 if not E.FlushPlacementInputs()then E.RefreshOptions();return end
 E.StopBoundTests();local b=E.ClassBank(E.draft);if b then b.configured=true end;E.Commit();E.Begin();change()
end
function E.CancelEffectStudio()
 if not E.draft or InCombatLockdown()then return end
 discardInputs();E.StopBoundTests();E.Cancel();E.Begin();change()
end
local function numberInput(parent,key,x,y,width,lo,hi)
 local input=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");input:SetSize(width,26);input:SetPoint("TOPLEFT",x,y)
 input:SetAutoFocus(false);input:SetMaxLetters(12);input.minimum=lo;input.maximum=hi
 input:SetScript("OnTextChanged",function(self,user)
  if user and not E.refreshing and not InCombatLockdown()then self.owner=target();self.dirty=true;E.UpdateSaveButton()end
 end)
 input:SetScript("OnEnterPressed",function(self)E.FlushPlacementInputs();self:ClearFocus();E.RefreshOptions()end)
 input:SetScript("OnEditFocusLost",function(self)if self.dirty then E.FlushPlacementInputs();E.RefreshOptions()end end)
 input:SetScript("OnEscapePressed",function(self)self.dirty=false;self.owner=nil;self:ClearFocus();E.RefreshOptions()end)
 input:SetScript("OnTabPressed",function()
  if not E.FlushPlacementInputs()then E.RefreshOptions();return end
  local order={"size","x","y"};local direction=IsShiftKeyDown and IsShiftKeyDown()and -1 or 1
  for i,name in ipairs(order)do if name==key then local nextInput=E.panel.inputs[order[(i-1+direction)%3+1]];nextInput:SetFocus();nextInput:HighlightText();break end end
  E.RefreshOptions()
 end)
 return input
end
local function nudge(key,direction)
 if not target()or not E.FlushPlacementInputs()then E.RefreshOptions();return end
 local input=E.panel.inputs[key];local step=IsShiftKeyDown and IsShiftKeyDown()and 10 or 1
 target()[key]=E.Number(target()[key]+direction*step,0,input.minimum,input.maximum);change()
end
local function preview(texture,c)
 local art=E.artworkByID[c.art];texture:SetShown(art.path~=nil)
 if not art.path then return end
 local height=192*art.height/art.width;local backingH=1;while backingH<height do backingH=backingH*2 end
 texture:SetTexture((art.path:gsub("CASSize%d+%.tga$","CASSize192.tga")))
 texture:SetSize(56*art.width/art.height,56);texture:SetTexCoord(E.UV({0,0,0,height/backingH,.75,0,.75,height/backingH},c.flip))
end
local function selectedTabs(tabs,current,unlocked)
 for key,t in pairs(tabs)do
  if key==current then PanelTemplates_SelectTab(t)else PanelTemplates_DeselectTab(t)end
  t:SetEnabled(unlocked and key~=current)
 end
end
local function responseSummary(c)
 if not c.effects then return "Animation and effects are currently off."end
 local groups,order={},{}
 for _,fx in ipairs(E.GetAddedEffects(c))do if fx.behavior=="bound"and fx.binding then
  local b=fx.binding;local spell=b.spell;local group=groups[spell]
  if not group then
   local name=spell~=""and spell or "No spell bound"
   if tonumber(spell)and C_Spell and C_Spell.GetSpellName then
    local ok,value=pcall(C_Spell.GetSpellName,tonumber(spell))
    if ok and not(issecretvalue and issecretvalue(value))and type(value)=="string"then name=value end
   end
   group={name=name,kinds={},seen={}};groups[spell]=group;order[#order+1]=group
  end
  if not group.seen[b.kind]then
   local kind=b.kind;for _,v in ipairs(E.BindingKinds)do if v[1]==kind then kind=v[2];break end end
   group.kinds[#group.kinds+1]=kind;group.seen[b.kind]=true
  end
 end end
 local lines={};for i=1,math.min(#order,#order>4 and 3 or 4)do local group=order[i];lines[#lines+1]=group.name.." · "..table.concat(group.kinds," / ")end
 if #order>4 then lines[#lines+1]=string.format("+ %d more spells in the effect library",#order-3)end
 if #lines==0 then return #E.GetAddedEffects(c)==0 and "This crest has no baked spell effects yet."or "These layers stay active while this crest is shown."end
 return table.concat(lines,"\n")
end
function E.RefreshOptions()
 local p=E.panel;if not p or not p:IsShown()or not E.draft then return end
 local db=E.draft;local choices=E.CrestChoices(E.editorSet);local unlocked=not InCombatLockdown()
 if not target()then E.editorSide=nil;for _,choice in ipairs(choices)do if E.IsCrestEnabled(db,E.editorSet,choice[1])then E.editorSide=choice[1];break end end;E.editorSide=E.editorSide or(choices[1]and choices[1][1])end
 local c=target();if not c then return end;E.editorKeys[selectionID(E.editorSet)]=E.editorSide;E.refreshing=true
 local class=E.ActiveClass();local className=E.ClassSpecs[class].name;local resource=E.editorSet=="resources"
 p:SetScale(math.max(.35,math.min(1,(UIParent:GetHeight()-30)/HEIGHT,(UIParent:GetWidth()-30)/WIDTH)))
 p.crests:SetShown(E.optionsPage=="crests");p.settings:SetShown(E.optionsPage=="settings")
 p.placement:SetShown(E.crestPage=="placement");p.behavior:SetShown(E.crestPage=="behavior")
 selectedTabs(p.mainTabs,E.optionsPage,unlocked);selectedTabs(p.tabs,E.editorSet,unlocked);selectedTabs(p.detailTabs,E.crestPage,unlocked)
 p.authorClass:SetShown(E.devMode);p.authorClass:SetText("Preview class: "..className.."  v");p.authorClass:SetEnabled(unlocked)
 p.collection:SetShown(not E.devMode);p.collection:SetText(resource and "Resource crests" or(className.." crests"))
 p.context:SetText(E.devMode and("Developer mode · "..className.." preview · ends on Close")or"Artwork & spell effects")
 p.choiceHint:SetText(E.HasPendingSetup()and not resource and "Choose any combination, then Save. Your talent spec will not switch them." or "Check Show to display a crest. Select its card to edit it.")
 for i,row in ipairs(p.crestRows)do
  local choice=choices[i];row:SetShown(choice~=nil);row.key=choice and choice[1]
  if choice then
   local config=E.GetSide(db,E.editorSet,choice[1]);local active=E.IsCrestEnabled(db,E.editorSet,choice[1]);local selected=choice[1]==E.editorSide
   row.choose:SetText(E.CrestLabel(db,E.editorSet,choice[1]));row.choose:SetEnabled(unlocked);row.active:SetChecked(active);row.active:SetEnabled(unlocked)
   row.summary:SetText((selected and "Editing"or(active and "Shown"or"Hidden")).." · "..displayNumber(config.size).."%")
   row.mark:SetShown(selected);row:SetBackdropBorderColor(selected and .7 or .23,selected and .45 or .21,selected and 1 or .3,1)
   preview(row.preview,config);row.placeholder:SetShown(E.artworkByID[config.art].pending==true)
  end
 end
 local active=E.IsCrestEnabled(db,E.editorSet,E.editorSide)
 local visibility=active and "Shown in game"or"Hidden — settings are kept"
 if active and resource and db.classOnly and E.PlayerClass()~="MAGE"then visibility="Preview only · Mage-only visibility"end
 p.subject:SetText(E.CrestLabel(db,E.editorSet,E.editorSide));p.detailMeta:SetText((resource and "Resources"or className).." · "..visibility)
 p.artNotice:SetText(E.artworkByID[c.art].pending and(resource and "Artwork pending. Native effects and meters remain available."or "Artwork pending. Native effects remain available.")or "Each crest has its own size, position and effects.")
 for key,input in pairs(p.inputs)do
  if not unlocked then input.dirty=false;input.owner=nil;input:ClearFocus()end
  if not input.dirty then input:SetText(displayNumber(c[key]))end
  if unlocked then input:Enable()else input:Disable()end
 end
 p.sliders.size:SetValue(c.size);p.sliders.size.control:SetEnabled(unlocked)
 for _,b in ipairs(p.placementButtons)do b:SetEnabled(unlocked)end
 p.flip:SetChecked(c.flip);p.flip:SetEnabled(unlocked);p.motion:SetChecked(c.effects);p.motion:SetEnabled(unlocked)
 p.resource:SetShown(resource);p.resource:SetEnabled(unlocked)
 local resourceName=c.resource;for _,r in ipairs(E.ResourceKinds)do if r[1]==c.resource then resourceName=r[2]end end
 p.resource:SetText("Resource: "..resourceName.."  v");p.meter:SetShown(resource);p.meter:SetChecked(c.showMeter);p.meter:SetEnabled(unlocked)
 p.resourceHelp:SetShown(resource);p.resourceHelp:SetText(db.classOnly and "Mage-only visibility is enabled in Settings. Other classes can preview resources here, but they are hidden after Close."or "Resource crests can appear on any class. Effect intensity follows the selected resource.")
 local bound=0;for _,fx in ipairs(E.GetAddedEffects(c))do if fx.behavior=="bound"then bound=bound+1 end end
 p.effectSummary:SetText(string.format("%d effect layers · %d spell-bound",#E.GetAddedEffects(c),bound));p.effectSummary:SetShown(not resource)
 p.responses:SetText(responseSummary(c));p.responses:SetShown(not resource)
 p.openEffects:SetShown(E.devMode);p.openEffects:SetEnabled(unlocked);p.report:SetShown(E.devMode and not resource);p.report:SetEnabled(unlocked and bound>0)
 p.exportBake:SetShown(E.devMode);p.exportBake:SetEnabled(unlocked)
 p.studioHint:SetText(E.devMode and "Effect edits are session-only. Copy a bake before reload to include them in a release."or "Spell effects belong to this crest and update with the addon.")
 p.hide:SetChecked(db.hideBlizzard);p.hide:SetEnabled(unlocked);p.class:SetChecked(db.classOnly);p.class:SetEnabled(unlocked)
 p.hideCooldown:SetChecked(db.hideCooldownManager);p.hideCooldown:SetEnabled(unlocked);p.developer:SetChecked(E.devMode==true);p.developer:SetEnabled(unlocked);p.cancel:SetEnabled(unlocked)
 E.refreshing=false;E.UpdateSaveButton();if E.EffectLibrary then E.EffectLibrary.RefreshTarget()end
end
local function create()
 local p=box(UIParent,0,0,WIDTH,HEIGHT,"EpicastOptions");E.panel=p;p:ClearAllPoints();p:SetPoint("CENTER");p:SetFrameStrata("DIALOG")
 p:SetMovable(true);p:SetClampedToScreen(true);p:EnableMouse(true)
 p.header=CreateFrame("Frame",nil,p);p.header:SetPoint("TOPLEFT");p.header:SetSize(WIDTH-170,60);p.header:EnableMouse(true);p.header:RegisterForDrag("LeftButton")
 p.header:SetScript("OnDragStart",function()p:StartMoving()end);p.header:SetScript("OnDragStop",function()p:StopMovingOrSizing()end)
 label(p,"EPICAST",20,-16,200,"GameFontNormalLarge");p.context=label(p,"",20,-40,650)
 p.close=button(p,"Close",684,-17,136,function()p:Hide()end,true)
 p.mainTabs={crests=tab(p,"Crests",18,-82,150,function()E.SelectOptionsPage("crests")end),settings=tab(p,"Settings",178,-82,150,function()E.SelectOptionsPage("settings")end)}
 p.crests=CreateFrame("Frame",nil,p);p.crests:SetPoint("TOPLEFT",18,-114);p.crests:SetSize(804,450)
 local list=box(p.crests,0,0,268,450);local detail=box(p.crests,280,0,524,450)
 p.settings=box(p,18,-114,804,450)
 p.tabs={spells=tab(list,"Spellcasting",12,-12,118,function()E.SelectCrest("spells")end),resources=tab(list,"Resources",138,-12,118,function()E.SelectCrest("resources")end)}
 p.collection=label(list,"",12,-58,240,"GameFontNormal");p.authorClass=button(list,"",12,-50,244,function()E.OpenAuthoringClassMenu(p.authorClass)end)
 p.choiceHint=label(list,"",12,-86,244);p.choiceHint:SetHeight(36);p.crestRows={}
 for i=1,3 do
  local row=box(list,12,-134-(i-1)*98,244,86);p.crestRows[i]=row
  row.choose=CreateFrame("Button",nil,row);row.choose:SetPoint("TOPLEFT",0,0);row.choose:SetSize(190,86)
  local hover=row.choose:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(.8,.65,1,.08);row.choose:SetHighlightTexture(hover)
  row.title=label(row.choose,"",66,-19,122,"GameFontNormal");row.choose:SetFontString(row.title)
  row.choose:SetScript("OnClick",function()if row.key then E.SelectCrest(E.editorSet,row.key)end end)
  row.summary=label(row.choose,"",66,-45,124);row.preview=row.choose:CreateTexture(nil,"ARTWORK");row.preview:SetPoint("TOPLEFT",6,-15)
  row.preview:SetSnapToPixelGrid(false);row.preview:SetTexelSnappingBias(0)
  row.placeholder=label(row.choose,"Art\nsoon",10,-27,46)
  row.mark=row:CreateTexture(nil,"OVERLAY");row.mark:SetColorTexture(.7,.45,1,1);row.mark:SetPoint("TOPLEFT",0,0);row.mark:SetSize(3,86)
  row.active=checkbox(row,"Show",202,-18,36,function(value)
   if E.draft and row.key then E.FlushPlacementInputs();E.StopBoundTests();E.SetCrestEnabled(E.draft,E.editorSet,row.key,value);change()end
  end)
  row.active.label:ClearAllPoints();row.active.label:SetPoint("TOPLEFT",-2,-32)
 end
 p.subject=label(detail,"",18,-16,488,"GameFontNormalLarge");p.detailMeta=label(detail,"",18,-44,488)
 p.artNotice=label(detail,"",18,-64,488)
 p.detailTabs={placement=tab(detail,"Placement",18,-104,230,function()E.SelectCrestPage("placement")end),behavior=tab(detail,"Behavior",268,-104,238,function()E.SelectCrestPage("behavior")end)}
 p.placement=CreateFrame("Frame",nil,detail);p.placement:SetPoint("TOPLEFT",0,-136);p.placement:SetSize(524,300)
 p.behavior=CreateFrame("Frame",nil,detail);p.behavior:SetPoint("TOPLEFT",0,-136);p.behavior:SetSize(524,300)
 local layout=p.placement;p.inputs={};p.sliders={};p.placementButtons={}
 label(layout,"Size (%)",18,-4,250,"GameFontNormal")
 local control=CreateFrame("Frame",nil,layout,"MinimalSliderWithSteppersTemplate");control:SetPoint("TOPLEFT",18,-33);control:SetSize(346,20)
 control:Init(100,25,400,375,{});p.sliders.size=control.Slider;p.sliders.size.control=control
 p.sliders.size:HookScript("OnValueChanged",function(_,v)if not E.refreshing and not InCombatLockdown()and target()then
  E.FlushPlacementInputs();target().size=E.Number(math.floor(v+.5),100,25,400);change()
 end end)
 p.inputs.size=numberInput(layout,"size",396,-26,102,25,400)
 for i,spec in ipairs({{"x","Horizontal (from center)",-8000,8000},{"y","Height (from bottom)",-2000,3000}})do
  local key=spec[1];local x=i==1 and 18 or 280;label(layout,spec[2],x,-79,226,"GameFontNormal")
  p.placementButtons[#p.placementButtons+1]=button(layout,"-",x,-105,28,function()nudge(key,-1)end)
  p.inputs[key]=numberInput(layout,key,x+42,-105,130,spec[3],spec[4])
  p.placementButtons[#p.placementButtons+1]=button(layout,"+",x+188,-105,28,function()nudge(key,1)end)
 end
 p.center=button(layout,"Center horizontally",18,-148,230,function()E.FlushPlacementInputs();target().x=0;change()end)
 p.bottom=button(layout,"Align to bottom",280,-148,218,function()E.FlushPlacementInputs();target().y=0;change()end)
 p.flip=checkbox(layout,"Mirror crest",18,-193,180,function(v)target().flip=v;change()end)
 p.reset=button(layout,"Reset placement",280,-196,218,function()discardInputs();local c=target();c.size=100;c.x=E.DefaultCrestX(E.editorSet,E.editorSide);c.y=0;change()end)
 for _,b in ipairs({p.center,p.bottom,p.reset})do p.placementButtons[#p.placementButtons+1]=b end
 label(layout,"Resets size and position only.",280,-226,218)
 label(layout,"Drag a shown crest's outline in-game to move it.",18,-258,488)
 p.inputNotice=label(layout,"Use +/- to nudge by 1. Hold Shift for 10.",18,-280,488)
 local behavior=p.behavior
 p.motion=checkbox(behavior,"Enable animation and effects",18,-3,420,function(v)target().effects=v;change()end)
 label(behavior,"Includes the crest's floating motion and all its spell effects.\nTurn off to keep the artwork still and hide its effects.",50,-42,448):SetHeight(40)
 p.effectSummary=label(behavior,"",18,-106,488,"GameFontNormal")
 p.responses=label(behavior,"",18,-135,488);p.responses:SetHeight(72);p.responses:SetMaxLines(4)
 p.resource=button(behavior,"",18,-103,230,function()
  if MenuUtil and MenuUtil.CreateContextMenu then local c=target();MenuUtil.CreateContextMenu(p.resource,function(_,root)
   for _,r in ipairs(E.ResourceKinds)do local key=r[1];root:CreateRadio(r[2],function()return c.resource==key end,function()if not InCombatLockdown()and target()==c then c.resource=key;change()end end)end
  end)end
 end)
 p.meter=checkbox(behavior,"Show meter",280,-103,180,function(v)target().showMeter=v;change()end)
 p.resourceHelp=label(behavior,"",18,-148,488);p.resourceHelp:SetHeight(44)
 p.openEffects=button(behavior,"Effect library",18,-214,152,function()E.EffectLibrary.Open()end)
 p.exportBake=button(behavior,"Copy crest bake",182,-214,152,function()E.ShowCrestBakeExport()end)
 p.report=button(behavior,"Trigger report",346,-214,152,function()E.PrintBoundStatus()end)
 p.studioHint=label(behavior,"",18,-260,488);p.studioHint:SetHeight(32)
 local settings=p.settings
 label(settings,"Game interface",20,-18,744,"GameFontNormalLarge")
 p.hide=checkbox(settings,"Hide Blizzard endcaps",20,-52,700,function(v)E.draft.hideBlizzard=v;change()end)
 p.hideCooldown=checkbox(settings,"Hide Cooldown Manager (keep tracking active)",20,-94,700,function(v)E.draft.hideCooldownManager=v;change()end)
 p.cooldownHelp=label(settings,"Buff/proc effects that use Cooldown Manager require it to be enabled in WoW settings, with the buff tracked and its viewer set to Always. This option hides the display without disabling tracking. CDM is revealed in Edit Mode and its settings.",52,-134,716);p.cooldownHelp:SetHeight(58)
 label(settings,"Resource visibility",20,-215,744,"GameFontNormal")
 p.class=checkbox(settings,"Show resource crests only on Mages",20,-242,700,function(v)E.draft.classOnly=v;change()end)
 label(settings,"Other classes can preview resources while editing. Uncheck to show them in-game, too.",52,-282,716)
 label(settings,"Developer tools",20,-328,744,"GameFontNormal")
 p.developer=checkbox(settings,"Developer mode",20,-353,700,function(v)E.SetDeveloperMode(v)end)
 label(settings,"Session only. Preview any class and open the effect library from a crest's Behavior tab.",52,-394,716)
 p.footer=box(p,18,-580,804,40)
 p.pending=label(p.footer,"",12,-12,370)
 p.cancel=button(p.footer,"Cancel",514,-7,112,function()E.CancelEffectStudio();p:Hide()end)
 p.save=button(p.footer,"Save all changes",638,-7,154,function()E.SaveEffectStudio()end)
 p:SetScript("OnHide",function()
  discardInputs();if E.EffectLibrary then E.EffectLibrary.Close()end;if E.bakeExport then E.bakeExport:Hide()end;E.StopBoundTests();E.ClearAuthoringClass();E.Cancel();E.Apply()
 end)
 tinsert(UISpecialFrames,"EpicastOptions");p:Hide();return p
end
function E.OpenOptions()
 if not E.ready or InCombatLockdown()then return end
 local p=E.panel or create();E.Begin()
 if E.setupPending then E.editorSet="spells";E.editorSide=nil;E.optionsPage="crests";E.crestPage="placement"end
 E.setupPending=false;p:Show();E.RefreshOptions();E.Apply()
end
