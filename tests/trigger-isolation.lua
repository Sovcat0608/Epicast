local E,mode=...
local reader,binding=E.ReadCooldownBuff,E.IsCooldownBuffBinding
if mode=='missing-reader' then E.ReadCooldownBuff=nil
elseif mode=='reader-error' then E.ReadCooldownBuff=function()error('Injected native reader failure')end
elseif mode=='binding-error' then E.IsCooldownBuffBinding=function()error('Injected binding detector failure')end end

local ok,err=pcall(Mock.event,'ADDON_LOADED','Epicast')
assert(ok,'Optional Cooldown Manager failure must not abort addon setup: '..tostring(err))
Mock.advance(0)
local book,scroll=E.instances.central.left,E.instances.central.right
assert(book and scroll and #book.addedEffectSlots==6 and #scroll.addedEffectSlots==7)
local blast,storm,glow=book.addedEffectSlots[4],book.addedEffectSlots[5],book.addedEffectSlots[6]
local impact,explosion,pulse,channel=scroll.addedEffectSlots[4],scroll.addedEffectSlots[5],scroll.addedEffectSlots[6],scroll.addedEffectSlots[7]
local saved,applies,reloads=EpicastDB,0,0
E.Apply=function()applies=applies+1;error('Trigger called Apply')end
for _,effect in ipairs({blast,storm,glow,impact,explosion,pulse,channel})do
 effect.nativeSmoke.slots[1].actor.SetModelByFileID=function()reloads=reloads+1;error('Trigger reloaded a model')end
end
Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED')
for cycle=1,3 do
 Mock.event('UNIT_SPELLCAST_START','player','blast-'..cycle,30451);assert(blast.castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','blast-'..cycle,30451);assert(impact.castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','blast-'..cycle,30451);assert(not blast.castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','explosion-'..cycle,1449);assert(explosion.castVisible)
 Mock.event('UNIT_SPELLCAST_CHANNEL_START','player','missiles-'..cycle,5143);assert(channel.castVisible)
 Mock.advance(.2);Mock.event('UNIT_SPELLCAST_SUCCEEDED','player',nil,7268);assert(pulse.castVisible)
 Mock.event('UNIT_SPELLCAST_INTERRUPTED','player','missiles-'..cycle,5143)
 assert(not channel.castVisible and not pulse.castVisible)
 Mock.aura={name='Missile Barrage',spellId=400589}
 Mock.event('UNIT_AURA','player');assert(storm.castVisible and glow.castVisible)
 Mock.aura=nil;Mock.event('UNIT_AURA','player');assert(not storm.castVisible and not glow.castVisible)
 Mock.advance(2);assert(not impact.castVisible and not explosion.castVisible)
end
assert(storm.boundCooldown=='module missing' or storm.boundCooldown=='reader error' or storm.boundCooldown=='binding error')
local messages={}
E.Message=function(message)messages[#messages+1]=message end
SlashCmdList.EPICAST('triggers')
local report=table.concat(messages,'\n')
for _,spell in ipairs({'Arcane Blast','Arcane Explosion','Arcane Missiles','Missile Barrage'})do assert(report:find(spell,1,true))end
assert(report:find(storm.boundCooldown,1,true))
assert(EpicastDB==saved and E.draft==nil and applies==0 and reloads==0)

-- An optional reader can recover later; no stale sample or failed batch is kept.
if reader and binding then
 E.IsCooldownBuffBinding=binding
 E.ReadCooldownBuff=function()return true,'active'end
 Mock.event('UNIT_AURA','player');assert(storm.castVisible and glow.castVisible)
 E.ReadCooldownBuff=function()return false,'inactive'end
 Mock.advance(.11);assert(not storm.castVisible and not glow.castVisible)
 E.ReadCooldownBuff=reader
end
print('PASS: '..mode..' cannot disable casts, success bursts, Missiles channel/pulses or public buff fallback')
