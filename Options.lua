local _,E=...
local function label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetWidth(width or 500);t:SetJustifyH("LEFT");t:SetText(text);return t
end
local function button(parent,text,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width or 140,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",function()if not InCombatLockdown()then fn()end end);return b
end
local function checkbox(parent,text,x,y,fn)
 local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",x,y);b.label=label(b,text,30,-8,240)
 b:SetScript("OnClick",function(self)if not InCombatLockdown()then fn(self:GetChecked()==true)end end);return b
end
local function change()E.Apply();E.RefreshOptions()end
function E.UpdateSaveButton()
 local enabled=not InCombatLockdown()and E.HasChanges()
 if E.panel then E.panel.save:SetEnabled(enabled);E.panel.pending:SetText(InCombatLockdown()and"Editing paused during combat"or(E.HasChanges()and"Unsaved changes · both sets"or"All changes saved"))end
 local w=E.EffectLibrary and E.EffectLibrary.window;if w and w.saveAll then w.saveAll:SetEnabled(enabled)end
end
function E.GetEffectLibraryTarget()
 if not E.devMode or not E.draft or not E.panel or not E.panel:IsShown()then return end
 return E.GetSide(E.draft,E.editorSet,E.editorSide),E.editorSide,E.editorSet
end
E.editorSides={central="left",edge="left"}
function E.SelectSet(key,side)
 if InCombatLockdown()or not E.SetLabels[key]then return end
 E.editorSides[E.editorSet]=E.editorSide;E.StopBoundTests();E.editorSet=key
 E.editorSide=side or E.editorSides[key];E.editorSides[key]=E.editorSide;E.RefreshOptions()
end
function E.SelectCapSide(side)
 if not InCombatLockdown()and(side=="left"or side=="right")then E.StopBoundTests();E.editorSide=side;E.editorSides[E.editorSet]=side;E.RefreshOptions()end
end
function E.PreviewLibraryChange()if E.GetEffectLibraryTarget()and not InCombatLockdown()then E.Apply();E.UpdateSaveButton()end end
function E.SaveEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();E.Commit();E.Begin();change()end
function E.CancelEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();E.Cancel();E.Begin();change()end
function E.DockCustomElements(studio,show)
 if not E.panel then return end;local custom=E.panel.custom
 E.customStudio=studio;E.customStudioVisible=show;custom:ClearAllPoints();custom:SetParent(studio or E.panel)
 if studio then custom:SetPoint("TOPLEFT",studio,"TOPLEFT",805,-48)else custom:SetPoint("TOPLEFT",E.panel,"TOPRIGHT",6,0)end
 local c=E.draft and E.GetSide(E.draft,E.editorSet,E.editorSide)
 custom:SetShown(E.devMode and E.panel:IsShown()and c and not E.DruidArtworks[c.art]and(not studio or show))
end
local function slider(parent,text,x,y,lo,hi,fn)
 local caption=label(parent,text,x,y,270)
 local control=CreateFrame("Frame",nil,parent,"MinimalSliderWithSteppersTemplate");control:SetPoint("TOPLEFT",x+2,y-24);control:SetSize(270,20)
 control:Init(lo,lo,hi,hi-lo,{[MinimalSliderWithSteppersMixin.Label.Right]=function(v)return string.format("%g",v)end})
 local s=control.Slider;s.control=control;s.label=caption
 s:HookScript("OnValueChanged",function(_,v)if not E.refreshing and not InCombatLockdown()and E.draft then fn(math.floor(v+.5));E.Apply();E.UpdateSaveButton()end end)
 return s
end
function E.RefreshOptions()
 local p=E.panel;if not p or not E.draft then return end;E.refreshing=true
 local db=E.draft;local s=db.sets[E.editorSet];local c=E.GetSide(db,E.editorSet,E.editorSide);local unlocked=not InCombatLockdown()
 p.hide:SetChecked(db.hideBlizzard);p.class:SetChecked(db.classOnly);p.hide:SetEnabled(unlocked);p.class:SetEnabled(unlocked)
 for _,key in ipairs({"central","edge"})do
  p.pages[key]:SetShown(E.editorSet==key)
  p.active[key]:SetChecked(db.sets[key].enabled);p.active[key]:SetEnabled(unlocked);p.roles[key]:SetText("Role: "..E.RoleLabels[db.sets[key].role].."  v");p.roles[key]:SetEnabled(unlocked)
  p.tabs[key]:SetEnabled(unlocked and E.editorSet~=key);p.tabs[key].selected:SetShown(E.editorSet==key)
 end
 local page=p.pages[E.editorSet]
 for _,key in ipairs({"swapRoles","left","right","subject","flip","swapArt","motion","resource","meter","sliders","reset","openEffects"})do p[key]=page[key]end
 local other=E.editorSet=="central"and"edge"or"central"
 page.other:SetText(E.SetLabels[other]..": "..E.RoleLabels[db.sets[other].role].." · "..(db.sets[other].enabled and"enabled"or"disabled"))
 p.swapRoles:SetEnabled(unlocked);p.left:SetEnabled(unlocked and E.editorSide~="left");p.right:SetEnabled(unlocked and E.editorSide~="right")
 p.subject:SetText(E.artworkByID[c.art].name.." · "..E.editorSide)
 p.flip:SetChecked(c.flip);p.flip:SetEnabled(unlocked);p.swapArt:SetEnabled(unlocked);p.motion:SetChecked(c.effects);p.motion:SetEnabled(unlocked)
 p.resource:SetShown(s.role=="resources");p.meter:SetShown(s.role=="resources");p.meter:SetChecked(c.showMeter);p.meter:SetEnabled(unlocked)
 for _,r in ipairs(E.ResourceKinds)do if r[1]==c.resource then p.resource:SetText("Resource: "..r[2])end end;p.resource:SetEnabled(unlocked)
 for key,control in pairs(p.sliders)do control:SetValue(s[key]);control.control:SetEnabled(unlocked)end
 page.spells:SetShown(s.role=="spells");page.resourceHint:SetShown(s.role=="resources")
 local druid=E.DruidArtworks[c.art]~=nil
 page.spellIntro:SetText(druid and"Druid spellcasting · Moonwarden / Groveheart"or"Spell effects follow your casts, channels and tracked buffs.")
 page.spellHelp:SetText(druid and #E.GetAddedEffects(c)==0 and"Add spell effects in developer mode when ready."or"Missed a proc? Capture a report while the buff is active.")
 page.report:SetShown(not druid or #E.GetAddedEffects(c)>0)
 p.reset:SetEnabled(unlocked);p.cancel:SetEnabled(unlocked);p.openEffects:SetShown(E.devMode);p.openEffects:SetEnabled(unlocked)
 page.dragHint:ClearAllPoints();page.dragHint:SetPoint("TOPLEFT",E.devMode and 216 or 0,-486);page.dragHint:SetWidth(E.devMode and 376 or 592)
 p.custom.title:SetText("Custom artwork · "..E.editorSide)
 local emission=E.GetEmissionConfig(c);for key,control in pairs(p.custom.emission)do control:SetValue(emission[key]);control.control:SetEnabled(unlocked)end
 local sigil=E.GetSigilConfig(c);p.custom.seal:SetShown(sigil~=nil)
 if sigil then for key,control in pairs(p.custom.sealSliders)do control:SetValue(sigil[key]);control.control:SetEnabled(unlocked)end end
 p.custom:SetSize(330,sigil and 480 or 175)
 E.DockCustomElements(E.customStudio,E.customStudioVisible);E.refreshing=false;E.UpdateSaveButton()
 if E.EffectLibrary then E.EffectLibrary.RefreshTarget()end
end
local function create()
 local p=CreateFrame("Frame","EpicastOptions",UIParent,"BackdropTemplate");E.panel=p;p:SetSize(640,746);p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetMovable(true);p:SetClampedToScreen(true);p:EnableMouse(true);p:RegisterForDrag("LeftButton")
 p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing)
 p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});p:SetBackdropColor(.045,.035,.075,.98);p:SetBackdropBorderColor(.5,.35,.7,.9)
 label(p,"EPICAST  ·  Beta",20,-18)
 button(p,"Close",560,-10,60,function()p:Hide()end)
 p.active={};p.roles={};p.tabs={};p.pages={}
 for i,key in ipairs({"central","edge"})do
  local tab=button(p,E.SetLabels[key],18+(i-1)*306,-52,298,function()E.SelectSet(key)end);p.tabs[key]=tab
  tab.selected=tab:CreateTexture(nil,"OVERLAY");tab.selected:SetColorTexture(.7,.45,1,1);tab.selected:SetPoint("BOTTOMLEFT",0,-4);tab.selected:SetSize(298,3)
  local page=CreateFrame("Frame",nil,p);p.pages[key]=page;page:SetPoint("TOPLEFT",18,-94);page:SetSize(604,514)
  local function edit(fn)return function(...)if not InCombatLockdown()and E.draft and E.editorSet==key then fn(...);change()end end end
  local function side()return E.GetSide(E.draft,key,E.editorSide)end
  p.active[key]=checkbox(page,"Enable "..E.SetLabels[key]:lower(),0,0,edit(function(v)E.draft.sets[key].enabled=v end))
  p.roles[key]=button(page,"",306,-2,286,function()
   if E.editorSet~=key or not E.draft then return end
   if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(p.roles[key],function(_,root)
    for _,role in ipairs({"spells","resources"})do root:CreateRadio(E.RoleLabels[role],function()return E.draft and E.draft.sets[key].role==role end,edit(function()E.StopBoundTests();E.AssignRole(E.draft,key,role)end))end
   end)end
  end)
  label(page,key=="central"and"Center the pair and adjust the space between sisters."or"Place sisters at the screen edges; positive inset moves both inward.",0,-42,596)
  page.other=label(page,"",0,-65,340)
  page.swapRoles=button(page,"Swap roles between sets",366,-60,226,edit(function()E.StopBoundTests();E.SwapRoles(E.draft)end))
  label(page,"PAIR PLACEMENT",0,-110,300)
  page.reset=button(page,"Reset placement",430,-102,162,edit(function()
   local s=E.draft.sets[key];for _,field in ipairs({"x","y","leftX","leftY","rightX","rightY"})do s[field]=0 end;s.size=100;s.gap=480
  end))
  page.sliders={}
  local specs=key=="central"and{{"size","Pair size (%)",50,200,0,-142},{"gap","Separation",0,1800,306,-142},{"x","Horizontal position",-2000,2000,0,-208},{"y","Height from bottom",0,1500,306,-208}}
   or{{"size","Pair size (%)",50,200,0,-142},{"x","Inset from screen edges",-2000,2000,306,-142},{"y","Height from bottom",0,1500,0,-208}}
  for _,spec in ipairs(specs)do page.sliders[spec[1]]=slider(page,spec[2],spec[5],spec[6],spec[3],spec[4],function(v)if E.editorSet==key then E.draft.sets[key][spec[1]]=v end end)end
  label(page,"SELECTED SISTER",0,-281,220);page.subject=label(page,"",244,-281,350)
  page.left=button(page,"Left sister",0,-306,136,function()E.SelectCapSide("left")end)
  page.right=button(page,"Right sister",144,-306,136,function()E.SelectCapSide("right")end)
  page.swapArt=button(page,"Swap sisters",306,-306,152,edit(function()E.StopBoundTests();local s=E.draft.sets[key];s.swapped=not s.swapped end))
  page.flip=checkbox(page,"Flip",490,-303,edit(function(v)side().flip=v end));page.flip.label:SetWidth(65)
  page.motion=checkbox(page,"Animate this sister's artwork and effects",0,-341,edit(function(v)side().effects=v end));page.motion.label:SetWidth(540)
  page.resource=button(page,"",0,-385,280,function()
   if E.editorSet~=key or not E.draft then return end
   if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(page.resource,function(_,root)
    local c=side();for _,r in ipairs(E.ResourceKinds)do local resource=r[1];root:CreateRadio(r[2],function()return c.resource==resource end,edit(function()c.resource=resource end))end
   end)end
  end)
  page.meter=checkbox(page,"Show resource meter",306,-382,edit(function(v)side().showMeter=v end))
  page.resourceHint=label(page,"Each sister has its own resource. Artwork brightness follows its level.",0,-425,592)
  page.spells=CreateFrame("Frame",nil,page);page.spells:SetPoint("TOPLEFT",0,-382);page.spells:SetSize(592,68)
  page.spellIntro=label(page.spells,"",0,0,592)
  page.spellHelp=label(page.spells,"",0,-23,400)
  page.report=button(page.spells,"Trigger report",438,-22,154,function()E.PrintBoundStatus()end)
  page.openEffects=button(page,"Edit sister's effects",0,-478,200,function()E.EffectLibrary.Open()end)
  page.dragHint=label(page,"Drag artwork outlines to adjust each sister individually.",216,-486,376)
 end
 label(p,"SHARED SETTINGS",18,-622,300)
 p.hide=checkbox(p,"Hide Blizzard endcaps",18,-642,function(v)E.draft.hideBlizzard=v;change()end)
 p.class=checkbox(p,"Restrict Arcane artwork to Mages",324,-642,function(v)E.draft.classOnly=v;change()end)
 label(p,"Druid spellcasting artwork appears only on Druids.",18,-676,592)
 p.pending=label(p,"",18,-704,290)
 p.save=button(p,"Save both sets",324,-696,136,function()E.SaveEffectStudio()end);p.cancel=button(p,"Cancel",472,-696,136,function()E.CancelEffectStudio();p:Hide()end)
 local custom=CreateFrame("Frame",nil,p,"BackdropTemplate");p.custom=custom;custom:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});custom:SetBackdropColor(.045,.035,.075,.98)
 custom.title=label(custom,"Custom artwork",16,-16,300);custom.emission={};custom.sealSliders={}
 for i,s in ipairs(E.EmissionFields)do custom.emission[s[1]]=slider(custom,s[2],18,-45-(i-1)*60,s[3],s[4],function(v)E.SetEmission(E.GetSide(E.draft,E.editorSet,E.editorSide),s[1],v)end)end
 custom.seal=CreateFrame("Frame",nil,custom);custom.seal:SetPoint("TOPLEFT",0,-175);custom.seal:SetSize(330,310)
 for i,s in ipairs(E.SigilFields)do custom.sealSliders[s[1]]=slider(custom.seal,s[2],18,-(i-1)*58,s[3],s[4],function(v)E.SetSigil(E.GetSide(E.draft,E.editorSet,E.editorSide),s[1],v)end)end
 p:SetScript("OnHide",function()if E.EffectLibrary then E.EffectLibrary.Close()end;E.StopBoundTests();E.Cancel();E.Apply()end)
 tinsert(UISpecialFrames,"EpicastOptions");p:Hide();return p
end
function E.OpenOptions()
 if not E.ready or InCombatLockdown()then return end
 local p=E.panel or create();E.Begin();p:SetScale(math.max(.35,math.min(1,(UIParent:GetHeight()-30)/746)));p:Show();E.RefreshOptions();E.Apply()
end
