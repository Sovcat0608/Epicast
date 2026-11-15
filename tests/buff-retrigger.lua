local E = ...

E.Cancel()
EpicastDB = E.Normalize(nil)
E.Apply()
Mock.advance(0)
local entry = E.instances.central.left
local storm = entry.addedEffectSlots[5]
local glow = entry.addedEffectSlots[6]
local blast = entry.addedEffectSlots[4]
local barrage = {name='Missile Barrage', spellId=400589}
local saved = EpicastDB
local originalApply = E.Apply
local originalAuras = C_UnitAuras
local reloads, applies = 0, 0
E.Apply = function(...) applies=applies+1; return originalApply(...) end
local modelSetters = {}
for _,effect in ipairs({storm, glow}) do
    local actor = effect.nativeSmoke.slots[1].actor
    modelSetters[actor] = actor.SetModelByFileID
    actor.SetModelByFileID = function(self, ...)
        reloads = reloads + 1
        return modelSetters[self](self, ...)
    end
end
local function visible(expected)
    for _,effect in ipairs({storm, glow}) do
        assert(effect.castVisible==expected and effect.boundPlaying==expected)
        assert(effect.nativeSmoke.slots[1].scene:IsVisible()==expected)
    end
end

-- Arcane Blast removes the buff, followed by a later fresh proc, in combat.
Mock.combat = true
Mock.event('PLAYER_REGEN_DISABLED')
for cycle=1,3 do
    local actor = storm.nativeSmoke.slots[1].actor
    local starts = actor.animationStarts
    Mock.aura = barrage
    Mock.event('UNIT_AURA', 'player')
    visible(true)
    assert(actor.animationStarts==starts+1)
    Mock.event('UNIT_AURA', 'player')
    assert(actor.animationStarts==starts+1)
    Mock.event('UNIT_SPELLCAST_START', 'player', 'blast-'..cycle, 30451)
    assert(blast.castVisible)
    visible(true)
    Mock.aura = nil
    Mock.event('UNIT_AURA', 'player')
    visible(false)
    Mock.event('UNIT_SPELLCAST_SUCCEEDED', 'player', 'blast-'..cycle, 30451)
    Mock.event('UNIT_SPELLCAST_STOP', 'player', 'blast-'..cycle, 30451)
    assert(not blast.castVisible)
    Mock.advance(2)
end
assert(reloads==0 and applies==0 and EpicastDB==saved)
print('PASS: both Barrage layers rearm after repeated Arcane Blast buff clears in combat, with no model reloads or settings writes')

-- A restricted earlier aura is not evidence that the list has ended.
local restricted = setmetatable({}, {__index=function()error('Restricted aura was inspected')end})
issecrettable = function(value) return value==restricted end
local scanCount = 0
C_UnitAuras = {
    GetAuraDataBySpellName=function() return nil end,
    GetAuraDataByIndex=function(_, index)
        scanCount = scanCount+1
        if index==1 then return restricted end
        if index==2 then return Mock.aura end
    end,
}
Mock.aura = barrage
Mock.event('UNIT_AURA', 'player')
assert(storm.castVisible and glow.castVisible, 'Readable Barrage after a restricted aura must activate both effects')
assert(scanCount>=4)
Mock.aura = nil
Mock.event('UNIT_AURA', 'player')
visible(false)
Mock.aura = barrage
Mock.event('UNIT_AURA', 'player')
visible(true)
Mock.aura = nil
Mock.event('UNIT_AURA', 'player')
visible(false)
issecrettable = nil

-- A restricted value and restricted identity fields remain unreadable too.
issecretvalue = function(value) return value==restricted end
Mock.aura = barrage
Mock.event('UNIT_AURA', 'player')
visible(true)
Mock.aura = {name=restricted, spellId=restricted}
Mock.event('UNIT_AURA', 'player')
visible(false)
assert(storm.boundInput=='restricted' and glow.boundInput=='restricted')

local messages = {}
local originalMessage = E.Message
local panelShown = E.panel:IsShown()
E.Message = function(message) messages[#messages+1]=message end
SlashCmdList.EPICAST('triggers')
assert(#messages==3 and messages[2]:find('input=restricted',1,true))
assert(E.panel:IsShown()==panelShown and E.draft==nil and EpicastDB==saved)
E.Message = originalMessage
issecretvalue = nil

scanCount = 0
C_UnitAuras.GetAuraDataByIndex = function() scanCount=scanCount+1;error('API unavailable') end
Mock.event('UNIT_AURA', 'player')
assert(scanCount==2 and storm.boundInput=='error' and glow.boundInput=='error')
visible(false)

C_UnitAuras = originalAuras
Mock.aura = barrage
local actor = storm.nativeSmoke.slots[1].actor
local setAnimation = actor.SetAnimation
actor.SetAnimation = function() error('Actor playback unavailable') end
Mock.event('UNIT_AURA', 'player')
assert(storm.boundInput=='matched' and storm.boundPlayback=='animation error' and not storm.castVisible)
assert(glow.castVisible)
actor.SetAnimation = setAnimation
Mock.event('UNIT_AURA', 'player')
visible(true)
assert(storm.boundPlayback=='started')
Mock.aura = nil
Mock.event('UNIT_AURA', 'player')
visible(false)
Mock.combat = false
E.Apply = originalApply
for actor,setter in pairs(modelSetters) do actor.SetModelByFileID=setter end
assert(reloads==0 and applies==0 and EpicastDB==saved)
print('PASS: restricted aura entries allow later public Barrage detection and repeated removal/reapplication')
