local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local defaults=E.Copy(E.AddedEffectDefaults.mageArcane)
local fresh=E.Normalize(nil);local c=fresh.content.classes.MAGE.slots.arcane
assert(#c.addedEffects==12 and equal(c.addedEffects,defaults),'Fresh Arcane must use exact approved effects and bindings')
assert(equal(fresh,E.Normalize(fresh)),'Defaults must be idempotent')
assert(#fresh.content.classes.MAGE.slots.fire.addedEffects==0 and #fresh.content.classes.MAGE.slots.frost.addedEffects==0)
local resources=E.Copy(fresh.content.resources);local druid=E.Copy(fresh.content.classes.DRUID)
assert(equal(E.NormalizeSide(nil,'left','spells','mageArcane').addedEffects,defaults))
-- Existing authoring, placement, hidden selections and intentional empties win.
c.addedEffects[1].trailOpacity=3;c.addedEffects[4].binding.duration=2.5
c.size=143;c.x=-411;c.y=87;c.flip=true;fresh.content.classes.MAGE.active.arcane=false
local edited=E.Copy(fresh);assert(equal(E.Normalize(edited),edited))
c.addedEffects={};assert(#E.Normalize(fresh).content.classes.MAGE.slots.arcane.addedEffects==0)
assert(equal(E.Normalize(fresh).content.resources,resources)and equal(E.Normalize(fresh).content.classes.DRUID,druid))
assert(equal(E.AddedEffectDefaults.mageArcane,defaults),'User edits must not mutate defaults')
local legacy=E.Normalize({version=2,content={spells={left={},right={}}}})
assert(#legacy.content.classes.MAGE.slots.arcane.addedEffects==13,'Legacy merge must retain both old lists')
local empty=E.Normalize({version=2,content={spells={left={addedEffects={}},right={addedEffects={}}}}})
assert(#empty.content.classes.MAGE.slots.arcane.addedEffects==0)
print('PASS: exact Arcane defaults, fresh/missing arrays, legacy merge, intentional empties, saved tuning/placement/class isolation and idempotence')

EpicastDB=nil;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
E.panel.save:Click();E.panel:Hide()
local entry=E.GetEntry('spells','arcane');local fx=entry.addedEffectSlots
assert(entry.frame:IsVisible()and #fx==12)
for _,i in ipairs({1,2,5,6,11,12})do assert(not fx[i].boundConfig and fx[i].nativeSmoke.slots[1].scene:IsVisible())end
local allocations=#Mock.frames
for _,row in ipairs(fx)do for _,slot in ipairs(row.nativeSmoke.slots)do slot.actor.SetModelByFileID=function()error('Cast-time model reload')end end end
Mock.event('UNIT_SPELLCAST_START','player','blast',30451);assert(fx[3].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','blast',30451);assert(fx[7].castVisible)
Mock.event('UNIT_SPELLCAST_STOP','player','blast',30451);assert(not fx[3].castVisible)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','explosion',1449);assert(fx[8].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_START','player','missiles',5143);assert(fx[10].castVisible)
Mock.advance(.5);Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','pulse',7268);assert(fx[9].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_STOP','player','missiles',5143);assert(not fx[10].castVisible)
C_UnitAuras={GetPlayerAuraBySpellID=function()error('restricted')end,GetAuraDataBySpellName=function()error('restricted')end}
local icon={cooldownID=71,isActive=false}
C_CooldownViewer={GetCooldownViewerCooldownInfo=function()return{spellID=400588,linkedSpellIDs={400589},selfAura=false}end}
BuffIconCooldownViewer={IsShown=function()return true end,IsVisible=function()return true end,GetItemFrames=function()return{icon}end}
local saved=E.Copy(EpicastDB);local barrage=fx[4];Mock.combat=true
for i=1,4 do
 icon.isActive=true;Mock.advance(.11);assert(barrage.boundPlaying and barrage.boundSegment==0)
 Mock.advance(.51);assert(barrage.boundSegment==158)
 -- Arcane Blast clears the native buff; the next gain must rearm it.
 Mock.event('UNIT_SPELLCAST_START','player','clear'..i,30451)
 icon.isActive=false;Mock.event('UNIT_AURA','player');assert(not barrage.boundPlaying and barrage.boundSegment==159)
 Mock.event('UNIT_SPELLCAST_STOP','player','clear'..i,30451)
 Mock.advance(.34);assert(not barrage.castVisible)
end
-- A new gain during the previous outro must survive that outro's stale timer.
icon.isActive=true;Mock.advance(.11);icon.isActive=false;Mock.event('UNIT_AURA','player')
icon.isActive=true;Mock.advance(.11);assert(barrage.boundPlaying)
Mock.advance(.34);assert(barrage.boundPlaying and barrage.castVisible)
assert(#Mock.frames==allocations and equal(EpicastDB,saved),'Triggers must not allocate frames or rewrite settings')
print('PASS: baked Arcane static/cast/success/pulse/channel routes; repeated Barrage intro/hold/outro, Arcane Blast clears and rapid re-proc without model reloads/settings writes')
