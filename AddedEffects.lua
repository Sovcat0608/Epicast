local _,E=...
function E.UpdateAddedEffects(entry,c)
 local rows=E.GetAddedEffects(c);entry.addedEffectSlots=entry.addedEffectSlots or{}
 for i,row in ipairs(rows)do
  local fx=entry.addedEffectSlots[i]or{frame=entry.frame,art=entry.art};entry.addedEffectSlots[i]=fx
  fx.side=entry.side;fx.setKey=entry.setKey;fx.castArt=c.art;fx.addedIndex=i;fx.alpha=entry.alpha
  fx.preview=entry.preview
  local identity=E.ActiveClass()..":"..c.art..":"..select(2,E.GetSide(E.Config(),entry.setKey,entry.side))..":"..(row.layerID or i)
  if fx.contentIdentity~=identity then E.StopBoundEffect(fx);fx.boundSignals={};fx.previewBound=nil;fx.contentIdentity=identity end
  local selected=entry.placementLayerID and entry.placementLayerID==E.EffectLayerID(row,i)
  local previewBound=selected and row.behavior=="bound"
  if previewBound then
   -- Hold the selected effect in its main animation while positioning it.
   E.ConfigureBoundEffect(fx,nil)
   if not fx.previewBound then
    for _,slot in ipairs(fx.nativeSmoke and fx.nativeSmoke.slots or{})do slot.needsAnimation=true end
   end
  else
   E.ConfigureBoundEffect(fx,row)
  end
  fx.previewBound=previewBound
  if not fx.boundConfig then fx.castBinding=nil;fx.castVisible=nil end
  fx.effectsEnabled=c.effects~=false and row.enabled~=false;fx.nativeWanted=fx.effectsEnabled and c.nativeSmoke~=false
  fx.libraryLevel=row.effectLayer=="back"and 1 or 8+i
  if E.GetRenderedStudioRank and (rows.studio or entry.artworkSegmentsActive)then
   local rank=E.GetRenderedStudioRank(entry,c,E.EffectLayerID(row,i));if rank then fx.libraryLevel=rank*2 end
  end
  if E.PrepareEffectMotion then E.PrepareEffectMotion(fx,entry,row)end
  fx.libraryProfile={fileID=row.fileID,name=row.name,animation=row.animation,modelScale=row.scale,emitterX=row.originX,emitterY=row.originY,emitterZ=row.originZ,
   cameraAzimuth=row.azimuth,cameraElevation=row.elevation,desaturation=row.desaturation,centered=true,naturalEdges=true,opacity=1}
  local tuning={art=c.art,flip=c.flip,effectLayer=row.effectLayer}
  local pending=selected and entry.pendingPlacement
  for _,field in ipairs(E.devEffectFields)do
   local key=field[1];tuning[key]=pending and pending[key] or row[key]
  end
  fx.resourceOpacity=tuning.trailOpacity/100
  if fx.nativeWanted then E.UpdateNativeSmoke(fx,tuning)else E.StopBoundEffect(fx)end
  E.SyncBoundEffect(fx)
 end
 for i=#rows+1,#entry.addedEffectSlots do local fx=entry.addedEffectSlots[i];fx.nativeWanted=false;fx.effectsEnabled=false;E.ConfigureBoundEffect(fx,nil);fx.castBinding=nil;E.StopNativeSmoke(fx)
  local s=fx.nativeSmoke;if s and s.profileID then s.generation=s.generation+1;s.profileID=nil;s.profile=nil;s.polling=false;for _,slot in ipairs(s.slots)do slot.actor.epicastOnModelLoaded=nil;slot.actor:ClearModel()end end
 end
end
