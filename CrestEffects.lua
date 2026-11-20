local _,E=...
-- Crest definitions belong to the addon. Neither old saves nor player profiles
-- may override them. Developer edits live only in RAM while the editor is open.
local baked={}
function E.GetCrestBakeKey(c)return E.CrestOwners[c]end
local function upgradeArtwork(studio)
 for id,bindings in pairs(studio.artworkBindings or {})do
  if bindings[1] and bindings[1].kind then
   local grouped,bySpell={},{}
   for _,binding in ipairs(bindings)do
    local key=binding.spell:lower()
    local link=bySpell[key]
    if not link then
     link={spell=binding.spell,mappings={}};bySpell[key]=link;grouped[#grouped+1]=link
    end
    local kinds=binding.kind=="channel" and {"cast","channel"} or {"success"}
    for _,kind in ipairs(kinds)do link.mappings[#link.mappings+1]={state=binding.kind,kind=kind}end
   end
   studio.artworkBindings[id]=grouped
  end
 end
end
local function definition(c)
 local key=E.GetCrestBakeKey(c);if not key then return{}end
 if not baked[key]then
  local data=E.CrestBakes[key];local rows=data and(data.effects or data)
  if not rows then
   if c.role=="resources"then local glow=E.Copy(E.AddedEffectDefaults.arcaneScroll[1]);glow.trailOpacity=35;rows={glow}
   else rows=E.AddedEffectDefaults[c.art]or{}end
  end
  local result={}
  for i=1,math.min(#rows,E.AddedEffectLimit)do
   local r=E.NormalizeAddedEffect(rows[i])
   if r then
    if c.role=="resources"then r.behavior="static";r.binding=nil;r.bindings=nil end
    if key=="MAGE:arcane"then
     for _,b in ipairs(r.bindings or {r.binding})do
      local id=tonumber(b.spell)
      if(b.kind=="proc"or b.kind=="buff")and(id==400588 or id==400589 or b.spell:lower()=="missile barrage")then b.kind="buff";if id then b.spell="400589"end end
     end
    end
    result[#result+1]=r
   end
  end
  if data and data.studio then result.studio=E.Copy(data.studio);upgradeArtwork(result.studio)end
  baked[key]=result
 end
 return baked[key]
end
local function authoring()return E.devMode and E.draft and E.authorDraft and E.panel and E.panel:IsShown()end
function E.GetAddedEffects(c)
 local key=E.GetCrestBakeKey(c)
 return authoring()and E.authorDraft[key]or definition(c)
end
function E.EditAddedEffects(c)
 local key=E.GetCrestBakeKey(c)
 assert(authoring()and key,"Effect editing requires an open developer session")
 if not E.authorDraft[key]then E.authorDraft[key]=E.Copy(definition(c))end
 return E.authorDraft[key]
end
function E.AuthorHasChanges(equal)
 local draft,session=E.authorDraft or{},E.authorSession or{}
 for key,rows in pairs(draft)do if not equal(rows,session[key]or baked[key])then return true end end
 for key,rows in pairs(session)do if not equal(draft[key]or baked[key],rows)then return true end end
 return false
end

-- JSON is data, not executable Lua. Export only the selected crest's layers.
local function quote(s)
 return '"'..s:gsub('[%z\1-\31\\"]',function(c)
  if c=='"'then return '\\"'elseif c=='\\'then return '\\\\'end
  return string.format('\\u%04x',string.byte(c))
 end)..'"'
end
local function json(v,array)
 if type(v)=="string"then return quote(v)end
 if type(v)=="number"then return string.format("%.17g",v)end
 if type(v)~="table"then return tostring(v)end
 local parts={}
 if array or #v>0 then for _,row in ipairs(v)do parts[#parts+1]=json(row)end;return'['..table.concat(parts,',')..']'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do parts[#parts+1]=quote(k)..':'..json(v[k],k=="order"or k=="spells"or k=="mappings")end
 return'{'..table.concat(parts,',')..'}'
end
function E.ExportCrestBake(c)
 if not authoring()or not E.GetCrestBakeKey(c)then return end
 local rows,hasMultiple={},false
 for _,row in ipairs(E.GetAddedEffects(c))do
  local normalized=E.NormalizeAddedEffect(row)
  rows[#rows+1]=normalized;hasMultiple=hasMultiple or normalized.bindings~=nil
 end
 local studio=E.GetAddedEffects(c).studio
 local version=studio and studio.artworkBindings and 5 or hasMultiple and 3 or studio and 2 or 1
 return'{"format":"epicast-crest-bake","version":'..version..',"crest":'..quote(E.GetCrestBakeKey(c))..',"effects":'..json(rows,true)..(studio and(',"studio":'..json(studio))or'')..'}'
end
function E.ShowCrestBakeExport()
 if InCombatLockdown()then return end
 local c=E.GetEffectLibraryTarget();local export=c and E.ExportCrestBake(c);if not export then return end
 local p=E.bakeExport
 if not p then
  p=CreateFrame("Frame","EpicastBakeExport",UIParent,"BackdropTemplate");E.bakeExport=p
  p:SetSize(690,310);p:SetPoint("CENTER");p:SetFrameStrata("FULLSCREEN_DIALOG");p:EnableMouse(true)
  p:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
  p:SetBackdropColor(.04,.035,.055,1);p:SetBackdropBorderColor(.65,.5,.2,1)
  local t=p:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");t:SetPoint("TOPLEFT",18,-18);t:SetText("Copy crest bake")
  local h=p:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");h:SetPoint("TOPLEFT",18,-48);h:SetWidth(650);h:SetJustifyH("LEFT")
  h:SetText("Press Ctrl+C to copy. Give this export to the addon builder to include in the next release.\nDeveloper edits are temporary and are lost on reload; Save only keeps them for this session.")
  local scroll=CreateFrame("ScrollFrame",nil,p,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",18,-90);scroll:SetSize(626,162)
  local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject("GameFontHighlightSmall");edit:SetWidth(620)
  scroll:SetScrollChild(edit);p.edit=edit;edit:SetScript("OnEscapePressed",function()p:Hide()end)
  local close=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");close:SetSize(110,26);close:SetPoint("BOTTOMRIGHT",-18,14);close:SetText("Close");close:SetScript("OnClick",function()p:Hide()end)
  p:SetScript("OnHide",function()edit:ClearFocus()end);tinsert(UISpecialFrames,"EpicastBakeExport")
 end
 p:Show();p.edit:SetText(export);p.edit:SetFocus();p.edit:HighlightText()
end
