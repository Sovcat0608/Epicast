local _,E=...
E.BindingKinds={{"success","Cast succeeds"},{"cast","While casting"},{"channel","While channeling"},{"pulse","Channel pulse"},{"buff","While buff active"},{"proc","While proc glows"}}
function E.GetLayerBinding(_,row)if row.behavior=="bound"then return row.binding end end
function E.SetLayerBehavior(c,index,behavior)
 if c.role=="resources"and behavior=="bound"then return end
 local r=E.EditAddedEffects(c)[index];if not r then return end;r.behavior=behavior
 if behavior=="bound"then r.binding=r.binding or{kind="success",spell="",duration=1,intro=false,outro=false,introDuration=.5,outroDuration=.5}end
end
function E.AnimationAvailable(id,animation)local m=E.EffectAnimations[id];return not m or m[animation]~=nil end
function E.AnimationSummary(id)
 if id==166602 then return"Stand only (1s); no separate intro / hold / end. Global loops and existing particles may resume on replay."end
 local m=E.EffectAnimations[id];if not m then return"Segments unverified. Preview IDs before binding."end
 local function t(s,id)return s..(m[id]and string.format(" %.2fs",m[id])or" —")end
 return t("Stand / intro",0).." | "..t("Hold",158).." | "..t("End",159)
end
