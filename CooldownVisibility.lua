local _,E=...
-- Cosmetic suppression only. Never Hide/Show, refresh, reparent, set a CVar,
-- or write Lua fields on Blizzard's viewers/items: their aura code must stay native.
local viewerNames={"EssentialCooldownViewer","UtilityCooldownViewer","BuffIconCooldownViewer","BuffBarCooldownViewer"}
local records=setmetatable({},{__mode="k"})
local watched=setmetatable({},{__mode="k"})
local updating=false
local properties={
 alpha={get="GetAlpha",set="SetAlpha",kind="number",target=0},
 motion={get="IsMouseMotionEnabled",set="SetMouseMotionEnabled",kind="boolean",target=false},
 click={get="IsMouseClickEnabled",set="SetMouseClickEnabled",kind="boolean",target=false},
}
local function public(v)
 return not(issecretvalue and issecretvalue(v))and not(type(v)=="table"and issecrettable and issecrettable(v))
end
local function read(object,key,...)
 if not public(object)or not object then return nil end
 local ok,fn=pcall(function()return object[key]end)
 if not ok or not public(fn)or type(fn)~="function"then return nil end
 local success,value=pcall(fn,object,...)
 if success and public(value)then return value end
 return nil
end
local function beneath(frame,root)
 for _=1,16 do if frame==root then return true end;frame=read(frame,"GetParent");if not frame then return false end end
 return false
end
local function hiding(root)
 local current=false;for _,name in ipairs(viewerNames)do if _G[name]==root then current=true;break end end
 local db=E.Config and E.Config()
 return current and E.ready and db and db.hideCooldownManager==true
  and read(EditModeManagerFrame,"IsShown")~=true
  and read(CooldownViewerSettings,"IsShown")~=true
  and read(root,"IsEditing")~=true
end
local function write(frame,state,property,value)
 -- Mouse setters are protected on protected widgets. Retry after combat rather
 -- than risking a blocked action; normal unprotected CDM widgets remain usable.
 if property~=properties.alpha and InCombatLockdown()and read(frame,"IsProtected")~=false then return false end
 state.writing=true
 local ok=pcall(function()frame[property.set](frame,value)end)
 state.writing=false
 return ok
end
local function applyProperty(frame,state,property,hide)
 local current=read(frame,property.get)
 if type(current)~=property.kind then return end
 if hide then
  if not state.owned then state.restore=current;state.owned=true end
  if current~=property.target then write(frame,state,property,property.target)end
 elseif state.owned then
  if current~=property.target or write(frame,state,property,state.restore)then state.owned=false;state.restore=nil end
 end
end
local function track(frame,root,key)
 local property=properties[key]
 if type(read(frame,property.get))~=property.kind then return end
 local record=records[frame];if not record then record={};records[frame]=record end
 record.root=root
 if not record[key]then
  local state={};record[key]=state
  if hooksecurefunc then pcall(hooksecurefunc,frame,property.set,function(_,value)
   if state.writing or not public(value)or type(value)~=property.kind then return end
   if state.owned then
    -- Preserve the latest native/other-addon intent for Cancel/uncheck/Edit Mode.
    state.restore=value
    if hiding(record.root)and beneath(frame,record.root)then write(frame,state,property,property.target)
    else state.owned=false;state.restore=nil end
   end
  end)end
 end
end
local function walk(frame,root,visited,depth)
 if not frame or not public(frame)or visited[frame]or depth>8 then return end
 visited[frame]=true;track(frame,root,"motion");track(frame,root,"click")
 local ok,children=pcall(function()return {frame:GetChildren()}end)
 if ok and public(children)then for _,child in ipairs(children)do walk(child,root,visited,depth+1)end end
end
local function watchScripts(frame)
 if not frame or watched[frame]then return end
 local ok=pcall(function()
  frame:HookScript("OnShow",function()E.ApplyCooldownVisibility()end)
  frame:HookScript("OnHide",function()E.ApplyCooldownVisibility()end)
 end)
 if ok then watched[frame]=true end
end
function E.ApplyCooldownVisibility()
 if not E.ready or updating then return end;updating=true
 local db=E.Config()
 if db and db.hideCooldownManager then
  watchScripts(EditModeManagerFrame);watchScripts(CooldownViewerSettings)
  for _,name in ipairs(viewerNames)do
   local viewer=_G[name]
   if viewer and public(viewer)then
    track(viewer,viewer,"alpha");walk(viewer,viewer,{},0)
    if not watched[viewer]then
     -- A post-hook observes native pool rebuilds; it never invokes the refresh.
     if hooksecurefunc then pcall(hooksecurefunc,viewer,"RefreshLayout",function()E.ApplyCooldownVisibility()end)end
     watchScripts(viewer)
    end
   end
  end
 end
 for frame,record in pairs(records)do
  local hide=hiding(record.root)and beneath(frame,record.root)
  for key,property in pairs(properties)do if record[key]then applyProperty(frame,record[key],property,hide)end end
 end
 updating=false
end
local events=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","CVAR_UPDATE","EDIT_MODE_LAYOUTS_UPDATED","PLAYER_REGEN_ENABLED"})do events:RegisterEvent(event)end
events:SetScript("OnEvent",function(_,event,name)
 if event~="CVAR_UPDATE"or name=="cooldownViewerEnabled"then E.ApplyCooldownVisibility()end
end)
