local _,E=...
function E.UpdateAddedEffects(entry,c)
 local rows=E.GetAddedEffects(c);entry.addedEffectSlots=entry.addedEffectSlots or{}
 for i,row in ipairs(rows)do
  local fx=entry.addedEffectSlots[i]or{frame=entry.frame,art=entry.art};entry.addedEffectSlots[i]=fx
  fx.side=entry.side;fx.setKey=entry.setKey;fx.castArt=c.art;fx.addedIndex=i;fx.alpha=entry.alpha
  local identity=E.ActiveClass()..":"..c.art..":"..select(2,E.GetSide(E.Config(),entry.setKey,entry.side))
  if fx.contentIdentity~=identity then E.StopBoundEffect(fx);fx.boundLast=nil;fx.boundGUID=nil;fx.contentIdentity=identity end
  fx.resourceOpacity=row.trailOpacity/100
  E.ConfigureBoundEffect(fx,row);if not fx.boundConfig then fx.castBinding=nil;fx.castVisible=nil end
  fx.effectsEnabled=c.effects~=false;fx.nativeWanted=fx.effectsEnabled and c.nativeSmoke~=false
  fx.libraryLevel=row.effectLayer=="back"and 1 or 8+i
  fx.libraryProfile={fileID=row.fileID,name=row.name,animation=row.animation,modelScale=row.scale,emitterX=row.originX,emitterY=row.originY,emitterZ=row.originZ,
   cameraAzimuth=row.azimuth,cameraElevation=row.elevation,desaturation=row.desaturation,centered=true,naturalEdges=true,opacity=1}
  local tuning={art=c.art,flip=c.flip,effectLayer=row.effectLayer};for _,s in ipairs(E.devEffectFields)do tuning[s[1]]=row[s[1]]end
  if fx.nativeWanted then E.UpdateNativeSmoke(fx,tuning)else E.StopBoundEffect(fx)end
  E.SyncBoundEffect(fx)
 end
 for i=#rows+1,#entry.addedEffectSlots do local fx=entry.addedEffectSlots[i];fx.nativeWanted=false;fx.effectsEnabled=false;E.ConfigureBoundEffect(fx,nil);fx.castBinding=nil;E.StopNativeSmoke(fx)
  local s=fx.nativeSmoke;if s and s.profileID then s.generation=s.generation+1;s.profileID=nil;s.profile=nil;s.polling=false;for _,slot in ipairs(s.slots)do slot.actor.epicastOnModelLoaded=nil;slot.actor:ClearModel()end end
 end
end
