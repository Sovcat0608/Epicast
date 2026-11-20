local _,E=...
E.EffectEmitters={{u=.5,v=.5,scale=1}}
function E.EffectAnchor(eye,w,h,c)local d=c.flip and -1 or 1;return(c.flip and 1-eye.u or eye.u)*w+d*(c.trailX or 0)*w/150,-eye.v*h+(c.trailY or 0)*h/150,d end
function E.StopEffects(entry)
 if E.HideRestorationSegments then E.HideRestorationSegments(entry)end
 E.StopDruidSisters(entry);E.StopMageReboot(entry)
 for _,fx in ipairs(entry.addedEffectSlots or{})do if fx.boundConfig then E.StopBoundEffect(fx)else E.StopNativeSmoke(fx)end end
end
function E.PlayEffects(entry)
 E.PlayDruidSisters(entry);E.PlayMageReboot(entry)
 if entry.restorationSegments and entry.config and E.ApplyStudioArtwork then E.ApplyStudioArtwork(entry,entry.config)end
 for _,fx in ipairs(entry.addedEffectSlots or{})do E.SyncBoundEffect(fx);E.PlayNativeSmoke(fx)end
end
function E.UpdateEffects(entry,c)
 if not entry.effectHooks then entry.frame:HookScript("OnHide",function()E.StopEffects(entry)end);entry.frame:HookScript("OnShow",function()E.PlayEffects(entry)end);entry.effectHooks=true end
 E.UpdateDruidSisters(entry,c);E.UpdateMageReboot(entry,c);if E.ApplyStudioArtwork then E.ApplyStudioArtwork(entry,c)end;E.UpdateAddedEffects(entry,c)
end
