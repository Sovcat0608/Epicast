local addonName,E=...
E.instances={central={},edge={}};E.editorSet="central";E.editorSide="left"
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
local function create(setKey,side)
 local frame=CreateFrame("Frame","Epicast_"..setKey.."_"..side,UIParent);frame:SetFrameStrata("BACKGROUND");frame:SetFrameLevel(10);frame:Hide()
 local entry={frame=frame,side=side,setKey=setKey,alpha=1};entry.art=frame:CreateTexture(nil,"ARTWORK");entry.art:SetAlpha(0)
 local handle=CreateFrame("Button",nil,frame,"BackdropTemplate");entry.handle=handle;handle:SetAllPoints();handle:SetFrameStrata("DIALOG");handle:SetFrameLevel(80)
 handle:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});handle:SetBackdropBorderColor(.6,.4,1,.7);handle:EnableMouse(true);handle:RegisterForDrag("LeftButton");handle:Hide()
 handle:SetScript("OnMouseDown",function()if editing()then E.SelectSet(setKey,side)end end)
 handle:SetScript("OnDragStart",function()
  if not editing()then return end
  local x,y=GetCursorPosition();local s=E.draft.sets[setKey];local ox,oy=s[side.."X"],s[side.."Y"]
  handle:SetScript("OnUpdate",function()
   if not editing()then handle:SetScript("OnUpdate",nil);return end
   local nx,ny=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
   s[side.."X"]=E.Number(ox+(nx-x)/scale,0,-2000,2000);s[side.."Y"]=E.Number(oy+(ny-y)/scale,0,-1500,1500)
   E.Place(entry,s);E.UpdateSaveButton()
  end)
 end)
 handle:SetScript("OnDragStop",function()handle:SetScript("OnUpdate",nil)end)
 return entry
end
function E.Place(entry,s)
 if not entry.config then return end
 local f=entry.frame;local sides=E.DisplaySides(E.Config(),entry.setKey);local x
 if entry.setKey=="central"then
  local total=s.gap*math.max(0,#sides-1)
  for _,side in ipairs(sides)do total=total+E.instances.central[side].frame:GetWidth()end
  local cursor=UIParent:GetWidth()/2+s.x-total/2
  for _,side in ipairs(sides)do local w=E.instances.central[side].frame:GetWidth();if side==entry.side then x=cursor+w/2;break end;cursor=cursor+w+s.gap end
 else
  if #sides==1 or entry.side=="middle"then x=UIParent:GetWidth()/2
  else x=entry.side=="left"and(f:GetWidth()/2+s.x)or(UIParent:GetWidth()-f:GetWidth()/2-s.x)end
 end
 if not x then return end
 x=x+s[entry.side.."X"];local y=f:GetHeight()/2+s.y+s[entry.side.."Y"]
 f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
end
function E.Apply()
 if not E.ready then return end;if InCombatLockdown()then E.pending=true;return end
 local db=E.Config()
 for _,setKey in ipairs({"central","edge"})do
  local s=db.sets[setKey];local allowed=E.SetAllowed(db,s.role,editing())
  for _,side in ipairs(E.PhysicalSides)do
   local entry=E.instances[setKey][side];if not entry then entry=create(setKey,side);E.instances[setKey][side]=entry end
   local source=E.GetSide(db,setKey,side);local c=source and E.Copy(source)
   if c then c.size=s.size*source.size/100;c.flip=source.flip~=(setKey=="edge"and E.MageArtworks[source.art]~=nil)end
   entry.config=c
   if c and s.enabled and allowed then
    local w,h,cx,cy=E.GetCapGeometry(c,c.flip);entry.frame:SetSize(w,h);entry.art:SetSize(225*c.size/100,225*c.size/100);entry.art:ClearAllPoints();entry.art:SetPoint("CENTER",entry.frame,"CENTER",-cx,-cy)
    entry.frame:Show();E.UpdateEffects(entry,c);E.UpdateResource(entry,c)
   else
    for _,fx in ipairs(entry.addedEffectSlots or{})do fx.nativeWanted=false end
    E.StopEffects(entry);entry.frame:Hide()
   end
   entry.handle:SetShown(c~=nil and editing()and s.enabled and allowed);if not editing()then entry.handle:SetScript("OnUpdate",nil)end
  end
  for _,entry in pairs(E.instances[setKey])do E.Place(entry,s)end
 end
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
 if (text or""):lower():match("^dev")then E.devMode=not E.devMode;if not E.devMode then E.ClearAuthoringClass();E.Schedule()end;E.Message("Developer mode "..(E.devMode and"on"or"off"))end
 E.OpenOptions()
end
