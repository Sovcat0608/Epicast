local _,E=...
local V=E.EffectLibrary
local WIDTH,HEIGHT=1220,790
local MAPPING_WIDTH=328
local function createWindow()
 local U=E.StudioUI
 local p=U.Box(UIParent,0,0,WIDTH,HEIGHT,"EpicastEffectStudio");tinsert(UISpecialFrames,"EpicastEffectStudio")
 p:ClearAllPoints();p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetFrameLevel(100);p:EnableMouse(true);p:SetMovable(true);p:SetClampedToScreen(true);p:RegisterForDrag("LeftButton")
 p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing);p:Hide()
 U.Label(p,"EPICAST · EFFECT STUDIO",16,-16,355,U.gold,"GameFontNormalLarge")
 p.authorClass=U.Button(p,"Build class",386,-11,240,function(self)if E.FlushStudioInputs()then E.OpenAuthoringClassMenu(self)end end)
 p.crest=U.Button(p,"Select crest",638,-11,350,function(self)if E.FlushStudioInputs()then E.OpenCrestMenu(self)end end)
 p.close=U.Button(p,"Close",1104,-11,100,function()if E.FlushStudioInputs()then p:Hide()end end)
 p.close:ClearAllPoints();p.close:SetPoint("TOPRIGHT",p,"TOPRIGHT",-16,-11)
 p.pages={};p.tabs={};p.tab="library";p.previewZoom=1
 for _,key in ipairs({"library","config"})do local page=CreateFrame("Frame",nil,p);page:SetPoint("TOPLEFT",16,-96);page:SetSize(1188,618);p.pages[key]=page end
 function p.SelectTab(key)
  if InCombatLockdown()or not E.FlushStudioInputs()then return end
  if key=="library" and p.layerControls then p.layerControls.EndQuickBind();p.layerControls.spells.mappingID=nil end
  E.StopBoundTests();p.tab=key
  if key=="config"then if p.preview then p.preview:Clear()end else E.HideStudioPreview();if p.PlaySelected then p.PlaySelected(true)end end
  p.RefreshTarget()
 end
 p.tabs.library=U.Tab(p,"Effect Library",nil,16,-59,function()p.SelectTab("library")end)
 p.tabs.config=U.Tab(p,"Artwork Config",p.tabs.library,0,0,function()p.SelectTab("config")end)
 local config=E.CreateStudioConfig(p,p.pages.config);config.crest=p.crest
 local library=p.pages.library;local browse=U.Box(library,0,0,330,618)
 U.Label(browse,"FIND A GAME EFFECT",12,-13,300,U.gold,"GameFontNormal")
 p.search=U.Input(browse,17,-43,299);p.search:SetMaxLetters(150)
 U.Label(browse,"Search name, path words or FileDataID",12,-74,305)
 local rows,matches,page,selected={},V.Search(""),1,nil;p.rows=rows
 local display=U.Box(library,342,0,846,618)
 local title=U.Label(display,"Select an effect",14,-14,818,U.gold,"GameFontNormalLarge");title:SetMaxLines(1)
 local path=U.Label(display,"",14,-43,818);path:SetMaxLines(2)
 local stage=U.Box(display,14,-80,818,350);p.catalogStage=stage
 local status=U.Label(display,"",14,-443,810)
 local count=U.Label(browse,"",68,-582,194)
 local previous,nextPage,render,play,filter
 previous=U.Button(browse,"<",10,-574,46,function()page=page-1;render()end)
 nextPage=U.Button(browse,">",274,-574,46,function()page=page+1;render()end)
 local function addEnabled()local c=E.GetEffectLibraryTarget();return c and not InCombatLockdown()and selected and p.preview and p.preview:CanAdd(selected)and #E.GetAddedEffects(c)<E.AddedEffectLimit end
 local segmentSummary=U.Label(display,"",14,-514,818)
 p.animation=U.Input(display,716,-474,112);p.animation:SetMaxLetters(5)
 U.Label(display,"Animation ID",616,-481,100)
 p.add=U.Button(display,"Add effect layer",602,-574,230,function()
  if not addEnabled()or not config.Flush()then return end
  local c=E.GetEffectLibraryTarget();local preview=p.preview
  -- New layers are static. Spell assignment happens in Config.
  E.EditStudioState(c)
  local index=E.AddLibraryEffect(c,{fileID=selected.id,name=selected.name,animation=preview.animation,
   scale=preview.baseScale*2^preview.zoom,originX=preview.x,originY=preview.y,originZ=preview.z,azimuth=preview.angle,elevation=preview.elevation,desaturation=selected.preset and selected.preset.desaturation or 0})
  if index then
   config.EndQuickBind();config.filter="static";config.tab="placement"
   local id=E.EffectLayerID(E.GetAddedEffects(c)[index],index)
   E.PreviewLibraryChange();p.SelectTab("config");config.Select(id)
  end
 end)
 local destination=U.Label(display,"",14,-580,567);destination:SetMaxLines(2)
 local pause
 local function statusChanged(message,ready,paused)
  status:SetText(message);if pause then pause:SetText(paused and"Resume"or"Pause")end
  if selected and not V.IsAvailable(selected.id)and filter then filter()end
  p.add:SetEnabled(addEnabled()and true or false)
 end
 local ok,preview=pcall(V.CreatePreview,stage,statusChanged);if ok then p.preview=preview end
 if not p.preview then status:SetText("Native model preview is unavailable in this client.")end
 render=function()
  page=math.max(1,math.min(page,math.max(1,math.ceil(#matches/10))))
  for i,b in ipairs(rows)do local item=matches[(page-1)*10+i];b.entry=item;b:SetShown(item~=nil)
   if item then b.title:SetText(item.name);b.detail:SetText("FileDataID "..item.id);U.RowSelected(b,selected and selected.id==item.id);b:SetEnabled(not InCombatLockdown())end
  end
  count:SetText(#matches.." effects · "..page.."/"..math.max(1,math.ceil(#matches/10)));previous:SetEnabled(page>1);nextPage:SetEnabled(page*10<#matches)
 end
 play=function(keep)
  if not selected or not p.preview or p.tab~="library"then return end
  local n=tonumber(p.animation:GetText())or(selected.preset and selected.preset.animation or 0);n=math.floor(math.max(0,math.min(65535,n)))
  p.animation:SetText(tostring(n));p.preview:Load(selected,n,keep)
 end;p.PlaySelected=play
 p.segmentButtons={}
 for i,v in ipairs({{"Stand / intro",0},{"Hold",158},{"End",159}})do local id=v[2]
  p.segmentButtons[id]=U.Button(display,v[1],14+(i-1)*140,-538,128,function()if selected and E.AnimationAvailable(selected.id,id)then p.animation:SetText(tostring(id));play(true)end end)
 end
 local function choose(item)
  selected=item;p.search:ClearFocus();title:SetText(item.name);path:SetText(item.path);p.animation:SetText(tostring(item.preset and item.preset.animation or 0))
  for i,v in ipairs(matches)do if v.id==item.id then page=math.floor((i-1)/10)+1;break end end
  segmentSummary:SetText(E.AnimationSummary(item.id));for id,b in pairs(p.segmentButtons)do b:SetEnabled(E.AnimationAvailable(item.id,id)and not InCombatLockdown())end
  render();play(false)
 end
 for i=1,10 do rows[i]=U.Row(browse,8,-107-(i-1)*46,314,function(b)choose(b.entry)end)end
 filter=function()
  matches=V.Search(p.search:GetText());page=1
  local found=false;for _,item in ipairs(matches)do if selected and item.id==selected.id then found=true;break end end
  if not found then selected=nil;if p.preview then p.preview:Clear()end;title:SetText(#matches==0 and"No matching Forever effects"or"Select an effect to preview");path:SetText("");segmentSummary:SetText("");for _,b in pairs(p.segmentButtons)do b:SetEnabled(false)end end
  render();p.add:SetEnabled(addEnabled()and true or false)
 end
 p.search:SetScript("OnTextChanged",filter);p.search:SetScript("OnEnterPressed",function()local item=matches[(page-1)*10+1];if item then choose(item)end end)
 browse:EnableMouseWheel(true);browse:SetScript("OnMouseWheel",function(_,d)page=page-d;render()end)
 U.Button(display,"Replay",14,-473,84,function()play(true)end)
 pause=U.Button(display,"Pause",108,-473,84,function()if p.preview then p.preview:TogglePause()end end)
 U.Button(display,"Rotate",202,-473,84,function()if p.preview then p.preview:SetView(p.preview.zoom,(p.preview.angle+45)%360)end end)
 U.Button(display,"Fit",296,-473,60,function()if p.preview then p.preview:Fit()end end)
 local function zoom(delta)if p.preview and p.preview.state=="ready"then p.preview:SetView(math.max(-8,math.min(8,p.preview.zoom+delta/2)),p.preview.angle)end end
 U.Button(display,"-",366,-473,34,function()zoom(-1)end);U.Button(display,"+",408,-473,34,function()zoom(1)end)
 local light=false;U.Button(display,"Background",452,-473,112,function()light=not light;stage:SetBackdropColor(light and .45 or .035,light and .47 or .035,light and .5 or .055,1)end)
 stage:EnableMouseWheel(true);stage:SetScript("OnMouseWheel",function(_,d)zoom(d)end)
 p.animation:SetScript("OnEnterPressed",function(self)self:ClearFocus();play(true)end)
 p.addMore=U.Button(p,"Find another effect",16,-729,184,function()p.SelectTab("library")end)
 p.export=U.Button(p,"Copy crest bake",212,-729,160,function()if config.Flush()then E.ShowCrestBakeExport()end end)
 p.cancel=U.Button(p,"Discard changes",896,-729,148,function()config.EndQuickBind();config.DiscardInputs();E.CancelEffectStudio();p.RefreshTarget()end)
 p.saveAll=U.Button(p,"Save session",1056,-729,148,function()if config.Flush()then E.SaveEffectStudio();p.RefreshTarget()end end)
 p.saveAll:ClearAllPoints();p.saveAll:SetPoint("TOPRIGHT",p,"TOPRIGHT",-16,-729)
 p.cancel:ClearAllPoints();p.cancel:SetPoint("TOPRIGHT",p.saveAll,"TOPLEFT",-12,0)
 p.notice=U.Label(p,"Developer edits are session-only. Copy the crest bake to ship them in an addon update.",16,-767,1180)
 function p.RefreshTarget()
  local c,sideKey,group=E.GetEffectLibraryTarget();if not c then p:Hide();return end
  p.authorClass:SetText("Class: "..E.ClassSpecs[E.ActiveClass()].name.."  v");p.authorClass:SetEnabled(not InCombatLockdown())
  p.crest:SetText(E.SetLabels[group].." · "..E.CrestLabel(E.draft,group,sideKey).."  v");p.crest:SetEnabled(not InCombatLockdown())
  for key,f in pairs(p.pages)do f:SetShown(p.tab==key);U.SelectTab(p.tabs[key],p.tab==key)end
  destination:SetText("Destination: "..E.CrestLabel(E.draft,group,sideKey).." · "..#E.GetAddedEffects(c).."/"..E.AddedEffectLimit.." effects")
  config.Refresh()
  local width=WIDTH+(config.spells.mapping:IsShown()and MAPPING_WIDTH or 0)
  p:SetWidth(width)
  p.pages.config:SetWidth(width-32)
  p:SetScale(math.max(.25,math.min(1,(UIParent:GetWidth()-24)/width,(UIParent:GetHeight()-24)/HEIGHT)))
  p.add:SetEnabled(addEnabled()and true or false);p.saveAll:SetEnabled(E.CanSave());p.cancel:SetEnabled(not InCombatLockdown());p.export:SetEnabled(not InCombatLockdown());p.addMore:SetEnabled(not InCombatLockdown())
  p.search:SetEnabled(not InCombatLockdown());p.animation:SetEnabled(not InCombatLockdown());render();E.RefreshStudioPreview()
 end
 for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"})do p:RegisterEvent(event)end
 p:SetScript("OnEvent",function()if p:IsShown()then p.RefreshTarget()end end)
 p:SetScript("OnShow",function()if p.tab=="library"then if selected then play(true)else local item=V.Search("166009")[1];if item then choose(item)end end end end)
 p:SetScript("OnHide",function()config.EndQuickBind();config.DiscardInputs();config.spells.mappingID=nil;config.spells.input:ClearFocus();p.search:ClearFocus();p.animation:ClearFocus();if p.preview then p.preview:Clear()end;E.StopBoundTests();E.HideStudioPreview()end)
 filter();return p
end
function V.Open()
 if not E.GetEffectLibraryTarget()or InCombatLockdown()then return end
 V.window=V.window or createWindow();local p=V.window
 p:SetScale(math.max(.25,math.min(1,(UIParent:GetWidth()-24)/WIDTH,(UIParent:GetHeight()-24)/HEIGHT)));p:Show();p.RefreshTarget()
end
function V.RefreshTarget()if V.window and V.window:IsShown()then V.window.RefreshTarget()end end
function V.Close()if V.window then V.window:Hide()end end
