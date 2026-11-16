local E=...
assert(E.EffectAnimations[166602][0]==1 and not E.AnimationAvailable(166602,158)and not E.AnimationAvailable(166602,159))
local repaired=E.NormalizeAddedEffect({fileID=166602,animation=158,trailX=37,behavior='bound',binding={kind='cast',spell='Regrowth',intro=true,outro=true,introDuration=.5}})
assert(repaired.animation==0 and not repaired.binding.intro and not repaired.binding.outro and repaired.trailX==37)
assert(E.AnimationSummary(166602):find('Global loops',1,true))
local db=E.Normalize(nil);db.content.spells.left.addedEffects={repaired};EpicastDB=db
Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
local effect=E.instances.central.left.addedEffectSlots[1];local actor=effect.nativeSmoke.slots[1].actor
local loads=0;actor.SetModelByFileID=function()loads=loads+1;error('A cast must not reload a model')end
local calls={};actor.SetAnimation=function(_,id,variation,speed,offset)calls[#calls+1]={id,variation,speed,offset}end
actor.SetAnimationBlendOperation=function()error('Optional blend API unavailable')end
for i=1,4 do
 E.devMode=true;E.OpenOptions();assert(E.TestBoundEffect('left','arcaneTome',1));assert(effect.boundPlaying)
 assert(calls[#calls][1]==0 and calls[#calls][4]==0 and effect.boundSegment==0)
 Mock.advance(.6);assert(effect.boundPlaying)
 E.StopBoundTests();assert(not effect.boundPlaying)
end
assert(loads==0)
-- Real separate segments still execute Intro -> Hold -> End on every cast.
local row=E.NormalizeAddedEffect({fileID=1699091,animation=158,behavior='bound',binding={kind='cast',spell='30451',intro=true,outro=true,introDuration=.967,outroDuration=.067}})
E.draft.content.spells.left.addedEffects={row};actor.SetModelByFileID=nil
-- Restore the original mock loader before changing selection (outside casts).
function actor:SetModelByFileID(id)self.modelID=id;self.loaded=true;if self.epicastOnModelLoaded then self.epicastOnModelLoaded()end;return true end
E.Apply();Mock.advance(0);calls={}
for i=1,3 do
 Mock.event('UNIT_SPELLCAST_START','player','cast-'..i,30451);assert(calls[#calls][1]==0)
 Mock.advance(.968);assert(calls[#calls][1]==158)
 Mock.event('UNIT_SPELLCAST_STOP','player','cast-'..i,30451);assert(calls[#calls][1]==159)
 Mock.advance(.068);assert(not effect.castVisible)
end
Mock.event('UNIT_SPELLCAST_START','player','interrupt',30451)
Mock.advance(.2);E.draft.content.spells.left.addedEffects={};E.Apply();local count=#calls
Mock.advance(2);assert(#calls==count and not effect.castVisible)
print('PASS: 166602 verified Stand-only repair/repeated playback, real intro-hold-end cycles and cancellation without cast-time reloads; GPU particle reset not simulated')
