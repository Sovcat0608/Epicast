local _,E=...
-- Player-only declarative triggers. No user Lua, protected actions or model reloads.
local layers=setmetatable({}, {__mode="k"})
local frame,cast,channel
local overlay={}
local lastEvent="initialization"
local auraEvents=0
local spellEvents=0
local triggerRevision="0.1.0-beta.13"
local bridgeError
local buffPollPending,dead=false,false
local buffBatch,buffSnapshot=false,nil
local function public(v)return not (issecretvalue and issecretvalue(v))end
local function readable(v)return public(v) and not(type(v)=="table" and issecrettable and issecrettable(v))end
local function call(fn,...)
    if not fn then return nil,"unavailable" end
    local ok,v=pcall(fn,...)
    if not ok then return nil,"error" end
    if not readable(v) then return nil,"restricted" end
    return v,"readable"
end
local function name(id)return C_Spell and call(C_Spell.GetSpellName,id)end
local function rememberBridgeError(value)
    bridgeError=public(value) and type(value)=="string" and value:sub(1,180) or "unreadable error"
end
-- The native buff bridge is optional. A missing file or reader error must not
-- interrupt configuration/event dispatch for cast, channel or burst effects.
local function cooldownBinding(b)
    if not b or b.kind~="buff" then return false end
    if type(E.IsCooldownBuffBinding)~="function" then return false,"module missing" end
    local ok,value,key=pcall(E.IsCooldownBuffBinding,b)
    if not ok then rememberBridgeError(value);return false,"binding error" end
    if not public(value) then return false,"restricted" end
    if value~=true then return false end
    if not public(key) then return false,"restricted" end
    return true,type(key)=="string" and key or "barrage"
end
local function readCooldownBuff(key)
    if type(E.ReadCooldownBuff)~="function" then return nil,"module missing" end
    local ok,value,status=pcall(E.ReadCooldownBuff,false,key)
    if not ok then rememberBridgeError(value);return nil,"reader error" end
    if not readable(value) or not readable(status) then return nil,"restricted" end
    if value~=nil and type(value)~="boolean" then return nil,"invalid state" end
    return value,type(status)=="string" and status or "unknown"
end
local function match(b,id,text)
    if b.spell=="" then return false end
    local number=tonumber(b.spell)
    if number then return public(id) and id==number end
    if public(text) and type(text)=="string" and text:lower()==b.spell:lower() then return true end
    if public(id) and type(id)=="number" then local n=name(id);return type(n)=="string" and n:lower()==b.spell:lower() end
    return false
end
local function info(isChannel,id,guid)
    local fn=isChannel and UnitChannelInfo or UnitCastingInfo
    local v={id=public(id) and id or nil,key=public(guid) and guid or nil}
    if isChannel then v.started=GetTime()end
    if fn then
        local r={pcall(fn,"player")}
        if r[1] then
            if public(r[2]) then v.name=r[2] end
            local spell=r[isChannel and 9 or 10]
            if public(spell) and type(spell)=="number" then v.id=spell end
        end
    end
    return v
end
local function usable(e)return e.effectsEnabled and e.nativeWanted and e.frame:IsVisible()end
function E.StopBoundEffect(e)
    if e.boundPlaying or e.castVisible then
        e.boundStops=(e.boundStops or 0)+1
        e.boundLastStop=lastEvent
    end
    e.boundToken=(e.boundToken or 0)+1;e.boundPlaying=false;e.castVisible=false;e.boundTest=nil
    E.StopNativeSmoke(e)
end
local function animate(e,animation)
    local s=e.nativeSmoke
    if not usable(e) or not s or s.status~="ready" or s.loadDirty then e.boundPlayback="not ready";return false end
    local ok=pcall(function()
        for _,slot in ipairs(s.slots) do
            if not slot.actor:IsLoaded() then error("not ready") end
            -- Avoid blending a new Stand/intro into the previous Hold pose.
            -- This is a sequence restart, not a reset of model-global particles.
            if slot.actor.SetAnimationBlendOperation then pcall(slot.actor.SetAnimationBlendOperation,slot.actor,0) end
            slot.actor:SetAnimation(animation,0,1,0);slot.actor:Show()
        end
        e.castVisible=true;E.PlayNativeSmoke(e)
    end)
    if not ok then e.boundPlayback="animation error";E.StopBoundEffect(e);return false end
    e.boundPlayback="started"
    e.boundSegment=animation
    return true
end
local function later(e,seconds,fn)
    local token=e.boundToken
    C_Timer.After(seconds,function()if layers[e] and e.boundToken==token then fn() end end)
end
local function finish(e)
    local b=e.boundConfig
    e.boundPlaying=false;e.boundToken=(e.boundToken or 0)+1
    if b.outro and animate(e,159) then later(e,b.outroDuration,function()E.StopBoundEffect(e);E.SyncBoundEffect(e)end)
    else E.StopBoundEffect(e);E.SyncBoundEffect(e) end
end
local function play(e,burst,test)
    e.boundToken=(e.boundToken or 0)+1
    local b=e.boundConfig
    if not animate(e,b.intro and 0 or e.libraryProfile.animation) then E.StopBoundEffect(e);return false end
    e.boundPlaying=true;e.boundTest=test
    e.boundStarts=(e.boundStarts or 0)+1
    if b.intro then later(e,b.introDuration,function()animate(e,e.libraryProfile.animation)end) end
    if burst then later(e,burst+(b.intro and b.introDuration or 0),function()finish(e)end) end
    return true
end
local function aura(b)
    local api=C_UnitAuras;if not api then return false,"unavailable" end
    local id=tonumber(b.spell)
    local a,status
    if id then a,status=call(api.GetPlayerAuraBySpellID,id)
    else a,status=call(api.GetAuraDataBySpellName,"player",b.spell,"HELPFUL") end
    if type(a)=="table" and match(b,a.spellId,a.name) then return true,"matched" end
    local unknown=status~="readable" and status or nil
    if type(a)=="table" and (not public(a.spellId) or not public(a.name)) then unknown="restricted" end
    if api.GetAuraDataByIndex then
        for i=1,255 do
            a,status=call(api.GetAuraDataByIndex,"player",i,"HELPFUL")
            -- Only a readable nil ends the list. Skip inaccessible entries
            -- without inspecting them so later public auras can still match.
            if status=="readable" and a==nil then break end
            if type(a)=="table" and match(b,a.spellId,a.name) then return true,"matched" end
            if status~="readable" then unknown=status
            elseif type(a)=="table" and (not public(a.spellId) or not public(a.name)) then unknown="restricted" end
            if status=="error" then break end
        end
    end
    return false,unknown or "absent"
end
local function proc(b)
    for id,active in pairs(overlay) do if active and match(b,id) then return true end end
    local id=tonumber(b.spell)
    if not id and C_Spell then local s=call(C_Spell.GetSpellInfo,b.spell);if type(s)=="table" and public(s.spellID) then id=s.spellID end end
    return id and C_SpellActivationOverlay and call(C_SpellActivationOverlay.IsSpellOverlayed,id)==true or false
end
local function active(b)
    if b.kind=="cast" then return cast and match(b,cast.id,cast.name)
    elseif b.kind=="channel" then return channel and match(b,channel.id,channel.name)
    elseif b.kind=="buff" then
        local supported,cooldownStatus=cooldownBinding(b)
        if supported then
            local snapshot=buffSnapshot and buffSnapshot[cooldownStatus] or {readCooldownBuff(cooldownStatus)}
            if buffBatch then buffSnapshot[cooldownStatus]=snapshot end
            if type(snapshot[1])=="boolean" then return snapshot[1],"cooldown-"..snapshot[2],snapshot[2] end
            local value,status=aura(b)
            return value,status,snapshot[2]
        end
        local value,status=aura(b)
        return value,status,cooldownStatus
    elseif b.kind=="proc" then return proc(b) end
    return false
end
local function pollBuffs()
    if buffPollPending or dead then return end
    buffPollPending=true
    C_Timer.After(.1,function()
        buffPollPending=false
        if dead then return end
        buffBatch=true;buffSnapshot={}
        for e in pairs(layers) do
            if cooldownBinding(e.boundConfig) and usable(e) then
                lastEvent="COOLDOWN_MANAGER_POLL"
                E.SyncBoundEffect(e)
            end
        end
        buffBatch=false;buffSnapshot=nil
    end)
end
function E.SyncBoundEffect(e)
    if not e.boundConfig then return end
    if not usable(e) then e.boundInput="disabled";E.StopBoundEffect(e);return end
    if dead then E.StopBoundEffect(e);return end
    if cooldownBinding(e.boundConfig) then pollBuffs() end
    if e.boundTest then return end
    local b=e.boundConfig
    if b.kind=="success" or b.kind=="pulse" then return end
    local isActive,status,cooldownStatus=active(b)
    e.boundInput=status or (isActive and "active" or "inactive")
    e.boundCooldown=cooldownStatus
    if isActive then
        if not e.boundPlaying then play(e) end
    elseif e.boundPlaying then finish(e) end
end
local function same(current,guid)
    return current and (not public(guid) or not guid or not current.key or current.key==guid)
end
function E.HandleBoundEvent(event,unit,guid,id)
    if event=="PLAYER_REGEN_DISABLED" then lastEvent=event;E.StopBoundTests();return end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_DEAD" or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST" then
        lastEvent=event
        dead=event=="PLAYER_DEAD"
        cast=nil;channel=nil;overlay={}
        for e in pairs(layers) do E.StopBoundEffect(e) end
        if event=="PLAYER_DEAD" then return end
        cast=info(false);channel=info(true)
    elseif event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event=="SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        lastEvent=event
        if public(unit) and type(unit)=="number" then overlay[unit]=event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" end
    else
        if not public(unit) or unit~="player" then return end
        lastEvent=event
        if event=="UNIT_AURA" then auraEvents=auraEvents+1 else spellEvents=spellEvents+1 end
        if event=="UNIT_SPELLCAST_START" then cast=info(false,id,guid);channel=nil
        elseif event=="UNIT_SPELLCAST_CHANNEL_START" then channel=info(true,id,guid);channel.started=GetTime();cast=nil
        elseif event=="UNIT_SPELLCAST_STOP" then if same(cast,guid) then cast=nil end
        elseif event=="UNIT_SPELLCAST_CHANNEL_STOP" then if same(channel,guid) then channel=nil end
        elseif event=="UNIT_SPELLCAST_INTERRUPTED" or event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET" then
            if same(cast,guid) then cast=nil end
            if same(channel,guid) then channel=nil;for e in pairs(layers) do if e.boundConfig.kind=="pulse" then E.StopBoundEffect(e) end end end
        elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
            local now=GetTime()
            for e in pairs(layers) do
                local b=e.boundConfig
                local eligible=b.kind=="success" or (b.kind=="pulse" and channel and match(b,channel.id,channel.name) and now-(channel.started or now)>.05)
                local matching=match(b,id)
                if not matching and eligible and b.kind=="pulse" and public(id) and type(id)=="number" then
                    local pulseName=name(id);local channelName=channel.name or (channel.id and name(channel.id))
                    matching=type(pulseName)=="string" and type(channelName)=="string" and pulseName==channelName
                end
                if eligible and matching then
                    local key=public(guid) and guid or nil
                    if (not e.boundLast or now-e.boundLast>.05) and (not key or key~=e.boundGUID or b.kind=="pulse") then
                        e.boundInput="matched";e.boundLast=now;e.boundGUID=key;play(e,b.duration)
                    end
                end
            end
        end
    end
    buffBatch=true;buffSnapshot={}
    for e in pairs(layers) do E.SyncBoundEffect(e) end
    buffBatch=false;buffSnapshot=nil
end

function E.PrintBoundStatus()
    E.Message(string.format("Triggers %s: combat=%s, spell events=%d, aura events=%d, last=%s, bridge error=%s",
        triggerRevision,tostring(InCombatLockdown()),spellEvents,auraEvents,lastEvent,bridgeError or "none"))
    if type(E.PrintCooldownBuffStatus)=="function" then
        local keys={}
        for e in pairs(layers)do local supported,key=cooldownBinding(e.boundConfig);if supported then keys[key]=true end end
        local ok,err=pcall(E.PrintCooldownBuffStatus,keys)
        if not ok then rememberBridgeError(err);E.Message("Native report unavailable: "..bridgeError)end
    end
    for setKey,entries in pairs(E.instances) do
        for _,entry in pairs(entries) do
            local side=entry.side
            for index,e in ipairs(entry.config and entry.addedEffectSlots or {}) do
                local b=e.boundConfig
                if b then
                    local s=e.nativeSmoke
                    local scene=s and s.slots[1] and s.slots[1].scene
                    E.Message(string.format("%s/%s #%d model=%d %s (%s): input=%s, cooldown=%s, enabled=%s, artwork=%s, starts/stops=%d/%d, playing=%s, scene=%s, model=%s, dirty=%s, playback=%s, stopped at=%s, segment=%s",
                        setKey,side,index,e.libraryProfile.fileID,b.spell,b.kind,e.boundInput or "unread",e.boundCooldown or "not used",
                        tostring(e.effectsEnabled==true and e.nativeWanted==true),tostring(e.frame:IsVisible()),
                        e.boundStarts or 0,e.boundStops or 0,tostring(e.boundPlaying==true),
                        tostring(scene and scene:IsVisible() or false),s and s.status or "missing",
                        tostring(s and s.loadDirty==true or false),e.boundPlayback or "none",e.boundLastStop or "none",tostring(e.boundSegment or "none")))
                end
            end
        end
    end
end
local function initialize()
    if frame then return end
    frame=CreateFrame("Frame")
    for _,event in ipairs({"UNIT_AURA","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_CHANNEL_UPDATE","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET"}) do frame:RegisterUnitEvent(event,"player") end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_REGEN_DISABLED","SPELL_ACTIVATION_OVERLAY_GLOW_SHOW","SPELL_ACTIVATION_OVERLAY_GLOW_HIDE"}) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent",function(_,...)E.HandleBoundEvent(...)end)
    cast=info(false);channel=info(true)
end
function E.ConfigureBoundEffect(e,row)
    local b=row and row.behavior=="bound" and row.binding
    local signature=b and table.concat({row.fileID,b.kind,b.spell,row.animation,b.duration,tostring(b.intro),tostring(b.outro),b.introDuration,b.outroDuration},"|")
    if signature~=e.boundSignature then E.StopBoundEffect(e);e.boundLast=nil;e.boundGUID=nil;e.boundSignature=signature end
    e.boundConfig=b;layers[e]=b and true or nil
    if b then e.castBinding={kind="custom",label=b.kind..": "..b.spell};initialize() end
end
function E.StopBoundTests()
    for e in pairs(layers) do if e.boundTest then E.StopBoundEffect(e);E.SyncBoundEffect(e) end end
end
function E.TestBoundEffect(side,art,index)
    if not E.devMode or InCombatLockdown() then return false end
    E.StopBoundTests()
    for e in pairs(layers) do
        if e.setKey==E.editorSet and e.side==side and e.castArt==art and e.addedIndex==index and usable(e) then
            local b=e.boundConfig
            return play(e,(b.kind=="success" or b.kind=="pulse") and b.duration or 3,true)
        end
    end
    return false
end

E.StopCastEffectTests=E.StopBoundTests
E.TestCastEffect=E.TestBoundEffect
