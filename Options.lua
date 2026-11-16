local _,E=...
local function label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetWidth(width or 500);t:SetJustifyH("LEFT");t:SetText(text);return t
end
local function button(parent,text,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width or 140,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",function()if not InCombatLockdown()then fn()end end);return b
end
local function checkbox(parent,text,x,y,fn)
 local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",x,y);b.label=label(b,text,30,-8,240);b:SetScript("OnClick",function(self)if not InCombatLockdown()then fn(self:GetChecked()==true)end end);return b
end
local function target()return E.draft and E.GetSide(E.draft,E.editorSet,E.editorSide)end
local function change()E.Apply();E.RefreshOptions()end
function E.HasPendingSetup()local b=E.draft and E.ClassBank(E.draft);return b and not b.configured end
function E.CanSave()return not InCombatLockdown()and(E.HasChanges()or E.HasPendingSetup())end
function E.UpdateSaveButton()
 local enabled=E.CanSave()
 if E.panel then E.panel.save:SetEnabled(enabled);E.panel.pending:SetText(InCombatLockdown()and"Editing paused during combat"or(E.HasPendingSetup()and"Choose your crests, then Save"or(E.HasChanges()and"Unsaved changes"or"All changes saved")))end
 local w=E.EffectLibrary and E.EffectLibrary.window;if w and w.saveAll then w.saveAll:SetEnabled(enabled)end
end
function E.GetEffectLibraryTarget()
 if not E.devMode or not E.draft or not E.panel or not E.panel:IsShown()then return end
 return target(),E.editorSide,E.editorSet
end
E.editorKeys={}
local function selectionID(group)return E.ActiveClass()..":"..group end
function E.SelectCrest(group,key)
 if InCombatLockdown()or not E.draft or not E.SetLabels[group]then return end
 E.StopBoundTests();E.editorSet=group;E.editorSide=key or E.editorKeys[selectionID(group)];E.RefreshOptions()
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
function E.PreviewLibraryChange()if E.GetEffectLibraryTarget()and not InCombatLockdown()then E.Apply();E.UpdateSaveButton()end end
function E.SaveEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();local b=E.ClassBank(E.draft);if b then b.configured=true end;E.Commit();E.Begin();change()end
function E.CancelEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();E.Cancel();E.Begin();change()end
local function slider(parent,text,x,y,lo,hi,fn)
 local caption=label(parent,text,x,y,270);local control=CreateFrame("Frame",nil,parent,"MinimalSliderWithSteppersTemplate");control:SetPoint("TOPLEFT",x+2,y-24);control:SetSize(270,20)
 control:Init(lo,lo,hi,hi-lo,{[MinimalSliderWithSteppersMixin.Label.Right]=function(v)return string.format("%g",v)end})
 local s=control.Slider;s.control=control;s.label=caption
 s:HookScript("OnValueChanged",function(_,v)if not E.refreshing and not InCombatLockdown()and target()then fn(math.floor(v+.5));change()end end);return s
end
function E.RefreshOptions()
 local p=E.panel;if not p or not p:IsShown()or not E.draft then return end
 local db=E.draft;local choices=E.CrestChoices(E.editorSet);local unlocked=not InCombatLockdown()
 if not target()then E.editorSide=nil;for _,choice in ipairs(choices)do if E.IsCrestEnabled(db,E.editorSet,choice[1])then E.editorSide=choice[1];break end end;E.editorSide=E.editorSide or(choices[1]and choices[1][1])end
 local c=target();if not c then return end;E.editorKeys[selectionID(E.editorSet)]=E.editorSide;E.refreshing=true
 local title=E.CrestLabel(db,E.editorSet,E.editorSide);local class=E.ActiveClass()
 p.authorClass:SetShown(E.devMode);p.authorClass:SetText("Build class: "..E.ClassSpecs[class].name.."  v");p.authorClass:SetEnabled(unlocked)
 for key,tab in pairs(p.tabs)do tab:SetEnabled(unlocked and key~=E.editorSet);tab.selected:SetShown(key==E.editorSet)end
 for i,row in ipairs(p.crestRows)do local choice=choices[i];row:SetShown(choice~=nil);row.key=choice and choice[1]
  if choice then local config=E.GetSide(db,E.editorSet,choice[1]);row.choose:SetText((choice[1]==E.editorSide and"Editing: "or"")..E.CrestLabel(db,E.editorSet,choice[1]));row.choose:SetEnabled(unlocked)
   row.active:SetChecked(E.IsCrestEnabled(db,E.editorSet,choice[1]));row.active:SetEnabled(unlocked);row.summary:SetText(string.format("%g%%   X %g   Y %g",config.size,config.x,config.y))
  end
 end
 p.subject:SetText(title..(E.artworkByID[c.art].pending and " · artwork pending"or" · independent placement"))
 for key,control in pairs(p.sliders)do control:SetValue(c[key]);control.control:SetEnabled(unlocked)end
 p.flip:SetChecked(c.flip);p.flip:SetEnabled(unlocked);p.motion:SetChecked(c.effects);p.motion:SetEnabled(unlocked);p.reset:SetEnabled(unlocked)
 local resource=E.editorSet=="resources";p.resource:SetShown(resource);p.resource:SetEnabled(unlocked);p.resource:SetText("Resource: "..c.resource.."  v")
 p.meter:SetShown(resource);p.meter:SetChecked(c.showMeter);p.meter:SetEnabled(unlocked);p.spellHelp:SetShown(not resource);p.report:SetShown(not resource);p.report:SetEnabled(unlocked and #c.addedEffects>0)
 p.openEffects:SetShown(E.devMode);p.openEffects:SetEnabled(unlocked);p.hide:SetChecked(db.hideBlizzard);p.hide:SetEnabled(unlocked);p.class:SetChecked(db.classOnly);p.class:SetEnabled(unlocked);p.cancel:SetEnabled(unlocked)
 E.refreshing=false;E.UpdateSaveButton();if E.EffectLibrary then E.EffectLibrary.RefreshTarget()end
end
local function create()
 local p=CreateFrame("Frame","EpicastOptions",UIParent,"BackdropTemplate");E.panel=p;p:SetSize(640,714);p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetMovable(true);p:SetClampedToScreen(true);p:EnableMouse(true);p:RegisterForDrag("LeftButton")
 p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing);p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});p:SetBackdropColor(.045,.035,.075,.98);p:SetBackdropBorderColor(.5,.35,.7,.9)
 label(p,"EPICAST · Crests",20,-18);p.authorClass=button(p,"",218,-12,314,function()E.OpenAuthoringClassMenu(p.authorClass)end);button(p,"Close",560,-10,60,function()p:Hide()end);p.tabs={}
 for i,key in ipairs({"spells","resources"})do local tab=button(p,E.SetLabels[key],18+(i-1)*306,-52,298,function()E.SelectCrest(key)end);p.tabs[key]=tab;tab.selected=tab:CreateTexture(nil,"OVERLAY");tab.selected:SetColorTexture(.7,.45,1,1);tab.selected:SetPoint("BOTTOMLEFT",0,-4);tab.selected:SetSize(298,3)end
 label(p,"Show any crests. Select a name to change only that crest.",18,-88,604);p.crestRows={}
 for i=1,3 do local row=CreateFrame("Frame",nil,p);p.crestRows[i]=row;row:SetPoint("TOPLEFT",18,-116-(i-1)*44);row:SetSize(604,40)
  row.choose=button(row,"",0,0,205,function()if row.key then E.SelectCrest(E.editorSet,row.key)end end)
  row.active=checkbox(row,"Show",216,3,function(value)if E.draft and row.key then E.StopBoundTests();E.SetCrestEnabled(E.draft,E.editorSet,row.key,value);change()end end);row.active.label:SetWidth(65);row.summary=label(row,"",320,-7,280)
 end
 p.subject=label(p,"",18,-268,604);p.sliders={}
 for _,s in ipairs({{"size","Crest size (%)",25,400,18,-307},{"x","Horizontal position",-8000,8000,324,-307},{"y","Height from bottom",-2000,3000,18,-379}})do p.sliders[s[1]]=slider(p,s[2],s[5],s[6],s[3],s[4],function(v)target()[s[1]]=E.Number(v,0,s[3],s[4])end)end
 p.flip=checkbox(p,"Flip this crest",324,-371,function(v)target().flip=v;change()end)
 p.reset=button(p,"Reset this crest's placement",324,-414,280,function()local c=target();c.size=100;c.x=E.DefaultCrestX(E.editorSet,E.editorSide);c.y=0;change()end)
 p.motion=checkbox(p,"Animate this crest's artwork and effects",18,-451,function(v)target().effects=v;change()end);p.motion.label:SetWidth(540)
 p.resource=button(p,"",18,-500,280,function()if MenuUtil and MenuUtil.CreateContextMenu then local c=target();MenuUtil.CreateContextMenu(p.resource,function(_,root)
  for _,r in ipairs(E.ResourceKinds)do local key=r[1];root:CreateRadio(r[2],function()return c.resource==key end,function()if not InCombatLockdown()and target()==c then c.resource=key;change()end end)end
 end)end end)
 p.meter=checkbox(p,"Show resource meter",324,-497,function(v)target().showMeter=v;change()end);p.spellHelp=label(p,"Position and size belong to the selected crest.",18,-505,420)
 p.report=button(p,"Trigger report",466,-499,148,function()E.PrintBoundStatus()end);p.openEffects=button(p,"Edit this crest's effects",18,-550,240,function()E.EffectLibrary.Open()end)
 label(p,"Drag a visible crest's outline to move it.",278,-558,340)
 p.hide=checkbox(p,"Hide Blizzard endcaps",18,-604,function(v)E.draft.hideBlizzard=v;change()end);p.class=checkbox(p,"Restrict resource art to Mages",324,-604,function(v)E.draft.classOnly=v;change()end)
 label(p,"Class preview ends on Close. Save includes all crests; Cancel discards previews.",18,-643,604);p.pending=label(p,"",18,-678,290)
 p.save=button(p,"Save",324,-668,136,function()E.SaveEffectStudio()end);p.cancel=button(p,"Cancel",472,-668,136,function()E.CancelEffectStudio();p:Hide()end)
 p:SetScript("OnHide",function()if E.EffectLibrary then E.EffectLibrary.Close()end;E.StopBoundTests();E.ClearAuthoringClass();E.Cancel();E.Apply()end);tinsert(UISpecialFrames,"EpicastOptions");p:Hide();return p
end
function E.OpenOptions()
 if not E.ready or InCombatLockdown()then return end
 local p=E.panel or create();E.Begin();if E.setupPending then E.editorSet="spells";E.editorSide=nil end
 E.setupPending=false;p:SetScale(math.max(.35,math.min(1,(UIParent:GetHeight()-30)/714)));p:Show();E.RefreshOptions();E.Apply()
end
