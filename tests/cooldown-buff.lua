local E = ...
Mock.combat = false
Mock.aura = nil
E.Cancel()
EpicastDB = E.Normalize(nil)
E.Apply()
Mock.advance(0)
local entry = E.instances.central.left
local storm, glow = entry.addedEffectSlots[5], entry.addedEffectSlots[6]
local saved, savedCopy = EpicastDB, E.Copy(EpicastDB)
local originalApply, applies, reloads = E.Apply, 0, 0
E.Apply = function(...)applies=applies+1;return originalApply(...)end
local setters={}
for _,effect in ipairs({storm,glow}) do
    local actor=effect.nativeSmoke.slots[1].actor
    setters[actor]=actor.SetModelByFileID
    actor.SetModelByFileID=function(self,...)reloads=reloads+1;return setters[self](self,...)end
end
local function visible(expected)
    for _,effect in ipairs({storm,glow}) do
        assert(effect.boundPlaying==expected and effect.castVisible==expected,
            'Cooldown Manager must drive both Barrage layers: '..tostring(expected))
        assert(effect.nativeSmoke.slots[1].scene:IsVisible()==expected)
    end
end
local originalAuras, originalSecret = C_UnitAuras, issecretvalue
local secret = setmetatable({}, {__index=function()error('Secret data inspected')end})
issecretvalue = function(v)return v==secret end
C_UnitAuras = {GetAuraDataBySpellName=function()return secret end,
    GetPlayerAuraBySpellID=function()return secret end}
local icon = {cooldownID=71, active=false}
function icon:GetCooldownID()return self.cooldownID end
function icon:IsActive()return self.active end
function icon:HasEditModeData()return self.preview or false end
-- Calling native refresh/auras or changing the viewer must never be necessary.
local function forbidden()error('Native state was changed or restricted aura read')end
for _,method in ipairs({'RefreshData','RefreshActive','GetAuraDataCached','GetAuraSpellID','SetIsActive','SetScript','HookScript','SetParent','Show','Hide'}) do
    icon[method]=forbidden
end
setmetatable(icon,{__index=function(_,key)if key=='auraInstanceID' then forbidden() end end})
local clearcasting={cooldownID=72,IsActive=function()return true end}
local viewer = {items={icon}, visible=true, editing=false, reads=0}
function viewer:IsVisible()return self.visible end
function viewer:IsEditing()return self.editing end
function viewer:GetChildren()self.reads=self.reads+1;return unpack(self.items) end
for _,method in ipairs({'RefreshData','RefreshLayout','SetScript','HookScript','SetParent','SetAlpha','Show','Hide'}) do viewer[method]=forbidden end
BuffIconCooldownViewer = viewer
local metadata={spellID=400588,linkedSpellIDs={400589},selfAura=true}
C_CooldownViewer = {GetCooldownViewerCooldownInfo=function(id)
    if id==71 then return metadata end
    if id==72 then return {spellID=11213,linkedSpellIDs={12536},selfAura=true} end
end,SetLayoutData=forbidden}
Mock.combat=true
Mock.event('PLAYER_REGEN_DISABLED')
Mock.event('UNIT_AURA','player')
visible(false)
-- Native UI updates after Epicast receives UNIT_AURA. No second aura event.
icon.active=true
Mock.advance(.11)
visible(true)
assert(storm.boundInput=='cooldown-active' and storm.boundCooldown=='active')
local actor=storm.nativeSmoke.slots[1].actor
for cycle=1,3 do
    local starts=actor.animationStarts
    Mock.advance(.11);assert(actor.animationStarts==starts)
    Mock.event('UNIT_SPELLCAST_START','player','blast-'..cycle,30451)
    assert(entry.addedEffectSlots[4].castVisible)
    visible(true) -- Blast alone is not an inferred consumption signal.
    icon.active=false
    Mock.advance(.11);visible(false)
    assert(storm.boundInput=='cooldown-inactive')
    Mock.event('UNIT_SPELLCAST_STOP','player','blast-'..cycle,30451)
    icon.active=true
    Mock.event('UNIT_AURA',secret) -- A restricted event payload cannot prevent polling.
    Mock.advance(.11);visible(true)
    assert(actor.animationStarts==starts+1)
end
-- Real native loss handles both consumption and expiry without guessed timers.
icon.active=false
Mock.event('UNIT_SPELLCAST_CHANNEL_START','player','missiles',5143)
visible(false)
local scroll=E.instances.central.right
assert(scroll.addedEffectSlots[7].castVisible)
Mock.advance(.5)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player',nil,7268)
assert(scroll.addedEffectSlots[6].castVisible)
Mock.event('UNIT_SPELLCAST_CHANNEL_STOP','player','missiles',5143)
icon.active=true;Mock.advance(.11);visible(true)
icon.active=false;Mock.advance(.11);visible(false)
viewer.items={clearcasting,icon};Mock.advance(.11);visible(false)
print('PASS: restricted Barrage gains, repeated clears, consumption and expiry; Clearcasting and Missiles remain independent')

-- Current metadata is read for every sample, including overrides and pooled reuse.
for _,info in ipairs({{spellID=400588},{spellID=400589},{overrideSpellID=400588},
    {overrideTooltipSpellID=400589},{spellID=7,linkedSpellIDs={400589}}}) do
    metadata=info;icon.active=true;Mock.advance(.11);visible(true)
end
icon.cooldownID=72;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='untracked')
icon.cooldownID=nil;Mock.advance(.11);visible(false)
icon.cooldownID=71;Mock.advance(.11);visible(true)
local replacement={cooldownID=71,isActive=false}
viewer.items={replacement};Mock.advance(.11);visible(false)
replacement.isActive=true;Mock.advance(.11);visible(true)
viewer.items={icon}
-- Both native buff viewers work; action-cooldown viewers are never consulted.
BuffIconCooldownViewer=nil;BuffBarCooldownViewer=viewer
Mock.advance(.11);visible(true)
BuffBarCooldownViewer=nil
EssentialCooldownViewer=viewer
Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='unavailable')
EssentialCooldownViewer=nil;BuffIconCooldownViewer=viewer
Mock.advance(.11);visible(true)

-- Hidden native rows stop updating. Edit Mode demo icons are not proc evidence.
viewer.visible=false;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='hidden')
viewer.visible=true;viewer.editing=true;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='preview')
viewer.editing=false;icon.preview=true;Mock.advance(.11);visible(false)
icon.preview=false;Mock.advance(.11);visible(true)
-- Unknown/secret/error results must not become true from visibility or presence.
icon.active=secret;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='restricted')
icon.active=nil;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='unknown')
local activeMethod=icon.IsActive
icon.IsActive=function()error('Unavailable native read')end
Mock.advance(.11);visible(false);assert(storm.boundCooldown=='error')
icon.IsActive=activeMethod;icon.active=true
metadata=secret;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='restricted')
metadata={spellID=secret,linkedSpellIDs=secret};Mock.advance(.11);visible(false)
metadata={spellID=400588,selfAura=false};Mock.advance(.11);visible(false)
metadata={spellID=400588,selfAura=true};Mock.advance(.11);visible(true)
local cooldownInfo=C_CooldownViewer.GetCooldownViewerCooldownInfo
C_CooldownViewer.GetCooldownViewerCooldownInfo=function()error('Native data not loaded')end
Mock.advance(.11);visible(false);assert(storm.boundCooldown=='error')
C_CooldownViewer.GetCooldownViewerCooldownInfo=cooldownInfo
issecrettable=function(v)return v==secret end
viewer.items={secret,icon};Mock.advance(.11);visible(true)
issecrettable=nil
viewer.items={icon}
BuffBarCooldownViewer={IsVisible=function()return true end,GetChildren=function()return replacement end}
replacement.isActive=false;Mock.advance(.11);visible(false)
assert(storm.boundCooldown=='conflict')
BuffBarCooldownViewer=nil;Mock.advance(.11);visible(true)
print('PASS: both buff viewers, native spell aliases, pool reassignment, hidden/preview/restricted/error/conflicting states')

-- Public aura lookup still works without usable native tracking, including
-- late loading/disabling of the native addon without an Epicast reconfiguration.
BuffIconCooldownViewer=nil;C_UnitAuras=originalAuras
Mock.aura={name='Missile Barrage',spellId=400589}
Mock.event('UNIT_AURA','player');visible(true)
assert(storm.boundInput=='matched' and storm.boundCooldown=='unavailable')
Mock.aura=nil;Mock.event('UNIT_AURA','player');visible(false)
BuffIconCooldownViewer=viewer;Mock.advance(.11);visible(true)
local row=E.Copy(E.GetAddedEffects(entry.config)[5])
local originalSpell=row.binding.spell
for _,spell in ipairs({'400588','400589'}) do
    row.binding.spell=spell;E.ConfigureBoundEffect(storm,row);E.SyncBoundEffect(storm)
    assert(storm.castVisible and storm.boundInput=='cooldown-active')
end
local spellName=C_Spell.GetSpellName
C_Spell.GetSpellName=function(id)if id==400589 then return 'Salve de projectiles' end;return spellName(id)end
row.binding.spell='Salve de projectiles'
E.ConfigureBoundEffect(storm,row);E.SyncBoundEffect(storm)
assert(storm.castVisible)
C_Spell.GetSpellName=spellName
row.binding.spell=originalSpell;E.ConfigureBoundEffect(storm,row);E.SyncBoundEffect(storm)
assert(not E.IsCooldownBuffBinding({kind='proc',spell='Missile Barrage'}))
assert(not E.IsCooldownBuffBinding({kind='buff',spell='Clearcasting'}))

local messages,oldMessage={},E.Message
E.Message=function(message)messages[#messages+1]=message end
local panelShown=E.panel:IsShown()
SlashCmdList.EPICAST('triggers')
assert(#messages==3 and messages[2]:find('cooldown=active',1,true))
assert(E.panel:IsShown()==panelShown and E.draft==nil)
E.Message=oldMessage

-- Polling cannot resurrect a disabled/removed effect or a dead player's buff.
Mock.event('PLAYER_DEAD');visible(false)
local reads=viewer.reads
Mock.advance(.2);assert(viewer.reads==reads);visible(false)
icon.active=false;Mock.event('PLAYER_ALIVE');visible(false)
icon.active=true;Mock.advance(.11);visible(true)
entry.frame:Hide();visible(false)
reads=viewer.reads;Mock.advance(.2);assert(viewer.reads==reads)
entry.frame:Show();visible(true)
E.ConfigureBoundEffect(storm,nil);E.ConfigureBoundEffect(glow,nil)
reads=viewer.reads;Mock.advance(.2);assert(viewer.reads==reads);visible(false)
E.ConfigureBoundEffect(storm,E.GetAddedEffects(entry.config)[5])
E.ConfigureBoundEffect(glow,E.GetAddedEffects(entry.config)[6])
E.SyncBoundEffect(storm);E.SyncBoundEffect(glow);visible(true)
assert(reloads==0 and applies==0 and EpicastDB==saved)
local function equal(a,b)
    if type(a)~='table' or type(b)~='table' then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
assert(equal(EpicastDB,savedCopy),'Polling or reporting wrote settings')
assert(viewer.GetChildren and icon.IsActive==activeMethod and icon.Show==forbidden)

C_UnitAuras,issecretvalue=originalAuras,originalSecret
BuffIconCooldownViewer,C_CooldownViewer=nil,nil
Mock.combat=false
E.Apply=originalApply
for actor,setter in pairs(setters)do actor.SetModelByFileID=setter end
Mock.event('UNIT_AURA','player');visible(false)
print('PASS: public aura fallback, numeric/localized bindings, diagnostics, death/disable/removal; zero model reloads, Apply calls or settings changes')
