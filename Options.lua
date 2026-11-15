local _,E=...
local function label(parent,text,x,y,width)
 local t=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetWidth(width or 500);t:SetJustifyH("LEFT");t:SetText(text);return t
end
local function button(parent,text,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width or 140,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",function()if not InCombatLockdown()then fn()end end);return b
end
local function checkbox(parent,text,x,y,fn)
 local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",x,y);label(parent,text,x+30,y-8,240)
 b:SetScript("OnClick",function(self)if not InCombatLockdown()then fn(self:GetChecked()==true)end end);return b
end
local function change()E.Apply();E.RefreshOptions()end
function E.UpdateSaveButton()
 local enabled=not InCombatLockdown()and E.HasChanges()
 if E.panel then E.panel.save:SetEnabled(enabled)end
 local w=E.EffectLibrary and E.EffectLibrary.window;if w and w.saveAll then w.saveAll:SetEnabled(enabled)end
end
function E.GetEffectLibraryTarget()
 if not E.devMode or not E.draft or not E.panel or not E.panel:IsShown()then return end
 return E.GetSide(E.draft,E.editorSet,E.editorSide),E.editorSide,E.editorSet
end
function E.SelectCapSide(side)if not InCombatLockdown()then E.editorSide=side;E.RefreshOptions()end end
function E.PreviewLibraryChange()if E.GetEffectLibraryTarget()and not InCombatLockdown()then E.Apply();E.UpdateSaveButton()end end
function E.SaveEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();E.Commit();E.Begin();change()end
function E.CancelEffectStudio()if not E.draft or InCombatLockdown()then return end;E.StopBoundTests();E.Cancel();E.Begin();change()end
function E.DockCustomElements(studio,show)
 if not E.panel then return end;local custom=E.panel.custom
 E.customStudio=studio;E.customStudioVisible=show;custom:ClearAllPoints();custom:SetParent(studio or E.panel)
 if studio then custom:SetPoint("TOPLEFT",studio,"TOPLEFT",805,-48)else custom:SetPoint("TOPLEFT",E.panel,"TOPRIGHT",6,0)end
 custom:SetShown(E.devMode and E.panel:IsShown()and(not studio or show))
end
local function slider(parent,text,x,y,lo,hi,fn)
 label(parent,text,x,y,290)
 local control=CreateFrame("Frame",nil,parent,"MinimalSliderWithSteppersTemplate");control:SetPoint("TOPLEFT",x+2,y-24);control:SetSize(270,20)
 control:Init(lo,lo,hi,hi-lo,{[MinimalSliderWithSteppersMixin.Label.Right]=function(v)return string.format("%g",v)end})
 local s=control.Slider;s.control=control
 s:HookScript("OnValueChanged",function(_,v)if not E.refreshing and not InCombatLockdown()and E.draft then fn(math.floor(v+.5));E.Apply();E.UpdateSaveButton()end end)
 return s
end
function E.RefreshOptions()
 local p=E.panel;if not p or not E.draft then return end;E.refreshing=true
 local db=E.draft;local s=db.sets[E.editorSet];local c=E.GetSide(db,E.editorSet,E.editorSide);local unlocked=not InCombatLockdown()
 p.hide:SetChecked(db.hideBlizzard);p.class:SetChecked(db.classOnly);p.hide:SetEnabled(unlocked);p.class:SetEnabled(unlocked)
 for _,key in ipairs({"central","edge"})do
  p.active[key]:SetChecked(db.sets[key].enabled);p.active[key]:SetEnabled(unlocked);p.roles[key]:SetText(E.RoleLabels[db.sets[key].role]);p.roles[key]:SetEnabled(unlocked)
  p.tabs[key]:SetEnabled(unlocked and E.editorSet~=key)
 end
 p.swapRoles:SetEnabled(unlocked);p.left:SetEnabled(unlocked and E.editorSide~="left");p.right:SetEnabled(unlocked and E.editorSide~="right")
 p.subject:SetText(E.SetLabels[E.editorSet].." · "..E.RoleLabels[s.role].." · "..E.editorSide.." · "..E.artworkByID[c.art].name)
 p.flip:SetChecked(c.flip);p.flip:SetEnabled(unlocked);p.swapArt:SetEnabled(unlocked);p.motion:SetChecked(c.effects);p.motion:SetEnabled(unlocked)
 p.resource:SetShown(s.role=="resources");p.meter:SetShown(s.role=="resources");p.meter:SetChecked(c.showMeter);p.meter:SetEnabled(unlocked)
 for _,r in ipairs(E.ResourceKinds)do if r[1]==c.resource then p.resource:SetText("Resource: "..r[2])end end;p.resource:SetEnabled(unlocked)
 for key,control in pairs(p.sliders)do control:SetValue(s[key]);control.control:SetEnabled(unlocked and(key~="gap"or E.editorSet=="central"))end
 p.reset:SetEnabled(unlocked);p.cancel:SetEnabled(unlocked);p.openEffects:SetShown(E.devMode);p.openEffects:SetEnabled(unlocked)
 p.custom.title:SetText("Custom artwork · "..E.editorSide)
 local emission=E.GetEmissionConfig(c);for key,control in pairs(p.custom.emission)do control:SetValue(emission[key]);control.control:SetEnabled(unlocked)end
 local sigil=E.GetSigilConfig(c);p.custom.seal:SetShown(sigil~=nil)
 if sigil then for key,control in pairs(p.custom.sealSliders)do control:SetValue(sigil[key]);control.control:SetEnabled(unlocked)end end
 p.custom:SetSize(330,sigil and 480 or 175)
 E.DockCustomElements(E.customStudio,E.customStudioVisible);E.refreshing=false;E.UpdateSaveButton()
 if E.EffectLibrary then E.EffectLibrary.RefreshTarget()end
end
local function create()
 local p=CreateFrame("Frame","EpicastOptions",UIParent,"BackdropTemplate");E.panel=p;p:SetSize(610,650);p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetMovable(true);p:SetClampedToScreen(true);p:EnableMouse(true);p:RegisterForDrag("LeftButton")
 p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing)
 p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});p:SetBackdropColor(.045,.035,.075,.98);p:SetBackdropBorderColor(.5,.35,.7,.9)
 label(p,"EPICAST  ·  Arcane beta",20,-18)
 button(p,"Close",530,-10,60,function()p:Hide()end)
 p.hide=checkbox(p,"Hide Blizzard endcaps",18,-46,function(v)E.draft.hideBlizzard=v;change()end)
 p.class=checkbox(p,"Show only on Mage characters",310,-46,function(v)E.draft.classOnly=v;change()end)
 p.active={};p.roles={};p.tabs={}
 for i,key in ipairs({"central","edge"})do
  local x=18+(i-1)*292;p.active[key]=checkbox(p,E.SetLabels[key].." active",x,-86,function(v)E.draft.sets[key].enabled=v;change()end)
  p.roles[key]=button(p,"",x+32,-122,220,function()local role=E.draft.sets[key].role;E.AssignRole(E.draft,key,role=="spells"and"resources"or"spells");change()end)
  p.tabs[key]=button(p,"Edit "..E.SetLabels[key],x,-204,278,function()E.editorSet=key;E.StopBoundTests();E.Apply();E.RefreshOptions()end)
 end
 p.swapRoles=button(p,"Swap spell / resource locations",18,-160,350,function()E.SwapRoles(E.draft);E.StopBoundTests();change()end)
 label(p,"Each role can occupy only one set. Enable either set or both.",18,-190,560)
 p.left=button(p,"Left sister",18,-240,140,function()E.SelectCapSide("left")end);p.right=button(p,"Right sister",164,-240,140,function()E.SelectCapSide("right")end)
 p.swapArt=button(p,"Swap sisters",320,-240,135,function()local s=E.draft.sets[E.editorSet];s.swapped=not s.swapped;change()end)
 p.flip=checkbox(p,"Flip",470,-237,function(v)E.GetSide(E.draft,E.editorSet,E.editorSide).flip=v;change()end)
 p.subject=label(p,"",18,-278,570)
 p.sliders={}
 local specs={{"size","Set size (%)",50,200},{"gap","Central separation",0,1800},{"x","Horizontal offset / edge inset",-2000,2000},{"y","Height from screen bottom",0,1500}}
 for i,s in ipairs(specs)do local x=18+((i-1)%2)*292;local y=-310-math.floor((i-1)/2)*67
  p.sliders[s[1]]=slider(p,s[2],x,y,s[3],s[4],function(v)E.draft.sets[E.editorSet][s[1]]=v end)
 end
 p.motion=checkbox(p,"Animate artwork and effects",18,-450,function(v)E.GetSide(E.draft,E.editorSet,E.editorSide).effects=v;change()end)
 p.resource=button(p,"",310,-452,275,function()
  local c=E.GetSide(E.draft,E.editorSet,E.editorSide)
  if MenuUtil and MenuUtil.CreateContextMenu then MenuUtil.CreateContextMenu(p.resource,function(_,root)for _,r in ipairs(E.ResourceKinds)do local key=r[1];root:CreateRadio(r[2],function()return c.resource==key end,function()c.resource=key;change()end)end end)
  end
 end)
 p.meter=checkbox(p,"Show resource meter",310,-484,function(v)E.GetSide(E.draft,E.editorSet,E.editorSide).showMeter=v;change()end)
 p.reset=button(p,"Reset this set's placement",18,-495,270,function()local s=E.draft.sets[E.editorSet];for _,key in ipairs({"x","y","leftX","leftY","rightX","rightY"})do s[key]=0 end;s.size=100;s.gap=480;change()end)
 label(p,"Drag the outlined artwork to adjust each sister. Save keeps both sets.",18,-540,570)
 p.openEffects=button(p,"Open effects",18,-575,170,function()E.EffectLibrary.Open()end)
 p.save=button(p,"Save",310,-600,132,function()E.SaveEffectStudio()end);p.cancel=button(p,"Cancel",452,-600,132,function()E.CancelEffectStudio();p:Hide()end)
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
 local p=E.panel or create();E.Begin();p:SetScale(math.max(.35,math.min(1,(UIParent:GetHeight()-30)/650)));p:Show();E.RefreshOptions();E.Apply()
end
