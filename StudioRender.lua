local _,E=...
function E.GetRenderedStudioRank(entry,c,id)
 local studio=E.GetAddedEffects(c).studio
 if not entry.artworkSegmentsActive and c.art=="druidRestoration"and studio and not studio.artworkBindings then
  for rank,key in ipairs(studio.order)do if key==id then return rank end end
 end
 local layer=E.FindStudioLayer(c,id);return layer and layer.rank
end
function E.ApplyStudioArtwork(entry,c)
 local s=entry.mageReboot and entry.mageReboot.enabled and entry.mageReboot or entry.druidSister
 entry.artworkLayers={}
 if not s or not s.enabled then
  if E.HideRestorationSegments then E.HideRestorationSegments(entry)end
  return
 end
 entry.artworkLayers.artwork=s
 if E.ApplyRestorationSegments and E.ApplyRestorationSegments(entry,c,s)then return end
 local studio=E.GetAddedEffects(c).studio
 local state=studio or E.GetStudioState(c);local settings=state.artwork.artwork
 if settings then
  local pending=entry.placementLayerID=="artwork"and entry.pendingPlacement
  local opacity=pending and pending.trailOpacity or settings.opacity
  s.host:SetAlpha(settings.enabled==false and 0 or entry.alpha*opacity/100)
 end
 if studio then
  local rank=E.GetRenderedStudioRank(entry,c,"artwork");if rank then s.host:SetFrameLevel(entry.frame:GetFrameLevel()+rank*2)end
 end
end
function E.GetArtworkPhase(artwork,now)
 if artwork and artwork.animate and artwork.startedAt then
  local nativeElapsed=artwork.hover.GetElapsed and artwork.hover:GetElapsed()
  if nativeElapsed then return nativeElapsed%6 end
  return ((artwork.elapsed or 0)+math.max(0,(now or GetTime())-artwork.startedAt))%6
 end
end
local movingEffects={}
local motionDriver
function E.StopEffectMotion(fx)
 movingEffects[fx]=nil
 if motionDriver and not next(movingEffects)then motionDriver:Hide()end
end
function E.PrepareEffectMotion(fx,entry,row)
 fx.motionSource=row.followArtwork and entry.artworkLayers and entry.artworkLayers[row.followArtwork]or nil
 if not fx.motionSource or not fx.motionSource.animate then E.StopEffectMotion(fx)end
end
local function updateEffectAnchor(fx,now)
 local source=fx.motionSource
 local root=source.root or source
 local phase=E.GetArtworkPhase(root,now)
 if not phase or not fx.frame:IsVisible()then return false end
 local rising=phase<3
 local leg=root.legs[rising and 1 or 2]
 local progress=leg.GetSmoothProgress and leg:GetSmoothProgress()
 if not progress then
  local t=(phase%3)/3
  progress=t*t*(3-2*t)
 end
 local amplitude=root.host:GetHeight()*.012
 local offset=amplitude*(rising and (2*progress-1) or (1-2*progress))
 local visible=false
 for _,slot in ipairs(fx.nativeSmoke.slots)do
  if slot.scene:IsVisible() and slot.anchorX then
   visible=true
   local x=slot.anchorX+(source.segment and source.segment.offset or 0)
   local y=slot.anchorY+offset+(source.segment and source.segment.lift or 0)
   if slot.motionX~=x or slot.motionY~=y then
    slot.scene:SetPoint("CENTER",fx.art,"TOPLEFT",x,y)
    slot.motionX,slot.motionY=x,y
   end
  end
 end
 return visible
end
function E.PlayEffectMotion(fx)
 if not fx.motionSource or fx.nativeSmoke.status~="ready"or not updateEffectAnchor(fx,GetTime())then
  E.StopEffectMotion(fx)
  return
 end
 movingEffects[fx]=true
 if not motionDriver then
  -- Move the ModelScene's actual viewport from the artwork's native hover phase.
  motionDriver=CreateFrame("Frame")
  motionDriver:SetScript("OnUpdate",function()
   local now=GetTime()
   for effect in pairs(movingEffects)do
    if not updateEffectAnchor(effect,now)then E.StopEffectMotion(effect)end
   end
  end)
 end
 motionDriver:Show()
end
