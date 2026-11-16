local addonName,E=...
E.instances={spells={},resources={}};E.editorSet="spells";E.editorSide=nil
function E.GetEntry(group,key,class)
 return E.instances[group][group=="spells"and((class or E.ActiveClass())..":"..key)or key]
end
function E.Message(text)print("|cffb59cffEpicast:|r "..text)end
local queued=false
function E.Schedule()
 if not E.ready or queued then return end;queued=true
 C_Timer.After(0,function()queued=false;if InCombatLockdown()then E.pending=true else E.Apply()end end)
end
local native={};local settingAlpha=false
function E.UpdateBlizzardVisibility()
 if InCombatLockdown()then E.pending=true;return end
 local root=MainActionBar and MainActionBar.EndCaps
 local hide=E.Config().hideBlizzard
 for _,key in ipairs({"LeftEndCap","RightEndCap"})do
  local texture=root and root[key]and root[key].Texture
  if texture and not native[texture]then
   local alpha=texture:GetAlpha();if issecretvalue and issecretvalue(alpha)then alpha=1 end
   native[texture]={alpha=alpha,hidden=false}
   hooksecurefunc(texture,"SetAlpha",function(t,alpha)
    if settingAlpha or(issecretvalue and issecretvalue(alpha))then return end
    native[t].alpha=alpha;if native[t].hidden then E.Schedule()end
   end)
  end
 end
 for texture,state in pairs(native)do
  local belongs=root and((root.LeftEndCap and root.LeftEndCap.Texture==texture)or(root.RightEndCap and root.RightEndCap.Texture==texture))
  local wanted=hide and belongs
  if wanted or state.hidden then settingAlpha=true;texture:SetAlpha(wanted and 0 or state.alpha);settingAlpha=false end
  state.hidden=wanted
 end
end
local function editing()return E.panel and E.panel:IsShown()and E.draft and not InCombatLockdown()end
local function dragging()return editing()and E.CanDragCrests()end
local function create(setKey,side,class)
 local frame=CreateFrame("Frame",nil,UIParent);frame:SetFrameStrata("BACKGROUND");frame:SetFrameLevel(10);frame:Hide()
 local entry={frame=frame,side=side,setKey=setKey,class=class,alpha=1};entry.art=frame:CreateTexture(nil,"ARTWORK");entry.art:SetAlpha(0)
 local handle=CreateFrame("Button",nil,frame,"BackdropTemplate");entry.handle=handle;handle:SetAllPoints();handle:SetFrameStrata("DIALOG");handle:SetFrameLevel(80)
 handle:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});handle:SetBackdropBorderColor(.6,.4,1,.7);handle:EnableMouse(true);handle:RegisterForDrag("LeftButton");handle:Hide()
 handle:SetScript("OnMouseDown",function()if dragging()then E.SelectCrest(setKey,side)end end)
 handle:SetScript("OnDragStart",function()
  if not dragging()then return end
  local x,y=GetCursorPosition();local s=E.GetSide(E.draft,setKey,side);local ox,oy=s.x,s.y
  handle:SetScript("OnUpdate",function()
   if not dragging()then handle:SetScript("OnUpdate",nil);return end
   local nx,ny=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
   s.x=E.Number(ox+(nx-x)/scale,0,-8000,8000);s.y=E.Number(oy+(ny-y)/scale,0,-2000,3000)
   E.Place(entry,s);E.UpdateSaveButton()
  end)
 end)
 handle:SetScript("OnDragStop",function()handle:SetScript("OnUpdate",nil);if editing()then E.RefreshOptions()end end)
 return entry
end
function E.Place(entry,s)
 if not entry.config then return end
 local f=entry.frame;f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"BOTTOM",s.x,f:GetHeight()/2+s.y)
end
function E.Apply()
 if not E.ready then return end;if InCombatLockdown()then E.pending=true;return end
 E.ApplyCooldownVisibility()
 local db=E.Config()
 for _,entries in pairs(E.instances)do for _,entry in pairs(entries)do entry.current=false end end
 for _,setKey in ipairs({"spells","resources"})do
  local allowed=E.SetAllowed(db,setKey,editing());local class=setKey=="spells"and E.ActiveClass()or nil
  for _,choice in ipairs(E.CrestChoices(setKey))do
   local side=choice[1];local poolKey=class and(class..":"..side)or side
   local entry=E.instances[setKey][poolKey];if not entry then entry=create(setKey,side,class);E.instances[setKey][poolKey]=entry end
   local source=E.GetSide(db,setKey,side);local c=source and E.Copy(source)
   entry.config=c;entry.current=true
   if c and E.IsCrestEnabled(db,setKey,side)and allowed then
    local w,h,cx,cy=E.GetCapGeometry(c,c.flip);entry.frame:SetSize(w,h);entry.art:SetSize(225*c.size/100,225*c.size/100);entry.art:ClearAllPoints();entry.art:SetPoint("CENTER",entry.frame,"CENTER",-cx,-cy)
    entry.frame:Show();E.UpdateEffects(entry,c);E.UpdateResource(entry,c)
   else
    for _,fx in ipairs(entry.addedEffectSlots or{})do fx.nativeWanted=false end
    E.StopEffects(entry);entry.frame:Hide()
   end
   entry.handle:SetShown(c~=nil and dragging()and E.IsCrestEnabled(db,setKey,side)and allowed);if not dragging()then entry.handle:SetScript("OnUpdate",nil)end
   if c then E.Place(entry,c)end
  end
 end
 for _,entries in pairs(E.instances)do for _,entry in pairs(entries)do if not entry.current then
  entry.config=nil;for _,fx in ipairs(entry.addedEffectSlots or{})do fx.nativeWanted=false end
  E.StopEffects(entry);entry.frame:Hide();entry.handle:Hide();entry.handle:SetScript("OnUpdate",nil)
 end end end
 E.UpdateBlizzardVisibility();E.pending=false
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED","PLAYER_SPECIALIZATION_CHANGED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,name)
 if event=="ADDON_LOADED"and name==addonName then
  if type(EpicastDB)=="table"and type(EpicastDB.version)=="number"and EpicastDB.version>E.schemaVersion then E.Message("Saved settings are from a newer Epicast. This build is inactive.");return end
  EpicastDB=E.Normalize(EpicastDB);E.ready=true;E.Apply()
  local bank=E.ClassBank(EpicastDB)
  if bank and not bank.configured then E.setupPending=true;C_Timer.After(0,function()if E.setupPending then E.OpenOptions()end end)end
 elseif E.ready then
  if event=="PLAYER_REGEN_DISABLED"then for _,entries in pairs(E.instances)do for _,entry in pairs(entries)do entry.handle:Hide();entry.handle:SetScript("OnUpdate",nil)end end
  else E.Schedule();if E.setupPending then E.OpenOptions()end end
  if E.panel and E.panel:IsShown()then E.RefreshOptions()end
 end
end)
SLASH_EPICAST1="/epicast";SLASH_EPICAST2="/epic"
SlashCmdList.EPICAST=function(text)
 if not E.ready then return end
 if (text or""):lower():match("^%s*triggers%s*$")then E.PrintBoundStatus();return end
 if (text or""):lower():match("^%s*bake%s*$")then E.ShowCrestBakeExport();return end
 if (text or""):lower():match("^dev")then E.SetDeveloperMode(not E.devMode);E.Message("Developer mode "..(E.devMode and"on"or"off"))end
 E.OpenOptions()
end
