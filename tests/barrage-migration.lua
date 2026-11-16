local E=...
local db=E.Normalize(nil)
for i,spell in ipairs({'Missile Barrage','400588','400589'})do
 db.content.spells.left.addedEffects[i]={fileID=166009,behavior='bound',trailX=i*13,binding={kind='proc',spell=spell}}
end
db=E.Normalize(db)
for i=1,3 do local r=db.content.spells.left.addedEffects[i];assert(r.binding.kind=='buff'and r.trailX==i*13);assert(E.IsCooldownBuffBinding(r.binding))end
assert(db.content.spells.left.addedEffects[2].binding.spell=='400589')
EpicastDB=db;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
C_UnitAuras={GetPlayerAuraBySpellID=function()error('restricted')end,GetAuraDataBySpellName=function()error('restricted')end}
local icon={cooldownID=71,isActive=false}
C_CooldownViewer={GetCooldownViewerCooldownInfo=function()return{spellID=400588,linkedSpellIDs={400589},selfAura=false}end}
BuffIconCooldownViewer={IsShown=function()return true end,IsVisible=function()return true end,GetItemFrames=function()return{icon}end}
for i=1,4 do
 icon.isActive=true;Mock.advance(.11)
 for n=1,3 do assert(E.instances.central.left.addedEffectSlots[n].castVisible)end
 icon.isActive=false;Mock.event('UNIT_AURA','player');Mock.advance(.11)
 for n=1,3 do assert(not E.instances.central.left.addedEffectSlots[n].castVisible)end
end
print('PASS: existing Arcane Proc/name/talent-ID layers upgrade to shared Buff tracking and repeat after native proc clears')
