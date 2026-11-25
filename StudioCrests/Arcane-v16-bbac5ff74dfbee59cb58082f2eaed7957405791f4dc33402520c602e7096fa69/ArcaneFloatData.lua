local _, E = ...

local function positionNativeCanvas(canvas)
    local artwork = canvas.artwork
    local offset = 0
    if artwork then
        local phase = E.GetArtworkPhase(artwork)
        if phase then
            local rising = phase < 3
            local leg = artwork.legs[rising and 1 or 2]
            local progress = leg.GetSmoothProgress and leg:GetSmoothProgress()
            if not progress then
                local t = (phase % 3) / 3
                progress = t*t*(3-2*t)
            end
            offset = artwork.host:GetHeight() * .012 * (rising and (2*progress-1) or (1-2*progress))
        end
    end
    local y = canvas.restY + offset
    if canvas.lastY ~= y then
        canvas:SetPoint("CENTER", canvas.anchor, "CENTER", 0, y)
        canvas.lastY = y
    end
end

local function useNativeCanvas(entry, canvas, artwork, width, height)
    local host = artwork and artwork.host
    if canvas.artwork ~= artwork then
        canvas.artwork = artwork
        if host and not canvas.watchedHosts[host] then
            canvas.watchedHosts[host] = true
            host:HookScript("OnHide", function()
                if canvas.artwork == artwork then canvas:Hide() end
            end)
            host:HookScript("OnShow", function()
                if canvas.artwork == artwork then canvas:Show() end
            end)
        end
    end
    if canvas.widthAtAnchor ~= width or canvas.heightAtAnchor ~= height then
        canvas:SetSize(width, height)
        canvas.widthAtAnchor, canvas.heightAtAnchor = width, height
    end
    canvas.restY = 30 * entry.art:GetWidth() / 225
    local level = (host or entry.frame):GetFrameLevel()+1
    if canvas:GetFrameLevel() ~= level then canvas:SetFrameLevel(level) end
    canvas:SetAlpha(host and host:GetAlpha() or entry.alpha)
    canvas:SetShown(not host or host:IsShown())
    positionNativeCanvas(canvas)
end

-- Keep native sprites outside the translated artwork subtree. Anchor once
-- per rendered frame using the existing hover phase. Desktop already
-- evaluates the artwork transform once for its entire render tree.
function E.GetCustomEffectCanvas(entry, width, height)
    entry = entry.customEffectOwner or entry
    local artwork = entry.mageReboot and entry.mageReboot.enabled and entry.mageReboot or entry.druidSister
    local host = artwork and artwork.enabled and artwork.host
    if not Desktop then
        local canvas = entry.customEffectCanvas
        if not canvas then
            canvas = CreateFrame("Frame", nil, entry.frame)
            canvas:EnableMouse(false)
            canvas.anchor = entry.art
            canvas.watchedHosts = {}
            canvas:SetScript("OnUpdate", positionNativeCanvas)
            entry.customEffectCanvas = canvas
        end
        useNativeCanvas(entry, canvas, host and artwork, width, height)
        return canvas
    end

    local parent = host or entry.frame
    local anchor = host or entry.art
    local bottom = (anchor:GetHeight()-height)/2
    if not host then bottom = bottom + 30*entry.art:GetWidth()/225 end

    local canvas = entry.customEffectCanvas
    if not canvas then
        canvas = CreateFrame("Frame", nil, parent)
        canvas:EnableMouse(false)
        entry.customEffectCanvas = canvas
    elseif canvas:GetParent() ~= parent then
        canvas:SetParent(parent)
    end
    if canvas.anchor ~= anchor or canvas.widthAtAnchor ~= width or canvas.heightAtAnchor ~= height
        or canvas.bottomAtAnchor ~= bottom then
        canvas:ClearAllPoints()
        canvas:SetSize(width, height)
        canvas:SetPoint("BOTTOM", anchor, "BOTTOM", 0, bottom)
        canvas.anchor,canvas.widthAtAnchor,canvas.heightAtAnchor,canvas.bottomAtAnchor = anchor,width,height,bottom
    end
    -- The segmented hosts already carry the crest's opacity.
    canvas:SetAlpha(host and 1 or entry.alpha)
    return canvas
end

function E.AnchorCustomEffect(entry, effect, width, height, x, y)
    local canvas = E.GetCustomEffectCanvas(entry, width, height)
    if effect:GetParent() ~= canvas then
        local level = effect:GetFrameLevel()
        effect:SetParent(canvas)
        effect:SetFrameLevel(level)
        effect:ClearAllPoints()
    elseif effect.epicastBaselineX == x and effect.epicastBaselineY == y then
        return
    end
    effect:SetPoint("CENTER", canvas, "TOPLEFT", x, y)
    effect.epicastBaselineX,effect.epicastBaselineY = x,y
end

local _, E = ...
if not E.SetupCustomEffects and E.CreateStudioConfig then
do
local function loadModule(...)
local _, E=...
local legacyNames={
    rejuvenationPrecast="RejuvPrecast",
    arcaneSeal="ArcaneOrbitSeal",
}
-- Older Restoration deliveries omitted timing metadata. These are the
-- exact cel counts of their native 48 FPS clips.
local impactStages={
    rejuvImpact1={playStart=24/48,hold=54/48,playEnd=66/48},
    rejuvImpact2={playStart=42/48,hold=40/48,playEnd=62/48},
    restorationImpact={playStart=24/48,hold=28/48,playEnd=92/48},
}
local limits={
    size={100,5,500},opacity={100,0,100},x={0,-1268,1268},y={0,-1268,1268},
    angle={0,-360,360},period={32,1,180},depth={0,-32,32},
}

function E.CustomEffectName(id,name)
    name=name:match("^%s*(.-)%s*$")
    if name:sub(1,3):upper()=="EC-" then return "EC-"..name:sub(4) end
    return "EC-"..(legacyNames[id] or name)
end

function E.ReadCustomEffectDefinitions()
    local result={}
    for crest,definitions in pairs(E.DesktopCustomEffects or {}) do
        local entries={}
        for _,effect in ipairs(definitions) do
            if type(effect)=="table" and type(effect.id)=="string" and effect.id~=""
                and type(effect.name)=="string" and effect.name:find("%S") then
                local source=type(effect.defaults)=="table" and effect.defaults or {}
                local defaults={enabled=source.enabled~=false,rotate=source.rotate~=false,
                    reverse=source.reverse==true,mirror=source.mirror==true}
                for key,spec in pairs(limits) do defaults[key]=E.Number(source[key],unpack(spec)) end
                for _,key in ipairs({"playStart","hold","playEnd"}) do
                    if type(source[key])=="boolean" then defaults[key]=source[key] end
                end
                local anchor=type(effect.anchor)=="string" and effect.anchor or nil
                if not anchor and crest=="MAGE:arcane" and effect.id=="arcaneSeal" then anchor="scroll" end
                local previewSeconds=E.Number(effect.previewSeconds,nil,.1,60)
                local stages=not previewSeconds and crest=="DRUID:restoration" and impactStages[effect.id] or nil
                if stages then previewSeconds=stages.playStart+stages.hold+stages.playEnd end
                entries[effect.id]={name=E.CustomEffectName(effect.id,effect.name),defaults=defaults,anchor=anchor,
                    libraryOnly=effect.libraryOnly==true,previewSeconds=previewSeconds,previewStages=stages}
            end
        end
        if next(entries) then result[crest]=entries end
    end
    return result
end

end
loadModule(...)
end
do
local function loadModule(...)
local _, E = ...

-- Each matched signal owns a clock and a render slot. The common spell router
-- still matches game events for both effects and artwork; only effects fan out.
function E.CreateCustomEffectVoices(D, api)
    local voices={}
    local serial=0
    local function schedule(entry)
        local state=entry.desktopCustom
        if not state or state.queued or state.drawing then return end
        state.queued=true
        C_Timer.After(0,function()
            state.queued=nil
            if entry.desktopCustom==state and entry.config and entry.frame:IsVisible() then
                if entry.customEffectRenderers and next(entry.customEffectRenderers) then
                    voices.draw(entry,entry.config,function()
                        for id,renderer in pairs(entry.customEffectRenderers) do
                            E.RenderCustomEffectInstances(entry,state.crest,id,renderer)
                        end
                    end)
                elseif entry.preview then E.ScheduleStudioPreview()
                else voices.draw(entry,entry.config,E.ApplyStudioArtwork) end
            end
        end)
    end

    local function retire(driver,voice,cancelled)
        if not voice then return end
        voice.active=false
        voice.cancelled=cancelled
        driver.voices[voice]=nil
        if driver.test==voice then driver.test=nil end
        schedule(driver.entry)
    end

    local function start(driver,duration)
        serial=serial+1
        local voice={driver=driver,active=true,generation=driver.generation,serial=serial}
        driver.voices[voice]=true
        if duration then C_Timer.After(duration,function()
            if voice.active then retire(driver,voice) end
        end) end
        schedule(driver.entry)
        return voice
    end

    local function cancel(driver)
        driver.generation=driver.generation+1
        for voice in pairs(driver.voices) do retire(driver,voice,true) end
        driver.sustain,driver.bursts={},{}
        driver.idle,driver.test=nil,nil
        driver.loopTimer=nil
    end

    local function clear(entry)
        local state=entry.desktopCustom
        if not state then return end
        entry.desktopCustom=nil
        entry.customEffectRenderers=nil
        E.SetArtworkSignalController(state,nil)
        for _,driver in pairs(state.drivers) do cancel(driver) end
        for _,pool in pairs(entry.customEffectPools or {}) do
            for _,slot in ipairs(pool) do
                if slot.frame then slot.frame:Hide() end
                slot.voice=nil
            end
        end
    end

    local function syncSignals(state,isActive,isBurst,key,reset)
        local now=GetTime()
        for _,keyID in ipairs(state.ordered) do
            local driver=state.drivers[keyID]
            if reset then cancel(driver)
            elseif driver.enabled then
                for i,binding in ipairs(driver.bindings) do
                    local kind=binding.kind
                    if kind=="success" or kind=="pulse" then
                        if isBurst and isBurst(binding) then
                            local past=driver.bursts[i]
                            local fresh=not past or (kind=="success" and key and key~=past.key)
                                or (now-past.time>.05 and (not key or kind=="pulse"))
                            if fresh then
                                driver.bursts[i]={key=key,time=now}
                                start(driver,binding.duration)
                            end
                        end
                    else
                        local signal=driver.sustain[i]
                        local on=isActive(binding)
                        local event=D.customActivationKind==kind and D.customActivationKey
                        if signal and (not on or (event and signal.key~=event)) then
                            retire(driver,signal)
                            driver.sustain[i]=nil
                        end
                        if on and not driver.sustain[i] then
                            signal=start(driver)
                            signal.key=event
                            driver.sustain[i]=signal
                        end
                    end
                end
            end
        end
    end

    local function enableBridge()
        if voices.bridge then return end
        voices.bridge=true
        local artwork=E.SyncRestorationSignals
        function E.SyncRestorationSignals(controller,...)
            if controller.customEffects then return syncSignals(controller,...) end
            return artwork(controller,...)
        end
    end

    local function sync(entry,config)
        local previous=D.customContext
        D.customContext=entry
        local crest=E.GetCrestBakeKey(config)
        local layers=api.layers(crest)
        local state=entry.desktopCustom
        if state and (state.crest~=crest or not layers) then clear(entry);state=nil end
        if not layers then D.customContext=previous;return end
        entry.config=config
        if not state then
            state={customEffects=true,host=entry.frame,animate=true,crest=crest,drivers={},ordered={}}
            entry.desktopCustom=state
        end
        local combined,changed={},false
        for key,driver in pairs(state.drivers) do
            if not layers[key] or not api.added(layers[key]) then
                cancel(driver)
                state.drivers[key]=nil
                changed=true
            end
        end
        for key,layer in pairs(layers) do
            if api.added(layer) then
                local driver=state.drivers[key]
                local bindings=api.bindings(layer)
                local enabled=config.effects~=false and api.enabled(layer)
                local signature={tostring(enabled)}
                for _,binding in ipairs(bindings) do
                    signature[#signature+1]=table.concat({binding.kind,#binding.spell,binding.spell,binding.duration},"|")
                end
                signature=table.concat(signature,";")
                if not driver then
                    driver={layer=layer,entry=entry,voices={},sustain={},bursts={},generation=0}
                    state.drivers[key]=driver
                end
                if driver.signature~=signature then
                    cancel(driver)
                    driver.enabled,driver.bindings,driver.signature=enabled,bindings,signature
                    changed=true
                end
                if enabled then
                    for _,binding in ipairs(bindings) do combined[#combined+1]=binding end
                end
            end
        end
        if changed then
            state.ordered={}
            for key in pairs(state.drivers) do state.ordered[#state.ordered+1]=key end
            table.sort(state.ordered)
            enableBridge()
            E.SetArtworkSignalController(state,combined)
        end
        D.customContext=previous
        return state
    end

    voices.schedule=schedule

    function voices.stopTests(entry)
        for _,driver in pairs(entry and entry.desktopCustom and entry.desktopCustom.drivers or {}) do
            if driver.test then retire(driver,driver.test,true) end
        end
    end

    function voices.test(entry,layer,which)
        local driver=entry.desktopCustom and entry.desktopCustom.drivers[layer.instanceID]
        if not driver or not driver.enabled then return false end
        if #driver.bindings==0 then
            if driver.idle then retire(driver,driver.idle,true);driver.idle=nil end
        else
            local binding=driver.bindings[which or 1]
            if not binding then return false end
            voices.stopTests(entry)
            local timed=binding.kind=="success" or binding.kind=="pulse"
            driver.test=start(driver,timed and binding.duration or 3)
        end
        return true
    end

    local function syncIdle(entry,state)
        for _,key in ipairs(state.ordered) do
            local driver=state.drivers[key]
            local hasSignal=false
            for voice in pairs(driver.voices) do
                if voice~=driver.idle then hasSignal=true;break end
            end
            local layer=driver.layer
            local loop=driver.enabled and not hasSignal and api.loop(entry,layer)
            local period=loop and api.period(layer)
            local idle=driver.enabled and not hasSignal and
                (#driver.bindings==0 or api.held(entry,layer) or loop)
            if idle then
                if not driver.idle then driver.idle=start(driver) end
            elseif driver.idle then
                retire(driver,driver.idle,true)
                driver.idle=nil
            end
            if driver.loopPeriod~=period then driver.loopPeriod=period;driver.loopTimer=nil end
            if period and not driver.loopTimer then
                local token={}
                driver.loopTimer=token
                C_Timer.After(period,function()
                    if driver.loopTimer~=token then return end
                    driver.loopTimer=nil
                    retire(driver,driver.idle,true);driver.idle=nil
                    schedule(entry)
                end)
            end
        end
    end

    function voices.draw(entry,config,draw)
        local state=entry.desktopCustom
        local old=D.customContext
        D.customContext=entry
        if state then state.drawing=true;syncIdle(entry,state) end
        draw(entry,config)
        if state then state.drawing=nil end
        api.native(entry)
        D.customContext=old
    end

    local function targetFor(entry,id,pool)
        if #pool==0 then return entry end
        return setmetatable({customEffectOwner=entry},{
            __index=function(_,key)
                if key~=id then return entry[key] end
            end,
        })
    end

    function E.RenderCustomEffectInstances(entry,crest,id,apply)
        if entry.libraryPreview then
            entry.libraryInstanceIDs=entry.libraryInstanceIDs or {}
            entry.libraryInstanceIDs[id]=true
            local frame=apply(entry)
            if type(frame)=="table" or type(frame)=="userdata" then
                E.RegisterCustomEffectPreviewFrame(entry,id,frame)
            end
            return
        end
        local state=entry.desktopCustom
        if state and state.crest==crest then
            entry.customEffectRenderers=entry.customEffectRenderers or {}
            entry.customEffectRenderers[id]=apply
        end
        local wanted={}
        if state and state.crest==crest then
            for _,driver in pairs(state.drivers) do
                if driver.layer.effectID==id then
                    for voice in pairs(driver.voices) do wanted[voice]=true end
                end
            end
        end
        entry.customEffectPools=entry.customEffectPools or {}
        local pool=entry.customEffectPools[id] or {}
        entry.customEffectPools[id]=pool
        local function render(slot,voice,active)
            local previous=D.customVoice
            D.customVoice={crest=crest,id=id,settings=voice and api.settings(voice.driver.layer,not active,
                voice==voice.driver.idle and api.held(entry,voice.driver.layer) and entry.pendingPlacement) or nil}
            local frame=apply(slot.target)
            if type(frame)=="table" or type(frame)=="userdata" then slot.frame=frame end
            api.native(slot.target,id)
            D.customVoice=previous
        end
        for _,slot in ipairs(pool) do
            local voice=slot.voice
            if voice and wanted[voice] then
                render(slot,voice,true)
                wanted[voice]=nil
            elseif voice then
                local driver=voice.driver
                local retained=state and state.drivers[driver.layer.instanceID]==driver and driver.enabled
                    and driver.generation==voice.generation and not voice.cancelled
                if retained and slot.frame and slot.frame:IsShown() then render(slot,voice,false) end
                if not retained or not slot.frame or not slot.frame:IsShown() then
                    render(slot,nil)
                    slot.voice=nil
                end
            end
        end
        local pending={}
        for voice in pairs(wanted) do pending[#pending+1]=voice end
        table.sort(pending,function(a,b)return a.serial<b.serial end)
        for _,voice in ipairs(pending) do
            local slot
            for _,candidate in ipairs(pool) do
                if not candidate.voice then slot=candidate;break end
            end
            if not slot then
                slot={target=targetFor(entry,id,pool)}
                pool[#pool+1]=slot
            elseif slot.frame then
                render(slot,nil)
            end
            slot.voice=voice
            render(slot,voice,true)
        end
    end

    local update,play,stop=E.UpdateEffects,E.PlayEffects,E.StopEffects
    function E.UpdateEffects(entry,config)
        if sync(entry,config) then voices.draw(entry,config,update)
        else update(entry,config) end
    end
    function E.PlayEffects(entry)
        local config=entry.config
        if config and not entry.preview and not entry.desktopCustom and sync(entry,config) then
            voices.draw(entry,config,function(entry,c)
                local hasSegments=entry.restorationSegments~=nil
                play(entry)
                if not hasSegments then E.ApplyStudioArtwork(entry,c) end
            end)
        else
            local previous=D.customContext
            D.customContext=entry
            play(entry)
            D.customContext=previous
        end
    end
    function E.StopEffects(entry)
        clear(entry)
        stop(entry)
    end
    local handle=E.HandleBoundEvent
    function E.HandleBoundEvent(event,unit,guid,...)
        local player=(not issecretvalue or not issecretvalue(unit)) and unit=="player"
        local cast=event=="UNIT_SPELLCAST_START"
        local channel=event=="UNIT_SPELLCAST_CHANNEL_START"
        if player and (cast or channel or event=="UNIT_SPELLCAST_SUCCEEDED")
            or event=="SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
            E.SuspendCustomPlacementPreview(true)
        end
        if player and (cast or channel) then
            D.customActivationKind=cast and "cast" or "channel"
            D.customActivationKey=(not issecretvalue or not issecretvalue(guid)) and guid or nil
        end
        handle(event,unit,guid,...)
        D.customActivationKind,D.customActivationKey=nil,nil
    end

    local stopTests=E.StopBoundTests
    function E.StopBoundTests()
        local window=E.EffectLibrary.window
        if window then voices.stopTests(window.crestPreview) end
        stopTests()
    end
    return voices
end

end
loadModule(...)
end
do
local function loadModule(...)
-- Pack-owned effects use the same layer, controls and spell driver in both Studios.
local _, E=...
if E.SetupCustomEffects then return end
local D=Desktop or {}
local placement={trailSize="size",trailAngle="angle",trailX="x",trailY="y",trailOpacity="opacity"}
local boxRanges={trailSize={5,500},trailAngle={-360,360},trailX={-1268,1268},trailY={-1268,1268}}
local makeLayers, instanceLayers
local voiceRuntime

local function settings(crest,id)
    local state=D.customDraft
    if D.customContext and not D.customContext.preview then state=E.CustomEffectBakes end
    local entries=state and state[crest]
    return entries and entries[id]
end

local function library(crest)
    if not D.customDraft then return end
    if not D.customLayers then D.customLayers=makeLayers(E.ReadCustomEffectDefinitions()) end
    return D.customLayers[crest]
end

local function field(layer,key)
    local overrides=settings(layer.crest,layer.instanceID)
    if overrides and overrides[key]~=nil then return overrides[key] end
    return layer.defaults[key]
end

local function edit(layer,key,value)
    local crest,id=layer.crest,layer.instanceID
    local entries=D.customDraft[crest] or {}
    local overrides=entries[id] or {}
    if value==layer.defaults[key] then value=nil end
    overrides[key]=value
    entries[id]=next(overrides) and overrides or nil
    D.customDraft[crest]=next(entries) and entries or nil
end

local function bindings(layer)
    local overrides=settings(layer.crest,layer.instanceID)
    return overrides and overrides.bindings or {}
end

local function placementPreview(entry,layer)
    return entry.preview and entry.placementLayerID==layer.id and not D.customPlacementSuspended
end

local function loopIsEnabled(layer)
    local crest=D.customPreviewLoops[layer.crest]
    return crest and crest[layer.instanceID] or false
end

local function setLoop(layer,enabled)
    local crest=D.customPreviewLoops[layer.crest] or {}
    crest[layer.instanceID]=enabled or nil
    D.customPreviewLoops[layer.crest]=next(crest) and crest or nil
end

local function loopPreview(entry,layer)
    return entry.preview and not D.previewGameView and loopIsEnabled(layer)
end

local function loopPeriod(layer)
    if layer.previewStages then
        local seconds=0
        for key,length in pairs(layer.previewStages) do
            if field(layer,key)~=false then seconds=seconds+length end
        end
        return seconds>0 and seconds or nil
    end
    if layer.previewSeconds then return layer.previewSeconds end
    local phases=E.RejuvenationPrecastLengths
    if phases and layer.effectID=="rejuvenationPrecast" and not field(layer,"hold") then
        local frames=(field(layer,"playStart") and phases.intro or 0)+(field(layer,"playEnd") and phases.ending or 0)
        if frames>0 then return frames/48 end
    end
end

function E.SuspendCustomPlacementPreview(stopTest)
    local window=E.EffectLibrary.window
    if stopTest and window then voiceRuntime.stopTests(window.crestPreview) end
    if D.customPlacementSuspended then return end
    D.customPlacementSuspended=true
    if window and window.crestPreview.desktopCustom then voiceRuntime.schedule(window.crestPreview) end
end

local function effectSettings(layer,hidden,pending)
    local overrides=settings(layer.crest,layer.instanceID)
    if not overrides or overrides.added~=true then return end
    local result=E.Copy(layer.defaults)
    for key,value in pairs(overrides) do
        if layer.defaults[key]~=nil then result[key]=value end
    end
    for key,value in pairs(pending or {}) do
        if placement[key] then result[placement[key]]=value end
    end
    if hidden then result.enabled=false end
    return result
end

function E.GetCustomEffectSettings(crest,id)
    local voice=D.customVoice
    if voice and voice.crest==crest and voice.id==id then return voice.settings end
    local layers=library(crest)
    local layer=layers and layers[id]
    if not layer then return end
    local preview=D.customContext
    if preview and preview.libraryPreview then
        if preview.libraryEffect~=layer or preview.libraryReset then return end
        return E.Copy(layer.defaults)
    end
    local state=preview and preview.desktopCustom
    local driver=state and state.crest==crest and state.drivers[id]
    local held=driver and placementPreview(preview,layer)
    local hidden=preview and ((preview.config and preview.config.effects==false)
        or #bindings(layer)>0 and not (driver and next(driver.voices)))
    return effectSettings(layer,hidden,held and preview.pendingPlacement)
end

-- Facing is local to the sprite. The crest still owns placement and spin.
function E.GetCustomEffectFlip(crestFlip)
    local voice=D.customVoice
    local settings=voice and voice.settings
    return (crestFlip==true)~=(settings and settings.mirror==true or false)
end

function E.GetLegacyCustomEffectSettings(crest,id)
    local selected=E.GetCustomEffectSettings(crest,id)
    if selected then return selected end
    local layers=library(crest)
    local layer=layers and layers[id]
    if not layer then return end
    local inactive=E.Copy(layer.defaults)
    inactive.enabled=false
    return inactive
end
if Desktop then D.GetCustomEffectSettings=E.GetLegacyCustomEffectSettings end

local function makeLayer(crest,id,data,number)
    local instanceID=number and (id.."#"..number) or id
    local layer={id="custom:"..instanceID,kind="effect",custom=true,effectID=id,instanceID=instanceID,
        crest=crest,name=(data.assetName or data.name)..(number and (" · "..number) or ""),
        assetName=data.assetName or data.name,index="custom:"..instanceID,
        defaults=data.defaults,anchor=data.anchor,previewSeconds=data.previewSeconds,previewStages=data.previewStages}
    layer.row=setmetatable({customLayer=layer,fileID="Custom effect",animation=0},{
        __index=function(_,key)
            if key=="behavior" then return #bindings(layer)>0 and "bound" or "static" end
            if key=="binding" then local list=bindings(layer);return #list==1 and list[1] or nil end
            if key=="bindings" then local list=bindings(layer);return #list>1 and list or nil end
            if layer.defaults[key]~=nil or placement[key] then return field(layer,placement[key] or key) end
        end,
        __newindex=function(_,key,value)
            if key=="enabled" or placement[key] then edit(layer,placement[key] or key,value) end
        end,
    })
    return layer
end

makeLayers=function(descriptors)
    local result={}
    for crest,effects in pairs(descriptors) do
        local layers={}
        for id,data in pairs(effects) do layers[id]=makeLayer(crest,id,data) end
        result[crest]=layers
    end
    return result
end

instanceLayers=function(crest)
    local assets=library(crest)
    if not assets then return end
    local layers={}
    for id,layer in pairs(assets) do layers[id]=layer end
    local state=D.customDraft
    if D.customContext and not D.customContext.preview then state=E.CustomEffectBakes end
    local copies=D.customCopies[crest] or {}
    D.customCopies[crest]=copies
    for key,override in pairs(state and state[crest] or {}) do
        local id,number
        if type(key)=="string" then id,number=key:match("^([^#]+)#(%d+)$") end
        if id and assets[id] and override.added==true and tonumber(number)>=2 then
            local copy=copies[key] or makeLayer(crest,id,assets[id],number)
            copies[key],layers[key]=copy,copy
        end
    end
    return layers
end

local function layerByID(layers,id)
    if layers and type(id)=="string" then return layers[id:match("^custom:(.+)$")] end
end

function E.CustomLibraryEffects(c)
    local crest=c and E.GetCrestBakeKey(c)
    local items={}
    for _,layer in pairs(library(crest) or {}) do
        items[#items+1]=layer
    end
    table.sort(items,function(a,b)return a.name<b.name or a.name==b.name and a.id<b.id end)
    return items
end
function E.CustomEffectIsAdded(layer)
    local selected=settings(layer.crest,layer.instanceID)
    return selected and selected.added==true or false
end
function E.DuplicateCustomEffect(layer, fromLibrary)
    if InCombatLockdown() then return end
    local entries=D.customDraft[layer.crest] or {}
    local id,number=layer.effectID,2
    while entries[id.."#"..number] and entries[id.."#"..number].added do number=number+1 end
    local key=id.."#"..number
    local copy=not fromLibrary and E.Copy(entries[layer.instanceID]) or {}
    copy.added=true
    entries[key]=copy
    D.customDraft[layer.crest]=entries
    return "custom:"..key
end

function E.AddCustomLibraryEffect(layer)
    if InCombatLockdown() then return end
    if E.CustomEffectIsAdded(layer) then return E.DuplicateCustomEffect(layer,true) end
    edit(layer,"added",true)
    return layer.id
end

local function adaptModel(E)
    local getLayers,editEffects=E.GetStudioLayers,E.EditAddedEffects
    local setBindings,moveLayer=E.SetEffectBindings,E.MoveStudioLayer
    function E.GetStudioLayers(c)
        local layers=getLayers(c)
        for i=#layers,1,-1 do
            if layers[i].installedCustom then table.remove(layers,i) end
        end
        local custom=instanceLayers(E.GetCrestBakeKey(c))
        if not custom then return layers end
        local ranks={}
        local topArtwork
        for _,layer in ipairs(layers) do
            ranks[layer.id]=layer.rank
            if layer.kind=="artwork" then topArtwork=layer.rank end
        end
        local fallback=topArtwork or #layers
        for _,layer in pairs(custom) do
            if E.CustomEffectIsAdded(layer) then
                layer.rank=(ranks[layer.anchor] or fallback)+.5+field(layer,"depth")
                layers[#layers+1]=layer
            end
        end
        table.sort(layers,function(a,b)
            if a.rank==b.rank then return a.id<b.id end
            return a.rank<b.rank
        end)
        return layers
    end
    function E.EditAddedEffects(c)
        local rows=editEffects(c)
        local crest=E.GetCrestBakeKey(c)
        if library(crest) and not getmetatable(rows) then
            setmetatable(rows,{__index=function(_,id)
                if type(id)~="string" or id:sub(1,7)~="custom:" then return end
                local layer=layerByID(instanceLayers(crest),id)
                return layer and layer.row
            end})
        end
        return rows
    end
    function E.SetEffectBindings(row,list)
        if not row.customLayer then return setBindings(row,list) end
        local layer=row.customLayer
        local previous={}
        for _,binding in ipairs(bindings(layer)) do previous[binding.spell:lower()]=true end
        local nextBindings=E.Copy(list)
        if layer.previewSeconds then
            for _,binding in ipairs(nextBindings) do
                if not previous[binding.spell:lower()] then binding.duration=layer.previewSeconds end
            end
        end
        edit(layer,"bindings",#nextBindings>0 and nextBindings or nil)
    end
    function E.MoveStudioLayer(c,id,delta)
        local layer=layerByID(instanceLayers(E.GetCrestBakeKey(c)),id)
        if not layer then return moveLayer(c,id,delta) end
        local depth=field(layer,"depth")+delta
        if depth>=-32 and depth<=32 then edit(layer,"depth",depth);return true end
    end
end

function E.RegisterCustomEffectPreviewFrame(entry,id,frame)
    if not frame or not entry.libraryPreview or not entry.libraryEffect or entry.libraryEffect.effectID~=id then return end
    entry.libraryFrames=entry.libraryFrames or {}
    if entry.libraryFrames[frame] then return end
    entry.libraryFrames[frame]=true
    if frame.SetIgnoreParentAlpha then frame:SetIgnoreParentAlpha(true) end
end

local function clearLibraryFrames(entry)
    for frame in pairs(entry.libraryFrames or {}) do
        if frame.SetIgnoreParentAlpha then frame:SetIgnoreParentAlpha(false) end
    end
    entry.libraryFrames=nil
end

-- The earliest delivered packs used entry fields for their effect frames.
local function registerDeliveredPreview(entry,layer)
    local seal=entry.arcaneFloat and entry.arcaneFloat.seal
    local frame=layer.effectID=="arcaneSeal" and seal and seal.frame or entry[layer.effectID]
    if (type(frame)=="table" or type(frame)=="userdata") and frame.GetParent then
        E.RegisterCustomEffectPreviewFrame(entry,layer.effectID,frame)
    end
end

local corners={{-1,1},{-1,-1},{1,1},{1,-1}}
local function rotateNativeTexture(texture,pivot,degrees)
    if not texture.SetVertexOffset then return end
    local w,h=texture:GetSize()
    local angle=-math.rad(degrees%360)
    local state=texture.epicastNativeAngle
    if state and state[1]==angle and state[2]==w and state[3]==h and state[4]==pivot[1] and state[5]==pivot[2] then
        return
    end
    local c,s=math.cos(angle),math.sin(angle)
    local offsetX,offsetY=(.5-pivot[1])*w,(pivot[2]-.5)*h
    for i,corner in ipairs(corners) do
        local x,y=corner[1]*w/2+offsetX,corner[2]*h/2+offsetY
        texture:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
    end
    texture.epicastNativeAngle={angle,w,h,pivot[1],pivot[2]}
end

local function nativeTransforms(entry,id)
    if Desktop then return end
    local seal=entry.arcaneSeal or entry.arcaneFloat and entry.arcaneFloat.seal
    if (not id or id=="arcaneSeal") and seal and seal.settings and seal.clock.pivot then
        -- Arcane's own animation group supplies the continuous spin.
        rotateNativeTexture(seal.texture,seal.clock.pivot,seal.settings.angle)
    end
    local precast=entry.rejuvenationPrecast
    if (id and id~="rejuvenationPrecast") or not precast or not precast.rotation then return end
    local function update(frame)
        local clock=frame.rotation
        local age=clock.elapsed or 0
        if clock.startedAt then age=age+math.max(0,GetTime()-clock.startedAt) end
        local angle=clock.angle+age*360*clock.direction/clock.period
        for _,voice in pairs(frame.voices) do
            if voice.texture:IsShown() then rotateNativeTexture(voice.texture,clock.pivot,angle) end
        end
    end
    if not precast.epicastNativeSpin then
        precast:HookScript("OnUpdate",update)
        precast.epicastNativeSpin=true
    end
    update(precast)
end

function E.RenderCustomLibraryPreview(entry,stage,source,layer,restart)
    if not layer or not source then
        if entry.frame:IsShown() then E.StopEffects(entry);entry.frame:Hide() end
        clearLibraryFrames(entry)
        entry.libraryEffect=nil
        return
    end
    if entry.libraryEffect and (entry.libraryEffect~=layer or restart) then
        if entry.libraryEffect~=layer then clearLibraryFrames(entry) end
        local saved=D.customContext
        D.customContext=entry
        entry.libraryReset=true
        E.ApplyStudioArtwork(entry,entry.config)
        entry.libraryReset=nil
        D.customContext=saved
    end
    local c=E.Copy(source)
    local w,h,cx,cy=E.GetCapGeometry(c,c.flip)
    entry.config=c
    entry.libraryEffect=layer
    entry.canvas:SetSize(stage:GetSize())
    entry.frame:SetSize(w,h)
    entry.frame:SetScale(math.min((stage:GetWidth()-38)/math.max(w,1),(stage:GetHeight()-32)/math.max(h,1)))
    entry.frame:SetPoint("CENTER",entry.canvas,"CENTER",0,0)
    local artWidth=225*E.CrestScale(c.size)
    entry.art:SetSize(artWidth,artWidth)
    entry.art:ClearAllPoints()
    entry.art:SetPoint("CENTER",entry.frame,"CENTER",-cx,-cy)
    -- Keep the anchors and animation drivers alive beneath the preview.
    entry.frame:SetAlpha(0)
    entry.frame:Show()
    local saved=D.customContext
    D.customContext=entry
    E.UpdateDruidSisters(entry,c);E.UpdateMageReboot(entry,c);E.ApplyStudioArtwork(entry,c)
    D.customContext=saved
    registerDeliveredPreview(entry,layer)
    nativeTransforms(entry)
end

local function adaptControls(E)
    local create=E.CreateStudioConfig
    function E.CreateStudioConfig(p,page)
        local U=E.StudioUI
        local s=create(p,page)
        local select=s.Select
        function s.Select(...)
            D.customPlacementSuspended=false
            select(...)
        end
        local playbackLabels={}
        local modelLabels={["Main animation ID"]=true,["Intro seconds"]=true,["End seconds"]=true}
        local regions=s.pages.playback.GetRegions and {s.pages.playback:GetRegions()} or Mock.frames
        for _,widget in ipairs(regions) do
            local kind=widget.GetObjectType and widget:GetObjectType() or widget.kind
            if kind=="FontString" and widget:GetParent()==s.pages.playback and modelLabels[widget:GetText()] then
                playbackLabels[#playbackLabels+1]=widget
            end
        end
        local standardRanges={}
        local function wheel(box,delta)
            local l,c=s.Target()
            if not l or not box:IsEnabled() or not s.Flush() then return end
            local step=IsShiftKeyDown and IsShiftKeyDown() and 10 or 1
            local n=tonumber(box:GetText())+delta*step
            box.apply(l,c,math.max(box.low,math.min(box.high,n)));s.Changed()
        end
        for key,range in pairs(boxRanges) do
            local b=s.inputs[key]
            standardRanges[key]={b.low,b.high}
            b:SetScript("OnMouseWheel",wheel)
        end
        for key in pairs(placement) do
            local slider=s.inputs[key].slider
            local setValue=slider.SetValue
            function slider:SetValue(value)
                setValue(self,value)
                -- The chevrons step from the child slider, which can lag the
                -- displayed field when the parent is synchronized.
                if self.Slider:GetValue()~=value then self.Slider:SetValue(value) end
            end
        end
        local function custom()
            local layer=s.Target()
            return layer and layer.custom and layer or nil
        end
        s.previewLoop=U.Button(s.pages.playback,"Loop",516,-115,104,function()
            local layer=custom()
            if not layer or InCombatLockdown() or not s.Flush() then return end
            setLoop(layer,not loopIsEnabled(layer))
            s.Refresh()
            E.RefreshStudioPreview()
        end)
        local function save(key,value)
            local layer=custom()
            if not layer or InCombatLockdown() then return end
            edit(layer,key,value);s.Changed()
        end
        local function number(parent,title,x,y,low,high,key,whole)
            local input=U.Input(parent,x+169,y+7,102)
            input.customLabel=U.Label(parent,title,x,y,165)
            input.low,input.high,input.integer=low,high,whole
            input.apply=function(layer,_,value) edit(layer,key,whole and value or math.floor(value*100+.5)/100) end
            s.inputs[key]=input
            input:SetScript("OnTextChanged",function(self,user)
                if not user or InCombatLockdown() then return end
                local layer,c=s.Target()
                if not layer or not layer.custom then return end
                self.owner,self.layerID,self.dirty=c,layer.id,true
                E.UpdateSaveButton()
            end)
            input:SetScript("OnEnterPressed",function()if s.Flush() then s.Changed() end end)
            input:SetScript("OnEditFocusLost",function(self)
                if self.dirty and not s.flushing then s.flushing=true;s.Flush();s.flushing=false end
            end)
            input:SetScript("OnEscapePressed",function(self)
                self.dirty=false;self.owner=nil;self:ClearFocus();s.Refresh();E.UpdateSaveButton()
            end)
            return input
        end
        local depth=number(s.pages.placement,"Draw depth",326,-84,-32,32,"depth",true)
        local mirror=U.Check(s.pages.placement,"Flip horizontally",326,-147,function(self)
            if s.Flush() then save("mirror",self:GetChecked()==true) end
        end)
        local spin=U.Check(s.pages.playback,"Spin",0,-14,function(self)save("rotate",self:GetChecked()==true)end)
        local period=number(s.pages.playback,"Spin period (seconds)",0,-65,1,180,"period")
        local reverse=U.Check(s.pages.playback,"Counterclockwise",326,-65,function(self)save("reverse",self:GetChecked()==true)end)
        local stages={}
        for i,spec in ipairs({{"playStart","Play start"},{"hold","Hold"},{"playEnd","Play end"}}) do
            local key=spec[1]
            stages[key]=U.Check(s.pages.playback,spec[2],(i-1)*163,-40,function(self)
                if s.Flush() then save(key,self:GetChecked()==true) end
            end)
        end

        local function clickHandler(widget)
            return widget.GetScript and widget:GetScript("OnClick") or widget.scripts.OnClick
        end
        local openPlacement=clickHandler(s.tabs.placement)
        s.tabs.placement:SetScript("OnClick",function(...)
            D.customPlacementSuspended=false
            openPlacement(...)
        end)
        local oldEnabled=clickHandler(s.enabled)
        s.enabled:SetScript("OnClick",function(self)
            if custom() then save("enabled",self:GetChecked()==true) else oldEnabled(self) end
        end)
        local reset=U.Button(s.pages.placement,"Reset effect",331,-113,210,function()
            local layer=custom()
            if not layer or not s.Flush() then return end
            local overrides=settings(layer.crest,layer.instanceID)
            for key in pairs(layer.defaults) do
                if overrides and overrides[key]~=nil then edit(layer,key,nil) end
            end
            s.Changed()
        end)
        local duplicate=U.Button(s.pages.placement,"Duplicate effect",155,-147,156,function()
            local layer=custom()
            if not layer or not s.Flush() then return end
            local id=E.DuplicateCustomEffect(layer)
            if id then s.EndQuickBind();s.Select(id);s.Changed();s.Reveal() end
        end)
        s.customTools={spin=spin,reverse=reverse,mirror=mirror,reset=reset,duplicate=duplicate,stages=stages}
        local oldRemove=clickHandler(s.remove)
        s.remove:SetScript("OnClick",function(...)
            local layer=custom()
            if not layer then return oldRemove(...) end
            if InCombatLockdown() then return end
            s.DiscardInputs();s.EndQuickBind();E.StopBoundTests()
            local entries=D.customDraft[layer.crest]
            entries[layer.instanceID]={added=false}
            setLoop(layer,false)
            s.selectedID=nil;s.noLayer=true
            s.Changed()
        end)
        local oldSequence=clickHandler(s.sequenceMenu)
        s.sequenceMenu:SetScript("OnClick",function(...)
            local layer,c=s.Target()
            if not layer or not layer.custom then return oldSequence(...) end
            local binding=bindings(layer)[s.bindingIndex]
            for _,spell in ipairs(E.GetStudioState(c).spells) do
                if binding and spell.spell:lower()==binding.spell:lower() then
                    s.spells.revealSpell=spell.id;s.SelectSpell(spell.id,true);return
                end
            end
        end)
        local oldTest=clickHandler(s.test)
        s.test:SetScript("OnClick",function(...)
            local layer=custom()
            if not layer then return oldTest(...) end
            E.SuspendCustomPlacementPreview()
            D.performing=true;E.RefreshStudioPreview()
            if voiceRuntime.test(p.crestPreview,layer,s.bindingIndex) then
                E.RefreshStudioPreview()
            else
                s.animationSummary:SetText("Enable crest effects and this layer to test its spell response.")
            end
        end)
        local refresh=s.Refresh
        function s.Refresh()
            local c=E.GetEffectLibraryTarget()
            local crest=c and E.GetCrestBakeKey(c)
            refresh()
            local layer=custom()
            local enabled=layer~=nil and not InCombatLockdown()
            for key,base in pairs(standardRanges) do
                local b=s.inputs[key]
                local range=layer and boxRanges[key] or base
                if b.low~=range[1] or b.high~=range[2] then
                    b.low,b.high=range[1],range[2]
                    b.syncingSlider=true
                    b.slider:Init(tonumber(b:GetText()) or range[1],range[1],range[2],range[2]-range[1],{})
                    b.syncingSlider=false
                end
            end
            for _,widget in ipairs({depth,spin,period,reverse,mirror}) do widget:SetShown(layer~=nil) end
            for key,widget in pairs(stages) do
                local supported=layer and layer.defaults[key]~=nil
                widget:SetShown(supported==true)
                widget:SetEnabled(enabled and supported)
                if supported then widget:SetChecked(field(layer,key)) end
            end
            -- Labels created alongside the custom numeric inputs share their visibility.
            depth.customLabel:SetShown(layer~=nil)
            period.customLabel:SetShown(layer~=nil)
            for _,widget in ipairs(playbackLabels) do widget:SetShown(not layer) end
            for _,widget in ipairs({s.inputs.animation,s.intro,s.outro,s.inputs.introDuration,s.inputs.outroDuration,s.lock,s.axis}) do
                widget:SetShown(not layer)
            end
            reset:SetShown(layer~=nil)
            duplicate:SetShown(layer~=nil);duplicate:SetEnabled(enabled)
            s.previewLoop:SetShown(layer~=nil)
            s.animationSummary:SetWidth(layer and 324 or 437)
            if not layer then
                s.test:SetText("Test response")
                local current=s.Target()
                if current and current.kind=="effect" and library(crest) then
                    local state=E.GetStudioState(c)
                    s.up:SetEnabled(not InCombatLockdown() and current.rank<#state.order)
                end
                return
            end
            local depthValue,rotating=field(layer,"depth"),field(layer,"rotate")
            spin:SetChecked(rotating);reverse:SetChecked(field(layer,"reverse"))
            depth:SetEnabled(enabled);spin:SetEnabled(enabled)
            mirror:SetChecked(field(layer,"mirror"));mirror:SetEnabled(enabled)
            period:SetEnabled(enabled and rotating);reverse:SetEnabled(enabled and rotating)
            s.up:SetEnabled(enabled and depthValue<32);s.down:SetEnabled(enabled and depthValue>-32)
            local overrides=settings(crest,layer.instanceID)
            local edited=false
            for key in pairs(layer.defaults) do
                if overrides and overrides[key]~=nil then edited=true;break end
            end
            reset:SetEnabled(enabled and edited)
            s.notice:SetText("Save session keeps custom layer settings and bindings in Studio.")
            s.sequenceMenu:SetText("Edit spell mappings")
            s.sequenceMenu:SetEnabled(enabled and #bindings(layer)>0 and not s.quick)
            local bound=#bindings(layer)>0
            local looping=loopIsEnabled(layer)
            s.previewLoop:SetText(looping and "Loop: On" or "Loop: Off")
            s.previewLoop:SetEnabled(enabled and (looping or layer.row.enabled~=false and c.effects~=false))
            s.test:SetText(bound and "Test response" or "Replay effect")
            s.test:SetEnabled(enabled and layer.row.enabled~=false and c.effects~=false)
            s.stop:SetEnabled(enabled and bound)
            s.animationSummary:SetText(layer.previewSeconds and "One-shot effect. Replay it here or bind it to a spell." or layer.defaults.hold~=nil and
                "Play start on activation, loop Hold while active, and play end on release." or
                "Uses the animation delivered with this layer.")
        end
        return s
    end
end

function E.SetupCustomEffects(descriptors,draft)
    D.customPreviewLoops={}
    D.customCopies={}
    D.customLayers=descriptors and makeLayers(descriptors) or nil
    D.customDraft=draft or E.Copy(E.CustomEffectBakes or {})
    if not Desktop then
        E.installedCustomEffects=true
        local begin,commit,changed=E.Begin,E.Commit,E.AuthorHasChanges
        local checkpoint=E.Copy(D.customDraft)
        function E.Begin()
            if not E.draft then D.customDraft=E.Copy(checkpoint) end
            begin()
        end
        function E.Commit()
            checkpoint=E.Copy(D.customDraft);commit()
        end
        function E.AuthorHasChanges(equal)
            return changed(equal) or not equal(D.customDraft,checkpoint)
        end
    end
    adaptModel(E)
    adaptControls(E)
    voiceRuntime=E.CreateCustomEffectVoices(D,{layers=instanceLayers,added=E.CustomEffectIsAdded,
        bindings=bindings,enabled=function(layer)return field(layer,"enabled")~=false end,
        held=placementPreview,loop=loopPreview,period=loopPeriod,settings=effectSettings,native=nativeTransforms})
end

end
loadModule(...)
end
do
local function loadModule(...)
local _, E=...
local U=E.StudioUI
local V={}
E.EffectLibrary=V
E.EffectAnimations={}

local function setup(p)
    local library=p.pages.library
    local custom=CreateFrame("Frame",nil,library)
    custom:SetAllPoints(library)
    local list=U.Box(custom,0,0,366,618)
    local detail=U.Box(custom,378,0,810,618)
    U.Label(list,"FIND A CUSTOM EFFECT",12,-13,335,U.gold,"GameFontNormal")
    local search=U.Input(list,17,-43,333)
    search:SetMaxLetters(150)
    U.Label(list,"Search by effect name",12,-75,330)
    local title=U.Label(detail,"",18,-19,770,U.gold,"GameFontNormalLarge")
    local description=U.Label(detail,"",18,-65,700)
    local stage=U.Box(detail,18,-102,774,395)
    local entry=E.CreateStudioPreview(stage)
    entry.libraryPreview=true
    p.customStage=stage
    local destination=U.Label(detail,"",18,-582,550)
    local count=U.Label(list,"",70,-584,225)
    local rows,matches={}, {}
    local page,selected=1,nil
    local replayToken
    local function preview(restart)
        local active=p:IsShown() and p.tab=="library" and selected
        if not active then
            replayToken=nil
            E.RenderCustomLibraryPreview(entry,stage,nil,nil)
            return
        end
        if InCombatLockdown() then return end
        if restart or entry.libraryEffect~=selected then replayToken=nil end
        E.RenderCustomLibraryPreview(entry,stage,E.GetEffectLibraryTarget(),selected,restart)
        if selected.previewSeconds and not replayToken then
            local token={}
            replayToken=token
            C_Timer.After(selected.previewSeconds,function()
                if replayToken==token then preview(true) end
            end)
        end
    end
    local replay=U.Button(detail,"Replay",18,-515,112,function()preview(true)end)
    local render
    local prev=U.Button(list,"<",10,-574,46,function()page=page-1;render()end)
    local forward=U.Button(list,">",310,-574,46,function()page=page+1;render()end)
    local add=U.Button(detail,"Add effect layer",562,-572,230,function()
        if not selected or not E.FlushStudioInputs() then return end
        local layerID=E.AddCustomLibraryEffect(selected)
        if not layerID then return end
        local config=p.layerControls
        config.EndQuickBind();config.filter="all";config.tab="placement"
        E.PreviewLibraryChange()
        p.SelectTab("config");config.Select(layerID)
    end)
    local function choose(item)
        selected=item
        search:ClearFocus()
        render()
    end
    for i=1,10 do
        rows[i]=U.Row(list,8,-107-(i-1)*46,350,function(row)choose(row.item)end)
    end
    render=function()
        local c,side,group=E.GetEffectLibraryTarget()
        local query=search:GetText():lower()
        matches={}
        local found=false
        for _,effect in ipairs(E.CustomLibraryEffects(c)) do
            if effect.name:lower():find(query,1,true) then
                matches[#matches+1]=effect
                if effect==selected then found=true end
            end
        end
        if not found then selected=nil end
        local maxPage=math.max(1,math.ceil(#matches/10))
        page=math.max(1,math.min(page,maxPage))
        for i,row in ipairs(rows) do
            local effect=matches[(page-1)*10+i]
            row.item=effect;row:SetShown(effect~=nil)
            if effect then
                row.title:SetText(effect.name)
                row.detail:SetText(E.CustomEffectIsAdded(effect) and "Added to this crest" or "Available")
                U.RowSelected(row,effect==selected)
                row:SetEnabled(not InCombatLockdown())
            end
        end
        count:SetText(#matches.." effects · "..page.."/"..maxPage)
        prev:SetEnabled(page>1);forward:SetEnabled(page<maxPage)
        local added=selected and E.CustomEffectIsAdded(selected)
        title:SetText(selected and selected.name or (#matches==0 and "No custom effects for this crest" or "Select an effect"))
        description:SetText(selected and (added and "This effect is in Layers under Artwork Config." or
            "Add this effect to the selected crest, then adjust placement, playback and spell bindings in Artwork Config.") or "")
        destination:SetText(c and "Destination: "..E.CrestLabel(E.draft,group,side) or "")
        add:SetText(added and "Add another layer" or "Add effect layer")
        add:SetEnabled(selected~=nil and not InCombatLockdown())
        replay:SetEnabled(selected~=nil and not InCombatLockdown())
        search:SetEnabled(not InCombatLockdown())
        preview()
    end
    search:SetScript("OnTextChanged",function()page=1;render()end)
    search:SetScript("OnEnterPressed",function()local effect=matches[(page-1)*10+1];if effect then choose(effect) end end)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel",function(_,delta)page=page-delta;render()end)

    p:HookScript("OnHide",function()preview()end)
    p.customLibrary={rows=rows,add=add,search=search,entry=entry,replay=replay,refreshPreview=preview,refresh=render,
        title=title,description=description}
    if Desktop then
        function p.customLibrary.results()return matches,selected end
        function p.customLibrary.select(id)
            if p.tab~="library" or InCombatLockdown() then return end
            for _,effect in ipairs(matches) do
                if effect.id==id then choose(effect);return end
            end
        end
    end
end

-- Keep the established studio layout and authoring controls with a single library.
local WIDTH,HEIGHT,MAPPING_WIDTH=1220,790,328
local function createWindow()
    local p=U.Box(UIParent,0,0,WIDTH,HEIGHT,"EpicastEffectStudio")
    tinsert(UISpecialFrames,"EpicastEffectStudio")
    p:ClearAllPoints();p:SetPoint("CENTER");p:SetFrameStrata("DIALOG");p:SetFrameLevel(100)
    p:EnableMouse(true);p:SetMovable(true);p:SetClampedToScreen(true);p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart",p.StartMoving);p:SetScript("OnDragStop",p.StopMovingOrSizing);p:Hide()
    U.Label(p,"EPICAST · EFFECT STUDIO",16,-16,355,U.gold,"GameFontNormalLarge")
    p.authorClass=U.Button(p,"Build class",386,-11,240,function(self)if E.FlushStudioInputs()then E.OpenAuthoringClassMenu(self)end end)
    p.crest=U.Button(p,"Select crest",638,-11,350,function(self)if E.FlushStudioInputs()then E.OpenCrestMenu(self)end end)
    p.close=U.Button(p,"Close",1104,-11,100,function()if E.FlushStudioInputs()then p:Hide()end end)
    p.close:ClearAllPoints();p.close:SetPoint("TOPRIGHT",p,"TOPRIGHT",-16,-11)
    p.pages={};p.tabs={};p.tab="library";p.previewZoom=1
    for _,key in ipairs({"library","config"})do
        local page=CreateFrame("Frame",nil,p)
        page:SetPoint("TOPLEFT",16,-96);page:SetSize(1188,618);p.pages[key]=page
    end
    function p.SelectTab(key)
        if InCombatLockdown() or not E.FlushStudioInputs() then return end
        if key=="library" then p.layerControls.EndQuickBind();p.layerControls.spells.mappingID=nil end
        E.StopBoundTests();p.tab=key;p.RefreshTarget()
    end
    p.tabs.library=U.Tab(p,"Effect Library",nil,16,-59,function()p.SelectTab("library")end)
    p.tabs.config=U.Tab(p,"Artwork Config",p.tabs.library,0,0,function()p.SelectTab("config")end)
    local config=E.CreateStudioConfig(p,p.pages.config);config.crest=p.crest
    setup(p)
    p.addMore=U.Button(p,"Find another effect",16,-729,184,function()p.SelectTab("library")end)
    p.export=U.Button(p,"Copy crest bake",212,-729,160,function()if config.Flush()then E.ShowCrestBakeExport()end end)
    p.cancel=U.Button(p,"Discard changes",896,-729,148,function()
        config.EndQuickBind();config.DiscardInputs();E.CancelEffectStudio();p.RefreshTarget()
    end)
    p.saveAll=U.Button(p,"Save session",1056,-729,148,function()
        if config.Flush()then E.SaveEffectStudio();p.RefreshTarget()end
    end)
    p.saveAll:ClearAllPoints();p.saveAll:SetPoint("TOPRIGHT",p,"TOPRIGHT",-16,-729)
    p.cancel:ClearAllPoints();p.cancel:SetPoint("TOPRIGHT",p.saveAll,"TOPLEFT",-12,0)
    p.notice=U.Label(p,"Save keeps game Studio edits for this session.",16,-767,1180)
    function p.RefreshTarget()
        local c,side,group=E.GetEffectLibraryTarget()
        if not c then p:Hide();return end
        local editable=not InCombatLockdown()
        p.authorClass:SetText("Class: "..E.ClassSpecs[E.ActiveClass()].name.."  v");p.authorClass:SetEnabled(editable)
        p.crest:SetText(E.SetLabels[group].." · "..E.CrestLabel(E.draft,group,side).."  v");p.crest:SetEnabled(editable)
        for key,page in pairs(p.pages)do page:SetShown(p.tab==key);U.SelectTab(p.tabs[key],p.tab==key)end
        config.Refresh()
        local width=WIDTH+(config.spells.mapping:IsShown() and MAPPING_WIDTH or 0)
        p:SetWidth(width);p.pages.config:SetWidth(width-32)
        p:SetScale(math.max(.25,math.min(1,(UIParent:GetWidth()-24)/width,(UIParent:GetHeight()-24)/HEIGHT)))
        p.saveAll:SetEnabled(E.CanSave());p.cancel:SetEnabled(editable)
        p.export:SetEnabled(editable);p.addMore:SetEnabled(editable)
        p.customLibrary.refresh();E.RefreshStudioPreview()
    end
    for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do
        p:RegisterEvent(event)
    end
    p:SetScript("OnEvent",function()if p:IsShown()then p.RefreshTarget()end end)
    p:HookScript("OnHide",function()
        config.EndQuickBind();config.DiscardInputs();config.spells.mappingID=nil
        config.spells.input:ClearFocus();p.customLibrary.search:ClearFocus()
        E.StopBoundTests();E.HideStudioPreview()
    end)
    return p
end
function V.Open()
    if not E.GetEffectLibraryTarget() or InCombatLockdown() then return end
    V.window=V.window or createWindow()
    V.window:Show();V.window.RefreshTarget()
end
function V.RefreshTarget()if V.window and V.window:IsShown()then V.window.RefreshTarget()end end
function V.Close()if V.window then V.window:Hide()end end
function V.IsAvailable()return false end

function E.CleanEffectBake(bake)
    local cleaned={effects={}}
    if bake.studio then
        local studio=E.Copy(bake.studio)
        local order={}
        for _,id in ipairs(studio.order or {})do
            if studio.artwork and studio.artwork[id] then order[#order+1]=id end
        end
        studio.order=order
        -- A failed custom-layer bind in the older editor could leave an
        -- effect ID in the artwork map of a saved desktop draft.
        for id in pairs(studio.artworkBindings or {}) do
            if type(id)=="string" and id:sub(1,7)=="custom:" then studio.artworkBindings[id]=nil end
        end
        cleaned.studio=studio
    end
    return cleaned
end

function E.SetupCustomLibrary()
    local bakes={}
    for key,bake in pairs(E.CrestBakes or {}) do bakes[key]=E.CleanEffectBake(bake) end
    for class,specs in pairs(E.ClassSpecs) do
        for _,slot in ipairs(specs.slots)do
            local key=class..":"..slot[1]
            bakes[key]=bakes[key] or {}
        end
    end
    for _,side in ipairs({"left","right"}) do
        local key="RESOURCE:"..side
        bakes[key]=bakes[key] or {}
    end
    E.CrestBakes=bakes
    E.AddedEffectDefaults={arcaneScroll={{}}}
end

end
loadModule(...)
end
E.SetupCustomEffects()
E.SetupCustomLibrary()
end
do
local function loadModule(...)
local _, E = ...
if E.ChannelPlusStableReplacement then return end
local alreadyRegistered = E.InstallArtworkChannelPlus ~= nil
E.ChannelPlusStableReplacement = true
local response = "channelPlus"
local restoration = "DRUID:restoration"
local declarations, idleContacts = {}, {}
local function banksFor(crest)
    local banks = E.ArtworkChannelPlusBanks and E.ArtworkChannelPlusBanks[crest]
    return banks or (crest==restoration and E.RestorationChannelPlusBanks or nil)
end
local function supports(crest,id)
    local layers = declarations[crest]
    return layers and layers[id]
end
local controllers = setmetatable({}, {__mode="k"})
local assetRoot = "Interface\\AddOns\\Epicast\\Media\\"
local joinSeconds = .10

if not alreadyRegistered then
    table.insert(E.ArtworkBindingKinds,2,{response,"Channel+"})
end
if not Desktop then
    local createSpells = E.CreateStudioSpells
    function E.CreateStudioSpells(panel,page,layers)
        local spells = createSpells(panel,page,layers)
        for _,row in ipairs(spells.mappingRows) do
            row.impact:ClearAllPoints()
            row.impact:SetPoint("TOPLEFT",210,-22)
            row.channelPlus=E.StudioUI.Check(row,"Channel+",105,-22,function(button)
                if InCombatLockdown() or layers.quick or not layers.Flush() then return end
                local config=E.GetEffectLibraryTarget()
                local spell=config and E.GetStudioSpell(config,spells.mappingID)
                if spell and spells.selected==spells.mappingID then
                    if E.SetStudioArtworkMapping(config,row.layerID,spell.spell,response,spells.trigger,
                        button:GetChecked()==true) then
                        layers.Changed()
                    else
                        spells.RefreshMapping()
                    end
                end
            end)
        end
        local refresh=spells.RefreshMapping
        function spells.RefreshMapping(...)
            refresh(...)
            if not spells.mapping:IsShown() then return end
            local config=E.GetEffectLibraryTarget()
            local spell=config and E.GetStudioSpell(config,spells.mappingID)
            for _,row in ipairs(spells.mappingRows) do
                local button=row.channelPlus
                local layer=spell and row:IsShown() and supports(E.GetCrestBakeKey(config),row.layerID)
                    and E.FindStudioLayer(config,row.layerID)
                local linked
                if layer and layer.kind=="artwork" then
                    for _,binding in ipairs(layer.bindings or {}) do
                        if binding.spell:lower()==spell.spell:lower() then linked=binding;break end
                    end
                end
                button:SetShown(linked~=nil)
                if linked then
                    button:SetChecked(E.GetArtworkMapping(linked,response,spells.trigger)~=nil)
                    button:SetEnabled(not InCombatLockdown())
                end
            end
        end
        return spells
    end
end

local function validateBanks(crest,banks)
    local layersFound={}
    declarations[crest]=layersFound
    for size,layers in pairs(banks) do
        assert(type(size)=="number" and size>0 and size==math.floor(size),"Invalid Channel+ crest size")
        for id,track in pairs(layers) do
            assert(type(id)=="string" and id:match("^[A-Za-z][A-Za-z0-9_-]*$")
                and type(track.fps)=="number" and track.fps==math.floor(track.fps)
                and track.fps>=1 and track.fps<=120,"Invalid Channel+ layer or frame rate")
            assert(type(track.pages)=="table" and type(track.intro)=="table"
                and type(track.hold)=="table" and type(track.ending)=="table",
                "Channel+ needs atlas pages and three playback stages")
            layersFound[id]=true
            for _,page in ipairs(track.pages) do
                assert(type(page)=="string" and page:match("^[A-Za-z][A-Za-z0-9_]*%.tga$"),
                    "Invalid Channel+ atlas name")
            end
            assert(#track.intro>0 and #track.hold==track.fps and #track.ending>0,
                "Channel+ needs Intro, exactly one second of Hold, and End")
            assert(track.mode==nil or track.mode=="add" or track.mode=="replace","Invalid Channel+ mode")
            if track.mode=="replace" then
                local rect=track.rect
                assert(crest==restoration and type(rect)=="table" and #rect==4,
                    "Channel+ replacement requires a Restoration canvas rectangle")
                local x,y,w,h=unpack(rect)
                assert(type(x)=="number" and type(y)=="number" and type(w)=="number" and type(h)=="number"
                    and x>=0 and y>=0 and w>0 and h>0 and x+w<=1+1e-8 and y+h<=1+1e-8,
                    "Invalid Channel+ replacement rectangle")
            end
            local stages={track.intro,track.hold,track.ending}
            if track.matched~=nil then
                local matched=track.matched
                local peer=type(matched)=="table" and layers[matched.layer]
                assert(track.mode=="replace" and peer and peer~=track and peer.mode=="replace"
                    and peer.fps==track.fps,"Channel+ contact needs a different replacement layer at the same frame rate")
                local idle=matched.idle
                if idle~=nil then
                    assert(type(idle)=="table","Invalid Channel+ idle contact")
                    idleContacts[id]=true
                end
                for _,stage in ipairs({"intro","hold","ending"}) do
                    assert(type(matched[stage])=="table" and type(peer[stage])=="table"
                        and #matched[stage]==#track[stage] and #peer[stage]==#track[stage],
                        "Channel+ contact stages must match both replacement tracks")
                    stages[#stages+1]=matched[stage]
                    if idle then
                        assert(type(idle[stage])=="table" and #idle[stage]==#peer[stage],
                            "Channel+ idle contact stages must match the casting layer")
                        stages[#stages+1]=idle[stage]
                    end
                end
            end
            for _,stage in ipairs(stages) do
                for _,tile in ipairs(stage) do
                    local page,u,v,r,b=unpack(tile)
                    assert(#tile==5 and track.pages[page] and type(u)=="number" and type(v)=="number"
                        and type(r)=="number" and type(b)=="number" and u>=0 and v>=0 and r<=1 and b<=1 and u<r and v<b,
                        "Invalid Channel+ atlas coordinates")
                end
            end
        end
    end
end

local function restoreArtwork(state,nativeDrawn)
    if state.replacement then state.replacement:Hide() end
    if state.suppressed and not nativeDrawn then
        for art in pairs(state.suppressed) do art:Show() end
    end
    state.suppressed=nil
end

local function hide(state,nativeDrawn)
    if state.primary then state.primary:Hide();state.outgoing:Hide() end
    restoreArtwork(state,nativeDrawn)
    state.phase,state.posePhase,state.fromPhase,state.at = nil,nil,nil,nil
end

local function suppressArtwork(layer,state,nativeDrawn)
    -- The native renderer keeps evaluating its own responses and contacts.
    -- Suppress only the textures it selected for this layer on this draw.
    if nativeDrawn or not state.suppressed then state.suppressed={} end
    local function conceal(art)
        if art and art:IsShown() then
            state.suppressed[art]=true
            art:Hide()
        end
    end
    conceal(layer.idle)
    conceal(layer.action)
    conceal(layer.fabricIdle)
    conceal(layer.fabricAction)
    for _,part in ipairs(layer.parts or {}) do conceal(part) end
    for _,part in ipairs(layer.treantParts or {}) do conceal(part) end
end

local function getTrack(controller,id)
    local banks = banksFor(controller.crest or restoration)
    local layer = controller.layers[id]
    local bank = banks and banks[layer and layer.size or controller.size]
    return bank and bank[id]
end

local function cue(state,phase,now)
    state.fromPhase,state.fromIndex,state.fromAlpha = state.posePhase,state.poseIndex,state.poseAlpha
    state.phase,state.at = phase,now
end

local function texture(layer,rank,replace,parent)
    local art = (parent or layer.frame):CreateTexture(nil,"ARTWORK",nil,rank)
    if replace then
        art:SetBlendMode("BLEND")
        if art.SetDesaturation then art:SetDesaturation(E.DruidArtworkDesaturation or 0) end
    else
        art:SetAllPoints(layer.frame)
        art:SetBlendMode("ADD")
    end
    if art.SetBlockingLoadsRequested then art:SetBlockingLoadsRequested(true) end
    if art.SetSnapToPixelGrid then art:SetSnapToPixelGrid(false) end
    if art.SetTexelSnappingBias then art:SetTexelSnappingBias(0) end
    return art
end

local function paint(art,track,tile,alpha,flip,crest)
    if not tile or alpha<=0 then art:Hide();return end
    local media=E.ArtworkChannelPlusMedia
    local path = (media and media[crest or restoration] or assetRoot)..track.pages[tile[1]]
    if art.plusPage~=path then art:SetTexture(path);art.plusPage=path end
    if art.plusTile~=tile or art.plusFlip~=flip then
        local _,u,v,r,b = unpack(tile)
        art:SetTexCoord(E.UV({u,v,u,b,r,v,r,b},flip))
        art.plusTile,art.plusFlip = tile,flip
    end
    art:SetAlpha(alpha)
    art:Show()
end

local function replacementPose(state,track,now,wanted)
    local fps = track.fps
    if not state.phase then
        if not wanted then return end
        state.phase,state.at="playing",now
    elseif not wanted and state.phase=="playing" then
        state.phase,state.at="release",now
        state.releaseStage,state.releaseIndex=state.posePhase,state.poseIndex
        if state.releaseStage=="hold" then
            local backward=state.releaseIndex-1
            local forward=(fps-backward)%fps
            state.releaseSteps,state.releaseDirection=math.min(backward,forward),backward<=forward and -1 or 1
        end
    end
    local ticks=math.floor(math.max(0,now-state.at)*fps+1e-7)
    if state.phase=="playing" then
        if ticks<#track.intro then return "intro",1+ticks end
        return "hold",1+(ticks-#track.intro)%fps
    end
    if state.releaseStage=="intro" then
        -- Replay the already visible Intro poses back to its exact-rest cel.
        local index=state.releaseIndex-ticks
        if index>=1 then return "intro",index end
        return
    end
    if ticks<state.releaseSteps then
        return "hold",1+(state.releaseIndex-1+state.releaseDirection*ticks)%fps
    end
    local index=ticks-state.releaseSteps+1
    if index<=#track.ending then return "ending",index end
end

local function placeReplacement(controller,layer,art,rect)
    local width,height=controller.host:GetSize()
    local l,t,w,h=unpack(rect)
    if controller.flip then l=1-l-w end
    local x,y=l*width-layer.x,-t*height-layer.y
    w,h=w*width,h*height
    if art.plusX~=x or art.plusY~=y or art.plusW~=w or art.plusH~=h then
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT",layer.frame,"TOPLEFT",x,y)
        art:SetSize(w,h)
        art.plusX,art.plusY,art.plusW,art.plusH=x,y,w,h
    end
end

local function replacementTexture(controller,layer,state,rect)
    if Desktop then
        if not state.replacement then state.replacement=texture(layer,5,true) end
        placeReplacement(controller,layer,state.replacement,rect)
        return state.replacement
    end

    -- Keep replacement quads outside the animated artwork subtree. The
    -- shared canvas already contributes the crest hover exactly once.
    local width,height=controller.host:GetSize()
    local canvas=E.GetCustomEffectCanvas(controller.entry,width,height)
    local receiver=state.nativeReceiver
    if not receiver then
        receiver=CreateFrame("Frame",nil,canvas)
        receiver:EnableMouse(false)
        state.nativeReceiver=receiver
        state.replacement=texture(layer,5,true,receiver)
        state.replacement:SetAllPoints(receiver)
    end
    local l,t,w,h=unpack(rect)
    if controller.flip then l=1-l-w end
    local x,y=l*width+(layer.offset or 0), -t*height+(layer.lift or 0)
    w,h=w*width,h*height
    if receiver.plusW~=w or receiver.plusH~=h then
        receiver:SetSize(w,h)
        receiver.plusW,receiver.plusH=w,h
    end
    if receiver.plusX~=x or receiver.plusY~=y then
        receiver:SetPoint("TOPLEFT",canvas,"TOPLEFT",x,y)
        receiver.plusX,receiver.plusY=x,y
    end
    local level=layer.frame:GetFrameLevel()
    if receiver:GetFrameLevel()~=level then receiver:SetFrameLevel(level) end
    local alpha=layer.frame:GetAlpha()
    if receiver:GetAlpha()~=alpha then receiver:SetAlpha(alpha) end
    return state.replacement
end

local function artworkVisible(controller,layer)
    return controller.animate and layer and layer.enabled and layer.frame:IsVisible()
end

local function draw(controller,id,state,now,nativeDrawn)
    local layer = controller.layers[id]
    local track = getTrack(controller,id)
    if not track or not artworkVisible(controller,layer) then
        hide(state,nativeDrawn)
        return
    end
    if (layer.response and layer.response.kind=="impact") or (layer.isImpact and layer.isImpact()) then
        state.burst,state.testUntil = nil,nil
        hide(state,nativeDrawn)
        return
    end
    local wanted = state.sustained or (state.testUntil or 0)>now or (state.burst or 0)>now
    if track.mode=="replace" then
        state.posePhase,state.poseIndex=replacementPose(state,track,now,wanted)
        if not state.posePhase then state.phase,state.at=nil,nil end
        return
    end
    if wanted then
        if not state.phase or state.phase=="ending" then cue(state,"intro",now) end
    elseif state.phase and state.phase~="ending" then
        cue(state,"ending",now)
    end
    if not state.phase then return end

    local age = math.max(0,now-state.at)
    local fps = track.fps
    local introSeconds = #track.intro/fps
    local endSeconds = #track.ending/fps
    local phase = state.phase
    local index
    if phase=="ending" then
        if age>=endSeconds then hide(state);return end
        index = math.min(#track.ending,1+math.floor(age*fps+1e-7))
    elseif age<introSeconds then
        phase = "intro"
        index = math.min(#track.intro,1+math.floor(age*fps+1e-7))
    else
        phase = "hold"
        index = 1+math.floor((age-introSeconds)*fps+1e-7)%fps
    end
    if not state.primary then
        state.primary = texture(layer,5)
        state.outgoing = texture(layer,4)
    elseif state.primary:GetParent()~=layer.frame then
        for _,art in ipairs({state.primary,state.outgoing}) do
            art:SetParent(layer.frame)
            art:ClearAllPoints()
            art:SetAllPoints(layer.frame)
        end
    end
    local fade = phase=="ending" and math.min(joinSeconds,endSeconds/2) or joinSeconds
    local from = state.fromPhase and track[state.fromPhase][state.fromIndex]
    local weight = from and math.min(1,age/fade) or 1
    local alpha = phase=="ending" and math.min(1,(endSeconds-age)/fade) or 1
    paint(state.primary,track,track[phase][index],alpha*weight,controller.flip,controller.crest)
    paint(state.outgoing,track,from,(state.fromAlpha or 0)*(1-weight),controller.flip,controller.crest)
    if alpha*weight >= (state.fromAlpha or 0)*(1-weight) then
        state.posePhase,state.poseIndex,state.poseAlpha = phase,index,alpha*weight
    end
    if weight>=1 then state.fromPhase=nil end
end

local function render(controller,nativeDrawn)
    local layers = controllers[controller]
    if not layers then return end
    local now = GetTime()
    for id,state in pairs(layers) do draw(controller,id,state,now,nativeDrawn) end
    -- Use only the peer's own pose. A contact on an idle receiver never casts a shadow.
    for id,state in pairs(layers) do
        local track=getTrack(controller,id)
        if track and track.mode=="replace" then
            local layer=controller.layers[id]
            local phase,index=state.posePhase,state.poseIndex
            local matched=track.matched
            local peer=matched and layers[matched.layer]
            local peerLayer=peer and controller.layers[matched.layer]
            local peerPhase=peerLayer and peerLayer.opacity>0 and peer.posePhase
            local tile
            if phase then
                local source=peerPhase==phase and peer.poseIndex==index and matched or track
                tile=source[phase][index]
            elseif matched and matched.idle and peerPhase and artworkVisible(controller,layer)
                    and layer.opacity>0 and not layer.response then
                tile=matched.idle[peerPhase][peer.poseIndex]
            end
            if tile and (Desktop or controller.entry) then
                local art=replacementTexture(controller,layer,state,track.rect)
                paint(art,track,tile,1,controller.flip,controller.crest)
                suppressArtwork(layer,state,nativeDrawn)
            elseif state.suppressed then
                restoreArtwork(state,nativeDrawn)
            end
        end
    end
end

local function getState(controller,id)
    local layers = controllers[controller]
    if not layers then layers={};controllers[controller]=layers end
    if not layers[id] then layers[id]={bursts={}} end
    return layers[id]
end

local function stop(controller)
    for _,state in pairs(controllers[controller] or {}) do
        state.sustained,state.burst,state.testUntil,state.signature,state.bursts = nil,nil,nil,nil,{}
        hide(state)
    end
end

local function signals(controller,id,bindings,isActive,isBurst,key)
    local track = getTrack(controller,id)
    local state = controllers[controller] and controllers[controller][id]
    if not track or not controller.layers[id] or not controller.layers[id].enabled or not controller.animate then
        if state then state.sustained,state.burst,state.testUntil = nil,nil,nil;hide(state) end
        return
    end
    if not state and #bindings==0 then return end
    state = state or getState(controller,id)
    local signature={}
    for i,b in ipairs(bindings) do signature[i]=b.kind.."|"..b.spell end
    signature=table.concat(signature,"\n")
    if state.signature~=signature then
        state.signature,state.bursts,state.burst=signature,{},nil
    end
    state.sustained = false
    local now = GetTime()
    for i,b in ipairs(bindings) do
        if b.kind=="success" or b.kind=="pulse" then
            if isBurst and isBurst(b) then
                local old=state.bursts[i]
                if not old or now-old.time>.05 and (not key or key~=old.key or b.kind=="pulse") then
                    state.bursts[i]={time=now,key=key}
                    state.burst=now+#track.intro/track.fps+1
                end
            end
        elseif isActive and isActive(b) then state.sustained=true end
    end
end

-- A pack can register a frame for multipart or otherwise custom artwork.
-- The frame already carries the receiver's geometry, motion, opacity and rank.
function E.SetArtworkChannelPlusReceiver(entry,id,frame,size,isImpact)
    entry.channelPlusReceivers=entry.channelPlusReceivers or {}
    entry.channelPlusReceivers[id]={frame=frame,size=size,isImpact=isImpact}
end

local function receiver(entry,id)
    local custom=entry.channelPlusReceivers and entry.channelPlusReceivers[id]
    if custom then return custom end
    local artwork=entry.artworkLayers and entry.artworkLayers[id]
    local frost=entry.frostHalo
    if frost and frost.active and frost.layers[id] then
        return {frame=frost.layers[id].host,size=frost.root.textureSize}
    end
    if not artwork then return end
    local root=artwork.root or artwork
    local frame=artwork.segment and artwork.segment.frame or artwork.host
    if frame then return {frame=frame,size=root.textureSize} end
end

local function stopEntry(entry,keep)
    local controller=entry.channelPlusController
    if not controller then return end
    E.SetArtworkSignalController(controller,nil)
    controller.driver:Hide()
    stop(controller)
    if not keep then entry.channelPlusController=nil end
end

local function configure(entry,config)
    local crest=E.GetCrestBakeKey(config)
    -- Restoration's original renderer has native Channel and Impact. It is
    -- routed separately so the additive response sees the actual Impact state.
    local declared=crest~=restoration and declarations[crest]
    if not declared or not next(declared) or entry.libraryPreview then stopEntry(entry);return end
    local controller=entry.channelPlusController
    if controller and crest~=controller.crest then stopEntry(entry);controller=nil end
    if not controller then
        local driver=entry.channelPlusDriver or CreateFrame("Frame",nil,entry.frame)
        entry.channelPlusDriver=driver
        controller={plusOnly=true,crest=crest,host=entry.frame,driver=driver,layers={},preview=entry.preview}
        entry.channelPlusController=controller
        driver:SetScript("OnUpdate",function()render(controller)end)
    end
    controller.animate,controller.flip=config.effects~=false,config.flip
    local layers,bindings={},{}
    for _,layer in ipairs(E.GetStudioLayers(config)) do
        if layer.kind=="artwork" and declared[layer.id] then
            local target=receiver(entry,layer.id)
            if target then
                target.enabled=layer.settings.enabled~=false
                target.bindings={}
                if target.enabled then
                    for _,link in ipairs(layer.bindings or {}) do
                        for _,mapping in ipairs(link.mappings) do
                            if mapping.state==response then
                                local binding={spell=link.spell,kind=mapping.kind,state=response}
                                target.bindings[#target.bindings+1]=binding
                                bindings[#bindings+1]=binding
                            end
                        end
                    end
                end
                layers[layer.id]=target
            end
        end
    end
    controller.layers=layers
    if not controller.animate then stop(controller) end
    for id,target in pairs(layers) do
        if #target.bindings==0 then signals(controller,id,{},nil,nil,nil) end
    end
    E.SetArtworkSignalController(controller,controller.animate and bindings or nil)
    controller.driver:SetShown(controller.animate and next(layers)~=nil)
    render(controller)
end

function E.HasArtworkChannelPlusReceiver(entry,crest,id)
    if crest==restoration then
        local controller=entry.restorationSegments
        return controller and controller.layers[id]~=nil
    end
    return receiver(entry,id)~=nil
end

local installed
function E.InstallArtworkChannelPlus()
    if installed then return end
    installed=true
    for crest,banks in pairs(E.ArtworkChannelPlusBanks or {}) do validateBanks(crest,banks) end
    if not declarations[restoration] and E.RestorationChannelPlusBanks then
        validateBanks(restoration,E.RestorationChannelPlusBanks)
    end
    local getLayers,getStateOfCrest=E.GetArtworkLayers,E.GetStudioState
    function E.GetArtworkLayers(config)
        local source=getLayers(config)
        local available=declarations[E.GetCrestBakeKey(config)]
        local changed
        for i,layer in ipairs(source) do
            local enabled=available and available[layer.id]==true
            local index
            for j,state in ipairs(layer.states or {}) do if state==response then index=j;break end end
            if (enabled and not index) or (not enabled and index) then
                changed=changed or {unpack(source)}
                local copy=E.Copy(layer)
                copy.states=copy.states or {}
                if enabled then table.insert(copy.states,response) else table.remove(copy.states,index) end
                changed[i]=copy
            end
        end
        return changed or source
    end
    function E.GetStudioState(config)
        local state=getStateOfCrest(config)
        if declarations[E.GetCrestBakeKey(config)] and not state.artworkBindings then
            state=E.Copy(state);state.artworkBindings={}
        end
        return state
    end
    local applyArt,stopEffects,playEffects=E.ApplyStudioArtwork,E.StopEffects,E.PlayEffects
    function E.ApplyStudioArtwork(entry,config)
        local crest=E.GetCrestBakeKey(config)
        if entry.channelPlusReceiverCrest~=crest then
            entry.channelPlusReceiverCrest,entry.channelPlusReceivers=crest,nil
        end
        applyArt(entry,config)
        configure(entry,config)
    end
    function E.StopEffects(entry) stopEntry(entry,true);return stopEffects(entry) end
    function E.PlayEffects(entry)
        playEffects(entry)
        if entry.config then configure(entry,entry.config) end
    end

    local apply,sync,hideSegments = E.ApplyRestorationSegments,E.SyncRestorationSignals,E.HideRestorationSegments
    local test,stopTests = E.TestRestorationSegment,E.StopArtworkTests
    function E.SyncRestorationSignals(controller,isActive,isBurst,key,reset)
        if controller.customEffects then return sync(controller,isActive,isBurst,key,reset) end
        if controller.plusOnly then
            if reset then stop(controller);return end
            for id,layer in pairs(controller.layers) do signals(controller,id,layer.bindings,isActive,isBurst,key) end
            render(controller)
            return
        end
        local split = {}
        for id,layer in pairs(controller.layers) do
            local base,plus = {},{}
            for _,binding in ipairs(layer.bindings or {}) do
                local target = binding.state==response and plus or base
                target[#target+1]=binding
            end
            if #plus>0 then split[id]={original=layer.bindings,plus=plus};layer.bindings=base end
        end
        sync(controller,isActive,isBurst,key,reset)
        for id,entry in pairs(split) do controller.layers[id].bindings=entry.original end
        if reset then stop(controller);return end
        for id in pairs(declarations[restoration] or {}) do
            if controller.layers[id] then signals(controller,id,split[id] and split[id].plus or {},isActive,isBurst,key) end
        end
        render(controller)
    end
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active=apply(entry,config,artwork)
        local controller=active and entry.restorationSegments
        if controller and declarations[restoration] then
            controller.entry=entry
            if not controller.plusHook then
                controller.driver:HookScript("OnUpdate",function()render(controller,true)end)
                controller.plusHook=true
            end
            if not controller.animate then stop(controller)
            else
                for id in pairs(controllers[controller] or {}) do
                    local layer=controller.layers[id]
                    local bound=false
                    for _,binding in ipairs(layer and layer.bindings or {}) do
                        if binding.state==response then bound=true;break end
                    end
                    if not bound then signals(controller,id,{},nil,nil,nil) end
                end
            end
            for id in pairs(idleContacts) do
                if controller.layers[id] then getState(controller,id) end
            end
            render(controller,true)
        end
        return active
    end
    function E.HideRestorationSegments(entry)
        if entry.restorationSegments then stop(entry.restorationSegments) end
        return hideSegments(entry)
    end
    function E.TestRestorationSegment(entry,id,binding)
        if not binding or binding.kind~=response then return test(entry,id,binding) end
        local controller=entry.channelPlusController or entry.restorationSegments
        local layer=controller and controller.layers[id]
        local track=layer and getTrack(controller,id)
        if InCombatLockdown() or not entry.preview or not track or not controller.animate or not layer.enabled then
            return false
        end
        E.StopBoundTests()
        local state=getState(controller,id)
        local now=GetTime()
        state.testUntil=now+#track.intro/track.fps+1
        render(controller)
        return true
    end
    function E.StopArtworkTests()
        if stopTests then stopTests() end
        for controller,layers in pairs(controllers) do
            if controller.preview then
                local stopped=false
                for _,state in pairs(layers) do
                    if state.testUntil then
                        state.testUntil=nil
                        stopped=true
                    end
                end
                if stopped then render(controller) end
            end
        end
    end
end

-- The in-game library loads before delivered crest modules. Core's first
-- update installs the hooks after all renderers have declared their tracks.
if not Desktop and not alreadyRegistered then
    local update=E.UpdateEffects
    function E.UpdateEffects(...)
        E.InstallArtworkChannelPlus()
        return update(...)
    end
end

end
loadModule(...)
end
local _,E=...
E.ArcaneFloatData={["motion"]={["kirinTor"]={5.9,8.5,0.4},["shards"]={4.7,14.5,1.6},["shoulderFloaters"]={6.7,12.5,4.5},["scroll"]={7.3,8.5,3.1},["bannerFloaters"]={5.3,12.5,2.7}},["contactOffsets"]={-8.5,-8,-6,-4,-2,0,2,4,6,8,8.5},["banks"]={["192"]={{["group"]="foundation",["rect"]={11,12,181,98},["tiles"]={{1,0.001953125,0.00390625,0.16796875,0.171875}}},{["group"]="foundation",["rect"]={11,98,23,131},["tiles"]={{1,0.9189453125,0.505859375,0.9306640625,0.5703125}}},{["group"]="foundation",["rect"]={167,98,181,132},["tiles"]={{1,0.9794921875,0.353515625,0.9931640625,0.419921875}}},{["group"]="foundation",["rect"]={23,98,167,134},["tiles"]={{1,0.8349609375,0.353515625,0.9755859375,0.423828125},{1,0.001953125,0.505859375,0.142578125,0.576171875},{1,0.146484375,0.505859375,0.287109375,0.576171875},{1,0.291015625,0.505859375,0.431640625,0.576171875},{1,0.435546875,0.505859375,0.576171875,0.576171875},{1,0.580078125,0.505859375,0.720703125,0.576171875},{1,0.724609375,0.505859375,0.865234375,0.576171875},{1,0.001953125,0.583984375,0.142578125,0.654296875},{1,0.146484375,0.583984375,0.287109375,0.654296875},{1,0.291015625,0.583984375,0.431640625,0.654296875},{1,0.435546875,0.583984375,0.576171875,0.654296875},{1,0.580078125,0.583984375,0.720703125,0.654296875}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={9,120,31,156},["tiles"]={{1,0.869140625,0.505859375,0.890625,0.576171875}}},{["group"]="bannerFloaters",["rect"]={162,120,183,156},["tiles"]={{1,0.89453125,0.505859375,0.9150390625,0.576171875}}},{["group"]="body",["rect"]={22,112,78,114},["tiles"]={{2,0.935546875,0.52734375,0.990234375,0.5283203125}}},{["group"]="body",["rect"]={22,114,44,134},["tiles"]={{2,0.3056640625,0.47412109375,0.3271484375,0.48388671875}}},{["group"]="body",["rect"]={76,114,78,134},["tiles"]={{2,0.99609375,0.1865234375,0.998046875,0.1962890625}}},{["group"]="body",["rect"]={44,114,76,134},["tiles"]={{2,0.3310546875,0.47412109375,0.3623046875,0.48388671875},{2,0.3662109375,0.47412109375,0.3974609375,0.48388671875},{2,0.4013671875,0.47412109375,0.4326171875,0.48388671875},{2,0.4365234375,0.47412109375,0.4677734375,0.48388671875},{2,0.4716796875,0.47412109375,0.5029296875,0.48388671875},{2,0.5068359375,0.47412109375,0.5380859375,0.48388671875},{2,0.5419921875,0.47412109375,0.5732421875,0.48388671875},{2,0.5771484375,0.47412109375,0.6083984375,0.48388671875},{2,0.6123046875,0.47412109375,0.6435546875,0.48388671875},{2,0.6474609375,0.47412109375,0.6787109375,0.48388671875},{2,0.6826171875,0.47412109375,0.7138671875,0.48388671875},{2,0.7177734375,0.47412109375,0.7490234375,0.48388671875}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={22,134,78,189},["tiles"]={{2,0.12109375,0.30419921875,0.17578125,0.3310546875},{2,0.1796875,0.30419921875,0.234375,0.3310546875},{2,0.23828125,0.30419921875,0.29296875,0.3310546875},{2,0.296875,0.30419921875,0.3515625,0.3310546875},{2,0.35546875,0.30419921875,0.41015625,0.3310546875},{2,0.4140625,0.30419921875,0.46875,0.3310546875},{2,0.47265625,0.30419921875,0.52734375,0.3310546875},{2,0.53125,0.30419921875,0.5859375,0.3310546875},{2,0.58984375,0.30419921875,0.64453125,0.3310546875},{2,0.6484375,0.30419921875,0.703125,0.3310546875},{2,0.70703125,0.30419921875,0.76171875,0.3310546875},{2,0.765625,0.30419921875,0.8203125,0.3310546875},{2,0.82421875,0.30419921875,0.87890625,0.3310546875},{2,0.8828125,0.30419921875,0.9375,0.3310546875},{2,0.94140625,0.30419921875,0.99609375,0.3310546875},{2,0.001953125,0.33349609375,0.056640625,0.3603515625},{2,0.060546875,0.33349609375,0.115234375,0.3603515625},{2,0.119140625,0.33349609375,0.173828125,0.3603515625},{2,0.177734375,0.33349609375,0.232421875,0.3603515625},{2,0.236328125,0.33349609375,0.291015625,0.3603515625},{2,0.294921875,0.33349609375,0.349609375,0.3603515625},{2,0.353515625,0.33349609375,0.408203125,0.3603515625},{2,0.412109375,0.33349609375,0.466796875,0.3603515625},{2,0.470703125,0.33349609375,0.525390625,0.3603515625},{2,0.529296875,0.33349609375,0.583984375,0.3603515625},{2,0.587890625,0.33349609375,0.642578125,0.3603515625},{2,0.646484375,0.33349609375,0.701171875,0.3603515625},{2,0.705078125,0.33349609375,0.759765625,0.3603515625},{2,0.763671875,0.33349609375,0.818359375,0.3603515625},{2,0.822265625,0.33349609375,0.876953125,0.3603515625},{2,0.880859375,0.33349609375,0.935546875,0.3603515625},{2,0.939453125,0.33349609375,0.994140625,0.3603515625},{2,0.001953125,0.3623046875,0.056640625,0.38916015625},{2,0.060546875,0.3623046875,0.115234375,0.38916015625},{2,0.119140625,0.3623046875,0.173828125,0.38916015625},{2,0.177734375,0.3623046875,0.232421875,0.38916015625},{2,0.236328125,0.3623046875,0.291015625,0.38916015625},{2,0.294921875,0.3623046875,0.349609375,0.38916015625},{2,0.353515625,0.3623046875,0.408203125,0.38916015625},{2,0.412109375,0.3623046875,0.466796875,0.38916015625},{2,0.470703125,0.3623046875,0.525390625,0.38916015625},{2,0.529296875,0.3623046875,0.583984375,0.38916015625},{2,0.587890625,0.3623046875,0.642578125,0.38916015625},{2,0.646484375,0.3623046875,0.701171875,0.38916015625},{2,0.705078125,0.3623046875,0.759765625,0.38916015625},{2,0.763671875,0.3623046875,0.818359375,0.38916015625},{2,0.822265625,0.3623046875,0.876953125,0.38916015625},{2,0.880859375,0.3623046875,0.935546875,0.38916015625},{2,0.939453125,0.3623046875,0.994140625,0.38916015625},{2,0.001953125,0.39111328125,0.056640625,0.41796875},{2,0.060546875,0.39111328125,0.115234375,0.41796875},{2,0.119140625,0.39111328125,0.173828125,0.41796875},{2,0.177734375,0.39111328125,0.232421875,0.41796875},{2,0.236328125,0.39111328125,0.291015625,0.41796875},{2,0.294921875,0.39111328125,0.349609375,0.41796875},{2,0.353515625,0.39111328125,0.408203125,0.41796875},{2,0.412109375,0.39111328125,0.466796875,0.41796875},{2,0.470703125,0.39111328125,0.525390625,0.41796875},{2,0.529296875,0.39111328125,0.583984375,0.41796875},{2,0.587890625,0.39111328125,0.642578125,0.41796875},{2,0.646484375,0.39111328125,0.701171875,0.41796875},{2,0.705078125,0.39111328125,0.759765625,0.41796875},{2,0.763671875,0.39111328125,0.818359375,0.41796875},{2,0.822265625,0.39111328125,0.876953125,0.41796875}},["clip"]="left-banner"},{["group"]="body",["rect"]={114,112,169,114},["tiles"]={{2,0.001953125,0.53369140625,0.0556640625,0.53466796875}}},{["group"]="body",["rect"]={114,114,116,133},["tiles"]={{2,0.99609375,0.21630859375,0.998046875,0.2255859375}}},{["group"]="body",["rect"]={149,114,169,133},["tiles"]={{2,0.7529296875,0.47412109375,0.7724609375,0.4833984375}}},{["group"]="body",["rect"]={116,114,149,133},["tiles"]={{2,0.7763671875,0.47412109375,0.80859375,0.4833984375},{2,0.8125,0.47412109375,0.8447265625,0.4833984375},{2,0.8486328125,0.47412109375,0.880859375,0.4833984375},{2,0.884765625,0.47412109375,0.9169921875,0.4833984375},{2,0.9208984375,0.47412109375,0.953125,0.4833984375},{2,0.95703125,0.47412109375,0.9892578125,0.4833984375},{2,0.001953125,0.48876953125,0.0341796875,0.498046875},{2,0.0380859375,0.48876953125,0.0703125,0.498046875},{2,0.07421875,0.48876953125,0.1064453125,0.498046875},{2,0.1103515625,0.48876953125,0.142578125,0.498046875},{2,0.146484375,0.48876953125,0.1787109375,0.498046875},{2,0.1826171875,0.48876953125,0.21484375,0.498046875}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={113,133,170,189},["tiles"]={{2,0.931640625,0.0673828125,0.9873046875,0.0947265625},{2,0.931640625,0.09716796875,0.9873046875,0.12451171875},{2,0.931640625,0.126953125,0.9873046875,0.154296875},{2,0.931640625,0.15673828125,0.9873046875,0.18408203125},{2,0.400390625,0.1865234375,0.4560546875,0.2138671875},{2,0.4599609375,0.1865234375,0.515625,0.2138671875},{2,0.51953125,0.1865234375,0.5751953125,0.2138671875},{2,0.5791015625,0.1865234375,0.634765625,0.2138671875},{2,0.638671875,0.1865234375,0.6943359375,0.2138671875},{2,0.6982421875,0.1865234375,0.75390625,0.2138671875},{2,0.7578125,0.1865234375,0.8134765625,0.2138671875},{2,0.8173828125,0.1865234375,0.873046875,0.2138671875},{2,0.876953125,0.1865234375,0.9326171875,0.2138671875},{2,0.9365234375,0.1865234375,0.9921875,0.2138671875},{2,0.001953125,0.21630859375,0.0576171875,0.24365234375},{2,0.0615234375,0.21630859375,0.1171875,0.24365234375},{2,0.12109375,0.21630859375,0.1767578125,0.24365234375},{2,0.1806640625,0.21630859375,0.236328125,0.24365234375},{2,0.240234375,0.21630859375,0.2958984375,0.24365234375},{2,0.2998046875,0.21630859375,0.35546875,0.24365234375},{2,0.359375,0.21630859375,0.4150390625,0.24365234375},{2,0.4189453125,0.21630859375,0.474609375,0.24365234375},{2,0.478515625,0.21630859375,0.5341796875,0.24365234375},{2,0.5380859375,0.21630859375,0.59375,0.24365234375},{2,0.59765625,0.21630859375,0.6533203125,0.24365234375},{2,0.6572265625,0.21630859375,0.712890625,0.24365234375},{2,0.716796875,0.21630859375,0.7724609375,0.24365234375},{2,0.7763671875,0.21630859375,0.83203125,0.24365234375},{2,0.8359375,0.21630859375,0.8916015625,0.24365234375},{2,0.8955078125,0.21630859375,0.951171875,0.24365234375},{2,0.001953125,0.24560546875,0.0576171875,0.27294921875},{2,0.0615234375,0.24560546875,0.1171875,0.27294921875},{2,0.12109375,0.24560546875,0.1767578125,0.27294921875},{2,0.1806640625,0.24560546875,0.236328125,0.27294921875},{2,0.240234375,0.24560546875,0.2958984375,0.27294921875},{2,0.2998046875,0.24560546875,0.35546875,0.27294921875},{2,0.359375,0.24560546875,0.4150390625,0.27294921875},{2,0.4189453125,0.24560546875,0.474609375,0.27294921875},{2,0.478515625,0.24560546875,0.5341796875,0.27294921875},{2,0.5380859375,0.24560546875,0.59375,0.27294921875},{2,0.59765625,0.24560546875,0.6533203125,0.27294921875},{2,0.6572265625,0.24560546875,0.712890625,0.27294921875},{2,0.716796875,0.24560546875,0.7724609375,0.27294921875},{2,0.7763671875,0.24560546875,0.83203125,0.27294921875},{2,0.8359375,0.24560546875,0.8916015625,0.27294921875},{2,0.8955078125,0.24560546875,0.951171875,0.27294921875},{2,0.001953125,0.27490234375,0.0576171875,0.30224609375},{2,0.0615234375,0.27490234375,0.1171875,0.30224609375},{2,0.12109375,0.27490234375,0.1767578125,0.30224609375},{2,0.1806640625,0.27490234375,0.236328125,0.30224609375},{2,0.240234375,0.27490234375,0.2958984375,0.30224609375},{2,0.2998046875,0.27490234375,0.35546875,0.30224609375},{2,0.359375,0.27490234375,0.4150390625,0.30224609375},{2,0.4189453125,0.27490234375,0.474609375,0.30224609375},{2,0.478515625,0.27490234375,0.5341796875,0.30224609375},{2,0.5380859375,0.27490234375,0.59375,0.30224609375},{2,0.59765625,0.27490234375,0.6533203125,0.30224609375},{2,0.6572265625,0.27490234375,0.712890625,0.30224609375},{2,0.716796875,0.27490234375,0.7724609375,0.30224609375},{2,0.7763671875,0.27490234375,0.83203125,0.30224609375},{2,0.8359375,0.27490234375,0.8916015625,0.30224609375},{2,0.8955078125,0.27490234375,0.951171875,0.30224609375},{2,0.001953125,0.30419921875,0.0576171875,0.33154296875},{2,0.0615234375,0.30419921875,0.1171875,0.33154296875}},["clip"]="right-banner"},{["group"]="body",["rect"]={24,39,169,42},["tiles"]={{2,0.548828125,0.52734375,0.6904296875,0.52880859375}}},{["group"]="body",["rect"]={24,77,169,98},["tiles"]={{2,0.16015625,0.47412109375,0.3017578125,0.484375}}},{["group"]="body",["rect"]={24,42,77,77},["tiles"]={{2,0.880859375,0.39111328125,0.9326171875,0.408203125}}},{["group"]="body",["rect"]={116,42,169,77},["tiles"]={{2,0.9365234375,0.39111328125,0.98828125,0.408203125}}},{["group"]="body",["rect"]={77,42,116,77},["tiles"]={{2,0.955078125,0.27490234375,0.9931640625,0.2919921875},{2,0.001953125,0.419921875,0.0400390625,0.43701171875},{2,0.0439453125,0.419921875,0.08203125,0.43701171875},{2,0.0859375,0.419921875,0.1240234375,0.43701171875},{2,0.1279296875,0.419921875,0.166015625,0.43701171875},{2,0.169921875,0.419921875,0.2080078125,0.43701171875},{2,0.2119140625,0.419921875,0.25,0.43701171875},{2,0.25390625,0.419921875,0.2919921875,0.43701171875},{2,0.2958984375,0.419921875,0.333984375,0.43701171875},{2,0.337890625,0.419921875,0.3759765625,0.43701171875},{2,0.3798828125,0.419921875,0.41796875,0.43701171875},{2,0.421875,0.419921875,0.4599609375,0.43701171875},{2,0.4638671875,0.419921875,0.501953125,0.43701171875},{2,0.505859375,0.419921875,0.5439453125,0.43701171875},{2,0.5478515625,0.419921875,0.5859375,0.43701171875},{2,0.58984375,0.419921875,0.6279296875,0.43701171875},{2,0.6318359375,0.419921875,0.669921875,0.43701171875},{2,0.673828125,0.419921875,0.7119140625,0.43701171875},{2,0.7158203125,0.419921875,0.75390625,0.43701171875},{2,0.7578125,0.419921875,0.7958984375,0.43701171875},{2,0.7998046875,0.419921875,0.837890625,0.43701171875},{2,0.841796875,0.419921875,0.8798828125,0.43701171875},{2,0.8837890625,0.419921875,0.921875,0.43701171875},{2,0.92578125,0.419921875,0.9638671875,0.43701171875},{2,0.001953125,0.43896484375,0.0400390625,0.4560546875},{2,0.0439453125,0.43896484375,0.08203125,0.4560546875},{2,0.0859375,0.43896484375,0.1240234375,0.4560546875},{2,0.1279296875,0.43896484375,0.166015625,0.4560546875},{2,0.169921875,0.43896484375,0.2080078125,0.4560546875},{2,0.2119140625,0.43896484375,0.25,0.4560546875},{2,0.25390625,0.43896484375,0.2919921875,0.4560546875},{2,0.2958984375,0.43896484375,0.333984375,0.4560546875},{2,0.337890625,0.43896484375,0.3759765625,0.4560546875},{2,0.3798828125,0.43896484375,0.41796875,0.4560546875}},["receiverFor"]="iris"},{["group"]="body",["rect"]={24,116,169,119},["tiles"]={{2,0.6943359375,0.52734375,0.8359375,0.52880859375}}},{["group"]="body",["rect"]={24,98,30,116},["tiles"]={{2,0.9921875,0.39111328125,0.998046875,0.39990234375}}},{["group"]="body",["rect"]={162,98,169,116},["tiles"]={{2,0.9912109375,0.0673828125,0.998046875,0.076171875}}},{["group"]="body",["rect"]={30,98,162,116},["tiles"]={{2,0.2373046875,0.48876953125,0.3662109375,0.49755859375},{2,0.3701171875,0.48876953125,0.4990234375,0.49755859375},{2,0.5029296875,0.48876953125,0.6318359375,0.49755859375},{2,0.6357421875,0.48876953125,0.7646484375,0.49755859375},{2,0.7685546875,0.48876953125,0.8974609375,0.49755859375},{2,0.001953125,0.5,0.130859375,0.5087890625},{2,0.134765625,0.5,0.263671875,0.5087890625},{2,0.267578125,0.5,0.396484375,0.5087890625},{2,0.400390625,0.5,0.529296875,0.5087890625},{2,0.533203125,0.5,0.662109375,0.5087890625},{2,0.666015625,0.5,0.794921875,0.5087890625},{2,0.798828125,0.5,0.927734375,0.5087890625}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={30,99,162,129},["tiles"]={{2,0.8046875,0.43896484375,0.93359375,0.45361328125}}},{["group"]="scroll",["rect"]={30,129,162,186},["tiles"]={{2,0.8486328125,0.03662109375,0.9775390625,0.064453125},{2,0.001953125,0.0673828125,0.130859375,0.09521484375},{2,0.134765625,0.0673828125,0.263671875,0.09521484375},{2,0.267578125,0.0673828125,0.396484375,0.09521484375},{2,0.400390625,0.0673828125,0.529296875,0.09521484375},{2,0.533203125,0.0673828125,0.662109375,0.09521484375},{2,0.666015625,0.0673828125,0.794921875,0.09521484375},{2,0.798828125,0.0673828125,0.927734375,0.09521484375},{2,0.001953125,0.09716796875,0.130859375,0.125},{2,0.134765625,0.09716796875,0.263671875,0.125},{2,0.267578125,0.09716796875,0.396484375,0.125},{2,0.400390625,0.09716796875,0.529296875,0.125},{2,0.533203125,0.09716796875,0.662109375,0.125},{2,0.666015625,0.09716796875,0.794921875,0.125},{2,0.798828125,0.09716796875,0.927734375,0.125},{2,0.001953125,0.126953125,0.130859375,0.15478515625},{2,0.134765625,0.126953125,0.263671875,0.15478515625},{2,0.267578125,0.126953125,0.396484375,0.15478515625},{2,0.400390625,0.126953125,0.529296875,0.15478515625},{2,0.533203125,0.126953125,0.662109375,0.15478515625},{2,0.666015625,0.126953125,0.794921875,0.15478515625},{2,0.798828125,0.126953125,0.927734375,0.15478515625},{2,0.001953125,0.15673828125,0.130859375,0.1845703125},{2,0.134765625,0.15673828125,0.263671875,0.1845703125},{2,0.267578125,0.15673828125,0.396484375,0.1845703125},{2,0.400390625,0.15673828125,0.529296875,0.1845703125},{2,0.533203125,0.15673828125,0.662109375,0.1845703125},{2,0.666015625,0.15673828125,0.794921875,0.1845703125},{2,0.798828125,0.15673828125,0.927734375,0.1845703125},{2,0.001953125,0.1865234375,0.130859375,0.21435546875},{2,0.134765625,0.1865234375,0.263671875,0.21435546875},{2,0.267578125,0.1865234375,0.396484375,0.21435546875}},["clip"]="scroll"},{["group"]="scroll",["rect"]={31,104,161,119},["tiles"]={{2,0.107421875,0.5107421875,0.234375,0.51806640625}},["glow"]="scroll"},{["group"]="body",["rect"]={49,2,143,9},["tiles"]={{2,0.453125,0.52734375,0.544921875,0.53076171875}}},{["group"]="body",["rect"]={49,68,143,71},["tiles"]={{2,0.83984375,0.52734375,0.931640625,0.52880859375}}},{["group"]="body",["rect"]={49,9,73,68},["tiles"]={{2,0.099609375,0.0009765625,0.123046875,0.02978515625}}},{["group"]="body",["rect"]={120,9,143,68},["tiles"]={{2,0.126953125,0.0009765625,0.1494140625,0.02978515625}}},{["group"]="body",["rect"]={73,9,120,68},["tiles"]={{2,0.1533203125,0.0009765625,0.19921875,0.02978515625},{2,0.203125,0.0009765625,0.2490234375,0.02978515625},{2,0.2529296875,0.0009765625,0.298828125,0.02978515625},{2,0.302734375,0.0009765625,0.3486328125,0.02978515625},{2,0.3525390625,0.0009765625,0.3984375,0.02978515625},{2,0.40234375,0.0009765625,0.4482421875,0.02978515625},{2,0.4521484375,0.0009765625,0.498046875,0.02978515625},{2,0.501953125,0.0009765625,0.5478515625,0.02978515625},{2,0.5517578125,0.0009765625,0.59765625,0.02978515625},{2,0.6015625,0.0009765625,0.6474609375,0.02978515625},{2,0.6513671875,0.0009765625,0.697265625,0.02978515625},{2,0.701171875,0.0009765625,0.7470703125,0.02978515625},{2,0.7509765625,0.0009765625,0.796875,0.02978515625},{2,0.80078125,0.0009765625,0.8466796875,0.02978515625},{2,0.8505859375,0.0009765625,0.896484375,0.02978515625},{2,0.900390625,0.0009765625,0.9462890625,0.02978515625},{2,0.9501953125,0.0009765625,0.99609375,0.02978515625},{2,0.001953125,0.03662109375,0.0478515625,0.0654296875},{2,0.0517578125,0.03662109375,0.09765625,0.0654296875},{2,0.1015625,0.03662109375,0.1474609375,0.0654296875},{2,0.1513671875,0.03662109375,0.197265625,0.0654296875},{2,0.201171875,0.03662109375,0.2470703125,0.0654296875},{2,0.2509765625,0.03662109375,0.296875,0.0654296875},{2,0.30078125,0.03662109375,0.3466796875,0.0654296875},{2,0.3505859375,0.03662109375,0.396484375,0.0654296875},{2,0.400390625,0.03662109375,0.4462890625,0.0654296875},{2,0.4501953125,0.03662109375,0.49609375,0.0654296875},{2,0.5,0.03662109375,0.5458984375,0.0654296875},{2,0.5498046875,0.03662109375,0.595703125,0.0654296875},{2,0.599609375,0.03662109375,0.6455078125,0.0654296875},{2,0.6494140625,0.03662109375,0.6953125,0.0654296875},{2,0.69921875,0.03662109375,0.7451171875,0.0654296875},{2,0.7490234375,0.03662109375,0.794921875,0.0654296875},{2,0.798828125,0.03662109375,0.8447265625,0.0654296875}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={77,15,115,25},["tiles"]={{2,0.9267578125,0.5107421875,0.9638671875,0.515625}}},{["group"]="kirinTor",["rect"]={77,15,115,25},["tiles"]={{2,0.001953125,0.5205078125,0.0390625,0.525390625}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={77,25,115,34},["tiles"]={{2,0.04296875,0.5205078125,0.080078125,0.52490234375},{2,0.083984375,0.5205078125,0.12109375,0.52490234375},{2,0.125,0.5205078125,0.162109375,0.52490234375},{2,0.166015625,0.5205078125,0.203125,0.52490234375},{2,0.20703125,0.5205078125,0.244140625,0.52490234375},{2,0.248046875,0.5205078125,0.28515625,0.52490234375},{2,0.2890625,0.5205078125,0.326171875,0.52490234375},{2,0.330078125,0.5205078125,0.3671875,0.52490234375},{2,0.37109375,0.5205078125,0.408203125,0.52490234375},{2,0.412109375,0.5205078125,0.44921875,0.52490234375},{2,0.453125,0.5205078125,0.490234375,0.52490234375},{2,0.494140625,0.5205078125,0.53125,0.52490234375},{2,0.53515625,0.5205078125,0.572265625,0.52490234375},{2,0.576171875,0.5205078125,0.61328125,0.52490234375},{2,0.6171875,0.5205078125,0.654296875,0.52490234375},{2,0.658203125,0.5205078125,0.6953125,0.52490234375},{2,0.69921875,0.5205078125,0.736328125,0.52490234375}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={77,25,115,34},["tiles"]={{2,0.740234375,0.5205078125,0.77734375,0.52490234375},{2,0.78125,0.5205078125,0.818359375,0.52490234375},{2,0.822265625,0.5205078125,0.859375,0.52490234375},{2,0.86328125,0.5205078125,0.900390625,0.52490234375},{2,0.904296875,0.5205078125,0.94140625,0.52490234375},{2,0.9453125,0.5205078125,0.982421875,0.52490234375},{2,0.001953125,0.52734375,0.0390625,0.53173828125},{2,0.04296875,0.52734375,0.080078125,0.53173828125},{2,0.083984375,0.52734375,0.12109375,0.53173828125},{2,0.125,0.52734375,0.162109375,0.53173828125},{2,0.166015625,0.52734375,0.203125,0.53173828125},{2,0.20703125,0.52734375,0.244140625,0.53173828125},{2,0.248046875,0.52734375,0.28515625,0.53173828125},{2,0.2890625,0.52734375,0.326171875,0.53173828125},{2,0.330078125,0.52734375,0.3671875,0.53173828125},{2,0.37109375,0.52734375,0.408203125,0.53173828125},{2,0.412109375,0.52734375,0.44921875,0.53173828125}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={77,34,115,71},["tiles"]={{2,0.955078125,0.21630859375,0.9921875,0.234375}}},{["group"]="kirinTor",["rect"]={77,34,115,71},["tiles"]={{2,0.955078125,0.24560546875,0.9921875,0.263671875}},["glow"]="eye"},{["group"]="shards",["rect"]={54,10,78,37},["tiles"]={{2,0.3447265625,0.4580078125,0.3681640625,0.47119140625},{2,0.3720703125,0.4580078125,0.3955078125,0.47119140625},{2,0.3994140625,0.4580078125,0.4228515625,0.47119140625},{2,0.4267578125,0.4580078125,0.4501953125,0.47119140625},{2,0.4541015625,0.4580078125,0.4775390625,0.47119140625},{2,0.4814453125,0.4580078125,0.5048828125,0.47119140625},{2,0.5087890625,0.4580078125,0.5322265625,0.47119140625},{2,0.5361328125,0.4580078125,0.5595703125,0.47119140625},{2,0.5634765625,0.4580078125,0.5869140625,0.47119140625},{2,0.5908203125,0.4580078125,0.6142578125,0.47119140625},{2,0.6181640625,0.4580078125,0.6416015625,0.47119140625},{2,0.6455078125,0.4580078125,0.6689453125,0.47119140625},{2,0.6728515625,0.4580078125,0.6962890625,0.47119140625},{2,0.7001953125,0.4580078125,0.7236328125,0.47119140625},{2,0.7275390625,0.4580078125,0.7509765625,0.47119140625}},["shard"]=1},{["group"]="shards",["rect"]={55,11,78,37},["tiles"]={{2,0.7548828125,0.4580078125,0.77734375,0.470703125},{2,0.78125,0.4580078125,0.8037109375,0.470703125},{2,0.8076171875,0.4580078125,0.830078125,0.470703125},{2,0.833984375,0.4580078125,0.8564453125,0.470703125},{2,0.8603515625,0.4580078125,0.8828125,0.470703125},{2,0.88671875,0.4580078125,0.9091796875,0.470703125},{2,0.9130859375,0.4580078125,0.935546875,0.470703125},{2,0.939453125,0.4580078125,0.9619140625,0.470703125},{2,0.9658203125,0.4580078125,0.98828125,0.470703125},{2,0.001953125,0.47412109375,0.0244140625,0.48681640625},{2,0.0283203125,0.47412109375,0.05078125,0.48681640625},{2,0.0546875,0.47412109375,0.0771484375,0.48681640625},{2,0.0810546875,0.47412109375,0.103515625,0.48681640625},{2,0.107421875,0.47412109375,0.1298828125,0.48681640625},{2,0.1337890625,0.47412109375,0.15625,0.48681640625}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={64,22,78,38},["tiles"]={{2,0.931640625,0.5,0.9453125,0.5078125},{2,0.94921875,0.5,0.962890625,0.5078125},{2,0.966796875,0.5,0.98046875,0.5078125},{2,0.984375,0.5,0.998046875,0.5078125},{2,0.9013671875,0.48876953125,0.9150390625,0.49658203125},{2,0.9189453125,0.48876953125,0.9326171875,0.49658203125},{2,0.9365234375,0.48876953125,0.9501953125,0.49658203125},{2,0.9541015625,0.48876953125,0.9677734375,0.49658203125},{2,0.9716796875,0.48876953125,0.9853515625,0.49658203125},{2,0.001953125,0.5107421875,0.015625,0.5185546875},{2,0.01953125,0.5107421875,0.033203125,0.5185546875},{2,0.037109375,0.5107421875,0.05078125,0.5185546875},{2,0.0546875,0.5107421875,0.068359375,0.5185546875},{2,0.072265625,0.5107421875,0.0859375,0.5185546875},{2,0.08984375,0.5107421875,0.103515625,0.5185546875}},["shard"]=2},{["group"]="shards",["rect"]={65,23,78,38},["tiles"]={{2,0.23828125,0.5107421875,0.2509765625,0.51806640625},{2,0.2548828125,0.5107421875,0.267578125,0.51806640625},{2,0.271484375,0.5107421875,0.2841796875,0.51806640625},{2,0.2880859375,0.5107421875,0.30078125,0.51806640625},{2,0.3046875,0.5107421875,0.3173828125,0.51806640625},{2,0.3212890625,0.5107421875,0.333984375,0.51806640625},{2,0.337890625,0.5107421875,0.3505859375,0.51806640625},{2,0.3544921875,0.5107421875,0.3671875,0.51806640625},{2,0.37109375,0.5107421875,0.3837890625,0.51806640625},{2,0.3876953125,0.5107421875,0.400390625,0.51806640625},{2,0.404296875,0.5107421875,0.4169921875,0.51806640625},{2,0.4208984375,0.5107421875,0.43359375,0.51806640625},{2,0.4375,0.5107421875,0.4501953125,0.51806640625},{2,0.4541015625,0.5107421875,0.466796875,0.51806640625},{2,0.470703125,0.5107421875,0.4833984375,0.51806640625}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={111,9,135,40},["tiles"]={{2,0.9677734375,0.419921875,0.9912109375,0.43505859375},{2,0.421875,0.43896484375,0.4453125,0.4541015625},{2,0.44921875,0.43896484375,0.47265625,0.4541015625},{2,0.4765625,0.43896484375,0.5,0.4541015625},{2,0.50390625,0.43896484375,0.52734375,0.4541015625},{2,0.53125,0.43896484375,0.5546875,0.4541015625},{2,0.55859375,0.43896484375,0.58203125,0.4541015625},{2,0.5859375,0.43896484375,0.609375,0.4541015625},{2,0.61328125,0.43896484375,0.63671875,0.4541015625},{2,0.640625,0.43896484375,0.6640625,0.4541015625},{2,0.66796875,0.43896484375,0.69140625,0.4541015625},{2,0.6953125,0.43896484375,0.71875,0.4541015625},{2,0.72265625,0.43896484375,0.74609375,0.4541015625},{2,0.75,0.43896484375,0.7734375,0.4541015625},{2,0.77734375,0.43896484375,0.80078125,0.4541015625}},["shard"]=3},{["group"]="shards",["rect"]={112,10,135,39},["tiles"]={{2,0.9375,0.43896484375,0.9599609375,0.453125},{2,0.9638671875,0.43896484375,0.986328125,0.453125},{2,0.001953125,0.4580078125,0.0244140625,0.47216796875},{2,0.0283203125,0.4580078125,0.05078125,0.47216796875},{2,0.0546875,0.4580078125,0.0771484375,0.47216796875},{2,0.0810546875,0.4580078125,0.103515625,0.47216796875},{2,0.107421875,0.4580078125,0.1298828125,0.47216796875},{2,0.1337890625,0.4580078125,0.15625,0.47216796875},{2,0.16015625,0.4580078125,0.1826171875,0.47216796875},{2,0.1865234375,0.4580078125,0.208984375,0.47216796875},{2,0.212890625,0.4580078125,0.2353515625,0.47216796875},{2,0.2392578125,0.4580078125,0.26171875,0.47216796875},{2,0.265625,0.4580078125,0.2880859375,0.47216796875},{2,0.2919921875,0.4580078125,0.314453125,0.47216796875},{2,0.318359375,0.4580078125,0.3408203125,0.47216796875}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={115,22,127,35},["tiles"]={{2,0.4873046875,0.5107421875,0.4990234375,0.51708984375},{2,0.5029296875,0.5107421875,0.5146484375,0.51708984375},{2,0.5185546875,0.5107421875,0.5302734375,0.51708984375},{2,0.5341796875,0.5107421875,0.5458984375,0.51708984375},{2,0.5498046875,0.5107421875,0.5615234375,0.51708984375},{2,0.5654296875,0.5107421875,0.5771484375,0.51708984375},{2,0.5810546875,0.5107421875,0.5927734375,0.51708984375},{2,0.5966796875,0.5107421875,0.6083984375,0.51708984375},{2,0.6123046875,0.5107421875,0.6240234375,0.51708984375},{2,0.6279296875,0.5107421875,0.6396484375,0.51708984375},{2,0.6435546875,0.5107421875,0.6552734375,0.51708984375},{2,0.6591796875,0.5107421875,0.6708984375,0.51708984375},{2,0.6748046875,0.5107421875,0.6865234375,0.51708984375},{2,0.6904296875,0.5107421875,0.7021484375,0.51708984375},{2,0.7060546875,0.5107421875,0.7177734375,0.51708984375}},["shard"]=4},{["group"]="shards",["rect"]={116,23,126,34},["tiles"]={{2,0.7216796875,0.5107421875,0.7314453125,0.51611328125},{2,0.7353515625,0.5107421875,0.7451171875,0.51611328125},{2,0.7490234375,0.5107421875,0.7587890625,0.51611328125},{2,0.7626953125,0.5107421875,0.7724609375,0.51611328125},{2,0.7763671875,0.5107421875,0.7861328125,0.51611328125},{2,0.7900390625,0.5107421875,0.7998046875,0.51611328125},{2,0.8037109375,0.5107421875,0.8134765625,0.51611328125},{2,0.8173828125,0.5107421875,0.8271484375,0.51611328125},{2,0.8310546875,0.5107421875,0.8408203125,0.51611328125},{2,0.8447265625,0.5107421875,0.8544921875,0.51611328125},{2,0.8583984375,0.5107421875,0.8681640625,0.51611328125},{2,0.8720703125,0.5107421875,0.8818359375,0.51611328125},{2,0.8857421875,0.5107421875,0.8955078125,0.51611328125},{2,0.8994140625,0.5107421875,0.9091796875,0.51611328125},{2,0.9130859375,0.5107421875,0.9228515625,0.51611328125}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={0,9,46,71},["tiles"]={{2,0.05078125,0.0009765625,0.095703125,0.03125}}},{["group"]="shoulderFloaters",["rect"]={0,51,15,70},["tiles"]={{2,0.21875,0.48876953125,0.2333984375,0.498046875}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={146,2,192,71},["tiles"]={{2,0.001953125,0.0009765625,0.046875,0.03466796875}}},{["group"]="shoulderFloaters",["rect"]={176,49,192,70},["tiles"]={{2,0.9814453125,0.03662109375,0.9970703125,0.046875}},["glow"]="shoulder"}},["288"]={{["group"]="foundation",["rect"]={17,20,270,150},["tiles"]={{1,0.001953125,0.001953125,0.2490234375,0.12890625}}},{["group"]="foundation",["rect"]={18,150,38,197},["tiles"]={{1,0.8271484375,0.5107421875,0.8466796875,0.556640625}}},{["group"]="foundation",["rect"]={250,150,270,196},["tiles"]={{1,0.8505859375,0.5107421875,0.8701171875,0.5556640625}}},{["group"]="foundation",["rect"]={38,150,250,199},["tiles"]={{1,0.1943359375,0.5107421875,0.4013671875,0.55859375},{1,0.4052734375,0.5107421875,0.6123046875,0.55859375},{1,0.6162109375,0.5107421875,0.8232421875,0.55859375},{1,0.001953125,0.580078125,0.208984375,0.6279296875},{1,0.212890625,0.580078125,0.419921875,0.6279296875},{1,0.423828125,0.580078125,0.630859375,0.6279296875},{1,0.634765625,0.580078125,0.841796875,0.6279296875},{1,0.001953125,0.6318359375,0.208984375,0.6796875},{1,0.212890625,0.6318359375,0.419921875,0.6796875},{1,0.423828125,0.6318359375,0.630859375,0.6796875},{1,0.634765625,0.6318359375,0.841796875,0.6796875},{1,0.001953125,0.68359375,0.208984375,0.7314453125}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={15,181,45,233},["tiles"]={{1,0.12890625,0.5107421875,0.158203125,0.5615234375}}},{["group"]="bannerFloaters",["rect"]={244,181,273,232},["tiles"]={{1,0.162109375,0.5107421875,0.1904296875,0.560546875}}},{["group"]="body",["rect"]={35,170,116,172},["tiles"]={{3,0.8076171875,0.5390625,0.88671875,0.546875}}},{["group"]="body",["rect"]={35,172,65,200},["tiles"]={{2,0.6591796875,0.9638671875,0.6884765625,0.9775390625}}},{["group"]="body",["rect"]={114,172,116,200},["tiles"]={{2,0.9951171875,0.8193359375,0.9970703125,0.8330078125}}},{["group"]="body",["rect"]={65,172,114,200},["tiles"]={{2,0.6923828125,0.9638671875,0.740234375,0.9775390625},{2,0.744140625,0.9638671875,0.7919921875,0.9775390625},{2,0.7958984375,0.9638671875,0.84375,0.9775390625},{2,0.84765625,0.9638671875,0.8955078125,0.9775390625},{2,0.8994140625,0.9638671875,0.947265625,0.9775390625},{2,0.001953125,0.98291015625,0.0498046875,0.99658203125},{2,0.0537109375,0.98291015625,0.1015625,0.99658203125},{2,0.10546875,0.98291015625,0.1533203125,0.99658203125},{2,0.1572265625,0.98291015625,0.205078125,0.99658203125},{2,0.208984375,0.98291015625,0.2568359375,0.99658203125},{2,0.2607421875,0.98291015625,0.30859375,0.99658203125},{2,0.3125,0.98291015625,0.3603515625,0.99658203125}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={35,200,116,282},["tiles"]={{2,0.1962890625,0.400390625,0.275390625,0.4404296875},{2,0.279296875,0.400390625,0.3583984375,0.4404296875},{2,0.3623046875,0.400390625,0.44140625,0.4404296875},{2,0.4453125,0.400390625,0.5244140625,0.4404296875},{2,0.5283203125,0.400390625,0.607421875,0.4404296875},{2,0.611328125,0.400390625,0.6904296875,0.4404296875},{2,0.6943359375,0.400390625,0.7734375,0.4404296875},{2,0.77734375,0.400390625,0.8564453125,0.4404296875},{2,0.8603515625,0.400390625,0.939453125,0.4404296875},{2,0.001953125,0.443359375,0.0810546875,0.4833984375},{2,0.0849609375,0.443359375,0.1640625,0.4833984375},{2,0.16796875,0.443359375,0.2470703125,0.4833984375},{2,0.2509765625,0.443359375,0.330078125,0.4833984375},{2,0.333984375,0.443359375,0.4130859375,0.4833984375},{2,0.4169921875,0.443359375,0.49609375,0.4833984375},{2,0.5,0.443359375,0.5791015625,0.4833984375},{2,0.5830078125,0.443359375,0.662109375,0.4833984375},{2,0.666015625,0.443359375,0.7451171875,0.4833984375},{2,0.7490234375,0.443359375,0.828125,0.4833984375},{2,0.83203125,0.443359375,0.9111328125,0.4833984375},{2,0.9150390625,0.443359375,0.994140625,0.4833984375},{2,0.001953125,0.4853515625,0.0810546875,0.525390625},{2,0.0849609375,0.4853515625,0.1640625,0.525390625},{2,0.16796875,0.4853515625,0.2470703125,0.525390625},{2,0.2509765625,0.4853515625,0.330078125,0.525390625},{2,0.333984375,0.4853515625,0.4130859375,0.525390625},{2,0.4169921875,0.4853515625,0.49609375,0.525390625},{2,0.5,0.4853515625,0.5791015625,0.525390625},{2,0.5830078125,0.4853515625,0.662109375,0.525390625},{2,0.666015625,0.4853515625,0.7451171875,0.525390625},{2,0.7490234375,0.4853515625,0.828125,0.525390625},{2,0.83203125,0.4853515625,0.9111328125,0.525390625},{2,0.9150390625,0.4853515625,0.994140625,0.525390625},{2,0.001953125,0.52734375,0.0810546875,0.5673828125},{2,0.0849609375,0.52734375,0.1640625,0.5673828125},{2,0.16796875,0.52734375,0.2470703125,0.5673828125},{2,0.2509765625,0.52734375,0.330078125,0.5673828125},{2,0.333984375,0.52734375,0.4130859375,0.5673828125},{2,0.4169921875,0.52734375,0.49609375,0.5673828125},{2,0.5,0.52734375,0.5791015625,0.5673828125},{2,0.5830078125,0.52734375,0.662109375,0.5673828125},{2,0.666015625,0.52734375,0.7451171875,0.5673828125},{2,0.7490234375,0.52734375,0.828125,0.5673828125},{2,0.83203125,0.52734375,0.9111328125,0.5673828125},{2,0.9150390625,0.52734375,0.994140625,0.5673828125},{2,0.001953125,0.5693359375,0.0810546875,0.609375},{2,0.0849609375,0.5693359375,0.1640625,0.609375},{2,0.16796875,0.5693359375,0.2470703125,0.609375},{2,0.2509765625,0.5693359375,0.330078125,0.609375},{2,0.333984375,0.5693359375,0.4130859375,0.609375},{2,0.4169921875,0.5693359375,0.49609375,0.609375},{2,0.5,0.5693359375,0.5791015625,0.609375},{2,0.5830078125,0.5693359375,0.662109375,0.609375},{2,0.666015625,0.5693359375,0.7451171875,0.609375},{2,0.7490234375,0.5693359375,0.828125,0.609375},{2,0.83203125,0.5693359375,0.9111328125,0.609375},{2,0.9150390625,0.5693359375,0.994140625,0.609375},{2,0.001953125,0.611328125,0.0810546875,0.6513671875},{2,0.0849609375,0.611328125,0.1640625,0.6513671875},{2,0.16796875,0.611328125,0.2470703125,0.6513671875},{2,0.2509765625,0.611328125,0.330078125,0.6513671875},{2,0.333984375,0.611328125,0.4130859375,0.6513671875},{2,0.4169921875,0.611328125,0.49609375,0.6513671875},{2,0.5,0.611328125,0.5791015625,0.6513671875}},["clip"]="left-banner"},{["group"]="body",["rect"]={172,170,252,172},["tiles"]={{3,0.890625,0.5390625,0.96875,0.546875}}},{["group"]="body",["rect"]={172,172,174,200},["tiles"]={{2,0.9912109375,0.09716796875,0.9931640625,0.11083984375}}},{["group"]="body",["rect"]={224,172,252,200},["tiles"]={{2,0.970703125,0.88818359375,0.998046875,0.90185546875}}},{["group"]="body",["rect"]={174,172,224,200},["tiles"]={{2,0.3642578125,0.98291015625,0.4130859375,0.99658203125},{2,0.4169921875,0.98291015625,0.4658203125,0.99658203125},{2,0.4697265625,0.98291015625,0.5185546875,0.99658203125},{2,0.5224609375,0.98291015625,0.5712890625,0.99658203125},{2,0.5751953125,0.98291015625,0.6240234375,0.99658203125},{2,0.6279296875,0.98291015625,0.6767578125,0.99658203125},{2,0.6806640625,0.98291015625,0.7294921875,0.99658203125},{2,0.7333984375,0.98291015625,0.7822265625,0.99658203125},{2,0.7861328125,0.98291015625,0.8349609375,0.99658203125},{2,0.8388671875,0.98291015625,0.8876953125,0.99658203125},{2,0.8916015625,0.98291015625,0.9404296875,0.99658203125},{2,0.9443359375,0.98291015625,0.9931640625,0.99658203125}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={172,200,253,281},["tiles"]={{2,0.5830078125,0.611328125,0.662109375,0.65087890625},{2,0.666015625,0.611328125,0.7451171875,0.65087890625},{2,0.7490234375,0.611328125,0.828125,0.65087890625},{2,0.83203125,0.611328125,0.9111328125,0.65087890625},{2,0.9150390625,0.611328125,0.994140625,0.65087890625},{2,0.001953125,0.6533203125,0.0810546875,0.69287109375},{2,0.0849609375,0.6533203125,0.1640625,0.69287109375},{2,0.16796875,0.6533203125,0.2470703125,0.69287109375},{2,0.2509765625,0.6533203125,0.330078125,0.69287109375},{2,0.333984375,0.6533203125,0.4130859375,0.69287109375},{2,0.4169921875,0.6533203125,0.49609375,0.69287109375},{2,0.5,0.6533203125,0.5791015625,0.69287109375},{2,0.5830078125,0.6533203125,0.662109375,0.69287109375},{2,0.666015625,0.6533203125,0.7451171875,0.69287109375},{2,0.7490234375,0.6533203125,0.828125,0.69287109375},{2,0.83203125,0.6533203125,0.9111328125,0.69287109375},{2,0.9150390625,0.6533203125,0.994140625,0.69287109375},{2,0.001953125,0.69482421875,0.0810546875,0.734375},{2,0.0849609375,0.69482421875,0.1640625,0.734375},{2,0.16796875,0.69482421875,0.2470703125,0.734375},{2,0.2509765625,0.69482421875,0.330078125,0.734375},{2,0.333984375,0.69482421875,0.4130859375,0.734375},{2,0.4169921875,0.69482421875,0.49609375,0.734375},{2,0.5,0.69482421875,0.5791015625,0.734375},{2,0.5830078125,0.69482421875,0.662109375,0.734375},{2,0.666015625,0.69482421875,0.7451171875,0.734375},{2,0.7490234375,0.69482421875,0.828125,0.734375},{2,0.83203125,0.69482421875,0.9111328125,0.734375},{2,0.9150390625,0.69482421875,0.994140625,0.734375},{2,0.001953125,0.736328125,0.0810546875,0.77587890625},{2,0.0849609375,0.736328125,0.1640625,0.77587890625},{2,0.16796875,0.736328125,0.2470703125,0.77587890625},{2,0.2509765625,0.736328125,0.330078125,0.77587890625},{2,0.333984375,0.736328125,0.4130859375,0.77587890625},{2,0.4169921875,0.736328125,0.49609375,0.77587890625},{2,0.5,0.736328125,0.5791015625,0.77587890625},{2,0.5830078125,0.736328125,0.662109375,0.77587890625},{2,0.666015625,0.736328125,0.7451171875,0.77587890625},{2,0.7490234375,0.736328125,0.828125,0.77587890625},{2,0.83203125,0.736328125,0.9111328125,0.77587890625},{2,0.9150390625,0.736328125,0.994140625,0.77587890625},{2,0.001953125,0.77783203125,0.0810546875,0.8173828125},{2,0.0849609375,0.77783203125,0.1640625,0.8173828125},{2,0.16796875,0.77783203125,0.2470703125,0.8173828125},{2,0.2509765625,0.77783203125,0.330078125,0.8173828125},{2,0.333984375,0.77783203125,0.4130859375,0.8173828125},{2,0.4169921875,0.77783203125,0.49609375,0.8173828125},{2,0.5,0.77783203125,0.5791015625,0.8173828125},{2,0.5830078125,0.77783203125,0.662109375,0.8173828125},{2,0.666015625,0.77783203125,0.7451171875,0.8173828125},{2,0.7490234375,0.77783203125,0.828125,0.8173828125},{2,0.83203125,0.77783203125,0.9111328125,0.8173828125},{2,0.9150390625,0.77783203125,0.994140625,0.8173828125},{2,0.001953125,0.8193359375,0.0810546875,0.85888671875},{2,0.0849609375,0.8193359375,0.1640625,0.85888671875},{2,0.16796875,0.8193359375,0.2470703125,0.85888671875},{2,0.2509765625,0.8193359375,0.330078125,0.85888671875},{2,0.333984375,0.8193359375,0.4130859375,0.85888671875},{2,0.4169921875,0.8193359375,0.49609375,0.85888671875},{2,0.5,0.8193359375,0.5791015625,0.85888671875},{2,0.5830078125,0.8193359375,0.662109375,0.85888671875},{2,0.666015625,0.8193359375,0.7451171875,0.85888671875},{2,0.7490234375,0.8193359375,0.828125,0.85888671875},{2,0.83203125,0.8193359375,0.9111328125,0.85888671875}},["clip"]="right-banner"},{["group"]="body",["rect"]={37,61,251,63},["tiles"]={{3,0.21484375,0.60546875,0.423828125,0.61328125}}},{["group"]="body",["rect"]={37,115,251,146},["tiles"]={{2,0.4462890625,0.9638671875,0.6552734375,0.97900390625}}},{["group"]="body",["rect"]={37,63,115,115},["tiles"]={{2,0.9150390625,0.8193359375,0.9912109375,0.8447265625}}},{["group"]="body",["rect"]={173,63,251,115},["tiles"]={{2,0.001953125,0.86083984375,0.078125,0.88623046875}}},{["group"]="body",["rect"]={115,63,173,115},["tiles"]={{2,0.9365234375,0.0009765625,0.9931640625,0.0263671875},{2,0.08203125,0.86083984375,0.138671875,0.88623046875},{2,0.142578125,0.86083984375,0.19921875,0.88623046875},{2,0.203125,0.86083984375,0.259765625,0.88623046875},{2,0.263671875,0.86083984375,0.3203125,0.88623046875},{2,0.32421875,0.86083984375,0.380859375,0.88623046875},{2,0.384765625,0.86083984375,0.44140625,0.88623046875},{2,0.4453125,0.86083984375,0.501953125,0.88623046875},{2,0.505859375,0.86083984375,0.5625,0.88623046875},{2,0.56640625,0.86083984375,0.623046875,0.88623046875},{2,0.626953125,0.86083984375,0.68359375,0.88623046875},{2,0.6875,0.86083984375,0.744140625,0.88623046875},{2,0.748046875,0.86083984375,0.8046875,0.88623046875},{2,0.80859375,0.86083984375,0.865234375,0.88623046875},{2,0.869140625,0.86083984375,0.92578125,0.88623046875},{2,0.9296875,0.86083984375,0.986328125,0.88623046875},{2,0.001953125,0.88818359375,0.05859375,0.91357421875},{2,0.0625,0.88818359375,0.119140625,0.91357421875},{2,0.123046875,0.88818359375,0.1796875,0.91357421875},{2,0.18359375,0.88818359375,0.240234375,0.91357421875},{2,0.244140625,0.88818359375,0.30078125,0.91357421875},{2,0.3046875,0.88818359375,0.361328125,0.91357421875},{2,0.365234375,0.88818359375,0.421875,0.91357421875},{2,0.42578125,0.88818359375,0.482421875,0.91357421875},{2,0.486328125,0.88818359375,0.54296875,0.91357421875},{2,0.546875,0.88818359375,0.603515625,0.91357421875},{2,0.607421875,0.88818359375,0.6640625,0.91357421875},{2,0.66796875,0.88818359375,0.724609375,0.91357421875},{2,0.728515625,0.88818359375,0.78515625,0.91357421875},{2,0.7890625,0.88818359375,0.845703125,0.91357421875},{2,0.849609375,0.88818359375,0.90625,0.91357421875},{2,0.91015625,0.88818359375,0.966796875,0.91357421875},{2,0.001953125,0.91552734375,0.05859375,0.94091796875},{2,0.0625,0.91552734375,0.119140625,0.94091796875}},["receiverFor"]="iris"},{["group"]="body",["rect"]={37,174,251,177},["tiles"]={{3,0.001953125,0.60546875,0.2109375,0.6171875}}},{["group"]="body",["rect"]={37,146,45,174},["tiles"]={{2,0.990234375,0.86083984375,0.998046875,0.87451171875}}},{["group"]="body",["rect"]={244,146,251,174},["tiles"]={{2,0.9775390625,0.94287109375,0.984375,0.95654296875}}},{["group"]="body",["rect"]={45,146,244,174},["tiles"]={{3,0.001953125,0.0078125,0.1962890625,0.1171875},{3,0.2001953125,0.0078125,0.39453125,0.1171875},{3,0.3984375,0.0078125,0.5927734375,0.1171875},{3,0.5966796875,0.0078125,0.791015625,0.1171875},{3,0.794921875,0.0078125,0.9892578125,0.1171875},{3,0.001953125,0.1328125,0.1962890625,0.2421875},{3,0.2001953125,0.1328125,0.39453125,0.2421875},{3,0.3984375,0.1328125,0.5927734375,0.2421875},{3,0.5966796875,0.1328125,0.791015625,0.2421875},{3,0.794921875,0.1328125,0.9892578125,0.2421875},{3,0.001953125,0.2578125,0.1962890625,0.3671875},{3,0.2001953125,0.2578125,0.39453125,0.3671875}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={46,150,241,194},["tiles"]={{2,0.123046875,0.91552734375,0.3134765625,0.93701171875}}},{["group"]="scroll",["rect"]={46,194,241,278},["tiles"]={{2,0.796875,0.09716796875,0.9873046875,0.13818359375},{2,0.001953125,0.142578125,0.1923828125,0.18359375},{2,0.1962890625,0.142578125,0.38671875,0.18359375},{2,0.390625,0.142578125,0.5810546875,0.18359375},{2,0.5849609375,0.142578125,0.775390625,0.18359375},{2,0.779296875,0.142578125,0.9697265625,0.18359375},{2,0.001953125,0.185546875,0.1923828125,0.2265625},{2,0.1962890625,0.185546875,0.38671875,0.2265625},{2,0.390625,0.185546875,0.5810546875,0.2265625},{2,0.5849609375,0.185546875,0.775390625,0.2265625},{2,0.779296875,0.185546875,0.9697265625,0.2265625},{2,0.001953125,0.228515625,0.1923828125,0.26953125},{2,0.1962890625,0.228515625,0.38671875,0.26953125},{2,0.390625,0.228515625,0.5810546875,0.26953125},{2,0.5849609375,0.228515625,0.775390625,0.26953125},{2,0.779296875,0.228515625,0.9697265625,0.26953125},{2,0.001953125,0.271484375,0.1923828125,0.3125},{2,0.1962890625,0.271484375,0.38671875,0.3125},{2,0.390625,0.271484375,0.5810546875,0.3125},{2,0.5849609375,0.271484375,0.775390625,0.3125},{2,0.779296875,0.271484375,0.9697265625,0.3125},{2,0.001953125,0.314453125,0.1923828125,0.35546875},{2,0.1962890625,0.314453125,0.38671875,0.35546875},{2,0.390625,0.314453125,0.5810546875,0.35546875},{2,0.5849609375,0.314453125,0.775390625,0.35546875},{2,0.779296875,0.314453125,0.9697265625,0.35546875},{2,0.001953125,0.357421875,0.1923828125,0.3984375},{2,0.1962890625,0.357421875,0.38671875,0.3984375},{2,0.390625,0.357421875,0.5810546875,0.3984375},{2,0.5849609375,0.357421875,0.775390625,0.3984375},{2,0.779296875,0.357421875,0.9697265625,0.3984375},{2,0.001953125,0.400390625,0.1923828125,0.44140625}},["clip"]="scroll"},{["group"]="scroll",["rect"]={48,158,240,177},["tiles"]={{3,0.578125,0.2578125,0.765625,0.33203125}},["glow"]="scroll"},{["group"]="body",["rect"]={76,5,213,14},["tiles"]={{3,0.669921875,0.5390625,0.8037109375,0.57421875}}},{["group"]="body",["rect"]={76,103,213,105},["tiles"]={{3,0.427734375,0.60546875,0.5615234375,0.61328125}}},{["group"]="body",["rect"]={76,14,109,103},["tiles"]={{2,0.140625,0.0009765625,0.1728515625,0.04443359375}}},{["group"]="body",["rect"]={179,14,213,103},["tiles"]={{2,0.1767578125,0.0009765625,0.2099609375,0.04443359375}}},{["group"]="body",["rect"]={109,14,179,103},["tiles"]={{2,0.2138671875,0.0009765625,0.2822265625,0.04443359375},{2,0.2861328125,0.0009765625,0.3544921875,0.04443359375},{2,0.3583984375,0.0009765625,0.4267578125,0.04443359375},{2,0.4306640625,0.0009765625,0.4990234375,0.04443359375},{2,0.5029296875,0.0009765625,0.5712890625,0.04443359375},{2,0.5751953125,0.0009765625,0.6435546875,0.04443359375},{2,0.6474609375,0.0009765625,0.7158203125,0.04443359375},{2,0.7197265625,0.0009765625,0.7880859375,0.04443359375},{2,0.7919921875,0.0009765625,0.8603515625,0.04443359375},{2,0.8642578125,0.0009765625,0.9326171875,0.04443359375},{2,0.001953125,0.0517578125,0.0703125,0.09521484375},{2,0.07421875,0.0517578125,0.142578125,0.09521484375},{2,0.146484375,0.0517578125,0.21484375,0.09521484375},{2,0.21875,0.0517578125,0.287109375,0.09521484375},{2,0.291015625,0.0517578125,0.359375,0.09521484375},{2,0.36328125,0.0517578125,0.431640625,0.09521484375},{2,0.435546875,0.0517578125,0.50390625,0.09521484375},{2,0.5078125,0.0517578125,0.576171875,0.09521484375},{2,0.580078125,0.0517578125,0.6484375,0.09521484375},{2,0.65234375,0.0517578125,0.720703125,0.09521484375},{2,0.724609375,0.0517578125,0.79296875,0.09521484375},{2,0.796875,0.0517578125,0.865234375,0.09521484375},{2,0.869140625,0.0517578125,0.9375,0.09521484375},{2,0.001953125,0.09716796875,0.0703125,0.140625},{2,0.07421875,0.09716796875,0.142578125,0.140625},{2,0.146484375,0.09716796875,0.21484375,0.140625},{2,0.21875,0.09716796875,0.287109375,0.140625},{2,0.291015625,0.09716796875,0.359375,0.140625},{2,0.36328125,0.09716796875,0.431640625,0.140625},{2,0.435546875,0.09716796875,0.50390625,0.140625},{2,0.5078125,0.09716796875,0.576171875,0.140625},{2,0.580078125,0.09716796875,0.6484375,0.140625},{2,0.65234375,0.09716796875,0.720703125,0.140625},{2,0.724609375,0.09716796875,0.79296875,0.140625}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={117,24,171,37},["tiles"]={{3,0.5771484375,0.3828125,0.6298828125,0.43359375}}},{["group"]="kirinTor",["rect"]={118,24,171,37},["tiles"]={{3,0.6337890625,0.3828125,0.685546875,0.43359375}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={117,37,171,50},["tiles"]={{3,0.689453125,0.3828125,0.7421875,0.43359375},{3,0.74609375,0.3828125,0.798828125,0.43359375},{3,0.802734375,0.3828125,0.85546875,0.43359375},{3,0.859375,0.3828125,0.912109375,0.43359375},{3,0.916015625,0.3828125,0.96875,0.43359375},{3,0.001953125,0.47265625,0.0546875,0.5234375},{3,0.05859375,0.47265625,0.111328125,0.5234375},{3,0.115234375,0.47265625,0.16796875,0.5234375},{3,0.171875,0.47265625,0.224609375,0.5234375},{3,0.228515625,0.47265625,0.28125,0.5234375},{3,0.28515625,0.47265625,0.337890625,0.5234375},{3,0.341796875,0.47265625,0.39453125,0.5234375},{3,0.3984375,0.47265625,0.451171875,0.5234375},{3,0.455078125,0.47265625,0.5078125,0.5234375},{3,0.51171875,0.47265625,0.564453125,0.5234375},{3,0.568359375,0.47265625,0.62109375,0.5234375},{3,0.625,0.47265625,0.677734375,0.5234375}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={118,37,171,50},["tiles"]={{3,0.681640625,0.47265625,0.7333984375,0.5234375},{3,0.7373046875,0.47265625,0.7890625,0.5234375},{3,0.79296875,0.47265625,0.8447265625,0.5234375},{3,0.8486328125,0.47265625,0.900390625,0.5234375},{3,0.904296875,0.47265625,0.9560546875,0.5234375},{3,0.001953125,0.5390625,0.0537109375,0.58984375},{3,0.0576171875,0.5390625,0.109375,0.58984375},{3,0.11328125,0.5390625,0.1650390625,0.58984375},{3,0.1689453125,0.5390625,0.220703125,0.58984375},{3,0.224609375,0.5390625,0.2763671875,0.58984375},{3,0.2802734375,0.5390625,0.33203125,0.58984375},{3,0.3359375,0.5390625,0.3876953125,0.58984375},{3,0.3916015625,0.5390625,0.443359375,0.58984375},{3,0.447265625,0.5390625,0.4990234375,0.58984375},{3,0.5029296875,0.5390625,0.5546875,0.58984375},{3,0.55859375,0.5390625,0.6103515625,0.58984375},{3,0.6142578125,0.5390625,0.666015625,0.58984375}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={117,50,171,105},["tiles"]={{2,0.943359375,0.400390625,0.99609375,0.42724609375}}},{["group"]="kirinTor",["rect"]={118,50,171,105},["tiles"]={{2,0.94140625,0.0517578125,0.9931640625,0.07861328125}},["glow"]="eye"},{["group"]="shards",["rect"]={83,16,116,54},["tiles"]={{2,0.3671875,0.94287109375,0.3994140625,0.96142578125},{2,0.4033203125,0.94287109375,0.435546875,0.96142578125},{2,0.439453125,0.94287109375,0.4716796875,0.96142578125},{2,0.4755859375,0.94287109375,0.5078125,0.96142578125},{2,0.51171875,0.94287109375,0.5439453125,0.96142578125},{2,0.5478515625,0.94287109375,0.580078125,0.96142578125},{2,0.583984375,0.94287109375,0.6162109375,0.96142578125},{2,0.6201171875,0.94287109375,0.65234375,0.96142578125},{2,0.65625,0.94287109375,0.6884765625,0.96142578125},{2,0.6923828125,0.94287109375,0.724609375,0.96142578125},{2,0.728515625,0.94287109375,0.7607421875,0.96142578125},{2,0.7646484375,0.94287109375,0.796875,0.96142578125},{2,0.80078125,0.94287109375,0.8330078125,0.96142578125},{2,0.8369140625,0.94287109375,0.869140625,0.96142578125},{2,0.873046875,0.94287109375,0.9052734375,0.96142578125}},["shard"]=1},{["group"]="shards",["rect"]={84,18,115,53},["tiles"]={{2,0.9091796875,0.94287109375,0.939453125,0.9599609375},{2,0.943359375,0.94287109375,0.9736328125,0.9599609375},{2,0.001953125,0.9638671875,0.0322265625,0.98095703125},{2,0.0361328125,0.9638671875,0.06640625,0.98095703125},{2,0.0703125,0.9638671875,0.1005859375,0.98095703125},{2,0.1044921875,0.9638671875,0.134765625,0.98095703125},{2,0.138671875,0.9638671875,0.1689453125,0.98095703125},{2,0.1728515625,0.9638671875,0.203125,0.98095703125},{2,0.20703125,0.9638671875,0.2373046875,0.98095703125},{2,0.2412109375,0.9638671875,0.271484375,0.98095703125},{2,0.275390625,0.9638671875,0.3056640625,0.98095703125},{2,0.3095703125,0.9638671875,0.33984375,0.98095703125},{2,0.34375,0.9638671875,0.3740234375,0.98095703125},{2,0.3779296875,0.9638671875,0.408203125,0.98095703125},{2,0.412109375,0.9638671875,0.4423828125,0.98095703125}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={97,34,116,56},["tiles"]={{2,0.9736328125,0.185546875,0.9921875,0.1962890625},{2,0.9736328125,0.228515625,0.9921875,0.2392578125},{2,0.9736328125,0.271484375,0.9921875,0.2822265625},{2,0.9736328125,0.314453125,0.9921875,0.3251953125},{2,0.9736328125,0.357421875,0.9921875,0.3681640625},{2,0.951171875,0.9638671875,0.9697265625,0.974609375},{2,0.9736328125,0.9638671875,0.9921875,0.974609375},{3,0.3984375,0.2578125,0.4169921875,0.34375},{3,0.4208984375,0.2578125,0.439453125,0.34375},{3,0.443359375,0.2578125,0.4619140625,0.34375},{3,0.4658203125,0.2578125,0.484375,0.34375},{3,0.48828125,0.2578125,0.5068359375,0.34375},{3,0.5107421875,0.2578125,0.529296875,0.34375},{3,0.533203125,0.2578125,0.5517578125,0.34375},{3,0.5556640625,0.2578125,0.57421875,0.34375}},["shard"]=2},{["group"]="shards",["rect"]={99,36,115,55},["tiles"]={{3,0.76953125,0.2578125,0.78515625,0.33203125},{3,0.7890625,0.2578125,0.8046875,0.33203125},{3,0.80859375,0.2578125,0.82421875,0.33203125},{3,0.828125,0.2578125,0.84375,0.33203125},{3,0.84765625,0.2578125,0.86328125,0.33203125},{3,0.8671875,0.2578125,0.8828125,0.33203125},{3,0.88671875,0.2578125,0.90234375,0.33203125},{3,0.90625,0.2578125,0.921875,0.33203125},{3,0.92578125,0.2578125,0.94140625,0.33203125},{3,0.9453125,0.2578125,0.9609375,0.33203125},{3,0.96484375,0.2578125,0.98046875,0.33203125},{3,0.001953125,0.3828125,0.017578125,0.45703125},{3,0.021484375,0.3828125,0.037109375,0.45703125},{3,0.041015625,0.3828125,0.056640625,0.45703125},{3,0.060546875,0.3828125,0.076171875,0.45703125}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={169,16,201,58},["tiles"]={{2,0.3173828125,0.91552734375,0.3486328125,0.93603515625},{2,0.3525390625,0.91552734375,0.3837890625,0.93603515625},{2,0.3876953125,0.91552734375,0.4189453125,0.93603515625},{2,0.4228515625,0.91552734375,0.4541015625,0.93603515625},{2,0.4580078125,0.91552734375,0.4892578125,0.93603515625},{2,0.4931640625,0.91552734375,0.5244140625,0.93603515625},{2,0.5283203125,0.91552734375,0.5595703125,0.93603515625},{2,0.5634765625,0.91552734375,0.5947265625,0.93603515625},{2,0.5986328125,0.91552734375,0.6298828125,0.93603515625},{2,0.6337890625,0.91552734375,0.6650390625,0.93603515625},{2,0.6689453125,0.91552734375,0.7001953125,0.93603515625},{2,0.7041015625,0.91552734375,0.7353515625,0.93603515625},{2,0.7392578125,0.91552734375,0.7705078125,0.93603515625},{2,0.7744140625,0.91552734375,0.8056640625,0.93603515625},{2,0.8095703125,0.91552734375,0.8408203125,0.93603515625}},["shard"]=3},{["group"]="shards",["rect"]={170,17,200,56},["tiles"]={{2,0.8447265625,0.91552734375,0.8740234375,0.9345703125},{2,0.8779296875,0.91552734375,0.9072265625,0.9345703125},{2,0.9111328125,0.91552734375,0.9404296875,0.9345703125},{2,0.9443359375,0.91552734375,0.9736328125,0.9345703125},{2,0.001953125,0.94287109375,0.03125,0.9619140625},{2,0.03515625,0.94287109375,0.064453125,0.9619140625},{2,0.068359375,0.94287109375,0.09765625,0.9619140625},{2,0.1015625,0.94287109375,0.130859375,0.9619140625},{2,0.134765625,0.94287109375,0.1640625,0.9619140625},{2,0.16796875,0.94287109375,0.197265625,0.9619140625},{2,0.201171875,0.94287109375,0.23046875,0.9619140625},{2,0.234375,0.94287109375,0.263671875,0.9619140625},{2,0.267578125,0.94287109375,0.296875,0.9619140625},{2,0.30078125,0.94287109375,0.330078125,0.9619140625},{2,0.333984375,0.94287109375,0.36328125,0.9619140625}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={174,35,189,51},["tiles"]={{3,0.080078125,0.3828125,0.0947265625,0.4453125},{3,0.0986328125,0.3828125,0.11328125,0.4453125},{3,0.1171875,0.3828125,0.1318359375,0.4453125},{3,0.1357421875,0.3828125,0.150390625,0.4453125},{3,0.154296875,0.3828125,0.1689453125,0.4453125},{3,0.1728515625,0.3828125,0.1875,0.4453125},{3,0.19140625,0.3828125,0.2060546875,0.4453125},{3,0.2099609375,0.3828125,0.224609375,0.4453125},{3,0.228515625,0.3828125,0.2431640625,0.4453125},{3,0.2470703125,0.3828125,0.26171875,0.4453125},{3,0.265625,0.3828125,0.2802734375,0.4453125},{3,0.2841796875,0.3828125,0.298828125,0.4453125},{3,0.302734375,0.3828125,0.3173828125,0.4453125},{3,0.3212890625,0.3828125,0.3359375,0.4453125},{3,0.33984375,0.3828125,0.3544921875,0.4453125}},["shard"]=4},{["group"]="shards",["rect"]={176,36,188,50},["tiles"]={{3,0.984375,0.2578125,0.99609375,0.3125},{3,0.3583984375,0.3828125,0.3701171875,0.4375},{3,0.3740234375,0.3828125,0.3857421875,0.4375},{3,0.3896484375,0.3828125,0.4013671875,0.4375},{3,0.4052734375,0.3828125,0.4169921875,0.4375},{3,0.4208984375,0.3828125,0.4326171875,0.4375},{3,0.4365234375,0.3828125,0.4482421875,0.4375},{3,0.4521484375,0.3828125,0.4638671875,0.4375},{3,0.4677734375,0.3828125,0.4794921875,0.4375},{3,0.4833984375,0.3828125,0.4951171875,0.4375},{3,0.4990234375,0.3828125,0.5107421875,0.4375},{3,0.5146484375,0.3828125,0.5263671875,0.4375},{3,0.5302734375,0.3828125,0.5419921875,0.4375},{3,0.5458984375,0.3828125,0.5576171875,0.4375},{3,0.5615234375,0.3828125,0.5732421875,0.4375}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={0,15,67,105},["tiles"]={{2,0.0712890625,0.0009765625,0.13671875,0.044921875}}},{["group"]="shoulderFloaters",["rect"]={1,78,21,104},["tiles"]={{2,0.9736328125,0.142578125,0.9931640625,0.1552734375}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={221,5,288,105},["tiles"]={{2,0.001953125,0.0009765625,0.0673828125,0.0498046875}}},{["group"]="shoulderFloaters",["rect"]={266,75,287,104},["tiles"]={{2,0.9775390625,0.91552734375,0.998046875,0.9296875}},["glow"]="shoulder"}},["384"]={{["group"]="foundation",["rect"]={24,27,360,199},["tiles"]={{1,0.001953125,0.001953125,0.330078125,0.169921875}}},{["group"]="foundation",["rect"]={24,199,50,262},["tiles"]={{1,0.7705078125,0.837890625,0.7958984375,0.8994140625}}},{["group"]="foundation",["rect"]={332,199,359,262},["tiles"]={{1,0.7998046875,0.837890625,0.826171875,0.8994140625}}},{["group"]="foundation",["rect"]={50,199,332,265},["tiles"]={{1,0.4912109375,0.837890625,0.7666015625,0.90234375},{2,0.001953125,0.00390625,0.27734375,0.1328125},{2,0.28125,0.00390625,0.556640625,0.1328125},{2,0.560546875,0.00390625,0.8359375,0.1328125},{2,0.001953125,0.140625,0.27734375,0.26953125},{2,0.28125,0.140625,0.556640625,0.26953125},{2,0.560546875,0.140625,0.8359375,0.26953125},{2,0.001953125,0.27734375,0.27734375,0.40625},{2,0.28125,0.27734375,0.556640625,0.40625},{2,0.560546875,0.27734375,0.8359375,0.40625},{2,0.001953125,0.4140625,0.27734375,0.54296875},{2,0.28125,0.4140625,0.556640625,0.54296875}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={21,242,60,310},["tiles"]={{1,0.4091796875,0.837890625,0.447265625,0.904296875}}},{["group"]="bannerFloaters",["rect"]={326,242,363,309},["tiles"]={{1,0.451171875,0.837890625,0.4873046875,0.9033203125}}},{["group"]="body",["rect"]={48,227,153,229},["tiles"]={{3,0.001953125,0.9970703125,0.1044921875,0.998046875}}},{["group"]="body",["rect"]={48,229,87,267},["tiles"]={{4,0.2822265625,0.68017578125,0.3203125,0.69873046875}}},{["group"]="body",["rect"]={151,229,153,267},["tiles"]={{4,0.9951171875,0.5478515625,0.9970703125,0.56640625}}},{["group"]="body",["rect"]={87,229,151,267},["tiles"]={{4,0.32421875,0.68017578125,0.38671875,0.69873046875},{4,0.390625,0.68017578125,0.453125,0.69873046875},{4,0.45703125,0.68017578125,0.51953125,0.69873046875},{4,0.5234375,0.68017578125,0.5859375,0.69873046875},{4,0.58984375,0.68017578125,0.65234375,0.69873046875},{4,0.65625,0.68017578125,0.71875,0.69873046875},{4,0.72265625,0.68017578125,0.78515625,0.69873046875},{4,0.7890625,0.68017578125,0.8515625,0.69873046875},{4,0.85546875,0.68017578125,0.91796875,0.69873046875},{4,0.921875,0.68017578125,0.984375,0.69873046875},{4,0.001953125,0.70263671875,0.064453125,0.72119140625},{4,0.068359375,0.70263671875,0.130859375,0.72119140625}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={47,267,153,375},["tiles"]={{3,0.7666015625,0.2470703125,0.8701171875,0.2998046875},{3,0.8740234375,0.2470703125,0.9775390625,0.2998046875},{3,0.7666015625,0.302734375,0.8701171875,0.35546875},{3,0.8740234375,0.302734375,0.9775390625,0.35546875},{3,0.7666015625,0.3583984375,0.8701171875,0.4111328125},{3,0.8740234375,0.3583984375,0.9775390625,0.4111328125},{3,0.7666015625,0.4140625,0.8701171875,0.466796875},{3,0.8740234375,0.4140625,0.9775390625,0.466796875},{3,0.7666015625,0.4697265625,0.8701171875,0.5224609375},{3,0.8740234375,0.4697265625,0.9775390625,0.5224609375},{3,0.7666015625,0.525390625,0.8701171875,0.578125},{3,0.8740234375,0.525390625,0.9775390625,0.578125},{3,0.7666015625,0.5810546875,0.8701171875,0.6337890625},{3,0.8740234375,0.5810546875,0.9775390625,0.6337890625},{3,0.7666015625,0.63671875,0.8701171875,0.689453125},{3,0.8740234375,0.63671875,0.9775390625,0.689453125},{3,0.7666015625,0.6923828125,0.8701171875,0.7451171875},{3,0.8740234375,0.6923828125,0.9775390625,0.7451171875},{3,0.7666015625,0.748046875,0.8701171875,0.80078125},{3,0.8740234375,0.748046875,0.9775390625,0.80078125},{3,0.2568359375,0.8037109375,0.3603515625,0.8564453125},{3,0.3642578125,0.8037109375,0.4677734375,0.8564453125},{3,0.4716796875,0.8037109375,0.5751953125,0.8564453125},{3,0.5791015625,0.8037109375,0.6826171875,0.8564453125},{3,0.6865234375,0.8037109375,0.7900390625,0.8564453125},{3,0.7939453125,0.8037109375,0.8974609375,0.8564453125},{3,0.001953125,0.859375,0.10546875,0.912109375},{3,0.109375,0.859375,0.212890625,0.912109375},{3,0.216796875,0.859375,0.3203125,0.912109375},{3,0.32421875,0.859375,0.427734375,0.912109375},{3,0.431640625,0.859375,0.53515625,0.912109375},{3,0.5390625,0.859375,0.642578125,0.912109375},{3,0.646484375,0.859375,0.75,0.912109375},{3,0.75390625,0.859375,0.857421875,0.912109375},{3,0.861328125,0.859375,0.96484375,0.912109375},{3,0.001953125,0.9140625,0.10546875,0.966796875},{3,0.109375,0.9140625,0.212890625,0.966796875},{3,0.216796875,0.9140625,0.3203125,0.966796875},{3,0.32421875,0.9140625,0.427734375,0.966796875},{3,0.431640625,0.9140625,0.53515625,0.966796875},{3,0.5390625,0.9140625,0.642578125,0.966796875},{3,0.646484375,0.9140625,0.75,0.966796875},{3,0.75390625,0.9140625,0.857421875,0.966796875},{3,0.861328125,0.9140625,0.96484375,0.966796875},{4,0.001953125,0.0009765625,0.10546875,0.0537109375},{4,0.109375,0.0009765625,0.212890625,0.0537109375},{4,0.216796875,0.0009765625,0.3203125,0.0537109375},{4,0.32421875,0.0009765625,0.427734375,0.0537109375},{4,0.431640625,0.0009765625,0.53515625,0.0537109375},{4,0.5390625,0.0009765625,0.642578125,0.0537109375},{4,0.646484375,0.0009765625,0.75,0.0537109375},{4,0.75390625,0.0009765625,0.857421875,0.0537109375},{4,0.861328125,0.0009765625,0.96484375,0.0537109375},{4,0.001953125,0.0556640625,0.10546875,0.1083984375},{4,0.109375,0.0556640625,0.212890625,0.1083984375},{4,0.216796875,0.0556640625,0.3203125,0.1083984375},{4,0.32421875,0.0556640625,0.427734375,0.1083984375},{4,0.431640625,0.0556640625,0.53515625,0.1083984375},{4,0.5390625,0.0556640625,0.642578125,0.1083984375},{4,0.646484375,0.0556640625,0.75,0.1083984375},{4,0.75390625,0.0556640625,0.857421875,0.1083984375},{4,0.861328125,0.0556640625,0.96484375,0.1083984375},{4,0.001953125,0.1103515625,0.10546875,0.1630859375},{4,0.109375,0.1103515625,0.212890625,0.1630859375}},["clip"]="left-banner"},{["group"]="body",["rect"]={231,227,335,229},["tiles"]={{3,0.1083984375,0.9970703125,0.2099609375,0.998046875}}},{["group"]="body",["rect"]={231,229,233,266},["tiles"]={{4,0.9951171875,0.58349609375,0.9970703125,0.6015625}}},{["group"]="body",["rect"]={299,229,335,266},["tiles"]={{4,0.9228515625,0.70263671875,0.9580078125,0.720703125}}},{["group"]="body",["rect"]={233,229,299,266},["tiles"]={{4,0.7900390625,0.72314453125,0.8544921875,0.7412109375},{4,0.8583984375,0.72314453125,0.9228515625,0.7412109375},{4,0.9267578125,0.72314453125,0.9912109375,0.7412109375},{4,0.7900390625,0.74365234375,0.8544921875,0.76171875},{4,0.8583984375,0.74365234375,0.9228515625,0.76171875},{4,0.9267578125,0.74365234375,0.9912109375,0.76171875},{4,0.7900390625,0.76416015625,0.8544921875,0.7822265625},{4,0.8583984375,0.76416015625,0.9228515625,0.7822265625},{4,0.9267578125,0.76416015625,0.9912109375,0.7822265625},{4,0.001953125,0.78466796875,0.06640625,0.802734375},{4,0.0703125,0.78466796875,0.134765625,0.802734375},{4,0.138671875,0.78466796875,0.203125,0.802734375}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={230,266,336,374},["tiles"]={{4,0.216796875,0.1103515625,0.3203125,0.1630859375},{4,0.32421875,0.1103515625,0.427734375,0.1630859375},{4,0.431640625,0.1103515625,0.53515625,0.1630859375},{4,0.5390625,0.1103515625,0.642578125,0.1630859375},{4,0.646484375,0.1103515625,0.75,0.1630859375},{4,0.75390625,0.1103515625,0.857421875,0.1630859375},{4,0.861328125,0.1103515625,0.96484375,0.1630859375},{4,0.001953125,0.1650390625,0.10546875,0.2177734375},{4,0.109375,0.1650390625,0.212890625,0.2177734375},{4,0.216796875,0.1650390625,0.3203125,0.2177734375},{4,0.32421875,0.1650390625,0.427734375,0.2177734375},{4,0.431640625,0.1650390625,0.53515625,0.2177734375},{4,0.5390625,0.1650390625,0.642578125,0.2177734375},{4,0.646484375,0.1650390625,0.75,0.2177734375},{4,0.75390625,0.1650390625,0.857421875,0.2177734375},{4,0.861328125,0.1650390625,0.96484375,0.2177734375},{4,0.001953125,0.2197265625,0.10546875,0.2724609375},{4,0.109375,0.2197265625,0.212890625,0.2724609375},{4,0.216796875,0.2197265625,0.3203125,0.2724609375},{4,0.32421875,0.2197265625,0.427734375,0.2724609375},{4,0.431640625,0.2197265625,0.53515625,0.2724609375},{4,0.5390625,0.2197265625,0.642578125,0.2724609375},{4,0.646484375,0.2197265625,0.75,0.2724609375},{4,0.75390625,0.2197265625,0.857421875,0.2724609375},{4,0.861328125,0.2197265625,0.96484375,0.2724609375},{4,0.001953125,0.2744140625,0.10546875,0.3271484375},{4,0.109375,0.2744140625,0.212890625,0.3271484375},{4,0.216796875,0.2744140625,0.3203125,0.3271484375},{4,0.32421875,0.2744140625,0.427734375,0.3271484375},{4,0.431640625,0.2744140625,0.53515625,0.3271484375},{4,0.5390625,0.2744140625,0.642578125,0.3271484375},{4,0.646484375,0.2744140625,0.75,0.3271484375},{4,0.75390625,0.2744140625,0.857421875,0.3271484375},{4,0.861328125,0.2744140625,0.96484375,0.3271484375},{4,0.001953125,0.3291015625,0.10546875,0.3818359375},{4,0.109375,0.3291015625,0.212890625,0.3818359375},{4,0.216796875,0.3291015625,0.3203125,0.3818359375},{4,0.32421875,0.3291015625,0.427734375,0.3818359375},{4,0.431640625,0.3291015625,0.53515625,0.3818359375},{4,0.5390625,0.3291015625,0.642578125,0.3818359375},{4,0.646484375,0.3291015625,0.75,0.3818359375},{4,0.75390625,0.3291015625,0.857421875,0.3818359375},{4,0.861328125,0.3291015625,0.96484375,0.3818359375},{4,0.001953125,0.3837890625,0.10546875,0.4365234375},{4,0.109375,0.3837890625,0.212890625,0.4365234375},{4,0.216796875,0.3837890625,0.3203125,0.4365234375},{4,0.32421875,0.3837890625,0.427734375,0.4365234375},{4,0.431640625,0.3837890625,0.53515625,0.4365234375},{4,0.5390625,0.3837890625,0.642578125,0.4365234375},{4,0.646484375,0.3837890625,0.75,0.4365234375},{4,0.75390625,0.3837890625,0.857421875,0.4365234375},{4,0.861328125,0.3837890625,0.96484375,0.4365234375},{4,0.001953125,0.4384765625,0.10546875,0.4912109375},{4,0.109375,0.4384765625,0.212890625,0.4912109375},{4,0.216796875,0.4384765625,0.3203125,0.4912109375},{4,0.32421875,0.4384765625,0.427734375,0.4912109375},{4,0.431640625,0.4384765625,0.53515625,0.4912109375},{4,0.5390625,0.4384765625,0.642578125,0.4912109375},{4,0.646484375,0.4384765625,0.75,0.4912109375},{4,0.75390625,0.4384765625,0.857421875,0.4912109375},{4,0.861328125,0.4384765625,0.96484375,0.4912109375},{4,0.001953125,0.4931640625,0.10546875,0.5458984375},{4,0.109375,0.4931640625,0.212890625,0.5458984375},{4,0.216796875,0.4931640625,0.3203125,0.5458984375}},["clip"]="right-banner"},{["group"]="body",["rect"]={51,82,334,84},["tiles"]={{3,0.2138671875,0.9970703125,0.490234375,0.998046875}}},{["group"]="body",["rect"]={51,153,334,195},["tiles"]={{4,0.001953125,0.68017578125,0.2783203125,0.70068359375}}},{["group"]="body",["rect"]={51,84,154,153},["tiles"]={{4,0.32421875,0.4931640625,0.4248046875,0.52685546875}}},{["group"]="body",["rect"]={231,84,334,153},["tiles"]={{4,0.4287109375,0.4931640625,0.529296875,0.52685546875}}},{["group"]="body",["rect"]={154,84,231,153},["tiles"]={{4,0.533203125,0.4931640625,0.6083984375,0.52685546875},{4,0.6123046875,0.4931640625,0.6875,0.52685546875},{4,0.69140625,0.4931640625,0.7666015625,0.52685546875},{4,0.7705078125,0.4931640625,0.845703125,0.52685546875},{4,0.849609375,0.4931640625,0.9248046875,0.52685546875},{4,0.001953125,0.5478515625,0.0771484375,0.58154296875},{4,0.0810546875,0.5478515625,0.15625,0.58154296875},{4,0.16015625,0.5478515625,0.2353515625,0.58154296875},{4,0.2392578125,0.5478515625,0.314453125,0.58154296875},{4,0.318359375,0.5478515625,0.3935546875,0.58154296875},{4,0.3974609375,0.5478515625,0.47265625,0.58154296875},{4,0.4765625,0.5478515625,0.5517578125,0.58154296875},{4,0.5556640625,0.5478515625,0.630859375,0.58154296875},{4,0.634765625,0.5478515625,0.7099609375,0.58154296875},{4,0.7138671875,0.5478515625,0.7890625,0.58154296875},{4,0.79296875,0.5478515625,0.8681640625,0.58154296875},{4,0.8720703125,0.5478515625,0.947265625,0.58154296875},{4,0.001953125,0.58349609375,0.0771484375,0.6171875},{4,0.0810546875,0.58349609375,0.15625,0.6171875},{4,0.16015625,0.58349609375,0.2353515625,0.6171875},{4,0.2392578125,0.58349609375,0.314453125,0.6171875},{4,0.318359375,0.58349609375,0.3935546875,0.6171875},{4,0.3974609375,0.58349609375,0.47265625,0.6171875},{4,0.4765625,0.58349609375,0.5517578125,0.6171875},{4,0.5556640625,0.58349609375,0.630859375,0.6171875},{4,0.634765625,0.58349609375,0.7099609375,0.6171875},{4,0.7138671875,0.58349609375,0.7890625,0.6171875},{4,0.79296875,0.58349609375,0.8681640625,0.6171875},{4,0.8720703125,0.58349609375,0.947265625,0.6171875},{4,0.001953125,0.619140625,0.0771484375,0.65283203125},{4,0.0810546875,0.619140625,0.15625,0.65283203125},{4,0.16015625,0.619140625,0.2353515625,0.65283203125},{4,0.2392578125,0.619140625,0.314453125,0.65283203125},{4,0.318359375,0.619140625,0.3935546875,0.65283203125}},["receiverFor"]="iris"},{["group"]="body",["rect"]={51,233,334,235},["tiles"]={{3,0.494140625,0.9970703125,0.7705078125,0.998046875}}},{["group"]="body",["rect"]={51,195,60,233},["tiles"]={{4,0.98828125,0.68017578125,0.9970703125,0.69873046875}}},{["group"]="body",["rect"]={325,195,334,233},["tiles"]={{3,0.9814453125,0.2470703125,0.990234375,0.265625}}},{["group"]="body",["rect"]={60,195,325,233},["tiles"]={{4,0.134765625,0.70263671875,0.3935546875,0.72119140625},{4,0.3974609375,0.70263671875,0.65625,0.72119140625},{4,0.66015625,0.70263671875,0.9189453125,0.72119140625},{4,0.001953125,0.72314453125,0.2607421875,0.74169921875},{4,0.2646484375,0.72314453125,0.5234375,0.74169921875},{4,0.52734375,0.72314453125,0.7861328125,0.74169921875},{4,0.001953125,0.74365234375,0.2607421875,0.76220703125},{4,0.2646484375,0.74365234375,0.5234375,0.76220703125},{4,0.52734375,0.74365234375,0.7861328125,0.76220703125},{4,0.001953125,0.76416015625,0.2607421875,0.78271484375},{4,0.2646484375,0.76416015625,0.5234375,0.78271484375},{4,0.52734375,0.76416015625,0.7861328125,0.78271484375}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={63,201,320,259},["tiles"]={{4,0.3974609375,0.619140625,0.6484375,0.6474609375}}},{["group"]="scroll",["rect"]={63,259,320,369},["tiles"]={{3,0.666015625,0.18701171875,0.9169921875,0.24072265625},{3,0.001953125,0.2470703125,0.2529296875,0.30078125},{3,0.2568359375,0.2470703125,0.5078125,0.30078125},{3,0.51171875,0.2470703125,0.7626953125,0.30078125},{3,0.001953125,0.302734375,0.2529296875,0.3564453125},{3,0.2568359375,0.302734375,0.5078125,0.3564453125},{3,0.51171875,0.302734375,0.7626953125,0.3564453125},{3,0.001953125,0.3583984375,0.2529296875,0.412109375},{3,0.2568359375,0.3583984375,0.5078125,0.412109375},{3,0.51171875,0.3583984375,0.7626953125,0.412109375},{3,0.001953125,0.4140625,0.2529296875,0.4677734375},{3,0.2568359375,0.4140625,0.5078125,0.4677734375},{3,0.51171875,0.4140625,0.7626953125,0.4677734375},{3,0.001953125,0.4697265625,0.2529296875,0.5234375},{3,0.2568359375,0.4697265625,0.5078125,0.5234375},{3,0.51171875,0.4697265625,0.7626953125,0.5234375},{3,0.001953125,0.525390625,0.2529296875,0.5791015625},{3,0.2568359375,0.525390625,0.5078125,0.5791015625},{3,0.51171875,0.525390625,0.7626953125,0.5791015625},{3,0.001953125,0.5810546875,0.2529296875,0.634765625},{3,0.2568359375,0.5810546875,0.5078125,0.634765625},{3,0.51171875,0.5810546875,0.7626953125,0.634765625},{3,0.001953125,0.63671875,0.2529296875,0.6904296875},{3,0.2568359375,0.63671875,0.5078125,0.6904296875},{3,0.51171875,0.63671875,0.7626953125,0.6904296875},{3,0.001953125,0.6923828125,0.2529296875,0.74609375},{3,0.2568359375,0.6923828125,0.5078125,0.74609375},{3,0.51171875,0.6923828125,0.7626953125,0.74609375},{3,0.001953125,0.748046875,0.2529296875,0.8017578125},{3,0.2568359375,0.748046875,0.5078125,0.8017578125},{3,0.51171875,0.748046875,0.7626953125,0.8017578125},{3,0.001953125,0.8037109375,0.2529296875,0.857421875}},["clip"]="scroll"},{["group"]="scroll",["rect"]={65,212,319,235},["tiles"]={{4,0.2578125,0.78466796875,0.505859375,0.7958984375}},["glow"]="scroll"},{["group"]="body",["rect"]={102,8,282,18},["tiles"]={{4,0.7958984375,0.826171875,0.9716796875,0.8310546875}}},{["group"]="body",["rect"]={102,137,282,139},["tiles"]={{3,0.7744140625,0.9970703125,0.9501953125,0.998046875}}},{["group"]="body",["rect"]={102,18,145,137},["tiles"]={{3,0.0908203125,0.0009765625,0.1328125,0.05908203125}}},{["group"]="body",["rect"]={239,18,282,137},["tiles"]={{3,0.13671875,0.0009765625,0.1787109375,0.05908203125}}},{["group"]="body",["rect"]={145,18,239,137},["tiles"]={{3,0.1826171875,0.0009765625,0.2744140625,0.05908203125},{3,0.2783203125,0.0009765625,0.3701171875,0.05908203125},{3,0.3740234375,0.0009765625,0.4658203125,0.05908203125},{3,0.4697265625,0.0009765625,0.5615234375,0.05908203125},{3,0.5654296875,0.0009765625,0.6572265625,0.05908203125},{3,0.6611328125,0.0009765625,0.7529296875,0.05908203125},{3,0.7568359375,0.0009765625,0.8486328125,0.05908203125},{3,0.8525390625,0.0009765625,0.9443359375,0.05908203125},{3,0.001953125,0.06689453125,0.09375,0.125},{3,0.09765625,0.06689453125,0.189453125,0.125},{3,0.193359375,0.06689453125,0.28515625,0.125},{3,0.2890625,0.06689453125,0.380859375,0.125},{3,0.384765625,0.06689453125,0.4765625,0.125},{3,0.48046875,0.06689453125,0.572265625,0.125},{3,0.576171875,0.06689453125,0.66796875,0.125},{3,0.671875,0.06689453125,0.763671875,0.125},{3,0.767578125,0.06689453125,0.859375,0.125},{3,0.86328125,0.06689453125,0.955078125,0.125},{3,0.001953125,0.126953125,0.09375,0.18505859375},{3,0.09765625,0.126953125,0.189453125,0.18505859375},{3,0.193359375,0.126953125,0.28515625,0.18505859375},{3,0.2890625,0.126953125,0.380859375,0.18505859375},{3,0.384765625,0.126953125,0.4765625,0.18505859375},{3,0.48046875,0.126953125,0.572265625,0.18505859375},{3,0.576171875,0.126953125,0.66796875,0.18505859375},{3,0.671875,0.126953125,0.763671875,0.18505859375},{3,0.767578125,0.126953125,0.859375,0.18505859375},{3,0.86328125,0.126953125,0.955078125,0.18505859375},{3,0.001953125,0.18701171875,0.09375,0.2451171875},{3,0.09765625,0.18701171875,0.189453125,0.2451171875},{3,0.193359375,0.18701171875,0.28515625,0.2451171875},{3,0.2890625,0.18701171875,0.380859375,0.2451171875},{3,0.384765625,0.18701171875,0.4765625,0.2451171875},{3,0.48046875,0.18701171875,0.572265625,0.2451171875}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={158,33,227,49},["tiles"]={{4,0.3896484375,0.826171875,0.45703125,0.833984375}}},{["group"]="kirinTor",["rect"]={158,33,227,49},["tiles"]={{4,0.4609375,0.826171875,0.5283203125,0.833984375}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={158,49,227,67},["tiles"]={{4,0.82421875,0.78466796875,0.8916015625,0.79345703125},{4,0.8955078125,0.78466796875,0.962890625,0.79345703125},{4,0.001953125,0.8046875,0.0693359375,0.8134765625},{4,0.0732421875,0.8046875,0.140625,0.8134765625},{4,0.14453125,0.8046875,0.2119140625,0.8134765625},{4,0.2158203125,0.8046875,0.283203125,0.8134765625},{4,0.287109375,0.8046875,0.3544921875,0.8134765625},{4,0.3583984375,0.8046875,0.42578125,0.8134765625},{4,0.4296875,0.8046875,0.4970703125,0.8134765625},{4,0.5009765625,0.8046875,0.568359375,0.8134765625},{4,0.572265625,0.8046875,0.6396484375,0.8134765625},{4,0.6435546875,0.8046875,0.7109375,0.8134765625},{4,0.71484375,0.8046875,0.7822265625,0.8134765625},{4,0.7861328125,0.8046875,0.853515625,0.8134765625},{4,0.857421875,0.8046875,0.9248046875,0.8134765625},{4,0.9287109375,0.8046875,0.99609375,0.8134765625},{4,0.001953125,0.8154296875,0.0693359375,0.82421875}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={158,49,227,67},["tiles"]={{4,0.0732421875,0.8154296875,0.140625,0.82421875},{4,0.14453125,0.8154296875,0.2119140625,0.82421875},{4,0.2158203125,0.8154296875,0.283203125,0.82421875},{4,0.287109375,0.8154296875,0.3544921875,0.82421875},{4,0.3583984375,0.8154296875,0.42578125,0.82421875},{4,0.4296875,0.8154296875,0.4970703125,0.82421875},{4,0.5009765625,0.8154296875,0.568359375,0.82421875},{4,0.572265625,0.8154296875,0.6396484375,0.82421875},{4,0.6435546875,0.8154296875,0.7109375,0.82421875},{4,0.71484375,0.8154296875,0.7822265625,0.82421875},{4,0.7861328125,0.8154296875,0.853515625,0.82421875},{4,0.857421875,0.8154296875,0.9248046875,0.82421875},{4,0.9287109375,0.8154296875,0.99609375,0.82421875},{4,0.001953125,0.826171875,0.0693359375,0.8349609375},{4,0.0732421875,0.826171875,0.140625,0.8349609375},{4,0.14453125,0.826171875,0.2119140625,0.8349609375},{4,0.2158203125,0.826171875,0.283203125,0.8349609375}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={158,67,227,139},["tiles"]={{3,0.9208984375,0.18701171875,0.98828125,0.22216796875}}},{["group"]="kirinTor",["rect"]={158,67,227,139},["tiles"]={{3,0.9013671875,0.8037109375,0.96875,0.8388671875}},["glow"]="eye"},{["group"]="shards",["rect"]={112,23,153,71},["tiles"]={{3,0.669921875,0.96875,0.7099609375,0.9921875},{3,0.7138671875,0.96875,0.75390625,0.9921875},{3,0.7578125,0.96875,0.7978515625,0.9921875},{3,0.8017578125,0.96875,0.841796875,0.9921875},{3,0.845703125,0.96875,0.8857421875,0.9921875},{3,0.8896484375,0.96875,0.9296875,0.9921875},{3,0.93359375,0.96875,0.9736328125,0.9921875},{4,0.001953125,0.65478515625,0.0419921875,0.67822265625},{4,0.0458984375,0.65478515625,0.0859375,0.67822265625},{4,0.08984375,0.65478515625,0.1298828125,0.67822265625},{4,0.1337890625,0.65478515625,0.173828125,0.67822265625},{4,0.177734375,0.65478515625,0.2177734375,0.67822265625},{4,0.2216796875,0.65478515625,0.26171875,0.67822265625},{4,0.265625,0.65478515625,0.3056640625,0.67822265625},{4,0.3095703125,0.65478515625,0.349609375,0.67822265625}},["shard"]=1},{["group"]="shards",["rect"]={114,25,152,70},["tiles"]={{4,0.353515625,0.65478515625,0.390625,0.6767578125},{4,0.39453125,0.65478515625,0.431640625,0.6767578125},{4,0.435546875,0.65478515625,0.47265625,0.6767578125},{4,0.4765625,0.65478515625,0.513671875,0.6767578125},{4,0.517578125,0.65478515625,0.5546875,0.6767578125},{4,0.55859375,0.65478515625,0.595703125,0.6767578125},{4,0.599609375,0.65478515625,0.63671875,0.6767578125},{4,0.640625,0.65478515625,0.677734375,0.6767578125},{4,0.681640625,0.65478515625,0.71875,0.6767578125},{4,0.72265625,0.65478515625,0.759765625,0.6767578125},{4,0.763671875,0.65478515625,0.80078125,0.6767578125},{4,0.8046875,0.65478515625,0.841796875,0.6767578125},{4,0.845703125,0.65478515625,0.8828125,0.6767578125},{4,0.88671875,0.65478515625,0.923828125,0.6767578125},{4,0.927734375,0.65478515625,0.96484375,0.6767578125}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={131,47,153,73},["tiles"]={{3,0.96875,0.859375,0.990234375,0.8720703125},{3,0.96875,0.9140625,0.990234375,0.9267578125},{4,0.96875,0.0009765625,0.990234375,0.013671875},{4,0.96875,0.0556640625,0.990234375,0.068359375},{4,0.96875,0.1103515625,0.990234375,0.123046875},{4,0.96875,0.1650390625,0.990234375,0.177734375},{4,0.96875,0.2197265625,0.990234375,0.232421875},{4,0.96875,0.2744140625,0.990234375,0.287109375},{4,0.96875,0.3291015625,0.990234375,0.341796875},{4,0.96875,0.3837890625,0.990234375,0.396484375},{4,0.96875,0.4384765625,0.990234375,0.451171875},{4,0.96875,0.65478515625,0.990234375,0.66748046875},{4,0.9619140625,0.70263671875,0.9833984375,0.71533203125},{4,0.20703125,0.78466796875,0.228515625,0.79736328125},{4,0.232421875,0.78466796875,0.25390625,0.79736328125}},["shard"]=2},{["group"]="shards",["rect"]={133,49,152,72},["tiles"]={{3,0.9775390625,0.96875,0.99609375,0.97998046875},{4,0.509765625,0.78466796875,0.5283203125,0.7958984375},{4,0.5322265625,0.78466796875,0.55078125,0.7958984375},{4,0.5546875,0.78466796875,0.5732421875,0.7958984375},{4,0.5771484375,0.78466796875,0.595703125,0.7958984375},{4,0.599609375,0.78466796875,0.6181640625,0.7958984375},{4,0.6220703125,0.78466796875,0.640625,0.7958984375},{4,0.64453125,0.78466796875,0.6630859375,0.7958984375},{4,0.6669921875,0.78466796875,0.685546875,0.7958984375},{4,0.689453125,0.78466796875,0.7080078125,0.7958984375},{4,0.7119140625,0.78466796875,0.73046875,0.7958984375},{4,0.734375,0.78466796875,0.7529296875,0.7958984375},{4,0.7568359375,0.78466796875,0.775390625,0.7958984375},{4,0.779296875,0.78466796875,0.7978515625,0.7958984375},{4,0.8017578125,0.78466796875,0.8203125,0.7958984375}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={226,22,267,76},["tiles"]={{4,0.951171875,0.5478515625,0.9912109375,0.57421875},{4,0.951171875,0.58349609375,0.9912109375,0.60986328125},{3,0.9482421875,0.0009765625,0.98828125,0.02734375},{4,0.9287109375,0.4931640625,0.96875,0.51953125},{4,0.65234375,0.619140625,0.6923828125,0.6455078125},{4,0.6962890625,0.619140625,0.736328125,0.6455078125},{4,0.740234375,0.619140625,0.7802734375,0.6455078125},{4,0.7841796875,0.619140625,0.82421875,0.6455078125},{4,0.828125,0.619140625,0.8681640625,0.6455078125},{4,0.8720703125,0.619140625,0.912109375,0.6455078125},{4,0.916015625,0.619140625,0.9560546875,0.6455078125},{3,0.001953125,0.96875,0.0419921875,0.9951171875},{3,0.0458984375,0.96875,0.0859375,0.9951171875},{3,0.08984375,0.96875,0.1298828125,0.9951171875},{3,0.1337890625,0.96875,0.173828125,0.9951171875}},["shard"]=3},{["group"]="shards",["rect"]={228,24,266,74},["tiles"]={{4,0.9599609375,0.619140625,0.9970703125,0.6435546875},{3,0.958984375,0.06689453125,0.99609375,0.09130859375},{3,0.958984375,0.126953125,0.99609375,0.1513671875},{3,0.177734375,0.96875,0.21484375,0.9931640625},{3,0.21875,0.96875,0.255859375,0.9931640625},{3,0.259765625,0.96875,0.296875,0.9931640625},{3,0.30078125,0.96875,0.337890625,0.9931640625},{3,0.341796875,0.96875,0.37890625,0.9931640625},{3,0.3828125,0.96875,0.419921875,0.9931640625},{3,0.423828125,0.96875,0.4609375,0.9931640625},{3,0.46484375,0.96875,0.501953125,0.9931640625},{3,0.505859375,0.96875,0.54296875,0.9931640625},{3,0.546875,0.96875,0.583984375,0.9931640625},{3,0.587890625,0.96875,0.625,0.9931640625},{3,0.62890625,0.96875,0.666015625,0.9931640625}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={234,48,251,66},["tiles"]={{3,0.9814453125,0.302734375,0.998046875,0.3115234375},{3,0.9814453125,0.3583984375,0.998046875,0.3671875},{3,0.9814453125,0.4140625,0.998046875,0.4228515625},{3,0.9814453125,0.4697265625,0.998046875,0.478515625},{3,0.9814453125,0.525390625,0.998046875,0.5341796875},{3,0.9814453125,0.5810546875,0.998046875,0.58984375},{3,0.9814453125,0.63671875,0.998046875,0.6455078125},{3,0.9814453125,0.6923828125,0.998046875,0.701171875},{3,0.9814453125,0.748046875,0.998046875,0.7568359375},{4,0.966796875,0.78466796875,0.9833984375,0.79345703125},{4,0.287109375,0.826171875,0.3037109375,0.8349609375},{4,0.3076171875,0.826171875,0.32421875,0.8349609375},{4,0.328125,0.826171875,0.3447265625,0.8349609375},{4,0.3486328125,0.826171875,0.365234375,0.8349609375},{4,0.369140625,0.826171875,0.3857421875,0.8349609375}},["shard"]=4},{["group"]="shards",["rect"]={235,49,249,65},["tiles"]={{4,0.5322265625,0.826171875,0.5458984375,0.833984375},{4,0.5498046875,0.826171875,0.5634765625,0.833984375},{4,0.5673828125,0.826171875,0.5810546875,0.833984375},{4,0.5849609375,0.826171875,0.5986328125,0.833984375},{4,0.6025390625,0.826171875,0.6162109375,0.833984375},{4,0.6201171875,0.826171875,0.6337890625,0.833984375},{4,0.6376953125,0.826171875,0.6513671875,0.833984375},{4,0.6552734375,0.826171875,0.6689453125,0.833984375},{4,0.6728515625,0.826171875,0.6865234375,0.833984375},{4,0.6904296875,0.826171875,0.7041015625,0.833984375},{4,0.7080078125,0.826171875,0.7216796875,0.833984375},{4,0.7255859375,0.826171875,0.7392578125,0.833984375},{4,0.7431640625,0.826171875,0.7568359375,0.833984375},{4,0.7607421875,0.826171875,0.7744140625,0.833984375},{4,0.7783203125,0.826171875,0.7919921875,0.833984375}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={1,21,89,139},["tiles"]={{3,0.576171875,0.18701171875,0.662109375,0.24462890625}}},{["group"]="shoulderFloaters",["rect"]={3,106,27,137},["tiles"]={{4,0.97265625,0.4931640625,0.99609375,0.50830078125}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={296,8,383,139},["tiles"]={{3,0.001953125,0.0009765625,0.0869140625,0.06494140625}}},{["group"]="shoulderFloaters",["rect"]={356,101,381,137},["tiles"]={{3,0.97265625,0.8037109375,0.9970703125,0.8212890625}},["glow"]="shoulder"}},["480"]={{["group"]="foundation",["rect"]={29,34,450,252},["tiles"]={{1,0.001953125,0.001953125,0.4130859375,0.21484375}}},{["group"]="foundation",["rect"]={30,252,64,327},["tiles"]={{1,0.9541015625,0.8369140625,0.9873046875,0.91015625}}},{["group"]="foundation",["rect"]={415,252,448,327},["tiles"]={{2,0.962890625,0.2080078125,0.9951171875,0.28125}}},{["group"]="foundation",["rect"]={64,252,415,332},["tiles"]={{1,0.607421875,0.8369140625,0.9501953125,0.9150390625},{2,0.2421875,0.3818359375,0.5849609375,0.4599609375},{2,0.5888671875,0.3818359375,0.931640625,0.4599609375},{2,0.001953125,0.5556640625,0.3447265625,0.6337890625},{2,0.3486328125,0.5556640625,0.69140625,0.6337890625},{2,0.001953125,0.6376953125,0.3447265625,0.7158203125},{2,0.3486328125,0.6376953125,0.69140625,0.7158203125},{2,0.001953125,0.7197265625,0.3447265625,0.7978515625},{2,0.3486328125,0.7197265625,0.69140625,0.7978515625},{2,0.001953125,0.8017578125,0.3447265625,0.8798828125},{2,0.3486328125,0.8017578125,0.69140625,0.8798828125},{2,0.001953125,0.8837890625,0.3447265625,0.9619140625}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={26,303,74,387},["tiles"]={{1,0.5068359375,0.8369140625,0.5537109375,0.9189453125}}},{["group"]="bannerFloaters",["rect"]={406,303,453,386},["tiles"]={{1,0.5576171875,0.8369140625,0.603515625,0.91796875}}},{["group"]="body",["rect"]={61,285,191,286},["tiles"]={{4,0.484375,0.9892578125,0.611328125,0.98974609375}}},{["group"]="body",["rect"]={61,286,109,334},["tiles"]={{5,0.49609375,0.56591796875,0.54296875,0.58935546875}}},{["group"]="body",["rect"]={189,286,191,334},["tiles"]={{4,0.98828125,0.94482421875,0.990234375,0.96826171875}}},{["group"]="body",["rect"]={109,286,189,334},["tiles"]={{5,0.546875,0.56591796875,0.625,0.58935546875},{5,0.62890625,0.56591796875,0.70703125,0.58935546875},{5,0.7109375,0.56591796875,0.7890625,0.58935546875},{5,0.79296875,0.56591796875,0.87109375,0.58935546875},{5,0.875,0.56591796875,0.953125,0.58935546875},{5,0.001953125,0.59423828125,0.080078125,0.61767578125},{5,0.083984375,0.59423828125,0.162109375,0.61767578125},{5,0.166015625,0.59423828125,0.244140625,0.61767578125},{5,0.248046875,0.59423828125,0.326171875,0.61767578125},{5,0.330078125,0.59423828125,0.408203125,0.61767578125},{5,0.412109375,0.59423828125,0.490234375,0.61767578125},{5,0.494140625,0.59423828125,0.572265625,0.61767578125}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={60,334,191,468},["tiles"]={{4,0.318359375,0.0693359375,0.4462890625,0.134765625},{4,0.4501953125,0.0693359375,0.578125,0.134765625},{4,0.58203125,0.0693359375,0.7099609375,0.134765625},{4,0.7138671875,0.0693359375,0.841796875,0.134765625},{4,0.845703125,0.0693359375,0.9736328125,0.134765625},{4,0.001953125,0.1376953125,0.1298828125,0.203125},{4,0.1337890625,0.1376953125,0.26171875,0.203125},{4,0.265625,0.1376953125,0.3935546875,0.203125},{4,0.3974609375,0.1376953125,0.525390625,0.203125},{4,0.529296875,0.1376953125,0.6572265625,0.203125},{4,0.6611328125,0.1376953125,0.7890625,0.203125},{4,0.79296875,0.1376953125,0.9208984375,0.203125},{4,0.001953125,0.205078125,0.1298828125,0.2705078125},{4,0.1337890625,0.205078125,0.26171875,0.2705078125},{4,0.265625,0.205078125,0.3935546875,0.2705078125},{4,0.3974609375,0.205078125,0.525390625,0.2705078125},{4,0.529296875,0.205078125,0.6572265625,0.2705078125},{4,0.6611328125,0.205078125,0.7890625,0.2705078125},{4,0.79296875,0.205078125,0.9208984375,0.2705078125},{4,0.001953125,0.2724609375,0.1298828125,0.337890625},{4,0.1337890625,0.2724609375,0.26171875,0.337890625},{4,0.265625,0.2724609375,0.3935546875,0.337890625},{4,0.3974609375,0.2724609375,0.525390625,0.337890625},{4,0.529296875,0.2724609375,0.6572265625,0.337890625},{4,0.6611328125,0.2724609375,0.7890625,0.337890625},{4,0.79296875,0.2724609375,0.9208984375,0.337890625},{4,0.001953125,0.33984375,0.1298828125,0.4052734375},{4,0.1337890625,0.33984375,0.26171875,0.4052734375},{4,0.265625,0.33984375,0.3935546875,0.4052734375},{4,0.3974609375,0.33984375,0.525390625,0.4052734375},{4,0.529296875,0.33984375,0.6572265625,0.4052734375},{4,0.6611328125,0.33984375,0.7890625,0.4052734375},{4,0.79296875,0.33984375,0.9208984375,0.4052734375},{4,0.001953125,0.4072265625,0.1298828125,0.47265625},{4,0.1337890625,0.4072265625,0.26171875,0.47265625},{4,0.265625,0.4072265625,0.3935546875,0.47265625},{4,0.3974609375,0.4072265625,0.525390625,0.47265625},{4,0.529296875,0.4072265625,0.6572265625,0.47265625},{4,0.6611328125,0.4072265625,0.7890625,0.47265625},{4,0.79296875,0.4072265625,0.9208984375,0.47265625},{4,0.001953125,0.474609375,0.1298828125,0.5400390625},{4,0.1337890625,0.474609375,0.26171875,0.5400390625},{4,0.265625,0.474609375,0.3935546875,0.5400390625},{4,0.3974609375,0.474609375,0.525390625,0.5400390625},{4,0.529296875,0.474609375,0.6572265625,0.5400390625},{4,0.6611328125,0.474609375,0.7890625,0.5400390625},{4,0.79296875,0.474609375,0.9208984375,0.5400390625},{4,0.001953125,0.5419921875,0.1298828125,0.607421875},{4,0.1337890625,0.5419921875,0.26171875,0.607421875},{4,0.265625,0.5419921875,0.3935546875,0.607421875},{4,0.3974609375,0.5419921875,0.525390625,0.607421875},{4,0.529296875,0.5419921875,0.6572265625,0.607421875},{4,0.6611328125,0.5419921875,0.7890625,0.607421875},{4,0.79296875,0.5419921875,0.9208984375,0.607421875},{4,0.001953125,0.609375,0.1298828125,0.6748046875},{4,0.1337890625,0.609375,0.26171875,0.6748046875},{4,0.265625,0.609375,0.3935546875,0.6748046875},{4,0.3974609375,0.609375,0.525390625,0.6748046875},{4,0.529296875,0.609375,0.6572265625,0.6748046875},{4,0.6611328125,0.609375,0.7890625,0.6748046875},{4,0.79296875,0.609375,0.9208984375,0.6748046875},{4,0.001953125,0.6767578125,0.1298828125,0.7421875},{4,0.1337890625,0.6767578125,0.26171875,0.7421875},{4,0.265625,0.6767578125,0.3935546875,0.7421875}},["clip"]="left-banner"},{["group"]="body",["rect"]={289,285,418,286},["tiles"]={{4,0.615234375,0.9892578125,0.7412109375,0.98974609375}}},{["group"]="body",["rect"]={289,286,291,333},["tiles"]={{4,0.994140625,0.94482421875,0.99609375,0.9677734375}}},{["group"]="body",["rect"]={373,286,418,333},["tiles"]={{5,0.576171875,0.59423828125,0.6201171875,0.6171875}}},{["group"]="body",["rect"]={291,286,373,333},["tiles"]={{5,0.6240234375,0.59423828125,0.7041015625,0.6171875},{5,0.7080078125,0.59423828125,0.7880859375,0.6171875},{5,0.7919921875,0.59423828125,0.8720703125,0.6171875},{5,0.8759765625,0.59423828125,0.9560546875,0.6171875},{5,0.001953125,0.61962890625,0.08203125,0.642578125},{5,0.0859375,0.61962890625,0.166015625,0.642578125},{5,0.169921875,0.61962890625,0.25,0.642578125},{5,0.25390625,0.61962890625,0.333984375,0.642578125},{5,0.337890625,0.61962890625,0.41796875,0.642578125},{5,0.421875,0.61962890625,0.501953125,0.642578125},{5,0.505859375,0.61962890625,0.5859375,0.642578125},{5,0.58984375,0.61962890625,0.669921875,0.642578125}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={289,333,420,466},["tiles"]={{4,0.3974609375,0.6767578125,0.525390625,0.74169921875},{4,0.529296875,0.6767578125,0.6572265625,0.74169921875},{4,0.6611328125,0.6767578125,0.7890625,0.74169921875},{4,0.79296875,0.6767578125,0.9208984375,0.74169921875},{4,0.001953125,0.744140625,0.1298828125,0.80908203125},{4,0.1337890625,0.744140625,0.26171875,0.80908203125},{4,0.265625,0.744140625,0.3935546875,0.80908203125},{4,0.3974609375,0.744140625,0.525390625,0.80908203125},{4,0.529296875,0.744140625,0.6572265625,0.80908203125},{4,0.6611328125,0.744140625,0.7890625,0.80908203125},{4,0.79296875,0.744140625,0.9208984375,0.80908203125},{4,0.001953125,0.81103515625,0.1298828125,0.8759765625},{4,0.1337890625,0.81103515625,0.26171875,0.8759765625},{4,0.265625,0.81103515625,0.3935546875,0.8759765625},{4,0.3974609375,0.81103515625,0.525390625,0.8759765625},{4,0.529296875,0.81103515625,0.6572265625,0.8759765625},{4,0.6611328125,0.81103515625,0.7890625,0.8759765625},{4,0.79296875,0.81103515625,0.9208984375,0.8759765625},{4,0.001953125,0.8779296875,0.1298828125,0.94287109375},{4,0.1337890625,0.8779296875,0.26171875,0.94287109375},{4,0.265625,0.8779296875,0.3935546875,0.94287109375},{4,0.3974609375,0.8779296875,0.525390625,0.94287109375},{4,0.529296875,0.8779296875,0.6572265625,0.94287109375},{4,0.6611328125,0.8779296875,0.7890625,0.94287109375},{4,0.79296875,0.8779296875,0.9208984375,0.94287109375},{5,0.001953125,0.0009765625,0.1298828125,0.06591796875},{5,0.1337890625,0.0009765625,0.26171875,0.06591796875},{5,0.265625,0.0009765625,0.3935546875,0.06591796875},{5,0.3974609375,0.0009765625,0.525390625,0.06591796875},{5,0.529296875,0.0009765625,0.6572265625,0.06591796875},{5,0.6611328125,0.0009765625,0.7890625,0.06591796875},{5,0.79296875,0.0009765625,0.9208984375,0.06591796875},{5,0.001953125,0.06787109375,0.1298828125,0.1328125},{5,0.1337890625,0.06787109375,0.26171875,0.1328125},{5,0.265625,0.06787109375,0.3935546875,0.1328125},{5,0.3974609375,0.06787109375,0.525390625,0.1328125},{5,0.529296875,0.06787109375,0.6572265625,0.1328125},{5,0.6611328125,0.06787109375,0.7890625,0.1328125},{5,0.79296875,0.06787109375,0.9208984375,0.1328125},{5,0.001953125,0.134765625,0.1298828125,0.19970703125},{5,0.1337890625,0.134765625,0.26171875,0.19970703125},{5,0.265625,0.134765625,0.3935546875,0.19970703125},{5,0.3974609375,0.134765625,0.525390625,0.19970703125},{5,0.529296875,0.134765625,0.6572265625,0.19970703125},{5,0.6611328125,0.134765625,0.7890625,0.19970703125},{5,0.79296875,0.134765625,0.9208984375,0.19970703125},{5,0.001953125,0.20166015625,0.1298828125,0.2666015625},{5,0.1337890625,0.20166015625,0.26171875,0.2666015625},{5,0.265625,0.20166015625,0.3935546875,0.2666015625},{5,0.3974609375,0.20166015625,0.525390625,0.2666015625},{5,0.529296875,0.20166015625,0.6572265625,0.2666015625},{5,0.6611328125,0.20166015625,0.7890625,0.2666015625},{5,0.79296875,0.20166015625,0.9208984375,0.2666015625},{5,0.001953125,0.2685546875,0.1298828125,0.33349609375},{5,0.1337890625,0.2685546875,0.26171875,0.33349609375},{5,0.265625,0.2685546875,0.3935546875,0.33349609375},{5,0.3974609375,0.2685546875,0.525390625,0.33349609375},{5,0.529296875,0.2685546875,0.6572265625,0.33349609375},{5,0.6611328125,0.2685546875,0.7890625,0.33349609375},{5,0.79296875,0.2685546875,0.9208984375,0.33349609375},{5,0.001953125,0.33544921875,0.1298828125,0.400390625},{5,0.1337890625,0.33544921875,0.26171875,0.400390625},{5,0.265625,0.33544921875,0.3935546875,0.400390625},{5,0.3974609375,0.33544921875,0.525390625,0.400390625}},["clip"]="right-banner"},{["group"]="body",["rect"]={64,104,416,105},["tiles"]={{3,0.001953125,0.994140625,0.345703125,0.99462890625}}},{["group"]="body",["rect"]={64,192,416,244},["tiles"]={{5,0.1484375,0.56591796875,0.4921875,0.59130859375}}},{["group"]="body",["rect"]={64,105,192,192},["tiles"]={{5,0.6162109375,0.33544921875,0.7412109375,0.3779296875}}},{["group"]="body",["rect"]={289,105,416,192},["tiles"]={{5,0.7451171875,0.33544921875,0.869140625,0.3779296875}}},{["group"]="body",["rect"]={192,105,289,192},["tiles"]={{5,0.873046875,0.33544921875,0.9677734375,0.3779296875},{4,0.001953125,0.94482421875,0.0966796875,0.9873046875},{4,0.1005859375,0.94482421875,0.1953125,0.9873046875},{4,0.19921875,0.94482421875,0.2939453125,0.9873046875},{4,0.2978515625,0.94482421875,0.392578125,0.9873046875},{4,0.396484375,0.94482421875,0.4912109375,0.9873046875},{4,0.4951171875,0.94482421875,0.58984375,0.9873046875},{4,0.59375,0.94482421875,0.6884765625,0.9873046875},{4,0.6923828125,0.94482421875,0.787109375,0.9873046875},{4,0.791015625,0.94482421875,0.8857421875,0.9873046875},{4,0.8896484375,0.94482421875,0.984375,0.9873046875},{5,0.001953125,0.40234375,0.0966796875,0.44482421875},{5,0.1005859375,0.40234375,0.1953125,0.44482421875},{5,0.19921875,0.40234375,0.2939453125,0.44482421875},{5,0.2978515625,0.40234375,0.392578125,0.44482421875},{5,0.396484375,0.40234375,0.4912109375,0.44482421875},{5,0.4951171875,0.40234375,0.58984375,0.44482421875},{5,0.59375,0.40234375,0.6884765625,0.44482421875},{5,0.6923828125,0.40234375,0.787109375,0.44482421875},{5,0.791015625,0.40234375,0.8857421875,0.44482421875},{5,0.8896484375,0.40234375,0.984375,0.44482421875},{5,0.001953125,0.44677734375,0.0966796875,0.4892578125},{5,0.1005859375,0.44677734375,0.1953125,0.4892578125},{5,0.19921875,0.44677734375,0.2939453125,0.4892578125},{5,0.2978515625,0.44677734375,0.392578125,0.4892578125},{5,0.396484375,0.44677734375,0.4912109375,0.4892578125},{5,0.4951171875,0.44677734375,0.58984375,0.4892578125},{5,0.59375,0.44677734375,0.6884765625,0.4892578125},{5,0.6923828125,0.44677734375,0.787109375,0.4892578125},{5,0.791015625,0.44677734375,0.8857421875,0.4892578125},{5,0.8896484375,0.44677734375,0.984375,0.4892578125},{5,0.001953125,0.4912109375,0.0966796875,0.53369140625},{5,0.1005859375,0.4912109375,0.1953125,0.53369140625},{5,0.19921875,0.4912109375,0.2939453125,0.53369140625}},["receiverFor"]="iris"},{["group"]="body",["rect"]={64,291,416,292},["tiles"]={{3,0.349609375,0.994140625,0.693359375,0.99462890625}}},{["group"]="body",["rect"]={64,244,75,291},["tiles"]={{3,0.9873046875,0.3046875,0.998046875,0.32763671875}}},{["group"]="body",["rect"]={406,244,416,291},["tiles"]={{5,0.98828125,0.40234375,0.998046875,0.42529296875}}},{["group"]="body",["rect"]={75,244,406,291},["tiles"]={{5,0.673828125,0.61962890625,0.9970703125,0.642578125},{5,0.001953125,0.64453125,0.3251953125,0.66748046875},{5,0.3291015625,0.64453125,0.65234375,0.66748046875},{5,0.65625,0.64453125,0.9794921875,0.66748046875},{5,0.001953125,0.66943359375,0.3251953125,0.6923828125},{5,0.3291015625,0.66943359375,0.65234375,0.6923828125},{5,0.65625,0.66943359375,0.9794921875,0.6923828125},{5,0.001953125,0.6943359375,0.3251953125,0.71728515625},{5,0.3291015625,0.6943359375,0.65234375,0.71728515625},{5,0.65625,0.6943359375,0.9794921875,0.71728515625},{5,0.001953125,0.71923828125,0.3251953125,0.7421875},{5,0.3291015625,0.71923828125,0.65234375,0.7421875}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={79,252,399,324},["tiles"]={{5,0.2978515625,0.4912109375,0.6103515625,0.5263671875}}},{["group"]="scroll",["rect"]={79,324,399,460},["tiles"]={{3,0.583984375,0.3046875,0.896484375,0.37109375},{3,0.001953125,0.37890625,0.314453125,0.4453125},{3,0.318359375,0.37890625,0.630859375,0.4453125},{3,0.634765625,0.37890625,0.947265625,0.4453125},{3,0.001953125,0.447265625,0.314453125,0.513671875},{3,0.318359375,0.447265625,0.630859375,0.513671875},{3,0.634765625,0.447265625,0.947265625,0.513671875},{3,0.001953125,0.515625,0.314453125,0.58203125},{3,0.318359375,0.515625,0.630859375,0.58203125},{3,0.634765625,0.515625,0.947265625,0.58203125},{3,0.001953125,0.583984375,0.314453125,0.650390625},{3,0.318359375,0.583984375,0.630859375,0.650390625},{3,0.634765625,0.583984375,0.947265625,0.650390625},{3,0.001953125,0.65234375,0.314453125,0.71875},{3,0.318359375,0.65234375,0.630859375,0.71875},{3,0.634765625,0.65234375,0.947265625,0.71875},{3,0.001953125,0.720703125,0.314453125,0.787109375},{3,0.318359375,0.720703125,0.630859375,0.787109375},{3,0.634765625,0.720703125,0.947265625,0.787109375},{3,0.001953125,0.7890625,0.314453125,0.85546875},{3,0.318359375,0.7890625,0.630859375,0.85546875},{3,0.634765625,0.7890625,0.947265625,0.85546875},{3,0.001953125,0.857421875,0.314453125,0.923828125},{3,0.318359375,0.857421875,0.630859375,0.923828125},{3,0.634765625,0.857421875,0.947265625,0.923828125},{3,0.001953125,0.92578125,0.314453125,0.9921875},{3,0.318359375,0.92578125,0.630859375,0.9921875},{3,0.634765625,0.92578125,0.947265625,0.9921875},{4,0.001953125,0.0009765625,0.314453125,0.0673828125},{4,0.318359375,0.0009765625,0.630859375,0.0673828125},{4,0.634765625,0.0009765625,0.947265625,0.0673828125},{4,0.001953125,0.0693359375,0.314453125,0.1357421875}},["clip"]="scroll"},{["group"]="scroll",["rect"]={82,266,398,293},["tiles"]={{5,0.001953125,0.744140625,0.310546875,0.75732421875}},["glow"]="scroll"},{["group"]="body",["rect"]={129,11,352,23},["tiles"]={{4,0.041015625,0.9892578125,0.2587890625,0.9951171875}}},{["group"]="body",["rect"]={129,171,352,173},["tiles"]={{4,0.2626953125,0.9892578125,0.48046875,0.990234375}}},{["group"]="body",["rect"]={129,23,182,171},["tiles"]={{3,0.109375,0.0009765625,0.1611328125,0.0732421875}}},{["group"]="body",["rect"]={299,23,352,171},["tiles"]={{3,0.1650390625,0.0009765625,0.216796875,0.0732421875}}},{["group"]="body",["rect"]={182,23,299,171},["tiles"]={{3,0.220703125,0.0009765625,0.3349609375,0.0732421875},{3,0.3388671875,0.0009765625,0.453125,0.0732421875},{3,0.45703125,0.0009765625,0.5712890625,0.0732421875},{3,0.5751953125,0.0009765625,0.689453125,0.0732421875},{3,0.693359375,0.0009765625,0.8076171875,0.0732421875},{3,0.8115234375,0.0009765625,0.92578125,0.0732421875},{3,0.001953125,0.08203125,0.1162109375,0.154296875},{3,0.1201171875,0.08203125,0.234375,0.154296875},{3,0.23828125,0.08203125,0.3525390625,0.154296875},{3,0.3564453125,0.08203125,0.470703125,0.154296875},{3,0.474609375,0.08203125,0.5888671875,0.154296875},{3,0.5927734375,0.08203125,0.70703125,0.154296875},{3,0.7109375,0.08203125,0.8251953125,0.154296875},{3,0.8291015625,0.08203125,0.943359375,0.154296875},{3,0.001953125,0.15625,0.1162109375,0.228515625},{3,0.1201171875,0.15625,0.234375,0.228515625},{3,0.23828125,0.15625,0.3525390625,0.228515625},{3,0.3564453125,0.15625,0.470703125,0.228515625},{3,0.474609375,0.15625,0.5888671875,0.228515625},{3,0.5927734375,0.15625,0.70703125,0.228515625},{3,0.7109375,0.15625,0.8251953125,0.228515625},{3,0.8291015625,0.15625,0.943359375,0.228515625},{3,0.001953125,0.23046875,0.1162109375,0.302734375},{3,0.1201171875,0.23046875,0.234375,0.302734375},{3,0.23828125,0.23046875,0.3525390625,0.302734375},{3,0.3564453125,0.23046875,0.470703125,0.302734375},{3,0.474609375,0.23046875,0.5888671875,0.302734375},{3,0.5927734375,0.23046875,0.70703125,0.302734375},{3,0.7109375,0.23046875,0.8251953125,0.302734375},{3,0.8291015625,0.23046875,0.943359375,0.302734375},{3,0.001953125,0.3046875,0.1162109375,0.376953125},{3,0.1201171875,0.3046875,0.234375,0.376953125},{3,0.23828125,0.3046875,0.3525390625,0.376953125},{3,0.3564453125,0.3046875,0.470703125,0.376953125}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={198,42,283,62},["tiles"]={{5,0.6240234375,0.78466796875,0.70703125,0.79443359375}}},{["group"]="kirinTor",["rect"]={198,42,283,62},["tiles"]={{5,0.7109375,0.78466796875,0.7939453125,0.79443359375}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={198,62,283,84},["tiles"]={{5,0.314453125,0.744140625,0.3974609375,0.7548828125},{5,0.4013671875,0.744140625,0.484375,0.7548828125},{5,0.48828125,0.744140625,0.5712890625,0.7548828125},{5,0.5751953125,0.744140625,0.658203125,0.7548828125},{5,0.662109375,0.744140625,0.7451171875,0.7548828125},{5,0.7490234375,0.744140625,0.83203125,0.7548828125},{5,0.8359375,0.744140625,0.9189453125,0.7548828125},{5,0.001953125,0.75927734375,0.0849609375,0.77001953125},{5,0.0888671875,0.75927734375,0.171875,0.77001953125},{5,0.17578125,0.75927734375,0.2587890625,0.77001953125},{5,0.2626953125,0.75927734375,0.345703125,0.77001953125},{5,0.349609375,0.75927734375,0.4326171875,0.77001953125},{5,0.4365234375,0.75927734375,0.51953125,0.77001953125},{5,0.5234375,0.75927734375,0.6064453125,0.77001953125},{5,0.6103515625,0.75927734375,0.693359375,0.77001953125},{5,0.697265625,0.75927734375,0.7802734375,0.77001953125},{5,0.7841796875,0.75927734375,0.8671875,0.77001953125}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={198,62,283,84},["tiles"]={{5,0.87109375,0.75927734375,0.9541015625,0.77001953125},{5,0.001953125,0.77197265625,0.0849609375,0.78271484375},{5,0.0888671875,0.77197265625,0.171875,0.78271484375},{5,0.17578125,0.77197265625,0.2587890625,0.78271484375},{5,0.2626953125,0.77197265625,0.345703125,0.78271484375},{5,0.349609375,0.77197265625,0.4326171875,0.78271484375},{5,0.4365234375,0.77197265625,0.51953125,0.78271484375},{5,0.5234375,0.77197265625,0.6064453125,0.78271484375},{5,0.6103515625,0.77197265625,0.693359375,0.78271484375},{5,0.697265625,0.77197265625,0.7802734375,0.78271484375},{5,0.7841796875,0.77197265625,0.8671875,0.78271484375},{5,0.87109375,0.77197265625,0.9541015625,0.78271484375},{5,0.001953125,0.78466796875,0.0849609375,0.79541015625},{5,0.0888671875,0.78466796875,0.171875,0.79541015625},{5,0.17578125,0.78466796875,0.2587890625,0.79541015625},{5,0.2626953125,0.78466796875,0.345703125,0.79541015625},{5,0.349609375,0.78466796875,0.4326171875,0.79541015625}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={198,84,283,173},["tiles"]={{3,0.900390625,0.3046875,0.9833984375,0.34814453125}}},{["group"]="kirinTor",["rect"]={198,84,283,173},["tiles"]={{5,0.529296875,0.33544921875,0.6123046875,0.37890625}},["glow"]="eye"},{["group"]="shards",["rect"]={141,30,191,88},["tiles"]={{5,0.9248046875,0.2685546875,0.9736328125,0.296875},{5,0.6142578125,0.4912109375,0.6630859375,0.51953125},{5,0.6669921875,0.4912109375,0.7158203125,0.51953125},{5,0.7197265625,0.4912109375,0.7685546875,0.51953125},{5,0.7724609375,0.4912109375,0.8212890625,0.51953125},{5,0.8251953125,0.4912109375,0.8740234375,0.51953125},{5,0.8779296875,0.4912109375,0.9267578125,0.51953125},{5,0.9306640625,0.4912109375,0.9794921875,0.51953125},{5,0.001953125,0.53564453125,0.05078125,0.56396484375},{5,0.0546875,0.53564453125,0.103515625,0.56396484375},{5,0.107421875,0.53564453125,0.15625,0.56396484375},{5,0.16015625,0.53564453125,0.208984375,0.56396484375},{5,0.212890625,0.53564453125,0.26171875,0.56396484375},{5,0.265625,0.53564453125,0.314453125,0.56396484375},{5,0.318359375,0.53564453125,0.3671875,0.56396484375}},["shard"]=1},{["group"]="shards",["rect"]={143,32,189,86},["tiles"]={{5,0.37109375,0.53564453125,0.416015625,0.56201171875},{5,0.419921875,0.53564453125,0.46484375,0.56201171875},{5,0.46875,0.53564453125,0.513671875,0.56201171875},{5,0.517578125,0.53564453125,0.5625,0.56201171875},{5,0.56640625,0.53564453125,0.611328125,0.56201171875},{5,0.615234375,0.53564453125,0.66015625,0.56201171875},{5,0.6640625,0.53564453125,0.708984375,0.56201171875},{5,0.712890625,0.53564453125,0.7578125,0.56201171875},{5,0.76171875,0.53564453125,0.806640625,0.56201171875},{5,0.810546875,0.53564453125,0.85546875,0.56201171875},{5,0.859375,0.53564453125,0.904296875,0.56201171875},{5,0.908203125,0.53564453125,0.953125,0.56201171875},{5,0.001953125,0.56591796875,0.046875,0.59228515625},{5,0.05078125,0.56591796875,0.095703125,0.59228515625},{5,0.099609375,0.56591796875,0.14453125,0.59228515625}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={165,60,191,90},["tiles"]={{4,0.97265625,0.8779296875,0.998046875,0.892578125},{5,0.97265625,0.0009765625,0.998046875,0.015625},{5,0.97265625,0.06787109375,0.998046875,0.08251953125},{5,0.97265625,0.134765625,0.998046875,0.1494140625},{5,0.97265625,0.20166015625,0.998046875,0.21630859375},{5,0.9716796875,0.33544921875,0.9970703125,0.35009765625},{5,0.95703125,0.56591796875,0.982421875,0.58056640625},{5,0.65625,0.71923828125,0.681640625,0.73388671875},{5,0.685546875,0.71923828125,0.7109375,0.73388671875},{5,0.71484375,0.71923828125,0.740234375,0.73388671875},{5,0.744140625,0.71923828125,0.76953125,0.73388671875},{5,0.7734375,0.71923828125,0.798828125,0.73388671875},{5,0.802734375,0.71923828125,0.828125,0.73388671875},{5,0.83203125,0.71923828125,0.857421875,0.73388671875},{5,0.861328125,0.71923828125,0.88671875,0.73388671875}},["shard"]=2},{["group"]="shards",["rect"]={167,62,189,89},["tiles"]={{4,0.9765625,0.1376953125,0.998046875,0.15087890625},{4,0.9765625,0.205078125,0.998046875,0.21826171875},{4,0.9765625,0.2724609375,0.998046875,0.28564453125},{4,0.9765625,0.33984375,0.998046875,0.35302734375},{4,0.9765625,0.4072265625,0.998046875,0.42041015625},{4,0.9765625,0.474609375,0.998046875,0.48779296875},{4,0.9765625,0.5419921875,0.998046875,0.55517578125},{4,0.9765625,0.609375,0.998046875,0.62255859375},{4,0.9765625,0.6767578125,0.998046875,0.68994140625},{4,0.9765625,0.744140625,0.998046875,0.75732421875},{4,0.9765625,0.81103515625,0.998046875,0.82421875},{5,0.890625,0.71923828125,0.912109375,0.732421875},{5,0.916015625,0.71923828125,0.9375,0.732421875},{5,0.94140625,0.71923828125,0.962890625,0.732421875},{5,0.966796875,0.71923828125,0.98828125,0.732421875}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={284,29,333,94},["tiles"]={{3,0.947265625,0.08203125,0.9951171875,0.11376953125},{3,0.947265625,0.15625,0.9951171875,0.18798828125},{3,0.947265625,0.23046875,0.9951171875,0.26220703125},{3,0.9296875,0.0009765625,0.9775390625,0.03271484375},{4,0.9248046875,0.1376953125,0.97265625,0.16943359375},{4,0.9248046875,0.205078125,0.97265625,0.23681640625},{4,0.9248046875,0.2724609375,0.97265625,0.30419921875},{4,0.9248046875,0.33984375,0.97265625,0.37158203125},{4,0.9248046875,0.4072265625,0.97265625,0.43896484375},{4,0.9248046875,0.474609375,0.97265625,0.50634765625},{4,0.9248046875,0.5419921875,0.97265625,0.57373046875},{4,0.9248046875,0.609375,0.97265625,0.64111328125},{4,0.9248046875,0.6767578125,0.97265625,0.70849609375},{4,0.9248046875,0.744140625,0.97265625,0.77587890625},{4,0.9248046875,0.81103515625,0.97265625,0.8427734375}},["shard"]=3},{["group"]="shards",["rect"]={286,31,331,92},["tiles"]={{3,0.951171875,0.37890625,0.9951171875,0.40869140625},{3,0.951171875,0.447265625,0.9951171875,0.47705078125},{3,0.951171875,0.515625,0.9951171875,0.54541015625},{3,0.951171875,0.583984375,0.9951171875,0.61376953125},{3,0.951171875,0.65234375,0.9951171875,0.68212890625},{3,0.951171875,0.720703125,0.9951171875,0.75048828125},{3,0.951171875,0.7890625,0.9951171875,0.81884765625},{3,0.951171875,0.857421875,0.9951171875,0.88720703125},{3,0.951171875,0.92578125,0.9951171875,0.95556640625},{4,0.951171875,0.0009765625,0.9951171875,0.03076171875},{4,0.9248046875,0.8779296875,0.96875,0.90771484375},{5,0.9248046875,0.0009765625,0.96875,0.03076171875},{5,0.9248046875,0.06787109375,0.96875,0.09765625},{5,0.9248046875,0.134765625,0.96875,0.16455078125},{5,0.9248046875,0.20166015625,0.96875,0.2314453125}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={293,61,313,82},["tiles"]={{4,0.9775390625,0.0693359375,0.9970703125,0.07958984375},{5,0.9775390625,0.2685546875,0.9970703125,0.27880859375},{5,0.9580078125,0.75927734375,0.9775390625,0.76953125},{5,0.9580078125,0.77197265625,0.9775390625,0.7822265625},{5,0.9228515625,0.744140625,0.9423828125,0.75439453125},{5,0.9462890625,0.744140625,0.9658203125,0.75439453125},{5,0.9697265625,0.744140625,0.9892578125,0.75439453125},{5,0.4365234375,0.78466796875,0.4560546875,0.794921875},{5,0.4599609375,0.78466796875,0.4794921875,0.794921875},{5,0.4833984375,0.78466796875,0.5029296875,0.794921875},{5,0.5068359375,0.78466796875,0.5263671875,0.794921875},{5,0.5302734375,0.78466796875,0.5498046875,0.794921875},{5,0.5537109375,0.78466796875,0.5732421875,0.794921875},{5,0.5771484375,0.78466796875,0.5966796875,0.794921875},{5,0.6005859375,0.78466796875,0.6201171875,0.794921875}},["shard"]=4},{["group"]="shards",["rect"]={295,63,311,80},["tiles"]={{3,0.9814453125,0.0009765625,0.9970703125,0.00927734375},{5,0.9814453125,0.75927734375,0.9970703125,0.767578125},{5,0.9814453125,0.77197265625,0.9970703125,0.7802734375},{5,0.7978515625,0.78466796875,0.8134765625,0.79296875},{5,0.8173828125,0.78466796875,0.8330078125,0.79296875},{5,0.8369140625,0.78466796875,0.8525390625,0.79296875},{5,0.8564453125,0.78466796875,0.8720703125,0.79296875},{5,0.8759765625,0.78466796875,0.8916015625,0.79296875},{5,0.8955078125,0.78466796875,0.9111328125,0.79296875},{5,0.9150390625,0.78466796875,0.9306640625,0.79296875},{5,0.9345703125,0.78466796875,0.9501953125,0.79296875},{5,0.9541015625,0.78466796875,0.9697265625,0.79296875},{5,0.9736328125,0.78466796875,0.9892578125,0.79296875},{4,0.001953125,0.9892578125,0.017578125,0.99755859375},{4,0.021484375,0.9892578125,0.037109375,0.99755859375}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={2,27,110,173},["tiles"]={{3,0.474609375,0.3046875,0.580078125,0.3759765625}}},{["group"]="shoulderFloaters",["rect"]={4,133,33,171},["tiles"]={{5,0.95703125,0.53564453125,0.9853515625,0.55419921875}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={371,11,477,173},["tiles"]={{3,0.001953125,0.0009765625,0.10546875,0.080078125}}},{["group"]="shoulderFloaters",["rect"]={445,127,475,171},["tiles"]={{5,0.9599609375,0.59423828125,0.9892578125,0.61572265625}},["glow"]="shoulder"}},["576"]={{["group"]="foundation",["rect"]={36,40,540,302},["tiles"]={{1,0.001953125,0.001953125,0.494140625,0.2578125}}},{["group"]="foundation",["rect"]={37,302,78,393},["tiles"]={{1,0.9296875,0.5068359375,0.9697265625,0.595703125}}},{["group"]="foundation",["rect"]={497,302,537,392},["tiles"]={{1,0.9296875,0.751953125,0.96875,0.83984375}}},{["group"]="foundation",["rect"]={78,302,497,397},["tiles"]={{3,0.4765625,0.001953125,0.8857421875,0.0947265625},{3,0.001953125,0.1728515625,0.4111328125,0.265625},{3,0.4150390625,0.1728515625,0.82421875,0.265625},{3,0.001953125,0.26953125,0.4111328125,0.3623046875},{3,0.4150390625,0.26953125,0.82421875,0.3623046875},{3,0.001953125,0.3662109375,0.4111328125,0.458984375},{3,0.4150390625,0.3662109375,0.82421875,0.458984375},{3,0.001953125,0.462890625,0.4111328125,0.5556640625},{3,0.4150390625,0.462890625,0.82421875,0.5556640625},{3,0.001953125,0.5595703125,0.4111328125,0.65234375},{3,0.4150390625,0.5595703125,0.82421875,0.65234375},{3,0.001953125,0.65625,0.4111328125,0.7490234375}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={31,362,89,465},["tiles"]={{1,0.9248046875,0.001953125,0.9814453125,0.1025390625}}},{["group"]="bannerFloaters",["rect"]={488,362,543,462},["tiles"]={{1,0.9296875,0.26171875,0.9833984375,0.359375}}},{["group"]="body",["rect"]={74,343,131,401},["tiles"]={{6,0.8515625,0.9560546875,0.9072265625,0.984375}}},{["group"]="body",["rect"]={227,343,228,401},["tiles"]={{5,0.994140625,0.9033203125,0.9951171875,0.931640625}}},{["group"]="body",["rect"]={131,343,227,401},["tiles"]={{7,0.001953125,0.66259765625,0.095703125,0.69091796875},{7,0.099609375,0.66259765625,0.193359375,0.69091796875},{7,0.197265625,0.66259765625,0.291015625,0.69091796875},{7,0.294921875,0.66259765625,0.388671875,0.69091796875},{7,0.392578125,0.66259765625,0.486328125,0.69091796875},{7,0.490234375,0.66259765625,0.583984375,0.69091796875},{7,0.587890625,0.66259765625,0.681640625,0.69091796875},{7,0.685546875,0.66259765625,0.779296875,0.69091796875},{7,0.783203125,0.66259765625,0.876953125,0.69091796875},{7,0.880859375,0.66259765625,0.974609375,0.69091796875},{7,0.001953125,0.69287109375,0.095703125,0.72119140625},{7,0.099609375,0.69287109375,0.193359375,0.72119140625}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={73,401,228,560},["tiles"]={{4,0.7578125,0.54150390625,0.9091796875,0.619140625},{4,0.7578125,0.62353515625,0.9091796875,0.701171875},{4,0.7578125,0.70556640625,0.9091796875,0.783203125},{4,0.7578125,0.78759765625,0.9091796875,0.865234375},{4,0.7578125,0.86962890625,0.9091796875,0.947265625},{5,0.7578125,0.0009765625,0.9091796875,0.07861328125},{5,0.7578125,0.0830078125,0.9091796875,0.16064453125},{5,0.7578125,0.1650390625,0.9091796875,0.24267578125},{5,0.7578125,0.2470703125,0.9091796875,0.32470703125},{5,0.7578125,0.3291015625,0.9091796875,0.40673828125},{5,0.7578125,0.4111328125,0.9091796875,0.48876953125},{5,0.7578125,0.4931640625,0.9091796875,0.57080078125},{5,0.7578125,0.5751953125,0.9091796875,0.65283203125},{5,0.7578125,0.6572265625,0.9091796875,0.73486328125},{5,0.7578125,0.7392578125,0.9091796875,0.81689453125},{4,0.650390625,0.45263671875,0.8017578125,0.5302734375},{4,0.8056640625,0.45263671875,0.95703125,0.5302734375},{5,0.3798828125,0.8212890625,0.53125,0.89892578125},{5,0.53515625,0.8212890625,0.6865234375,0.89892578125},{5,0.6904296875,0.8212890625,0.841796875,0.89892578125},{5,0.845703125,0.8212890625,0.9970703125,0.89892578125},{5,0.001953125,0.9033203125,0.1533203125,0.98095703125},{5,0.1572265625,0.9033203125,0.30859375,0.98095703125},{5,0.3125,0.9033203125,0.4638671875,0.98095703125},{5,0.4677734375,0.9033203125,0.619140625,0.98095703125},{5,0.623046875,0.9033203125,0.7744140625,0.98095703125},{5,0.7783203125,0.9033203125,0.9296875,0.98095703125},{6,0.001953125,0.0009765625,0.1533203125,0.07861328125},{6,0.1572265625,0.0009765625,0.30859375,0.07861328125},{6,0.3125,0.0009765625,0.4638671875,0.07861328125},{6,0.4677734375,0.0009765625,0.619140625,0.07861328125},{6,0.623046875,0.0009765625,0.7744140625,0.07861328125},{6,0.7783203125,0.0009765625,0.9296875,0.07861328125},{6,0.001953125,0.08056640625,0.1533203125,0.158203125},{6,0.1572265625,0.08056640625,0.30859375,0.158203125},{6,0.3125,0.08056640625,0.4638671875,0.158203125},{6,0.4677734375,0.08056640625,0.619140625,0.158203125},{6,0.623046875,0.08056640625,0.7744140625,0.158203125},{6,0.7783203125,0.08056640625,0.9296875,0.158203125},{6,0.001953125,0.16015625,0.1533203125,0.23779296875},{6,0.1572265625,0.16015625,0.30859375,0.23779296875},{6,0.3125,0.16015625,0.4638671875,0.23779296875},{6,0.4677734375,0.16015625,0.619140625,0.23779296875},{6,0.623046875,0.16015625,0.7744140625,0.23779296875},{6,0.7783203125,0.16015625,0.9296875,0.23779296875},{6,0.001953125,0.23974609375,0.1533203125,0.3173828125},{6,0.1572265625,0.23974609375,0.30859375,0.3173828125},{6,0.3125,0.23974609375,0.4638671875,0.3173828125},{6,0.4677734375,0.23974609375,0.619140625,0.3173828125},{6,0.623046875,0.23974609375,0.7744140625,0.3173828125},{6,0.7783203125,0.23974609375,0.9296875,0.3173828125},{6,0.001953125,0.3193359375,0.1533203125,0.39697265625},{6,0.1572265625,0.3193359375,0.30859375,0.39697265625},{6,0.3125,0.3193359375,0.4638671875,0.39697265625},{6,0.4677734375,0.3193359375,0.619140625,0.39697265625},{6,0.623046875,0.3193359375,0.7744140625,0.39697265625},{6,0.7783203125,0.3193359375,0.9296875,0.39697265625},{6,0.001953125,0.39892578125,0.1533203125,0.4765625},{6,0.1572265625,0.39892578125,0.30859375,0.4765625},{6,0.3125,0.39892578125,0.4638671875,0.4765625},{6,0.4677734375,0.39892578125,0.619140625,0.4765625},{6,0.623046875,0.39892578125,0.7744140625,0.4765625},{6,0.7783203125,0.39892578125,0.9296875,0.4765625},{6,0.001953125,0.478515625,0.1533203125,0.55615234375}},["clip"]="left-banner"},{["group"]="body",["rect"]={348,343,349,400},["tiles"]={{6,0.994140625,0.0009765625,0.9951171875,0.02880859375}}},{["group"]="body",["rect"]={448,343,501,400},["tiles"]={{6,0.9111328125,0.9560546875,0.962890625,0.98388671875}}},{["group"]="body",["rect"]={349,343,448,400},["tiles"]={{7,0.197265625,0.69287109375,0.2939453125,0.720703125},{7,0.2978515625,0.69287109375,0.39453125,0.720703125},{7,0.3984375,0.69287109375,0.4951171875,0.720703125},{7,0.4990234375,0.69287109375,0.595703125,0.720703125},{7,0.599609375,0.69287109375,0.6962890625,0.720703125},{7,0.7001953125,0.69287109375,0.796875,0.720703125},{7,0.80078125,0.69287109375,0.8974609375,0.720703125},{7,0.9013671875,0.69287109375,0.998046875,0.720703125},{7,0.001953125,0.72314453125,0.0986328125,0.7509765625},{7,0.1025390625,0.72314453125,0.19921875,0.7509765625},{7,0.203125,0.72314453125,0.2998046875,0.7509765625},{7,0.3037109375,0.72314453125,0.400390625,0.7509765625}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={347,400,503,559},["tiles"]={{6,0.1572265625,0.478515625,0.3095703125,0.55615234375},{6,0.3134765625,0.478515625,0.4658203125,0.55615234375},{6,0.4697265625,0.478515625,0.6220703125,0.55615234375},{6,0.6259765625,0.478515625,0.7783203125,0.55615234375},{6,0.7822265625,0.478515625,0.9345703125,0.55615234375},{6,0.001953125,0.55810546875,0.154296875,0.6357421875},{6,0.158203125,0.55810546875,0.310546875,0.6357421875},{6,0.314453125,0.55810546875,0.466796875,0.6357421875},{6,0.470703125,0.55810546875,0.623046875,0.6357421875},{6,0.626953125,0.55810546875,0.779296875,0.6357421875},{6,0.783203125,0.55810546875,0.935546875,0.6357421875},{6,0.001953125,0.6376953125,0.154296875,0.71533203125},{6,0.158203125,0.6376953125,0.310546875,0.71533203125},{6,0.314453125,0.6376953125,0.466796875,0.71533203125},{6,0.470703125,0.6376953125,0.623046875,0.71533203125},{6,0.626953125,0.6376953125,0.779296875,0.71533203125},{6,0.783203125,0.6376953125,0.935546875,0.71533203125},{6,0.001953125,0.71728515625,0.154296875,0.794921875},{6,0.158203125,0.71728515625,0.310546875,0.794921875},{6,0.314453125,0.71728515625,0.466796875,0.794921875},{6,0.470703125,0.71728515625,0.623046875,0.794921875},{6,0.626953125,0.71728515625,0.779296875,0.794921875},{6,0.783203125,0.71728515625,0.935546875,0.794921875},{6,0.001953125,0.796875,0.154296875,0.87451171875},{6,0.158203125,0.796875,0.310546875,0.87451171875},{6,0.314453125,0.796875,0.466796875,0.87451171875},{6,0.470703125,0.796875,0.623046875,0.87451171875},{6,0.626953125,0.796875,0.779296875,0.87451171875},{6,0.783203125,0.796875,0.935546875,0.87451171875},{6,0.001953125,0.87646484375,0.154296875,0.9541015625},{6,0.158203125,0.87646484375,0.310546875,0.9541015625},{6,0.314453125,0.87646484375,0.466796875,0.9541015625},{6,0.470703125,0.87646484375,0.623046875,0.9541015625},{6,0.626953125,0.87646484375,0.779296875,0.9541015625},{6,0.783203125,0.87646484375,0.935546875,0.9541015625},{7,0.001953125,0.0009765625,0.154296875,0.07861328125},{7,0.158203125,0.0009765625,0.310546875,0.07861328125},{7,0.314453125,0.0009765625,0.466796875,0.07861328125},{7,0.470703125,0.0009765625,0.623046875,0.07861328125},{7,0.626953125,0.0009765625,0.779296875,0.07861328125},{7,0.783203125,0.0009765625,0.935546875,0.07861328125},{7,0.001953125,0.08056640625,0.154296875,0.158203125},{7,0.158203125,0.08056640625,0.310546875,0.158203125},{7,0.314453125,0.08056640625,0.466796875,0.158203125},{7,0.470703125,0.08056640625,0.623046875,0.158203125},{7,0.626953125,0.08056640625,0.779296875,0.158203125},{7,0.783203125,0.08056640625,0.935546875,0.158203125},{7,0.001953125,0.16015625,0.154296875,0.23779296875},{7,0.158203125,0.16015625,0.310546875,0.23779296875},{7,0.314453125,0.16015625,0.466796875,0.23779296875},{7,0.470703125,0.16015625,0.623046875,0.23779296875},{7,0.626953125,0.16015625,0.779296875,0.23779296875},{7,0.783203125,0.16015625,0.935546875,0.23779296875},{7,0.001953125,0.23974609375,0.154296875,0.3173828125},{7,0.158203125,0.23974609375,0.310546875,0.3173828125},{7,0.314453125,0.23974609375,0.466796875,0.3173828125},{7,0.470703125,0.23974609375,0.623046875,0.3173828125},{7,0.626953125,0.23974609375,0.779296875,0.3173828125},{7,0.783203125,0.23974609375,0.935546875,0.3173828125},{7,0.001953125,0.3193359375,0.154296875,0.39697265625},{7,0.158203125,0.3193359375,0.310546875,0.39697265625},{7,0.314453125,0.3193359375,0.466796875,0.39697265625},{7,0.470703125,0.3193359375,0.623046875,0.39697265625},{7,0.626953125,0.3193359375,0.779296875,0.39697265625}},["clip"]="right-banner"},{["group"]="body",["rect"]={78,125,499,126},["tiles"]={{5,0.001953125,0.998046875,0.4130859375,0.99853515625}}},{["group"]="body",["rect"]={78,230,499,293},["tiles"]={{4,0.546875,0.95166015625,0.9580078125,0.982421875}}},{["group"]="body",["rect"]={78,126,231,230},["tiles"]={{7,0.001953125,0.39892578125,0.1513671875,0.44970703125}}},{["group"]="body",["rect"]={347,126,499,230},["tiles"]={{7,0.1552734375,0.39892578125,0.3037109375,0.44970703125}}},{["group"]="body",["rect"]={231,126,347,230},["tiles"]={{7,0.3076171875,0.39892578125,0.4208984375,0.44970703125},{7,0.4248046875,0.39892578125,0.5380859375,0.44970703125},{7,0.5419921875,0.39892578125,0.6552734375,0.44970703125},{7,0.6591796875,0.39892578125,0.7724609375,0.44970703125},{7,0.7763671875,0.39892578125,0.8896484375,0.44970703125},{7,0.001953125,0.45166015625,0.115234375,0.50244140625},{7,0.119140625,0.45166015625,0.232421875,0.50244140625},{7,0.236328125,0.45166015625,0.349609375,0.50244140625},{7,0.353515625,0.45166015625,0.466796875,0.50244140625},{7,0.470703125,0.45166015625,0.583984375,0.50244140625},{7,0.587890625,0.45166015625,0.701171875,0.50244140625},{7,0.705078125,0.45166015625,0.818359375,0.50244140625},{7,0.822265625,0.45166015625,0.935546875,0.50244140625},{7,0.001953125,0.50439453125,0.115234375,0.55517578125},{7,0.119140625,0.50439453125,0.232421875,0.55517578125},{7,0.236328125,0.50439453125,0.349609375,0.55517578125},{7,0.353515625,0.50439453125,0.466796875,0.55517578125},{7,0.470703125,0.50439453125,0.583984375,0.55517578125},{7,0.587890625,0.50439453125,0.701171875,0.55517578125},{7,0.705078125,0.50439453125,0.818359375,0.55517578125},{7,0.822265625,0.50439453125,0.935546875,0.55517578125},{7,0.001953125,0.55712890625,0.115234375,0.60791015625},{7,0.119140625,0.55712890625,0.232421875,0.60791015625},{7,0.236328125,0.55712890625,0.349609375,0.60791015625},{7,0.353515625,0.55712890625,0.466796875,0.60791015625},{7,0.470703125,0.55712890625,0.583984375,0.60791015625},{7,0.587890625,0.55712890625,0.701171875,0.60791015625},{7,0.705078125,0.55712890625,0.818359375,0.60791015625},{7,0.822265625,0.55712890625,0.935546875,0.60791015625},{7,0.001953125,0.60986328125,0.115234375,0.66064453125},{7,0.119140625,0.60986328125,0.232421875,0.66064453125},{7,0.236328125,0.60986328125,0.349609375,0.66064453125},{7,0.353515625,0.60986328125,0.466796875,0.66064453125},{7,0.470703125,0.60986328125,0.583984375,0.66064453125}},["receiverFor"]="iris"},{["group"]="body",["rect"]={78,349,499,350},["tiles"]={{5,0.4169921875,0.998046875,0.828125,0.99853515625}}},{["group"]="body",["rect"]={78,293,90,349},["tiles"]={{7,0.978515625,0.66259765625,0.990234375,0.68994140625}}},{["group"]="body",["rect"]={487,293,499,349},["tiles"]={{5,0.9736328125,0.4111328125,0.9853515625,0.4384765625}}},{["group"]="body",["rect"]={90,293,487,349},["tiles"]={{7,0.404296875,0.72314453125,0.7919921875,0.75048828125},{7,0.001953125,0.7529296875,0.3896484375,0.7802734375},{7,0.3935546875,0.7529296875,0.78125,0.7802734375},{7,0.001953125,0.7822265625,0.3896484375,0.8095703125},{7,0.3935546875,0.7822265625,0.78125,0.8095703125},{7,0.001953125,0.8115234375,0.3896484375,0.8388671875},{7,0.3935546875,0.8115234375,0.78125,0.8388671875},{7,0.001953125,0.8408203125,0.3896484375,0.8681640625},{7,0.3935546875,0.8408203125,0.78125,0.8681640625},{7,0.001953125,0.8701171875,0.3896484375,0.8974609375},{7,0.3935546875,0.8701171875,0.78125,0.8974609375},{7,0.001953125,0.8994140625,0.3896484375,0.9267578125}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={96,303,479,388},["tiles"]={{7,0.587890625,0.60986328125,0.9619140625,0.6513671875}}},{["group"]="scroll",["rect"]={96,388,479,552},["tiles"]={{4,0.2724609375,0.45263671875,0.646484375,0.53271484375},{4,0.001953125,0.54150390625,0.3759765625,0.62158203125},{4,0.3798828125,0.54150390625,0.75390625,0.62158203125},{4,0.001953125,0.62353515625,0.3759765625,0.70361328125},{4,0.3798828125,0.62353515625,0.75390625,0.70361328125},{4,0.001953125,0.70556640625,0.3759765625,0.78564453125},{4,0.3798828125,0.70556640625,0.75390625,0.78564453125},{4,0.001953125,0.78759765625,0.3759765625,0.86767578125},{4,0.3798828125,0.78759765625,0.75390625,0.86767578125},{4,0.001953125,0.86962890625,0.3759765625,0.94970703125},{4,0.3798828125,0.86962890625,0.75390625,0.94970703125},{5,0.001953125,0.0009765625,0.3759765625,0.0810546875},{5,0.3798828125,0.0009765625,0.75390625,0.0810546875},{5,0.001953125,0.0830078125,0.3759765625,0.1630859375},{5,0.3798828125,0.0830078125,0.75390625,0.1630859375},{5,0.001953125,0.1650390625,0.3759765625,0.2451171875},{5,0.3798828125,0.1650390625,0.75390625,0.2451171875},{5,0.001953125,0.2470703125,0.3759765625,0.3271484375},{5,0.3798828125,0.2470703125,0.75390625,0.3271484375},{5,0.001953125,0.3291015625,0.3759765625,0.4091796875},{5,0.3798828125,0.3291015625,0.75390625,0.4091796875},{5,0.001953125,0.4111328125,0.3759765625,0.4912109375},{5,0.3798828125,0.4111328125,0.75390625,0.4912109375},{5,0.001953125,0.4931640625,0.3759765625,0.5732421875},{5,0.3798828125,0.4931640625,0.75390625,0.5732421875},{5,0.001953125,0.5751953125,0.3759765625,0.6552734375},{5,0.3798828125,0.5751953125,0.75390625,0.6552734375},{5,0.001953125,0.6572265625,0.3759765625,0.7373046875},{5,0.3798828125,0.6572265625,0.75390625,0.7373046875},{5,0.001953125,0.7392578125,0.3759765625,0.8193359375},{5,0.3798828125,0.7392578125,0.75390625,0.8193359375},{5,0.001953125,0.8212890625,0.3759765625,0.9013671875}},["clip"]="scroll"},{["group"]="scroll",["rect"]={99,320,476,351},["tiles"]={{7,0.3935546875,0.8994140625,0.76171875,0.91455078125}},["glow"]="scroll"},{["group"]="body",["rect"]={155,14,422,27},["tiles"]={{4,0.2685546875,0.9873046875,0.529296875,0.99365234375}}},{["group"]="body",["rect"]={155,205,422,207},["tiles"]={{4,0.533203125,0.9873046875,0.7939453125,0.98828125}}},{["group"]="body",["rect"]={155,27,218,205},["tiles"]={{4,0.12890625,0.0009765625,0.1904296875,0.087890625}}},{["group"]="body",["rect"]={359,27,422,205},["tiles"]={{4,0.1943359375,0.0009765625,0.255859375,0.087890625}}},{["group"]="body",["rect"]={218,27,359,205},["tiles"]={{4,0.259765625,0.0009765625,0.3974609375,0.087890625},{4,0.4013671875,0.0009765625,0.5390625,0.087890625},{4,0.54296875,0.0009765625,0.6806640625,0.087890625},{4,0.6845703125,0.0009765625,0.822265625,0.087890625},{4,0.826171875,0.0009765625,0.9638671875,0.087890625},{4,0.001953125,0.09716796875,0.1396484375,0.18408203125},{4,0.1435546875,0.09716796875,0.28125,0.18408203125},{4,0.28515625,0.09716796875,0.4228515625,0.18408203125},{4,0.4267578125,0.09716796875,0.564453125,0.18408203125},{4,0.568359375,0.09716796875,0.7060546875,0.18408203125},{4,0.7099609375,0.09716796875,0.84765625,0.18408203125},{4,0.8515625,0.09716796875,0.9892578125,0.18408203125},{4,0.001953125,0.18603515625,0.1396484375,0.27294921875},{4,0.1435546875,0.18603515625,0.28125,0.27294921875},{4,0.28515625,0.18603515625,0.4228515625,0.27294921875},{4,0.4267578125,0.18603515625,0.564453125,0.27294921875},{4,0.568359375,0.18603515625,0.7060546875,0.27294921875},{4,0.7099609375,0.18603515625,0.84765625,0.27294921875},{4,0.8515625,0.18603515625,0.9892578125,0.27294921875},{4,0.001953125,0.27490234375,0.1396484375,0.36181640625},{4,0.1435546875,0.27490234375,0.28125,0.36181640625},{4,0.28515625,0.27490234375,0.4228515625,0.36181640625},{4,0.4267578125,0.27490234375,0.564453125,0.36181640625},{4,0.568359375,0.27490234375,0.7060546875,0.36181640625},{4,0.7099609375,0.27490234375,0.84765625,0.36181640625},{4,0.8515625,0.27490234375,0.9892578125,0.36181640625},{4,0.001953125,0.36376953125,0.1396484375,0.45068359375},{4,0.1435546875,0.36376953125,0.28125,0.45068359375},{4,0.28515625,0.36376953125,0.4228515625,0.45068359375},{4,0.4267578125,0.36376953125,0.564453125,0.45068359375},{4,0.568359375,0.36376953125,0.7060546875,0.45068359375},{4,0.7099609375,0.36376953125,0.84765625,0.45068359375},{4,0.8515625,0.36376953125,0.9892578125,0.45068359375},{4,0.001953125,0.45263671875,0.1396484375,0.53955078125}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={238,51,339,74},["tiles"]={{7,0.76953125,0.94384765625,0.8681640625,0.955078125}}},{["group"]="kirinTor",["rect"]={239,51,339,74},["tiles"]={{7,0.8720703125,0.94384765625,0.9697265625,0.955078125}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={238,74,339,101},["tiles"]={{7,0.78515625,0.7822265625,0.8837890625,0.79541015625},{7,0.8876953125,0.7822265625,0.986328125,0.79541015625},{7,0.78515625,0.8115234375,0.8837890625,0.82470703125},{7,0.8876953125,0.8115234375,0.986328125,0.82470703125},{7,0.78515625,0.8408203125,0.8837890625,0.85400390625},{7,0.8876953125,0.8408203125,0.986328125,0.85400390625},{7,0.78515625,0.8701171875,0.8837890625,0.88330078125},{7,0.8876953125,0.8701171875,0.986328125,0.88330078125},{7,0.765625,0.8994140625,0.8642578125,0.91259765625},{7,0.8681640625,0.8994140625,0.966796875,0.91259765625},{5,0.001953125,0.98291015625,0.1005859375,0.99609375},{5,0.1044921875,0.98291015625,0.203125,0.99609375},{5,0.20703125,0.98291015625,0.3056640625,0.99609375},{5,0.3095703125,0.98291015625,0.408203125,0.99609375},{5,0.412109375,0.98291015625,0.5107421875,0.99609375},{5,0.5146484375,0.98291015625,0.61328125,0.99609375},{5,0.6171875,0.98291015625,0.7158203125,0.99609375}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={239,74,339,101},["tiles"]={{5,0.7197265625,0.98291015625,0.8173828125,0.99609375},{5,0.8212890625,0.98291015625,0.9189453125,0.99609375},{7,0.001953125,0.9287109375,0.099609375,0.94189453125},{7,0.103515625,0.9287109375,0.201171875,0.94189453125},{7,0.205078125,0.9287109375,0.302734375,0.94189453125},{7,0.306640625,0.9287109375,0.404296875,0.94189453125},{7,0.408203125,0.9287109375,0.505859375,0.94189453125},{7,0.509765625,0.9287109375,0.607421875,0.94189453125},{7,0.611328125,0.9287109375,0.708984375,0.94189453125},{7,0.712890625,0.9287109375,0.810546875,0.94189453125},{7,0.814453125,0.9287109375,0.912109375,0.94189453125},{7,0.001953125,0.94384765625,0.099609375,0.95703125},{7,0.103515625,0.94384765625,0.201171875,0.95703125},{7,0.205078125,0.94384765625,0.302734375,0.95703125},{7,0.306640625,0.94384765625,0.404296875,0.95703125},{7,0.408203125,0.94384765625,0.505859375,0.95703125},{7,0.509765625,0.94384765625,0.607421875,0.95703125}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={238,101,339,207},["tiles"]={{7,0.783203125,0.3193359375,0.8818359375,0.37109375}}},{["group"]="kirinTor",["rect"]={239,101,339,207},["tiles"]={{7,0.8857421875,0.3193359375,0.9833984375,0.37109375}},["glow"]="eye"},{["group"]="shards",["rect"]={170,36,228,105},["tiles"]={{5,0.9130859375,0.4111328125,0.9697265625,0.44482421875},{5,0.9130859375,0.4931640625,0.9697265625,0.52685546875},{5,0.9130859375,0.5751953125,0.9697265625,0.60888671875},{5,0.9130859375,0.6572265625,0.9697265625,0.69091796875},{5,0.9130859375,0.7392578125,0.9697265625,0.77294921875},{7,0.8935546875,0.39892578125,0.9501953125,0.4326171875},{4,0.001953125,0.95166015625,0.05859375,0.9853515625},{4,0.0625,0.95166015625,0.119140625,0.9853515625},{4,0.123046875,0.95166015625,0.1796875,0.9853515625},{4,0.18359375,0.95166015625,0.240234375,0.9853515625},{4,0.244140625,0.95166015625,0.30078125,0.9853515625},{4,0.3046875,0.95166015625,0.361328125,0.9853515625},{4,0.365234375,0.95166015625,0.421875,0.9853515625},{4,0.42578125,0.95166015625,0.482421875,0.9853515625},{4,0.486328125,0.95166015625,0.54296875,0.9853515625}},["shard"]=1},{["group"]="shards",["rect"]={172,40,226,103},["tiles"]={{6,0.001953125,0.9560546875,0.0546875,0.98681640625},{6,0.05859375,0.9560546875,0.111328125,0.98681640625},{6,0.115234375,0.9560546875,0.16796875,0.98681640625},{6,0.171875,0.9560546875,0.224609375,0.98681640625},{6,0.228515625,0.9560546875,0.28125,0.98681640625},{6,0.28515625,0.9560546875,0.337890625,0.98681640625},{6,0.341796875,0.9560546875,0.39453125,0.98681640625},{6,0.3984375,0.9560546875,0.451171875,0.98681640625},{6,0.455078125,0.9560546875,0.5078125,0.98681640625},{6,0.51171875,0.9560546875,0.564453125,0.98681640625},{6,0.568359375,0.9560546875,0.62109375,0.98681640625},{6,0.625,0.9560546875,0.677734375,0.98681640625},{6,0.681640625,0.9560546875,0.734375,0.98681640625},{6,0.73828125,0.9560546875,0.791015625,0.98681640625},{6,0.794921875,0.9560546875,0.84765625,0.98681640625}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={198,72,228,108},["tiles"]={{4,0.96875,0.54150390625,0.998046875,0.55908203125},{4,0.96875,0.62353515625,0.998046875,0.64111328125},{4,0.96875,0.70556640625,0.998046875,0.72314453125},{4,0.96875,0.78759765625,0.998046875,0.80517578125},{4,0.96875,0.86962890625,0.998046875,0.88720703125},{5,0.96875,0.0009765625,0.998046875,0.0185546875},{5,0.96875,0.0830078125,0.998046875,0.1005859375},{5,0.96875,0.1650390625,0.998046875,0.1826171875},{5,0.96875,0.2470703125,0.998046875,0.2646484375},{5,0.96875,0.3291015625,0.998046875,0.3466796875},{4,0.9677734375,0.0009765625,0.9970703125,0.0185546875},{6,0.966796875,0.9560546875,0.99609375,0.9736328125},{4,0.9609375,0.45263671875,0.990234375,0.47021484375},{7,0.9541015625,0.39892578125,0.9833984375,0.41650390625},{7,0.7958984375,0.72314453125,0.8251953125,0.74072265625}},["shard"]=2},{["group"]="shards",["rect"]={201,75,226,106},["tiles"]={{5,0.9736328125,0.4931640625,0.998046875,0.50830078125},{5,0.9736328125,0.5751953125,0.998046875,0.59033203125},{5,0.9736328125,0.6572265625,0.998046875,0.67236328125},{5,0.9736328125,0.7392578125,0.998046875,0.75439453125},{7,0.8291015625,0.72314453125,0.853515625,0.73828125},{7,0.857421875,0.72314453125,0.8818359375,0.73828125},{7,0.8857421875,0.72314453125,0.91015625,0.73828125},{7,0.9140625,0.72314453125,0.9384765625,0.73828125},{7,0.9423828125,0.72314453125,0.966796875,0.73828125},{7,0.970703125,0.72314453125,0.9951171875,0.73828125},{7,0.78515625,0.7529296875,0.8095703125,0.76806640625},{7,0.8134765625,0.7529296875,0.837890625,0.76806640625},{7,0.841796875,0.7529296875,0.8662109375,0.76806640625},{7,0.8701171875,0.7529296875,0.89453125,0.76806640625},{7,0.8984375,0.7529296875,0.9228515625,0.76806640625}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={341,35,399,112},["tiles"]={{6,0.939453125,0.55810546875,0.99609375,0.595703125},{6,0.939453125,0.6376953125,0.99609375,0.67529296875},{6,0.939453125,0.71728515625,0.99609375,0.7548828125},{6,0.939453125,0.796875,0.99609375,0.83447265625},{6,0.939453125,0.87646484375,0.99609375,0.9140625},{7,0.939453125,0.0009765625,0.99609375,0.03857421875},{7,0.939453125,0.08056640625,0.99609375,0.1181640625},{7,0.939453125,0.16015625,0.99609375,0.19775390625},{7,0.939453125,0.23974609375,0.99609375,0.27734375},{7,0.939453125,0.45166015625,0.99609375,0.4892578125},{7,0.939453125,0.50439453125,0.99609375,0.5419921875},{7,0.939453125,0.55712890625,0.99609375,0.5947265625},{6,0.9384765625,0.478515625,0.9951171875,0.51611328125},{5,0.93359375,0.9033203125,0.990234375,0.94091796875},{6,0.93359375,0.0009765625,0.990234375,0.03857421875}},["shard"]=3},{["group"]="shards",["rect"]={344,38,397,109},["tiles"]={{6,0.93359375,0.08056640625,0.9853515625,0.115234375},{6,0.93359375,0.16015625,0.9853515625,0.19482421875},{6,0.93359375,0.23974609375,0.9853515625,0.2744140625},{6,0.93359375,0.3193359375,0.9853515625,0.35400390625},{6,0.93359375,0.39892578125,0.9853515625,0.43359375},{4,0.9130859375,0.54150390625,0.96484375,0.576171875},{4,0.9130859375,0.62353515625,0.96484375,0.658203125},{4,0.9130859375,0.70556640625,0.96484375,0.740234375},{4,0.9130859375,0.78759765625,0.96484375,0.822265625},{4,0.9130859375,0.86962890625,0.96484375,0.904296875},{5,0.9130859375,0.0009765625,0.96484375,0.03564453125},{5,0.9130859375,0.0830078125,0.96484375,0.11767578125},{5,0.9130859375,0.1650390625,0.96484375,0.19970703125},{5,0.9130859375,0.2470703125,0.96484375,0.28173828125},{5,0.9130859375,0.3291015625,0.96484375,0.36376953125}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={352,74,375,98},["tiles"]={{7,0.970703125,0.8994140625,0.9931640625,0.9111328125},{7,0.9267578125,0.7529296875,0.94921875,0.7646484375},{7,0.953125,0.7529296875,0.9755859375,0.7646484375},{5,0.9228515625,0.98291015625,0.9453125,0.99462890625},{5,0.94921875,0.98291015625,0.9716796875,0.99462890625},{5,0.9755859375,0.98291015625,0.998046875,0.99462890625},{7,0.916015625,0.9287109375,0.9384765625,0.9404296875},{7,0.9423828125,0.9287109375,0.96484375,0.9404296875},{7,0.96875,0.9287109375,0.9912109375,0.9404296875},{7,0.611328125,0.94384765625,0.6337890625,0.95556640625},{7,0.6376953125,0.94384765625,0.66015625,0.95556640625},{7,0.6640625,0.94384765625,0.6865234375,0.95556640625},{7,0.6904296875,0.94384765625,0.712890625,0.95556640625},{7,0.716796875,0.94384765625,0.7392578125,0.95556640625},{7,0.7431640625,0.94384765625,0.765625,0.95556640625}},["shard"]=4},{["group"]="shards",["rect"]={355,76,372,96},["tiles"]={{7,0.9794921875,0.7529296875,0.99609375,0.7626953125},{7,0.9736328125,0.94384765625,0.990234375,0.95361328125},{4,0.001953125,0.9873046875,0.0185546875,0.9970703125},{4,0.0224609375,0.9873046875,0.0390625,0.9970703125},{4,0.04296875,0.9873046875,0.0595703125,0.9970703125},{4,0.0634765625,0.9873046875,0.080078125,0.9970703125},{4,0.083984375,0.9873046875,0.1005859375,0.9970703125},{4,0.1044921875,0.9873046875,0.12109375,0.9970703125},{4,0.125,0.9873046875,0.1416015625,0.9970703125},{4,0.1455078125,0.9873046875,0.162109375,0.9970703125},{4,0.166015625,0.9873046875,0.1826171875,0.9970703125},{4,0.1865234375,0.9873046875,0.203125,0.9970703125},{4,0.20703125,0.9873046875,0.2236328125,0.9970703125},{4,0.2275390625,0.9873046875,0.244140625,0.9970703125},{4,0.248046875,0.9873046875,0.2646484375,0.9970703125}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={3,33,131,207},["tiles"]={{4,0.1435546875,0.45263671875,0.2685546875,0.53759765625}}},{["group"]="shoulderFloaters",["rect"]={6,160,39,204},["tiles"]={{7,0.9658203125,0.60986328125,0.998046875,0.63134765625}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={446,14,572,207},["tiles"]={{4,0.001953125,0.0009765625,0.125,0.09521484375}}},{["group"]="shoulderFloaters",["rect"]={535,153,570,204},["tiles"]={{4,0.9619140625,0.95166015625,0.99609375,0.9765625}},["glow"]="shoulder"}},["768"]={{["group"]="foundation",["rect"]={49,54,719,404},["tiles"]={{1,0.001953125,0.001953125,0.65625,0.34375}}},{["group"]="foundation",["rect"]={50,404,105,525},["tiles"]={{1,0.89453125,0.669921875,0.9482421875,0.7880859375}}},{["group"]="foundation",["rect"]={660,404,717,525},["tiles"]={{2,0.89453125,0.001953125,0.9501953125,0.1201171875}}},{["group"]="foundation",["rect"]={105,404,660,529},["tiles"]={{5,0.001953125,0.6455078125,0.5439453125,0.767578125},{5,0.001953125,0.771484375,0.5439453125,0.8935546875},{6,0.001953125,0.001953125,0.5439453125,0.1240234375},{6,0.001953125,0.1279296875,0.5439453125,0.25},{6,0.001953125,0.25390625,0.5439453125,0.3759765625},{6,0.001953125,0.3798828125,0.5439453125,0.501953125},{6,0.001953125,0.505859375,0.5439453125,0.6279296875},{6,0.001953125,0.6318359375,0.5439453125,0.75390625},{6,0.001953125,0.7578125,0.5439453125,0.8798828125},{7,0.001953125,0.00390625,0.5439453125,0.248046875},{7,0.001953125,0.255859375,0.5439453125,0.5},{7,0.001953125,0.5078125,0.5439453125,0.751953125}},["receiverFor"]="scroll"},{["group"]="bannerFloaters",["rect"]={43,484,117,619},["tiles"]={{1,0.890625,0.001953125,0.962890625,0.1337890625}}},{["group"]="bannerFloaters",["rect"]={651,484,725,616},["tiles"]={{1,0.89453125,0.34765625,0.966796875,0.4765625}}},{["group"]="body",["rect"]={100,458,174,534},["tiles"]={{14,0.001953125,0.42724609375,0.07421875,0.46435546875}}},{["group"]="body",["rect"]={174,458,303,534},["tiles"]={{14,0.078125,0.42724609375,0.2041015625,0.46435546875},{14,0.2080078125,0.42724609375,0.333984375,0.46435546875},{14,0.337890625,0.42724609375,0.4638671875,0.46435546875},{14,0.4677734375,0.42724609375,0.59375,0.46435546875},{14,0.59765625,0.42724609375,0.7236328125,0.46435546875},{14,0.7275390625,0.42724609375,0.853515625,0.46435546875},{14,0.857421875,0.42724609375,0.9833984375,0.46435546875},{14,0.001953125,0.46630859375,0.1279296875,0.50341796875},{14,0.1318359375,0.46630859375,0.2578125,0.50341796875},{14,0.26171875,0.46630859375,0.3876953125,0.50341796875},{14,0.3916015625,0.46630859375,0.517578125,0.50341796875},{14,0.521484375,0.46630859375,0.6474609375,0.50341796875}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={98,534,303,746},["tiles"]={{10,0.501953125,0.6484375,0.7021484375,0.751953125},{10,0.7060546875,0.6484375,0.90625,0.751953125},{10,0.001953125,0.75634765625,0.2021484375,0.85986328125},{10,0.2060546875,0.75634765625,0.40625,0.85986328125},{10,0.41015625,0.75634765625,0.6103515625,0.85986328125},{10,0.6142578125,0.75634765625,0.814453125,0.85986328125},{10,0.001953125,0.86181640625,0.2021484375,0.96533203125},{10,0.2060546875,0.86181640625,0.40625,0.96533203125},{10,0.41015625,0.86181640625,0.6103515625,0.96533203125},{10,0.6142578125,0.86181640625,0.814453125,0.96533203125},{11,0.001953125,0.0009765625,0.2021484375,0.1044921875},{11,0.2060546875,0.0009765625,0.40625,0.1044921875},{11,0.41015625,0.0009765625,0.6103515625,0.1044921875},{11,0.6142578125,0.0009765625,0.814453125,0.1044921875},{11,0.001953125,0.1064453125,0.2021484375,0.2099609375},{11,0.2060546875,0.1064453125,0.40625,0.2099609375},{11,0.41015625,0.1064453125,0.6103515625,0.2099609375},{11,0.6142578125,0.1064453125,0.814453125,0.2099609375},{11,0.001953125,0.2119140625,0.2021484375,0.3154296875},{11,0.2060546875,0.2119140625,0.40625,0.3154296875},{11,0.41015625,0.2119140625,0.6103515625,0.3154296875},{11,0.6142578125,0.2119140625,0.814453125,0.3154296875},{11,0.001953125,0.3173828125,0.2021484375,0.4208984375},{11,0.2060546875,0.3173828125,0.40625,0.4208984375},{11,0.41015625,0.3173828125,0.6103515625,0.4208984375},{11,0.6142578125,0.3173828125,0.814453125,0.4208984375},{11,0.001953125,0.4228515625,0.2021484375,0.5263671875},{11,0.2060546875,0.4228515625,0.40625,0.5263671875},{11,0.41015625,0.4228515625,0.6103515625,0.5263671875},{11,0.6142578125,0.4228515625,0.814453125,0.5263671875},{11,0.001953125,0.5283203125,0.2021484375,0.6318359375},{11,0.2060546875,0.5283203125,0.40625,0.6318359375},{11,0.41015625,0.5283203125,0.6103515625,0.6318359375},{11,0.6142578125,0.5283203125,0.814453125,0.6318359375},{11,0.001953125,0.6337890625,0.2021484375,0.7373046875},{11,0.2060546875,0.6337890625,0.40625,0.7373046875},{11,0.41015625,0.6337890625,0.6103515625,0.7373046875},{11,0.6142578125,0.6337890625,0.814453125,0.7373046875},{11,0.001953125,0.7392578125,0.2021484375,0.8427734375},{11,0.2060546875,0.7392578125,0.40625,0.8427734375},{11,0.41015625,0.7392578125,0.6103515625,0.8427734375},{11,0.6142578125,0.7392578125,0.814453125,0.8427734375},{11,0.001953125,0.8447265625,0.2021484375,0.9482421875},{11,0.2060546875,0.8447265625,0.40625,0.9482421875},{11,0.41015625,0.8447265625,0.6103515625,0.9482421875},{11,0.6142578125,0.8447265625,0.814453125,0.9482421875},{12,0.001953125,0.0009765625,0.2021484375,0.1044921875},{12,0.2060546875,0.0009765625,0.40625,0.1044921875},{12,0.41015625,0.0009765625,0.6103515625,0.1044921875},{12,0.6142578125,0.0009765625,0.814453125,0.1044921875},{12,0.001953125,0.1064453125,0.2021484375,0.2099609375},{12,0.2060546875,0.1064453125,0.40625,0.2099609375},{12,0.41015625,0.1064453125,0.6103515625,0.2099609375},{12,0.6142578125,0.1064453125,0.814453125,0.2099609375},{12,0.001953125,0.2119140625,0.2021484375,0.3154296875},{12,0.2060546875,0.2119140625,0.40625,0.3154296875},{12,0.41015625,0.2119140625,0.6103515625,0.3154296875},{12,0.6142578125,0.2119140625,0.814453125,0.3154296875},{12,0.001953125,0.3173828125,0.2021484375,0.4208984375},{12,0.2060546875,0.3173828125,0.40625,0.4208984375},{12,0.41015625,0.3173828125,0.6103515625,0.4208984375},{12,0.6142578125,0.3173828125,0.814453125,0.4208984375},{12,0.001953125,0.4228515625,0.2021484375,0.5263671875},{12,0.2060546875,0.4228515625,0.40625,0.5263671875}},["clip"]="left-banner"},{["group"]="body",["rect"]={597,458,667,533},["tiles"]={{14,0.6513671875,0.46630859375,0.7197265625,0.5029296875}}},{["group"]="body",["rect"]={465,458,597,533},["tiles"]={{14,0.7236328125,0.46630859375,0.8525390625,0.5029296875},{14,0.8564453125,0.46630859375,0.9853515625,0.5029296875},{14,0.001953125,0.50537109375,0.130859375,0.5419921875},{14,0.134765625,0.50537109375,0.263671875,0.5419921875},{14,0.267578125,0.50537109375,0.396484375,0.5419921875},{14,0.400390625,0.50537109375,0.529296875,0.5419921875},{14,0.533203125,0.50537109375,0.662109375,0.5419921875},{14,0.666015625,0.50537109375,0.794921875,0.5419921875},{14,0.798828125,0.50537109375,0.927734375,0.5419921875},{14,0.001953125,0.5439453125,0.130859375,0.58056640625},{14,0.134765625,0.5439453125,0.263671875,0.58056640625},{14,0.267578125,0.5439453125,0.396484375,0.58056640625}},["receiverFor"]="scroll"},{["group"]="body",["rect"]={464,533,669,744},["tiles"]={{12,0.41015625,0.4228515625,0.6103515625,0.52587890625},{12,0.6142578125,0.4228515625,0.814453125,0.52587890625},{12,0.001953125,0.5283203125,0.2021484375,0.63134765625},{12,0.2060546875,0.5283203125,0.40625,0.63134765625},{12,0.41015625,0.5283203125,0.6103515625,0.63134765625},{12,0.6142578125,0.5283203125,0.814453125,0.63134765625},{12,0.001953125,0.63330078125,0.2021484375,0.736328125},{12,0.2060546875,0.63330078125,0.40625,0.736328125},{12,0.41015625,0.63330078125,0.6103515625,0.736328125},{12,0.6142578125,0.63330078125,0.814453125,0.736328125},{12,0.001953125,0.73828125,0.2021484375,0.84130859375},{12,0.2060546875,0.73828125,0.40625,0.84130859375},{12,0.41015625,0.73828125,0.6103515625,0.84130859375},{12,0.6142578125,0.73828125,0.814453125,0.84130859375},{12,0.001953125,0.84326171875,0.2021484375,0.9462890625},{12,0.2060546875,0.84326171875,0.40625,0.9462890625},{12,0.41015625,0.84326171875,0.6103515625,0.9462890625},{12,0.6142578125,0.84326171875,0.814453125,0.9462890625},{13,0.001953125,0.0009765625,0.2021484375,0.10400390625},{13,0.2060546875,0.0009765625,0.40625,0.10400390625},{13,0.41015625,0.0009765625,0.6103515625,0.10400390625},{13,0.6142578125,0.0009765625,0.814453125,0.10400390625},{13,0.001953125,0.10595703125,0.2021484375,0.208984375},{13,0.2060546875,0.10595703125,0.40625,0.208984375},{13,0.41015625,0.10595703125,0.6103515625,0.208984375},{13,0.6142578125,0.10595703125,0.814453125,0.208984375},{13,0.001953125,0.2109375,0.2021484375,0.31396484375},{13,0.2060546875,0.2109375,0.40625,0.31396484375},{13,0.41015625,0.2109375,0.6103515625,0.31396484375},{13,0.6142578125,0.2109375,0.814453125,0.31396484375},{13,0.001953125,0.31591796875,0.2021484375,0.4189453125},{13,0.2060546875,0.31591796875,0.40625,0.4189453125},{13,0.41015625,0.31591796875,0.6103515625,0.4189453125},{13,0.6142578125,0.31591796875,0.814453125,0.4189453125},{13,0.001953125,0.4208984375,0.2021484375,0.52392578125},{13,0.2060546875,0.4208984375,0.40625,0.52392578125},{13,0.41015625,0.4208984375,0.6103515625,0.52392578125},{13,0.6142578125,0.4208984375,0.814453125,0.52392578125},{13,0.001953125,0.52587890625,0.2021484375,0.62890625},{13,0.2060546875,0.52587890625,0.40625,0.62890625},{13,0.41015625,0.52587890625,0.6103515625,0.62890625},{13,0.6142578125,0.52587890625,0.814453125,0.62890625},{13,0.001953125,0.630859375,0.2021484375,0.73388671875},{13,0.2060546875,0.630859375,0.40625,0.73388671875},{13,0.41015625,0.630859375,0.6103515625,0.73388671875},{13,0.6142578125,0.630859375,0.814453125,0.73388671875},{13,0.001953125,0.73583984375,0.2021484375,0.8388671875},{13,0.2060546875,0.73583984375,0.40625,0.8388671875},{13,0.41015625,0.73583984375,0.6103515625,0.8388671875},{13,0.6142578125,0.73583984375,0.814453125,0.8388671875},{13,0.001953125,0.8408203125,0.2021484375,0.94384765625},{13,0.2060546875,0.8408203125,0.40625,0.94384765625},{13,0.41015625,0.8408203125,0.6103515625,0.94384765625},{13,0.6142578125,0.8408203125,0.814453125,0.94384765625},{14,0.001953125,0.0009765625,0.2021484375,0.10400390625},{14,0.2060546875,0.0009765625,0.40625,0.10400390625},{14,0.41015625,0.0009765625,0.6103515625,0.10400390625},{14,0.6142578125,0.0009765625,0.814453125,0.10400390625},{14,0.001953125,0.10595703125,0.2021484375,0.208984375},{14,0.2060546875,0.10595703125,0.40625,0.208984375},{14,0.41015625,0.10595703125,0.6103515625,0.208984375},{14,0.6142578125,0.10595703125,0.814453125,0.208984375},{14,0.001953125,0.2109375,0.2021484375,0.31396484375},{14,0.2060546875,0.2109375,0.40625,0.31396484375}},["clip"]="right-banner"},{["group"]="body",["rect"]={105,306,664,390},["tiles"]={{8,0.314453125,0.95458984375,0.8603515625,0.99560546875}}},{["group"]="body",["rect"]={105,168,308,306},["tiles"]={{14,0.41015625,0.2109375,0.6083984375,0.2783203125}}},{["group"]="body",["rect"]={462,168,664,306},["tiles"]={{14,0.6123046875,0.2109375,0.8095703125,0.2783203125}}},{["group"]="body",["rect"]={308,168,462,306},["tiles"]={{10,0.818359375,0.86181640625,0.96875,0.92919921875},{11,0.818359375,0.0009765625,0.96875,0.068359375},{11,0.818359375,0.1064453125,0.96875,0.173828125},{11,0.818359375,0.2119140625,0.96875,0.279296875},{11,0.818359375,0.3173828125,0.96875,0.384765625},{11,0.818359375,0.4228515625,0.96875,0.490234375},{11,0.818359375,0.5283203125,0.96875,0.595703125},{11,0.818359375,0.6337890625,0.96875,0.701171875},{11,0.818359375,0.7392578125,0.96875,0.806640625},{11,0.818359375,0.8447265625,0.96875,0.912109375},{12,0.818359375,0.0009765625,0.96875,0.068359375},{12,0.818359375,0.1064453125,0.96875,0.173828125},{12,0.818359375,0.2119140625,0.96875,0.279296875},{12,0.818359375,0.3173828125,0.96875,0.384765625},{12,0.818359375,0.4228515625,0.96875,0.490234375},{12,0.818359375,0.5283203125,0.96875,0.595703125},{12,0.818359375,0.63330078125,0.96875,0.70068359375},{12,0.818359375,0.73828125,0.96875,0.8056640625},{12,0.818359375,0.84326171875,0.96875,0.91064453125},{13,0.818359375,0.0009765625,0.96875,0.068359375},{13,0.818359375,0.10595703125,0.96875,0.17333984375},{13,0.818359375,0.2109375,0.96875,0.2783203125},{13,0.818359375,0.31591796875,0.96875,0.38330078125},{13,0.818359375,0.4208984375,0.96875,0.48828125},{13,0.818359375,0.52587890625,0.96875,0.59326171875},{13,0.818359375,0.630859375,0.96875,0.6982421875},{13,0.818359375,0.73583984375,0.96875,0.80322265625},{13,0.818359375,0.8408203125,0.96875,0.908203125},{14,0.818359375,0.0009765625,0.96875,0.068359375},{14,0.818359375,0.10595703125,0.96875,0.17333984375},{14,0.8134765625,0.2109375,0.9638671875,0.2783203125},{14,0.001953125,0.31591796875,0.15234375,0.38330078125},{14,0.15625,0.31591796875,0.306640625,0.38330078125},{14,0.310546875,0.31591796875,0.4609375,0.38330078125}},["receiverFor"]="iris"},{["group"]="body",["rect"]={105,465,664,466},["tiles"]={{9,0.001953125,0.9931640625,0.5478515625,0.99365234375}}},{["group"]="body",["rect"]={105,390,120,465},["tiles"]={{8,0.9736328125,0.0009765625,0.98828125,0.03759765625}}},{["group"]="body",["rect"]={650,390,664,465},["tiles"]={{10,0.97265625,0.86181640625,0.986328125,0.8984375}}},{["group"]="body",["rect"]={120,390,650,465},["tiles"]={{14,0.400390625,0.5439453125,0.91796875,0.58056640625},{14,0.001953125,0.58251953125,0.51953125,0.619140625},{14,0.001953125,0.62109375,0.51953125,0.65771484375},{14,0.001953125,0.65966796875,0.51953125,0.6962890625},{14,0.001953125,0.6982421875,0.51953125,0.73486328125},{14,0.001953125,0.73681640625,0.51953125,0.7734375},{14,0.001953125,0.775390625,0.51953125,0.81201171875},{14,0.001953125,0.81396484375,0.51953125,0.8505859375},{14,0.001953125,0.8525390625,0.51953125,0.88916015625},{14,0.001953125,0.89111328125,0.51953125,0.927734375},{14,0.001953125,0.9296875,0.51953125,0.96630859375},{15,0.001953125,0.015625,0.51953125,0.6015625}},["receiverFor"]="scroll"},{["group"]="scroll",["rect"]={129,405,637,518},["tiles"]={{14,0.46484375,0.31591796875,0.9609375,0.37109375}}},{["group"]="scroll",["rect"]={129,518,637,735},["tiles"]={{8,0.357421875,0.83642578125,0.853515625,0.9423828125},{9,0.001953125,0.0009765625,0.498046875,0.10693359375},{9,0.501953125,0.0009765625,0.998046875,0.10693359375},{9,0.001953125,0.10888671875,0.498046875,0.21484375},{9,0.501953125,0.10888671875,0.998046875,0.21484375},{9,0.001953125,0.216796875,0.498046875,0.32275390625},{9,0.501953125,0.216796875,0.998046875,0.32275390625},{9,0.001953125,0.32470703125,0.498046875,0.4306640625},{9,0.501953125,0.32470703125,0.998046875,0.4306640625},{9,0.001953125,0.4326171875,0.498046875,0.53857421875},{9,0.501953125,0.4326171875,0.998046875,0.53857421875},{9,0.001953125,0.54052734375,0.498046875,0.646484375},{9,0.501953125,0.54052734375,0.998046875,0.646484375},{9,0.001953125,0.6484375,0.498046875,0.75439453125},{9,0.501953125,0.6484375,0.998046875,0.75439453125},{9,0.001953125,0.75634765625,0.498046875,0.8623046875},{9,0.501953125,0.75634765625,0.998046875,0.8623046875},{9,0.001953125,0.8642578125,0.498046875,0.97021484375},{9,0.501953125,0.8642578125,0.998046875,0.97021484375},{10,0.001953125,0.0009765625,0.498046875,0.10693359375},{10,0.501953125,0.0009765625,0.998046875,0.10693359375},{10,0.001953125,0.10888671875,0.498046875,0.21484375},{10,0.501953125,0.10888671875,0.998046875,0.21484375},{10,0.001953125,0.216796875,0.498046875,0.32275390625},{10,0.501953125,0.216796875,0.998046875,0.32275390625},{10,0.001953125,0.32470703125,0.498046875,0.4306640625},{10,0.501953125,0.32470703125,0.998046875,0.4306640625},{10,0.001953125,0.4326171875,0.498046875,0.53857421875},{10,0.501953125,0.4326171875,0.998046875,0.53857421875},{10,0.001953125,0.54052734375,0.498046875,0.646484375},{10,0.501953125,0.54052734375,0.998046875,0.646484375},{10,0.001953125,0.6484375,0.498046875,0.75439453125}},["clip"]="scroll"},{["group"]="scroll",["rect"]={133,428,634,467},["tiles"]={{9,0.001953125,0.97216796875,0.4912109375,0.9912109375}},["glow"]="scroll"},{["group"]="body",["rect"]={208,20,561,36},["tiles"]={{10,0.5302734375,0.96728515625,0.875,0.97509765625}}},{["group"]="body",["rect"]={208,36,291,274},["tiles"]={{8,0.16796875,0.0009765625,0.2490234375,0.1171875}}},{["group"]="body",["rect"]={478,36,561,274},["tiles"]={{8,0.2529296875,0.0009765625,0.333984375,0.1171875}}},{["group"]="body",["rect"]={291,36,478,274},["tiles"]={{8,0.337890625,0.0009765625,0.5205078125,0.1171875},{8,0.5244140625,0.0009765625,0.70703125,0.1171875},{8,0.7109375,0.0009765625,0.8935546875,0.1171875},{8,0.001953125,0.12744140625,0.1845703125,0.24365234375},{8,0.1884765625,0.12744140625,0.37109375,0.24365234375},{8,0.375,0.12744140625,0.5576171875,0.24365234375},{8,0.5615234375,0.12744140625,0.744140625,0.24365234375},{8,0.748046875,0.12744140625,0.9306640625,0.24365234375},{8,0.001953125,0.24560546875,0.1845703125,0.36181640625},{8,0.1884765625,0.24560546875,0.37109375,0.36181640625},{8,0.375,0.24560546875,0.5576171875,0.36181640625},{8,0.5615234375,0.24560546875,0.744140625,0.36181640625},{8,0.748046875,0.24560546875,0.9306640625,0.36181640625},{8,0.001953125,0.36376953125,0.1845703125,0.47998046875},{8,0.1884765625,0.36376953125,0.37109375,0.47998046875},{8,0.375,0.36376953125,0.5576171875,0.47998046875},{8,0.5615234375,0.36376953125,0.744140625,0.47998046875},{8,0.748046875,0.36376953125,0.9306640625,0.47998046875},{8,0.001953125,0.48193359375,0.1845703125,0.59814453125},{8,0.1884765625,0.48193359375,0.37109375,0.59814453125},{8,0.375,0.48193359375,0.5576171875,0.59814453125},{8,0.5615234375,0.48193359375,0.744140625,0.59814453125},{8,0.748046875,0.48193359375,0.9306640625,0.59814453125},{8,0.001953125,0.60009765625,0.1845703125,0.71630859375},{8,0.1884765625,0.60009765625,0.37109375,0.71630859375},{8,0.375,0.60009765625,0.5576171875,0.71630859375},{8,0.5615234375,0.60009765625,0.744140625,0.71630859375},{8,0.748046875,0.60009765625,0.9306640625,0.71630859375},{8,0.001953125,0.71826171875,0.1845703125,0.83447265625},{8,0.1884765625,0.71826171875,0.37109375,0.83447265625},{8,0.375,0.71826171875,0.5576171875,0.83447265625},{8,0.5615234375,0.71826171875,0.744140625,0.83447265625},{8,0.748046875,0.71826171875,0.9306640625,0.83447265625},{8,0.001953125,0.83642578125,0.1845703125,0.95263671875}},["receiverFor"]="iris"},{["group"]="kirinTor",["rect"]={319,70,451,99},["tiles"]={{10,0.265625,0.96728515625,0.39453125,0.9814453125}}},{["group"]="kirinTor",["rect"]={319,70,450,99},["tiles"]={{10,0.3984375,0.96728515625,0.5263671875,0.9814453125}},["glow"]="eye"},{["group"]="kirinTor",["rect"]={319,99,451,134},["tiles"]={{14,0.689453125,0.62109375,0.818359375,0.63818359375},{14,0.822265625,0.62109375,0.951171875,0.63818359375},{14,0.5234375,0.65966796875,0.65234375,0.6767578125},{14,0.65625,0.65966796875,0.78515625,0.6767578125},{14,0.7890625,0.65966796875,0.91796875,0.6767578125},{14,0.5234375,0.6982421875,0.65234375,0.71533203125},{14,0.65625,0.6982421875,0.78515625,0.71533203125},{14,0.7890625,0.6982421875,0.91796875,0.71533203125},{14,0.5234375,0.73681640625,0.65234375,0.75390625},{14,0.65625,0.73681640625,0.78515625,0.75390625},{14,0.7890625,0.73681640625,0.91796875,0.75390625},{14,0.5234375,0.775390625,0.65234375,0.79248046875},{14,0.65625,0.775390625,0.78515625,0.79248046875},{14,0.7890625,0.775390625,0.91796875,0.79248046875},{14,0.5234375,0.81396484375,0.65234375,0.8310546875},{14,0.65625,0.81396484375,0.78515625,0.8310546875},{14,0.7890625,0.81396484375,0.91796875,0.8310546875}},["clip"]="iris"},{["group"]="kirinTor",["rect"]={319,99,450,134},["tiles"]={{14,0.5234375,0.8525390625,0.6513671875,0.86962890625},{14,0.6552734375,0.8525390625,0.783203125,0.86962890625},{14,0.787109375,0.8525390625,0.9150390625,0.86962890625},{14,0.5234375,0.89111328125,0.6513671875,0.908203125},{14,0.6552734375,0.89111328125,0.783203125,0.908203125},{14,0.787109375,0.89111328125,0.9150390625,0.908203125},{14,0.5234375,0.9296875,0.6513671875,0.94677734375},{14,0.6552734375,0.9296875,0.783203125,0.94677734375},{14,0.787109375,0.9296875,0.9150390625,0.94677734375},{15,0.5234375,0.015625,0.6513671875,0.2890625},{15,0.6552734375,0.015625,0.783203125,0.2890625},{15,0.787109375,0.015625,0.9150390625,0.2890625},{9,0.4951171875,0.97216796875,0.623046875,0.9892578125},{9,0.626953125,0.97216796875,0.7548828125,0.9892578125},{9,0.7587890625,0.97216796875,0.88671875,0.9892578125},{10,0.001953125,0.96728515625,0.1298828125,0.984375},{10,0.1337890625,0.96728515625,0.26171875,0.984375}},["clip"]="iris",["glow"]="eye"},{["group"]="kirinTor",["rect"]={319,134,451,275},["tiles"]={{8,0.857421875,0.83642578125,0.986328125,0.9052734375}}},{["group"]="kirinTor",["rect"]={319,134,450,274},["tiles"]={{10,0.818359375,0.75634765625,0.9462890625,0.82470703125}},["glow"]="eye"},{["group"]="shards",["rect"]={227,50,303,139},["tiles"]={{13,0.072265625,0.94580078125,0.146484375,0.9892578125},{13,0.150390625,0.94580078125,0.224609375,0.9892578125},{13,0.228515625,0.94580078125,0.302734375,0.9892578125},{13,0.306640625,0.94580078125,0.380859375,0.9892578125},{13,0.384765625,0.94580078125,0.458984375,0.9892578125},{13,0.462890625,0.94580078125,0.537109375,0.9892578125},{13,0.541015625,0.94580078125,0.615234375,0.9892578125},{13,0.619140625,0.94580078125,0.693359375,0.9892578125},{13,0.697265625,0.94580078125,0.771484375,0.9892578125},{13,0.775390625,0.94580078125,0.849609375,0.9892578125},{13,0.853515625,0.94580078125,0.927734375,0.9892578125},{8,0.001953125,0.95458984375,0.076171875,0.998046875},{8,0.080078125,0.95458984375,0.154296875,0.998046875},{8,0.158203125,0.95458984375,0.232421875,0.998046875},{8,0.236328125,0.95458984375,0.310546875,0.998046875}},["shard"]=1},{["group"]="shards",["rect"]={231,54,300,136},["tiles"]={{8,0.8642578125,0.95458984375,0.931640625,0.99462890625},{14,0.001953125,0.38525390625,0.0693359375,0.42529296875},{14,0.0732421875,0.38525390625,0.140625,0.42529296875},{14,0.14453125,0.38525390625,0.2119140625,0.42529296875},{14,0.2158203125,0.38525390625,0.283203125,0.42529296875},{14,0.287109375,0.38525390625,0.3544921875,0.42529296875},{14,0.3583984375,0.38525390625,0.42578125,0.42529296875},{14,0.4296875,0.38525390625,0.4970703125,0.42529296875},{14,0.5009765625,0.38525390625,0.568359375,0.42529296875},{14,0.572265625,0.38525390625,0.6396484375,0.42529296875},{14,0.6435546875,0.38525390625,0.7109375,0.42529296875},{14,0.71484375,0.38525390625,0.7822265625,0.42529296875},{14,0.7861328125,0.38525390625,0.853515625,0.42529296875},{14,0.857421875,0.38525390625,0.9248046875,0.42529296875},{14,0.9287109375,0.38525390625,0.99609375,0.42529296875}},["shard"]=1,["glow"]="shard"},{["group"]="shards",["rect"]={265,98,303,142},["tiles"]={{8,0.9345703125,0.12744140625,0.9716796875,0.14892578125},{8,0.9345703125,0.24560546875,0.9716796875,0.26708984375},{8,0.9345703125,0.36376953125,0.9716796875,0.38525390625},{8,0.9345703125,0.48193359375,0.9716796875,0.50341796875},{8,0.9345703125,0.60009765625,0.9716796875,0.62158203125},{8,0.9345703125,0.71826171875,0.9716796875,0.73974609375},{13,0.931640625,0.94580078125,0.96875,0.96728515625},{14,0.931640625,0.50537109375,0.96875,0.52685546875},{14,0.921875,0.5439453125,0.958984375,0.5654296875},{14,0.5234375,0.58251953125,0.560546875,0.60400390625},{14,0.564453125,0.58251953125,0.6015625,0.60400390625},{14,0.60546875,0.58251953125,0.642578125,0.60400390625},{14,0.646484375,0.58251953125,0.68359375,0.60400390625},{14,0.6875,0.58251953125,0.724609375,0.60400390625},{14,0.728515625,0.58251953125,0.765625,0.60400390625}},["shard"]=2},{["group"]="shards",["rect"]={270,101,300,140},["tiles"]={{14,0.9677734375,0.2109375,0.9970703125,0.22998046875},{14,0.96484375,0.31591796875,0.994140625,0.3349609375},{14,0.962890625,0.5439453125,0.9921875,0.56298828125},{14,0.76953125,0.58251953125,0.798828125,0.6015625},{14,0.802734375,0.58251953125,0.83203125,0.6015625},{14,0.8359375,0.58251953125,0.865234375,0.6015625},{14,0.869140625,0.58251953125,0.8984375,0.6015625},{14,0.90234375,0.58251953125,0.931640625,0.6015625},{14,0.935546875,0.58251953125,0.96484375,0.6015625},{14,0.96875,0.58251953125,0.998046875,0.6015625},{14,0.5234375,0.62109375,0.552734375,0.64013671875},{14,0.556640625,0.62109375,0.5859375,0.64013671875},{14,0.58984375,0.62109375,0.619140625,0.64013671875},{14,0.623046875,0.62109375,0.65234375,0.64013671875},{14,0.65625,0.62109375,0.685546875,0.64013671875}},["shard"]=2,["glow"]="shard"},{["group"]="shards",["rect"]={456,48,530,148},["tiles"]={{10,0.91015625,0.6484375,0.982421875,0.697265625},{8,0.8974609375,0.0009765625,0.9697265625,0.0498046875},{11,0.001953125,0.9501953125,0.07421875,0.9990234375},{11,0.078125,0.9501953125,0.150390625,0.9990234375},{11,0.154296875,0.9501953125,0.2265625,0.9990234375},{11,0.23046875,0.9501953125,0.302734375,0.9990234375},{11,0.306640625,0.9501953125,0.37890625,0.9990234375},{11,0.3828125,0.9501953125,0.455078125,0.9990234375},{11,0.458984375,0.9501953125,0.53125,0.9990234375},{11,0.53515625,0.9501953125,0.607421875,0.9990234375},{11,0.611328125,0.9501953125,0.68359375,0.9990234375},{11,0.6875,0.9501953125,0.759765625,0.9990234375},{11,0.763671875,0.9501953125,0.8359375,0.9990234375},{11,0.83984375,0.9501953125,0.912109375,0.9990234375},{11,0.916015625,0.9501953125,0.98828125,0.9990234375}},["shard"]=3},{["group"]="shards",["rect"]={460,52,528,145},["tiles"]={{12,0.001953125,0.9482421875,0.068359375,0.99365234375},{12,0.072265625,0.9482421875,0.138671875,0.99365234375},{12,0.142578125,0.9482421875,0.208984375,0.99365234375},{12,0.212890625,0.9482421875,0.279296875,0.99365234375},{12,0.283203125,0.9482421875,0.349609375,0.99365234375},{12,0.353515625,0.9482421875,0.419921875,0.99365234375},{12,0.423828125,0.9482421875,0.490234375,0.99365234375},{12,0.494140625,0.9482421875,0.560546875,0.99365234375},{12,0.564453125,0.9482421875,0.630859375,0.99365234375},{12,0.634765625,0.9482421875,0.701171875,0.99365234375},{12,0.705078125,0.9482421875,0.771484375,0.99365234375},{12,0.775390625,0.9482421875,0.841796875,0.99365234375},{12,0.845703125,0.9482421875,0.912109375,0.99365234375},{12,0.916015625,0.9482421875,0.982421875,0.99365234375},{13,0.001953125,0.94580078125,0.068359375,0.9912109375}},["shard"]=3,["glow"]="shard"},{["group"]="shards",["rect"]={471,99,499,129},["tiles"]={{14,0.955078125,0.62109375,0.982421875,0.6357421875},{14,0.921875,0.65966796875,0.94921875,0.67431640625},{14,0.953125,0.65966796875,0.98046875,0.67431640625},{14,0.921875,0.6982421875,0.94921875,0.712890625},{14,0.953125,0.6982421875,0.98046875,0.712890625},{14,0.921875,0.73681640625,0.94921875,0.75146484375},{14,0.953125,0.73681640625,0.98046875,0.75146484375},{14,0.921875,0.775390625,0.94921875,0.7900390625},{14,0.953125,0.775390625,0.98046875,0.7900390625},{14,0.921875,0.81396484375,0.94921875,0.82861328125},{14,0.953125,0.81396484375,0.98046875,0.82861328125},{14,0.9189453125,0.8525390625,0.9462890625,0.8671875},{14,0.9501953125,0.8525390625,0.9775390625,0.8671875},{14,0.9189453125,0.89111328125,0.9462890625,0.90576171875},{14,0.9501953125,0.89111328125,0.9775390625,0.90576171875}},["shard"]=4},{["group"]="shards",["rect"]={474,102,495,126},["tiles"]={{8,0.9755859375,0.12744140625,0.99609375,0.13916015625},{8,0.9755859375,0.24560546875,0.99609375,0.25732421875},{8,0.9755859375,0.36376953125,0.99609375,0.37548828125},{8,0.9755859375,0.48193359375,0.99609375,0.49365234375},{8,0.9755859375,0.60009765625,0.99609375,0.61181640625},{8,0.9755859375,0.71826171875,0.99609375,0.72998046875},{11,0.97265625,0.0009765625,0.9931640625,0.0126953125},{11,0.97265625,0.1064453125,0.9931640625,0.1181640625},{11,0.97265625,0.2119140625,0.9931640625,0.2236328125},{11,0.97265625,0.3173828125,0.9931640625,0.3291015625},{11,0.97265625,0.4228515625,0.9931640625,0.4345703125},{11,0.97265625,0.5283203125,0.9931640625,0.5400390625},{11,0.97265625,0.6337890625,0.9931640625,0.6455078125},{11,0.97265625,0.7392578125,0.9931640625,0.7509765625},{11,0.97265625,0.8447265625,0.9931640625,0.8564453125}},["shard"]=4,["glow"]="shard"},{["group"]="shoulderFloaters",["rect"]={5,45,174,275},["tiles"]={{8,0.1884765625,0.83642578125,0.353515625,0.94873046875}}},{["group"]="shoulderFloaters",["rect"]={9,215,51,271},["tiles"]={{8,0.935546875,0.95458984375,0.9765625,0.98193359375}},["glow"]="shoulder"},{["group"]="shoulderFloaters",["rect"]={596,20,762,275},["tiles"]={{8,0.001953125,0.0009765625,0.1640625,0.12548828125}}},{["group"]="shoulderFloaters",["rect"]={715,205,758,271},["tiles"]={{10,0.9501953125,0.75634765625,0.9921875,0.78857421875}},["glow"]="shoulder"}}},["clips"]={["left-banner"]={["period"]=5.8,["phase"]=0.7},["right-banner"]={["period"]=6.3,["phase"]=2.1},["scroll"]={["period"]=7.1,["phase"]=1.6}},["angles"]={-5.25,-4.5,-3.75,-3.0,-2.25,-1.5,-0.75,0.0,0.75,1.5,2.25,3.0,3.75,4.5,5.25},["irisGazes"]={-5.5,-4.8125,-4.125,-3.4375,-2.75,-2.0625,-1.375,-0.6875,0.0,0.6875,1.375,2.0625,2.75,3.4375,4.125,4.8125,5.5},["irisShadowGazes"]={-5.5,0,5.5},["pages"]={["192"]={1,2},["288"]={1,2,3},["384"]={1,2,3,4},["480"]={1,2,3,4,5},["576"]={1,3,4,5,6,7},["768"]={1,2,5,6,7,8,9,10,11,12,13,14,15}}}
local sealData = E.ArcaneFloatData
sealData.seal = {center={632.453811646,934.588317871},width=762,period=32,tiles={}}
sealData.seal.tiles["192"] = {3,0.8984375}
table.insert(sealData.pages["192"], 3)
sealData.seal.tiles["288"] = {4,0.67578125}
table.insert(sealData.pages["288"], 4)
sealData.seal.tiles["384"] = {5,0.90234375}
table.insert(sealData.pages["384"], 5)
sealData.seal.tiles["480"] = {6,0.5625}
table.insert(sealData.pages["480"], 6)
sealData.seal.tiles["576"] = {8,0.67578125}
table.insert(sealData.pages["576"], 8)
sealData.seal.tiles["768"] = {16,0.90234375}
table.insert(sealData.pages["768"], 16)
sealData.seal.idle = {fps=8,banks={}}
table.remove(sealData.pages["192"])
table.insert(sealData.pages["192"], 3)
table.insert(sealData.pages["192"], 4)
table.insert(sealData.pages["192"], 5)
sealData.seal.idle.banks["192"] = {rect={0.05217391304347826,0.10434782608695652,0.9304347826086956,0.9391304347826087},tiles={{3,0.015625,0.0078125,0.8046875,0.3828125},{3,0.015625,0.3984375,0.8046875,0.7734375},{4,0.015625,0.001953125,0.8046875,0.095703125},{4,0.015625,0.099609375,0.8046875,0.193359375},{4,0.015625,0.197265625,0.8046875,0.291015625},{4,0.015625,0.294921875,0.8046875,0.388671875},{4,0.015625,0.392578125,0.8046875,0.486328125},{4,0.015625,0.490234375,0.8046875,0.583984375},{4,0.015625,0.587890625,0.8046875,0.681640625},{4,0.015625,0.685546875,0.8046875,0.779296875},{4,0.015625,0.783203125,0.8046875,0.876953125},{4,0.015625,0.880859375,0.8046875,0.974609375},{5,0.015625,0.0009765625,0.8046875,0.0478515625},{5,0.015625,0.0498046875,0.8046875,0.0966796875},{5,0.015625,0.0986328125,0.8046875,0.1455078125},{5,0.015625,0.1474609375,0.8046875,0.1943359375},{5,0.015625,0.1962890625,0.8046875,0.2431640625},{5,0.015625,0.2451171875,0.8046875,0.2919921875},{5,0.015625,0.2939453125,0.8046875,0.3408203125},{5,0.015625,0.3427734375,0.8046875,0.3896484375},{5,0.015625,0.3916015625,0.8046875,0.4384765625},{5,0.015625,0.4404296875,0.8046875,0.4873046875},{5,0.015625,0.4892578125,0.8046875,0.5361328125},{5,0.015625,0.5380859375,0.8046875,0.5849609375},{5,0.015625,0.5869140625,0.8046875,0.6337890625},{5,0.015625,0.6357421875,0.8046875,0.6826171875},{5,0.015625,0.6845703125,0.8046875,0.7314453125},{5,0.015625,0.7333984375,0.8046875,0.7802734375},{5,0.015625,0.7822265625,0.8046875,0.8291015625},{5,0.015625,0.8310546875,0.8046875,0.8779296875},{5,0.015625,0.8798828125,0.8046875,0.9267578125},{5,0.015625,0.9287109375,0.8046875,0.9755859375}}}
table.remove(sealData.pages["288"])
table.insert(sealData.pages["288"], 4)
sealData.seal.idle.banks["288"] = {rect={0.05202312138728324,0.10404624277456648,0.930635838150289,0.9421965317919075},tiles={{4,0.00390625,0.0009765625,0.30078125,0.07177734375},{4,0.30859375,0.0009765625,0.60546875,0.07177734375},{4,0.61328125,0.0009765625,0.91015625,0.07177734375},{4,0.00390625,0.07373046875,0.30078125,0.14453125},{4,0.30859375,0.07373046875,0.60546875,0.14453125},{4,0.61328125,0.07373046875,0.91015625,0.14453125},{4,0.00390625,0.146484375,0.30078125,0.21728515625},{4,0.30859375,0.146484375,0.60546875,0.21728515625},{4,0.61328125,0.146484375,0.91015625,0.21728515625},{4,0.00390625,0.21923828125,0.30078125,0.2900390625},{4,0.30859375,0.21923828125,0.60546875,0.2900390625},{4,0.61328125,0.21923828125,0.91015625,0.2900390625},{4,0.00390625,0.2919921875,0.30078125,0.36279296875},{4,0.30859375,0.2919921875,0.60546875,0.36279296875},{4,0.61328125,0.2919921875,0.91015625,0.36279296875},{4,0.00390625,0.36474609375,0.30078125,0.435546875},{4,0.30859375,0.36474609375,0.60546875,0.435546875},{4,0.61328125,0.36474609375,0.91015625,0.435546875},{4,0.00390625,0.4375,0.30078125,0.50830078125},{4,0.30859375,0.4375,0.60546875,0.50830078125},{4,0.61328125,0.4375,0.91015625,0.50830078125},{4,0.00390625,0.51025390625,0.30078125,0.5810546875},{4,0.30859375,0.51025390625,0.60546875,0.5810546875},{4,0.61328125,0.51025390625,0.91015625,0.5810546875},{4,0.00390625,0.5830078125,0.30078125,0.65380859375},{4,0.30859375,0.5830078125,0.60546875,0.65380859375},{4,0.61328125,0.5830078125,0.91015625,0.65380859375},{4,0.00390625,0.65576171875,0.30078125,0.7265625},{4,0.30859375,0.65576171875,0.60546875,0.7265625},{4,0.61328125,0.65576171875,0.91015625,0.7265625},{4,0.00390625,0.728515625,0.30078125,0.79931640625},{4,0.30859375,0.728515625,0.60546875,0.79931640625}}}
table.remove(sealData.pages["384"])
table.insert(sealData.pages["384"], 5)
table.insert(sealData.pages["384"], 6)
table.insert(sealData.pages["384"], 7)
sealData.seal.idle.banks["384"] = {rect={0.047619047619047616,0.1038961038961039,0.9307359307359307,0.9393939393939394},tiles={{5,0.0078125,0.00390625,0.8046875,0.380859375},{5,0.0078125,0.388671875,0.8046875,0.765625},{6,0.0078125,0.0009765625,0.8046875,0.09521484375},{6,0.0078125,0.09716796875,0.8046875,0.19140625},{6,0.0078125,0.193359375,0.8046875,0.28759765625},{6,0.0078125,0.28955078125,0.8046875,0.3837890625},{6,0.0078125,0.3857421875,0.8046875,0.47998046875},{6,0.0078125,0.48193359375,0.8046875,0.576171875},{6,0.0078125,0.578125,0.8046875,0.67236328125},{6,0.0078125,0.67431640625,0.8046875,0.7685546875},{6,0.0078125,0.7705078125,0.8046875,0.86474609375},{6,0.0078125,0.86669921875,0.8046875,0.9609375},{7,0.00390625,0.0009765625,0.40234375,0.09521484375},{7,0.41015625,0.0009765625,0.80859375,0.09521484375},{7,0.00390625,0.09716796875,0.40234375,0.19140625},{7,0.41015625,0.09716796875,0.80859375,0.19140625},{7,0.00390625,0.193359375,0.40234375,0.28759765625},{7,0.41015625,0.193359375,0.80859375,0.28759765625},{7,0.00390625,0.28955078125,0.40234375,0.3837890625},{7,0.41015625,0.28955078125,0.80859375,0.3837890625},{7,0.00390625,0.3857421875,0.40234375,0.47998046875},{7,0.41015625,0.3857421875,0.80859375,0.47998046875},{7,0.00390625,0.48193359375,0.40234375,0.576171875},{7,0.41015625,0.48193359375,0.80859375,0.576171875},{7,0.00390625,0.578125,0.40234375,0.67236328125},{7,0.41015625,0.578125,0.80859375,0.67236328125},{7,0.00390625,0.67431640625,0.40234375,0.7685546875},{7,0.41015625,0.67431640625,0.80859375,0.7685546875},{7,0.00390625,0.7705078125,0.40234375,0.86474609375},{7,0.41015625,0.7705078125,0.80859375,0.86474609375},{7,0.00390625,0.86669921875,0.40234375,0.9609375},{7,0.41015625,0.86669921875,0.80859375,0.9609375}}}
table.remove(sealData.pages["480"])
table.insert(sealData.pages["480"], 6)
table.insert(sealData.pages["480"], 7)
table.insert(sealData.pages["480"], 8)
sealData.seal.idle.banks["480"] = {rect={0.04861111111111111,0.10416666666666667,0.9305555555555556,0.9409722222222222},tiles={{6,0.00390625,0.0078125,0.5,0.94921875},{7,0.001953125,0.0078125,0.25,0.94921875},{7,0.25390625,0.0078125,0.501953125,0.94921875},{7,0.505859375,0.0078125,0.75390625,0.94921875},{8,0.0009765625,0.001953125,0.125,0.2373046875},{8,0.126953125,0.001953125,0.2509765625,0.2373046875},{8,0.2529296875,0.001953125,0.376953125,0.2373046875},{8,0.37890625,0.001953125,0.5029296875,0.2373046875},{8,0.5048828125,0.001953125,0.62890625,0.2373046875},{8,0.630859375,0.001953125,0.7548828125,0.2373046875},{8,0.7568359375,0.001953125,0.880859375,0.2373046875},{8,0.0009765625,0.2412109375,0.125,0.4765625},{8,0.126953125,0.2412109375,0.2509765625,0.4765625},{8,0.2529296875,0.2412109375,0.376953125,0.4765625},{8,0.37890625,0.2412109375,0.5029296875,0.4765625},{8,0.5048828125,0.2412109375,0.62890625,0.4765625},{8,0.630859375,0.2412109375,0.7548828125,0.4765625},{8,0.7568359375,0.2412109375,0.880859375,0.4765625},{8,0.0009765625,0.48046875,0.125,0.7158203125},{8,0.126953125,0.48046875,0.2509765625,0.7158203125},{8,0.2529296875,0.48046875,0.376953125,0.7158203125},{8,0.37890625,0.48046875,0.5029296875,0.7158203125},{8,0.5048828125,0.48046875,0.62890625,0.7158203125},{8,0.630859375,0.48046875,0.7548828125,0.7158203125},{8,0.7568359375,0.48046875,0.880859375,0.7158203125},{8,0.0009765625,0.7197265625,0.125,0.955078125},{8,0.126953125,0.7197265625,0.2509765625,0.955078125},{8,0.2529296875,0.7197265625,0.376953125,0.955078125},{8,0.37890625,0.7197265625,0.5029296875,0.955078125},{8,0.5048828125,0.7197265625,0.62890625,0.955078125},{8,0.630859375,0.7197265625,0.7548828125,0.955078125},{8,0.7568359375,0.7197265625,0.880859375,0.955078125}}}
table.remove(sealData.pages["576"])
table.insert(sealData.pages["576"], 8)
sealData.seal.idle.banks["576"] = {rect={0.049132947976878616,0.10404624277456648,0.930635838150289,0.9393063583815029},tiles={{8,0.0009765625,0.0009765625,0.14990234375,0.14208984375},{8,0.15185546875,0.0009765625,0.30078125,0.14208984375},{8,0.302734375,0.0009765625,0.45166015625,0.14208984375},{8,0.45361328125,0.0009765625,0.6025390625,0.14208984375},{8,0.6044921875,0.0009765625,0.75341796875,0.14208984375},{8,0.75537109375,0.0009765625,0.904296875,0.14208984375},{8,0.0009765625,0.14404296875,0.14990234375,0.28515625},{8,0.15185546875,0.14404296875,0.30078125,0.28515625},{8,0.302734375,0.14404296875,0.45166015625,0.28515625},{8,0.45361328125,0.14404296875,0.6025390625,0.28515625},{8,0.6044921875,0.14404296875,0.75341796875,0.28515625},{8,0.75537109375,0.14404296875,0.904296875,0.28515625},{8,0.0009765625,0.287109375,0.14990234375,0.42822265625},{8,0.15185546875,0.287109375,0.30078125,0.42822265625},{8,0.302734375,0.287109375,0.45166015625,0.42822265625},{8,0.45361328125,0.287109375,0.6025390625,0.42822265625},{8,0.6044921875,0.287109375,0.75341796875,0.42822265625},{8,0.75537109375,0.287109375,0.904296875,0.42822265625},{8,0.0009765625,0.43017578125,0.14990234375,0.5712890625},{8,0.15185546875,0.43017578125,0.30078125,0.5712890625},{8,0.302734375,0.43017578125,0.45166015625,0.5712890625},{8,0.45361328125,0.43017578125,0.6025390625,0.5712890625},{8,0.6044921875,0.43017578125,0.75341796875,0.5712890625},{8,0.75537109375,0.43017578125,0.904296875,0.5712890625},{8,0.0009765625,0.5732421875,0.14990234375,0.71435546875},{8,0.15185546875,0.5732421875,0.30078125,0.71435546875},{8,0.302734375,0.5732421875,0.45166015625,0.71435546875},{8,0.45361328125,0.5732421875,0.6025390625,0.71435546875},{8,0.6044921875,0.5732421875,0.75341796875,0.71435546875},{8,0.75537109375,0.5732421875,0.904296875,0.71435546875},{8,0.0009765625,0.71630859375,0.14990234375,0.857421875},{8,0.15185546875,0.71630859375,0.30078125,0.857421875}}}
table.remove(sealData.pages["768"])
table.insert(sealData.pages["768"], 16)
table.insert(sealData.pages["768"], 17)
table.insert(sealData.pages["768"], 18)
sealData.seal.idle.banks["768"] = {rect={0.049783549783549784,0.1038961038961039,0.9307359307359307,0.9393939393939394},tiles={{16,0.00390625,0.001953125,0.798828125,0.37890625},{16,0.00390625,0.3828125,0.798828125,0.759765625},{17,0.001953125,0.0009765625,0.3994140625,0.189453125},{17,0.4033203125,0.0009765625,0.80078125,0.189453125},{17,0.001953125,0.19140625,0.3994140625,0.3798828125},{17,0.4033203125,0.19140625,0.80078125,0.3798828125},{17,0.001953125,0.3818359375,0.3994140625,0.5703125},{17,0.4033203125,0.3818359375,0.80078125,0.5703125},{17,0.001953125,0.572265625,0.3994140625,0.7607421875},{17,0.4033203125,0.572265625,0.80078125,0.7607421875},{17,0.001953125,0.7626953125,0.3994140625,0.951171875},{17,0.4033203125,0.7626953125,0.80078125,0.951171875},{18,0.0009765625,0.0009765625,0.19970703125,0.189453125},{18,0.20166015625,0.0009765625,0.400390625,0.189453125},{18,0.40234375,0.0009765625,0.60107421875,0.189453125},{18,0.60302734375,0.0009765625,0.8017578125,0.189453125},{18,0.0009765625,0.19140625,0.19970703125,0.3798828125},{18,0.20166015625,0.19140625,0.400390625,0.3798828125},{18,0.40234375,0.19140625,0.60107421875,0.3798828125},{18,0.60302734375,0.19140625,0.8017578125,0.3798828125},{18,0.0009765625,0.3818359375,0.19970703125,0.5703125},{18,0.20166015625,0.3818359375,0.400390625,0.5703125},{18,0.40234375,0.3818359375,0.60107421875,0.5703125},{18,0.60302734375,0.3818359375,0.8017578125,0.5703125},{18,0.0009765625,0.572265625,0.19970703125,0.7607421875},{18,0.20166015625,0.572265625,0.400390625,0.7607421875},{18,0.40234375,0.572265625,0.60107421875,0.7607421875},{18,0.60302734375,0.572265625,0.8017578125,0.7607421875},{18,0.0009765625,0.7626953125,0.19970703125,0.951171875},{18,0.20166015625,0.7626953125,0.400390625,0.951171875},{18,0.40234375,0.7626953125,0.60107421875,0.951171875},{18,0.60302734375,0.7626953125,0.8017578125,0.951171875}}}
sealData.seal.tiles = nil
