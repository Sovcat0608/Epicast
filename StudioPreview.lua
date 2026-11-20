local _,E=...
local queued=false
function E.ScheduleStudioPreview()
 if queued then return end;queued=true
 C_Timer.After(0,function()queued=false;E.RefreshStudioPreview()end)
end
function E.CreateStudioPreview(stage)
 -- The scroll viewport contains the composition without changing native camera geometry.
 local viewport=CreateFrame("ScrollFrame",nil,stage)
 viewport:SetAllPoints(stage);viewport:EnableMouse(false)
 local canvas=CreateFrame("Frame",nil,viewport)
 canvas:SetSize(stage:GetSize());canvas:SetPoint("TOPLEFT",viewport,"TOPLEFT",0,0)
 viewport:SetScrollChild(canvas)
 local frame=CreateFrame("Frame",nil,canvas);frame:Hide()
 local entry={frame=frame,canvas=canvas,preview=true,alpha=1}
 entry.art=frame:CreateTexture(nil,"ARTWORK");entry.art:SetAlpha(0)
 return entry
end
function E.HideStudioPreview()
 local p=E.EffectLibrary.window;local entry=p and p.crestPreview
 if entry then
  for _,fx in ipairs(entry.addedEffectSlots or{})do fx.nativeWanted=false;fx.previewBound=nil;E.ConfigureBoundEffect(fx,nil)end
  E.StopEffects(entry);entry.frame:Hide()
 end
end
function E.RefreshStudioPreview()
 local p=E.EffectLibrary.window
 if not p or not p:IsShown()or p.tab~="config"then E.HideStudioPreview();return end
 if InCombatLockdown()then return end
 local source,side,group=E.GetEffectLibraryTarget();if not source then E.HideStudioPreview();return end
 local entry=p.crestPreview;local c=E.Copy(source)
 local identity=E.GetCrestBakeKey(c)
 if entry.identity~=identity then E.HideStudioPreview();entry.identity=identity end
 entry.side=side;entry.setKey=group;entry.config=c
 entry.placementLayerID,entry.pendingPlacement=p.layerControls.PreviewPlacement(source)
 local live=E.GetEntry(group,side)
 entry.artworkPhase=nil
 if live and live.frame:IsVisible() and E.GetCrestBakeKey(live.config)==identity then
  entry.artworkPhase=E.GetArtworkPhase(live.artworkLayers and live.artworkLayers.artwork)
 end
 local w,h,cx,cy=E.GetCapGeometry(c,c.flip)
 local stage=p.crestStage
 local scale
 if p.previewActualSize then
  local gameFrame=live and live.frame or UIParent
  scale=gameFrame:GetEffectiveScale()/stage:GetEffectiveScale()
 else
  scale=math.min((stage:GetWidth()-50)/math.max(w,1),(stage:GetHeight()-40)/math.max(h,1))
 end
 entry.canvas:SetSize(stage:GetSize())
 entry.frame:SetSize(w,h);entry.frame:SetScale(scale*(p.previewZoom or 1));entry.frame:ClearAllPoints();entry.frame:SetPoint("CENTER",entry.canvas,"CENTER",0,0)
 local artWidth=225*c.size/100;entry.art:SetSize(artWidth,artWidth);entry.art:ClearAllPoints();entry.art:SetPoint("CENTER",entry.frame,"CENTER",-cx,-cy)
 entry.frame:Show();E.UpdateEffects(entry,c);E.UpdateResource(entry,c)
end
