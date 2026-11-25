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
local _, E = ...
local P={
{"StudioDruidRestorationSize192Page0.tga",2048,2048},
{"StudioDruidRestorationSize288Page0.tga",2048,2048},
{"StudioDruidRestorationSize384Page0.tga",2048,2048},
{"StudioDruidRestorationSize480Page0.tga",1024,2048},
{"StudioDruidRestorationSize576Page0.tga",512,512},
{"StudioDruidRestorationSize660Page0.tga",512,512},
{"StudioDruidRestorationSize192Page1.tga",1024,2048},
{"StudioDruidRestorationSize288Page1.tga",2048,2048},
{"StudioDruidRestorationSize384Page1.tga",2048,2048},
{"StudioDruidRestorationSize480Page1.tga",2048,2048},
{"StudioDruidRestorationSize576Page1.tga",2048,2048},
{"StudioDruidRestorationSize660Page1.tga",2048,512},
{"StudioDruidRestorationSize192Page2.tga",2048,2048},
{"StudioDruidRestorationSize288Page2.tga",1024,2048},
{"StudioDruidRestorationSize384Page2.tga",1024,2048},
{"StudioDruidRestorationSize480Page2.tga",2048,2048},
{"StudioDruidRestorationSize576Page2.tga",1024,2048},
{"StudioDruidRestorationSize660Page2.tga",512,2048},
{"StudioDruidRestorationSize192Page3.tga",2048,2048},
{"StudioDruidRestorationSize288Page3.tga",2048,2048},
{"StudioDruidRestorationSize384Page3.tga",512,128},
}
local precastLow={pixels=168,pages=P,bands={
{
{1,1600,155,157,150,3,2},
{1,1440,155,158,150,2,2},
{1,1,309,159,149,1,3},
{1,162,309,159,149,-1,3},
{1,487,309,160,148,-2,4},
{1,323,309,162,148,-2,4},
{1,649,309,162,147,-2,5},
{1,1142,309,162,146,-2,6},
{1,1306,309,162,146,-2,6},
{1,1470,309,162,146,-2,6},
{1,328,460,162,145,-2,7},
{1,1307,460,162,144,-2,8},
{1,156,608,163,142,-3,8},
{1,321,608,162,142,-2,6},
{1,1786,460,164,143,-4,5},
{1,976,460,164,144,-4,2},
{1,1142,460,163,144,-3,-2},
{1,163,460,163,145,-3,-5},
{1,977,309,163,146,-3,-6},
{1,813,309,162,147,-4,-7},
{1,1634,309,162,146,-4,-8},
{1,1798,309,162,146,-4,-8},
{1,492,460,161,145,-5,-7},
{1,1,460,160,146,-6,-8},
{1,655,460,159,145,-7,-9},
{1,816,460,158,145,-8,-9},
{1,1471,460,156,144,-10,-10},
{1,1629,460,155,144,-11,-12},
{1,1,608,153,143,-13,-13},
{1,485,608,152,141,-14,-13},
{1,639,608,152,139,-16,-15},
{1,1100,608,150,138,-18,-16},
{1,793,608,152,138,-16,-16},
{1,1252,608,150,138,-18,-16},
{1,619,753,151,137,-17,-15},
{1,1404,608,150,138,-16,-14},
{1,1860,608,149,138,-17,-14},
{1,1556,608,150,138,-16,-14},
{1,1708,608,150,138,-14,-14},
{1,772,753,150,137,-14,-13},
{1,157,753,152,137,-14,-13},
{1,311,753,152,137,-14,-13},
{1,465,753,152,137,-14,-13},
{1,1,753,154,137,-12,-13},
{1,947,608,151,138,-13,-14},
{1,1,1,153,152,-11,2},
{1,156,1,152,152,-10,2},
{1,310,1,152,152,-10,2},
{1,1759,155,151,150,-9,4},
{1,562,155,148,151,-10,5},
{1,712,155,146,151,-10,5},
{1,1206,1,144,152,-8,4},
{1,1644,1,142,152,-6,4},
{1,144,155,139,152,-3,4},
{1,424,155,136,152,2,6},
{1,285,155,137,152,5,6},
{1,1300,155,138,151,6,5},
{1,1,155,141,152,7,6},
{1,1788,1,142,152,8,6},
{1,1352,1,144,152,8,6},
{1,764,1,146,152,10,6},
{1,912,1,145,152,11,6},
{1,1059,1,145,152,13,6},
{1,860,155,145,151,13,7},
{1,1007,155,145,151,13,7},
{1,1154,155,144,151,14,7},
{1,1498,1,144,152,14,6},
{1,615,1,147,152,11,6},
{1,464,1,149,152,9,6},
{2,1167,156,152,151,8,7},
{2,1011,156,154,151,6,7},
{2,853,156,156,151,4,7},
{2,694,156,157,151,3,7},
{2,1,310,158,150,2,8},
{2,161,310,158,150,2,8},
{2,321,310,160,149,0,9},
{2,483,310,160,149,-2,9},
{2,1136,310,160,148,-2,10},
{2,645,310,162,148,-2,10},
{2,1298,310,162,147,-2,11},
{2,163,462,163,146,-1,10},
{2,328,462,162,146,-2,12},
{2,1142,462,162,145,-2,11},
{2,1788,462,162,144,-2,12},
{2,487,611,162,142,-2,12},
{2,159,611,162,143,0,11},
{2,323,611,162,143,0,9},
{2,1623,462,163,144,-1,6},
{2,977,462,163,145,-1,1},
{2,492,462,162,146,-2,-2},
{2,1462,310,162,147,-2,-3},
{2,809,310,162,148,-2,-4},
{2,1626,310,162,147,-2,-5},
{2,1790,310,162,147,-2,-5},
{2,973,310,161,148,-3,-6},
{2,1,462,160,147,-2,-7},
{2,656,462,159,146,-3,-8},
{2,817,462,158,146,-4,-8},
{2,1306,462,157,145,-5,-9},
{2,1465,462,156,145,-6,-11},
{2,1,611,156,144,-6,-12},
{2,651,611,156,142,-6,-14},
{2,809,611,155,140,-9,-14},
{2,966,611,155,140,-7,-16},
{2,1123,611,153,138,-9,-18},
{2,1278,611,154,137,-8,-19},
{2,1590,611,153,135,-9,-19},
{2,1,757,152,135,-10,-19},
{2,155,757,152,135,-10,-19},
{2,1745,611,153,135,-9,-19},
{2,1434,611,154,135,-10,-19},
{2,623,757,154,134,-8,-18},
{2,779,757,154,134,-8,-18},
{2,935,757,154,134,-8,-18},
{2,309,757,155,134,-7,-18},
{2,466,757,155,134,-7,-18},
{2,158,1,153,153,-7,-1},
{2,1,1,155,153,-5,-1},
{2,313,1,152,152,-6,-2},
{2,467,1,152,152,-4,0},
{2,621,1,150,152,-4,0},
{2,773,1,149,152,-5,2},
{2,1895,156,145,150,-7,2},
{2,1506,1,142,152,-6,2},
{2,1794,1,141,152,-3,2},
{2,1755,156,138,151,0,1},
{2,282,156,136,152,6,2},
{2,558,156,134,152,10,2},
{2,420,156,136,152,12,2},
{2,142,156,138,152,14,2},
{2,1,156,139,152,15,2},
{2,1612,156,141,151,15,1},
{2,1216,1,143,152,13,2},
{2,924,1,144,152,14,2},
{2,1321,156,144,151,14,1},
{2,1070,1,144,152,14,2},
{2,1650,1,142,152,16,2},
{2,1467,156,143,151,15,1},
{2,1361,1,143,152,15,2},
{3,1040,359,147,151,11,1},
{3,889,359,149,151,9,1},
{3,579,359,152,152,8,2},
{3,733,359,154,151,6,1},
{3,1333,359,155,150,5,2},
},
{
{1,1192,892,152,133,0,-15},
{1,445,1163,153,132,-1,-14},
{1,130,1163,156,132,-2,-14},
{1,1632,1163,156,131,-2,-13},
{1,1472,1163,158,131,-2,-13},
{1,1790,1163,157,130,-3,-12},
{1,1,1298,157,130,-3,-12},
{1,160,1298,157,130,-5,-12},
{1,319,1298,156,130,-6,-10},
{1,800,1430,156,120,-6,0},
{1,1431,1298,158,120,-6,0},
{1,958,1430,156,120,-4,0},
{1,1591,1298,158,120,-4,0},
{1,1751,1298,158,120,-4,0},
{1,1,1430,158,120,-4,0},
{1,161,1430,158,120,-4,0},
{1,321,1430,158,120,-4,0},
{1,1270,1298,159,120,-5,0},
{1,641,1430,157,120,-5,0},
{1,481,1430,158,120,-6,0},
{1,1110,1298,158,121,-4,-1},
{1,951,1298,157,122,-5,-2},
{1,792,1298,157,124,-5,-2},
{1,634,1298,156,127,-6,-5},
{1,477,1298,155,130,-7,-8},
{1,288,1163,155,132,-7,-10},
{1,1036,892,154,133,-8,-11},
{1,1346,892,151,133,-9,-11},
{1,1499,892,151,133,-11,-11},
{1,600,1163,149,132,-13,-10},
{1,751,1163,147,132,-15,-10},
{1,900,1163,147,132,-17,-10},
{1,1652,892,147,133,-15,-11},
{1,1801,892,147,133,-15,-11},
{1,150,1028,146,133,-16,-11},
{1,1057,753,146,134,-16,-10},
{1,1352,753,144,134,-16,-10},
{1,1205,753,145,134,-15,-10},
{1,298,1028,145,133,-15,-9},
{1,445,1028,145,133,-15,-9},
{1,592,1028,145,133,-15,-9},
{1,886,1028,144,133,-14,-9},
{1,1177,1028,142,133,-14,-9},
{1,1049,1163,142,132,-14,-8},
{1,1321,1028,140,133,-14,-9},
{1,1767,753,131,134,-1,-10},
{1,1,892,129,134,-1,-10},
{1,653,892,126,134,-2,-10},
{1,924,753,131,135,5,-11},
{1,1912,155,133,135,3,-11},
{1,1498,753,133,134,3,-10},
{1,1633,753,132,134,4,-10},
{1,1900,753,131,134,5,-10},
{1,132,892,129,134,5,-10},
{1,394,892,128,134,4,-10},
{1,1,1163,127,133,3,-11},
{1,524,892,127,134,3,-10},
{1,781,892,126,134,2,-10},
{1,909,892,125,134,1,-10},
{1,263,892,129,134,5,-10},
{1,1875,1028,130,133,6,-11},
{1,1741,1028,132,133,6,-11},
{1,1336,1163,134,132,6,-10},
{1,1603,1028,136,133,8,-11},
{1,1463,1028,138,133,8,-11},
{1,1193,1163,141,132,9,-10},
{1,1032,1028,143,133,9,-11},
{1,739,1028,145,133,7,-11},
{1,1,1028,147,133,5,-11},
{2,305,1029,149,131,3,-11},
{2,1843,894,151,131,1,-11},
{2,123,894,153,132,1,-10},
{2,313,1162,153,130,1,-10},
{2,1,1162,154,130,0,-10},
{2,1803,1029,155,130,-1,-10},
{2,1645,1029,156,130,-2,-10},
{2,1486,1029,157,130,-1,-10},
{2,143,1294,157,128,-1,-8},
{2,302,1294,157,128,-3,-8},
{2,461,1294,157,128,-3,-8},
{2,778,1294,155,128,-3,-8},
{2,1572,1294,156,120,-4,0},
{2,1730,1294,156,120,-4,0},
{2,1254,1294,157,120,-3,0},
{2,1888,1294,158,119,-2,1},
{2,160,1425,158,118,-2,0},
{2,1120,1425,157,118,-1,0},
{2,320,1425,158,118,-2,0},
{2,480,1425,158,118,-2,0},
{2,640,1425,158,118,-2,0},
{2,800,1425,158,118,-2,0},
{2,960,1425,158,118,-2,0},
{2,1,1425,157,119,-1,-1},
{2,1413,1294,157,120,-1,-2},
{2,1094,1294,158,122,-2,-4},
{2,935,1294,157,125,-1,-7},
{2,620,1294,156,128,-2,-10},
{2,1817,1162,155,129,-3,-13},
{2,157,1162,154,130,-4,-14},
{2,468,1162,153,130,-5,-14},
{2,623,1162,152,130,-6,-14},
{2,930,1162,150,130,-8,-14},
{2,1082,1162,149,130,-9,-14},
{2,777,1162,151,130,-7,-14},
{2,1,1029,150,131,-8,-15},
{2,153,1029,150,131,-8,-15},
{2,456,1029,149,131,-9,-15},
{2,607,1029,148,131,-10,-15},
{2,1056,1029,146,131,-10,-15},
{2,757,1029,148,131,-8,-15},
{2,907,1029,147,131,-9,-15},
{2,1204,1029,146,131,-8,-15},
{2,1233,1162,145,130,-9,-14},
{2,1672,1162,143,130,-9,-14},
{2,1380,1162,144,130,-8,-14},
{2,1,1294,140,129,-10,-13},
{2,1526,1162,144,130,-6,-14},
{2,1352,1029,132,131,6,-15},
{2,412,894,131,132,7,-16},
{2,278,894,132,132,10,-16},
{2,545,894,131,132,11,-16},
{2,678,894,130,132,10,-16},
{2,810,894,129,132,9,-16},
{2,1072,894,128,132,8,-16},
{2,1332,894,127,132,7,-16},
{2,1590,894,126,132,6,-16},
{2,1768,757,124,133,4,-17},
{2,1718,894,123,132,3,-16},
{2,1894,757,121,133,1,-17},
{2,1,894,120,133,0,-17},
{2,1640,757,126,133,6,-17},
{2,1461,894,127,132,9,-16},
{2,1510,757,128,133,10,-17},
{2,1202,894,128,132,10,-16},
{2,941,894,129,132,11,-16},
{2,1374,757,134,133,10,-17},
{2,1236,757,136,133,12,-17},
{2,1900,611,137,134,13,-16},
{2,1091,757,143,133,9,-15},
{3,300,663,144,133,8,-15},
{3,1298,518,146,134,6,-16},
{3,151,663,147,133,3,-15},
{3,1873,518,149,133,1,-15},
{3,1719,518,152,133,0,-15},
},
{
{1,958,1770,93,102,3,16},
{1,1053,1770,93,102,3,16},
{1,1148,1770,93,102,3,16},
{1,670,1770,94,102,4,16},
{1,191,1770,94,103,4,15},
{1,766,1770,94,102,4,16},
{1,862,1770,94,102,4,16},
{1,287,1770,94,103,4,15},
{1,1265,1662,94,104,4,16},
{1,383,1770,94,103,4,17},
{1,479,1770,94,103,4,17},
{1,1361,1662,94,104,4,16},
{1,1457,1662,94,104,4,16},
{1,1553,1662,94,104,4,16},
{1,1649,1662,94,104,4,16},
{1,867,1662,98,104,0,16},
{1,967,1662,98,104,0,16},
{1,1067,1662,97,104,-1,16},
{1,1166,1662,97,104,-1,16},
{1,481,1662,96,105,0,15},
{1,579,1662,95,105,1,15},
{1,676,1662,94,105,2,15},
{1,1247,1552,94,106,2,16},
{1,1053,1552,95,106,3,16},
{1,1150,1552,95,106,3,16},
{1,1343,1552,94,106,2,16},
{1,1439,1552,94,106,2,16},
{1,1535,1552,94,106,2,16},
{1,1631,1552,94,106,2,16},
{1,1727,1552,94,106,2,16},
{1,1823,1552,94,106,2,16},
{1,1919,1552,94,106,2,16},
{1,1,1662,94,106,2,16},
{1,97,1662,94,106,2,16},
{1,193,1662,94,106,2,16},
{1,1116,1430,94,109,4,15},
{1,1952,460,94,110,4,14},
{1,1950,892,94,110,4,14},
{1,1949,1163,93,110,3,14},
{1,1932,1,93,110,3,14},
{1,1212,1430,93,109,1,15},
{1,1782,1430,92,109,2,15},
{1,1307,1430,93,109,1,15},
{1,1402,1430,93,109,1,15},
{1,1911,1298,93,110,1,14},
{1,1497,1430,93,109,1,15},
{1,1592,1430,93,109,1,15},
{1,1687,1430,93,109,1,15},
{1,98,1552,93,108,1,16},
{1,193,1552,93,108,1,16},
{1,288,1552,93,108,1,16},
{1,673,1552,93,107,1,17},
{1,768,1552,93,107,1,17},
{1,863,1552,93,107,1,17},
{1,958,1552,93,107,1,17},
{1,289,1662,94,106,2,16},
{1,577,1552,94,107,2,17},
{1,383,1552,95,107,3,17},
{1,1876,1430,95,108,3,16},
{1,1,1552,95,108,3,16},
{1,480,1552,95,107,3,15},
{1,385,1662,94,106,2,16},
{1,772,1662,93,105,1,17},
{1,1745,1662,93,104,1,18},
{1,1840,1662,93,104,1,18},
{1,1935,1662,93,104,1,18},
{1,1,1770,93,104,1,18},
{1,96,1770,93,104,1,18},
{1,575,1770,93,103,1,19},
{2,868,1653,93,102,1,18},
{2,963,1653,93,102,1,18},
{2,1058,1653,93,102,1,18},
{2,96,1653,94,103,2,17},
{2,676,1653,94,102,2,18},
{2,772,1653,94,102,2,18},
{2,288,1653,95,102,3,18},
{2,385,1653,95,102,3,18},
{2,1153,1653,95,101,3,19},
{2,482,1653,95,102,3,18},
{2,1250,1653,95,101,3,19},
{2,1347,1653,95,101,3,19},
{2,1444,1653,95,101,3,19},
{2,1541,1653,95,101,3,19},
{2,1638,1653,95,101,3,19},
{2,1735,1653,95,101,3,19},
{2,99,1759,95,100,3,18},
{2,196,1759,95,100,3,18},
{2,1832,1653,96,100,4,18},
{2,293,1759,95,100,3,18},
{2,1930,1653,96,100,4,18},
{2,883,1759,96,99,4,19},
{2,1,1759,96,100,4,18},
{2,981,1759,96,99,4,19},
{2,487,1759,97,99,3,19},
{2,586,1759,97,99,3,19},
{2,685,1759,97,99,3,19},
{2,784,1759,97,99,3,19},
{2,1177,1759,97,98,3,18},
{2,1276,1759,97,98,3,18},
{2,1375,1759,97,98,3,18},
{2,1474,1759,97,98,3,18},
{2,1573,1759,97,98,3,18},
{2,1672,1759,96,98,4,18},
{2,1770,1759,96,98,4,18},
{2,1079,1759,96,99,4,17},
{2,390,1759,95,100,3,16},
{2,579,1653,95,102,3,14},
{2,1484,1546,95,104,3,12},
{2,207,1546,95,105,3,11},
{2,497,1546,93,105,3,11},
{2,592,1546,93,105,3,11},
{2,687,1546,93,105,3,11},
{2,782,1546,93,105,3,11},
{2,1954,310,93,106,3,10},
{2,877,1546,93,105,3,11},
{2,1774,1425,94,106,4,10},
{2,1375,1425,99,106,-1,10},
{2,1577,1425,98,106,-2,10},
{2,1476,1425,99,106,-3,10},
{2,1,1546,101,105,-3,11},
{2,104,1546,101,105,-1,11},
{2,1076,1546,101,104,-1,12},
{2,972,1546,102,104,0,12},
{2,1179,1546,101,104,1,12},
{2,1282,1546,100,104,2,12},
{2,1384,1546,98,104,2,12},
{2,1581,1546,94,104,2,12},
{2,1773,1546,93,104,3,12},
{2,304,1546,95,105,5,11},
{2,1677,1425,95,106,5,10},
{2,1952,462,95,107,5,9},
{2,1937,1,95,107,5,9},
{2,1279,1425,94,107,4,9},
{2,1870,1425,94,106,4,10},
{2,401,1546,94,105,4,11},
{2,1677,1546,94,104,4,12},
{2,192,1653,94,103,4,13},
{2,1868,1546,93,104,3,14},
{2,1,1653,93,104,3,14},
{3,1,1606,93,104,3,14},
{3,563,1606,93,103,3,15},
{3,980,1606,93,102,3,16},
{3,1075,1606,93,102,3,16},
{3,1170,1606,93,102,3,16},
},
{
{1,296,1962,56,83,8,25},
{1,354,1962,56,83,8,25},
{1,412,1962,56,83,8,25},
{1,470,1962,56,83,8,25},
{1,528,1962,56,83,8,25},
{1,1605,1876,56,84,8,26},
{1,1663,1876,56,84,8,26},
{1,586,1962,56,83,8,27},
{1,644,1962,56,83,8,27},
{1,1837,1876,57,83,7,27},
{1,702,1962,56,83,8,27},
{1,760,1962,56,83,8,27},
{1,818,1962,56,83,8,27},
{1,876,1962,56,83,8,27},
{1,934,1962,56,83,8,27},
{1,1896,1876,57,83,7,27},
{1,1955,1876,57,83,7,27},
{1,1,1962,57,83,7,27},
{1,60,1962,57,83,7,27},
{1,119,1962,57,83,7,27},
{1,178,1962,57,83,7,27},
{1,661,1876,57,84,7,28},
{1,720,1876,57,84,7,28},
{1,779,1876,57,84,7,28},
{1,1721,1876,56,84,6,28},
{1,1779,1876,56,84,6,28},
{1,992,1962,56,83,6,29},
{1,1050,1962,56,83,6,29},
{1,1108,1962,56,83,6,29},
{1,838,1876,57,84,5,30},
{1,897,1876,57,84,5,30},
{1,956,1876,57,84,5,30},
{1,1015,1876,57,84,5,30},
{1,1074,1876,57,84,5,30},
{1,1133,1876,57,84,5,30},
{1,1192,1876,57,84,5,30},
{1,1251,1876,57,84,5,30},
{1,1310,1876,57,84,5,30},
{1,1369,1876,57,84,5,30},
{1,1428,1876,57,84,5,30},
{1,237,1962,57,83,5,31},
{1,1487,1876,57,84,5,32},
{1,1546,1876,57,84,5,32},
{1,1967,1770,58,84,4,32},
{1,1723,1770,59,84,3,32},
{1,1,1876,58,84,4,32},
{1,61,1876,58,84,4,32},
{1,121,1876,58,84,4,32},
{1,1243,1770,58,85,4,33},
{1,1303,1770,58,85,4,33},
{1,1973,1430,59,85,5,33},
{1,181,1876,58,84,4,32},
{1,1363,1770,58,85,4,33},
{1,1962,309,59,85,5,33},
{1,1423,1770,58,85,4,33},
{1,241,1876,58,84,4,32},
{1,1483,1770,58,85,4,33},
{1,1543,1770,58,85,4,33},
{1,1603,1770,58,85,4,33},
{1,1663,1770,58,85,4,33},
{1,301,1876,58,84,4,32},
{1,361,1876,58,84,4,32},
{1,421,1876,58,84,4,32},
{1,481,1876,58,84,4,32},
{1,541,1876,58,84,4,32},
{1,601,1876,58,84,4,32},
{1,1784,1770,59,84,5,32},
{1,1845,1770,59,84,5,32},
{1,1906,1770,59,84,5,32},
{2,1966,1425,59,84,5,32},
{2,1974,1162,60,84,4,32},
{2,1963,1546,59,84,5,32},
{2,1960,1029,59,84,5,32},
{2,1868,1759,59,83,5,31},
{2,1929,1759,59,83,5,31},
{2,1,1861,58,83,6,31},
{2,61,1861,58,83,6,31},
{2,121,1861,58,83,6,31},
{2,181,1861,58,83,6,31},
{2,241,1861,58,83,6,31},
{2,301,1861,58,83,6,31},
{2,361,1861,58,83,6,31},
{2,421,1861,58,83,6,31},
{2,481,1861,58,83,6,31},
{2,541,1861,58,83,6,31},
{2,601,1861,58,83,6,31},
{2,661,1861,58,83,6,31},
{2,721,1861,58,83,6,31},
{2,781,1861,58,83,6,31},
{2,457,1946,58,82,6,30},
{2,517,1946,57,82,7,30},
{2,1990,1759,57,83,7,29},
{2,841,1861,57,83,7,29},
{2,900,1861,57,83,7,29},
{2,959,1861,57,83,7,29},
{2,1018,1861,57,83,7,29},
{2,1077,1861,57,83,7,29},
{2,576,1946,57,82,7,28},
{2,635,1946,57,82,7,28},
{2,694,1946,57,82,7,28},
{2,753,1946,57,82,7,28},
{2,812,1946,57,82,7,28},
{2,871,1946,57,82,7,28},
{2,1343,1946,56,82,8,28},
{2,1401,1946,56,82,8,28},
{2,1459,1946,56,82,8,28},
{2,1136,1861,57,83,9,27},
{2,1549,1861,56,83,8,27},
{2,1195,1861,57,83,9,27},
{2,1254,1861,57,83,9,27},
{2,1313,1861,57,83,9,27},
{2,1372,1861,57,83,9,27},
{2,1431,1861,57,83,9,27},
{2,1607,1861,56,83,8,27},
{2,1665,1861,56,83,8,27},
{2,1490,1861,57,83,9,27},
{2,930,1946,57,82,9,26},
{2,989,1946,57,82,9,26},
{2,1048,1946,57,82,9,26},
{2,1107,1946,57,82,9,26},
{2,1166,1946,57,82,9,26},
{2,1225,1946,57,82,9,26},
{2,1284,1946,57,82,9,26},
{2,1517,1946,56,82,10,26},
{2,1723,1861,56,83,10,25},
{2,1781,1861,56,83,10,25},
{2,1839,1861,56,83,10,25},
{2,1897,1861,56,83,10,25},
{2,1955,1861,56,83,10,25},
{2,1,1946,55,83,9,25},
{2,58,1946,55,83,9,25},
{2,115,1946,55,83,9,25},
{2,1575,1946,55,82,9,24},
{2,1632,1946,55,82,9,24},
{2,172,1946,55,83,9,25},
{2,229,1946,55,83,9,25},
{2,286,1946,55,83,9,25},
{2,343,1946,55,83,9,25},
{2,400,1946,55,83,9,25},
{3,1978,1042,55,83,9,25},
{3,1972,1712,55,83,9,25},
{3,1990,1606,56,83,8,25},
{3,1989,192,56,83,8,25},
{3,1984,1388,56,83,8,25},
},
}}
local impact1Low={pixels=202,pages=P,tiles={
{3,2045,1,2,2,0,0},
{3,2021,1,22,11,12,-7},
{3,1998,1498,35,51,17,25},
{3,1951,1812,74,62,-22,16},
{3,1967,663,78,72,-18,6},
{3,1523,1812,90,85,-6,-3},
{3,1941,922,104,104,2,-6},
{3,1926,359,115,115,1,-5},
{3,1714,663,126,125,2,-5},
{3,1148,663,129,129,1,-5},
{3,581,663,132,132,2,-4},
{3,1583,518,134,134,2,-4},
{3,738,518,136,136,2,-4},
{3,876,518,135,136,3,-4},
{3,1013,518,135,136,3,-4},
{3,1446,518,135,134,3,-4},
{3,446,663,133,132,3,-4},
{3,1017,663,129,130,3,-4},
{3,1431,663,127,127,3,-3},
{3,1842,663,123,123,3,-3},
{3,591,798,123,120,1,-4},
{3,1,1042,122,116,-2,-4},
{3,1319,1160,123,112,-7,-4},
{3,1350,1275,124,110,-12,-4},
{3,1921,1275,126,106,-16,-4},
{3,1869,1498,127,104,-21,-4},
{3,1571,1606,132,100,-20,-4},
{3,1853,1606,135,99,-17,-5},
{3,925,1712,139,97,-15,-5},
{3,1686,1712,142,95,-12,-5},
{3,458,1812,144,93,-10,-5},
{3,604,1812,145,92,-9,-6},
{3,1064,1812,145,91,-7,-5},
{3,751,1812,145,92,-7,-6},
{3,167,1812,146,94,-6,-8},
{3,1381,1712,146,96,-4,-8},
{3,777,1712,146,97,-4,-9},
{3,322,1712,147,98,-3,-8},
{3,471,1712,146,98,-2,-8},
{3,1705,1606,146,99,-2,-7},
{3,1423,1606,146,100,0,-8},
{3,415,1606,146,103,0,-9},
{3,1404,1498,145,105,1,-11},
{3,469,1498,144,106,2,-12},
{3,459,1388,144,108,2,-12},
{3,605,1388,143,108,1,-12},
{3,1775,1275,144,109,0,-11},
{3,1204,1275,144,110,0,-12},
{3,299,1275,144,111,0,-11},
{3,445,1275,143,111,-1,-11},
{3,452,1160,143,112,-1,-10},
{3,597,1160,143,112,-1,-10},
{3,1,1160,142,113,-2,-11},
{3,887,1160,142,112,-2,-10},
{3,1031,1160,142,112,-2,-10},
{3,1175,1160,142,112,-4,-10},
{3,742,1160,143,112,-5,-10},
{3,590,1275,143,111,-5,-9},
{3,1902,1160,145,111,-5,-9},
{3,1753,1160,147,111,-5,-7},
{3,1,1275,147,111,-5,-7},
{3,1603,1160,148,111,-4,-5},
{3,1054,1275,148,110,-4,-4},
{3,1476,1275,148,109,-4,-3},
{3,161,1388,148,108,-4,-2},
{3,1224,1388,148,107,-4,-1},
{3,1374,1388,148,107,-4,-1},
{3,1524,1388,147,107,-5,1},
{3,320,1498,147,106,-5,2},
{3,1255,1498,147,105,-5,3},
{3,1673,1388,147,107,-5,3},
{3,311,1388,146,108,-4,2},
{3,1626,1275,147,109,-3,1},
{3,150,1275,147,111,-3,1},
{3,304,1160,146,112,-2,0},
{3,1830,1042,146,113,-2,-1},
{3,1366,1042,146,114,-2,-2},
{3,1218,1042,146,115,-2,-1},
{3,1645,922,146,116,-2,-2},
{3,1793,922,146,116,-2,-2},
{3,588,922,146,117,-2,-3},
{3,1892,798,146,118,-2,-2},
{3,1,922,146,118,-2,-2},
{3,872,798,146,119,-2,-1},
{3,1020,798,145,119,-1,-1},
{3,1167,798,144,119,-2,1},
{3,1313,798,144,119,-2,1},
{3,155,798,144,120,-2,2},
{3,301,798,144,120,-2,4},
{3,1459,798,143,119,-1,5},
{3,447,798,142,120,-2,6},
{3,1604,798,142,119,-2,7},
{3,1748,798,142,119,-2,9},
{3,294,922,142,118,0,10},
{3,149,922,143,118,1,12},
{3,884,922,145,117,1,13},
{3,736,922,146,117,2,13},
{3,438,922,148,117,2,13},
{3,1494,922,149,116,3,12},
{3,1342,922,150,116,2,12},
{3,1189,922,151,116,3,12},
{3,1064,1042,152,115,4,13},
{3,754,1042,153,115,3,13},
{3,909,1042,153,115,3,13},
{3,598,1042,154,115,4,15},
{3,441,1042,155,115,3,15},
{3,125,1042,156,115,4,15},
{3,283,1042,156,115,4,15},
{3,1514,1042,156,113,4,17},
{3,145,1160,157,112,5,18},
{3,1444,1160,157,111,5,19},
{3,895,1275,157,110,5,20},
{3,1,1388,158,108,6,22},
{3,750,1388,158,107,6,23},
{3,615,1498,158,105,6,25},
{3,96,1606,158,103,6,27},
{3,1265,1606,156,101,8,29},
{3,822,1606,156,102,8,30},
{3,256,1606,157,103,7,29},
{3,1551,1498,157,104,7,30},
{3,1710,1498,157,104,7,30},
{3,775,1498,158,105,6,31},
{3,935,1498,158,105,6,31},
{3,1095,1498,158,105,6,31},
{3,1,1498,158,106,6,32},
{3,161,1498,157,106,7,32},
{3,910,1388,155,107,9,33},
{3,1067,1388,155,107,9,33},
{3,165,1712,155,98,9,24},
{3,619,1712,156,97,8,23},
{3,1066,1712,156,96,8,22},
{3,1224,1712,155,96,7,22},
{3,1529,1712,155,95,7,21},
{3,1830,1712,140,95,-8,21},
{3,315,1812,141,94,-9,20},
{3,1211,1812,142,91,-10,17},
{3,1,1908,142,75,-10,1},
{3,145,1908,118,75,-36,1},
{3,601,1908,117,70,-37,-4},
{3,1216,1908,58,56,22,-18},
{3,1276,1908,57,56,23,-16},
{3,1995,1,24,40,-8,-32},
{3,2024,518,22,36,-10,-34},
{3,2045,1042,2,2,0,0},
}}
local impact2Low={pixels=202,pages=P,tiles={
{3,2045,1712,2,2,0,0},
{3,2035,1042,8,7,0,-149},
{3,2029,1712,14,7,0,-149},
{3,661,1985,30,10,0,-148},
{3,615,1985,44,11,0,-149},
{3,1977,1908,66,14,0,-150},
{3,527,1985,86,17,0,-149},
{3,421,1985,104,20,0,-148},
{3,295,1985,124,24,0,-148},
{3,155,1985,138,28,0,-146},
{3,1,1985,152,33,0,-143},
{3,1821,1908,154,37,0,-141},
{3,1661,1908,158,41,0,-139},
{3,1499,1908,160,46,0,-136},
{3,1335,1908,162,51,0,-133},
{3,1052,1908,162,56,0,-130},
{3,886,1908,164,60,0,-126},
{3,720,1908,164,65,0,-123},
{3,433,1908,166,70,0,-118},
{3,265,1908,166,74,0,-114},
{3,1783,1812,166,78,0,-110},
{3,1615,1812,166,82,0,-106},
{3,1355,1812,166,87,0,-101},
{3,898,1812,164,91,0,-97},
{3,1,1812,164,94,0,-92},
{3,1,1712,162,98,0,-88},
{3,658,1606,162,102,0,-84},
{3,1822,1388,160,106,0,-80},
{3,735,1275,158,110,0,-76},
{3,1672,1042,156,113,0,-73},
{3,1031,922,156,116,0,-68},
{3,716,798,154,119,0,-65},
{3,1,798,152,122,0,-62},
{3,1560,663,152,125,0,-59},
{3,1279,663,150,128,0,-56},
{3,865,663,150,130,0,-54},
{3,715,663,148,131,0,-51},
{3,1,663,148,133,0,-49},
{3,1150,518,146,135,0,-47},
{3,590,518,146,136,0,-46},
{3,442,518,146,137,0,-45},
{3,294,518,146,138,0,-44},
{3,147,518,145,140,1,-42},
{3,1,518,144,143,0,-39},
{3,1780,359,144,147,0,-35},
{3,1490,359,144,150,0,-32},
{3,433,359,144,153,0,-29},
{3,143,359,144,156,0,-26},
{3,1559,192,144,159,0,-23},
{3,287,192,142,162,0,-20},
{3,1,192,142,165,0,-17},
{3,1709,1,142,168,0,-14},
{3,1423,1,142,170,0,-12},
{3,1137,1,142,172,0,-10},
{3,1636,359,142,150,0,-32},
{3,1189,359,142,151,0,-29},
{3,289,359,142,154,0,-26},
{3,1,359,140,157,0,-23},
{3,1133,192,140,160,0,-20},
{3,431,192,140,162,0,-18},
{3,145,192,140,165,0,-15},
{3,1853,1,140,167,0,-13},
{3,1567,1,140,170,0,-10},
{3,1281,1,140,172,0,-8},
{3,995,1,140,174,0,-6},
{3,853,1,140,177,0,-3},
{3,711,1,140,179,0,-1},
{3,569,1,140,181,0,1},
{3,427,1,140,183,0,3},
{3,285,1,140,185,0,5},
{3,143,1,140,187,0,7},
{3,1,1,140,189,0,9},
{3,1847,192,140,158,0,-22},
{3,1705,192,140,159,0,-21},
{3,1275,192,140,160,0,-20},
{3,1417,192,140,160,0,-20},
{3,851,192,140,161,0,-19},
{3,993,192,138,161,0,-19},
{3,573,192,138,162,0,-18},
{3,713,192,136,162,0,-18},
{4,1,855,136,163,0,-17},
{4,139,855,134,163,0,-17},
{4,1,523,132,164,0,-16},
{4,135,523,130,164,0,-16},
{4,363,355,128,165,0,-15},
{4,737,184,126,166,2,-14},
{4,126,184,126,167,4,-13},
{4,1,184,123,169,5,-11},
{4,842,1,122,170,8,-8},
{4,718,1,122,171,10,-7},
{4,596,1,120,173,12,-5},
{4,476,1,118,174,14,-2},
{4,358,1,116,176,16,0},
{4,241,1,115,177,17,3},
{4,122,1,117,180,15,6},
{4,1,1,119,181,13,9},
{4,376,184,119,167,11,-5},
{4,254,184,120,167,10,-3},
{4,618,184,117,167,3,-3},
{4,243,355,118,166,2,-2},
{4,497,184,119,167,1,-1},
{4,865,184,119,166,1,0},
{4,1,355,119,166,-1,2},
{4,122,355,119,166,-1,2},
{4,493,355,120,165,-2,3},
{4,267,523,119,164,-3,4},
{4,615,355,119,165,-3,5},
{4,388,523,118,164,-2,6},
{4,508,523,117,164,-3,6},
{4,627,523,116,164,-2,6},
{4,745,523,114,164,-2,6},
{4,736,355,113,165,-1,7},
{4,229,689,111,164,-1,8},
{4,342,689,111,164,-3,8},
{4,861,523,112,164,-4,8},
{4,1,689,112,164,-6,8},
{4,115,689,112,164,-8,8},
{4,455,689,111,164,-9,8},
{4,568,689,111,164,-11,8},
{4,681,689,111,164,-13,8},
{4,794,689,110,164,-14,8},
{4,489,855,110,161,-16,11},
{4,382,855,105,162,-21,12},
{4,275,855,105,163,-21,15},
{4,906,689,107,164,-21,16},
{4,851,355,109,165,-19,19},
{4,1,1020,110,103,-18,83},
{4,832,855,111,104,-17,86},
{4,717,855,113,104,-15,88},
{4,601,855,114,104,-14,90},
{4,475,1020,115,93,-13,79},
{4,356,1020,117,94,-11,82},
{4,712,1020,118,91,-10,81},
{4,592,1020,118,92,-8,84},
{4,235,1020,119,95,-7,87},
{4,113,1020,120,96,-6,90},
{4,1,1125,121,83,-5,107},
{4,493,1125,120,73,-4,99},
{4,698,1125,114,71,4,101},
{4,814,1125,113,70,5,102},
{4,444,1210,113,60,7,94},
{4,130,1950,103,34,17,122},
{4,1008,523,15,28,105,120},
{4,1021,1612,2,2,0,0},
}}
local ccIntroLow={pixels=160,pages=P,tiles={
{4,1022,1020,1,1,1,-1},
{4,956,2007,21,10,-5,0},
{4,834,1950,42,18,-8,0},
{4,663,1950,74,25,-14,1},
{4,59,1908,108,39,-20,-1},
{4,81,1210,114,64,-22,-8},
{4,364,1125,127,79,-23,-7},
{4,229,1125,133,81,-25,3},
{4,832,1020,124,86,-24,0},
{4,124,1125,103,82,-19,4},
{4,615,1125,81,73,-11,11},
{4,945,855,78,69,-10,13},
{4,1,1210,78,65,-10,9},
{4,559,1210,78,60,-10,4},
{4,575,1277,77,55,-11,1},
{4,451,1393,78,53,-10,1},
{4,725,1449,78,52,-10,0},
{4,1,1612,73,51,-5,1},
}}
local ccFlowLow={pixels=160,pages=P,bands={
{
{4,961,1558,62,51,0,1},
{4,960,1449,63,52,-1,0},
{4,756,1393,64,53,0,1},
{4,822,1393,64,53,0,1},
{4,554,1336,65,54,-1,0},
{4,486,1336,66,54,0,0},
{4,941,1277,66,55,0,1},
{4,1,1336,66,55,0,1},
{4,69,1336,66,55,0,1},
{4,137,1336,66,55,0,1},
{4,205,1336,66,55,0,1},
{4,621,1336,65,54,-1,0},
{4,688,1336,65,54,-1,0},
{4,68,1393,64,54,0,0},
{4,888,1393,64,53,0,1},
{4,397,1449,63,53,-1,1},
{4,604,1504,62,52,0,0},
{4,668,1504,62,52,0,0},
{4,732,1504,62,52,0,0},
{4,796,1504,62,52,0,0},
{4,860,1504,62,52,0,0},
{4,924,1504,62,52,0,0},
{4,1,1558,62,52,0,0},
{4,462,1449,63,53,-1,1},
{4,954,1393,64,53,0,1},
{4,1,1449,64,53,0,1},
{4,67,1449,64,53,0,1},
{4,133,1449,64,53,0,1},
{4,199,1449,64,53,0,1},
{4,134,1393,64,54,0,0},
{4,265,1449,64,53,0,1},
{4,331,1449,64,53,0,1},
{4,65,1558,62,52,0,0},
{4,129,1558,62,52,0,0},
{4,366,1612,62,51,0,1},
{4,316,1665,60,50,0,0},
{4,378,1665,60,50,0,0},
{4,131,1717,58,49,0,1},
{4,585,1717,58,48,0,0},
{4,645,1717,58,48,0,0},
{4,130,1768,56,47,0,1},
{4,188,1768,56,47,0,1},
{4,884,1717,56,48,0,0},
{4,942,1717,56,48,0,0},
{4,246,1768,56,47,0,1},
{4,304,1768,56,47,0,1},
{4,825,1717,57,48,-1,0},
{4,705,1717,58,48,0,0},
{4,765,1717,58,48,0,0},
{4,564,1665,59,50,-1,0},
{4,440,1665,60,50,0,0},
{4,502,1665,60,50,0,0},
{4,716,1612,61,50,-1,0},
{4,193,1558,62,52,0,0},
{4,257,1558,62,52,0,0},
{4,321,1558,62,52,0,0},
{4,385,1558,62,52,0,0},
{4,449,1558,62,52,0,0},
{4,513,1558,62,52,0,0},
{4,577,1558,62,52,0,0},
{4,641,1558,62,52,0,0},
{4,430,1612,61,51,-1,1},
{4,779,1612,61,50,-1,0},
{4,842,1612,61,50,-1,0},
{4,905,1612,61,50,-1,0},
{4,1,1665,61,50,-1,0},
{4,64,1665,61,50,-1,0},
{4,705,1558,62,52,0,0},
{4,214,1504,63,52,-1,0},
{4,279,1504,63,52,-1,0},
{4,344,1504,63,52,-1,0},
{4,755,1336,65,54,-1,0},
{4,822,1336,65,54,-1,0},
{4,889,1336,65,54,-1,0},
{4,348,1336,67,54,-1,0},
{4,955,1210,67,56,-1,0},
{4,299,1277,67,56,-1,0},
{4,368,1277,67,56,-1,0},
{4,437,1277,67,56,-1,0},
{4,506,1277,67,56,-1,0},
{4,872,1277,67,55,-1,1},
{4,417,1336,67,54,-1,0},
{4,956,1336,65,54,-1,0},
{4,1,1393,65,54,-1,0},
{4,409,1504,63,52,-1,0},
{4,474,1504,63,52,-1,0},
{4,539,1504,63,52,-1,0},
{4,127,1665,61,50,-1,0},
{4,190,1665,61,50,-1,0},
{4,253,1665,61,50,-1,0},
{4,625,1665,59,50,-1,0},
{4,524,1717,59,48,-1,0},
{5,451,297,59,48,-1,0},
{5,1,349,59,48,-1,0},
{5,207,297,59,49,-1,1},
{5,378,245,59,50,-1,0},
{5,439,245,59,50,-1,0},
{5,139,191,61,50,-1,0},
{5,202,191,61,50,-1,0},
{5,265,191,61,50,-1,0},
{5,328,191,61,50,-1,0},
{5,391,191,61,50,-1,0},
{5,1,245,61,50,-1,0},
{5,64,245,61,50,-1,0},
{5,127,245,61,50,-1,0},
{5,190,245,61,50,-1,0},
{5,1,297,59,50,-1,0},
{5,329,297,59,49,-1,1},
{5,62,349,59,48,-1,0},
{5,123,349,59,48,-1,0},
{5,305,349,58,48,0,0},
{5,1,399,57,48,-1,0},
{5,60,399,57,48,-1,0},
{5,119,399,57,48,-1,0},
{5,365,349,58,48,0,0},
{5,425,349,58,48,0,0},
{5,184,349,59,48,-1,0},
{5,390,297,59,49,-1,1},
{5,316,245,60,50,0,0},
{5,253,245,61,50,-1,0},
},
{
{4,20,2025,14,6,12,-2},
{4,50,2025,10,4,8,0},
{4,62,2025,5,4,3,0},
{4,1022,1125,1,1,1,-1},
{4,1020,355,1,1,1,-1},
{4,1020,1393,1,1,1,-1},
{4,1020,1717,1,1,1,-1},
{4,1020,1988,1,1,1,-1},
{4,69,2025,1,1,1,-1},
{4,1017,1504,6,9,0,-5},
{4,1012,1768,11,16,-1,-14},
{4,615,1950,16,27,-2,-23},
{4,1000,1817,21,35,-3,-31},
{4,362,1768,24,47,-4,-33},
{4,415,1210,27,61,-5,-27},
{4,975,523,31,69,-9,-15},
{4,986,184,37,71,-13,-5},
{4,966,1,41,67,-15,3},
{4,910,1210,43,58,-19,6},
{4,461,1817,42,44,-22,8},
{4,438,1950,37,29,-23,7},
{4,896,1950,32,17,-22,5},
{4,912,2007,25,11,-23,5},
{4,992,2007,21,7,-19,3},
{4,1,2025,17,6,-15,2},
{4,36,2025,12,5,-10,1},
{4,1015,2007,7,4,-5,0},
{4,72,2025,1,1,1,-1},
{4,1018,1950,5,5,-1,-1},
{4,899,2007,11,13,1,5},
{4,564,1950,21,28,5,16},
{4,164,1864,30,42,8,24},
{4,769,1558,36,52,10,28},
{4,648,1449,37,53,7,25},
{4,979,1665,35,48,3,16},
{4,980,1864,31,39,1,7},
{4,587,1950,26,27,-2,-3},
{4,201,2007,22,15,-2,-11},
{4,877,2007,20,13,-2,-9},
{4,939,2007,15,11,-1,-7},
{4,979,2007,11,8,-1,-4},
{4,1016,1665,6,6,0,-2},
{4,75,2025,1,1,1,-1},
{4,78,2025,1,1,1,-1},
{4,81,2025,1,1,1,-1},
{4,84,2025,1,1,1,-1},
{4,87,2025,1,1,1,-1},
{4,1015,1908,8,9,-4,-5},
{4,813,1950,19,19,-9,-13},
{4,477,1950,31,29,-11,-19},
{4,937,1908,43,37,-9,-21},
{4,476,1908,50,38,0,-18},
{4,75,1950,53,36,11,-12},
{4,235,1950,52,34,22,0},
{4,289,1950,53,33,31,15},
{4,1,1908,56,40,30,16},
{4,954,1768,56,45,30,15},
{4,968,1612,51,47,29,13},
{4,54,1817,44,45,28,7},
{4,125,1864,37,42,25,4},
{4,982,1908,31,36,21,0},
{4,510,1950,24,29,16,-3},
{4,766,1950,17,22,11,-8},
{4,733,2007,12,15,8,-9},
{4,1013,1864,10,11,6,-9},
{4,1015,689,8,15,4,1},
{4,1009,1277,12,23,6,15},
{4,378,1950,16,32,10,26},
{4,1000,1717,18,40,12,28},
{4,1000,1125,20,47,10,19},
{4,988,1504,27,51,7,3},
{4,687,1449,36,53,6,-13},
{4,710,1210,50,60,-2,-20},
{4,958,1020,62,66,-8,-24},
{4,929,1125,69,66,-15,-26},
{4,269,1210,71,62,-21,-24},
{4,802,1277,68,55,-22,-21},
{4,69,1717,60,49,-20,-19},
{4,1,1817,51,45,-17,-19},
{4,528,1908,40,38,-14,-18},
{4,344,1950,32,32,-14,-18},
{4,739,1950,25,25,-15,-17},
{4,878,1950,16,18,-14,-14},
{4,718,2007,13,15,-9,-7},
{4,861,2007,14,14,-8,2},
{4,88,1988,21,16,-13,10},
{4,785,1950,26,21,-18,15},
{4,633,1950,28,26,-18,20},
{4,536,1950,26,28,-16,24},
{4,396,1950,22,30,-12,26},
{4,420,1950,16,30,-8,28},
{4,1009,1,12,28,-4,26},
{5,485,349,13,30,-5,28},
{5,467,399,12,30,-6,28},
{5,481,399,12,29,-6,27},
{5,500,245,11,26,-5,24},
{5,502,191,9,23,-5,21},
{5,500,349,8,20,-4,18},
{5,495,399,7,16,-3,14},
{5,504,399,6,11,-2,9},
{5,489,488,5,6,-1,4},
{5,510,70,1,1,1,-1},
{5,510,133,1,1,1,-1},
{5,496,488,7,5,3,-1},
{5,470,488,17,8,5,-4},
{5,41,488,30,15,6,-5},
{5,284,449,46,29,4,-3},
{5,178,399,60,43,2,-5},
{5,1,191,71,52,1,-6},
{5,364,133,77,53,-1,-3},
{5,322,1,75,63,-7,-3},
{5,1,1,67,67,-9,3},
{5,261,1,59,64,-9,10},
{5,214,70,56,60,-2,12},
{5,311,133,51,55,5,11},
{5,454,191,46,49,10,9},
{5,471,1,40,42,12,6},
{5,475,70,33,34,13,4},
{5,332,449,27,25,15,1},
{5,157,488,19,15,15,-1},
},
{
{4,360,1864,75,41,-15,-1},
{4,1,1950,72,36,-10,-8},
{4,645,1908,72,37,-10,-9},
{4,570,1908,73,37,-11,-9},
{4,324,1908,74,38,-12,-10},
{4,169,1908,76,39,-12,-9},
{4,823,1864,77,40,-13,-10},
{4,503,1864,61,41,3,-11},
{4,437,1864,64,41,2,-11},
{4,933,1817,65,42,1,-12},
{4,676,1817,66,43,0,-11},
{4,187,1817,68,44,0,-12},
{4,866,1908,69,37,-1,-5},
{4,793,1908,71,37,-3,-5},
{4,719,1908,72,37,-4,-5},
{4,400,1908,74,38,-4,-4},
{4,247,1908,75,38,-5,-4},
{4,902,1864,76,40,-6,-4},
{4,743,1864,78,40,-6,-4},
{4,279,1864,79,41,-7,-3},
{4,196,1864,81,41,-9,-3},
{4,591,1817,83,43,-9,-3},
{4,505,1817,84,43,-10,-3},
{4,100,1817,85,44,-11,-2},
{4,756,1768,68,45,6,-1},
{4,684,1768,70,45,6,-1},
{4,388,1768,66,46,10,0},
{4,1,1768,67,47,9,1},
{4,262,1717,68,48,10,2},
{4,191,1717,69,48,9,2},
{4,838,1665,69,49,9,3},
{4,643,1612,71,50,7,2},
{4,76,1612,73,51,7,3},
{4,885,1558,74,51,6,3},
{4,883,1449,75,52,5,4},
{4,805,1449,76,52,4,4},
{4,531,1393,78,53,4,5},
{4,370,1393,79,53,3,5},
{4,273,1336,73,54,-5,6},
{4,654,1277,76,55,-6,7},
{4,732,1277,68,55,-16,7},
{4,227,1277,70,56,-16,8},
{4,153,1277,72,56,-16,8},
{4,78,1277,73,57,-17,9},
{4,1,1277,75,57,-17,9},
{4,842,1210,66,58,-6,10},
{4,762,1210,78,59,-18,9},
{4,639,1210,69,60,-7,10},
{4,342,1210,71,61,-7,9},
{4,197,1210,70,63,-10,9},
{4,258,1393,55,54,-27,18},
{4,962,355,56,65,-28,9},
{4,685,1864,56,41,-28,3},
{4,626,1864,57,41,-29,3},
{4,566,1864,58,41,-30,3},
{4,64,1864,59,42,-31,2},
{4,1,1864,61,42,-31,2},
{4,744,1817,63,43,-31,3},
{4,872,1817,59,43,-25,3},
{4,809,1817,61,43,-25,3},
{4,395,1817,64,44,-26,2},
{4,327,1817,66,44,-26,2},
{4,257,1817,68,44,-26,2},
{4,891,1768,61,45,-17,3},
{4,826,1768,63,45,-17,3},
{4,629,1768,53,46,-5,2},
{4,573,1768,54,46,-4,2},
{4,515,1768,56,46,-4,2},
{4,456,1768,57,46,-3,2},
{4,70,1768,58,47,-2,3},
{4,462,1717,60,48,-2,2},
{4,398,1717,62,48,-2,2},
{4,332,1717,64,48,-2,2},
{4,1,1717,66,49,-2,3},
{4,909,1665,68,49,-2,3},
{4,766,1665,70,49,-2,3},
{4,569,1612,72,50,-2,2},
{4,493,1612,74,50,-2,2},
{4,807,1558,76,51,-2,3},
{4,686,1665,78,49,-2,1},
{4,147,1504,65,52,-17,2},
{4,297,1612,67,51,-17,1},
{4,77,1504,68,52,-18,2},
{4,225,1612,70,51,-18,1},
{4,151,1612,72,51,-18,1},
{4,1,1504,74,52,-18,0},
{4,527,1449,62,53,-6,1},
{4,611,1393,76,53,-18,1},
{4,689,1393,65,53,-5,1},
{4,591,1449,55,53,-15,1},
{4,315,1393,53,54,-13,0},
{4,200,1393,56,54,-14,0},
{5,253,133,56,55,-14,1},
{5,192,133,59,55,-15,1},
{5,130,133,60,55,-16,1},
{5,66,133,62,56,-16,0},
{5,1,133,63,56,-17,0},
{5,409,70,64,57,-18,1},
{5,341,70,66,57,-18,1},
{5,272,70,67,58,-19,2},
{5,143,70,69,60,-21,2},
{5,71,70,70,60,-20,2},
{5,135,297,70,49,-22,15},
{5,1,70,68,61,-16,3},
{5,399,1,70,62,-18,4},
{5,245,349,58,48,-8,18},
{5,268,297,59,49,-7,19},
{5,199,1,60,64,-8,4},
{5,136,1,61,65,-9,5},
{5,74,191,63,52,-9,20},
{5,70,1,64,67,-10,5},
{5,443,133,65,53,-9,19},
{5,143,449,66,37,-10,3},
{5,73,449,68,37,-10,3},
{5,1,449,70,37,-10,3},
{5,62,297,71,49,-9,13},
{5,392,399,73,38,-9,2},
{5,316,399,74,39,-10,1},
{5,211,449,71,33,-5,-7},
{5,240,399,74,40,-14,0},
},
{
{4,111,1988,20,16,0,0},
{4,133,1988,20,16,0,0},
{4,155,1988,20,16,0,0},
{4,177,1988,20,16,0,0},
{4,199,1988,20,16,0,0},
{4,221,1988,20,16,0,0},
{4,309,1988,19,16,1,0},
{4,330,1988,19,16,1,0},
{4,351,1988,19,16,1,0},
{4,372,1988,19,16,1,0},
{4,393,1988,19,16,1,0},
{4,414,1988,19,16,1,0},
{4,435,1988,19,16,1,0},
{4,456,1988,19,16,1,0},
{4,477,1988,19,16,1,0},
{4,498,1988,19,16,1,0},
{4,519,1988,19,16,1,0},
{4,540,1988,19,16,1,0},
{4,561,1988,19,16,1,0},
{4,582,1988,19,16,1,0},
{4,603,1988,19,16,1,0},
{4,624,1988,19,16,1,0},
{4,645,1988,19,16,1,0},
{4,666,1988,19,16,1,0},
{4,687,1988,19,16,1,0},
{4,708,1988,19,16,1,0},
{4,225,2007,19,15,1,1},
{4,246,2007,19,15,1,1},
{4,309,2007,18,15,0,1},
{4,509,2007,17,15,1,1},
{4,528,2007,17,15,1,1},
{4,547,2007,17,15,1,1},
{4,566,2007,17,15,1,1},
{4,747,2007,17,14,1,0},
{4,766,2007,17,14,1,0},
{4,785,2007,17,14,1,0},
{4,804,2007,17,14,1,0},
{4,823,2007,17,14,1,0},
{4,842,2007,17,14,1,0},
{4,585,2007,17,15,1,1},
{4,604,2007,17,15,1,1},
{4,329,2007,18,15,0,1},
{4,349,2007,18,15,0,1},
{4,369,2007,18,15,0,1},
{4,960,1988,18,16,0,0},
{4,729,1988,19,16,1,0},
{4,750,1988,19,16,1,0},
{4,771,1988,19,16,1,0},
{4,792,1988,19,16,1,0},
{4,813,1988,19,16,1,0},
{4,834,1988,19,16,1,0},
{4,980,1988,18,16,0,0},
{4,1000,1988,18,16,0,0},
{4,1,2007,18,16,0,0},
{4,21,2007,18,16,0,0},
{4,41,2007,18,16,0,0},
{4,61,2007,18,16,0,0},
{4,81,2007,18,16,0,0},
{4,101,2007,18,16,0,0},
{4,121,2007,18,16,0,0},
{4,141,2007,18,16,0,0},
{4,161,2007,18,16,0,0},
{4,181,2007,18,16,0,0},
{4,855,1988,19,16,-1,0},
{4,243,1988,20,16,0,0},
{4,265,1988,20,16,0,0},
{4,287,1988,20,16,0,0},
{4,930,1950,20,17,0,-1},
{4,952,1950,20,17,0,-1},
{4,974,1950,20,17,0,-1},
{4,996,1950,20,17,0,-1},
{4,1,1988,20,17,0,-1},
{4,23,1988,20,17,0,-1},
{4,45,1988,20,17,0,-1},
{4,67,1988,19,17,-1,-1},
{4,876,1988,19,16,-1,0},
{4,897,1988,19,16,-1,0},
{4,918,1988,19,16,-1,0},
{4,939,1988,19,16,-1,0},
{4,267,2007,19,15,-1,-1},
{4,389,2007,18,15,0,-1},
{4,409,2007,18,15,0,-1},
{4,429,2007,18,15,0,-1},
{4,623,2007,17,15,-1,-1},
{4,642,2007,17,15,-1,-1},
{4,661,2007,17,15,-1,-1},
{4,680,2007,17,15,-1,-1},
{4,699,2007,17,15,-1,-1},
{4,449,2007,18,15,0,-1},
{4,469,2007,18,15,0,-1},
{4,489,2007,18,15,0,-1},
{4,288,2007,19,15,-1,-1},
{5,73,488,19,15,-1,-1},
{5,94,488,19,15,-1,-1},
{5,115,488,19,15,-1,-1},
{5,136,488,19,15,-1,-1},
{5,178,488,18,15,0,-1},
{5,198,488,18,15,0,-1},
{5,218,488,18,15,0,-1},
{5,238,488,18,15,0,-1},
{5,298,488,17,15,-1,-1},
{5,317,488,17,15,-1,-1},
{5,336,488,17,15,-1,-1},
{5,375,488,17,14,-1,0},
{5,394,488,17,14,-1,0},
{5,413,488,17,14,-1,0},
{5,432,488,17,14,-1,0},
{5,451,488,17,14,-1,0},
{5,355,488,18,14,0,0},
{5,258,488,18,15,0,-1},
{5,278,488,18,15,0,-1},
{5,491,449,18,16,0,0},
{5,1,488,18,16,0,0},
{5,21,488,18,16,0,0},
{5,449,449,19,16,-1,0},
{5,470,449,19,16,-1,0},
{5,361,449,20,16,0,0},
{5,383,449,20,16,0,0},
{5,405,449,20,16,0,0},
{5,427,449,20,16,0,0},
},
}}
local precastHigh={pixels=296,pages=P,bands={
{
{6,1,1,276,261,6,3},
{7,1,1,276,261,4,3},
{7,279,1,278,260,2,4},
{7,559,1,280,259,0,5},
{7,1,264,280,258,-2,6},
{7,283,264,282,257,-2,7},
{7,567,264,283,256,-3,8},
{7,1,524,285,255,-3,9},
{7,576,524,285,254,-5,10},
{7,288,524,286,254,-4,10},
{7,1,781,285,252,-3,10},
{8,1677,258,285,250,-3,12},
{8,845,514,286,248,-4,14},
{8,288,514,286,249,-4,11},
{8,1,514,285,250,-5,8},
{8,1117,258,285,251,-5,3},
{8,1147,1,285,254,-5,-4},
{8,1434,1,285,254,-5,-10},
{8,1,1,285,255,-5,-13},
{8,859,1,286,254,-6,-14},
{8,288,1,284,255,-6,-15},
{8,574,1,283,255,-7,-15},
{8,1721,1,282,254,-8,-16},
{8,281,258,280,253,-10,-15},
{8,1,258,278,254,-12,-16},
{8,563,258,276,253,-14,-17},
{8,841,258,274,252,-16,-18},
{8,1404,258,271,251,-19,-21},
{8,576,514,267,249,-21,-23},
{8,1133,514,265,247,-23,-25},
{8,1400,514,263,244,-27,-26},
{8,1665,514,261,242,-29,-28},
{8,1,766,260,242,-28,-28},
{9,1038,269,260,242,-30,-28},
{9,1,535,260,241,-30,-27},
{9,1300,269,260,242,-30,-26},
{9,263,535,259,241,-29,-25},
{9,1562,269,262,241,-28,-25},
{9,1,778,263,240,-27,-24},
{9,791,535,264,240,-26,-24},
{9,1057,535,264,240,-26,-24},
{9,524,535,265,240,-25,-24},
{9,1323,535,264,240,-24,-24},
{9,1589,535,264,240,-24,-24},
{9,1,1,265,266,-23,2},
{9,268,1,264,266,-22,2},
{9,534,1,263,266,-21,2},
{9,799,1,263,265,-19,3},
{9,1,269,260,264,-18,4},
{9,519,269,259,263,-17,7},
{9,780,269,256,263,-16,7},
{9,263,269,254,264,-14,8},
{9,1064,1,249,265,-11,7},
{9,1315,1,242,265,-6,7},
{9,1802,1,238,265,4,7},
{9,1559,1,241,265,7,7},
{10,1,1,242,265,10,7},
{10,1267,268,245,264,13,8},
{10,1015,268,250,264,14,8},
{10,1,268,252,264,18,8},
{10,509,268,251,264,21,10},
{10,1789,268,252,263,22,9},
{10,1,534,252,263,24,9},
{10,1570,1,253,264,23,10},
{10,762,268,251,264,25,10},
{10,255,268,252,264,26,10},
{10,1311,1,257,264,21,10},
{10,1050,1,259,264,19,10},
{10,786,1,262,264,16,10},
{10,517,1,267,264,13,10},
{10,245,1,270,264,10,10},
{10,1514,268,273,263,7,11},
{10,255,534,275,262,5,12},
{10,532,534,276,261,4,13},
{10,810,534,278,260,2,12},
{10,1373,534,280,259,0,15},
{10,1090,534,281,259,-1,15},
{10,1,799,282,257,-2,15},
{10,1655,534,284,257,-2,17},
{11,1,260,285,255,-1,17},
{11,1136,260,285,254,-1,18},
{11,1423,260,285,254,-1,18},
{11,1,517,285,253,-1,19},
{11,1136,517,286,250,-2,20},
{11,1711,517,285,248,-1,22},
{11,1424,517,285,249,-1,19},
{11,849,517,285,251,-1,15},
{11,562,517,285,252,-1,10},
{11,288,260,285,255,-1,1},
{11,1148,1,285,256,-1,-6},
{11,860,1,286,256,-2,-8},
{11,1,1,285,257,-3,-9},
{11,288,1,284,257,-2,-11},
{11,574,1,284,257,-2,-11},
{11,1435,1,283,256,-3,-12},
{11,575,260,280,255,-4,-13},
{11,1720,1,279,256,-5,-14},
{11,857,260,277,255,-7,-15},
{11,1710,260,275,254,-9,-16},
{11,288,517,272,253,-12,-19},
{12,1,1,270,251,-14,-21},
{12,273,1,271,249,-13,-23},
{12,546,1,269,246,-15,-26},
{12,817,1,268,245,-16,-29},
{12,1087,1,267,242,-17,-32},
{13,1245,270,267,239,-17,-33},
{13,1,537,267,237,-17,-33},
{13,270,537,266,237,-18,-33},
{13,538,537,265,237,-19,-33},
{13,805,537,264,237,-20,-33},
{13,272,776,268,236,-16,-32},
{13,1,776,269,236,-15,-32},
{13,1618,537,270,236,-14,-32},
{13,1071,537,272,236,-12,-32},
{13,1345,537,271,236,-13,-32},
{13,1514,270,270,237,-14,-33},
{13,1,1,271,267,-11,-3},
{13,274,1,267,267,-13,-3},
{13,543,1,266,266,-12,-2},
{13,811,1,263,266,-11,-2},
{13,1076,1,260,265,-10,-1},
{13,477,270,257,264,-11,0},
{13,988,270,255,263,-11,1},
{13,736,270,250,264,-10,2},
{13,1338,1,245,265,-7,1},
{13,1585,1,242,265,0,1},
{13,1,270,238,265,10,1},
{13,241,270,234,265,20,1},
{14,1,534,237,264,23,0},
{14,504,1,242,265,22,1},
{14,754,268,246,264,24,0},
{14,753,534,248,263,26,1},
{14,1,1,250,265,24,1},
{14,1,268,251,264,27,0},
{14,253,1,249,265,29,1},
{14,254,268,248,264,30,2},
{14,501,534,250,263,28,1},
{14,504,268,248,264,30,2},
{14,748,1,256,264,24,2},
{14,240,534,259,263,21,1},
{15,540,1,263,263,17,1},
{15,1,1,266,264,14,2},
{15,269,1,269,263,11,1},
{15,1,267,273,262,9,2},
},
{
{6,1,264,267,231,-1,-25},
{7,288,781,268,231,-2,-25},
{7,557,1035,272,229,-2,-23},
{7,558,781,275,230,-3,-22},
{7,1,1035,276,229,-4,-21},
{7,279,1035,276,229,-4,-21},
{7,1,1266,276,228,-6,-20},
{7,555,1266,275,227,-9,-19},
{7,279,1266,274,228,-10,-18},
{7,278,1496,274,210,-10,0},
{7,1,1496,275,210,-9,0},
{8,1,1458,276,210,-8,0},
{8,279,1458,276,210,-8,0},
{8,1670,1244,277,210,-9,0},
{8,1114,1244,276,211,-8,1},
{8,1392,1244,276,211,-8,1},
{8,835,1244,277,211,-9,1},
{8,1,1244,276,212,-8,0},
{8,279,1244,276,212,-8,0},
{8,1642,1010,277,212,-9,0},
{8,557,1244,276,212,-8,0},
{8,1364,1010,276,214,-8,-2},
{8,1085,1010,277,217,-9,-5},
{8,809,1010,274,222,-10,-10},
{8,534,1010,273,227,-11,-15},
{8,261,1010,271,230,-13,-18},
{8,1580,766,270,232,-14,-20},
{8,263,766,267,233,-17,-19},
{8,532,766,264,233,-20,-19},
{8,798,766,260,233,-22,-19},
{8,1060,766,259,233,-25,-17},
{8,1,1010,258,232,-28,-18},
{8,1321,766,257,233,-27,-19},
{9,1412,1020,256,233,-26,-19},
{9,1670,1020,256,233,-28,-19},
{9,1414,778,255,234,-27,-18},
{9,1671,778,255,234,-29,-18},
{9,1,1020,255,234,-27,-18},
{9,1,1256,254,233,-26,-17},
{9,257,1256,253,233,-27,-17},
{9,512,1256,252,232,-26,-16},
{9,766,1256,250,232,-26,-16},
{9,1268,1256,249,231,-25,-15},
{9,1519,1256,247,231,-25,-15},
{9,1018,1256,248,232,-22,-16},
{9,958,1020,227,234,-3,-18},
{9,1188,778,224,235,-4,-19},
{9,1826,269,221,235,-3,-19},
{9,501,778,230,235,8,-19},
{9,258,1020,234,234,6,-18},
{9,266,778,233,235,7,-19},
{9,494,1020,231,234,7,-18},
{9,727,1020,229,234,9,-18},
{9,733,778,226,235,10,-19},
{9,961,778,225,235,9,-19},
{9,1187,1020,223,234,7,-20},
{10,1825,1,221,235,5,-19},
{10,285,799,220,234,4,-18},
{10,507,799,218,234,2,-18},
{10,1190,799,225,233,9,-17},
{10,960,799,228,233,10,-19},
{10,727,799,231,233,11,-19},
{10,1,1058,233,232,11,-18},
{10,1666,799,238,232,14,-18},
{10,1269,1058,241,231,15,-19},
{10,1417,799,247,232,17,-20},
{10,1016,1058,251,231,15,-19},
{10,759,1058,255,231,13,-19},
{10,499,1058,258,231,10,-19},
{10,236,1058,261,231,7,-19},
{10,1781,1058,264,230,4,-18},
{10,1512,1058,267,230,1,-18},
{10,273,1292,268,229,2,-17},
{10,1,1292,270,229,0,-17},
{10,543,1292,272,227,-2,-17},
{10,1094,1292,274,226,-2,-16},
{10,817,1292,275,226,-3,-16},
{10,1370,1292,276,225,-4,-15},
{10,1648,1292,275,224,-5,-14},
{11,818,772,275,224,-7,-14},
{11,1095,772,274,223,-6,-13},
{11,836,1003,274,210,-6,0},
{11,1112,1003,274,210,-6,0},
{11,280,1003,276,210,-4,0},
{11,1388,1003,276,209,-4,1},
{11,1666,1003,278,208,-4,0},
{11,1,1218,277,208,-3,0},
{11,280,1218,277,208,-3,0},
{11,837,1218,277,207,-3,1},
{11,1116,1218,276,207,-2,-1},
{11,1394,1218,277,206,-3,0},
{11,1673,1218,277,206,-3,0},
{11,559,1218,276,208,-2,-2},
{11,558,1003,276,210,-2,-4},
{11,1,1003,277,213,-3,-7},
{11,1646,772,274,219,0,-13},
{11,1371,772,273,223,-3,-17},
{11,544,772,272,227,-4,-23},
{11,272,772,270,228,-6,-24},
{11,1,772,269,229,-9,-25},
{12,1356,1,267,229,-11,-25},
{12,532,254,262,228,-12,-24},
{12,266,254,264,228,-12,-24},
{12,1625,1,264,229,-14,-25},
{12,1,254,263,229,-13,-25},
{13,1246,1014,261,230,-15,-26},
{13,1509,1014,261,230,-15,-26},
{13,1772,1014,258,230,-16,-26},
{13,1,1014,260,231,-14,-27},
{13,263,1014,258,231,-14,-27},
{13,523,1014,257,231,-15,-27},
{13,1,1247,255,230,-15,-26},
{13,491,1247,253,229,-17,-25},
{13,746,1247,249,229,-17,-25},
{13,997,1247,247,229,-17,-25},
{13,1246,1247,244,228,-18,-24},
{13,1492,1247,252,227,-10,-25},
{13,258,1247,231,230,11,-26},
{13,1016,1014,228,231,12,-27},
{13,782,1014,232,231,18,-27},
{13,758,776,230,232,18,-28},
{13,990,776,228,232,18,-28},
{13,1220,776,227,232,17,-28},
{13,1786,270,224,233,14,-29},
{13,1449,776,222,232,12,-28},
{13,1673,776,220,232,10,-28},
{13,1829,1,218,233,8,-29},
{13,542,776,214,233,6,-29},
{14,675,1036,211,233,3,-29},
{14,1,1271,208,233,0,-29},
{14,454,1036,219,233,11,-29},
{14,677,1271,223,232,15,-28},
{14,229,1036,223,233,17,-29},
{14,451,1271,224,232,18,-28},
{14,1,1036,226,233,20,-29},
{14,748,800,235,233,17,-29},
{14,211,1271,238,232,20,-28},
{14,506,800,240,233,24,-27},
{14,1,800,248,234,16,-28},
{14,251,800,253,233,13,-27},
{15,537,267,255,233,9,-27},
{15,276,267,259,233,5,-27},
{15,268,531,262,232,2,-26},
{15,1,531,265,232,-1,-26},
},
{
{6,279,1,163,178,5,28},
{7,333,1708,163,178,5,28},
{7,167,1708,164,179,6,27},
{7,721,1496,164,180,6,28},
{7,1,1708,164,180,6,28},
{7,554,1496,165,180,7,28},
{7,832,1266,165,181,7,27},
{7,831,1035,165,181,7,27},
{7,852,264,165,182,7,28},
{7,841,1,165,182,7,28},
{7,835,781,165,182,7,28},
{8,1691,1670,164,182,6,28},
{8,1857,1670,164,182,6,28},
{8,1,1857,164,182,6,28},
{8,1359,1670,164,184,6,28},
{8,842,1670,171,184,-1,28},
{8,668,1670,172,184,-2,28},
{8,1015,1670,170,184,0,28},
{8,1187,1670,170,184,-2,28},
{8,1389,1458,168,185,0,27},
{8,1559,1458,166,185,2,27},
{8,502,1670,164,185,4,27},
{8,1525,1670,164,184,4,28},
{8,1,1670,165,185,5,27},
{8,1727,1458,166,185,4,27},
{8,168,1670,165,185,3,27},
{8,335,1670,165,185,3,27},
{8,890,1458,165,186,3,28},
{8,1852,766,165,187,3,29},
{8,557,1458,165,187,3,29},
{8,724,1458,164,187,2,29},
{8,1057,1458,164,186,2,28},
{8,1223,1458,164,186,2,28},
{9,657,1685,165,186,3,28},
{9,1318,1685,164,185,4,29},
{9,987,1491,165,190,5,26},
{9,1855,535,165,192,5,24},
{9,1768,1256,164,192,6,24},
{9,1,1491,163,192,5,24},
{9,330,1491,163,191,3,25},
{9,1482,1491,161,190,3,26},
{9,1645,1491,161,190,3,26},
{9,495,1491,162,191,2,25},
{9,659,1491,162,191,2,25},
{9,166,1491,162,192,2,24},
{9,823,1491,162,191,2,25},
{9,1154,1491,162,190,2,26},
{9,1318,1491,162,190,2,26},
{9,1808,1491,162,189,2,27},
{9,1,1685,162,188,2,28},
{9,165,1685,162,187,2,29},
{9,329,1685,162,187,2,29},
{9,493,1685,162,187,2,29},
{9,990,1685,162,186,2,30},
{9,1154,1685,162,186,2,30},
{9,824,1685,164,186,4,30},
{10,669,1523,165,186,5,30},
{10,502,1523,165,187,5,29},
{10,168,1523,165,188,5,28},
{10,1,1523,165,189,5,27},
{10,335,1523,165,188,5,26},
{10,836,1523,164,186,4,28},
{10,1002,1523,163,183,3,31},
{10,1167,1523,162,183,2,31},
{10,1827,1523,162,182,2,30},
{10,1,1714,162,182,2,30},
{10,1497,1523,163,182,3,30},
{10,1662,1523,163,182,3,30},
{10,991,1714,163,180,3,32},
{10,165,1714,163,181,3,31},
{10,330,1714,163,181,3,31},
{10,495,1714,163,181,3,31},
{10,660,1714,163,181,3,31},
{10,1331,1523,164,182,4,32},
{10,825,1714,164,180,4,32},
{10,1324,1714,165,178,5,32},
{10,1491,1714,165,178,5,32},
{10,1658,1714,165,178,5,32},
{10,1156,1714,166,178,6,32},
{11,1,1428,166,178,6,32},
{11,169,1428,166,178,6,32},
{11,337,1428,166,178,6,32},
{11,505,1428,166,178,6,32},
{11,673,1428,166,178,6,32},
{11,841,1428,166,177,6,33},
{11,1178,1428,166,176,6,32},
{11,1346,1428,166,175,6,33},
{11,1009,1428,167,176,7,32},
{11,1514,1428,166,175,6,33},
{11,685,1608,167,174,7,32},
{11,854,1608,167,174,7,32},
{11,1023,1608,167,174,7,32},
{11,1854,1428,169,174,5,32},
{11,1,1608,169,174,5,32},
{11,172,1608,169,174,5,32},
{11,343,1608,169,174,5,32},
{11,1682,1428,170,174,4,32},
{11,514,1608,169,174,5,32},
{11,1192,1608,171,173,5,31},
{11,1365,1608,170,173,4,31},
{12,796,254,169,173,5,31},
{12,967,254,169,173,5,31},
{12,1138,254,168,173,6,31},
{12,1477,254,167,172,7,32},
{12,1308,254,167,173,7,31},
{13,1561,1667,166,175,6,29},
{13,1394,1667,165,178,5,26},
{13,1227,1667,165,182,7,22},
{13,1039,1479,165,184,7,20},
{13,1206,1479,163,184,5,20},
{13,1701,1479,162,184,4,20},
{13,1865,1479,162,184,4,20},
{13,1371,1479,163,184,5,20},
{13,516,1479,163,185,5,19},
{13,1536,1479,163,184,5,20},
{13,175,1479,165,186,7,18},
{13,1746,1247,173,187,-1,17},
{13,1,1479,172,186,-2,18},
{13,342,1479,172,185,-2,19},
{13,861,1479,176,184,-4,20},
{13,681,1479,178,184,-4,20},
{13,181,1667,177,183,-1,21},
{13,1,1667,178,183,0,21},
{13,1050,1667,175,182,1,22},
{13,360,1667,174,183,4,21},
{13,536,1667,171,183,5,21},
{13,709,1667,170,183,8,21},
{13,881,1667,167,183,9,21},
{14,1,1697,167,184,9,20},
{14,504,1506,166,187,8,17},
{14,169,1506,166,188,8,16},
{14,1,1506,166,189,8,15},
{14,337,1506,165,188,7,16},
{14,672,1506,165,187,7,17},
{14,839,1506,164,185,6,19},
{14,170,1697,164,183,6,21},
{14,501,1697,164,181,6,23},
{14,336,1697,163,182,5,24},
{14,667,1697,163,181,5,25},
{14,832,1697,163,181,5,25},
{15,845,989,163,179,5,27},
{15,1,1405,163,178,5,28},
{15,166,1405,163,178,5,28},
{15,331,1405,163,178,5,28},
},
{
{6,270,264,97,145,15,45},
{7,201,1890,97,145,15,45},
{7,599,1708,98,145,14,45},
{7,699,1708,98,145,14,45},
{7,799,1708,98,145,14,45},
{7,887,1496,98,146,14,46},
{7,863,524,98,146,14,46},
{7,899,1708,98,145,14,47},
{7,1,1890,98,145,14,47},
{7,498,1708,99,145,13,47},
{7,101,1890,98,145,14,47},
{8,1949,1244,98,146,14,48},
{8,1371,1857,97,146,13,48},
{8,1470,1857,97,146,13,48},
{8,571,1857,98,146,12,48},
{8,671,1857,98,146,12,48},
{8,771,1857,98,146,12,48},
{8,871,1857,98,146,12,48},
{8,971,1857,98,146,12,48},
{8,1670,1857,98,145,12,49},
{8,1770,1857,98,145,12,49},
{8,1928,514,99,146,11,50},
{8,1921,1010,99,146,11,50},
{8,1895,1458,99,146,11,50},
{8,1071,1857,98,146,10,50},
{8,1171,1857,98,146,10,50},
{8,1271,1857,98,146,10,50},
{8,1870,1857,98,145,10,51},
{8,1569,1857,99,145,9,51},
{8,167,1857,99,146,9,52},
{8,268,1857,99,146,9,52},
{8,369,1857,99,146,9,52},
{8,470,1857,99,146,9,52},
{9,1332,1875,99,146,9,52},
{9,720,1875,100,146,8,52},
{9,822,1875,100,146,8,52},
{9,1433,1875,100,145,8,53},
{9,924,1875,100,146,8,54},
{9,1026,1875,100,146,8,54},
{9,1128,1875,100,146,8,54},
{9,1230,1875,100,146,8,54},
{9,516,1875,100,147,8,55},
{9,1691,1685,100,148,8,56},
{9,618,1875,100,147,8,57},
{9,1793,1685,103,147,5,57},
{9,1,1875,101,147,7,57},
{9,104,1875,101,147,7,57},
{9,1898,1685,102,147,6,57},
{9,1588,1685,101,148,7,58},
{9,1934,1256,102,148,8,58},
{9,1928,778,102,148,8,58},
{9,207,1875,101,147,7,57},
{9,1928,1020,102,148,8,58},
{9,1484,1685,102,148,8,58},
{9,310,1875,101,147,7,57},
{9,413,1875,101,147,7,57},
{10,1941,534,101,148,7,58},
{10,1906,799,101,147,7,57},
{10,1925,1292,101,148,7,58},
{10,1,1898,101,146,7,58},
{10,104,1898,101,146,7,58},
{10,207,1898,101,146,7,58},
{10,310,1898,101,146,7,58},
{10,413,1898,101,146,7,58},
{10,1825,1714,102,146,8,58},
{10,622,1898,102,145,8,57},
{10,726,1898,102,145,8,57},
{10,830,1898,102,145,8,57},
{10,934,1898,102,145,8,57},
{10,1038,1898,102,145,8,57},
{10,516,1898,104,145,6,57},
{10,1142,1898,102,145,8,55},
{10,1929,1714,102,146,8,56},
{10,1246,1898,102,145,8,55},
{10,1350,1898,101,145,9,55},
{10,1453,1898,101,145,9,55},
{10,1556,1898,101,145,9,55},
{10,1659,1898,101,145,9,55},
{10,1762,1898,101,145,9,55},
{11,1946,1003,101,145,9,55},
{11,1922,772,101,145,9,55},
{11,1740,1608,101,144,9,54},
{11,1843,1608,101,144,11,54},
{11,1946,1608,101,144,11,54},
{11,1,1784,101,144,11,54},
{11,104,1784,101,144,11,54},
{11,207,1784,100,144,12,54},
{11,309,1784,100,144,12,54},
{11,1537,1608,100,145,12,53},
{11,411,1784,100,144,12,52},
{11,513,1784,100,144,12,52},
{11,615,1784,100,144,12,52},
{11,717,1784,100,144,12,52},
{11,819,1784,100,144,12,52},
{11,921,1784,100,144,12,52},
{11,1023,1784,99,144,13,52},
{11,1639,1608,99,145,13,51},
{11,1124,1784,99,144,13,50},
{11,1225,1784,99,144,13,50},
{11,1326,1784,98,144,14,50},
{12,1646,254,98,144,14,50},
{12,1746,254,98,144,14,50},
{12,1846,254,98,144,14,50},
{12,1946,254,98,144,14,50},
{12,1891,1,98,145,14,49},
{13,1895,776,98,145,14,49},
{13,1890,537,98,145,14,49},
{13,1729,1667,98,145,14,49},
{13,1829,1667,98,145,14,49},
{13,1921,1247,99,145,15,49},
{13,200,1852,98,144,16,48},
{13,800,1852,97,144,15,48},
{13,300,1852,98,144,16,48},
{13,101,1852,97,145,15,47},
{13,1929,1667,98,145,14,47},
{13,1,1852,98,145,14,47},
{13,400,1852,98,144,16,46},
{13,500,1852,98,144,16,46},
{13,1196,1852,98,143,16,45},
{13,1296,1852,98,143,16,45},
{13,1396,1852,98,143,16,45},
{13,1496,1852,98,143,16,45},
{13,1596,1852,98,143,16,45},
{13,600,1852,98,144,16,46},
{13,700,1852,98,144,16,44},
{13,899,1852,97,144,17,44},
{13,998,1852,97,144,17,44},
{13,1097,1852,97,144,17,44},
{14,100,1883,96,144,16,44},
{14,198,1883,96,144,16,44},
{14,296,1883,96,144,16,44},
{14,394,1883,96,144,16,44},
{14,492,1883,96,144,16,44},
{14,590,1883,96,144,16,44},
{14,688,1883,96,144,16,44},
{14,1,1883,97,144,17,44},
{14,786,1883,96,144,16,44},
{14,884,1883,96,144,16,44},
{14,902,1271,97,145,15,45},
{14,888,1036,97,145,15,45},
{15,889,1585,97,145,15,45},
{15,887,765,97,145,15,45},
{15,881,1405,97,145,15,45},
{15,716,1758,97,145,15,45},
},
}}
local impact1High={pixels=336,pages=P,tiles={
{15,1021,267,2,2,0,0},
{15,986,765,36,16,20,-12},
{15,259,1916,58,84,28,42},
{15,132,1916,125,100,-31,26},
{15,1,1916,129,119,-29,11},
{15,815,1758,149,139,-11,-5},
{15,707,1405,172,172,2,-10},
{15,409,1205,190,190,2,-8},
{15,428,989,209,208,3,-8},
{15,1,989,213,214,3,-8},
{15,805,1,218,218,4,-8},
{15,225,765,222,221,4,-7},
{15,532,531,224,225,4,-7},
{15,758,531,224,225,4,-7},
{15,794,267,225,225,5,-7},
{15,1,765,222,222,4,-6},
{15,449,765,219,220,5,-6},
{15,670,765,215,214,5,-6},
{15,216,989,210,210,6,-6},
{15,639,989,204,204,6,-6},
{15,1,1205,202,198,2,-6},
{15,205,1205,202,192,-4,-6},
{15,601,1205,204,186,-12,-6},
{15,807,1205,206,180,-20,-6},
{15,496,1405,209,175,-27,-7},
{15,1,1585,210,171,-34,-7},
{15,213,1585,217,166,-33,-8},
{15,432,1585,223,163,-29,-7},
{15,657,1585,230,159,-26,-7},
{15,1,1758,234,156,-22,-8},
{15,237,1758,237,154,-17,-8},
{15,476,1758,238,152,-16,-8},
{16,1699,1884,239,151,-13,-9},
{16,1457,1884,240,152,-12,-10},
{16,1215,1884,240,155,-10,-13},
{16,972,1884,241,157,-9,-15},
{16,486,1884,241,160,-7,-14},
{16,729,1884,241,160,-5,-14},
{16,243,1884,241,162,-3,-14},
{16,1,1884,240,163,-2,-13},
{16,1792,1710,240,165,-2,-13},
{16,1027,1710,240,169,0,-15},
{16,1,1710,239,172,1,-18},
{16,1245,1532,237,174,3,-18},
{16,1727,1349,237,177,3,-19},
{16,1488,1349,237,178,3,-20},
{16,245,1349,237,180,1,-18},
{16,1243,1163,237,182,1,-18},
{16,1,1163,238,184,0,-18},
{16,482,975,237,185,-1,-17},
{16,1432,785,236,186,-2,-18},
{16,244,785,236,187,-2,-17},
{16,482,785,234,187,-2,-17},
{16,954,785,233,187,-3,-17},
{16,718,785,234,187,-4,-17},
{16,1670,785,235,186,-7,-16},
{16,1,975,235,186,-9,-16},
{16,721,975,237,185,-9,-15},
{16,1711,975,241,184,-9,-14},
{16,1467,975,242,184,-8,-12},
{16,1221,975,244,184,-8,-10},
{16,503,1163,246,183,-8,-9},
{16,751,1163,247,182,-7,-6},
{16,1744,1163,247,181,-7,-5},
{16,746,1349,247,179,-7,-3},
{16,995,1349,247,178,-7,-2},
{16,263,1532,245,176,-7,0},
{16,510,1532,244,176,-8,2},
{16,1000,1532,243,174,-9,4},
{16,1746,1532,242,173,-8,5},
{16,756,1532,242,176,-8,4},
{16,1244,1349,242,178,-6,2},
{16,1,1349,242,181,-6,1},
{16,1000,1163,241,182,-5,0},
{16,238,975,242,185,-4,-1},
{16,1189,785,241,186,-3,-2},
{16,1,785,241,188,-3,-2},
{16,1799,593,242,189,-4,-3},
{16,1476,398,242,191,-4,-3},
{16,730,398,242,192,-4,-4},
{16,714,200,242,194,-4,-4},
{16,958,200,242,194,-4,-4},
{16,471,200,241,195,-3,-3},
{16,1194,1,240,196,-4,-2},
{16,1,1,239,197,-3,-1},
{16,1436,1,239,196,-3,0},
{16,1677,1,238,196,-2,2},
{16,242,1,237,197,-3,5},
{16,481,1,237,197,-3,7},
{16,720,1,235,197,-3,9},
{16,957,1,235,197,-3,11},
{16,1,200,233,196,-3,14},
{16,236,200,233,196,-3,16},
{16,1202,200,235,194,-1,18},
{16,242,398,237,193,1,21},
{16,1,398,239,193,3,21},
{16,1685,200,242,193,4,21},
{16,1439,200,244,193,4,21},
{16,481,398,247,192,5,22},
{16,1226,398,248,191,6,21},
{16,974,398,250,191,6,21},
{16,259,593,252,190,6,22},
{16,1545,593,252,189,6,21},
{16,1289,593,254,189,6,23},
{16,1032,593,255,189,7,23},
{16,1,593,256,190,6,24},
{16,773,593,257,189,7,25},
{16,513,593,258,189,6,25},
{16,1720,398,259,190,7,24},
{16,960,975,259,184,7,30},
{16,241,1163,260,183,8,33},
{16,1482,1163,260,181,8,35},
{16,484,1349,260,179,8,37},
{16,1,1532,260,176,10,40},
{16,1484,1532,260,173,10,43},
{16,242,1710,260,170,10,46},
{16,1530,1710,260,167,12,49},
{16,1269,1710,259,168,13,48},
{16,766,1710,259,169,13,49},
{16,504,1710,260,170,12,50},
{17,263,953,260,170,12,50},
{17,1,953,260,171,12,51},
{17,527,778,261,172,11,52},
{17,1,778,261,173,11,53},
{17,264,778,261,173,11,53},
{17,516,601,261,174,11,54},
{17,259,601,255,175,15,55},
{17,1,601,256,175,14,55},
{17,265,418,256,176,14,56},
{17,273,1126,256,159,14,39},
{17,531,1126,256,158,14,38},
{17,1,1291,256,157,12,37},
{17,533,1291,256,156,12,36},
{17,1,1450,255,156,11,36},
{17,790,778,233,154,-15,34},
{17,789,418,234,153,-16,33},
{17,781,218,235,148,-17,28},
{17,779,601,235,147,-17,27},
{17,808,1450,193,123,-61,3},
{17,795,953,95,123,37,3},
{17,892,953,92,92,38,-28},
{17,831,1608,39,66,-15,-54},
{17,872,1608,38,63,-14,-55},
{17,1021,1,2,2,0,0},
}}
local impact2High={pixels=336,pages=P,tiles={
{17,1021,1291,2,2,0,0},
{17,1007,1,12,9,0,-249},
{17,999,1745,22,12,0,-246},
{17,775,1955,48,14,0,-248},
{17,931,1126,74,17,0,-249},
{17,912,1608,108,22,0,-248},
{17,789,1126,140,26,0,-248},
{17,825,1745,172,33,0,-247},
{17,810,1861,206,38,0,-246},
{17,791,1291,228,45,0,-243},
{17,523,1955,250,53,0,-239},
{17,265,1955,256,60,0,-236},
{17,1,1955,262,68,0,-232},
{17,543,1861,265,75,-1,-227},
{17,273,1861,268,84,0,-222},
{17,1,1861,270,92,0,-216},
{17,551,1745,272,100,0,-210},
{17,277,1745,272,107,0,-203},
{17,1,1745,274,114,0,-196},
{17,555,1608,274,121,0,-189},
{17,277,1608,276,128,0,-182},
{17,1,1608,274,135,0,-175},
{17,532,1450,274,142,0,-168},
{17,258,1450,272,149,0,-161},
{17,259,1291,272,156,0,-154},
{17,1,1126,270,163,0,-147},
{17,525,953,268,168,0,-140},
{17,523,418,264,175,0,-133},
{17,1,418,262,181,0,-127},
{17,519,218,260,186,0,-120},
{17,259,218,258,192,0,-114},
{17,1,218,256,198,0,-108},
{17,753,1,252,202,0,-102},
{17,501,1,250,206,0,-98},
{17,251,1,248,211,0,-93},
{17,1,1,248,215,0,-89},
{18,247,1754,246,218,0,-86},
{18,1,1754,244,220,0,-82},
{18,245,1527,244,223,0,-79},
{18,1,1527,242,225,0,-77},
{18,243,1297,242,226,0,-76},
{18,1,1297,240,228,0,-74},
{18,243,1058,240,231,0,-71},
{18,1,1058,240,237,0,-65},
{18,241,808,238,243,0,-59},
{18,1,808,238,248,0,-54},
{18,241,548,238,253,0,-47},
{18,1,548,238,258,0,-42},
{18,239,279,236,263,0,-37},
{18,1,279,236,267,0,-33},
{18,239,1,236,272,0,-28},
{18,1,1,236,276,0,-24},
{19,440,611,234,281,0,-19},
{19,1486,316,234,284,0,-16},
{19,1637,1720,234,247,0,-53},
{19,1401,1720,234,252,0,-48},
{19,1165,1720,234,257,0,-43},
{19,931,1720,232,261,0,-39},
{19,1,1720,232,265,0,-35},
{19,372,1447,232,270,0,-30},
{19,598,895,232,274,0,-26},
{19,882,611,232,278,0,-22},
{19,1,611,232,282,0,-18},
{19,1252,316,232,285,0,-15},
{19,426,316,230,289,0,-11},
{19,1,316,230,293,0,-7},
{19,1557,1,230,297,0,-3},
{19,1128,1,230,300,0,0},
{19,697,1,230,304,0,4},
{19,465,1,230,307,0,7},
{19,233,1,230,310,0,10},
{19,1,1,230,313,0,13},
{19,699,1720,230,263,0,-37},
{19,467,1720,230,264,0,-36},
{19,235,1720,230,265,0,-35},
{19,1754,1447,230,266,0,-34},
{19,1522,1447,230,267,0,-33},
{19,1290,1447,230,268,0,-32},
{19,1060,1447,228,269,0,-31},
{19,606,1447,226,270,0,-30},
{19,834,1447,224,270,0,-30},
{19,1207,1172,220,271,0,-29},
{19,214,1172,218,272,0,-28},
{19,1640,895,214,273,0,-27},
{19,1,1172,211,273,1,-25},
{19,832,895,209,274,3,-24},
{19,1116,611,206,277,6,-21},
{19,676,611,204,279,8,-17},
{19,235,611,203,282,13,-14},
{19,1722,316,201,283,17,-11},
{19,1051,316,199,286,21,-8},
{19,853,316,196,288,24,-4},
{19,658,316,193,289,27,-1},
{19,233,316,191,293,27,3},
{19,1789,1,194,297,24,9},
{19,1360,1,195,300,21,14},
{19,929,1,197,303,17,19},
{19,1525,611,198,276,14,-6},
{19,1324,611,199,276,11,-4},
{19,1725,611,194,276,4,-2},
{19,400,895,196,275,2,-1},
{19,201,895,197,275,1,1},
{19,1043,895,197,274,-1,2},
{19,1,895,198,275,-2,3},
{19,1242,895,197,274,-3,4},
{19,1441,895,197,274,-3,6},
{19,434,1172,196,272,-4,8},
{19,632,1172,194,272,-4,8},
{19,828,1172,192,272,-4,10},
{19,1856,895,190,272,-4,10},
{19,1429,1172,188,271,-4,11},
{19,1619,1172,185,271,-3,11},
{19,1022,1172,183,272,-3,12},
{19,187,1447,183,271,-5,13},
{19,1806,1172,184,271,-8,13},
{19,1,1447,184,271,-10,13},
{20,364,1,183,271,-13,13},
{20,549,1,183,271,-15,13},
{20,734,1,182,271,-18,13},
{20,918,1,181,271,-21,13},
{20,1101,1,181,271,-23,13},
{20,1459,1,180,270,-26,14},
{20,1819,1,179,268,-29,20},
{20,1284,1,173,271,-35,23},
{20,1641,1,176,270,-34,28},
{20,184,1,178,273,-32,31},
{20,1,1,181,275,-29,33},
{20,379,278,183,171,-27,143},
{20,191,278,186,172,-26,146},
{20,1,278,188,172,-22,150},
{20,1354,278,190,152,-20,132},
{20,1160,278,192,153,-18,137},
{20,1743,278,194,149,-16,135},
{20,1546,278,195,151,-13,139},
{20,962,278,196,155,-12,145},
{20,764,278,196,158,-10,150},
{20,564,278,198,159,-8,155},
{20,213,452,199,137,-7,185},
{20,1306,452,187,117,7,167},
{20,1547,452,186,115,8,169},
{20,1410,597,186,105,10,165},
{20,930,711,186,99,12,161},
{20,776,816,184,92,14,158},
{20,2045,1453,2,2,0,0},
}}
local ccIntroHigh={pixels=272,pages=P,tiles={
{20,2046,1539,1,1,1,-1},
{20,1759,2016,37,14,-7,0},
{20,1504,1926,72,30,-14,0},
{20,1157,1926,128,43,-24,1},
{20,265,1858,182,65,-34,-3},
{20,455,597,193,109,-37,-15},
{20,816,452,216,133,-38,-13},
{20,589,452,225,136,-43,4},
{20,1,452,210,143,-40,-1},
{20,414,452,173,137,-33,7},
{20,1167,452,137,124,-19,20},
{20,1034,452,131,130,-15,10},
{20,216,597,130,110,-16,16},
{20,355,711,129,101,-17,7},
{20,962,816,128,92,-18,0},
{20,964,1006,129,89,-17,1},
{20,305,1189,129,87,-17,1},
{20,961,1279,131,85,-17,1},
}}
local ccFlowHigh={pixels=272,pages=P,bands={
{
{20,1340,1279,103,85,-1,1},
{20,563,1189,105,87,-1,1},
{20,1535,1006,107,89,-1,1},
{20,1095,1006,108,89,0,1},
{20,1110,912,109,91,-1,1},
{20,886,912,110,91,0,1},
{20,773,912,111,91,-1,1},
{20,115,912,111,92,-1,0},
{20,228,912,111,92,-1,0},
{20,341,912,111,92,-1,0},
{20,998,912,110,91,0,1},
{20,1221,912,109,91,-1,1},
{20,1332,912,109,91,-1,1},
{20,1205,1006,108,89,0,1},
{20,1644,1006,107,89,-1,1},
{20,1862,1006,106,89,0,1},
{20,1244,1098,106,88,0,0},
{20,670,1189,105,87,-1,1},
{20,777,1189,105,87,-1,1},
{20,884,1189,105,87,-1,1},
{20,991,1189,105,87,-1,1},
{20,1352,1098,106,88,0,0},
{20,1460,1098,106,88,0,0},
{20,1,1098,106,89,0,1},
{20,109,1098,106,89,0,1},
{20,1753,1006,107,89,-1,1},
{20,1315,1006,108,89,0,1},
{20,335,1006,108,90,0,0},
{20,445,1006,108,90,0,0},
{20,555,1006,108,90,0,0},
{20,1425,1006,108,89,0,1},
{20,217,1098,106,89,0,1},
{20,1568,1098,106,88,0,0},
{20,1205,1189,104,87,0,1},
{20,1550,1279,102,85,0,1},
{20,994,1367,102,84,0,0},
{20,430,1453,100,83,0,1},
{20,405,1539,98,82,0,0},
{20,1045,1539,98,81,0,1},
{20,199,1623,96,80,0,0},
{20,1180,1623,94,79,0,1},
{20,1276,1623,94,79,0,1},
{20,1344,1539,94,81,0,-1},
{20,689,1623,94,80,0,0},
{20,1372,1623,94,79,0,1},
{20,1468,1623,94,79,0,1},
{20,297,1623,96,80,0,0},
{20,1245,1539,97,81,-1,1},
{20,505,1539,98,82,0,0},
{20,1,1539,99,82,-1,0},
{20,1,1453,100,84,0,0},
{20,1722,1367,101,84,-1,0},
{20,1654,1279,102,85,0,1},
{20,751,1279,103,86,-1,0},
{20,112,1279,105,86,-1,0},
{20,1098,1189,105,87,-1,1},
{20,1892,1098,105,88,-1,0},
{20,1,1189,105,88,-1,0},
{20,219,1279,105,86,-1,0},
{20,433,1279,104,86,-2,0},
{20,856,1279,103,86,-1,0},
{20,1445,1279,103,85,-1,1},
{20,364,1367,103,84,-1,0},
{20,469,1367,103,84,-1,0},
{20,574,1367,103,84,-1,0},
{20,679,1367,103,84,-1,0},
{20,784,1367,103,84,-1,0},
{20,539,1279,104,86,-2,0},
{20,326,1279,105,86,-1,0},
{20,1676,1098,106,88,-2,0},
{20,1026,1098,107,88,-1,0},
{20,665,1006,108,90,-2,0},
{20,113,1006,109,90,-1,0},
{20,1908,912,110,90,-2,0},
{20,1553,816,112,92,-2,0},
{20,1667,816,112,92,-2,0},
{20,1208,816,113,92,-1,0},
{20,1323,816,113,92,-1,0},
{20,1438,816,113,92,-1,0},
{20,1781,816,112,92,-2,0},
{20,1895,816,112,92,-2,0},
{20,1,912,112,92,-2,0},
{20,1,1006,110,90,-2,0},
{20,224,1006,109,90,-1,0},
{20,1135,1098,107,88,-1,0},
{20,1784,1098,106,88,-2,0},
{20,645,1279,104,86,-2,0},
{20,889,1367,103,84,-1,0},
{20,1098,1367,102,84,-2,0},
{20,1192,1453,101,82,-1,0},
{20,1501,1453,100,82,-2,0},
{20,1603,1453,100,82,-2,0},
{20,102,1539,99,82,-1,0},
{20,1705,1453,100,82,-2,0},
{20,1807,1453,100,82,-2,0},
{20,1909,1453,100,82,-2,0},
{20,1295,1453,101,82,-1,0},
{20,224,1453,101,83,-1,1},
{20,1825,1367,101,84,-1,0},
{20,1202,1367,102,84,-2,0},
{20,1306,1367,102,84,-2,0},
{20,1410,1367,102,84,-2,0},
{20,1514,1367,102,84,-2,0},
{20,1618,1367,102,84,-2,0},
{20,1928,1367,101,84,-1,0},
{20,327,1453,101,83,-1,1},
{20,1398,1453,101,82,-1,0},
{20,203,1539,99,82,-1,0},
{20,843,1539,99,81,-1,1},
{20,1145,1539,98,81,-2,1},
{20,1894,1539,97,80,-1,0},
{20,395,1623,96,80,-2,0},
{20,493,1623,96,80,-2,0},
{20,591,1623,96,80,-2,0},
{20,1,1623,97,80,-1,0},
{20,100,1623,97,80,-1,0},
{20,944,1539,99,81,-1,1},
{20,304,1539,99,82,-1,0},
{21,104,1,101,83,-1,1},
{21,1,1,101,84,-1,0},
},
{
{20,1907,2016,23,9,21,-5},
{20,2018,2016,16,4,14,0},
{20,2036,2016,9,4,7,0},
{20,2045,1858,1,1,1,-1},
{20,2044,597,1,1,1,-1},
{20,2042,452,1,1,1,-1},
{20,2045,452,1,1,1,-1},
{20,2040,1623,1,1,1,-1},
{20,2043,1623,1,1,1,-1},
{20,1861,2016,8,12,0,-8},
{20,538,1988,16,26,-2,-22},
{20,1129,1926,26,44,-2,-40},
{20,331,1926,34,59,-6,-53},
{20,1999,1098,39,80,-7,-56},
{20,2002,278,44,102,-8,-46},
{20,1495,452,50,117,-16,-27},
{20,1939,278,61,120,-21,-8},
{20,1735,452,69,115,-27,5},
{20,1484,711,71,97,-33,9},
{20,701,1705,69,75,-37,13},
{20,723,1926,63,49,-39,13},
{20,1607,1926,53,27,-39,9},
{20,1672,2016,41,17,-39,9},
{20,1871,2016,34,10,-32,4},
{20,1932,2016,27,8,-25,4},
{20,1985,2016,19,6,-17,2},
{20,2006,2016,10,5,-8,1},
{20,2046,1623,1,1,1,-1},
{20,2040,1098,6,5,-2,-1},
{20,1643,2016,17,21,1,9},
{20,1093,1926,34,46,8,28},
{20,1997,1189,49,70,13,42},
{20,1311,1189,60,87,16,49},
{20,108,1189,62,88,12,42},
{20,785,1623,59,80,7,28},
{20,1993,1539,51,66,1,12},
{20,1049,1926,42,46,-4,-4},
{20,609,1988,38,25,-4,-19},
{20,1610,2016,31,21,-3,-17},
{20,1715,2016,25,17,-3,-13},
{20,1827,2016,18,13,-2,-9},
{20,1961,2016,10,8,0,-4},
{20,2040,1926,1,1,1,-1},
{20,2043,1926,1,1,1,-1},
{20,2046,1926,1,1,1,-1},
{20,1,2043,1,1,1,-1},
{20,4,2043,1,1,1,-1},
{20,1847,2016,12,13,-8,-9},
{20,1470,1926,32,31,-16,-23},
{20,788,1926,53,49,-19,-33},
{20,1794,1858,72,61,-14,-37},
{20,707,1858,85,65,1,-31},
{20,119,1926,89,60,19,-20},
{20,367,1926,89,57,39,1},
{20,517,1926,90,55,52,25},
{20,1769,1784,97,67,53,27},
{20,210,1705,94,77,52,27},
{20,1564,1623,85,79,49,21},
{20,1965,1623,73,77,47,13},
{20,891,1784,62,70,44,6},
{20,1868,1858,52,61,38,-1},
{20,843,1926,40,49,28,-7},
{20,1396,1926,27,35,19,-13},
{20,467,2016,18,25,14,-15},
{20,1742,2016,15,17,11,-15},
{20,1184,2016,11,24,7,2},
{20,1376,1926,18,37,10,25},
{20,2020,912,25,52,17,44},
{20,2009,816,29,68,21,48},
{20,2011,1453,32,79,18,33},
{20,2000,1,46,86,12,6},
{20,1970,1006,61,89,9,-23},
{20,725,711,85,101,-3,-35},
{20,110,597,104,112,-14,-42},
{20,1922,452,118,112,-26,-44},
{20,1598,597,121,105,-35,-41},
{20,122,816,115,94,-37,-36},
{20,1088,1453,102,82,-34,-32},
{20,1248,1705,87,74,-29,-32},
{20,1964,1784,68,64,-24,-32},
{20,609,1926,54,53,-24,-31},
{20,1334,1926,40,41,-26,-29},
{20,1578,1926,27,30,-25,-26},
{20,2028,1988,19,25,-15,-13},
{20,1587,2016,21,22,-15,4},
{20,649,1988,34,25,-24,17},
{20,1425,1926,43,34,-29,26},
{20,1287,1926,45,42,-31,34},
{20,1005,1926,42,47,-28,41},
{20,665,1926,35,50,-21,46},
{20,2020,1279,27,51,-13,47},
{20,964,1926,19,48,-7,44},
{20,702,1926,19,50,-9,48},
{20,2027,1705,19,51,-9,49},
{20,985,1926,18,48,-10,46},
{20,2031,1367,15,43,-9,41},
{20,2033,1006,14,38,-8,36},
{20,2034,1784,11,32,-7,30},
{20,487,2016,10,25,-6,23},
{20,1662,2016,8,18,-4,16},
{20,2040,816,6,10,-2,8},
{20,7,2043,1,1,1,-1},
{20,10,2043,1,1,1,-1},
{20,1973,2016,10,7,6,-3},
{20,1798,2016,27,13,9,-7},
{20,556,1988,51,25,11,-7},
{20,885,1926,77,48,7,-6},
{20,1710,1705,101,73,3,-9},
{20,685,1098,119,88,1,-12},
{20,1775,912,131,90,-3,-6},
{20,754,597,127,108,-11,-6},
{20,1806,452,114,113,-16,3},
{20,1210,597,99,107,-15,17},
{20,1947,597,95,101,-1,19},
{20,555,912,87,92,11,18},
{20,532,1453,78,83,18,15},
{20,1956,1705,69,71,21,13},
{20,458,1926,57,57,23,7},
{21,453,1,44,41,26,3},
{21,69,87,31,24,27,-2},
},
{
{20,1536,1784,126,68,-24,-2},
{20,210,1926,119,59,-17,-13},
{20,1922,1858,121,60,-17,-14},
{20,1426,1858,123,62,-19,-14},
{20,1050,1858,125,63,-19,-15},
{20,794,1858,127,64,-21,-16},
{20,134,1858,129,66,-21,-16},
{20,1664,1784,103,67,5,-17},
{20,1093,1784,106,69,4,-19},
{20,328,1784,108,71,2,-19},
{20,1,1784,111,72,1,-20},
{20,1482,1705,113,73,-1,-21},
{20,1,1926,116,60,-2,-8},
{20,1674,1858,118,62,-4,-8},
{20,1551,1858,121,62,-5,-8},
{20,1177,1858,123,63,-7,-7},
{20,579,1858,126,65,-8,-7},
{20,449,1858,128,65,-10,-7},
{20,1,1858,131,66,-11,-6},
{20,1401,1784,133,68,-13,-6},
{20,955,1784,136,69,-14,-5},
{20,540,1784,138,70,-16,-4},
{20,1813,1705,141,72,-17,-4},
{20,1337,1705,143,73,-19,-3},
{20,772,1705,145,74,-19,-2},
{20,306,1705,116,76,10,0},
{20,1,1705,110,77,16,1},
{20,961,1623,112,79,16,1},
{20,1558,1539,113,80,15,2},
{20,726,1539,115,81,15,3},
{20,854,1453,116,82,14,4},
{20,103,1453,119,83,13,5},
{20,127,1367,121,84,11,6},
{20,1094,1279,124,85,10,7},
{20,1504,1189,126,86,8,8},
{20,1373,1189,129,86,7,8},
{20,172,1189,131,87,5,9},
{20,419,1098,133,88,5,10},
{20,1638,912,135,90,3,10},
{20,644,912,127,91,-9,11},
{20,1092,816,114,92,-26,12},
{20,446,816,117,93,-27,13},
{20,1,816,119,94,-27,14},
{20,1925,711,122,95,-28,15},
{20,1686,711,125,96,-29,16},
{20,1557,711,127,96,-29,16},
{20,1236,711,131,98,-29,16},
{20,812,711,116,100,-12,16},
{20,235,711,118,102,-12,16},
{20,1,711,116,103,-16,15},
{20,1721,597,106,105,-30,15},
{20,986,597,121,107,-19,15},
{20,1868,1784,94,67,-48,5},
{20,348,816,96,94,-50,32},
{20,1302,1784,97,69,-51,5},
{20,1201,1784,99,69,-51,5},
{20,787,1784,102,70,-52,4},
{20,680,1784,105,70,-51,4},
{20,438,1784,100,71,-42,5},
{20,223,1784,103,72,-43,4},
{20,114,1784,107,72,-43,4},
{20,1597,1705,111,73,-43,5},
{20,919,1705,114,74,-44,4},
{20,1143,1705,103,74,-29,4},
{20,1035,1705,106,74,-30,4},
{20,611,1705,88,76,-8,4},
{20,519,1705,90,76,-6,4},
{20,424,1705,93,76,-5,4},
{20,113,1705,95,77,-3,3},
{20,1866,1623,97,78,-3,4},
{20,1764,1623,100,78,-2,4},
{20,1075,1623,103,79,-3,3},
{20,1785,1539,107,80,-3,4},
{20,1673,1539,110,80,-4,4},
{20,972,1453,114,82,-4,4},
{20,735,1453,117,82,-5,4},
{20,612,1453,121,82,-5,4},
{20,1,1367,124,84,-4,4},
{20,1891,1279,127,84,-5,4},
{20,1758,1279,131,84,-5,4},
{20,1,1279,109,86,-29,4},
{20,250,1367,112,84,-30,2},
{20,1880,1189,115,86,-31,4},
{20,1220,1279,118,85,-30,1},
{20,1757,1189,121,86,-31,2},
{20,1632,1189,123,86,-31,2},
{20,436,1189,125,87,-31,1},
{20,554,1098,129,88,-31,2},
{20,806,1098,108,88,-8,2},
{20,325,1098,92,89,-26,1},
{20,870,1006,92,90,-24,0},
{20,775,1006,93,90,-25,2},
{20,1542,912,94,91,-24,1},
{20,1443,912,97,91,-25,1},
{20,454,912,99,92,-27,2},
{20,672,816,102,93,-28,1},
{20,565,816,105,93,-29,1},
{20,239,816,107,94,-31,2},
{20,1813,711,110,96,-32,2},
{20,1369,711,113,97,-33,3},
{20,1118,711,116,99,-34,3},
{20,606,711,117,101,-35,5},
{20,486,711,118,101,-38,5},
{20,119,711,114,103,-28,5},
{20,1829,597,116,104,-30,6},
{20,1311,597,97,106,-13,6},
{20,1109,597,99,107,-13,7},
{20,883,597,101,108,-13,6},
{20,650,597,102,109,-14,7},
{20,348,597,105,110,-15,8},
{20,1,597,107,112,-15,8},
{20,916,1098,108,88,-16,34},
{20,1651,1623,111,78,-17,24},
{20,846,1623,113,79,-17,23},
{20,1440,1539,116,80,-16,24},
{20,605,1539,119,81,-17,23},
{20,1302,1858,122,63,-16,3},
{20,923,1858,125,64,-17,2},
{21,333,1,118,53,-8,-11},
{21,207,1,124,67,-24,-1},
},
{
{20,1938,1926,32,26,0,0},
{20,1972,1926,32,26,0,0},
{20,2006,1926,32,26,0,0},
{20,1,1988,32,26,0,0},
{20,35,1988,32,26,0,0},
{20,69,1988,32,26,0,0},
{20,307,1988,31,26,1,0},
{20,340,1988,31,26,1,0},
{20,685,1988,31,25,1,1},
{20,718,1988,31,25,1,1},
{20,751,1988,31,25,1,1},
{20,784,1988,31,25,1,1},
{20,817,1988,31,25,1,1},
{20,850,1988,31,25,1,1},
{20,883,1988,31,25,1,1},
{20,916,1988,31,25,1,1},
{20,949,1988,31,25,1,1},
{20,982,1988,31,25,1,1},
{20,1015,1988,31,25,1,1},
{20,1048,1988,31,25,1,1},
{20,1081,1988,31,25,1,1},
{20,1114,1988,31,25,1,1},
{20,1147,1988,31,25,1,1},
{20,1180,1988,31,25,1,1},
{20,1213,1988,31,25,1,1},
{20,1246,1988,31,25,1,1},
{20,1279,1988,31,25,1,1},
{20,1708,1988,30,25,2,1},
{20,33,2016,29,25,1,1},
{20,64,2016,29,25,1,1},
{20,1197,2016,28,23,2,1},
{20,1227,2016,28,23,2,1},
{20,1257,2016,28,23,2,1},
{20,1287,2016,28,23,2,1},
{20,1317,2016,28,23,2,1},
{20,1347,2016,28,23,2,1},
{20,1377,2016,28,23,2,1},
{20,1407,2016,28,23,2,1},
{20,1437,2016,28,23,2,1},
{20,1467,2016,28,23,2,1},
{20,1034,2016,28,24,2,0},
{20,755,2016,29,24,1,0},
{20,786,2016,29,24,1,0},
{20,95,2016,29,25,1,1},
{20,1312,1988,31,25,1,1},
{20,1345,1988,31,25,1,1},
{20,1378,1988,31,25,1,1},
{20,1411,1988,31,25,1,1},
{20,1444,1988,31,25,1,1},
{20,1477,1988,31,25,1,1},
{20,1510,1988,31,25,1,1},
{20,1543,1988,31,25,1,1},
{20,1740,1988,30,25,0,1},
{20,499,2016,30,24,0,0},
{20,531,2016,30,24,0,0},
{20,563,2016,30,24,0,0},
{20,595,2016,30,24,0,0},
{20,627,2016,30,24,0,0},
{20,659,2016,30,24,0,0},
{20,1772,1988,30,25,0,-1},
{20,1804,1988,30,25,0,-1},
{20,1836,1988,30,25,0,-1},
{20,373,1988,31,26,-1,0},
{20,103,1988,32,26,0,0},
{20,137,1988,32,26,0,0},
{20,171,1988,32,26,0,0},
{20,205,1988,32,26,0,0},
{20,1802,1926,32,27,0,-1},
{20,1836,1926,32,27,0,-1},
{20,1662,1926,33,27,-1,-1},
{20,1697,1926,33,27,-1,-1},
{20,1732,1926,33,27,-1,-1},
{20,1767,1926,33,27,-1,-1},
{20,1870,1926,32,27,0,-1},
{20,1904,1926,32,27,0,-1},
{20,406,1988,31,26,-1,0},
{20,1576,1988,31,25,-1,-1},
{20,1609,1988,31,25,-1,-1},
{20,1642,1988,31,25,-1,-1},
{20,1675,1988,31,25,-1,-1},
{20,126,2016,29,25,-1,-1},
{20,157,2016,29,25,-1,-1},
{20,188,2016,29,25,-1,-1},
{20,219,2016,29,25,-1,-1},
{20,817,2016,29,24,-1,0},
{20,250,2016,29,25,-1,-1},
{20,281,2016,29,25,-1,-1},
{20,312,2016,29,25,-1,-1},
{20,343,2016,29,25,-1,-1},
{20,374,2016,29,25,-1,-1},
{20,405,2016,29,25,-1,-1},
{20,1868,1988,30,25,-2,-1},
{20,1900,1988,30,25,-2,-1},
{20,1932,1988,30,25,-2,-1},
{20,1964,1988,30,25,-2,-1},
{20,1996,1988,30,25,-2,-1},
{20,1,2016,30,25,-2,-1},
{20,436,2016,29,25,-1,-1},
{20,848,2016,29,24,-1,0},
{20,879,2016,29,24,-1,0},
{20,910,2016,29,24,-1,0},
{20,1064,2016,28,24,-2,0},
{20,1094,2016,28,24,-2,0},
{20,1497,2016,28,23,-2,-1},
{20,1527,2016,28,23,-2,-1},
{20,1557,2016,28,23,-2,-1},
{20,1124,2016,28,24,-2,0},
{20,1154,2016,28,24,-2,0},
{20,941,2016,29,24,-1,0},
{20,972,2016,29,24,-1,0},
{20,1003,2016,29,24,-1,0},
{20,691,2016,30,24,0,0},
{20,723,2016,30,24,0,0},
{20,439,1988,31,26,-1,0},
{20,472,1988,31,26,-1,0},
{20,505,1988,31,26,-1,0},
{20,239,1988,32,26,0,0},
{20,273,1988,32,26,0,0},
{21,1,87,32,26,0,0},
{21,35,87,32,26,0,0},
},
}}
E.RejuvenationPrecastFlowBanks={[192]=precastLow,[288]=precastLow,[384]=precastHigh,[480]=precastHigh,[576]=precastHigh,[660]=precastHigh}
E.RejuvenationPrecastLengths={intro=40,hold=144,ending=54}
E.RejuvImpactBanks={{[192]=impact1Low,[288]=impact1Low,[384]=impact1High,[480]=impact1High,[576]=impact1High,[660]=impact1High},{[192]=impact2Low,[288]=impact2Low,[384]=impact2High,[480]=impact2High,[576]=impact2High,[660]=impact2High}}
E.ClearcastingFlare={
intro=18,hold=120,ending=36,
introBank={[192]=ccIntroLow,[288]=ccIntroLow,[384]=ccIntroHigh,[480]=ccIntroHigh,[576]=ccIntroHigh,[660]=ccIntroHigh},
holdBank={[192]=ccFlowLow,[288]=ccFlowLow,[384]=ccFlowHigh,[480]=ccFlowHigh,[576]=ccFlowHigh,[660]=ccFlowHigh}, release={
{1.0000000,0.9983382,0.9940525,0.9881924,0.9818076,0.9759475,0.9716618,0.9700000,0.9624400,0.9419200,0.9116800,0.8749600,0.8350000,0.7950400,0.7583200,0.7280800,0.7075600,0.7000000,0.6910400,0.6667200,0.6308800,0.5873600,0.5400000,0.4926400,0.4491200,0.4132800,0.3889600,0.3800000,0.3669685,0.3320439,0.2814815,0.2215364,0.1584636,0.0985185,0.0479561,0.0130315,0.0000000},
{1.0000000,0.9953125,0.9850000,0.9746875,0.9700000,0.9561516,0.9204373,0.8716035,0.8183965,0.7695627,0.7338484,0.7200000,0.7074000,0.6732000,0.6228000,0.5616000,0.4950000,0.4284000,0.3672000,0.3168000,0.2826000,0.2700000,0.2607407,0.2359259,0.2000000,0.1574074,0.1125926,0.0700000,0.0340741,0.0092593,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000},
{1.0000000,0.9988921,0.9960350,0.9921283,0.9878717,0.9839650,0.9811079,0.9800000,0.9716153,0.9486251,0.9142750,0.8718107,0.8244779,0.7755222,0.7281893,0.6857250,0.6513749,0.6283846,0.6200000,0.6115394,0.5881482,0.5528125,0.5085185,0.4582523,0.4050000,0.3517477,0.3014815,0.2571875,0.2218519,0.1984607,0.1900000,0.1759259,0.1407407,0.0950000,0.0492593,0.0140741,0.0000000},
{1.0000000,0.9911111,0.9688889,0.9400000,0.9111111,0.8888889,0.8800000,0.8622222,0.8177778,0.7600000,0.7022222,0.6577778,0.6400000,0.6306837,0.6051390,0.5669722,0.5197896,0.4671976,0.4128024,0.3602104,0.3130278,0.2748610,0.2493163,0.2400000,0.2344102,0.2190834,0.1961833,0.1678738,0.1363186,0.1036814,0.0721262,0.0438167,0.0209166,0.0055898,0.0000000,0.0000000,0.0000000},
}}

local addedLow={
{"StudioDruidRestorationSize288Page4.tga",1024,2048},
}
local moonlightGlowIntroLow={pixels=112,pages=addedLow,tiles={
{1,1022,933,1,1,1,-1},
{1,1010,1,8,8,0,0},
{1,1007,776,16,14,0,0},
{1,702,2012,20,18,0,0},
{1,348,1933,28,26,0,0},
{1,892,1819,38,36,0,0},
{1,446,1501,50,46,0,0},
{1,526,1440,60,56,0,0},
{1,826,1376,66,60,0,0},
{1,77,1376,68,62,0,0},
{1,605,1305,69,64,-1,0},
{1,373,1305,72,66,0,0},
{1,81,1305,74,68,0,0},
{1,945,1010,78,72,0,0},
{1,527,1010,80,73,0,1},
}}
local moonlightGlowHoldLow={pixels=112,pages=addedLow,bands={
{
{1,912,933,80,74,0,0},
{1,339,933,80,75,0,1},
{1,87,933,82,75,0,1},
{1,171,933,82,75,0,1},
{1,689,855,82,76,0,0},
{1,773,855,82,76,0,0},
{1,349,855,83,76,1,0},
{1,434,855,83,76,1,0},
{1,177,855,84,76,0,0},
{1,610,697,84,77,0,1},
{1,702,617,85,77,1,1},
{1,789,617,85,77,1,1},
{1,876,617,85,77,1,1},
{1,1,697,85,77,1,1},
{1,88,697,85,77,1,1},
{1,86,617,86,77,0,1},
{1,174,617,86,77,0,1},
{1,262,617,86,77,0,1},
{1,350,617,86,77,0,1},
{1,780,776,86,76,0,0},
{1,513,776,87,76,1,0},
{1,602,776,87,76,1,0},
{1,691,776,87,76,1,0},
{1,868,776,86,76,0,0},
{1,1,855,86,76,0,0},
{1,89,855,86,76,0,0},
{1,857,855,86,75,0,1},
{1,473,933,86,74,0,0},
{1,561,933,86,74,0,0},
{1,649,933,86,74,0,0},
{1,737,933,86,74,0,0},
{1,825,933,85,74,1,0},
{1,356,1010,85,73,1,-1},
{1,773,1010,84,72,0,0},
{1,859,1010,84,72,0,0},
{1,1,1086,84,72,0,0},
{1,87,1086,84,72,0,0},
{1,173,1086,83,72,-1,0},
{1,1,1160,82,71,0,-1},
{1,85,1160,82,71,0,-1},
{1,169,1160,82,71,0,-1},
{1,253,1160,82,71,0,-1},
{1,417,1160,81,70,-1,0},
{1,500,1160,81,70,-1,0},
{1,583,1160,80,70,0,0},
{1,665,1160,80,70,0,0},
{1,747,1160,80,70,0,0},
{1,829,1160,79,70,-1,0},
{1,910,1160,79,70,-1,0},
{1,1,1233,79,70,-1,0},
{1,82,1233,79,70,-1,0},
{1,163,1233,78,70,0,0},
{1,243,1233,78,70,0,0},
{1,323,1233,78,70,0,0},
{1,403,1233,77,70,-1,0},
{1,482,1233,77,70,-1,0},
{1,561,1233,77,70,-1,0},
{1,640,1233,77,70,-1,0},
{1,719,1233,77,70,-1,0},
{1,798,1233,77,70,-1,0},
{1,337,1160,78,71,0,-1},
{1,585,1086,78,72,0,0},
{1,665,1086,78,72,0,0},
{1,745,1086,78,72,0,0},
{1,825,1086,78,72,0,0},
{1,342,1086,79,72,-1,0},
{1,423,1086,79,72,-1,0},
{1,504,1086,79,72,-1,0},
{1,609,1010,80,73,0,1},
{1,1,1010,80,74,0,0},
{1,83,1010,80,74,0,0},
{1,165,1010,80,74,0,0},
},
{
{1,277,1778,43,39,1,1},
{1,322,1778,43,39,1,1},
{1,925,1736,44,39,2,1},
{1,971,1736,44,39,2,1},
{1,1,1778,44,39,2,1},
{1,47,1778,44,39,2,1},
{1,93,1778,44,39,2,1},
{1,139,1778,44,39,2,1},
{1,185,1778,44,39,2,1},
{1,231,1778,44,39,2,-1},
{1,978,1305,45,39,3,-1},
{1,831,1736,45,39,3,-1},
{1,878,1736,45,39,3,-1},
{1,639,1736,46,39,2,-1},
{1,687,1736,46,39,2,-1},
{1,635,1778,46,38,2,-2},
{1,683,1778,46,38,2,-2},
{1,731,1778,46,38,2,-2},
{1,779,1778,46,38,2,-2},
{1,827,1778,46,38,2,-2},
{1,875,1778,46,38,2,-2},
{1,174,1819,46,37,2,-3},
{1,222,1819,46,37,2,-3},
{1,270,1819,45,37,1,-3},
{1,360,1819,45,36,1,-2},
{1,407,1819,45,36,1,-2},
{1,454,1819,45,36,1,-2},
{1,932,1819,45,35,1,-3},
{1,1,1859,45,35,1,-3},
{1,48,1859,45,35,1,-3},
{1,979,1819,44,35,0,-3},
{1,95,1859,44,35,0,-3},
{1,141,1859,44,35,0,-3},
{1,187,1859,44,35,0,-3},
{1,233,1859,44,35,0,-3},
{1,279,1859,44,35,0,-3},
{1,325,1859,43,35,-1,-3},
{1,370,1859,43,35,-1,-3},
{1,415,1859,43,35,-1,-3},
{1,460,1859,43,35,-1,-3},
{1,505,1859,43,35,-1,-3},
{1,550,1859,42,35,-2,-3},
{1,594,1859,42,35,-2,-3},
{1,638,1859,42,35,-2,-3},
{1,682,1859,42,35,-2,-3},
{1,726,1859,42,35,-2,-3},
{1,770,1859,42,35,-2,-3},
{1,547,1819,42,36,-2,-2},
{1,814,1859,42,35,-2,-1},
{1,858,1859,41,35,-3,-1},
{1,901,1859,41,35,-3,-1},
{1,944,1859,41,35,-3,-1},
{1,1,1896,41,35,-3,-1},
{1,635,1819,41,36,-3,0},
{1,678,1819,41,36,-3,0},
{1,591,1819,42,36,-2,0},
{1,721,1819,41,36,-1,0},
{1,764,1819,41,36,-1,0},
{1,807,1819,41,36,-1,0},
{1,317,1819,41,37,-1,-1},
{1,45,1819,41,38,-1,0},
{1,88,1819,41,38,-1,0},
{1,131,1819,41,38,-1,0},
{1,923,1778,42,38,0,0},
{1,967,1778,42,38,0,0},
{1,1,1819,42,38,0,0},
{1,547,1778,42,39,0,1},
{1,591,1778,42,39,0,1},
{1,367,1778,43,39,1,1},
{1,412,1778,43,39,1,1},
{1,457,1778,43,39,1,1},
{1,502,1778,43,39,1,1},
},
{
{1,581,1961,26,24,0,0},
{1,609,1961,26,24,0,0},
{1,637,1961,26,24,0,0},
{1,665,1961,26,24,0,0},
{1,436,1961,27,24,1,0},
{1,465,1961,27,24,1,0},
{1,494,1961,27,24,1,0},
{1,523,1961,27,24,1,0},
{1,552,1961,27,24,1,0},
{1,250,1987,27,23,1,1},
{1,279,1987,27,23,1,1},
{1,308,1987,27,23,1,1},
{1,337,1987,27,23,1,1},
{1,366,1987,27,23,1,1},
{1,395,1987,27,23,1,1},
{1,511,1987,26,23,2,1},
{1,567,1987,25,23,1,1},
{1,594,1987,25,23,1,1},
{1,621,1987,25,23,1,1},
{1,648,1987,25,23,1,1},
{1,675,1987,25,23,1,1},
{1,702,1987,25,23,1,1},
{1,370,2012,24,22,2,0},
{1,396,2012,24,22,2,0},
{1,578,2012,23,22,1,0},
{1,603,2012,23,22,1,0},
{1,628,2012,23,22,1,0},
{1,653,2012,23,22,1,0},
{1,422,2012,24,22,0,0},
{1,448,2012,24,22,0,0},
{1,474,2012,24,22,0,0},
{1,500,2012,24,22,0,0},
{1,526,2012,24,22,0,0},
{1,316,2012,25,22,1,0},
{1,343,2012,25,22,1,0},
{1,997,1987,26,22,0,0},
{1,204,2012,26,22,0,0},
{1,232,2012,26,22,0,0},
{1,260,2012,26,22,0,0},
{1,288,2012,26,22,0,0},
{1,968,1987,27,22,-1,0},
{1,1,2012,27,22,-1,0},
{1,30,2012,27,22,-1,0},
{1,59,2012,27,22,-1,0},
{1,88,2012,27,22,-1,0},
{1,117,2012,27,22,-1,0},
{1,146,2012,27,22,-1,0},
{1,175,2012,27,22,-1,0},
{1,424,1987,27,23,-1,-1},
{1,453,1987,27,23,-1,-1},
{1,482,1987,27,23,-1,-1},
{1,539,1987,26,23,-2,-1},
{1,729,1987,25,23,-1,-1},
{1,756,1987,25,23,-1,-1},
{1,783,1987,25,23,-1,-1},
{1,810,1987,25,23,-1,-1},
{1,837,1987,25,23,-1,-1},
{1,864,1987,25,23,-1,-1},
{1,891,1987,24,23,-2,-1},
{1,917,1987,24,23,-2,-1},
{1,943,1987,23,23,-1,-1},
{1,852,1961,23,24,-1,0},
{1,877,1961,23,24,-1,0},
{1,902,1961,23,24,-1,0},
{1,999,105,24,24,0,0},
{1,748,1961,24,24,0,0},
{1,774,1961,24,24,0,0},
{1,800,1961,24,24,0,0},
{1,826,1961,24,24,0,0},
{1,998,855,25,24,-1,0},
{1,721,1961,25,24,-1,0},
{1,693,1961,26,24,0,0},
},
}}
local natureGlowIntroLow={pixels=112,pages=addedLow,tiles={
{1,1022,1440,1,1,1,-1},
{1,1018,205,5,4,-1,0},
{1,1011,1778,12,10,0,0},
{1,1004,1647,18,17,0,1},
{1,678,2012,22,20,0,0},
{1,552,2012,24,22,0,0},
{1,991,1692,30,28,0,0},
{1,850,1819,40,36,0,0},
{1,498,1501,50,46,0,0},
{1,660,1440,61,55,-1,1},
{1,754,1305,71,63,-1,1},
{1,1,1305,78,69,0,1},
{1,691,1010,80,73,0,1},
{1,443,1010,82,73,0,1},
{1,1,933,84,75,0,1},
{1,438,617,86,77,0,1},
}}
local natureGlowHoldLow={pixels=112,pages=addedLow,bands={
{
{1,365,455,88,79,0,1},
{1,455,455,88,79,0,1},
{1,545,455,88,79,0,1},
{1,635,455,88,79,0,1},
{1,1,455,89,79,1,1},
{1,92,455,89,79,1,1},
{1,183,455,89,79,1,1},
{1,274,455,89,79,1,1},
{1,796,372,89,80,1,0},
{1,1,289,90,81,2,1},
{1,93,289,90,81,2,1},
{1,185,289,90,81,2,1},
{1,277,289,90,81,2,1},
{1,369,289,90,81,2,1},
{1,461,289,90,81,2,1},
{1,553,289,90,81,2,1},
{1,1,205,90,82,2,0},
{1,93,205,90,82,2,0},
{1,185,205,90,82,2,0},
{1,277,205,90,82,2,0},
{1,369,205,90,82,2,0},
{1,461,205,90,82,2,0},
{1,553,205,90,82,2,0},
{1,645,205,90,82,2,0},
{1,737,205,90,82,2,0},
{1,829,205,89,82,1,0},
{1,645,289,89,81,1,-1},
{1,736,289,89,81,1,-1},
{1,827,289,89,81,1,-1},
{1,918,289,89,81,1,-1},
{1,1,372,88,81,0,-1},
{1,91,372,87,81,1,-1},
{1,180,372,87,81,1,-1},
{1,269,372,87,81,1,-1},
{1,358,372,86,81,0,-1},
{1,446,372,86,81,0,-1},
{1,534,372,86,81,0,-1},
{1,622,372,86,81,0,-1},
{1,887,372,86,80,0,-2},
{1,725,455,85,79,-1,-1},
{1,812,455,85,79,-1,-1},
{1,899,455,85,79,-1,-1},
{1,1,536,85,79,-1,-1},
{1,88,536,85,79,-1,-1},
{1,175,536,84,79,-2,-1},
{1,261,536,83,79,-1,-1},
{1,346,536,83,79,-1,-1},
{1,783,536,83,78,-1,0},
{1,868,536,83,78,-1,0},
{1,1,617,83,78,-1,0},
{1,173,776,83,77,-1,-1},
{1,258,776,83,77,-1,-1},
{1,343,776,83,77,-1,-1},
{1,428,776,83,77,-1,-1},
{1,519,855,83,76,-1,0},
{1,604,855,83,76,-1,0},
{1,263,855,84,76,-2,0},
{1,696,697,84,77,-2,1},
{1,782,697,84,77,-2,1},
{1,868,697,84,77,-2,1},
{1,1,776,84,77,-2,1},
{1,87,776,84,77,-2,1},
{1,175,697,85,77,-1,1},
{1,262,697,85,77,-1,1},
{1,349,697,85,77,-1,1},
{1,436,697,85,77,-1,1},
{1,523,697,85,77,-1,1},
{1,526,617,86,77,0,1},
{1,614,617,86,77,0,1},
{1,609,536,86,78,0,2},
{1,431,536,87,78,-1,2},
{1,520,536,87,78,-1,2},
},
{
{1,718,1501,50,45,0,7},
{1,770,1501,50,45,0,7},
{1,550,1501,50,46,0,6},
{1,602,1501,50,46,0,6},
{1,822,1501,50,45,0,5},
{1,926,1501,49,45,1,5},
{1,1,1554,49,45,1,5},
{1,52,1554,49,45,1,3},
{1,103,1554,49,45,1,3},
{1,358,1554,48,45,2,3},
{1,274,1601,48,44,2,2},
{1,324,1601,48,44,2,2},
{1,453,1647,48,43,2,1},
{1,374,1601,48,44,2,0},
{1,674,1601,47,44,3,0},
{1,723,1601,47,44,3,0},
{1,772,1601,47,44,3,0},
{1,821,1601,47,44,3,0},
{1,703,1647,47,43,3,-1},
{1,752,1647,47,43,3,-1},
{1,801,1647,47,43,3,-1},
{1,870,1601,47,44,3,-2},
{1,919,1601,47,44,3,-2},
{1,424,1601,48,44,2,-2},
{1,474,1601,48,44,2,-2},
{1,503,1647,48,43,2,-3},
{1,553,1647,48,43,2,-3},
{1,603,1647,48,43,2,-3},
{1,249,1647,49,43,1,-3},
{1,300,1647,49,43,1,-3},
{1,351,1647,49,43,1,-3},
{1,402,1647,49,43,1,-3},
{1,968,1601,50,43,0,-3},
{1,1,1692,50,42,0,-4},
{1,483,1692,50,41,0,-3},
{1,535,1692,50,41,0,-3},
{1,587,1692,49,41,-1,-3},
{1,638,1692,49,41,-1,-3},
{1,689,1692,49,41,-1,-3},
{1,740,1692,49,41,-1,-3},
{1,791,1692,49,41,-1,-3},
{1,842,1692,48,41,-2,-3},
{1,941,1692,48,40,-2,-2},
{1,1,1736,48,40,-2,-2},
{1,51,1736,48,40,-2,-2},
{1,101,1736,47,40,-3,-2},
{1,150,1736,47,40,-3,-2},
{1,199,1736,47,40,-3,-2},
{1,248,1736,47,40,-3,0},
{1,297,1736,47,40,-3,0},
{1,346,1736,47,40,-3,0},
{1,395,1736,46,40,-4,0},
{1,443,1736,46,40,-4,0},
{1,491,1736,46,40,-4,0},
{1,735,1736,46,39,-4,1},
{1,783,1736,46,39,-4,1},
{1,539,1736,46,40,-4,2},
{1,977,1501,46,41,-4,3},
{1,892,1692,47,41,-3,3},
{1,53,1692,47,42,-3,4},
{1,102,1692,47,42,-3,4},
{1,850,1647,47,43,-3,5},
{1,899,1647,47,43,-3,5},
{1,653,1647,48,43,-2,5},
{1,524,1601,48,44,-2,6},
{1,574,1601,48,44,-2,6},
{1,624,1601,48,44,-2,6},
{1,154,1554,49,45,-1,7},
{1,205,1554,49,45,-1,7},
{1,256,1554,49,45,-1,7},
{1,307,1554,49,45,-1,7},
{1,874,1501,50,45,0,7},
},
{
{1,613,1896,30,27,0,1},
{1,645,1896,30,27,0,1},
{1,986,455,31,27,1,1},
{1,514,1896,31,27,1,1},
{1,547,1896,31,27,1,1},
{1,580,1896,31,27,1,1},
{1,677,1896,30,27,2,1},
{1,709,1896,30,27,2,1},
{1,1,1933,30,26,2,0},
{1,33,1933,30,26,2,0},
{1,741,1896,31,26,3,0},
{1,774,1896,31,26,3,0},
{1,807,1896,31,26,3,0},
{1,840,1896,31,26,3,0},
{1,873,1896,31,26,3,0},
{1,906,1896,31,26,3,0},
{1,939,1896,31,26,3,0},
{1,972,1896,31,26,3,0},
{1,378,1933,32,25,2,-1},
{1,412,1933,32,25,2,-1},
{1,446,1933,32,25,2,-1},
{1,480,1933,32,25,2,-1},
{1,514,1933,32,25,2,-1},
{1,548,1933,32,25,2,-1},
{1,582,1933,31,25,1,-1},
{1,615,1933,31,25,1,-1},
{1,950,1933,31,24,1,-2},
{1,983,1933,31,24,1,-2},
{1,1,1961,31,24,1,-2},
{1,34,1961,31,24,1,-2},
{1,67,1961,31,24,1,-2},
{1,100,1961,31,24,1,-2},
{1,133,1961,30,24,0,-2},
{1,927,1961,30,23,0,-1},
{1,959,1961,30,23,0,-1},
{1,991,1961,30,23,0,-1},
{1,1,1987,30,23,0,-1},
{1,33,1987,29,23,-1,-1},
{1,64,1987,29,23,-1,-1},
{1,95,1987,29,23,-1,-1},
{1,126,1987,29,23,-1,-1},
{1,157,1987,29,23,-1,-1},
{1,188,1987,29,23,-1,-1},
{1,219,1987,29,23,-1,-1},
{1,165,1961,29,24,-1,0},
{1,196,1961,28,24,-2,0},
{1,226,1961,28,24,-2,0},
{1,256,1961,28,24,-2,0},
{1,286,1961,28,24,-2,0},
{1,316,1961,28,24,-2,0},
{1,346,1961,28,24,-2,0},
{1,376,1961,28,24,-2,0},
{1,406,1961,28,24,-2,0},
{1,710,1933,28,25,-2,1},
{1,740,1933,28,25,-2,1},
{1,770,1933,28,25,-2,1},
{1,800,1933,28,25,-2,1},
{1,830,1933,28,25,-2,1},
{1,860,1933,28,25,-2,1},
{1,890,1933,28,25,-2,1},
{1,920,1933,28,25,-2,1},
{1,648,1933,29,25,-1,1},
{1,679,1933,29,25,-1,1},
{1,193,1933,29,26,-1,2},
{1,224,1933,29,26,-1,2},
{1,255,1933,29,26,-1,2},
{1,286,1933,29,26,-1,2},
{1,317,1933,29,26,-1,2},
{1,65,1933,30,26,0,2},
{1,97,1933,30,26,0,2},
{1,129,1933,30,26,0,2},
{1,161,1933,30,26,0,2},
},
}}
local restorationImpactLow={pixels=128,pages=addedLow,tiles={
{1,1020,1,1,1,1,-1},
{1,1020,1601,1,1,1,-1},
{1,1019,455,4,3,0,-83},
{1,1017,617,6,6,2,-80},
{1,1013,1233,10,24,0,-64},
{1,1011,697,12,24,0,-64},
{1,1005,1896,18,25,0,-63},
{1,994,933,26,28,-2,-62},
{1,991,1160,31,30,-1,-62},
{1,987,1859,36,33,0,-61},
{1,501,1819,44,36,0,-60},
{1,587,1736,50,39,0,-59},
{1,151,1692,56,41,0,-57},
{1,654,1501,62,45,0,-55},
{1,230,1501,66,47,0,-53},
{1,952,1440,68,50,0,-52},
{1,880,1440,70,53,0,-49},
{1,588,1440,70,55,0,-47},
{1,372,1440,72,57,0,-45},
{1,81,1440,72,59,0,-43},
{1,607,1376,74,60,0,-42},
{1,1,1376,74,62,0,-40},
{1,676,1305,76,63,0,-39},
{1,527,1305,76,64,0,-38},
{1,447,1305,78,65,0,-37},
{1,293,1305,78,66,0,-36},
{1,157,1305,80,67,0,-35},
{1,877,1233,80,69,0,-33},
{1,258,1086,82,72,0,-30},
{1,255,933,82,75,0,-27},
{1,697,536,84,78,0,-24},
{1,710,372,84,81,0,-21},
{1,863,105,86,84,0,-18},
{1,727,105,86,87,0,-15},
{1,590,105,86,90,0,-12},
{1,447,105,88,92,0,-10},
{1,243,105,88,95,0,-7},
{1,91,105,88,97,0,-5},
{1,1,105,88,98,0,-2},
{1,790,1,86,99,0,-1},
{1,411,1,86,101,0,1},
{1,1,1,84,102,0,2},
{1,87,1,82,102,-2,2},
{1,171,1,80,102,-2,4},
{1,253,1,78,102,-4,4},
{1,333,1,76,102,-4,4},
{1,499,1,73,101,-5,5},
{1,574,1,72,101,-4,5},
{1,648,1,70,101,-4,5},
{1,720,1,68,100,-4,6},
{1,878,1,65,99,-3,5},
{1,945,1,63,98,-3,6},
{1,181,105,60,97,-2,5},
{1,333,105,57,95,-1,3},
{1,392,105,53,93,-1,3},
{1,537,105,51,91,-1,1},
{1,678,105,47,88,-1,0},
{1,815,105,46,86,0,-2},
{1,951,105,46,84,0,-4},
{1,920,205,47,82,-1,-6},
{1,969,205,47,81,-1,-7},
{1,975,372,48,79,0,-9},
{1,956,776,49,76,-1,-10},
{1,421,933,50,75,0,-11},
{1,303,1010,51,74,1,-12},
{1,945,855,51,75,1,-9},
{1,963,617,52,76,2,-8},
{1,953,536,53,78,1,-6},
{1,239,1305,52,67,-2,-17},
{1,959,1233,52,69,-2,-15},
{1,961,1086,53,71,-3,-13},
{1,905,1086,54,72,-4,-12},
{1,247,1010,54,74,-4,-10},
{1,954,697,55,75,-5,-9},
{1,959,1376,57,60,-5,10},
{1,547,1376,58,61,-4,13},
{1,486,1376,59,61,-5,15},
{1,424,1376,60,61,-4,15},
{1,280,1376,61,62,-5,18},
{1,894,1376,63,60,-5,18},
{1,215,1376,63,62,-5,20},
{1,155,1440,65,59,-5,19},
{1,147,1376,66,62,-6,22},
{1,827,1305,67,63,-5,25},
{1,302,1440,68,58,-6,20},
{1,755,1376,69,60,-5,22},
{1,683,1376,70,60,-6,24},
{1,298,1501,72,46,-6,10},
{1,372,1501,72,46,-6,12},
{1,155,1501,73,48,-7,14},
{1,78,1501,75,49,-7,17},
{1,1,1501,75,51,-7,19},
{1,802,1440,76,53,-8,21},
{1,723,1440,77,54,-7,24},
{1,446,1440,78,56,-8,26},
{1,222,1440,78,58,-8,28},
{1,1,1440,78,59,-8,31},
{1,343,1376,79,61,-9,33},
{1,896,1305,80,62,-8,34},
{1,85,1647,80,43,-8,17},
{1,167,1647,80,43,-8,17},
{1,85,1601,81,44,-9,18},
{1,1,1647,82,43,-8,19},
{1,1,1601,82,44,-8,20},
{1,755,1554,83,44,-9,20},
{1,840,1554,83,44,-9,22},
{1,925,1554,83,44,-9,22},
{1,669,1554,84,44,-8,22},
{1,408,1554,85,44,-9,24},
{1,495,1554,85,44,-9,24},
{1,582,1554,85,44,-9,26},
{1,168,1601,51,44,-5,26},
{1,221,1601,51,44,-5,26},
{1,375,1692,52,41,-4,25},
{1,429,1692,52,41,-4,25},
{1,265,1692,53,41,-5,27},
{1,320,1692,53,41,-5,27},
{1,209,1692,54,41,-4,27},
{1,948,1647,54,42,-4,28},
{1,457,1896,55,29,-5,17},
{1,341,1896,56,30,-4,18},
{1,399,1896,56,30,-4,18},
{1,283,1896,56,31,-4,19},
{1,164,1896,57,32,-5,20},
{1,223,1896,58,31,-4,21},
{1,44,1896,58,32,-4,22},
{1,104,1896,58,32,-4,22},
{1,1018,1376,1,1,1,-1},
{1,1021,1376,1,1,1,-1},
{1,1017,1736,1,1,1,-1},
{1,1020,1736,1,1,1,-1},
{1,1016,1086,1,1,1,-1},
{1,1019,1086,1,1,1,-1},
{1,1022,1086,1,1,1,-1},
{1,1016,1933,1,1,1,-1},
{1,1019,1933,1,1,1,-1},
{1,1022,1933,1,1,1,-1},
{1,1010,1554,1,1,1,-1},
{1,1013,1554,1,1,1,-1},
{1,1016,1554,1,1,1,-1},
{1,1019,1554,1,1,1,-1},
{1,1022,1554,1,1,1,-1},
{1,1009,289,1,1,1,-1},
{1,1012,289,1,1,1,-1},
}}
local addedHigh={
{"StudioDruidRestorationSize660Page3.tga",512,1024},
{"StudioDruidRestorationSize660Page4.tga",256,128},
{"StudioDruidRestorationSize660Page5.tga",2048,2048},
{"StudioDruidRestorationSize660Page6.tga",512,256},
{"StudioDruidRestorationSize660Page7.tga",512,128},
{"StudioDruidRestorationSize660Page8.tga",512,1024},
}
local moonlightGlowIntroHigh={pixels=176,pages=addedHigh,tiles={
{1,500,726,1,1,1,-1},
{1,496,814,13,12,-1,0},
{1,243,978,24,22,0,0},
{1,211,978,30,26,0,0},
{1,456,726,42,38,0,0},
{1,432,877,60,54,0,0},
{1,96,726,77,70,-1,0},
{1,1,726,93,86,-1,0},
{1,407,1,103,94,-1,0},
{1,406,123,105,96,-1,0},
{1,383,607,107,98,-1,0},
{1,400,245,111,103,-1,1},
{1,393,366,116,106,0,0},
{1,389,487,120,111,0,1},
{1,257,607,124,114,0,0},
}}
local moonlightGlowHoldHigh={pixels=176,pages=addedHigh,bands={
{
{1,129,607,126,115,0,1},
{1,261,487,126,117,0,1},
{1,1,607,126,117,0,1},
{1,131,487,128,117,0,1},
{1,263,366,128,118,0,0},
{1,1,487,128,118,0,0},
{1,1,366,129,119,1,1},
{1,132,366,129,119,1,1},
{1,1,245,131,119,1,1},
{1,134,245,131,119,1,1},
{1,267,245,131,119,1,1},
{1,136,123,133,119,1,1},
{1,271,123,133,119,1,1},
{1,137,1,133,120,1,0},
{1,272,1,133,120,1,0},
{1,1,123,133,120,1,0},
{1,1,1,134,120,2,0},
{2,1,1,135,119,1,1},
{3,272,992,135,119,1,1},
{3,409,992,135,119,1,1},
{3,546,992,135,119,1,1},
{3,683,992,135,119,1,1},
{3,1750,992,135,118,1,0},
{3,1887,992,135,118,1,0},
{3,1,1114,135,118,1,0},
{3,138,1114,135,118,1,0},
{3,367,1114,135,117,1,1},
{3,504,1114,134,116,0,0},
{3,640,1114,133,116,1,0},
{3,775,1114,133,116,1,0},
{3,1448,1114,133,114,1,0},
{3,1583,1114,133,114,1,0},
{3,1718,1114,132,114,0,0},
{3,504,1234,132,113,0,-1},
{3,774,1234,132,112,0,0},
{3,908,1234,130,112,0,0},
{3,1040,1234,130,112,0,0},
{3,1918,1234,129,111,-1,-1},
{3,1,1350,128,111,0,-1},
{3,131,1350,128,111,0,-1},
{3,395,1350,128,110,0,0},
{3,525,1350,127,110,-1,0},
{3,1146,1350,126,109,0,-1},
{3,1274,1350,126,109,0,-1},
{3,1402,1350,125,109,-1,-1},
{3,1529,1350,125,109,-1,-1},
{3,1656,1350,125,109,-1,-1},
{3,1783,1350,123,109,-1,-1},
{3,1908,1350,123,109,-1,-1},
{3,1,1463,123,109,-1,-1},
{3,126,1463,122,109,-2,-1},
{3,250,1463,122,109,-2,-1},
{3,374,1463,121,109,-1,-1},
{3,497,1463,121,109,-1,-1},
{3,620,1463,121,109,-1,-1},
{3,743,1463,121,109,-1,-1},
{3,866,1463,121,109,-1,-1},
{3,989,1463,121,109,-1,-1},
{3,654,1350,121,110,-1,0},
{3,777,1350,121,110,-1,0},
{3,900,1350,121,110,-1,0},
{3,1023,1350,121,110,-1,0},
{3,1549,1234,121,112,-1,0},
{3,1672,1234,121,112,-1,0},
{3,1795,1234,121,112,-1,0},
{3,1299,1234,123,112,-1,0},
{3,1424,1234,123,112,-1,0},
{3,379,1234,123,114,-1,0},
{3,1,1234,124,114,0,0},
{3,127,1234,124,114,0,0},
{3,253,1234,124,114,0,0},
{3,1183,1114,125,115,-1,1},
},
{
{1,71,814,67,61,1,1},
{1,246,726,68,61,2,1},
{1,316,726,68,61,2,1},
{1,386,726,68,61,2,1},
{1,1,814,68,61,2,1},
{1,175,726,69,61,3,1},
{1,212,814,69,60,3,0},
{1,283,814,69,60,3,0},
{1,354,814,69,60,3,0},
{1,425,814,69,60,3,0},
{1,1,877,69,60,3,0},
{1,140,814,70,60,4,0},
{1,72,877,70,59,4,-1},
{1,144,877,70,59,4,-1},
{1,216,877,70,59,4,-1},
{1,288,877,70,59,4,-1},
{1,360,877,70,59,4,-1},
{2,138,1,71,58,3,-2},
{3,769,1807,71,58,3,-2},
{3,1172,1807,71,57,3,-3},
{3,1245,1807,71,57,3,-3},
{3,1318,1807,71,57,3,-3},
{3,1391,1807,70,57,2,-3},
{3,1659,1807,70,56,2,-4},
{3,1731,1807,70,56,2,-4},
{3,1803,1807,70,56,2,-4},
{3,194,1870,70,55,2,-5},
{3,266,1870,70,55,0,-5},
{3,338,1870,70,55,0,-5},
{3,410,1870,70,55,0,-5},
{3,745,1870,70,54,0,-6},
{3,817,1870,70,54,0,-6},
{3,1155,1870,69,53,-1,-5},
{3,1226,1870,69,53,-1,-5},
{3,1297,1870,69,53,-1,-5},
{3,1368,1870,68,53,-2,-5},
{3,1438,1870,68,53,-2,-5},
{3,1508,1870,68,53,-2,-5},
{3,1578,1870,68,53,-2,-5},
{3,1648,1870,67,53,-3,-5},
{3,1717,1870,66,53,-2,-5},
{3,1785,1870,65,53,-3,-5},
{3,1852,1870,65,53,-3,-5},
{3,1919,1870,65,53,-3,-5},
{3,889,1870,65,54,-3,-4},
{3,956,1870,65,54,-3,-4},
{3,1023,1870,64,54,-4,-4},
{3,1089,1870,64,54,-4,-4},
{3,482,1870,64,55,-4,-3},
{3,548,1870,64,55,-4,-3},
{3,614,1870,64,55,-4,-3},
{3,680,1870,63,55,-3,-3},
{3,1875,1807,63,56,-3,-2},
{3,1940,1807,63,56,-3,-2},
{3,1,1870,63,56,-3,-2},
{3,66,1870,63,56,-3,-2},
{3,1529,1807,63,57,-3,-1},
{3,1594,1807,63,57,-3,-1},
{3,842,1807,64,58,-2,0},
{3,908,1807,64,58,-2,0},
{3,974,1807,64,58,-2,0},
{3,1040,1807,64,58,-2,0},
{3,1106,1807,64,58,-2,0},
{3,635,1807,65,59,-1,1},
{3,702,1807,65,59,-1,1},
{3,1981,1114,66,59,0,1},
{3,431,1807,66,59,0,1},
{3,499,1807,66,59,0,1},
{3,567,1807,66,59,0,1},
{3,293,1807,67,60,1,2},
{3,362,1807,67,60,1,2},
{3,1978,1740,67,61,1,1},
},
{
{1,345,939,40,37,0,1},
{1,387,939,40,37,0,1},
{1,429,939,40,37,0,1},
{1,471,939,40,37,0,1},
{1,1,939,41,37,1,1},
{1,44,939,41,37,1,1},
{1,87,939,41,37,1,1},
{1,130,939,41,37,1,1},
{1,173,939,41,37,1,1},
{1,216,939,41,37,1,1},
{1,259,939,41,37,1,1},
{1,302,939,41,37,1,1},
{1,1,978,41,36,1,2},
{1,44,978,40,36,2,2},
{1,86,978,40,36,2,2},
{1,128,978,40,35,2,1},
{1,170,978,39,35,1,1},
{2,211,1,39,35,1,1},
{3,1,2011,38,35,2,1},
{3,41,2011,38,35,2,1},
{3,81,2011,38,35,2,1},
{3,121,2011,38,35,2,1},
{3,321,2011,37,35,1,1},
{3,729,2011,36,34,2,0},
{3,767,2011,36,34,2,0},
{3,805,2011,36,34,2,0},
{3,843,2011,36,34,2,0},
{3,881,2011,36,34,2,0},
{3,573,2011,37,34,1,0},
{3,612,2011,37,34,1,0},
{3,651,2011,37,34,1,0},
{3,1505,2011,37,33,1,-1},
{3,1345,2011,38,33,0,-1},
{3,1385,2011,38,33,0,-1},
{3,1425,2011,38,33,0,-1},
{3,1465,2011,38,33,0,-1},
{3,1177,2011,40,33,0,-1},
{3,1219,2011,40,33,0,-1},
{3,1261,2011,40,33,0,-1},
{3,1303,2011,40,33,0,-1},
{3,919,2011,41,33,-1,-1},
{3,962,2011,41,33,-1,-1},
{3,1005,2011,41,33,-1,-1},
{3,1048,2011,41,33,-1,-1},
{3,1091,2011,41,33,-1,-1},
{3,360,2011,41,34,-1,-2},
{3,403,2011,41,34,-1,-2},
{3,1134,2011,41,33,-1,-1},
{3,446,2011,41,34,-1,-2},
{3,489,2011,40,34,-2,-2},
{3,531,2011,40,34,-2,-2},
{3,1906,1971,40,35,-2,-1},
{3,1948,1971,39,35,-1,-1},
{3,1989,1971,39,35,-1,-1},
{3,161,2011,38,35,-2,-1},
{3,201,2011,38,35,-2,-1},
{3,241,2011,38,35,-2,-1},
{3,281,2011,38,35,-2,-1},
{3,1555,1971,37,36,-1,0},
{3,1594,1971,37,36,-1,0},
{3,1633,1971,37,36,-1,0},
{3,1672,1971,37,36,-1,0},
{3,1711,1971,37,36,-1,0},
{3,1750,1971,37,36,-1,0},
{3,1789,1971,37,36,-1,0},
{3,1828,1971,37,36,-1,0},
{3,1867,1971,37,36,-1,0},
{3,757,1971,37,37,-1,1},
{3,597,1971,38,37,0,1},
{3,637,1971,38,37,0,1},
{3,677,1971,38,37,0,1},
{3,717,1971,38,37,0,1},
},
}}
local natureGlowIntroHigh={pixels=176,pages=addedHigh,tiles={
{3,2046,992,1,1,1,-1},
{3,2037,1807,6,6,0,0},
{3,2029,181,18,16,0,0},
{3,1579,2011,28,26,0,0},
{3,1544,2011,33,30,-1,0},
{3,690,2011,37,34,-1,0},
{3,1996,743,47,43,-1,1},
{3,131,1870,61,56,-1,0},
{3,1962,486,79,71,-1,1},
{3,367,1574,95,86,-1,2},
{3,1751,1463,111,99,-1,1},
{3,1244,1463,121,108,-1,2},
{3,1172,1234,125,112,-1,2},
{3,1852,1114,127,114,-1,2},
{3,910,1114,131,116,-1,2},
{3,665,869,134,120,0,2},
}}
local natureGlowHoldHigh={pixels=176,pages=addedHigh,bands={
{
{3,779,743,136,122,0,2},
{3,917,743,136,122,0,2},
{3,640,743,137,122,1,2},
{3,500,743,138,122,0,2},
{3,1261,615,139,124,1,2},
{3,1402,615,139,124,1,2},
{3,1543,615,139,124,1,2},
{3,977,615,140,124,2,2},
{3,273,615,140,125,2,1},
{3,415,615,140,125,2,1},
{3,557,615,140,125,2,1},
{3,699,615,140,125,2,1},
{3,1268,486,141,126,3,0},
{3,1256,351,141,127,3,1},
{3,1399,351,141,127,3,1},
{3,1542,351,141,127,3,1},
{3,1685,351,141,127,3,1},
{3,1828,351,141,127,3,1},
{3,684,351,141,128,3,0},
{3,827,351,141,128,3,0},
{3,970,351,141,128,3,0},
{3,1113,351,141,128,3,0},
{3,1,486,140,127,2,-1},
{3,143,486,140,127,2,-1},
{3,285,486,140,127,2,-1},
{3,427,486,139,127,3,-1},
{3,568,486,139,127,3,-1},
{3,709,486,138,127,2,-1},
{3,849,486,138,127,2,-1},
{3,989,486,138,127,2,-1},
{3,1129,486,137,127,1,-1},
{3,1411,486,137,126,1,-2},
{3,1550,486,136,126,0,-2},
{3,1688,486,135,126,1,-2},
{3,1825,486,135,126,1,-2},
{3,1,615,134,126,0,-2},
{3,137,615,134,126,0,-2},
{3,841,615,134,125,0,-1},
{3,1684,615,133,124,-1,-2},
{3,1819,615,133,124,-1,-2},
{3,1,743,133,124,-1,-2},
{3,136,743,133,124,-1,-2},
{3,271,743,131,123,-1,-1},
{3,1330,743,131,122,-1,-2},
{3,1463,743,130,122,-2,-2},
{3,1595,743,130,122,-2,-2},
{3,1727,743,130,122,-2,-2},
{3,1,869,130,121,-2,-1},
{3,133,869,130,121,-2,-1},
{3,265,869,130,121,-2,-1},
{3,397,869,129,121,-3,-1},
{3,1473,869,129,120,-3,0},
{3,1604,869,129,120,-3,0},
{3,1735,869,129,120,-3,0},
{3,1866,869,129,120,-3,0},
{3,1,992,129,120,-3,0},
{3,1341,869,130,120,-2,0},
{3,1354,992,130,119,-2,1},
{3,1486,992,130,119,-2,1},
{3,1618,992,130,119,-2,1},
{3,1088,992,131,119,-3,1},
{3,1221,992,131,119,-3,1},
{3,820,992,132,119,-2,1},
{3,954,992,132,119,-2,1},
{3,801,869,133,120,-1,2},
{3,936,869,133,120,-1,2},
{3,1071,869,133,120,-1,2},
{3,1206,869,133,120,-1,2},
{3,528,869,135,120,-1,2},
{3,1859,743,135,121,-1,3},
{3,1193,743,135,122,-1,2},
{3,1055,743,136,122,0,2},
},
{
{3,945,1574,77,70,-1,10},
{3,1024,1574,77,70,-1,10},
{3,785,1574,78,70,0,10},
{3,1103,1574,77,70,1,8},
{3,1182,1574,77,70,1,8},
{3,1261,1574,77,70,1,8},
{3,1577,1574,76,69,2,7},
{3,1971,351,76,70,2,6},
{3,1655,1574,76,69,2,5},
{3,1733,1574,75,69,3,5},
{3,1810,1574,75,69,3,3},
{3,78,1670,73,68,3,2},
{3,839,1670,73,67,3,1},
{3,914,1670,73,67,3,1},
{3,153,1670,73,68,3,0},
{3,228,1670,73,68,3,0},
{3,303,1670,72,68,4,0},
{3,1214,1670,72,67,4,-1},
{3,1288,1670,72,67,4,-1},
{3,377,1670,72,68,4,-2},
{3,451,1670,72,68,4,-2},
{3,525,1670,72,68,4,-2},
{3,989,1670,73,67,3,-3},
{3,1064,1670,73,67,3,-3},
{3,1139,1670,73,67,3,-3},
{3,1824,1670,73,66,3,-4},
{3,1596,1670,74,66,2,-4},
{3,1672,1670,74,66,2,-4},
{3,1362,1670,76,66,2,-4},
{3,1440,1670,76,66,2,-4},
{3,1518,1670,76,66,2,-4},
{3,1,1740,77,65,1,-5},
{3,159,1740,76,65,0,-5},
{3,237,1740,76,65,0,-5},
{3,315,1740,76,65,0,-5},
{3,80,1740,77,65,-1,-5},
{3,393,1740,77,64,-1,-4},
{3,472,1740,77,64,-1,-4},
{3,551,1740,76,64,-2,-4},
{3,629,1740,76,64,-2,-4},
{3,707,1740,76,64,-2,-4},
{3,859,1740,75,63,-3,-3},
{3,936,1740,75,63,-3,-3},
{3,1013,1740,74,63,-4,-3},
{3,1089,1740,74,63,-4,-3},
{3,1384,1740,74,62,-4,-2},
{3,1460,1740,73,62,-5,-2},
{3,1535,1740,72,62,-4,-2},
{3,1904,1740,72,61,-4,-1},
{3,1,1807,71,61,-5,-1},
{3,1609,1740,71,62,-5,0},
{3,1682,1740,71,62,-5,0},
{3,74,1807,71,61,-5,1},
{3,147,1807,71,61,-5,1},
{3,220,1807,71,61,-5,1},
{3,1755,1740,71,62,-5,2},
{3,1165,1740,71,63,-5,3},
{3,1238,1740,71,63,-5,3},
{3,1311,1740,71,63,-5,5},
{3,785,1740,72,64,-4,6},
{3,1974,1670,72,65,-4,7},
{3,1899,1670,73,66,-5,8},
{3,1748,1670,74,66,-4,8},
{3,687,1670,74,67,-4,9},
{3,763,1670,74,67,-4,9},
{3,1,1670,75,68,-3,10},
{3,1966,1574,76,68,-4,10},
{3,1887,1574,77,68,-3,10},
{3,1419,1574,77,69,-3,11},
{3,1498,1574,77,69,-3,11},
{3,865,1574,78,70,-2,10},
{3,1340,1574,77,70,-1,10},
},
{
{3,692,1928,46,40,0,2},
{3,496,1928,47,40,1,2},
{3,545,1928,47,40,1,2},
{3,594,1928,47,40,1,2},
{3,1986,1870,47,41,1,1},
{3,148,1928,46,41,2,1},
{3,1,1928,47,41,3,1},
{3,50,1928,47,41,3,1},
{3,99,1928,47,41,3,1},
{3,643,1928,47,40,3,0},
{3,196,1928,48,40,4,0},
{3,246,1928,48,40,4,0},
{3,296,1928,48,40,4,0},
{3,346,1928,48,40,4,0},
{3,396,1928,48,40,4,0},
{3,446,1928,48,40,4,0},
{3,1318,1928,48,39,4,-1},
{3,1368,1928,48,39,4,-1},
{3,1418,1928,48,39,4,-1},
{3,1165,1928,49,39,3,-1},
{3,1216,1928,49,39,3,-1},
{3,1267,1928,49,39,3,-1},
{3,1514,1928,49,38,3,-2},
{3,1565,1928,49,38,3,-2},
{3,1616,1928,48,38,2,-2},
{3,1666,1928,48,38,2,-2},
{3,46,1971,48,37,2,-3},
{3,1716,1928,48,38,2,-2},
{3,96,1971,48,37,2,-3},
{3,796,1971,47,36,1,-2},
{3,845,1971,47,36,1,-2},
{3,894,1971,47,36,1,-2},
{3,943,1971,47,36,1,-2},
{3,992,1971,46,36,0,-2},
{3,1040,1971,46,36,0,-2},
{3,1088,1971,46,36,0,-2},
{3,1136,1971,46,36,0,-2},
{3,1184,1971,45,36,-1,-2},
{3,1231,1971,45,36,-1,-2},
{3,1278,1971,45,36,-1,-2},
{3,1325,1971,45,36,-1,-2},
{3,1372,1971,44,36,-2,-2},
{3,1418,1971,44,36,-2,-2},
{3,1464,1971,44,36,-2,-2},
{3,146,1971,44,37,-2,-1},
{3,192,1971,43,37,-3,-1},
{3,237,1971,43,37,-3,-1},
{3,1510,1971,43,36,-3,0},
{3,282,1971,43,37,-3,1},
{3,327,1971,43,37,-3,1},
{3,372,1971,43,37,-3,1},
{3,417,1971,43,37,-3,1},
{3,462,1971,43,37,-3,1},
{3,507,1971,43,37,-3,1},
{3,552,1971,43,37,-3,1},
{3,1812,1928,43,38,-3,2},
{3,1857,1928,43,38,-3,2},
{3,1902,1928,43,38,-3,2},
{3,1947,1928,43,38,-3,2},
{3,1992,1928,43,38,-3,2},
{3,1,1971,43,38,-3,2},
{3,1766,1928,44,38,-2,2},
{3,1468,1928,44,39,-2,1},
{3,1119,1928,44,40,-2,2},
{3,884,1928,45,40,-1,2},
{3,931,1928,45,40,-1,2},
{3,978,1928,45,40,-1,2},
{3,1025,1928,45,40,-1,2},
{3,1072,1928,45,40,-1,2},
{3,740,1928,46,40,0,2},
{3,788,1928,46,40,0,2},
{3,836,1928,46,40,0,2},
},
}}
local restorationImpactHigh={pixels=224,pages=addedHigh,tiles={
{3,2045,743,1,1,1,-1},
{3,2045,1807,1,1,1,-1},
{3,2043,486,4,3,0,-145},
{3,2035,1,12,38,-2,-112},
{3,2033,1350,14,39,0,-111},
{3,2024,992,20,41,0,-111},
{3,2005,1807,30,43,0,-111},
{3,1997,869,44,48,-4,-110},
{3,1990,1463,52,51,0,-109},
{3,1463,1807,64,57,0,-107},
{3,1828,1740,74,61,0,-105},
{3,599,1670,86,67,0,-103},
{3,687,1574,96,72,0,-100},
{3,579,1574,106,77,0,-97},
{3,464,1574,113,81,1,-93},
{3,247,1574,118,86,0,-90},
{3,125,1574,120,91,0,-85},
{3,1,1574,122,94,0,-82},
{3,1864,1463,124,98,0,-78},
{3,1625,1463,124,101,0,-75},
{3,1497,1463,126,104,0,-72},
{3,1367,1463,128,106,0,-70},
{3,1112,1463,130,108,0,-68},
{3,261,1350,132,110,0,-66},
{3,638,1234,134,112,0,-64},
{3,1310,1114,136,114,0,-62},
{3,1043,1114,138,115,0,-61},
{3,132,992,138,119,0,-57},
{3,1119,615,140,124,0,-52},
{3,273,351,142,130,0,-46},
{3,1798,181,144,135,0,-41},
{3,1392,181,146,141,0,-35},
{3,1159,181,148,146,0,-30},
{3,926,181,150,151,0,-25},
{3,693,181,150,156,0,-20},
{3,451,181,152,160,0,-16},
{3,204,181,152,164,0,-12},
{3,1880,1,153,168,1,-8},
{3,1617,1,152,171,0,-5},
{3,1351,1,150,173,0,-1},
{3,704,1,148,176,0,2},
{3,143,1,144,177,0,3},
{3,289,1,142,177,-2,5},
{3,1,1,140,178,-4,6},
{3,433,1,136,177,-6,7},
{3,571,1,131,177,-7,7},
{3,854,1,127,176,-9,8},
{3,983,1,124,175,-8,9},
{3,1109,1,121,175,-7,9},
{3,1232,1,117,174,-7,10},
{3,1503,1,112,172,-6,10},
{3,1771,1,107,171,-5,9},
{3,1,181,102,168,-4,8},
{3,105,181,97,165,-3,7},
{3,358,181,91,162,-3,4},
{3,605,181,86,158,-2,2},
{3,845,181,79,154,-1,0},
{3,1078,181,79,150,-1,-4},
{3,1309,181,81,145,-1,-7},
{3,1540,181,81,141,-1,-11},
{3,1623,181,82,139,-2,-11},
{3,1944,181,83,135,-1,-15},
{3,95,351,84,133,-2,-17},
{3,508,351,85,130,-1,-20},
{3,595,351,87,129,-1,-21},
{3,417,351,89,130,1,-18},
{3,181,351,90,132,2,-14},
{3,1,351,92,133,2,-11},
{3,1707,181,89,136,-3,-8},
{3,275,1114,90,118,-4,-26},
{3,1954,615,92,121,-6,-23},
{3,404,743,94,123,-6,-21},
{4,99,1,95,126,-7,-18},
{4,1,1,96,129,-8,-15},
{4,412,1,98,102,-8,18},
{4,213,132,100,104,-8,22},
{4,1,132,102,106,-8,26},
{4,306,1,104,107,-8,31},
{4,105,132,106,105,-8,31},
{4,196,1,108,107,-8,35},
{5,352,1,111,106,-9,36},
{5,1,1,113,111,-9,41},
{5,235,1,115,106,-9,38},
{5,116,1,117,109,-9,43},
{6,1,1,118,112,-10,48},
{6,390,115,120,101,-10,39},
{6,127,115,122,104,-10,42},
{6,1,115,124,106,-10,46},
{6,263,420,126,79,-12,21},
{6,133,420,128,81,-12,25},
{6,1,420,130,85,-12,29},
{6,269,326,131,87,-13,33},
{6,136,326,131,89,-13,37},
{6,1,326,133,92,-13,42},
{6,277,223,134,95,-14,45},
{6,139,223,136,98,-14,50},
{6,1,223,136,101,-14,53},
{6,251,115,137,103,-15,57},
{6,262,1,138,107,-14,61},
{6,121,1,139,110,-15,64},
{6,144,738,139,74,-15,30},
{6,287,661,140,75,-16,31},
{6,1,738,141,74,-15,32},
{6,1,661,141,75,-15,33},
{6,144,661,141,75,-15,35},
{6,147,584,143,75,-15,37},
{6,292,584,143,75,-15,37},
{6,1,584,144,75,-16,39},
{6,149,507,145,75,-15,41},
{6,296,507,145,75,-15,41},
{6,1,507,146,75,-16,43},
{6,391,420,113,75,17,45},
{6,402,1,88,75,-8,47},
{6,413,223,89,75,-7,47},
{6,94,814,90,70,-8,44},
{6,186,814,90,69,-8,45},
{6,1,814,91,70,-7,46},
{6,380,738,92,70,-8,48},
{6,285,738,93,70,-7,50},
{6,402,326,94,70,-8,50},
{6,395,886,94,50,-8,30},
{6,298,886,95,50,-7,32},
{6,200,886,96,51,-8,33},
{6,101,886,97,51,-7,35},
{6,1,886,98,53,-8,37},
{6,380,814,99,54,-7,38},
{6,278,814,100,55,-8,39},
{6,506,420,4,3,-104,-11},
{6,504,223,1,1,1,-1},
{6,507,223,1,1,1,-1},
{6,510,223,1,1,1,-1},
{6,498,326,1,1,1,-1},
{6,501,326,1,1,1,-1},
{6,504,326,1,1,1,-1},
{6,507,326,1,1,1,-1},
{6,510,326,1,1,1,-1},
{6,492,1,1,1,1,-1},
{6,495,1,1,1,1,-1},
{6,498,1,1,1,1,-1},
{6,501,1,1,1,1,-1},
{6,504,1,1,1,1,-1},
{6,507,1,1,1,1,-1},
{6,510,1,1,1,1,-1},
{6,491,886,1,1,1,-1},
}}
E.moonlightGlow={intro=30,hold=144,ending=42,stride=2,
introBank={[192]=moonlightGlowIntroLow,[288]=moonlightGlowIntroLow,[384]=moonlightGlowIntroHigh,[480]=moonlightGlowIntroHigh,[576]=moonlightGlowIntroHigh,[660]=moonlightGlowIntroHigh},holdBank={[192]=moonlightGlowHoldLow,[288]=moonlightGlowHoldLow,[384]=moonlightGlowHoldHigh,[480]=moonlightGlowHoldHigh,[576]=moonlightGlowHoldHigh,[660]=moonlightGlowHoldHigh},release={
{1.0000000,0.9988800,0.9958400,0.9913600,0.9859200,0.9800000,0.9740800,0.9686400,0.9641600,0.9611200,0.9600000,0.9543149,0.9383965,0.9139504,0.8826822,0.8462974,0.8065014,0.7650000,0.7234985,0.6837026,0.6473178,0.6160496,0.5916035,0.5756851,0.5700000,0.5649177,0.5504526,0.5277778,0.4980658,0.4624897,0.4222222,0.3784362,0.3323045,0.2850000,0.2376955,0.1915638,0.1477778,0.1075103,0.0719342,0.0422222,0.0195473,0.0050823,0.0000000},
{1.0000000,0.9957031,0.9843750,0.9683594,0.9500000,0.9316406,0.9156250,0.9042969,0.9000000,0.8924829,0.8713304,0.8386400,0.7965096,0.7470371,0.6923200,0.6344563,0.5755437,0.5176800,0.4629630,0.4134904,0.3713600,0.3386696,0.3175170,0.3100000,0.3065186,0.2966797,0.2813916,0.2615625,0.2381006,0.2119141,0.1839111,0.1550000,0.1260889,0.0980859,0.0718994,0.0484375,0.0286084,0.0133203,0.0034814,0.0000000,0.0000000,0.0000000,0.0000000},
{1.0000000,0.9911111,0.9688889,0.9400000,0.9111111,0.8888889,0.8800000,0.8702179,0.8433959,0.8033208,0.7537791,0.6985575,0.6414425,0.5862209,0.5366792,0.4966041,0.4697821,0.4600000,0.4541393,0.4376474,0.4121600,0.3793126,0.3407407,0.2980800,0.2529659,0.2070341,0.1619200,0.1192593,0.0806874,0.0478400,0.0223526,0.0058607,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000},
}}
E.natureGlow={intro=32,hold=144,ending=48,stride=2,
introBank={[192]=natureGlowIntroLow,[288]=natureGlowIntroLow,[384]=natureGlowIntroHigh,[480]=natureGlowIntroHigh,[576]=natureGlowIntroHigh,[660]=natureGlowIntroHigh},holdBank={[192]=natureGlowHoldLow,[288]=natureGlowHoldLow,[384]=natureGlowHoldHigh,[480]=natureGlowHoldHigh,[576]=natureGlowHoldHigh,[660]=natureGlowHoldHigh},release={
{1.0000000,0.9996632,0.9987255,0.9972963,0.9954848,0.9934001,0.9911516,0.9888484,0.9865999,0.9845152,0.9827037,0.9812745,0.9803368,0.9800000,0.9748843,0.9607407,0.9393750,0.9125926,0.8821990,0.8500000,0.8178009,0.7874074,0.7606250,0.7392592,0.7251157,0.7200000,0.7160352,0.7046141,0.6864470,0.6622438,0.6327147,0.5985699,0.5605195,0.5192735,0.4755420,0.4300354,0.3834635,0.3365365,0.2899646,0.2444580,0.2007266,0.1594806,0.1214301,0.0872853,0.0577562,0.0335531,0.0153859,0.0039648,0.0000000},
{1.0000000,0.9988800,0.9958400,0.9913600,0.9859200,0.9800000,0.9740800,0.9686400,0.9641600,0.9611200,0.9600000,0.9540233,0.9372886,0.9115889,0.8787172,0.8404665,0.7986298,0.7550000,0.7113703,0.6695336,0.6312828,0.5984111,0.5727113,0.5559767,0.5500000,0.5463773,0.5359842,0.5195335,0.4977378,0.4713098,0.4409621,0.4074074,0.3713584,0.3335277,0.2946280,0.2553720,0.2164723,0.1786416,0.1425926,0.1090379,0.0786902,0.0522622,0.0304665,0.0140158,0.0036227,0.0000000,0.0000000,0.0000000,0.0000000},
{1.0000000,0.9955556,0.9844444,0.9700000,0.9555556,0.9444444,0.9400000,0.9333748,0.9147319,0.8859200,0.8487881,0.8051852,0.7569600,0.7059615,0.6540385,0.6030400,0.5548148,0.5112119,0.4740800,0.4452682,0.4266252,0.4200000,0.4129267,0.3932362,0.3632226,0.3251798,0.2814019,0.2341830,0.1858170,0.1385981,0.0948202,0.0567774,0.0267638,0.0070733,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000},
}}
E.restorationImpact={[192]=restorationImpactLow,[288]=restorationImpactLow,[384]=restorationImpactHigh,[480]=restorationImpactHigh,[576]=restorationImpactHigh,[660]=restorationImpactHigh}
E.RestorationAdditionalEffectBanks={E.moonlightGlow.introBank,E.moonlightGlow.holdBank,E.natureGlow.introBank,E.natureGlow.holdBank,E.restorationImpact}

local burstPages={
{"StudioDruidRestorationSize660Page9.tga",2048,1024},
}
local burstLow={pixels=128,pages=burstPages,tiles={
{1,1669,316,1,1,1,-1},
{1,531,358,6,5,0,1},
{1,622,930,48,84,34,-6},
{1,1753,905,84,84,6,-6},
{1,1675,316,87,89,7,-3},
{1,526,930,94,92,0,-2},
{1,1657,905,94,94,0,0},
{1,1659,695,96,95,0,-1},
{1,1776,102,96,96,0,0},
{1,1639,424,96,96,0,0},
{1,1559,807,96,96,0,0},
{1,1559,905,96,96,0,0},
{1,1657,807,96,96,0,0},
{1,1573,596,97,97,1,-1},
{1,1874,1,98,98,0,0},
{1,1874,101,98,98,0,0},
{1,1776,201,98,98,0,0},
{1,1876,201,98,98,0,0},
{1,1767,301,98,98,0,0},
{1,1867,301,98,98,0,0},
{1,1559,707,98,98,0,0},
{1,1776,1,96,99,0,1},
{1,1678,104,96,100,0,2},
{1,1678,1,96,101,0,1},
{1,1669,212,96,102,0,2},
{1,1576,319,97,103,1,1},
{1,1578,1,98,103,2,1},
{1,1577,107,99,103,5,1},
{1,1476,107,99,104,5,0},
{1,1537,490,100,104,6,0},
{1,1476,1,100,104,6,0},
{1,1473,383,101,105,7,-1},
{1,1455,877,102,106,6,-2},
{1,1455,767,102,108,6,-2},
{1,1368,656,103,109,5,-3},
{1,1351,846,102,110,4,-4},
{1,727,904,103,111,3,-5},
{1,1373,167,101,106,5,0},
{1,1374,1,100,106,4,0},
{1,1373,275,98,106,0,0},
{1,1373,383,98,106,0,0},
{1,1437,491,98,106,0,0},
{1,1473,599,98,106,0,0},
{1,1473,275,98,106,0,0},
{1,1573,213,94,104,4,2},
{1,1755,792,82,83,0,1},
{1,1041,681,12,11,64,59},
{1,1672,316,1,1,1,-1},
}}
local burstHigh={pixels=224,pages=burstPages,tiles={
{1,1537,596,1,1,1,-1},
{1,1351,958,70,65,62,59},
{1,1353,509,82,145,58,-11},
{1,864,875,148,145,12,-11},
{1,1199,862,150,158,12,-4},
{1,1034,862,163,158,1,-4},
{1,1202,681,164,163,0,-1},
{1,1207,169,164,164,0,0},
{1,1208,1,164,164,0,0},
{1,1040,1,166,166,0,0},
{1,1034,694,166,166,0,0},
{1,1041,513,166,166,0,0},
{1,1205,341,166,166,0,0},
{1,865,354,168,168,0,0},
{1,867,173,168,168,0,0},
{1,870,1,168,168,0,0},
{1,864,705,168,168,0,0},
{1,871,524,168,168,0,0},
{1,1035,343,168,168,0,0},
{1,1037,171,168,168,0,0},
{1,701,534,168,169,0,1},
{1,700,1,168,170,0,2},
{1,699,180,166,172,0,2},
{1,697,358,166,174,0,2},
{1,531,180,166,176,0,2},
{1,531,1,167,177,3,1},
{1,693,725,169,177,5,1},
{1,529,545,170,178,8,0},
{1,524,365,171,178,9,0},
{1,356,1,173,180,11,0},
{1,356,183,173,180,11,0},
{1,350,760,174,182,12,-2},
{1,1,764,175,185,11,-3},
{1,1,576,176,186,10,-4},
{1,1,386,177,188,9,-6},
{1,1,194,177,190,7,-8},
{1,1,1,178,191,6,-9},
{1,179,576,178,182,4,0},
{1,180,194,174,182,6,0},
{1,181,1,173,182,5,0},
{1,359,562,168,182,0,0},
{1,180,378,170,182,0,0},
{1,352,378,170,182,0,0},
{1,178,764,170,183,0,1},
{1,526,746,165,182,5,0},
{1,1209,509,142,151,0,9},
{1,693,904,32,117,108,11},
{1,1540,596,1,1,1,-1},
}}
E.NatureSealBurstBanks={[192]=burstLow,[288]=burstLow,[384]=burstHigh,[480]=burstHigh,[576]=burstHigh,[660]=burstHigh}
table.insert(E.RestorationAdditionalEffectBanks,E.NatureSealBurstBanks)

local _, E = ...
E.ArtworkChannelPlusBanks = E.ArtworkChannelPlusBanks or {}
E.ArtworkChannelPlusBanks["DRUID:restoration"]={[192]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{1,0.7802734375,0.3095703125,0.90625,0.4580078125},{1,0.7802734375,0.4599609375,0.90625,0.6083984375},{1,0.4462890625,0.4638671875,0.572265625,0.6123046875},{1,0.57421875,0.4638671875,0.7001953125,0.6123046875},{1,0.7021484375,0.6103515625,0.828125,0.7587890625},{1,0.830078125,0.6103515625,0.9560546875,0.7587890625},{1,0.4462890625,0.7607421875,0.572265625,0.9091796875},{1,0.57421875,0.6142578125,0.7001953125,0.7626953125},{1,0.57421875,0.7646484375,0.7001953125,0.9130859375},{1,0.7021484375,0.7607421875,0.828125,0.9091796875},{1,0.830078125,0.7607421875,0.9560546875,0.9091796875},{2,0.0009765625,0.0009765625,0.126953125,0.1494140625}},["hold"]={{2,0.0009765625,0.0009765625,0.126953125,0.1494140625},{2,0.0009765625,0.1513671875,0.126953125,0.2998046875},{2,0.0009765625,0.3017578125,0.126953125,0.4501953125},{2,0.0009765625,0.4521484375,0.126953125,0.6005859375},{2,0.0009765625,0.6025390625,0.126953125,0.7509765625},{2,0.0009765625,0.7529296875,0.126953125,0.9013671875},{2,0.12890625,0.0009765625,0.2548828125,0.1494140625},{2,0.2568359375,0.0009765625,0.3828125,0.1494140625},{2,0.384765625,0.0009765625,0.5107421875,0.1494140625},{2,0.5126953125,0.0009765625,0.638671875,0.1494140625},{2,0.640625,0.0009765625,0.7666015625,0.1494140625},{2,0.7685546875,0.0009765625,0.89453125,0.1494140625},{2,0.12890625,0.1513671875,0.2548828125,0.2998046875},{2,0.12890625,0.3017578125,0.2548828125,0.4501953125},{2,0.12890625,0.4521484375,0.2548828125,0.6005859375},{2,0.12890625,0.6025390625,0.2548828125,0.7509765625},{2,0.12890625,0.7529296875,0.2548828125,0.9013671875},{2,0.2568359375,0.1513671875,0.3828125,0.2998046875},{2,0.384765625,0.1513671875,0.5107421875,0.2998046875},{2,0.5126953125,0.1513671875,0.638671875,0.2998046875},{2,0.640625,0.1513671875,0.7666015625,0.2998046875},{2,0.7685546875,0.1513671875,0.89453125,0.2998046875},{2,0.2568359375,0.3017578125,0.3828125,0.4501953125},{2,0.2568359375,0.4521484375,0.3828125,0.6005859375}},["ending"]={{2,0.0009765625,0.0009765625,0.126953125,0.1494140625},{1,0.830078125,0.7607421875,0.9560546875,0.9091796875},{1,0.7021484375,0.7607421875,0.828125,0.9091796875},{1,0.57421875,0.7646484375,0.7001953125,0.9130859375},{1,0.57421875,0.6142578125,0.7001953125,0.7626953125},{1,0.4462890625,0.7607421875,0.572265625,0.9091796875},{1,0.830078125,0.6103515625,0.9560546875,0.7587890625},{1,0.7021484375,0.6103515625,0.828125,0.7587890625},{1,0.57421875,0.4638671875,0.7001953125,0.6123046875},{1,0.4462890625,0.4638671875,0.572265625,0.6123046875},{1,0.7802734375,0.4599609375,0.90625,0.6083984375},{1,0.7802734375,0.3095703125,0.90625,0.4580078125}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{2,0.8095703125,0.7314453125,0.8515625,0.7900390625},{1,0.6455078125,0.9150390625,0.6875,0.9736328125},{1,0.0009765625,0.9267578125,0.04296875,0.9853515625},{1,0.044921875,0.9267578125,0.0869140625,0.9853515625},{1,0.0888671875,0.9267578125,0.130859375,0.9853515625},{1,0.1328125,0.9267578125,0.1748046875,0.9853515625},{1,0.1767578125,0.9267578125,0.21875,0.9853515625},{1,0.220703125,0.9267578125,0.2626953125,0.9853515625},{1,0.2646484375,0.9267578125,0.306640625,0.9853515625},{1,0.30859375,0.9267578125,0.3505859375,0.9853515625},{1,0.3525390625,0.9267578125,0.39453125,0.9853515625},{1,0.396484375,0.9267578125,0.4384765625,0.9853515625}},["hold"]={{1,0.396484375,0.9267578125,0.4384765625,0.9853515625},{1,0.5146484375,0.6142578125,0.556640625,0.6728515625},{1,0.5146484375,0.6748046875,0.556640625,0.7333984375},{3,0.4697265625,0.3173828125,0.51171875,0.3759765625},{3,0.513671875,0.3173828125,0.5556640625,0.3759765625},{3,0.5576171875,0.3173828125,0.599609375,0.3759765625},{3,0.6015625,0.3173828125,0.6435546875,0.3759765625},{3,0.6455078125,0.3173828125,0.6875,0.3759765625},{3,0.689453125,0.3173828125,0.7314453125,0.3759765625},{3,0.7333984375,0.3173828125,0.775390625,0.3759765625},{3,0.77734375,0.3173828125,0.8193359375,0.3759765625},{3,0.8212890625,0.3173828125,0.86328125,0.3759765625},{3,0.865234375,0.3173828125,0.9072265625,0.3759765625},{3,0.9091796875,0.3603515625,0.951171875,0.4189453125},{3,0.953125,0.3603515625,0.9951171875,0.4189453125},{3,0.4697265625,0.3779296875,0.51171875,0.4365234375},{3,0.3916015625,0.396484375,0.43359375,0.455078125},{3,0.513671875,0.3779296875,0.5556640625,0.4365234375},{3,0.5576171875,0.3779296875,0.599609375,0.4365234375},{3,0.6015625,0.3779296875,0.6435546875,0.4365234375},{3,0.6455078125,0.3779296875,0.6875,0.4365234375},{3,0.689453125,0.3779296875,0.7314453125,0.4365234375},{3,0.7333984375,0.3779296875,0.775390625,0.4365234375},{3,0.77734375,0.3779296875,0.8193359375,0.4365234375}},["ending"]={{1,0.396484375,0.9267578125,0.4384765625,0.9853515625},{3,0.8212890625,0.3779296875,0.86328125,0.4365234375},{3,0.865234375,0.3779296875,0.9072265625,0.4365234375},{3,0.9091796875,0.4208984375,0.951171875,0.4794921875},{3,0.953125,0.4208984375,0.9951171875,0.4794921875},{3,0.435546875,0.4384765625,0.4775390625,0.4970703125},{3,0.3916015625,0.45703125,0.43359375,0.515625},{3,0.4794921875,0.4384765625,0.521484375,0.4970703125},{3,0.5234375,0.4384765625,0.5654296875,0.4970703125},{3,0.5673828125,0.4384765625,0.609375,0.4970703125},{3,0.611328125,0.4384765625,0.6533203125,0.4970703125},{2,0.8095703125,0.7314453125,0.8515625,0.7900390625}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{3,0.0009765625,0.0009765625,0.0771484375,0.078125},{3,0.0009765625,0.080078125,0.0771484375,0.1572265625},{3,0.0009765625,0.1591796875,0.0771484375,0.236328125},{3,0.0009765625,0.23828125,0.0771484375,0.3154296875},{3,0.0009765625,0.3173828125,0.0771484375,0.39453125},{3,0.0009765625,0.396484375,0.0771484375,0.4736328125},{3,0.0009765625,0.4755859375,0.0771484375,0.552734375},{3,0.0009765625,0.5546875,0.0771484375,0.6318359375},{3,0.0009765625,0.6337890625,0.0771484375,0.7109375},{3,0.0009765625,0.712890625,0.0771484375,0.7900390625},{3,0.0009765625,0.7919921875,0.0771484375,0.869140625},{3,0.0009765625,0.87109375,0.0771484375,0.9482421875}},["hold"]={{3,0.0009765625,0.87109375,0.0771484375,0.9482421875},{3,0.0791015625,0.0009765625,0.1552734375,0.078125},{3,0.1572265625,0.0009765625,0.2333984375,0.078125},{3,0.2353515625,0.0009765625,0.3115234375,0.078125},{3,0.3134765625,0.0009765625,0.3896484375,0.078125},{3,0.3916015625,0.0009765625,0.4677734375,0.078125},{3,0.4697265625,0.0009765625,0.5458984375,0.078125},{3,0.5478515625,0.0009765625,0.6240234375,0.078125},{3,0.6259765625,0.0009765625,0.7021484375,0.078125},{3,0.7041015625,0.0009765625,0.7802734375,0.078125},{3,0.7822265625,0.0009765625,0.8583984375,0.078125},{3,0.8603515625,0.0009765625,0.9365234375,0.078125},{3,0.0791015625,0.080078125,0.1552734375,0.1572265625},{3,0.0791015625,0.1591796875,0.1552734375,0.236328125},{3,0.0791015625,0.23828125,0.1552734375,0.3154296875},{3,0.0791015625,0.3173828125,0.1552734375,0.39453125},{3,0.0791015625,0.396484375,0.1552734375,0.4736328125},{3,0.0791015625,0.4755859375,0.1552734375,0.552734375},{3,0.0791015625,0.5546875,0.1552734375,0.6318359375},{3,0.0791015625,0.6337890625,0.1552734375,0.7109375},{3,0.0791015625,0.712890625,0.1552734375,0.7900390625},{3,0.0791015625,0.7919921875,0.1552734375,0.869140625},{3,0.0791015625,0.87109375,0.1552734375,0.9482421875},{3,0.1572265625,0.080078125,0.2333984375,0.1572265625}},["ending"]={{3,0.0009765625,0.87109375,0.0771484375,0.9482421875},{3,0.2353515625,0.080078125,0.3115234375,0.1572265625},{3,0.3134765625,0.080078125,0.3896484375,0.1572265625},{3,0.3916015625,0.080078125,0.4677734375,0.1572265625},{3,0.4697265625,0.080078125,0.5458984375,0.1572265625},{3,0.5478515625,0.080078125,0.6240234375,0.1572265625},{3,0.6259765625,0.080078125,0.7021484375,0.1572265625},{3,0.7041015625,0.080078125,0.7802734375,0.1572265625},{3,0.7822265625,0.080078125,0.8583984375,0.1572265625},{3,0.8603515625,0.080078125,0.9365234375,0.1572265625},{3,0.1572265625,0.1591796875,0.2333984375,0.236328125},{3,0.0009765625,0.0009765625,0.0771484375,0.078125}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"},["matched"]={["layer"]="treant",["intro"]={{3,0.0009765625,0.0009765625,0.0771484375,0.078125},{3,0.1572265625,0.23828125,0.2333984375,0.3154296875},{3,0.1572265625,0.3173828125,0.2333984375,0.39453125},{3,0.1572265625,0.396484375,0.2333984375,0.4736328125},{3,0.1572265625,0.4755859375,0.2333984375,0.552734375},{3,0.1572265625,0.5546875,0.2333984375,0.6318359375},{3,0.1572265625,0.6337890625,0.2333984375,0.7109375},{3,0.1572265625,0.712890625,0.2333984375,0.7900390625},{3,0.1572265625,0.7919921875,0.2333984375,0.869140625},{3,0.1572265625,0.87109375,0.2333984375,0.9482421875},{3,0.2353515625,0.1591796875,0.3115234375,0.236328125},{3,0.3134765625,0.1591796875,0.3896484375,0.236328125}},["hold"]={{3,0.3134765625,0.1591796875,0.3896484375,0.236328125},{3,0.3916015625,0.1591796875,0.4677734375,0.236328125},{3,0.4697265625,0.1591796875,0.5458984375,0.236328125},{3,0.5478515625,0.1591796875,0.6240234375,0.236328125},{3,0.6259765625,0.1591796875,0.7021484375,0.236328125},{3,0.7041015625,0.1591796875,0.7802734375,0.236328125},{3,0.7822265625,0.1591796875,0.8583984375,0.236328125},{3,0.8603515625,0.1591796875,0.9365234375,0.236328125},{3,0.2353515625,0.23828125,0.3115234375,0.3154296875},{3,0.2353515625,0.3173828125,0.3115234375,0.39453125},{3,0.2353515625,0.396484375,0.3115234375,0.4736328125},{3,0.2353515625,0.4755859375,0.3115234375,0.552734375},{3,0.2353515625,0.5546875,0.3115234375,0.6318359375},{3,0.2353515625,0.6337890625,0.3115234375,0.7109375},{3,0.2353515625,0.712890625,0.3115234375,0.7900390625},{3,0.2353515625,0.7919921875,0.3115234375,0.869140625},{3,0.2353515625,0.87109375,0.3115234375,0.9482421875},{3,0.3134765625,0.23828125,0.3896484375,0.3154296875},{3,0.3916015625,0.23828125,0.4677734375,0.3154296875},{3,0.4697265625,0.23828125,0.5458984375,0.3154296875},{3,0.5478515625,0.23828125,0.6240234375,0.3154296875},{3,0.6259765625,0.23828125,0.7021484375,0.3154296875},{3,0.7041015625,0.23828125,0.7802734375,0.3154296875},{3,0.7822265625,0.23828125,0.8583984375,0.3154296875}},["ending"]={{3,0.3134765625,0.1591796875,0.3896484375,0.236328125},{3,0.8603515625,0.23828125,0.9365234375,0.3154296875},{3,0.3134765625,0.3173828125,0.3896484375,0.39453125},{3,0.3134765625,0.396484375,0.3896484375,0.4736328125},{3,0.3134765625,0.4755859375,0.3896484375,0.552734375},{3,0.3134765625,0.5546875,0.3896484375,0.6318359375},{3,0.3134765625,0.6337890625,0.3896484375,0.7109375},{3,0.3134765625,0.712890625,0.3896484375,0.7900390625},{3,0.3134765625,0.7919921875,0.3896484375,0.869140625},{3,0.3134765625,0.87109375,0.3896484375,0.9482421875},{3,0.3916015625,0.3173828125,0.4677734375,0.39453125},{3,0.0009765625,0.0009765625,0.0771484375,0.078125}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{2,0.9375,0.6630859375,0.9892578125,0.6875},{2,0.93359375,0.9580078125,0.9853515625,0.982421875},{1,0.4462890625,0.701171875,0.498046875,0.7255859375},{1,0.4462890625,0.7275390625,0.498046875,0.751953125},{2,0.3974609375,0.95703125,0.44921875,0.9814453125},{1,0.7021484375,0.55078125,0.75390625,0.5751953125},{1,0.7021484375,0.5771484375,0.75390625,0.6015625},{3,0.2470703125,0.9501953125,0.298828125,0.974609375},{3,0.30078125,0.9501953125,0.3525390625,0.974609375},{3,0.3544921875,0.9501953125,0.40625,0.974609375},{3,0.6552734375,0.4384765625,0.70703125,0.462890625},{3,0.708984375,0.4384765625,0.7607421875,0.462890625}},["hold"]={{3,0.708984375,0.4384765625,0.7607421875,0.462890625},{3,0.7626953125,0.4384765625,0.814453125,0.462890625},{3,0.81640625,0.4384765625,0.8681640625,0.462890625},{3,0.6552734375,0.46484375,0.70703125,0.4892578125},{3,0.708984375,0.46484375,0.7607421875,0.4892578125},{3,0.7626953125,0.46484375,0.814453125,0.4892578125},{3,0.81640625,0.46484375,0.8681640625,0.4892578125},{3,0.8701171875,0.4814453125,0.921875,0.505859375},{3,0.923828125,0.4814453125,0.9755859375,0.505859375},{3,0.6552734375,0.4912109375,0.70703125,0.515625},{3,0.708984375,0.4912109375,0.7607421875,0.515625},{3,0.7626953125,0.4912109375,0.814453125,0.515625},{3,0.81640625,0.4912109375,0.8681640625,0.515625},{3,0.8701171875,0.5078125,0.921875,0.5322265625},{3,0.923828125,0.5078125,0.9755859375,0.5322265625},{3,0.435546875,0.4990234375,0.4873046875,0.5234375},{3,0.4892578125,0.4990234375,0.541015625,0.5234375},{3,0.54296875,0.4990234375,0.5947265625,0.5234375},{3,0.5966796875,0.4990234375,0.6484375,0.5234375},{3,0.650390625,0.517578125,0.7021484375,0.5419921875},{3,0.7041015625,0.517578125,0.755859375,0.5419921875},{3,0.7578125,0.517578125,0.8095703125,0.5419921875},{3,0.8115234375,0.517578125,0.86328125,0.5419921875},{3,0.865234375,0.5341796875,0.9169921875,0.55859375}},["ending"]={{3,0.708984375,0.4384765625,0.7607421875,0.462890625},{3,0.6552734375,0.4384765625,0.70703125,0.462890625},{3,0.3544921875,0.9501953125,0.40625,0.974609375},{3,0.30078125,0.9501953125,0.3525390625,0.974609375},{3,0.2470703125,0.9501953125,0.298828125,0.974609375},{1,0.7021484375,0.5771484375,0.75390625,0.6015625},{1,0.7021484375,0.55078125,0.75390625,0.5751953125},{2,0.3974609375,0.95703125,0.44921875,0.9814453125},{1,0.4462890625,0.7275390625,0.498046875,0.751953125},{1,0.4462890625,0.701171875,0.498046875,0.7255859375},{2,0.93359375,0.9580078125,0.9853515625,0.982421875},{2,0.9375,0.6630859375,0.9892578125,0.6875}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{2,0.9375,0.6630859375,0.9892578125,0.6875},{3,0.9189453125,0.5341796875,0.970703125,0.55859375},{3,0.408203125,0.525390625,0.4599609375,0.5498046875},{3,0.4619140625,0.525390625,0.513671875,0.5498046875},{3,0.515625,0.525390625,0.5673828125,0.5498046875},{3,0.5693359375,0.525390625,0.62109375,0.5498046875},{3,0.623046875,0.5439453125,0.6748046875,0.568359375},{3,0.6767578125,0.5439453125,0.728515625,0.568359375},{3,0.73046875,0.5439453125,0.7822265625,0.568359375},{3,0.7841796875,0.5439453125,0.8359375,0.568359375},{3,0.837890625,0.560546875,0.8896484375,0.5849609375},{3,0.8916015625,0.560546875,0.943359375,0.5849609375}},["hold"]={{3,0.8916015625,0.560546875,0.943359375,0.5849609375},{3,0.9453125,0.560546875,0.9970703125,0.5849609375},{3,0.408203125,0.5517578125,0.4599609375,0.576171875},{3,0.4619140625,0.5517578125,0.513671875,0.576171875},{3,0.515625,0.5517578125,0.5673828125,0.576171875},{3,0.5693359375,0.5517578125,0.62109375,0.576171875},{3,0.623046875,0.5703125,0.6748046875,0.5947265625},{3,0.6767578125,0.5703125,0.728515625,0.5947265625},{3,0.73046875,0.5703125,0.7822265625,0.5947265625},{3,0.7841796875,0.5703125,0.8359375,0.5947265625},{3,0.837890625,0.5869140625,0.8896484375,0.611328125},{3,0.8916015625,0.5869140625,0.943359375,0.611328125},{3,0.9453125,0.5869140625,0.9970703125,0.611328125},{3,0.408203125,0.578125,0.4599609375,0.6025390625},{3,0.4619140625,0.578125,0.513671875,0.6025390625},{3,0.515625,0.578125,0.5673828125,0.6025390625},{3,0.5693359375,0.578125,0.62109375,0.6025390625},{3,0.623046875,0.5966796875,0.6748046875,0.62109375},{3,0.6767578125,0.5966796875,0.728515625,0.62109375},{3,0.73046875,0.5966796875,0.7822265625,0.62109375},{3,0.7841796875,0.5966796875,0.8359375,0.62109375},{3,0.837890625,0.61328125,0.8896484375,0.6376953125},{3,0.8916015625,0.61328125,0.943359375,0.6376953125},{3,0.9453125,0.61328125,0.9970703125,0.6376953125}},["ending"]={{3,0.8916015625,0.560546875,0.943359375,0.5849609375},{3,0.408203125,0.6044921875,0.4599609375,0.62890625},{3,0.4619140625,0.6044921875,0.513671875,0.62890625},{3,0.515625,0.6044921875,0.5673828125,0.62890625},{3,0.5693359375,0.6044921875,0.62109375,0.62890625},{3,0.623046875,0.623046875,0.6748046875,0.6474609375},{3,0.6767578125,0.623046875,0.728515625,0.6474609375},{3,0.73046875,0.623046875,0.7822265625,0.6474609375},{3,0.7841796875,0.623046875,0.8359375,0.6474609375},{3,0.837890625,0.6396484375,0.8896484375,0.6640625},{3,0.8916015625,0.6396484375,0.943359375,0.6640625},{2,0.9375,0.6630859375,0.9892578125,0.6875}},["idle"]={["intro"]={{2,0.9375,0.6630859375,0.9892578125,0.6875},{3,0.9453125,0.6396484375,0.9970703125,0.6640625},{3,0.408203125,0.630859375,0.4599609375,0.6552734375},{3,0.4619140625,0.630859375,0.513671875,0.6552734375},{3,0.515625,0.630859375,0.5673828125,0.6552734375},{3,0.5693359375,0.630859375,0.62109375,0.6552734375},{3,0.623046875,0.6494140625,0.6748046875,0.673828125},{3,0.6767578125,0.6494140625,0.728515625,0.673828125},{3,0.73046875,0.6494140625,0.7822265625,0.673828125},{3,0.7841796875,0.6494140625,0.8359375,0.673828125},{3,0.837890625,0.666015625,0.8896484375,0.6904296875},{3,0.8916015625,0.666015625,0.943359375,0.6904296875}},["hold"]={{3,0.8916015625,0.666015625,0.943359375,0.6904296875},{3,0.9453125,0.666015625,0.9970703125,0.6904296875},{3,0.408203125,0.6572265625,0.4599609375,0.681640625},{3,0.4619140625,0.6572265625,0.513671875,0.681640625},{3,0.515625,0.6572265625,0.5673828125,0.681640625},{3,0.5693359375,0.6572265625,0.62109375,0.681640625},{3,0.623046875,0.67578125,0.6748046875,0.7001953125},{3,0.6767578125,0.67578125,0.728515625,0.7001953125},{3,0.73046875,0.67578125,0.7822265625,0.7001953125},{3,0.7841796875,0.67578125,0.8359375,0.7001953125},{3,0.837890625,0.6923828125,0.8896484375,0.716796875},{3,0.8916015625,0.6923828125,0.943359375,0.716796875},{3,0.9453125,0.6923828125,0.9970703125,0.716796875},{3,0.408203125,0.68359375,0.4599609375,0.7080078125},{3,0.4619140625,0.68359375,0.513671875,0.7080078125},{3,0.515625,0.68359375,0.5673828125,0.7080078125},{3,0.5693359375,0.68359375,0.62109375,0.7080078125},{3,0.623046875,0.7021484375,0.6748046875,0.7265625},{3,0.6767578125,0.7021484375,0.728515625,0.7265625},{3,0.73046875,0.7021484375,0.7822265625,0.7265625},{3,0.7841796875,0.7021484375,0.8359375,0.7265625},{3,0.837890625,0.71875,0.8896484375,0.7431640625},{3,0.8916015625,0.71875,0.943359375,0.7431640625},{3,0.9453125,0.71875,0.9970703125,0.7431640625}},["ending"]={{3,0.8916015625,0.666015625,0.943359375,0.6904296875},{3,0.408203125,0.7099609375,0.4599609375,0.734375},{3,0.4619140625,0.7099609375,0.513671875,0.734375},{3,0.515625,0.7099609375,0.5673828125,0.734375},{3,0.5693359375,0.7099609375,0.62109375,0.734375},{3,0.623046875,0.728515625,0.6748046875,0.7529296875},{3,0.6767578125,0.728515625,0.728515625,0.7529296875},{3,0.73046875,0.728515625,0.7822265625,0.7529296875},{3,0.7841796875,0.728515625,0.8359375,0.7529296875},{3,0.837890625,0.7451171875,0.8896484375,0.76953125},{3,0.8916015625,0.7451171875,0.943359375,0.76953125},{2,0.9375,0.6630859375,0.9892578125,0.6875}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{3,0.9453125,0.7451171875,0.9970703125,0.76953125},{3,0.3916015625,0.771484375,0.443359375,0.7958984375},{3,0.3916015625,0.736328125,0.443359375,0.7607421875},{3,0.4453125,0.736328125,0.4970703125,0.7607421875},{3,0.4990234375,0.736328125,0.55078125,0.7607421875},{3,0.552734375,0.736328125,0.6044921875,0.7607421875},{3,0.3916015625,0.7978515625,0.443359375,0.822265625},{3,0.3916015625,0.82421875,0.443359375,0.8486328125},{3,0.3916015625,0.8505859375,0.443359375,0.875},{3,0.3916015625,0.876953125,0.443359375,0.9013671875},{3,0.3916015625,0.9033203125,0.443359375,0.927734375},{3,0.408203125,0.9296875,0.4599609375,0.9541015625}},["hold"]={{3,0.408203125,0.9296875,0.4599609375,0.9541015625},{3,0.408203125,0.9560546875,0.4599609375,0.98046875},{3,0.4453125,0.771484375,0.4970703125,0.7958984375},{3,0.4453125,0.7978515625,0.4970703125,0.822265625},{3,0.4453125,0.82421875,0.4970703125,0.8486328125},{3,0.4453125,0.8505859375,0.4970703125,0.875},{3,0.4453125,0.876953125,0.4970703125,0.9013671875},{3,0.4453125,0.9033203125,0.4970703125,0.927734375},{3,0.4619140625,0.9296875,0.513671875,0.9541015625},{3,0.4619140625,0.9560546875,0.513671875,0.98046875},{3,0.4990234375,0.771484375,0.55078125,0.7958984375},{3,0.4990234375,0.7978515625,0.55078125,0.822265625},{3,0.4990234375,0.82421875,0.55078125,0.8486328125},{3,0.4990234375,0.8505859375,0.55078125,0.875},{3,0.4990234375,0.876953125,0.55078125,0.9013671875},{3,0.4990234375,0.9033203125,0.55078125,0.927734375},{3,0.515625,0.9296875,0.5673828125,0.9541015625},{3,0.515625,0.9560546875,0.5673828125,0.98046875},{3,0.552734375,0.771484375,0.6044921875,0.7958984375},{3,0.552734375,0.7978515625,0.6044921875,0.822265625},{3,0.552734375,0.82421875,0.6044921875,0.8486328125},{3,0.552734375,0.8505859375,0.6044921875,0.875},{3,0.552734375,0.876953125,0.6044921875,0.9013671875},{3,0.552734375,0.9033203125,0.6044921875,0.927734375}},["ending"]={{3,0.408203125,0.9296875,0.4599609375,0.9541015625},{3,0.3916015625,0.9033203125,0.443359375,0.927734375},{3,0.3916015625,0.876953125,0.443359375,0.9013671875},{3,0.3916015625,0.8505859375,0.443359375,0.875},{3,0.3916015625,0.82421875,0.443359375,0.8486328125},{3,0.3916015625,0.7978515625,0.443359375,0.822265625},{3,0.552734375,0.736328125,0.6044921875,0.7607421875},{3,0.4990234375,0.736328125,0.55078125,0.7607421875},{3,0.4453125,0.736328125,0.4970703125,0.7607421875},{3,0.3916015625,0.736328125,0.443359375,0.7607421875},{3,0.3916015625,0.771484375,0.443359375,0.7958984375},{3,0.9453125,0.7451171875,0.9970703125,0.76953125}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{3,0.9453125,0.7451171875,0.9970703125,0.76953125},{3,0.5693359375,0.9296875,0.62109375,0.9541015625},{3,0.5693359375,0.9560546875,0.62109375,0.98046875},{3,0.6064453125,0.771484375,0.658203125,0.7958984375},{3,0.6064453125,0.7978515625,0.658203125,0.822265625},{3,0.6064453125,0.82421875,0.658203125,0.8486328125},{3,0.6064453125,0.8505859375,0.658203125,0.875},{3,0.6064453125,0.876953125,0.658203125,0.9013671875},{3,0.6064453125,0.9033203125,0.658203125,0.927734375},{3,0.623046875,0.9296875,0.6748046875,0.9541015625},{3,0.623046875,0.9560546875,0.6748046875,0.98046875},{3,0.6767578125,0.7548828125,0.728515625,0.779296875}},["hold"]={{3,0.6767578125,0.7548828125,0.728515625,0.779296875},{3,0.73046875,0.7548828125,0.7822265625,0.779296875},{3,0.7841796875,0.7548828125,0.8359375,0.779296875},{3,0.837890625,0.771484375,0.8896484375,0.7958984375},{3,0.8916015625,0.771484375,0.943359375,0.7958984375},{3,0.9453125,0.771484375,0.9970703125,0.7958984375},{3,0.66015625,0.7978515625,0.7119140625,0.822265625},{3,0.7138671875,0.78125,0.765625,0.8056640625},{3,0.767578125,0.78125,0.8193359375,0.8056640625},{3,0.66015625,0.82421875,0.7119140625,0.8486328125},{3,0.66015625,0.8505859375,0.7119140625,0.875},{3,0.66015625,0.876953125,0.7119140625,0.9013671875},{3,0.66015625,0.9033203125,0.7119140625,0.927734375},{3,0.6767578125,0.9296875,0.728515625,0.9541015625},{3,0.6767578125,0.9560546875,0.728515625,0.98046875},{3,0.7138671875,0.8076171875,0.765625,0.83203125},{3,0.7138671875,0.833984375,0.765625,0.8583984375},{3,0.7138671875,0.8603515625,0.765625,0.884765625},{3,0.7138671875,0.88671875,0.765625,0.9111328125},{3,0.73046875,0.9130859375,0.7822265625,0.9375},{3,0.73046875,0.939453125,0.7822265625,0.9638671875},{3,0.73046875,0.9658203125,0.7822265625,0.990234375},{3,0.767578125,0.8076171875,0.8193359375,0.83203125},{3,0.767578125,0.833984375,0.8193359375,0.8583984375}},["ending"]={{3,0.6767578125,0.7548828125,0.728515625,0.779296875},{3,0.767578125,0.8603515625,0.8193359375,0.884765625},{3,0.767578125,0.88671875,0.8193359375,0.9111328125},{3,0.7841796875,0.9130859375,0.8359375,0.9375},{3,0.7841796875,0.939453125,0.8359375,0.9638671875},{3,0.7841796875,0.9658203125,0.8359375,0.990234375},{3,0.8212890625,0.7978515625,0.873046875,0.822265625},{3,0.8212890625,0.82421875,0.873046875,0.8486328125},{3,0.8212890625,0.8505859375,0.873046875,0.875},{3,0.8212890625,0.876953125,0.873046875,0.9013671875},{3,0.837890625,0.9033203125,0.8896484375,0.927734375},{3,0.9453125,0.7451171875,0.9970703125,0.76953125}},["idle"]={["intro"]={{3,0.9453125,0.7451171875,0.9970703125,0.76953125},{3,0.837890625,0.9296875,0.8896484375,0.9541015625},{3,0.837890625,0.9560546875,0.8896484375,0.98046875},{3,0.8916015625,0.7978515625,0.943359375,0.822265625},{3,0.9453125,0.7978515625,0.9970703125,0.822265625},{3,0.875,0.82421875,0.9267578125,0.8486328125},{3,0.9287109375,0.82421875,0.98046875,0.8486328125},{3,0.875,0.8505859375,0.9267578125,0.875},{3,0.875,0.876953125,0.9267578125,0.9013671875},{3,0.9287109375,0.8505859375,0.98046875,0.875},{3,0.9287109375,0.876953125,0.98046875,0.9013671875},{3,0.8916015625,0.9033203125,0.943359375,0.927734375}},["hold"]={{3,0.8916015625,0.9033203125,0.943359375,0.927734375},{3,0.9453125,0.9033203125,0.9970703125,0.927734375},{3,0.8916015625,0.9296875,0.943359375,0.9541015625},{3,0.9453125,0.9296875,0.9970703125,0.9541015625},{3,0.8916015625,0.9560546875,0.943359375,0.98046875},{3,0.9453125,0.9560546875,0.9970703125,0.98046875},{4,0.0009765625,0.0009765625,0.052734375,0.025390625},{4,0.0546875,0.0009765625,0.1064453125,0.025390625},{4,0.1083984375,0.0009765625,0.16015625,0.025390625},{4,0.162109375,0.0009765625,0.2138671875,0.025390625},{4,0.2158203125,0.0009765625,0.267578125,0.025390625},{4,0.26953125,0.0009765625,0.3212890625,0.025390625},{4,0.3232421875,0.0009765625,0.375,0.025390625},{4,0.376953125,0.0009765625,0.4287109375,0.025390625},{4,0.4306640625,0.0009765625,0.482421875,0.025390625},{4,0.484375,0.0009765625,0.5361328125,0.025390625},{4,0.5380859375,0.0009765625,0.58984375,0.025390625},{4,0.591796875,0.0009765625,0.6435546875,0.025390625},{4,0.6455078125,0.0009765625,0.697265625,0.025390625},{4,0.69921875,0.0009765625,0.7509765625,0.025390625},{4,0.7529296875,0.0009765625,0.8046875,0.025390625},{4,0.806640625,0.0009765625,0.8583984375,0.025390625},{4,0.8603515625,0.0009765625,0.912109375,0.025390625},{4,0.9140625,0.0009765625,0.9658203125,0.025390625}},["ending"]={{3,0.8916015625,0.9033203125,0.943359375,0.927734375},{4,0.0009765625,0.02734375,0.052734375,0.0517578125},{4,0.0546875,0.02734375,0.1064453125,0.0517578125},{4,0.1083984375,0.02734375,0.16015625,0.0517578125},{4,0.162109375,0.02734375,0.2138671875,0.0517578125},{4,0.2158203125,0.02734375,0.267578125,0.0517578125},{4,0.26953125,0.02734375,0.3212890625,0.0517578125},{4,0.3232421875,0.02734375,0.375,0.0517578125},{4,0.376953125,0.02734375,0.4287109375,0.0517578125},{4,0.4306640625,0.02734375,0.482421875,0.0517578125},{4,0.484375,0.02734375,0.5361328125,0.0517578125},{3,0.9453125,0.7451171875,0.9970703125,0.76953125}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{2,0.4794921875,0.9560546875,0.5390625,0.9990234375},{2,0.541015625,0.9560546875,0.6005859375,0.9990234375},{2,0.6025390625,0.9560546875,0.662109375,0.9990234375},{2,0.6787109375,0.8173828125,0.73828125,0.8603515625},{3,0.9384765625,0.0009765625,0.998046875,0.0439453125},{3,0.9384765625,0.0458984375,0.998046875,0.0888671875},{3,0.9384765625,0.0908203125,0.998046875,0.1337890625},{3,0.9384765625,0.1357421875,0.998046875,0.1787109375},{3,0.9384765625,0.1806640625,0.998046875,0.2236328125},{3,0.9384765625,0.2255859375,0.998046875,0.2685546875},{3,0.9384765625,0.2705078125,0.998046875,0.3134765625},{3,0.9384765625,0.3154296875,0.998046875,0.3583984375}},["hold"]={{3,0.9384765625,0.3154296875,0.998046875,0.3583984375},{2,0.9375,0.7783203125,0.9970703125,0.8212890625},{2,0.9375,0.8232421875,0.9970703125,0.8662109375},{2,0.9375,0.8681640625,0.9970703125,0.9111328125},{2,0.9375,0.9130859375,0.9970703125,0.9560546875},{2,0.384765625,0.3017578125,0.4443359375,0.3447265625},{2,0.4462890625,0.3017578125,0.505859375,0.3447265625},{2,0.5078125,0.3017578125,0.5673828125,0.3447265625},{2,0.5693359375,0.3017578125,0.62890625,0.3447265625},{2,0.9375,0.3486328125,0.9970703125,0.3916015625},{2,0.9375,0.3935546875,0.9970703125,0.4365234375},{2,0.9375,0.4384765625,0.9970703125,0.4814453125},{2,0.9375,0.4833984375,0.9970703125,0.5263671875},{2,0.9375,0.5283203125,0.9970703125,0.5712890625},{2,0.9375,0.5732421875,0.9970703125,0.6162109375},{2,0.9375,0.6181640625,0.9970703125,0.6611328125},{2,0.8720703125,0.9501953125,0.931640625,0.9931640625},{2,0.67578125,0.9501953125,0.7353515625,0.9931640625},{2,0.2744140625,0.9501953125,0.333984375,0.9931640625},{2,0.3359375,0.9501953125,0.3955078125,0.9931640625},{3,0.0009765625,0.9501953125,0.060546875,0.9931640625},{3,0.0625,0.9501953125,0.1220703125,0.9931640625},{3,0.1240234375,0.9501953125,0.18359375,0.9931640625},{3,0.185546875,0.9501953125,0.2451171875,0.9931640625}},["ending"]={{3,0.9384765625,0.3154296875,0.998046875,0.3583984375},{3,0.9384765625,0.2705078125,0.998046875,0.3134765625},{3,0.9384765625,0.2255859375,0.998046875,0.2685546875},{3,0.9384765625,0.1806640625,0.998046875,0.2236328125},{3,0.9384765625,0.1357421875,0.998046875,0.1787109375},{3,0.9384765625,0.0908203125,0.998046875,0.1337890625},{3,0.9384765625,0.0458984375,0.998046875,0.0888671875},{3,0.9384765625,0.0009765625,0.998046875,0.0439453125},{2,0.6787109375,0.8173828125,0.73828125,0.8603515625},{2,0.6025390625,0.9560546875,0.662109375,0.9990234375},{2,0.541015625,0.9560546875,0.6005859375,0.9990234375},{2,0.4794921875,0.9560546875,0.5390625,0.9990234375}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.1103515625,0.1533203125},{1,0.0009765625,0.1552734375,0.1103515625,0.3076171875},{1,0.0009765625,0.3095703125,0.1103515625,0.4619140625},{1,0.0009765625,0.4638671875,0.1103515625,0.6162109375},{1,0.0009765625,0.6181640625,0.1103515625,0.7705078125},{1,0.0009765625,0.7724609375,0.1103515625,0.9248046875},{1,0.1123046875,0.0009765625,0.2216796875,0.1533203125},{1,0.2236328125,0.0009765625,0.3330078125,0.1533203125},{1,0.3349609375,0.0009765625,0.4443359375,0.1533203125},{1,0.4462890625,0.0009765625,0.5556640625,0.1533203125},{1,0.5576171875,0.0009765625,0.6669921875,0.1533203125},{1,0.6689453125,0.0009765625,0.7783203125,0.1533203125}},["hold"]={{1,0.6689453125,0.0009765625,0.7783203125,0.1533203125},{1,0.7802734375,0.0009765625,0.8896484375,0.1533203125},{1,0.1123046875,0.1552734375,0.2216796875,0.3076171875},{1,0.1123046875,0.3095703125,0.2216796875,0.4619140625},{1,0.1123046875,0.4638671875,0.2216796875,0.6162109375},{1,0.1123046875,0.6181640625,0.2216796875,0.7705078125},{1,0.1123046875,0.7724609375,0.2216796875,0.9248046875},{1,0.2236328125,0.1552734375,0.3330078125,0.3076171875},{1,0.2236328125,0.3095703125,0.3330078125,0.4619140625},{1,0.2236328125,0.4638671875,0.3330078125,0.6162109375},{1,0.2236328125,0.6181640625,0.3330078125,0.7705078125},{1,0.2236328125,0.7724609375,0.3330078125,0.9248046875},{1,0.3349609375,0.1552734375,0.4443359375,0.3076171875},{1,0.4462890625,0.1552734375,0.5556640625,0.3076171875},{1,0.5576171875,0.1552734375,0.6669921875,0.3076171875},{1,0.6689453125,0.1552734375,0.7783203125,0.3076171875},{1,0.7802734375,0.1552734375,0.8896484375,0.3076171875},{1,0.3349609375,0.3095703125,0.4443359375,0.4619140625},{1,0.3349609375,0.4638671875,0.4443359375,0.6162109375},{1,0.3349609375,0.6181640625,0.4443359375,0.7705078125},{1,0.3349609375,0.7724609375,0.4443359375,0.9248046875},{1,0.4462890625,0.3095703125,0.5556640625,0.4619140625},{1,0.5576171875,0.3095703125,0.6669921875,0.4619140625},{1,0.6689453125,0.3095703125,0.7783203125,0.4619140625}},["ending"]={{1,0.6689453125,0.0009765625,0.7783203125,0.1533203125},{1,0.5576171875,0.0009765625,0.6669921875,0.1533203125},{1,0.4462890625,0.0009765625,0.5556640625,0.1533203125},{1,0.3349609375,0.0009765625,0.4443359375,0.1533203125},{1,0.2236328125,0.0009765625,0.3330078125,0.1533203125},{1,0.1123046875,0.0009765625,0.2216796875,0.1533203125},{1,0.0009765625,0.7724609375,0.1103515625,0.9248046875},{1,0.0009765625,0.6181640625,0.1103515625,0.7705078125},{1,0.0009765625,0.4638671875,0.1103515625,0.6162109375},{1,0.0009765625,0.3095703125,0.1103515625,0.4619140625},{1,0.0009765625,0.1552734375,0.1103515625,0.3076171875},{1,0.0009765625,0.0009765625,0.1103515625,0.1533203125}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{1,0.5146484375,0.9150390625,0.578125,0.9990234375},{1,0.580078125,0.9150390625,0.6435546875,0.9990234375},{2,0.4794921875,0.8701171875,0.54296875,0.9541015625},{2,0.544921875,0.8701171875,0.6083984375,0.9541015625},{2,0.5302734375,0.5224609375,0.59375,0.6064453125},{2,0.58984375,0.3486328125,0.6533203125,0.4326171875},{2,0.58984375,0.4345703125,0.6533203125,0.5185546875},{2,0.5302734375,0.6083984375,0.59375,0.6923828125},{2,0.5302734375,0.6943359375,0.59375,0.7783203125},{2,0.5478515625,0.7802734375,0.611328125,0.8642578125},{2,0.6103515625,0.8662109375,0.673828125,0.9501953125},{2,0.67578125,0.3017578125,0.7392578125,0.3857421875}},["hold"]={{2,0.67578125,0.3017578125,0.7392578125,0.3857421875},{2,0.7412109375,0.3017578125,0.8046875,0.3857421875},{2,0.806640625,0.3017578125,0.8701171875,0.3857421875},{2,0.8720703125,0.3486328125,0.935546875,0.4326171875},{2,0.67578125,0.3876953125,0.7392578125,0.4716796875},{2,0.7412109375,0.3876953125,0.8046875,0.4716796875},{2,0.806640625,0.3876953125,0.8701171875,0.4716796875},{2,0.8720703125,0.4345703125,0.935546875,0.5185546875},{2,0.67578125,0.4736328125,0.7392578125,0.5576171875},{2,0.595703125,0.5205078125,0.6591796875,0.6044921875},{2,0.7412109375,0.4736328125,0.8046875,0.5576171875},{2,0.806640625,0.4736328125,0.8701171875,0.5576171875},{2,0.8720703125,0.5205078125,0.935546875,0.6044921875},{2,0.595703125,0.6064453125,0.6591796875,0.6904296875},{2,0.595703125,0.6923828125,0.6591796875,0.7763671875},{2,0.61328125,0.7783203125,0.6767578125,0.8623046875},{2,0.67578125,0.8642578125,0.7392578125,0.9482421875},{2,0.7412109375,0.5595703125,0.8046875,0.6435546875},{2,0.806640625,0.5595703125,0.8701171875,0.6435546875},{2,0.6611328125,0.5595703125,0.724609375,0.6435546875},{2,0.6611328125,0.6455078125,0.724609375,0.7294921875},{2,0.6787109375,0.7314453125,0.7421875,0.8154296875},{2,0.7265625,0.6455078125,0.7900390625,0.7294921875},{2,0.8720703125,0.6064453125,0.935546875,0.6904296875}},["ending"]={{2,0.67578125,0.3017578125,0.7392578125,0.3857421875},{2,0.7919921875,0.6455078125,0.85546875,0.7294921875},{2,0.857421875,0.6923828125,0.9208984375,0.7763671875},{2,0.9228515625,0.6923828125,0.986328125,0.7763671875},{2,0.744140625,0.7314453125,0.8076171875,0.8154296875},{2,0.7412109375,0.8173828125,0.8046875,0.9013671875},{2,0.7412109375,0.9033203125,0.8046875,0.9873046875},{2,0.806640625,0.8173828125,0.8701171875,0.9013671875},{2,0.806640625,0.9033203125,0.8701171875,0.9873046875},{2,0.8720703125,0.7783203125,0.935546875,0.8623046875},{2,0.8720703125,0.8642578125,0.935546875,0.9482421875},{1,0.5146484375,0.9150390625,0.578125,0.9990234375}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{1,0.4462890625,0.9111328125,0.5126953125,0.99609375},{1,0.7021484375,0.9111328125,0.7685546875,0.99609375},{1,0.7705078125,0.9111328125,0.8369140625,0.99609375},{1,0.8388671875,0.9111328125,0.9052734375,0.99609375},{1,0.9072265625,0.9111328125,0.9736328125,0.99609375},{1,0.7021484375,0.4638671875,0.7685546875,0.548828125},{2,0.0009765625,0.9033203125,0.0673828125,0.98828125},{2,0.0693359375,0.9033203125,0.1357421875,0.98828125},{2,0.1376953125,0.9033203125,0.2041015625,0.98828125},{2,0.2060546875,0.9033203125,0.2724609375,0.98828125},{1,0.908203125,0.0009765625,0.974609375,0.0859375},{1,0.908203125,0.087890625,0.974609375,0.1728515625}},["hold"]={{1,0.908203125,0.087890625,0.974609375,0.1728515625},{1,0.908203125,0.1748046875,0.974609375,0.259765625},{1,0.908203125,0.26171875,0.974609375,0.3466796875},{1,0.908203125,0.3486328125,0.974609375,0.43359375},{1,0.908203125,0.435546875,0.974609375,0.5205078125},{1,0.908203125,0.5224609375,0.974609375,0.607421875},{2,0.896484375,0.0009765625,0.962890625,0.0859375},{2,0.896484375,0.087890625,0.962890625,0.1728515625},{2,0.896484375,0.1748046875,0.962890625,0.259765625},{2,0.896484375,0.26171875,0.962890625,0.3466796875},{1,0.4462890625,0.6142578125,0.5126953125,0.69921875},{2,0.2568359375,0.6025390625,0.3232421875,0.6875},{2,0.2568359375,0.689453125,0.3232421875,0.7744140625},{2,0.2568359375,0.7763671875,0.3232421875,0.861328125},{2,0.2744140625,0.86328125,0.3408203125,0.9482421875},{2,0.3251953125,0.6025390625,0.3916015625,0.6875},{2,0.3251953125,0.689453125,0.3916015625,0.7744140625},{2,0.3251953125,0.7763671875,0.3916015625,0.861328125},{2,0.3427734375,0.86328125,0.4091796875,0.9482421875},{2,0.384765625,0.3486328125,0.451171875,0.43359375},{2,0.384765625,0.435546875,0.451171875,0.5205078125},{2,0.3935546875,0.5224609375,0.4599609375,0.607421875},{2,0.453125,0.3486328125,0.51953125,0.43359375},{2,0.453125,0.435546875,0.51953125,0.5205078125}},["ending"]={{1,0.908203125,0.087890625,0.974609375,0.1728515625},{2,0.3935546875,0.609375,0.4599609375,0.6943359375},{2,0.3935546875,0.6962890625,0.4599609375,0.78125},{2,0.4111328125,0.783203125,0.4775390625,0.8681640625},{2,0.4111328125,0.8701171875,0.4775390625,0.955078125},{2,0.4619140625,0.5224609375,0.5283203125,0.607421875},{2,0.521484375,0.3486328125,0.587890625,0.43359375},{2,0.521484375,0.435546875,0.587890625,0.5205078125},{2,0.4619140625,0.609375,0.5283203125,0.6943359375},{2,0.4619140625,0.6962890625,0.5283203125,0.78125},{2,0.4794921875,0.783203125,0.5458984375,0.8681640625},{1,0.4462890625,0.9111328125,0.5126953125,0.99609375}},["pages"]={"StudioDruidRestorationChannelPlusSize192Page1.tga","StudioDruidRestorationChannelPlusSize192Page2.tga","StudioDruidRestorationChannelPlusSize192Page3.tga","StudioDruidRestorationChannelPlusSize192Page4.tga"}}},[288]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{2,0.1669921875,0.6923828125,0.3564453125,0.9150390625},{2,0.3330078125,0.2314453125,0.5224609375,0.4541015625},{2,0.3330078125,0.4560546875,0.5224609375,0.6787109375},{2,0.3583984375,0.6806640625,0.5478515625,0.9033203125},{2,0.5244140625,0.2314453125,0.7138671875,0.4541015625},{2,0.5244140625,0.4560546875,0.7138671875,0.6787109375},{2,0.7158203125,0.2314453125,0.9052734375,0.4541015625},{2,0.7158203125,0.4560546875,0.9052734375,0.6787109375},{2,0.5498046875,0.6806640625,0.7392578125,0.9033203125},{2,0.7412109375,0.6806640625,0.9306640625,0.9033203125},{3,0.0009765625,0.0009765625,0.1904296875,0.2236328125},{3,0.0009765625,0.2255859375,0.1904296875,0.4482421875}},["hold"]={{3,0.0009765625,0.2255859375,0.1904296875,0.4482421875},{3,0.0009765625,0.4501953125,0.1904296875,0.6728515625},{3,0.0009765625,0.6748046875,0.1904296875,0.8974609375},{3,0.1923828125,0.0009765625,0.3818359375,0.2236328125},{3,0.3837890625,0.0009765625,0.5732421875,0.2236328125},{3,0.5751953125,0.0009765625,0.7646484375,0.2236328125},{3,0.7666015625,0.0009765625,0.9560546875,0.2236328125},{3,0.1923828125,0.2255859375,0.3818359375,0.4482421875},{3,0.1923828125,0.4501953125,0.3818359375,0.6728515625},{3,0.1923828125,0.6748046875,0.3818359375,0.8974609375},{3,0.3837890625,0.2255859375,0.5732421875,0.4482421875},{3,0.5751953125,0.2255859375,0.7646484375,0.4482421875},{3,0.7666015625,0.2255859375,0.9560546875,0.4482421875},{3,0.3837890625,0.4501953125,0.5732421875,0.6728515625},{3,0.3837890625,0.6748046875,0.5732421875,0.8974609375},{3,0.5751953125,0.4501953125,0.7646484375,0.6728515625},{3,0.7666015625,0.4501953125,0.9560546875,0.6728515625},{3,0.5751953125,0.6748046875,0.7646484375,0.8974609375},{3,0.7666015625,0.6748046875,0.9560546875,0.8974609375},{4,0.0009765625,0.0009765625,0.1904296875,0.2236328125},{4,0.0009765625,0.2255859375,0.1904296875,0.4482421875},{4,0.0009765625,0.4501953125,0.1904296875,0.6728515625},{4,0.0009765625,0.6748046875,0.1904296875,0.8974609375},{4,0.1923828125,0.0009765625,0.3818359375,0.2236328125}},["ending"]={{3,0.0009765625,0.2255859375,0.1904296875,0.4482421875},{3,0.0009765625,0.0009765625,0.1904296875,0.2236328125},{2,0.7412109375,0.6806640625,0.9306640625,0.9033203125},{2,0.5498046875,0.6806640625,0.7392578125,0.9033203125},{2,0.7158203125,0.4560546875,0.9052734375,0.6787109375},{2,0.7158203125,0.2314453125,0.9052734375,0.4541015625},{2,0.5244140625,0.4560546875,0.7138671875,0.6787109375},{2,0.5244140625,0.2314453125,0.7138671875,0.4541015625},{2,0.3583984375,0.6806640625,0.5478515625,0.9033203125},{2,0.3330078125,0.4560546875,0.5224609375,0.6787109375},{2,0.3330078125,0.2314453125,0.5224609375,0.4541015625},{2,0.1669921875,0.6923828125,0.3564453125,0.9150390625}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{2,0.9326171875,0.6298828125,0.99609375,0.716796875},{2,0.9326171875,0.71875,0.99609375,0.8056640625},{2,0.9326171875,0.8076171875,0.99609375,0.89453125},{2,0.9326171875,0.896484375,0.99609375,0.9833984375},{6,0.9306640625,0.0009765625,0.994140625,0.087890625},{6,0.9306640625,0.08984375,0.994140625,0.1767578125},{6,0.9306640625,0.1787109375,0.994140625,0.265625},{6,0.9306640625,0.267578125,0.994140625,0.3544921875},{6,0.9306640625,0.3564453125,0.994140625,0.443359375},{6,0.9306640625,0.4453125,0.994140625,0.5322265625},{6,0.9306640625,0.5341796875,0.994140625,0.62109375},{6,0.9306640625,0.623046875,0.994140625,0.7099609375}},["hold"]={{6,0.9306640625,0.623046875,0.994140625,0.7099609375},{5,0.0009765625,0.9033203125,0.064453125,0.990234375},{5,0.06640625,0.9033203125,0.1298828125,0.990234375},{5,0.1318359375,0.9033203125,0.1953125,0.990234375},{5,0.197265625,0.9033203125,0.2607421875,0.990234375},{4,0.2900390625,0.9033203125,0.353515625,0.990234375},{4,0.35546875,0.9033203125,0.4189453125,0.990234375},{4,0.4208984375,0.9033203125,0.484375,0.990234375},{4,0.486328125,0.9033203125,0.5498046875,0.990234375},{4,0.5517578125,0.9033203125,0.615234375,0.990234375},{4,0.6171875,0.9033203125,0.6806640625,0.990234375},{4,0.6826171875,0.9033203125,0.74609375,0.990234375},{4,0.748046875,0.9033203125,0.8115234375,0.990234375},{4,0.8134765625,0.9033203125,0.876953125,0.990234375},{4,0.87890625,0.9033203125,0.9423828125,0.990234375},{4,0.0009765625,0.8994140625,0.064453125,0.986328125},{4,0.06640625,0.8994140625,0.1298828125,0.986328125},{3,0.0009765625,0.8994140625,0.064453125,0.986328125},{3,0.06640625,0.8994140625,0.1298828125,0.986328125},{3,0.1318359375,0.8994140625,0.1953125,0.986328125},{3,0.197265625,0.8994140625,0.2607421875,0.986328125},{3,0.2626953125,0.8994140625,0.326171875,0.986328125},{3,0.328125,0.8994140625,0.3916015625,0.986328125},{3,0.3935546875,0.8994140625,0.45703125,0.986328125}},["ending"]={{6,0.9306640625,0.623046875,0.994140625,0.7099609375},{3,0.458984375,0.8994140625,0.5224609375,0.986328125},{3,0.5244140625,0.8994140625,0.587890625,0.986328125},{3,0.58984375,0.8994140625,0.6533203125,0.986328125},{3,0.6552734375,0.8994140625,0.71875,0.986328125},{3,0.720703125,0.8994140625,0.7841796875,0.986328125},{3,0.7861328125,0.8994140625,0.849609375,0.986328125},{3,0.8515625,0.8994140625,0.9150390625,0.986328125},{3,0.9169921875,0.8994140625,0.98046875,0.986328125},{5,0.9150390625,0.0009765625,0.978515625,0.087890625},{5,0.9150390625,0.08984375,0.978515625,0.1767578125},{2,0.9326171875,0.6298828125,0.99609375,0.716796875}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{5,0.3056640625,0.7744140625,0.419921875,0.8896484375},{5,0.4072265625,0.2587890625,0.521484375,0.3740234375},{5,0.4072265625,0.3759765625,0.521484375,0.4912109375},{5,0.4072265625,0.4931640625,0.521484375,0.6083984375},{5,0.4072265625,0.6103515625,0.521484375,0.7255859375},{5,0.421875,0.7275390625,0.5361328125,0.8427734375},{5,0.421875,0.8447265625,0.5361328125,0.9599609375},{5,0.5380859375,0.2587890625,0.65234375,0.3740234375},{5,0.654296875,0.2587890625,0.7685546875,0.3740234375},{5,0.7705078125,0.2587890625,0.884765625,0.3740234375},{5,0.5234375,0.3759765625,0.6376953125,0.4912109375},{5,0.5234375,0.4931640625,0.6376953125,0.6083984375}},["hold"]={{5,0.5234375,0.4931640625,0.6376953125,0.6083984375},{5,0.5234375,0.6103515625,0.6376953125,0.7255859375},{5,0.5380859375,0.7275390625,0.65234375,0.8427734375},{5,0.5380859375,0.8447265625,0.65234375,0.9599609375},{5,0.654296875,0.3759765625,0.7685546875,0.4912109375},{5,0.7705078125,0.3759765625,0.884765625,0.4912109375},{5,0.6396484375,0.4931640625,0.75390625,0.6083984375},{5,0.6396484375,0.6103515625,0.75390625,0.7255859375},{5,0.755859375,0.4931640625,0.8701171875,0.6083984375},{5,0.8720703125,0.4931640625,0.986328125,0.6083984375},{5,0.755859375,0.6103515625,0.8701171875,0.7255859375},{5,0.8720703125,0.6103515625,0.986328125,0.7255859375},{5,0.654296875,0.7275390625,0.7685546875,0.8427734375},{5,0.654296875,0.8447265625,0.7685546875,0.9599609375},{5,0.7705078125,0.7275390625,0.884765625,0.8427734375},{5,0.7705078125,0.8447265625,0.884765625,0.9599609375},{6,0.0009765625,0.0009765625,0.115234375,0.1162109375},{6,0.0009765625,0.1181640625,0.115234375,0.2333984375},{6,0.0009765625,0.2353515625,0.115234375,0.3505859375},{6,0.0009765625,0.3525390625,0.115234375,0.4677734375},{6,0.0009765625,0.4697265625,0.115234375,0.5849609375},{6,0.0009765625,0.5869140625,0.115234375,0.7021484375},{6,0.0009765625,0.7041015625,0.115234375,0.8193359375},{6,0.0009765625,0.8212890625,0.115234375,0.9365234375}},["ending"]={{5,0.5234375,0.4931640625,0.6376953125,0.6083984375},{6,0.1171875,0.0009765625,0.2314453125,0.1162109375},{6,0.2333984375,0.0009765625,0.34765625,0.1162109375},{6,0.349609375,0.0009765625,0.4638671875,0.1162109375},{6,0.4658203125,0.0009765625,0.580078125,0.1162109375},{6,0.58203125,0.0009765625,0.6962890625,0.1162109375},{6,0.6982421875,0.0009765625,0.8125,0.1162109375},{6,0.814453125,0.0009765625,0.9287109375,0.1162109375},{6,0.1171875,0.1181640625,0.2314453125,0.2333984375},{6,0.1171875,0.2353515625,0.2314453125,0.3505859375},{6,0.1171875,0.3525390625,0.2314453125,0.4677734375},{5,0.3056640625,0.7744140625,0.419921875,0.8896484375}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"},["matched"]={["layer"]="treant",["intro"]={{5,0.3056640625,0.7744140625,0.419921875,0.8896484375},{6,0.1171875,0.4697265625,0.2314453125,0.5849609375},{6,0.1171875,0.5869140625,0.2314453125,0.7021484375},{6,0.1171875,0.7041015625,0.2314453125,0.8193359375},{6,0.1171875,0.8212890625,0.2314453125,0.9365234375},{6,0.2333984375,0.1181640625,0.34765625,0.2333984375},{6,0.349609375,0.1181640625,0.4638671875,0.2333984375},{6,0.4658203125,0.1181640625,0.580078125,0.2333984375},{6,0.58203125,0.1181640625,0.6962890625,0.2333984375},{6,0.6982421875,0.1181640625,0.8125,0.2333984375},{6,0.814453125,0.1181640625,0.9287109375,0.2333984375},{6,0.2333984375,0.2353515625,0.34765625,0.3505859375}},["hold"]={{6,0.2333984375,0.2353515625,0.34765625,0.3505859375},{6,0.2333984375,0.3525390625,0.34765625,0.4677734375},{6,0.2333984375,0.4697265625,0.34765625,0.5849609375},{6,0.2333984375,0.5869140625,0.34765625,0.7021484375},{6,0.2333984375,0.7041015625,0.34765625,0.8193359375},{6,0.2333984375,0.8212890625,0.34765625,0.9365234375},{6,0.349609375,0.2353515625,0.4638671875,0.3505859375},{6,0.4658203125,0.2353515625,0.580078125,0.3505859375},{6,0.58203125,0.2353515625,0.6962890625,0.3505859375},{6,0.6982421875,0.2353515625,0.8125,0.3505859375},{6,0.814453125,0.2353515625,0.9287109375,0.3505859375},{6,0.349609375,0.3525390625,0.4638671875,0.4677734375},{6,0.349609375,0.4697265625,0.4638671875,0.5849609375},{6,0.349609375,0.5869140625,0.4638671875,0.7021484375},{6,0.349609375,0.7041015625,0.4638671875,0.8193359375},{6,0.349609375,0.8212890625,0.4638671875,0.9365234375},{6,0.4658203125,0.3525390625,0.580078125,0.4677734375},{6,0.58203125,0.3525390625,0.6962890625,0.4677734375},{6,0.6982421875,0.3525390625,0.8125,0.4677734375},{6,0.814453125,0.3525390625,0.9287109375,0.4677734375},{6,0.4658203125,0.4697265625,0.580078125,0.5849609375},{6,0.4658203125,0.5869140625,0.580078125,0.7021484375},{6,0.4658203125,0.7041015625,0.580078125,0.8193359375},{6,0.4658203125,0.8212890625,0.580078125,0.9365234375}},["ending"]={{6,0.2333984375,0.2353515625,0.34765625,0.3505859375},{6,0.58203125,0.4697265625,0.6962890625,0.5849609375},{6,0.6982421875,0.4697265625,0.8125,0.5849609375},{6,0.814453125,0.4697265625,0.9287109375,0.5849609375},{6,0.58203125,0.5869140625,0.6962890625,0.7021484375},{6,0.58203125,0.7041015625,0.6962890625,0.8193359375},{6,0.58203125,0.8212890625,0.6962890625,0.9365234375},{6,0.6982421875,0.5869140625,0.8125,0.7021484375},{6,0.814453125,0.5869140625,0.9287109375,0.7021484375},{6,0.6982421875,0.7041015625,0.8125,0.8193359375},{6,0.6982421875,0.8212890625,0.8125,0.9365234375},{5,0.3056640625,0.7744140625,0.419921875,0.8896484375}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{5,0.2626953125,0.9619140625,0.33984375,0.998046875},{5,0.341796875,0.9580078125,0.4189453125,0.994140625},{5,0.4208984375,0.9619140625,0.498046875,0.998046875},{5,0.5,0.9619140625,0.5771484375,0.998046875},{5,0.5791015625,0.9619140625,0.65625,0.998046875},{5,0.658203125,0.9619140625,0.7353515625,0.998046875},{5,0.7373046875,0.9619140625,0.814453125,0.998046875},{5,0.9150390625,0.1787109375,0.9921875,0.21484375},{5,0.9150390625,0.216796875,0.9921875,0.2529296875},{6,0.0009765625,0.9384765625,0.078125,0.974609375},{6,0.080078125,0.9384765625,0.1572265625,0.974609375},{6,0.1591796875,0.9384765625,0.236328125,0.974609375}},["hold"]={{6,0.1591796875,0.9384765625,0.236328125,0.974609375},{6,0.23828125,0.9384765625,0.3154296875,0.974609375},{6,0.3173828125,0.9384765625,0.39453125,0.974609375},{6,0.396484375,0.9384765625,0.4736328125,0.974609375},{6,0.4755859375,0.9384765625,0.552734375,0.974609375},{6,0.5546875,0.9384765625,0.6318359375,0.974609375},{6,0.6337890625,0.9384765625,0.7109375,0.974609375},{6,0.712890625,0.9384765625,0.7900390625,0.974609375},{6,0.7919921875,0.9384765625,0.869140625,0.974609375},{6,0.814453125,0.7041015625,0.8916015625,0.740234375},{6,0.8935546875,0.7119140625,0.970703125,0.748046875},{6,0.814453125,0.7421875,0.8916015625,0.7783203125},{6,0.8935546875,0.75,0.970703125,0.7861328125},{6,0.814453125,0.7802734375,0.8916015625,0.81640625},{6,0.8935546875,0.7880859375,0.970703125,0.82421875},{6,0.814453125,0.818359375,0.8916015625,0.8544921875},{6,0.8935546875,0.826171875,0.970703125,0.8623046875},{6,0.814453125,0.8564453125,0.8916015625,0.892578125},{6,0.814453125,0.89453125,0.8916015625,0.9306640625},{6,0.8935546875,0.8642578125,0.970703125,0.900390625},{6,0.8935546875,0.90234375,0.970703125,0.9384765625},{6,0.87109375,0.9404296875,0.9482421875,0.9765625},{7,0.0009765625,0.0009765625,0.078125,0.037109375},{7,0.080078125,0.0009765625,0.1572265625,0.037109375}},["ending"]={{6,0.1591796875,0.9384765625,0.236328125,0.974609375},{6,0.080078125,0.9384765625,0.1572265625,0.974609375},{6,0.0009765625,0.9384765625,0.078125,0.974609375},{5,0.9150390625,0.216796875,0.9921875,0.2529296875},{5,0.9150390625,0.1787109375,0.9921875,0.21484375},{5,0.7373046875,0.9619140625,0.814453125,0.998046875},{5,0.658203125,0.9619140625,0.7353515625,0.998046875},{5,0.5791015625,0.9619140625,0.65625,0.998046875},{5,0.5,0.9619140625,0.5771484375,0.998046875},{5,0.4208984375,0.9619140625,0.498046875,0.998046875},{5,0.341796875,0.9580078125,0.4189453125,0.994140625},{5,0.2626953125,0.9619140625,0.33984375,0.998046875}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{5,0.2626953125,0.9619140625,0.33984375,0.998046875},{7,0.1591796875,0.0009765625,0.236328125,0.037109375},{7,0.23828125,0.0009765625,0.3154296875,0.037109375},{7,0.3173828125,0.0009765625,0.39453125,0.037109375},{7,0.396484375,0.0009765625,0.4736328125,0.037109375},{7,0.4755859375,0.0009765625,0.552734375,0.037109375},{7,0.5546875,0.0009765625,0.6318359375,0.037109375},{7,0.6337890625,0.0009765625,0.7109375,0.037109375},{7,0.712890625,0.0009765625,0.7900390625,0.037109375},{7,0.7919921875,0.0009765625,0.869140625,0.037109375},{7,0.87109375,0.0009765625,0.9482421875,0.037109375},{7,0.0009765625,0.0390625,0.078125,0.0751953125}},["hold"]={{7,0.0009765625,0.0390625,0.078125,0.0751953125},{7,0.080078125,0.0390625,0.1572265625,0.0751953125},{7,0.1591796875,0.0390625,0.236328125,0.0751953125},{7,0.23828125,0.0390625,0.3154296875,0.0751953125},{7,0.3173828125,0.0390625,0.39453125,0.0751953125},{7,0.396484375,0.0390625,0.4736328125,0.0751953125},{7,0.4755859375,0.0390625,0.552734375,0.0751953125},{7,0.5546875,0.0390625,0.6318359375,0.0751953125},{7,0.6337890625,0.0390625,0.7109375,0.0751953125},{7,0.712890625,0.0390625,0.7900390625,0.0751953125},{7,0.7919921875,0.0390625,0.869140625,0.0751953125},{7,0.87109375,0.0390625,0.9482421875,0.0751953125},{7,0.0009765625,0.0771484375,0.078125,0.11328125},{7,0.080078125,0.0771484375,0.1572265625,0.11328125},{7,0.1591796875,0.0771484375,0.236328125,0.11328125},{7,0.23828125,0.0771484375,0.3154296875,0.11328125},{7,0.3173828125,0.0771484375,0.39453125,0.11328125},{7,0.396484375,0.0771484375,0.4736328125,0.11328125},{7,0.4755859375,0.0771484375,0.552734375,0.11328125},{7,0.5546875,0.0771484375,0.6318359375,0.11328125},{7,0.6337890625,0.0771484375,0.7109375,0.11328125},{7,0.712890625,0.0771484375,0.7900390625,0.11328125},{7,0.7919921875,0.0771484375,0.869140625,0.11328125},{7,0.87109375,0.0771484375,0.9482421875,0.11328125}},["ending"]={{7,0.0009765625,0.0390625,0.078125,0.0751953125},{7,0.0009765625,0.115234375,0.078125,0.1513671875},{7,0.0009765625,0.1533203125,0.078125,0.189453125},{7,0.0009765625,0.19140625,0.078125,0.2275390625},{7,0.0009765625,0.2294921875,0.078125,0.265625},{7,0.0009765625,0.267578125,0.078125,0.3037109375},{7,0.0009765625,0.3056640625,0.078125,0.341796875},{7,0.0009765625,0.34375,0.078125,0.3798828125},{7,0.0009765625,0.3818359375,0.078125,0.41796875},{7,0.0009765625,0.419921875,0.078125,0.4560546875},{7,0.0009765625,0.4580078125,0.078125,0.494140625},{5,0.2626953125,0.9619140625,0.33984375,0.998046875}},["idle"]={["intro"]={{5,0.2626953125,0.9619140625,0.33984375,0.998046875},{7,0.0009765625,0.49609375,0.078125,0.5322265625},{7,0.0009765625,0.5341796875,0.078125,0.5703125},{7,0.0009765625,0.572265625,0.078125,0.6083984375},{7,0.0009765625,0.6103515625,0.078125,0.646484375},{7,0.0009765625,0.6484375,0.078125,0.6845703125},{7,0.0009765625,0.6865234375,0.078125,0.72265625},{7,0.0009765625,0.724609375,0.078125,0.7607421875},{7,0.0009765625,0.7626953125,0.078125,0.798828125},{7,0.0009765625,0.80078125,0.078125,0.8369140625},{7,0.0009765625,0.8388671875,0.078125,0.875},{7,0.0009765625,0.876953125,0.078125,0.9130859375}},["hold"]={{7,0.0009765625,0.876953125,0.078125,0.9130859375},{7,0.0009765625,0.9150390625,0.078125,0.951171875},{7,0.0009765625,0.953125,0.078125,0.9892578125},{7,0.080078125,0.115234375,0.1572265625,0.1513671875},{7,0.1591796875,0.115234375,0.236328125,0.1513671875},{7,0.23828125,0.115234375,0.3154296875,0.1513671875},{7,0.3173828125,0.115234375,0.39453125,0.1513671875},{7,0.396484375,0.115234375,0.4736328125,0.1513671875},{7,0.4755859375,0.115234375,0.552734375,0.1513671875},{7,0.5546875,0.115234375,0.6318359375,0.1513671875},{7,0.6337890625,0.115234375,0.7109375,0.1513671875},{7,0.712890625,0.115234375,0.7900390625,0.1513671875},{7,0.7919921875,0.115234375,0.869140625,0.1513671875},{7,0.87109375,0.115234375,0.9482421875,0.1513671875},{7,0.080078125,0.1533203125,0.1572265625,0.189453125},{7,0.1591796875,0.1533203125,0.236328125,0.189453125},{7,0.23828125,0.1533203125,0.3154296875,0.189453125},{7,0.3173828125,0.1533203125,0.39453125,0.189453125},{7,0.396484375,0.1533203125,0.4736328125,0.189453125},{7,0.4755859375,0.1533203125,0.552734375,0.189453125},{7,0.5546875,0.1533203125,0.6318359375,0.189453125},{7,0.6337890625,0.1533203125,0.7109375,0.189453125},{7,0.712890625,0.1533203125,0.7900390625,0.189453125},{7,0.7919921875,0.1533203125,0.869140625,0.189453125}},["ending"]={{7,0.0009765625,0.876953125,0.078125,0.9130859375},{7,0.87109375,0.1533203125,0.9482421875,0.189453125},{7,0.080078125,0.19140625,0.1572265625,0.2275390625},{7,0.080078125,0.2294921875,0.1572265625,0.265625},{7,0.080078125,0.267578125,0.1572265625,0.3037109375},{7,0.080078125,0.3056640625,0.1572265625,0.341796875},{7,0.080078125,0.34375,0.1572265625,0.3798828125},{7,0.080078125,0.3818359375,0.1572265625,0.41796875},{7,0.080078125,0.419921875,0.1572265625,0.4560546875},{7,0.080078125,0.4580078125,0.1572265625,0.494140625},{7,0.080078125,0.49609375,0.1572265625,0.5322265625},{5,0.2626953125,0.9619140625,0.33984375,0.998046875}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{7,0.080078125,0.5341796875,0.1572265625,0.5712890625},{7,0.080078125,0.5732421875,0.1572265625,0.6103515625},{7,0.080078125,0.6123046875,0.1572265625,0.6494140625},{7,0.080078125,0.6513671875,0.1572265625,0.6884765625},{7,0.080078125,0.6904296875,0.1572265625,0.7275390625},{7,0.080078125,0.7294921875,0.1572265625,0.7666015625},{7,0.080078125,0.7685546875,0.1572265625,0.8056640625},{7,0.080078125,0.8076171875,0.1572265625,0.8447265625},{7,0.080078125,0.8466796875,0.1572265625,0.8837890625},{7,0.080078125,0.8857421875,0.1572265625,0.9228515625},{7,0.080078125,0.9248046875,0.1572265625,0.9619140625},{7,0.1591796875,0.19140625,0.236328125,0.228515625}},["hold"]={{7,0.1591796875,0.19140625,0.236328125,0.228515625},{7,0.23828125,0.19140625,0.3154296875,0.228515625},{7,0.3173828125,0.19140625,0.39453125,0.228515625},{7,0.396484375,0.19140625,0.4736328125,0.228515625},{7,0.4755859375,0.19140625,0.552734375,0.228515625},{7,0.5546875,0.19140625,0.6318359375,0.228515625},{7,0.6337890625,0.19140625,0.7109375,0.228515625},{7,0.712890625,0.19140625,0.7900390625,0.228515625},{7,0.7919921875,0.19140625,0.869140625,0.228515625},{7,0.87109375,0.19140625,0.9482421875,0.228515625},{7,0.1591796875,0.23046875,0.236328125,0.267578125},{7,0.23828125,0.23046875,0.3154296875,0.267578125},{7,0.3173828125,0.23046875,0.39453125,0.267578125},{7,0.396484375,0.23046875,0.4736328125,0.267578125},{7,0.4755859375,0.23046875,0.552734375,0.267578125},{7,0.5546875,0.23046875,0.6318359375,0.267578125},{7,0.6337890625,0.23046875,0.7109375,0.267578125},{7,0.712890625,0.23046875,0.7900390625,0.267578125},{7,0.7919921875,0.23046875,0.869140625,0.267578125},{7,0.87109375,0.23046875,0.9482421875,0.267578125},{7,0.1591796875,0.26953125,0.236328125,0.306640625},{7,0.1591796875,0.30859375,0.236328125,0.345703125},{7,0.1591796875,0.34765625,0.236328125,0.384765625},{7,0.1591796875,0.38671875,0.236328125,0.423828125}},["ending"]={{7,0.1591796875,0.19140625,0.236328125,0.228515625},{7,0.080078125,0.9248046875,0.1572265625,0.9619140625},{7,0.080078125,0.8857421875,0.1572265625,0.9228515625},{7,0.080078125,0.8466796875,0.1572265625,0.8837890625},{7,0.080078125,0.8076171875,0.1572265625,0.8447265625},{7,0.080078125,0.7685546875,0.1572265625,0.8056640625},{7,0.080078125,0.7294921875,0.1572265625,0.7666015625},{7,0.080078125,0.6904296875,0.1572265625,0.7275390625},{7,0.080078125,0.6513671875,0.1572265625,0.6884765625},{7,0.080078125,0.6123046875,0.1572265625,0.6494140625},{7,0.080078125,0.5732421875,0.1572265625,0.6103515625},{7,0.080078125,0.5341796875,0.1572265625,0.5712890625}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{7,0.080078125,0.5341796875,0.1572265625,0.5712890625},{7,0.1591796875,0.42578125,0.236328125,0.462890625},{7,0.1591796875,0.46484375,0.236328125,0.501953125},{7,0.1591796875,0.50390625,0.236328125,0.541015625},{7,0.1591796875,0.54296875,0.236328125,0.580078125},{7,0.1591796875,0.58203125,0.236328125,0.619140625},{7,0.1591796875,0.62109375,0.236328125,0.658203125},{7,0.1591796875,0.66015625,0.236328125,0.697265625},{7,0.1591796875,0.69921875,0.236328125,0.736328125},{7,0.1591796875,0.73828125,0.236328125,0.775390625},{7,0.1591796875,0.77734375,0.236328125,0.814453125},{7,0.1591796875,0.81640625,0.236328125,0.853515625}},["hold"]={{7,0.1591796875,0.81640625,0.236328125,0.853515625},{7,0.1591796875,0.85546875,0.236328125,0.892578125},{7,0.1591796875,0.89453125,0.236328125,0.931640625},{7,0.1591796875,0.93359375,0.236328125,0.970703125},{7,0.23828125,0.26953125,0.3154296875,0.306640625},{7,0.3173828125,0.26953125,0.39453125,0.306640625},{7,0.396484375,0.26953125,0.4736328125,0.306640625},{7,0.4755859375,0.26953125,0.552734375,0.306640625},{7,0.5546875,0.26953125,0.6318359375,0.306640625},{7,0.6337890625,0.26953125,0.7109375,0.306640625},{7,0.712890625,0.26953125,0.7900390625,0.306640625},{7,0.7919921875,0.26953125,0.869140625,0.306640625},{7,0.87109375,0.26953125,0.9482421875,0.306640625},{7,0.23828125,0.30859375,0.3154296875,0.345703125},{7,0.3173828125,0.30859375,0.39453125,0.345703125},{7,0.396484375,0.30859375,0.4736328125,0.345703125},{7,0.4755859375,0.30859375,0.552734375,0.345703125},{7,0.5546875,0.30859375,0.6318359375,0.345703125},{7,0.6337890625,0.30859375,0.7109375,0.345703125},{7,0.712890625,0.30859375,0.7900390625,0.345703125},{7,0.7919921875,0.30859375,0.869140625,0.345703125},{7,0.87109375,0.30859375,0.9482421875,0.345703125},{7,0.23828125,0.34765625,0.3154296875,0.384765625},{7,0.23828125,0.38671875,0.3154296875,0.423828125}},["ending"]={{7,0.1591796875,0.81640625,0.236328125,0.853515625},{7,0.23828125,0.42578125,0.3154296875,0.462890625},{7,0.23828125,0.46484375,0.3154296875,0.501953125},{7,0.23828125,0.50390625,0.3154296875,0.541015625},{7,0.23828125,0.54296875,0.3154296875,0.580078125},{7,0.23828125,0.58203125,0.3154296875,0.619140625},{7,0.23828125,0.62109375,0.3154296875,0.658203125},{7,0.23828125,0.66015625,0.3154296875,0.697265625},{7,0.23828125,0.69921875,0.3154296875,0.736328125},{7,0.23828125,0.73828125,0.3154296875,0.775390625},{7,0.23828125,0.77734375,0.3154296875,0.814453125},{7,0.080078125,0.5341796875,0.1572265625,0.5712890625}},["idle"]={["intro"]={{7,0.080078125,0.5341796875,0.1572265625,0.5712890625},{7,0.23828125,0.81640625,0.3154296875,0.853515625},{7,0.23828125,0.85546875,0.3154296875,0.892578125},{7,0.23828125,0.89453125,0.3154296875,0.931640625},{7,0.23828125,0.93359375,0.3154296875,0.970703125},{7,0.3173828125,0.34765625,0.39453125,0.384765625},{7,0.396484375,0.34765625,0.4736328125,0.384765625},{7,0.4755859375,0.34765625,0.552734375,0.384765625},{7,0.5546875,0.34765625,0.6318359375,0.384765625},{7,0.6337890625,0.34765625,0.7109375,0.384765625},{7,0.712890625,0.34765625,0.7900390625,0.384765625},{7,0.7919921875,0.34765625,0.869140625,0.384765625}},["hold"]={{7,0.7919921875,0.34765625,0.869140625,0.384765625},{7,0.87109375,0.34765625,0.9482421875,0.384765625},{7,0.3173828125,0.38671875,0.39453125,0.423828125},{7,0.396484375,0.38671875,0.4736328125,0.423828125},{7,0.4755859375,0.38671875,0.552734375,0.423828125},{7,0.5546875,0.38671875,0.6318359375,0.423828125},{7,0.6337890625,0.38671875,0.7109375,0.423828125},{7,0.712890625,0.38671875,0.7900390625,0.423828125},{7,0.7919921875,0.38671875,0.869140625,0.423828125},{7,0.87109375,0.38671875,0.9482421875,0.423828125},{7,0.3173828125,0.42578125,0.39453125,0.462890625},{7,0.3173828125,0.46484375,0.39453125,0.501953125},{7,0.3173828125,0.50390625,0.39453125,0.541015625},{7,0.3173828125,0.54296875,0.39453125,0.580078125},{7,0.3173828125,0.58203125,0.39453125,0.619140625},{7,0.3173828125,0.62109375,0.39453125,0.658203125},{7,0.3173828125,0.66015625,0.39453125,0.697265625},{7,0.3173828125,0.69921875,0.39453125,0.736328125},{7,0.3173828125,0.73828125,0.39453125,0.775390625},{7,0.3173828125,0.77734375,0.39453125,0.814453125},{7,0.3173828125,0.81640625,0.39453125,0.853515625},{7,0.3173828125,0.85546875,0.39453125,0.892578125},{7,0.3173828125,0.89453125,0.39453125,0.931640625},{7,0.3173828125,0.93359375,0.39453125,0.970703125}},["ending"]={{7,0.7919921875,0.34765625,0.869140625,0.384765625},{7,0.396484375,0.42578125,0.4736328125,0.462890625},{7,0.4755859375,0.42578125,0.552734375,0.462890625},{7,0.5546875,0.42578125,0.6318359375,0.462890625},{7,0.6337890625,0.42578125,0.7109375,0.462890625},{7,0.712890625,0.42578125,0.7900390625,0.462890625},{7,0.7919921875,0.42578125,0.869140625,0.462890625},{7,0.87109375,0.42578125,0.9482421875,0.462890625},{7,0.396484375,0.46484375,0.4736328125,0.501953125},{7,0.4755859375,0.46484375,0.552734375,0.501953125},{7,0.5546875,0.46484375,0.6318359375,0.501953125},{7,0.080078125,0.5341796875,0.1572265625,0.5712890625}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{2,0.9072265625,0.2314453125,0.99609375,0.2958984375},{2,0.9072265625,0.2978515625,0.99609375,0.3623046875},{2,0.9072265625,0.3642578125,0.99609375,0.4287109375},{2,0.9072265625,0.4306640625,0.99609375,0.4951171875},{2,0.9072265625,0.4970703125,0.99609375,0.5615234375},{2,0.9072265625,0.5634765625,0.99609375,0.6279296875},{1,0.0009765625,0.9228515625,0.08984375,0.9873046875},{1,0.091796875,0.9228515625,0.1806640625,0.9873046875},{1,0.1826171875,0.9228515625,0.271484375,0.9873046875},{1,0.2734375,0.9228515625,0.3623046875,0.9873046875},{1,0.3642578125,0.9228515625,0.453125,0.9873046875},{1,0.455078125,0.9228515625,0.5439453125,0.9873046875}},["hold"]={{1,0.455078125,0.9228515625,0.5439453125,0.9873046875},{1,0.5458984375,0.9228515625,0.634765625,0.9873046875},{1,0.63671875,0.9228515625,0.7255859375,0.9873046875},{1,0.7275390625,0.9228515625,0.81640625,0.9873046875},{1,0.818359375,0.9228515625,0.9072265625,0.9873046875},{1,0.9091796875,0.9228515625,0.998046875,0.9873046875},{2,0.0009765625,0.9228515625,0.08984375,0.9873046875},{2,0.091796875,0.9228515625,0.1806640625,0.9873046875},{2,0.1826171875,0.9169921875,0.271484375,0.9814453125},{2,0.2734375,0.9169921875,0.3623046875,0.9814453125},{5,0.88671875,0.2587890625,0.9755859375,0.3232421875},{5,0.88671875,0.3251953125,0.9755859375,0.3896484375},{5,0.88671875,0.3916015625,0.9755859375,0.4560546875},{5,0.88671875,0.7275390625,0.9755859375,0.7919921875},{5,0.88671875,0.7939453125,0.9755859375,0.8583984375},{5,0.88671875,0.8603515625,0.9755859375,0.9248046875},{5,0.88671875,0.9267578125,0.9755859375,0.9912109375},{5,0.3056640625,0.8916015625,0.39453125,0.9560546875},{2,0.3642578125,0.9052734375,0.453125,0.9697265625},{2,0.455078125,0.9052734375,0.5439453125,0.9697265625},{2,0.5458984375,0.9052734375,0.634765625,0.9697265625},{2,0.63671875,0.9052734375,0.7255859375,0.9697265625},{2,0.7275390625,0.9052734375,0.81640625,0.9697265625},{2,0.818359375,0.9052734375,0.9072265625,0.9697265625}},["ending"]={{1,0.455078125,0.9228515625,0.5439453125,0.9873046875},{1,0.3642578125,0.9228515625,0.453125,0.9873046875},{1,0.2734375,0.9228515625,0.3623046875,0.9873046875},{1,0.1826171875,0.9228515625,0.271484375,0.9873046875},{1,0.091796875,0.9228515625,0.1806640625,0.9873046875},{1,0.0009765625,0.9228515625,0.08984375,0.9873046875},{2,0.9072265625,0.5634765625,0.99609375,0.6279296875},{2,0.9072265625,0.4970703125,0.99609375,0.5615234375},{2,0.9072265625,0.4306640625,0.99609375,0.4951171875},{2,0.9072265625,0.3642578125,0.99609375,0.4287109375},{2,0.9072265625,0.2978515625,0.99609375,0.3623046875},{2,0.9072265625,0.2314453125,0.99609375,0.2958984375}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.1650390625,0.2294921875},{1,0.0009765625,0.2314453125,0.1650390625,0.4599609375},{1,0.0009765625,0.4619140625,0.1650390625,0.6904296875},{1,0.0009765625,0.6923828125,0.1650390625,0.9208984375},{1,0.1669921875,0.0009765625,0.3310546875,0.2294921875},{1,0.3330078125,0.0009765625,0.4970703125,0.2294921875},{1,0.4990234375,0.0009765625,0.6630859375,0.2294921875},{1,0.6650390625,0.0009765625,0.8291015625,0.2294921875},{1,0.8310546875,0.0009765625,0.9951171875,0.2294921875},{1,0.1669921875,0.2314453125,0.3310546875,0.4599609375},{1,0.1669921875,0.4619140625,0.3310546875,0.6904296875},{1,0.1669921875,0.6923828125,0.3310546875,0.9208984375}},["hold"]={{1,0.1669921875,0.6923828125,0.3310546875,0.9208984375},{1,0.3330078125,0.2314453125,0.4970703125,0.4599609375},{1,0.3330078125,0.4619140625,0.4970703125,0.6904296875},{1,0.3330078125,0.6923828125,0.4970703125,0.9208984375},{1,0.4990234375,0.2314453125,0.6630859375,0.4599609375},{1,0.6650390625,0.2314453125,0.8291015625,0.4599609375},{1,0.8310546875,0.2314453125,0.9951171875,0.4599609375},{1,0.4990234375,0.4619140625,0.6630859375,0.6904296875},{1,0.4990234375,0.6923828125,0.6630859375,0.9208984375},{1,0.6650390625,0.4619140625,0.8291015625,0.6904296875},{1,0.8310546875,0.4619140625,0.9951171875,0.6904296875},{1,0.6650390625,0.6923828125,0.8291015625,0.9208984375},{1,0.8310546875,0.6923828125,0.9951171875,0.9208984375},{2,0.0009765625,0.0009765625,0.1650390625,0.2294921875},{2,0.0009765625,0.2314453125,0.1650390625,0.4599609375},{2,0.0009765625,0.4619140625,0.1650390625,0.6904296875},{2,0.0009765625,0.6923828125,0.1650390625,0.9208984375},{2,0.1669921875,0.0009765625,0.3310546875,0.2294921875},{2,0.3330078125,0.0009765625,0.4970703125,0.2294921875},{2,0.4990234375,0.0009765625,0.6630859375,0.2294921875},{2,0.6650390625,0.0009765625,0.8291015625,0.2294921875},{2,0.8310546875,0.0009765625,0.9951171875,0.2294921875},{2,0.1669921875,0.2314453125,0.3310546875,0.4599609375},{2,0.1669921875,0.4619140625,0.3310546875,0.6904296875}},["ending"]={{1,0.1669921875,0.6923828125,0.3310546875,0.9208984375},{1,0.1669921875,0.4619140625,0.3310546875,0.6904296875},{1,0.1669921875,0.2314453125,0.3310546875,0.4599609375},{1,0.8310546875,0.0009765625,0.9951171875,0.2294921875},{1,0.6650390625,0.0009765625,0.8291015625,0.2294921875},{1,0.4990234375,0.0009765625,0.6630859375,0.2294921875},{1,0.3330078125,0.0009765625,0.4970703125,0.2294921875},{1,0.1669921875,0.0009765625,0.3310546875,0.2294921875},{1,0.0009765625,0.6923828125,0.1650390625,0.9208984375},{1,0.0009765625,0.4619140625,0.1650390625,0.6904296875},{1,0.0009765625,0.2314453125,0.1650390625,0.4599609375},{1,0.0009765625,0.0009765625,0.1650390625,0.2294921875}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{4,0.3837890625,0.0009765625,0.4794921875,0.1279296875},{4,0.4814453125,0.0009765625,0.5771484375,0.1279296875},{4,0.5791015625,0.0009765625,0.6748046875,0.1279296875},{4,0.6767578125,0.0009765625,0.7724609375,0.1279296875},{4,0.7744140625,0.0009765625,0.8701171875,0.1279296875},{4,0.8720703125,0.0009765625,0.9677734375,0.1279296875},{4,0.3837890625,0.1298828125,0.4794921875,0.2568359375},{4,0.1923828125,0.2255859375,0.2880859375,0.3525390625},{4,0.4814453125,0.1298828125,0.5771484375,0.2568359375},{4,0.5791015625,0.1298828125,0.6748046875,0.2568359375},{4,0.6767578125,0.1298828125,0.7724609375,0.2568359375},{4,0.7744140625,0.1298828125,0.8701171875,0.2568359375}},["hold"]={{4,0.7744140625,0.1298828125,0.8701171875,0.2568359375},{4,0.8720703125,0.1298828125,0.9677734375,0.2568359375},{4,0.1923828125,0.3544921875,0.2880859375,0.4814453125},{4,0.1923828125,0.4833984375,0.2880859375,0.6103515625},{4,0.1923828125,0.6123046875,0.2880859375,0.7392578125},{4,0.1923828125,0.7412109375,0.2880859375,0.8681640625},{4,0.1923828125,0.8701171875,0.2880859375,0.9970703125},{4,0.2900390625,0.2587890625,0.3857421875,0.3857421875},{4,0.2900390625,0.3876953125,0.3857421875,0.5146484375},{4,0.2900390625,0.5166015625,0.3857421875,0.6435546875},{4,0.2900390625,0.6455078125,0.3857421875,0.7724609375},{4,0.2900390625,0.7744140625,0.3857421875,0.9013671875},{4,0.3876953125,0.2587890625,0.4833984375,0.3857421875},{4,0.4853515625,0.2587890625,0.5810546875,0.3857421875},{4,0.5830078125,0.2587890625,0.6787109375,0.3857421875},{4,0.6806640625,0.2587890625,0.7763671875,0.3857421875},{4,0.7783203125,0.2587890625,0.8740234375,0.3857421875},{4,0.8759765625,0.2587890625,0.9716796875,0.3857421875},{4,0.3876953125,0.3876953125,0.4833984375,0.5146484375},{4,0.3876953125,0.5166015625,0.4833984375,0.6435546875},{4,0.3876953125,0.6455078125,0.4833984375,0.7724609375},{4,0.3876953125,0.7744140625,0.4833984375,0.9013671875},{4,0.4853515625,0.3876953125,0.5810546875,0.5146484375},{4,0.5830078125,0.3876953125,0.6787109375,0.5146484375}},["ending"]={{4,0.7744140625,0.1298828125,0.8701171875,0.2568359375},{4,0.6806640625,0.3876953125,0.7763671875,0.5146484375},{4,0.7783203125,0.3876953125,0.8740234375,0.5146484375},{4,0.8759765625,0.3876953125,0.9716796875,0.5146484375},{4,0.4853515625,0.5166015625,0.5810546875,0.6435546875},{4,0.4853515625,0.6455078125,0.5810546875,0.7724609375},{4,0.4853515625,0.7744140625,0.5810546875,0.9013671875},{4,0.5830078125,0.5166015625,0.6787109375,0.6435546875},{4,0.6806640625,0.5166015625,0.7763671875,0.6435546875},{4,0.7783203125,0.5166015625,0.8740234375,0.6435546875},{4,0.8759765625,0.5166015625,0.9716796875,0.6435546875},{4,0.3837890625,0.0009765625,0.4794921875,0.1279296875}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{4,0.5830078125,0.6455078125,0.6826171875,0.7724609375},{4,0.5830078125,0.7744140625,0.6826171875,0.9013671875},{4,0.6845703125,0.6455078125,0.7841796875,0.7724609375},{4,0.6845703125,0.7744140625,0.7841796875,0.9013671875},{4,0.7861328125,0.6455078125,0.8857421875,0.7724609375},{4,0.8876953125,0.6455078125,0.9873046875,0.7724609375},{4,0.7861328125,0.7744140625,0.8857421875,0.9013671875},{4,0.8876953125,0.7744140625,0.9873046875,0.9013671875},{5,0.0009765625,0.0009765625,0.1005859375,0.1279296875},{5,0.0009765625,0.1298828125,0.1005859375,0.2568359375},{5,0.0009765625,0.2587890625,0.1005859375,0.3857421875},{5,0.0009765625,0.3876953125,0.1005859375,0.5146484375}},["hold"]={{5,0.0009765625,0.3876953125,0.1005859375,0.5146484375},{5,0.0009765625,0.5166015625,0.1005859375,0.6435546875},{5,0.0009765625,0.6455078125,0.1005859375,0.7724609375},{5,0.0009765625,0.7744140625,0.1005859375,0.9013671875},{5,0.1025390625,0.0009765625,0.2021484375,0.1279296875},{5,0.2041015625,0.0009765625,0.3037109375,0.1279296875},{5,0.3056640625,0.0009765625,0.4052734375,0.1279296875},{5,0.4072265625,0.0009765625,0.5068359375,0.1279296875},{5,0.5087890625,0.0009765625,0.6083984375,0.1279296875},{5,0.6103515625,0.0009765625,0.7099609375,0.1279296875},{5,0.7119140625,0.0009765625,0.8115234375,0.1279296875},{5,0.8134765625,0.0009765625,0.9130859375,0.1279296875},{5,0.1025390625,0.1298828125,0.2021484375,0.2568359375},{5,0.1025390625,0.2587890625,0.2021484375,0.3857421875},{5,0.1025390625,0.3876953125,0.2021484375,0.5146484375},{5,0.1025390625,0.5166015625,0.2021484375,0.6435546875},{5,0.1025390625,0.6455078125,0.2021484375,0.7724609375},{5,0.1025390625,0.7744140625,0.2021484375,0.9013671875},{5,0.2041015625,0.1298828125,0.3037109375,0.2568359375},{5,0.3056640625,0.1298828125,0.4052734375,0.2568359375},{5,0.4072265625,0.1298828125,0.5068359375,0.2568359375},{5,0.5087890625,0.1298828125,0.6083984375,0.2568359375},{5,0.6103515625,0.1298828125,0.7099609375,0.2568359375},{5,0.7119140625,0.1298828125,0.8115234375,0.2568359375}},["ending"]={{5,0.0009765625,0.3876953125,0.1005859375,0.5146484375},{5,0.8134765625,0.1298828125,0.9130859375,0.2568359375},{5,0.2041015625,0.2587890625,0.3037109375,0.3857421875},{5,0.2041015625,0.3876953125,0.3037109375,0.5146484375},{5,0.2041015625,0.5166015625,0.3037109375,0.6435546875},{5,0.2041015625,0.6455078125,0.3037109375,0.7724609375},{5,0.2041015625,0.7744140625,0.3037109375,0.9013671875},{5,0.3056640625,0.2587890625,0.4052734375,0.3857421875},{5,0.3056640625,0.3876953125,0.4052734375,0.5146484375},{5,0.3056640625,0.5166015625,0.4052734375,0.6435546875},{5,0.3056640625,0.6455078125,0.4052734375,0.7724609375},{4,0.5830078125,0.6455078125,0.6826171875,0.7724609375}},["pages"]={"StudioDruidRestorationChannelPlusSize288Page1.tga","StudioDruidRestorationChannelPlusSize288Page2.tga","StudioDruidRestorationChannelPlusSize288Page3.tga","StudioDruidRestorationChannelPlusSize288Page4.tga","StudioDruidRestorationChannelPlusSize288Page5.tga","StudioDruidRestorationChannelPlusSize288Page6.tga","StudioDruidRestorationChannelPlusSize288Page7.tga"}}},[384]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{3,0.6630859375,0.6142578125,0.916015625,0.9111328125},{4,0.0009765625,0.0009765625,0.25390625,0.2978515625},{4,0.0009765625,0.2998046875,0.25390625,0.5966796875},{4,0.0009765625,0.5986328125,0.25390625,0.8955078125},{4,0.255859375,0.0009765625,0.5087890625,0.2978515625},{4,0.5107421875,0.0009765625,0.763671875,0.2978515625},{4,0.255859375,0.2998046875,0.5087890625,0.5966796875},{4,0.255859375,0.5986328125,0.5087890625,0.8955078125},{4,0.5107421875,0.2998046875,0.763671875,0.5966796875},{4,0.5107421875,0.5986328125,0.763671875,0.8955078125},{5,0.0009765625,0.0009765625,0.25390625,0.2978515625},{5,0.0009765625,0.2998046875,0.25390625,0.5966796875}},["hold"]={{5,0.0009765625,0.2998046875,0.25390625,0.5966796875},{5,0.0009765625,0.5986328125,0.25390625,0.8955078125},{5,0.255859375,0.0009765625,0.5087890625,0.2978515625},{5,0.5107421875,0.0009765625,0.763671875,0.2978515625},{5,0.255859375,0.2998046875,0.5087890625,0.5966796875},{5,0.255859375,0.5986328125,0.5087890625,0.8955078125},{5,0.5107421875,0.2998046875,0.763671875,0.5966796875},{5,0.5107421875,0.5986328125,0.763671875,0.8955078125},{6,0.0009765625,0.0009765625,0.25390625,0.2978515625},{6,0.0009765625,0.2998046875,0.25390625,0.5966796875},{6,0.0009765625,0.5986328125,0.25390625,0.8955078125},{6,0.255859375,0.0009765625,0.5087890625,0.2978515625},{6,0.5107421875,0.0009765625,0.763671875,0.2978515625},{6,0.255859375,0.2998046875,0.5087890625,0.5966796875},{6,0.255859375,0.5986328125,0.5087890625,0.8955078125},{6,0.5107421875,0.2998046875,0.763671875,0.5966796875},{6,0.5107421875,0.5986328125,0.763671875,0.8955078125},{7,0.0009765625,0.0009765625,0.25390625,0.2978515625},{7,0.0009765625,0.2998046875,0.25390625,0.5966796875},{7,0.0009765625,0.5986328125,0.25390625,0.8955078125},{7,0.255859375,0.0009765625,0.5087890625,0.2978515625},{7,0.5107421875,0.0009765625,0.763671875,0.2978515625},{7,0.255859375,0.2998046875,0.5087890625,0.5966796875},{7,0.255859375,0.5986328125,0.5087890625,0.8955078125}},["ending"]={{5,0.0009765625,0.2998046875,0.25390625,0.5966796875},{5,0.0009765625,0.0009765625,0.25390625,0.2978515625},{4,0.5107421875,0.5986328125,0.763671875,0.8955078125},{4,0.5107421875,0.2998046875,0.763671875,0.5966796875},{4,0.255859375,0.5986328125,0.5087890625,0.8955078125},{4,0.255859375,0.2998046875,0.5087890625,0.5966796875},{4,0.5107421875,0.0009765625,0.763671875,0.2978515625},{4,0.255859375,0.0009765625,0.5087890625,0.2978515625},{4,0.0009765625,0.5986328125,0.25390625,0.8955078125},{4,0.0009765625,0.2998046875,0.25390625,0.5966796875},{4,0.0009765625,0.0009765625,0.25390625,0.2978515625},{3,0.6630859375,0.6142578125,0.916015625,0.9111328125}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{9,0.91015625,0.0009765625,0.9951171875,0.1171875},{9,0.91015625,0.119140625,0.9951171875,0.2353515625},{9,0.91015625,0.2373046875,0.9951171875,0.353515625},{9,0.91015625,0.35546875,0.9951171875,0.4716796875},{7,0.900390625,0.0009765625,0.9853515625,0.1171875},{7,0.900390625,0.119140625,0.9853515625,0.2353515625},{4,0.900390625,0.0009765625,0.9853515625,0.1171875},{4,0.900390625,0.119140625,0.9853515625,0.2353515625},{4,0.900390625,0.2373046875,0.9853515625,0.353515625},{4,0.900390625,0.35546875,0.9853515625,0.4716796875},{4,0.900390625,0.4736328125,0.9853515625,0.58984375},{4,0.900390625,0.591796875,0.9853515625,0.7080078125}},["hold"]={{4,0.900390625,0.591796875,0.9853515625,0.7080078125},{4,0.900390625,0.7099609375,0.9853515625,0.826171875},{5,0.900390625,0.0009765625,0.9853515625,0.1171875},{5,0.900390625,0.119140625,0.9853515625,0.2353515625},{5,0.900390625,0.2373046875,0.9853515625,0.353515625},{5,0.900390625,0.35546875,0.9853515625,0.4716796875},{5,0.900390625,0.4736328125,0.9853515625,0.58984375},{5,0.900390625,0.591796875,0.9853515625,0.7080078125},{5,0.900390625,0.7099609375,0.9853515625,0.826171875},{6,0.900390625,0.0009765625,0.9853515625,0.1171875},{6,0.900390625,0.119140625,0.9853515625,0.2353515625},{6,0.900390625,0.2373046875,0.9853515625,0.353515625},{6,0.900390625,0.35546875,0.9853515625,0.4716796875},{6,0.900390625,0.4736328125,0.9853515625,0.58984375},{6,0.900390625,0.591796875,0.9853515625,0.7080078125},{6,0.900390625,0.7099609375,0.9853515625,0.826171875},{7,0.765625,0.8603515625,0.8505859375,0.9765625},{7,0.8525390625,0.8603515625,0.9375,0.9765625},{8,0.390625,0.857421875,0.4755859375,0.9736328125},{8,0.4775390625,0.857421875,0.5625,0.9736328125},{8,0.564453125,0.857421875,0.6494140625,0.9736328125},{8,0.6513671875,0.857421875,0.736328125,0.9736328125},{8,0.73828125,0.8564453125,0.8232421875,0.97265625},{8,0.8251953125,0.8564453125,0.91015625,0.97265625}},["ending"]={{4,0.900390625,0.591796875,0.9853515625,0.7080078125},{8,0.912109375,0.8564453125,0.9970703125,0.97265625},{9,0.0009765625,0.85546875,0.0859375,0.9716796875},{9,0.087890625,0.85546875,0.1728515625,0.9716796875},{9,0.1748046875,0.85546875,0.259765625,0.9716796875},{9,0.26171875,0.85546875,0.3466796875,0.9716796875},{9,0.3486328125,0.85546875,0.43359375,0.9716796875},{3,0.8837890625,0.0009765625,0.96875,0.1171875},{3,0.8837890625,0.119140625,0.96875,0.2353515625},{3,0.8837890625,0.2373046875,0.96875,0.353515625},{3,0.8837890625,0.35546875,0.96875,0.4716796875},{9,0.91015625,0.0009765625,0.9951171875,0.1171875}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{9,0.5205078125,0.513671875,0.673828125,0.66796875},{9,0.67578125,0.513671875,0.8291015625,0.66796875},{9,0.8310546875,0.513671875,0.984375,0.66796875},{9,0.5205078125,0.669921875,0.673828125,0.82421875},{9,0.5205078125,0.826171875,0.673828125,0.98046875},{9,0.67578125,0.669921875,0.8291015625,0.82421875},{9,0.8310546875,0.669921875,0.984375,0.82421875},{9,0.67578125,0.826171875,0.8291015625,0.98046875},{9,0.8310546875,0.826171875,0.984375,0.98046875},{10,0.0009765625,0.0009765625,0.154296875,0.1552734375},{10,0.0009765625,0.1572265625,0.154296875,0.3115234375},{10,0.0009765625,0.3134765625,0.154296875,0.4677734375}},["hold"]={{10,0.0009765625,0.3134765625,0.154296875,0.4677734375},{10,0.0009765625,0.4697265625,0.154296875,0.6240234375},{10,0.0009765625,0.6259765625,0.154296875,0.7802734375},{10,0.0009765625,0.7822265625,0.154296875,0.9365234375},{10,0.15625,0.0009765625,0.3095703125,0.1552734375},{10,0.3115234375,0.0009765625,0.46484375,0.1552734375},{10,0.466796875,0.0009765625,0.6201171875,0.1552734375},{10,0.6220703125,0.0009765625,0.775390625,0.1552734375},{10,0.77734375,0.0009765625,0.9306640625,0.1552734375},{10,0.15625,0.1572265625,0.3095703125,0.3115234375},{10,0.15625,0.3134765625,0.3095703125,0.4677734375},{10,0.15625,0.4697265625,0.3095703125,0.6240234375},{10,0.15625,0.6259765625,0.3095703125,0.7802734375},{10,0.15625,0.7822265625,0.3095703125,0.9365234375},{10,0.3115234375,0.1572265625,0.46484375,0.3115234375},{10,0.466796875,0.1572265625,0.6201171875,0.3115234375},{10,0.6220703125,0.1572265625,0.775390625,0.3115234375},{10,0.77734375,0.1572265625,0.9306640625,0.3115234375},{10,0.3115234375,0.3134765625,0.46484375,0.4677734375},{10,0.3115234375,0.4697265625,0.46484375,0.6240234375},{10,0.3115234375,0.6259765625,0.46484375,0.7802734375},{10,0.3115234375,0.7822265625,0.46484375,0.9365234375},{10,0.466796875,0.3134765625,0.6201171875,0.4677734375},{10,0.6220703125,0.3134765625,0.775390625,0.4677734375}},["ending"]={{10,0.0009765625,0.3134765625,0.154296875,0.4677734375},{10,0.77734375,0.3134765625,0.9306640625,0.4677734375},{10,0.466796875,0.4697265625,0.6201171875,0.6240234375},{10,0.466796875,0.6259765625,0.6201171875,0.7802734375},{10,0.466796875,0.7822265625,0.6201171875,0.9365234375},{10,0.6220703125,0.4697265625,0.775390625,0.6240234375},{10,0.77734375,0.4697265625,0.9306640625,0.6240234375},{10,0.6220703125,0.6259765625,0.775390625,0.7802734375},{10,0.6220703125,0.7822265625,0.775390625,0.9365234375},{10,0.77734375,0.6259765625,0.9306640625,0.7802734375},{10,0.77734375,0.7822265625,0.9306640625,0.9365234375},{9,0.5205078125,0.513671875,0.673828125,0.66796875}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"},["matched"]={["layer"]="treant",["intro"]={{9,0.5205078125,0.513671875,0.673828125,0.66796875},{11,0.0009765625,0.0009765625,0.154296875,0.1552734375},{11,0.0009765625,0.1572265625,0.154296875,0.3115234375},{11,0.0009765625,0.3134765625,0.154296875,0.4677734375},{11,0.0009765625,0.4697265625,0.154296875,0.6240234375},{11,0.0009765625,0.6259765625,0.154296875,0.7802734375},{11,0.0009765625,0.7822265625,0.154296875,0.9365234375},{11,0.15625,0.0009765625,0.3095703125,0.1552734375},{11,0.3115234375,0.0009765625,0.46484375,0.1552734375},{11,0.466796875,0.0009765625,0.6201171875,0.1552734375},{11,0.6220703125,0.0009765625,0.775390625,0.1552734375},{11,0.77734375,0.0009765625,0.9306640625,0.1552734375}},["hold"]={{11,0.77734375,0.0009765625,0.9306640625,0.1552734375},{11,0.15625,0.1572265625,0.3095703125,0.3115234375},{11,0.15625,0.3134765625,0.3095703125,0.4677734375},{11,0.15625,0.4697265625,0.3095703125,0.6240234375},{11,0.15625,0.6259765625,0.3095703125,0.7802734375},{11,0.15625,0.7822265625,0.3095703125,0.9365234375},{11,0.3115234375,0.1572265625,0.46484375,0.3115234375},{11,0.466796875,0.1572265625,0.6201171875,0.3115234375},{11,0.6220703125,0.1572265625,0.775390625,0.3115234375},{11,0.77734375,0.1572265625,0.9306640625,0.3115234375},{11,0.3115234375,0.3134765625,0.46484375,0.4677734375},{11,0.3115234375,0.4697265625,0.46484375,0.6240234375},{11,0.3115234375,0.6259765625,0.46484375,0.7802734375},{11,0.3115234375,0.7822265625,0.46484375,0.9365234375},{11,0.466796875,0.3134765625,0.6201171875,0.4677734375},{11,0.6220703125,0.3134765625,0.775390625,0.4677734375},{11,0.77734375,0.3134765625,0.9306640625,0.4677734375},{11,0.466796875,0.4697265625,0.6201171875,0.6240234375},{11,0.466796875,0.6259765625,0.6201171875,0.7802734375},{11,0.466796875,0.7822265625,0.6201171875,0.9365234375},{11,0.6220703125,0.4697265625,0.775390625,0.6240234375},{11,0.77734375,0.4697265625,0.9306640625,0.6240234375},{11,0.6220703125,0.6259765625,0.775390625,0.7802734375},{11,0.6220703125,0.7822265625,0.775390625,0.9365234375}},["ending"]={{11,0.77734375,0.0009765625,0.9306640625,0.1552734375},{11,0.77734375,0.6259765625,0.9306640625,0.7802734375},{11,0.77734375,0.7822265625,0.9306640625,0.9365234375},{12,0.0009765625,0.0009765625,0.154296875,0.1552734375},{12,0.0009765625,0.1572265625,0.154296875,0.3115234375},{12,0.0009765625,0.3134765625,0.154296875,0.4677734375},{12,0.0009765625,0.4697265625,0.154296875,0.6240234375},{12,0.0009765625,0.6259765625,0.154296875,0.7802734375},{12,0.0009765625,0.7822265625,0.154296875,0.9365234375},{12,0.15625,0.0009765625,0.3095703125,0.1552734375},{12,0.3115234375,0.0009765625,0.46484375,0.1552734375},{9,0.5205078125,0.513671875,0.673828125,0.66796875}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{7,0.6455078125,0.9482421875,0.748046875,0.99609375},{4,0.841796875,0.9482421875,0.9443359375,0.99609375},{5,0.841796875,0.9482421875,0.9443359375,0.99609375},{6,0.841796875,0.9482421875,0.9443359375,0.99609375},{8,0.0009765625,0.9482421875,0.103515625,0.99609375},{8,0.10546875,0.9482421875,0.2080078125,0.99609375},{8,0.2099609375,0.9482421875,0.3125,0.99609375},{3,0.8837890625,0.4736328125,0.986328125,0.521484375},{3,0.8837890625,0.5234375,0.986328125,0.5712890625},{10,0.0009765625,0.9384765625,0.103515625,0.986328125},{10,0.10546875,0.9384765625,0.2080078125,0.986328125},{10,0.2099609375,0.9384765625,0.3125,0.986328125}},["hold"]={{10,0.2099609375,0.9384765625,0.3125,0.986328125},{10,0.314453125,0.9384765625,0.4169921875,0.986328125},{10,0.4189453125,0.9384765625,0.521484375,0.986328125},{10,0.5234375,0.9384765625,0.6259765625,0.986328125},{10,0.6279296875,0.9384765625,0.73046875,0.986328125},{10,0.732421875,0.9384765625,0.8349609375,0.986328125},{10,0.8369140625,0.9384765625,0.939453125,0.986328125},{11,0.0009765625,0.9384765625,0.103515625,0.986328125},{11,0.10546875,0.9384765625,0.2080078125,0.986328125},{11,0.2099609375,0.9384765625,0.3125,0.986328125},{11,0.314453125,0.9384765625,0.4169921875,0.986328125},{11,0.4189453125,0.9384765625,0.521484375,0.986328125},{11,0.5234375,0.9384765625,0.6259765625,0.986328125},{11,0.6279296875,0.9384765625,0.73046875,0.986328125},{11,0.732421875,0.9384765625,0.8349609375,0.986328125},{11,0.8369140625,0.9384765625,0.939453125,0.986328125},{12,0.0009765625,0.9384765625,0.103515625,0.986328125},{12,0.10546875,0.9384765625,0.2080078125,0.986328125},{1,0.8837890625,0.0009765625,0.986328125,0.048828125},{1,0.8837890625,0.05078125,0.986328125,0.0986328125},{1,0.8837890625,0.1005859375,0.986328125,0.1484375},{1,0.8837890625,0.150390625,0.986328125,0.1982421875},{1,0.8837890625,0.2001953125,0.986328125,0.248046875},{1,0.8837890625,0.25,0.986328125,0.2978515625}},["ending"]={{10,0.2099609375,0.9384765625,0.3125,0.986328125},{10,0.10546875,0.9384765625,0.2080078125,0.986328125},{10,0.0009765625,0.9384765625,0.103515625,0.986328125},{3,0.8837890625,0.5234375,0.986328125,0.5712890625},{3,0.8837890625,0.4736328125,0.986328125,0.521484375},{8,0.2099609375,0.9482421875,0.3125,0.99609375},{8,0.10546875,0.9482421875,0.2080078125,0.99609375},{8,0.0009765625,0.9482421875,0.103515625,0.99609375},{6,0.841796875,0.9482421875,0.9443359375,0.99609375},{5,0.841796875,0.9482421875,0.9443359375,0.99609375},{4,0.841796875,0.9482421875,0.9443359375,0.99609375},{7,0.6455078125,0.9482421875,0.748046875,0.99609375}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{7,0.6455078125,0.9482421875,0.748046875,0.99609375},{1,0.8837890625,0.2998046875,0.986328125,0.34765625},{1,0.8837890625,0.349609375,0.986328125,0.3974609375},{1,0.8837890625,0.3994140625,0.986328125,0.447265625},{1,0.8837890625,0.44921875,0.986328125,0.4970703125},{1,0.8837890625,0.4990234375,0.986328125,0.546875},{1,0.8837890625,0.548828125,0.986328125,0.5966796875},{1,0.8837890625,0.5986328125,0.986328125,0.646484375},{1,0.8837890625,0.6484375,0.986328125,0.6962890625},{1,0.8837890625,0.6982421875,0.986328125,0.74609375},{1,0.8837890625,0.748046875,0.986328125,0.7958984375},{1,0.8837890625,0.7978515625,0.986328125,0.845703125}},["hold"]={{1,0.8837890625,0.7978515625,0.986328125,0.845703125},{1,0.8837890625,0.84765625,0.986328125,0.8955078125},{1,0.8837890625,0.8974609375,0.986328125,0.9453125},{1,0.0009765625,0.947265625,0.103515625,0.9951171875},{1,0.10546875,0.947265625,0.2080078125,0.9951171875},{1,0.2099609375,0.947265625,0.3125,0.9951171875},{1,0.314453125,0.947265625,0.4169921875,0.9951171875},{1,0.4189453125,0.947265625,0.521484375,0.9951171875},{1,0.5234375,0.947265625,0.6259765625,0.9951171875},{1,0.6279296875,0.947265625,0.73046875,0.9951171875},{1,0.732421875,0.947265625,0.8349609375,0.9951171875},{1,0.8369140625,0.947265625,0.939453125,0.9951171875},{2,0.8837890625,0.0009765625,0.986328125,0.048828125},{2,0.8837890625,0.05078125,0.986328125,0.0986328125},{2,0.8837890625,0.1005859375,0.986328125,0.1484375},{2,0.8837890625,0.150390625,0.986328125,0.1982421875},{2,0.8837890625,0.2001953125,0.986328125,0.248046875},{2,0.8837890625,0.25,0.986328125,0.2978515625},{2,0.8837890625,0.2998046875,0.986328125,0.34765625},{2,0.8837890625,0.349609375,0.986328125,0.3974609375},{2,0.8837890625,0.3994140625,0.986328125,0.447265625},{2,0.8837890625,0.44921875,0.986328125,0.4970703125},{2,0.8837890625,0.4990234375,0.986328125,0.546875},{2,0.8837890625,0.548828125,0.986328125,0.5966796875}},["ending"]={{1,0.8837890625,0.7978515625,0.986328125,0.845703125},{2,0.8837890625,0.5986328125,0.986328125,0.646484375},{2,0.8837890625,0.6484375,0.986328125,0.6962890625},{2,0.8837890625,0.6982421875,0.986328125,0.74609375},{2,0.8837890625,0.748046875,0.986328125,0.7958984375},{2,0.8837890625,0.7978515625,0.986328125,0.845703125},{2,0.8837890625,0.84765625,0.986328125,0.8955078125},{2,0.8837890625,0.8974609375,0.986328125,0.9453125},{2,0.0009765625,0.947265625,0.103515625,0.9951171875},{2,0.10546875,0.947265625,0.2080078125,0.9951171875},{2,0.2099609375,0.947265625,0.3125,0.9951171875},{7,0.6455078125,0.9482421875,0.748046875,0.99609375}},["idle"]={["intro"]={{7,0.6455078125,0.9482421875,0.748046875,0.99609375},{2,0.314453125,0.947265625,0.4169921875,0.9951171875},{2,0.4189453125,0.947265625,0.521484375,0.9951171875},{2,0.5234375,0.947265625,0.6259765625,0.9951171875},{2,0.6279296875,0.947265625,0.73046875,0.9951171875},{2,0.732421875,0.947265625,0.8349609375,0.9951171875},{2,0.8369140625,0.947265625,0.939453125,0.9951171875},{8,0.2705078125,0.603515625,0.373046875,0.6513671875},{3,0.0009765625,0.9208984375,0.103515625,0.96875},{3,0.10546875,0.9208984375,0.2080078125,0.96875},{3,0.2099609375,0.9208984375,0.3125,0.96875},{3,0.314453125,0.9208984375,0.4169921875,0.96875}},["hold"]={{3,0.314453125,0.9208984375,0.4169921875,0.96875},{3,0.4189453125,0.9208984375,0.521484375,0.96875},{3,0.5234375,0.9208984375,0.6259765625,0.96875},{12,0.466796875,0.0009765625,0.5693359375,0.048828125},{12,0.5712890625,0.0009765625,0.673828125,0.048828125},{12,0.67578125,0.0009765625,0.7783203125,0.048828125},{12,0.7802734375,0.0009765625,0.8828125,0.048828125},{12,0.884765625,0.0009765625,0.9873046875,0.048828125},{12,0.466796875,0.05078125,0.5693359375,0.0986328125},{12,0.5712890625,0.05078125,0.673828125,0.0986328125},{12,0.67578125,0.05078125,0.7783203125,0.0986328125},{12,0.7802734375,0.05078125,0.8828125,0.0986328125},{12,0.884765625,0.05078125,0.9873046875,0.0986328125},{12,0.466796875,0.1005859375,0.5693359375,0.1484375},{12,0.5712890625,0.1005859375,0.673828125,0.1484375},{12,0.67578125,0.1005859375,0.7783203125,0.1484375},{12,0.7802734375,0.1005859375,0.8828125,0.1484375},{12,0.884765625,0.1005859375,0.9873046875,0.1484375},{12,0.466796875,0.150390625,0.5693359375,0.1982421875},{12,0.2099609375,0.1572265625,0.3125,0.205078125},{12,0.314453125,0.1572265625,0.4169921875,0.205078125},{12,0.5712890625,0.150390625,0.673828125,0.1982421875},{12,0.67578125,0.150390625,0.7783203125,0.1982421875},{12,0.7802734375,0.150390625,0.8828125,0.1982421875}},["ending"]={{3,0.314453125,0.9208984375,0.4169921875,0.96875},{12,0.884765625,0.150390625,0.9873046875,0.1982421875},{12,0.4189453125,0.2001953125,0.521484375,0.248046875},{12,0.2099609375,0.20703125,0.3125,0.2548828125},{12,0.314453125,0.20703125,0.4169921875,0.2548828125},{12,0.5234375,0.2001953125,0.6259765625,0.248046875},{12,0.6279296875,0.2001953125,0.73046875,0.248046875},{12,0.732421875,0.2001953125,0.8349609375,0.248046875},{12,0.8369140625,0.2001953125,0.939453125,0.248046875},{12,0.4189453125,0.25,0.521484375,0.2978515625},{12,0.2099609375,0.2568359375,0.3125,0.3046875},{7,0.6455078125,0.9482421875,0.748046875,0.99609375}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{12,0.314453125,0.2568359375,0.4169921875,0.3056640625},{12,0.2099609375,0.306640625,0.3125,0.35546875},{12,0.5234375,0.25,0.6259765625,0.298828125},{12,0.4189453125,0.2998046875,0.521484375,0.3486328125},{12,0.314453125,0.3076171875,0.4169921875,0.3564453125},{12,0.2099609375,0.357421875,0.3125,0.40625},{12,0.6279296875,0.25,0.73046875,0.298828125},{12,0.732421875,0.25,0.8349609375,0.298828125},{12,0.8369140625,0.25,0.939453125,0.298828125},{12,0.5234375,0.30078125,0.6259765625,0.349609375},{12,0.4189453125,0.3505859375,0.521484375,0.3994140625},{12,0.314453125,0.3583984375,0.4169921875,0.4072265625}},["hold"]={{12,0.314453125,0.3583984375,0.4169921875,0.4072265625},{12,0.2099609375,0.408203125,0.3125,0.45703125},{12,0.6279296875,0.30078125,0.73046875,0.349609375},{12,0.732421875,0.30078125,0.8349609375,0.349609375},{12,0.8369140625,0.30078125,0.939453125,0.349609375},{12,0.5234375,0.3515625,0.6259765625,0.400390625},{12,0.4189453125,0.4013671875,0.521484375,0.4501953125},{12,0.314453125,0.4091796875,0.4169921875,0.4580078125},{12,0.2099609375,0.458984375,0.3125,0.5078125},{12,0.6279296875,0.3515625,0.73046875,0.400390625},{12,0.732421875,0.3515625,0.8349609375,0.400390625},{12,0.8369140625,0.3515625,0.939453125,0.400390625},{12,0.5234375,0.40234375,0.6259765625,0.451171875},{12,0.4189453125,0.4521484375,0.521484375,0.5009765625},{12,0.314453125,0.4599609375,0.4169921875,0.5087890625},{12,0.2099609375,0.509765625,0.3125,0.55859375},{12,0.6279296875,0.40234375,0.73046875,0.451171875},{12,0.732421875,0.40234375,0.8349609375,0.451171875},{12,0.8369140625,0.40234375,0.939453125,0.451171875},{12,0.15625,0.560546875,0.2587890625,0.609375},{12,0.15625,0.611328125,0.2587890625,0.66015625},{12,0.15625,0.662109375,0.2587890625,0.7109375},{12,0.15625,0.712890625,0.2587890625,0.76171875},{12,0.15625,0.763671875,0.2587890625,0.8125}},["ending"]={{12,0.314453125,0.3583984375,0.4169921875,0.4072265625},{12,0.4189453125,0.3505859375,0.521484375,0.3994140625},{12,0.5234375,0.30078125,0.6259765625,0.349609375},{12,0.8369140625,0.25,0.939453125,0.298828125},{12,0.732421875,0.25,0.8349609375,0.298828125},{12,0.6279296875,0.25,0.73046875,0.298828125},{12,0.2099609375,0.357421875,0.3125,0.40625},{12,0.314453125,0.3076171875,0.4169921875,0.3564453125},{12,0.4189453125,0.2998046875,0.521484375,0.3486328125},{12,0.5234375,0.25,0.6259765625,0.298828125},{12,0.2099609375,0.306640625,0.3125,0.35546875},{12,0.314453125,0.2568359375,0.4169921875,0.3056640625}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{12,0.314453125,0.2568359375,0.4169921875,0.3056640625},{12,0.15625,0.814453125,0.2587890625,0.86328125},{12,0.15625,0.865234375,0.2587890625,0.9140625},{12,0.2099609375,0.916015625,0.3125,0.96484375},{12,0.2607421875,0.560546875,0.36328125,0.609375},{12,0.2607421875,0.611328125,0.36328125,0.66015625},{12,0.2607421875,0.662109375,0.36328125,0.7109375},{12,0.2607421875,0.712890625,0.36328125,0.76171875},{12,0.2607421875,0.763671875,0.36328125,0.8125},{12,0.2607421875,0.814453125,0.36328125,0.86328125},{12,0.2607421875,0.865234375,0.36328125,0.9140625},{12,0.314453125,0.916015625,0.4169921875,0.96484375}},["hold"]={{12,0.314453125,0.916015625,0.4169921875,0.96484375},{12,0.365234375,0.5107421875,0.4677734375,0.5595703125},{12,0.365234375,0.5615234375,0.4677734375,0.6103515625},{12,0.365234375,0.6123046875,0.4677734375,0.6611328125},{12,0.365234375,0.6630859375,0.4677734375,0.7119140625},{12,0.365234375,0.7138671875,0.4677734375,0.7626953125},{12,0.365234375,0.7646484375,0.4677734375,0.8134765625},{12,0.365234375,0.8154296875,0.4677734375,0.8642578125},{12,0.4189453125,0.8662109375,0.521484375,0.9150390625},{12,0.4189453125,0.9169921875,0.521484375,0.9658203125},{12,0.4697265625,0.5029296875,0.572265625,0.5517578125},{12,0.4697265625,0.5537109375,0.572265625,0.6025390625},{12,0.4697265625,0.6044921875,0.572265625,0.6533203125},{12,0.4697265625,0.6552734375,0.572265625,0.7041015625},{12,0.4697265625,0.7060546875,0.572265625,0.7548828125},{12,0.4697265625,0.7568359375,0.572265625,0.8056640625},{12,0.4697265625,0.8076171875,0.572265625,0.8564453125},{12,0.5234375,0.8583984375,0.6259765625,0.9072265625},{12,0.5234375,0.9091796875,0.6259765625,0.9580078125},{12,0.6279296875,0.453125,0.73046875,0.501953125},{12,0.732421875,0.453125,0.8349609375,0.501953125},{12,0.8369140625,0.453125,0.939453125,0.501953125},{12,0.6279296875,0.50390625,0.73046875,0.552734375},{12,0.732421875,0.50390625,0.8349609375,0.552734375}},["ending"]={{12,0.314453125,0.916015625,0.4169921875,0.96484375},{12,0.8369140625,0.50390625,0.939453125,0.552734375},{12,0.57421875,0.5546875,0.6767578125,0.603515625},{12,0.57421875,0.60546875,0.6767578125,0.654296875},{12,0.57421875,0.65625,0.6767578125,0.705078125},{12,0.57421875,0.70703125,0.6767578125,0.755859375},{12,0.57421875,0.7578125,0.6767578125,0.806640625},{12,0.6279296875,0.80859375,0.73046875,0.857421875},{12,0.6279296875,0.859375,0.73046875,0.908203125},{12,0.6279296875,0.91015625,0.73046875,0.958984375},{12,0.732421875,0.5546875,0.8349609375,0.603515625},{12,0.314453125,0.2568359375,0.4169921875,0.3056640625}},["idle"]={["intro"]={{12,0.314453125,0.2568359375,0.4169921875,0.3056640625},{12,0.8369140625,0.5546875,0.939453125,0.603515625},{12,0.6787109375,0.60546875,0.78125,0.654296875},{12,0.6787109375,0.65625,0.78125,0.705078125},{12,0.6787109375,0.70703125,0.78125,0.755859375},{12,0.6787109375,0.7578125,0.78125,0.806640625},{12,0.783203125,0.60546875,0.8857421875,0.654296875},{12,0.8876953125,0.60546875,0.990234375,0.654296875},{12,0.783203125,0.65625,0.8857421875,0.705078125},{12,0.8876953125,0.65625,0.990234375,0.705078125},{12,0.783203125,0.70703125,0.8857421875,0.755859375},{12,0.8876953125,0.70703125,0.990234375,0.755859375}},["hold"]={{12,0.8876953125,0.70703125,0.990234375,0.755859375},{12,0.783203125,0.7578125,0.8857421875,0.806640625},{12,0.8876953125,0.7578125,0.990234375,0.806640625},{12,0.732421875,0.80859375,0.8349609375,0.857421875},{12,0.8369140625,0.80859375,0.939453125,0.857421875},{12,0.732421875,0.859375,0.8349609375,0.908203125},{12,0.732421875,0.91015625,0.8349609375,0.958984375},{12,0.8369140625,0.859375,0.939453125,0.908203125},{12,0.8369140625,0.91015625,0.939453125,0.958984375},{13,0.0009765625,0.0009765625,0.103515625,0.0498046875},{13,0.10546875,0.0009765625,0.2080078125,0.0498046875},{13,0.2099609375,0.0009765625,0.3125,0.0498046875},{13,0.314453125,0.0009765625,0.4169921875,0.0498046875},{13,0.4189453125,0.0009765625,0.521484375,0.0498046875},{13,0.5234375,0.0009765625,0.6259765625,0.0498046875},{13,0.6279296875,0.0009765625,0.73046875,0.0498046875},{13,0.732421875,0.0009765625,0.8349609375,0.0498046875},{13,0.8369140625,0.0009765625,0.939453125,0.0498046875},{13,0.0009765625,0.0517578125,0.103515625,0.1005859375},{13,0.10546875,0.0517578125,0.2080078125,0.1005859375},{13,0.2099609375,0.0517578125,0.3125,0.1005859375},{13,0.314453125,0.0517578125,0.4169921875,0.1005859375},{13,0.4189453125,0.0517578125,0.521484375,0.1005859375},{13,0.5234375,0.0517578125,0.6259765625,0.1005859375}},["ending"]={{12,0.8876953125,0.70703125,0.990234375,0.755859375},{13,0.6279296875,0.0517578125,0.73046875,0.1005859375},{13,0.732421875,0.0517578125,0.8349609375,0.1005859375},{13,0.8369140625,0.0517578125,0.939453125,0.1005859375},{13,0.0009765625,0.1025390625,0.103515625,0.1513671875},{13,0.10546875,0.1025390625,0.2080078125,0.1513671875},{13,0.2099609375,0.1025390625,0.3125,0.1513671875},{13,0.314453125,0.1025390625,0.4169921875,0.1513671875},{13,0.4189453125,0.1025390625,0.521484375,0.1513671875},{13,0.5234375,0.1025390625,0.6259765625,0.1513671875},{13,0.6279296875,0.1025390625,0.73046875,0.1513671875},{12,0.314453125,0.2568359375,0.4169921875,0.3056640625}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{3,0.6630859375,0.9130859375,0.78125,0.9990234375},{3,0.783203125,0.9130859375,0.9013671875,0.9990234375},{8,0.2705078125,0.8564453125,0.388671875,0.9423828125},{8,0.2705078125,0.515625,0.388671875,0.6015625},{7,0.0009765625,0.8974609375,0.119140625,0.9833984375},{7,0.12109375,0.8974609375,0.2392578125,0.9833984375},{7,0.2412109375,0.8974609375,0.359375,0.9833984375},{7,0.361328125,0.8974609375,0.4794921875,0.9833984375},{4,0.0009765625,0.8974609375,0.119140625,0.9833984375},{4,0.12109375,0.8974609375,0.2392578125,0.9833984375},{4,0.2412109375,0.8974609375,0.359375,0.9833984375},{4,0.361328125,0.8974609375,0.4794921875,0.9833984375}},["hold"]={{4,0.361328125,0.8974609375,0.4794921875,0.9833984375},{4,0.4814453125,0.8974609375,0.599609375,0.9833984375},{4,0.6015625,0.8974609375,0.7197265625,0.9833984375},{4,0.7216796875,0.8974609375,0.83984375,0.9833984375},{5,0.0009765625,0.8974609375,0.119140625,0.9833984375},{5,0.12109375,0.8974609375,0.2392578125,0.9833984375},{5,0.2412109375,0.8974609375,0.359375,0.9833984375},{5,0.361328125,0.8974609375,0.4794921875,0.9833984375},{5,0.4814453125,0.8974609375,0.599609375,0.9833984375},{5,0.6015625,0.8974609375,0.7197265625,0.9833984375},{5,0.7216796875,0.8974609375,0.83984375,0.9833984375},{6,0.0009765625,0.8974609375,0.119140625,0.9833984375},{6,0.12109375,0.8974609375,0.2392578125,0.9833984375},{6,0.2412109375,0.8974609375,0.359375,0.9833984375},{6,0.361328125,0.8974609375,0.4794921875,0.9833984375},{6,0.4814453125,0.8974609375,0.599609375,0.9833984375},{6,0.6015625,0.8974609375,0.7197265625,0.9833984375},{6,0.7216796875,0.8974609375,0.83984375,0.9833984375},{4,0.841796875,0.8603515625,0.9599609375,0.9462890625},{5,0.841796875,0.8603515625,0.9599609375,0.9462890625},{6,0.841796875,0.8603515625,0.9599609375,0.9462890625},{8,0.0009765625,0.8603515625,0.119140625,0.9462890625},{8,0.12109375,0.8603515625,0.2392578125,0.9462890625},{7,0.6455078125,0.8603515625,0.763671875,0.9462890625}},["ending"]={{4,0.361328125,0.8974609375,0.4794921875,0.9833984375},{4,0.2412109375,0.8974609375,0.359375,0.9833984375},{4,0.12109375,0.8974609375,0.2392578125,0.9833984375},{4,0.0009765625,0.8974609375,0.119140625,0.9833984375},{7,0.361328125,0.8974609375,0.4794921875,0.9833984375},{7,0.2412109375,0.8974609375,0.359375,0.9833984375},{7,0.12109375,0.8974609375,0.2392578125,0.9833984375},{7,0.0009765625,0.8974609375,0.119140625,0.9833984375},{8,0.2705078125,0.515625,0.388671875,0.6015625},{8,0.2705078125,0.8564453125,0.388671875,0.9423828125},{3,0.783203125,0.9130859375,0.9013671875,0.9990234375},{3,0.6630859375,0.9130859375,0.78125,0.9990234375}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.2197265625,0.3056640625},{1,0.0009765625,0.3076171875,0.2197265625,0.6123046875},{1,0.0009765625,0.6142578125,0.2197265625,0.9189453125},{1,0.2216796875,0.0009765625,0.4404296875,0.3056640625},{1,0.4423828125,0.0009765625,0.6611328125,0.3056640625},{1,0.6630859375,0.0009765625,0.8818359375,0.3056640625},{1,0.2216796875,0.3076171875,0.4404296875,0.6123046875},{1,0.2216796875,0.6142578125,0.4404296875,0.9189453125},{1,0.4423828125,0.3076171875,0.6611328125,0.6123046875},{1,0.4423828125,0.6142578125,0.6611328125,0.9189453125},{1,0.6630859375,0.3076171875,0.8818359375,0.6123046875},{1,0.6630859375,0.6142578125,0.8818359375,0.9189453125}},["hold"]={{1,0.6630859375,0.6142578125,0.8818359375,0.9189453125},{2,0.0009765625,0.0009765625,0.2197265625,0.3056640625},{2,0.0009765625,0.3076171875,0.2197265625,0.6123046875},{2,0.0009765625,0.6142578125,0.2197265625,0.9189453125},{2,0.2216796875,0.0009765625,0.4404296875,0.3056640625},{2,0.4423828125,0.0009765625,0.6611328125,0.3056640625},{2,0.6630859375,0.0009765625,0.8818359375,0.3056640625},{2,0.2216796875,0.3076171875,0.4404296875,0.6123046875},{2,0.2216796875,0.6142578125,0.4404296875,0.9189453125},{2,0.4423828125,0.3076171875,0.6611328125,0.6123046875},{2,0.4423828125,0.6142578125,0.6611328125,0.9189453125},{2,0.6630859375,0.3076171875,0.8818359375,0.6123046875},{2,0.6630859375,0.6142578125,0.8818359375,0.9189453125},{3,0.0009765625,0.0009765625,0.2197265625,0.3056640625},{3,0.0009765625,0.3076171875,0.2197265625,0.6123046875},{3,0.0009765625,0.6142578125,0.2197265625,0.9189453125},{3,0.2216796875,0.0009765625,0.4404296875,0.3056640625},{3,0.4423828125,0.0009765625,0.6611328125,0.3056640625},{3,0.6630859375,0.0009765625,0.8818359375,0.3056640625},{3,0.2216796875,0.3076171875,0.4404296875,0.6123046875},{3,0.2216796875,0.6142578125,0.4404296875,0.9189453125},{3,0.4423828125,0.3076171875,0.6611328125,0.6123046875},{3,0.4423828125,0.6142578125,0.6611328125,0.9189453125},{3,0.6630859375,0.3076171875,0.8818359375,0.6123046875}},["ending"]={{1,0.6630859375,0.6142578125,0.8818359375,0.9189453125},{1,0.6630859375,0.3076171875,0.8818359375,0.6123046875},{1,0.4423828125,0.6142578125,0.6611328125,0.9189453125},{1,0.4423828125,0.3076171875,0.6611328125,0.6123046875},{1,0.2216796875,0.6142578125,0.4404296875,0.9189453125},{1,0.2216796875,0.3076171875,0.4404296875,0.6123046875},{1,0.6630859375,0.0009765625,0.8818359375,0.3056640625},{1,0.4423828125,0.0009765625,0.6611328125,0.3056640625},{1,0.2216796875,0.0009765625,0.4404296875,0.3056640625},{1,0.0009765625,0.6142578125,0.2197265625,0.9189453125},{1,0.0009765625,0.3076171875,0.2197265625,0.6123046875},{1,0.0009765625,0.0009765625,0.2197265625,0.3056640625}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{8,0.6748046875,0.1728515625,0.802734375,0.341796875},{8,0.8046875,0.1728515625,0.9326171875,0.341796875},{8,0.6748046875,0.34375,0.802734375,0.5126953125},{8,0.8046875,0.34375,0.9326171875,0.5126953125},{8,0.2705078125,0.3447265625,0.3984375,0.513671875},{8,0.400390625,0.3447265625,0.5283203125,0.513671875},{8,0.5302734375,0.3447265625,0.658203125,0.513671875},{8,0.66015625,0.5146484375,0.7880859375,0.68359375},{8,0.7900390625,0.5146484375,0.91796875,0.68359375},{8,0.2705078125,0.685546875,0.3984375,0.8544921875},{8,0.400390625,0.515625,0.5283203125,0.6845703125},{8,0.5302734375,0.515625,0.658203125,0.6845703125}},["hold"]={{8,0.5302734375,0.515625,0.658203125,0.6845703125},{8,0.400390625,0.6865234375,0.5283203125,0.85546875},{8,0.5302734375,0.6865234375,0.658203125,0.85546875},{8,0.66015625,0.685546875,0.7880859375,0.8544921875},{8,0.7900390625,0.685546875,0.91796875,0.8544921875},{9,0.0009765625,0.0009765625,0.12890625,0.169921875},{9,0.0009765625,0.171875,0.12890625,0.3408203125},{9,0.0009765625,0.3427734375,0.12890625,0.51171875},{9,0.0009765625,0.513671875,0.12890625,0.6826171875},{9,0.0009765625,0.6845703125,0.12890625,0.853515625},{9,0.130859375,0.0009765625,0.2587890625,0.169921875},{9,0.2607421875,0.0009765625,0.388671875,0.169921875},{9,0.390625,0.0009765625,0.5185546875,0.169921875},{9,0.5205078125,0.0009765625,0.6484375,0.169921875},{9,0.650390625,0.0009765625,0.7783203125,0.169921875},{9,0.7802734375,0.0009765625,0.908203125,0.169921875},{9,0.130859375,0.171875,0.2587890625,0.3408203125},{9,0.130859375,0.3427734375,0.2587890625,0.51171875},{9,0.130859375,0.513671875,0.2587890625,0.6826171875},{9,0.130859375,0.6845703125,0.2587890625,0.853515625},{9,0.2607421875,0.171875,0.388671875,0.3408203125},{9,0.390625,0.171875,0.5185546875,0.3408203125},{9,0.5205078125,0.171875,0.6484375,0.3408203125},{9,0.650390625,0.171875,0.7783203125,0.3408203125}},["ending"]={{8,0.5302734375,0.515625,0.658203125,0.6845703125},{9,0.7802734375,0.171875,0.908203125,0.3408203125},{9,0.2607421875,0.3427734375,0.388671875,0.51171875},{9,0.2607421875,0.513671875,0.388671875,0.6826171875},{9,0.2607421875,0.6845703125,0.388671875,0.853515625},{9,0.390625,0.3427734375,0.5185546875,0.51171875},{9,0.390625,0.513671875,0.5185546875,0.6826171875},{9,0.390625,0.6845703125,0.5185546875,0.853515625},{9,0.5205078125,0.3427734375,0.6484375,0.51171875},{9,0.650390625,0.3427734375,0.7783203125,0.51171875},{9,0.7802734375,0.3427734375,0.908203125,0.51171875},{8,0.6748046875,0.1728515625,0.802734375,0.341796875}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{4,0.765625,0.0009765625,0.8984375,0.1708984375},{4,0.765625,0.1728515625,0.8984375,0.3427734375},{4,0.765625,0.3447265625,0.8984375,0.5146484375},{4,0.765625,0.5166015625,0.8984375,0.6865234375},{4,0.765625,0.6884765625,0.8984375,0.8583984375},{5,0.765625,0.0009765625,0.8984375,0.1708984375},{5,0.765625,0.1728515625,0.8984375,0.3427734375},{5,0.765625,0.3447265625,0.8984375,0.5146484375},{5,0.765625,0.5166015625,0.8984375,0.6865234375},{5,0.765625,0.6884765625,0.8984375,0.8583984375},{6,0.765625,0.0009765625,0.8984375,0.1708984375},{6,0.765625,0.1728515625,0.8984375,0.3427734375}},["hold"]={{6,0.765625,0.1728515625,0.8984375,0.3427734375},{6,0.765625,0.3447265625,0.8984375,0.5146484375},{6,0.765625,0.5166015625,0.8984375,0.6865234375},{6,0.765625,0.6884765625,0.8984375,0.8583984375},{7,0.765625,0.0009765625,0.8984375,0.1708984375},{7,0.765625,0.1728515625,0.8984375,0.3427734375},{7,0.5107421875,0.2998046875,0.6435546875,0.4697265625},{7,0.6455078125,0.3447265625,0.7783203125,0.5146484375},{7,0.5107421875,0.4716796875,0.6435546875,0.6416015625},{7,0.7802734375,0.3447265625,0.9130859375,0.5146484375},{7,0.5107421875,0.6435546875,0.6435546875,0.8134765625},{7,0.5107421875,0.8154296875,0.6435546875,0.9853515625},{7,0.6455078125,0.5166015625,0.7783203125,0.6865234375},{7,0.7802734375,0.5166015625,0.9130859375,0.6865234375},{7,0.6455078125,0.6884765625,0.7783203125,0.8583984375},{7,0.7802734375,0.6884765625,0.9130859375,0.8583984375},{8,0.0009765625,0.0009765625,0.1337890625,0.1708984375},{8,0.0009765625,0.1728515625,0.1337890625,0.3427734375},{8,0.0009765625,0.3447265625,0.1337890625,0.5146484375},{8,0.0009765625,0.5166015625,0.1337890625,0.6865234375},{8,0.0009765625,0.6884765625,0.1337890625,0.8583984375},{8,0.1357421875,0.0009765625,0.2685546875,0.1708984375},{8,0.2705078125,0.0009765625,0.4033203125,0.1708984375},{8,0.4052734375,0.0009765625,0.5380859375,0.1708984375}},["ending"]={{6,0.765625,0.1728515625,0.8984375,0.3427734375},{8,0.5400390625,0.0009765625,0.6728515625,0.1708984375},{8,0.6748046875,0.0009765625,0.8076171875,0.1708984375},{8,0.8095703125,0.0009765625,0.9423828125,0.1708984375},{8,0.1357421875,0.1728515625,0.2685546875,0.3427734375},{8,0.1357421875,0.3447265625,0.2685546875,0.5146484375},{8,0.1357421875,0.5166015625,0.2685546875,0.6865234375},{8,0.1357421875,0.6884765625,0.2685546875,0.8583984375},{8,0.2705078125,0.1728515625,0.4033203125,0.3427734375},{8,0.4052734375,0.1728515625,0.5380859375,0.3427734375},{8,0.5400390625,0.1728515625,0.6728515625,0.3427734375},{4,0.765625,0.0009765625,0.8984375,0.1708984375}},["pages"]={"StudioDruidRestorationChannelPlusSize384Page1.tga","StudioDruidRestorationChannelPlusSize384Page2.tga","StudioDruidRestorationChannelPlusSize384Page3.tga","StudioDruidRestorationChannelPlusSize384Page4.tga","StudioDruidRestorationChannelPlusSize384Page5.tga","StudioDruidRestorationChannelPlusSize384Page6.tga","StudioDruidRestorationChannelPlusSize384Page7.tga","StudioDruidRestorationChannelPlusSize384Page8.tga","StudioDruidRestorationChannelPlusSize384Page9.tga","StudioDruidRestorationChannelPlusSize384Page10.tga","StudioDruidRestorationChannelPlusSize384Page11.tga","StudioDruidRestorationChannelPlusSize384Page12.tga","StudioDruidRestorationChannelPlusSize384Page13.tga"}}},[480]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{6,0.5517578125,0.3837890625,0.8681640625,0.7548828125},{7,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{7,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{7,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{7,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{7,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{7,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{8,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{8,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{8,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{8,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{8,0.3193359375,0.3740234375,0.6357421875,0.7451171875}},["hold"]={{8,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{8,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{9,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{9,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{9,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{9,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{9,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{9,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{10,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{10,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{10,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{10,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{10,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{10,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{11,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{11,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{11,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{11,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{11,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{11,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{12,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{12,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{12,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{12,0.6376953125,0.0009765625,0.9541015625,0.3720703125}},["ending"]={{8,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{8,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{8,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{8,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{8,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{7,0.6376953125,0.3740234375,0.9541015625,0.7451171875},{7,0.3193359375,0.3740234375,0.6357421875,0.7451171875},{7,0.6376953125,0.0009765625,0.9541015625,0.3720703125},{7,0.3193359375,0.0009765625,0.6357421875,0.3720703125},{7,0.0009765625,0.3740234375,0.3173828125,0.7451171875},{7,0.0009765625,0.0009765625,0.3173828125,0.3720703125},{6,0.5517578125,0.3837890625,0.8681640625,0.7548828125}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{6,0.8701171875,0.3251953125,0.9755859375,0.470703125},{6,0.8701171875,0.47265625,0.9755859375,0.6181640625},{16,0.6865234375,0.7470703125,0.7919921875,0.892578125},{16,0.7939453125,0.7470703125,0.8994140625,0.892578125},{17,0.0009765625,0.0009765625,0.1064453125,0.146484375},{17,0.0009765625,0.1484375,0.1064453125,0.2939453125},{17,0.0009765625,0.2958984375,0.1064453125,0.44140625},{17,0.0009765625,0.443359375,0.1064453125,0.5888671875},{17,0.0009765625,0.5908203125,0.1064453125,0.736328125},{17,0.0009765625,0.73828125,0.1064453125,0.8837890625},{17,0.1083984375,0.0009765625,0.2138671875,0.146484375},{17,0.2158203125,0.0009765625,0.3212890625,0.146484375}},["hold"]={{17,0.2158203125,0.0009765625,0.3212890625,0.146484375},{17,0.3232421875,0.0009765625,0.4287109375,0.146484375},{17,0.4306640625,0.0009765625,0.5361328125,0.146484375},{17,0.5380859375,0.0009765625,0.6435546875,0.146484375},{17,0.6455078125,0.0009765625,0.7509765625,0.146484375},{17,0.7529296875,0.0009765625,0.8583984375,0.146484375},{17,0.8603515625,0.0009765625,0.9658203125,0.146484375},{17,0.1083984375,0.1484375,0.2138671875,0.2939453125},{17,0.1083984375,0.2958984375,0.2138671875,0.44140625},{17,0.1083984375,0.443359375,0.2138671875,0.5888671875},{17,0.1083984375,0.5908203125,0.2138671875,0.736328125},{17,0.1083984375,0.73828125,0.2138671875,0.8837890625},{17,0.2158203125,0.1484375,0.3212890625,0.2939453125},{17,0.2158203125,0.2958984375,0.3212890625,0.44140625},{17,0.2158203125,0.443359375,0.3212890625,0.5888671875},{17,0.2158203125,0.5908203125,0.3212890625,0.736328125},{17,0.2158203125,0.73828125,0.3212890625,0.8837890625},{17,0.3232421875,0.1484375,0.4287109375,0.2939453125},{17,0.4306640625,0.1484375,0.5361328125,0.2939453125},{17,0.5380859375,0.1484375,0.6435546875,0.2939453125},{17,0.6455078125,0.1484375,0.7509765625,0.2939453125},{17,0.7529296875,0.1484375,0.8583984375,0.2939453125},{17,0.8603515625,0.1484375,0.9658203125,0.2939453125},{17,0.3232421875,0.2958984375,0.4287109375,0.44140625}},["ending"]={{17,0.2158203125,0.0009765625,0.3212890625,0.146484375},{17,0.3232421875,0.443359375,0.4287109375,0.5888671875},{17,0.3232421875,0.5908203125,0.4287109375,0.736328125},{17,0.3232421875,0.73828125,0.4287109375,0.8837890625},{17,0.4306640625,0.2958984375,0.5361328125,0.44140625},{17,0.5380859375,0.2958984375,0.6435546875,0.44140625},{17,0.6455078125,0.2958984375,0.7509765625,0.44140625},{17,0.7529296875,0.2958984375,0.8583984375,0.44140625},{17,0.8603515625,0.2958984375,0.9658203125,0.44140625},{17,0.4306640625,0.443359375,0.5361328125,0.5888671875},{17,0.4306640625,0.5908203125,0.5361328125,0.736328125},{6,0.8701171875,0.3251953125,0.9755859375,0.470703125}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{12,0.3251953125,0.7998046875,0.5166015625,0.9921875},{12,0.5185546875,0.7998046875,0.7099609375,0.9921875},{12,0.7119140625,0.7998046875,0.9033203125,0.9921875},{13,0.0009765625,0.6396484375,0.1923828125,0.83203125},{13,0.1630859375,0.0009765625,0.3544921875,0.193359375},{13,0.1630859375,0.1953125,0.3544921875,0.3876953125},{13,0.1630859375,0.3896484375,0.3544921875,0.58203125},{13,0.1943359375,0.583984375,0.3857421875,0.7763671875},{13,0.1943359375,0.7783203125,0.3857421875,0.970703125},{13,0.3564453125,0.0009765625,0.5478515625,0.193359375},{13,0.3564453125,0.1953125,0.5478515625,0.3876953125},{13,0.3564453125,0.3896484375,0.5478515625,0.58203125}},["hold"]={{13,0.3564453125,0.3896484375,0.5478515625,0.58203125},{13,0.3876953125,0.583984375,0.5791015625,0.7763671875},{13,0.3876953125,0.7783203125,0.5791015625,0.970703125},{13,0.5810546875,0.0009765625,0.7724609375,0.193359375},{13,0.7744140625,0.0009765625,0.9658203125,0.193359375},{13,0.5498046875,0.1953125,0.7412109375,0.3876953125},{13,0.5498046875,0.3896484375,0.7412109375,0.58203125},{13,0.7431640625,0.1953125,0.9345703125,0.3876953125},{13,0.7431640625,0.3896484375,0.9345703125,0.58203125},{13,0.5810546875,0.583984375,0.7724609375,0.7763671875},{13,0.5810546875,0.7783203125,0.7724609375,0.970703125},{13,0.7744140625,0.583984375,0.9658203125,0.7763671875},{13,0.7744140625,0.7783203125,0.9658203125,0.970703125},{14,0.0009765625,0.0009765625,0.1923828125,0.193359375},{14,0.0009765625,0.1953125,0.1923828125,0.3876953125},{14,0.0009765625,0.3896484375,0.1923828125,0.58203125},{14,0.0009765625,0.583984375,0.1923828125,0.7763671875},{14,0.0009765625,0.7783203125,0.1923828125,0.970703125},{14,0.1943359375,0.0009765625,0.3857421875,0.193359375},{14,0.3876953125,0.0009765625,0.5791015625,0.193359375},{14,0.5810546875,0.0009765625,0.7724609375,0.193359375},{14,0.7744140625,0.0009765625,0.9658203125,0.193359375},{14,0.1943359375,0.1953125,0.3857421875,0.3876953125},{14,0.1943359375,0.3896484375,0.3857421875,0.58203125}},["ending"]={{13,0.3564453125,0.3896484375,0.5478515625,0.58203125},{14,0.1943359375,0.583984375,0.3857421875,0.7763671875},{14,0.1943359375,0.7783203125,0.3857421875,0.970703125},{14,0.3876953125,0.1953125,0.5791015625,0.3876953125},{14,0.5810546875,0.1953125,0.7724609375,0.3876953125},{14,0.7744140625,0.1953125,0.9658203125,0.3876953125},{14,0.3876953125,0.3896484375,0.5791015625,0.58203125},{14,0.3876953125,0.583984375,0.5791015625,0.7763671875},{14,0.3876953125,0.7783203125,0.5791015625,0.970703125},{14,0.5810546875,0.3896484375,0.7724609375,0.58203125},{14,0.7744140625,0.3896484375,0.9658203125,0.58203125},{12,0.3251953125,0.7998046875,0.5166015625,0.9921875}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"},["matched"]={["layer"]="treant",["intro"]={{12,0.3251953125,0.7998046875,0.5166015625,0.9921875},{14,0.5810546875,0.583984375,0.7724609375,0.7763671875},{14,0.5810546875,0.7783203125,0.7724609375,0.970703125},{14,0.7744140625,0.583984375,0.9658203125,0.7763671875},{14,0.7744140625,0.7783203125,0.9658203125,0.970703125},{15,0.0009765625,0.0009765625,0.1923828125,0.193359375},{15,0.0009765625,0.1953125,0.1923828125,0.3876953125},{15,0.0009765625,0.3896484375,0.1923828125,0.58203125},{15,0.0009765625,0.583984375,0.1923828125,0.7763671875},{15,0.0009765625,0.7783203125,0.1923828125,0.970703125},{15,0.1943359375,0.0009765625,0.3857421875,0.193359375},{15,0.3876953125,0.0009765625,0.5791015625,0.193359375}},["hold"]={{15,0.3876953125,0.0009765625,0.5791015625,0.193359375},{15,0.5810546875,0.0009765625,0.7724609375,0.193359375},{15,0.7744140625,0.0009765625,0.9658203125,0.193359375},{15,0.1943359375,0.1953125,0.3857421875,0.3876953125},{15,0.1943359375,0.3896484375,0.3857421875,0.58203125},{15,0.1943359375,0.583984375,0.3857421875,0.7763671875},{15,0.1943359375,0.7783203125,0.3857421875,0.970703125},{15,0.3876953125,0.1953125,0.5791015625,0.3876953125},{15,0.5810546875,0.1953125,0.7724609375,0.3876953125},{15,0.7744140625,0.1953125,0.9658203125,0.3876953125},{15,0.3876953125,0.3896484375,0.5791015625,0.58203125},{15,0.3876953125,0.583984375,0.5791015625,0.7763671875},{15,0.3876953125,0.7783203125,0.5791015625,0.970703125},{15,0.5810546875,0.3896484375,0.7724609375,0.58203125},{15,0.7744140625,0.3896484375,0.9658203125,0.58203125},{15,0.5810546875,0.583984375,0.7724609375,0.7763671875},{15,0.5810546875,0.7783203125,0.7724609375,0.970703125},{15,0.7744140625,0.583984375,0.9658203125,0.7763671875},{15,0.7744140625,0.7783203125,0.9658203125,0.970703125},{16,0.0009765625,0.0009765625,0.1923828125,0.193359375},{16,0.0009765625,0.1953125,0.1923828125,0.3876953125},{16,0.0009765625,0.3896484375,0.1923828125,0.58203125},{16,0.0009765625,0.583984375,0.1923828125,0.7763671875},{16,0.0009765625,0.7783203125,0.1923828125,0.970703125}},["ending"]={{15,0.3876953125,0.0009765625,0.5791015625,0.193359375},{16,0.1943359375,0.0009765625,0.3857421875,0.193359375},{16,0.3876953125,0.0009765625,0.5791015625,0.193359375},{16,0.5810546875,0.0009765625,0.7724609375,0.193359375},{16,0.7744140625,0.0009765625,0.9658203125,0.193359375},{16,0.1943359375,0.1953125,0.3857421875,0.3876953125},{16,0.1943359375,0.3896484375,0.3857421875,0.58203125},{16,0.1943359375,0.583984375,0.3857421875,0.7763671875},{16,0.1943359375,0.7783203125,0.3857421875,0.970703125},{16,0.3876953125,0.1953125,0.5791015625,0.3876953125},{16,0.5810546875,0.1953125,0.7724609375,0.3876953125},{12,0.3251953125,0.7998046875,0.5166015625,0.9921875}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625},{6,0.8701171875,0.6826171875,0.9990234375,0.7431640625},{16,0.6865234375,0.89453125,0.8154296875,0.955078125},{16,0.8173828125,0.89453125,0.9462890625,0.955078125},{17,0.0009765625,0.8857421875,0.1298828125,0.9462890625},{17,0.1318359375,0.8857421875,0.2607421875,0.9462890625},{17,0.2626953125,0.8857421875,0.3916015625,0.9462890625},{17,0.3935546875,0.8857421875,0.5224609375,0.9462890625},{17,0.4306640625,0.73828125,0.5595703125,0.798828125},{17,0.4306640625,0.80078125,0.5595703125,0.861328125},{17,0.5244140625,0.86328125,0.6533203125,0.923828125},{17,0.5244140625,0.92578125,0.6533203125,0.986328125}},["hold"]={{17,0.5244140625,0.92578125,0.6533203125,0.986328125},{17,0.6552734375,0.443359375,0.7841796875,0.50390625},{17,0.7861328125,0.443359375,0.9150390625,0.50390625},{17,0.5380859375,0.505859375,0.6669921875,0.56640625},{17,0.5380859375,0.568359375,0.6669921875,0.62890625},{17,0.5380859375,0.630859375,0.6669921875,0.69140625},{17,0.5615234375,0.693359375,0.6904296875,0.75390625},{17,0.5615234375,0.755859375,0.6904296875,0.81640625},{17,0.6552734375,0.818359375,0.7841796875,0.87890625},{17,0.6552734375,0.880859375,0.7841796875,0.94140625},{17,0.7861328125,0.505859375,0.9150390625,0.56640625},{17,0.6689453125,0.568359375,0.7978515625,0.62890625},{17,0.6689453125,0.630859375,0.7978515625,0.69140625},{17,0.6923828125,0.693359375,0.8212890625,0.75390625},{17,0.6923828125,0.755859375,0.8212890625,0.81640625},{17,0.8232421875,0.568359375,0.9521484375,0.62890625},{17,0.7998046875,0.630859375,0.9287109375,0.69140625},{17,0.8232421875,0.693359375,0.9521484375,0.75390625},{17,0.8232421875,0.755859375,0.9521484375,0.81640625},{17,0.7861328125,0.818359375,0.9150390625,0.87890625},{17,0.7861328125,0.880859375,0.9150390625,0.94140625},{18,0.0009765625,0.0009765625,0.1298828125,0.0615234375},{18,0.1318359375,0.0009765625,0.2607421875,0.0615234375},{18,0.2626953125,0.0009765625,0.3916015625,0.0615234375}},["ending"]={{17,0.5244140625,0.92578125,0.6533203125,0.986328125},{17,0.5244140625,0.86328125,0.6533203125,0.923828125},{17,0.4306640625,0.80078125,0.5595703125,0.861328125},{17,0.4306640625,0.73828125,0.5595703125,0.798828125},{17,0.3935546875,0.8857421875,0.5224609375,0.9462890625},{17,0.2626953125,0.8857421875,0.3916015625,0.9462890625},{17,0.1318359375,0.8857421875,0.2607421875,0.9462890625},{17,0.0009765625,0.8857421875,0.1298828125,0.9462890625},{16,0.8173828125,0.89453125,0.9462890625,0.955078125},{16,0.6865234375,0.89453125,0.8154296875,0.955078125},{6,0.8701171875,0.6826171875,0.9990234375,0.7431640625},{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625},{18,0.3935546875,0.0009765625,0.5224609375,0.0615234375},{18,0.5244140625,0.0009765625,0.6533203125,0.0615234375},{18,0.6552734375,0.0009765625,0.7841796875,0.0615234375},{18,0.7861328125,0.0009765625,0.9150390625,0.0615234375},{18,0.0009765625,0.0634765625,0.1298828125,0.1240234375},{18,0.1318359375,0.0634765625,0.2607421875,0.1240234375},{18,0.2626953125,0.0634765625,0.3916015625,0.1240234375},{18,0.3935546875,0.0634765625,0.5224609375,0.1240234375},{18,0.5244140625,0.0634765625,0.6533203125,0.1240234375},{18,0.6552734375,0.0634765625,0.7841796875,0.1240234375},{18,0.7861328125,0.0634765625,0.9150390625,0.1240234375}},["hold"]={{18,0.7861328125,0.0634765625,0.9150390625,0.1240234375},{18,0.0009765625,0.1259765625,0.1298828125,0.1865234375},{18,0.1318359375,0.1259765625,0.2607421875,0.1865234375},{18,0.2626953125,0.1259765625,0.3916015625,0.1865234375},{18,0.3935546875,0.1259765625,0.5224609375,0.1865234375},{18,0.5244140625,0.1259765625,0.6533203125,0.1865234375},{18,0.6552734375,0.1259765625,0.7841796875,0.1865234375},{18,0.7861328125,0.1259765625,0.9150390625,0.1865234375},{18,0.0009765625,0.1884765625,0.1298828125,0.2490234375},{18,0.0009765625,0.2509765625,0.1298828125,0.3115234375},{18,0.0009765625,0.3134765625,0.1298828125,0.3740234375},{18,0.0009765625,0.3759765625,0.1298828125,0.4365234375},{18,0.0009765625,0.4384765625,0.1298828125,0.4990234375},{18,0.0009765625,0.5009765625,0.1298828125,0.5615234375},{18,0.0009765625,0.5634765625,0.1298828125,0.6240234375},{18,0.0009765625,0.6259765625,0.1298828125,0.6865234375},{18,0.0009765625,0.6884765625,0.1298828125,0.7490234375},{18,0.0009765625,0.7509765625,0.1298828125,0.8115234375},{18,0.0009765625,0.8134765625,0.1298828125,0.8740234375},{18,0.0009765625,0.8759765625,0.1298828125,0.9365234375},{18,0.0009765625,0.9384765625,0.1298828125,0.9990234375},{18,0.1318359375,0.1884765625,0.2607421875,0.2490234375},{18,0.2626953125,0.1884765625,0.3916015625,0.2490234375},{18,0.3935546875,0.1884765625,0.5224609375,0.2490234375}},["ending"]={{18,0.7861328125,0.0634765625,0.9150390625,0.1240234375},{18,0.5244140625,0.1884765625,0.6533203125,0.2490234375},{18,0.6552734375,0.1884765625,0.7841796875,0.2490234375},{18,0.7861328125,0.1884765625,0.9150390625,0.2490234375},{18,0.1318359375,0.2509765625,0.2607421875,0.3115234375},{18,0.2626953125,0.2509765625,0.3916015625,0.3115234375},{18,0.3935546875,0.2509765625,0.5224609375,0.3115234375},{18,0.5244140625,0.2509765625,0.6533203125,0.3115234375},{18,0.6552734375,0.2509765625,0.7841796875,0.3115234375},{18,0.7861328125,0.2509765625,0.9150390625,0.3115234375},{18,0.1318359375,0.3134765625,0.2607421875,0.3740234375},{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625}},["idle"]={["intro"]={{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625},{18,0.1318359375,0.3759765625,0.2607421875,0.4365234375},{18,0.1318359375,0.4384765625,0.2607421875,0.4990234375},{18,0.1318359375,0.5009765625,0.2607421875,0.5615234375},{18,0.1318359375,0.5634765625,0.2607421875,0.6240234375},{18,0.1318359375,0.6259765625,0.2607421875,0.6865234375},{18,0.1318359375,0.6884765625,0.2607421875,0.7490234375},{18,0.1318359375,0.7509765625,0.2607421875,0.8115234375},{18,0.1318359375,0.8134765625,0.2607421875,0.8740234375},{18,0.1318359375,0.8759765625,0.2607421875,0.9365234375},{18,0.1318359375,0.9384765625,0.2607421875,0.9990234375},{18,0.2626953125,0.3134765625,0.3916015625,0.3740234375}},["hold"]={{18,0.2626953125,0.3134765625,0.3916015625,0.3740234375},{18,0.3935546875,0.3134765625,0.5224609375,0.3740234375},{18,0.5244140625,0.3134765625,0.6533203125,0.3740234375},{18,0.6552734375,0.3134765625,0.7841796875,0.3740234375},{18,0.7861328125,0.3134765625,0.9150390625,0.3740234375},{18,0.2626953125,0.3759765625,0.3916015625,0.4365234375},{18,0.3935546875,0.3759765625,0.5224609375,0.4365234375},{18,0.5244140625,0.3759765625,0.6533203125,0.4365234375},{18,0.6552734375,0.3759765625,0.7841796875,0.4365234375},{18,0.7861328125,0.3759765625,0.9150390625,0.4365234375},{18,0.2626953125,0.4384765625,0.3916015625,0.4990234375},{18,0.2626953125,0.5009765625,0.3916015625,0.5615234375},{18,0.2626953125,0.5634765625,0.3916015625,0.6240234375},{18,0.2626953125,0.6259765625,0.3916015625,0.6865234375},{18,0.2626953125,0.6884765625,0.3916015625,0.7490234375},{18,0.2626953125,0.7509765625,0.3916015625,0.8115234375},{18,0.2626953125,0.8134765625,0.3916015625,0.8740234375},{18,0.2626953125,0.8759765625,0.3916015625,0.9365234375},{18,0.2626953125,0.9384765625,0.3916015625,0.9990234375},{18,0.3935546875,0.4384765625,0.5224609375,0.4990234375},{18,0.5244140625,0.4384765625,0.6533203125,0.4990234375},{18,0.6552734375,0.4384765625,0.7841796875,0.4990234375},{18,0.7861328125,0.4384765625,0.9150390625,0.4990234375},{18,0.3935546875,0.5009765625,0.5224609375,0.5615234375}},["ending"]={{18,0.2626953125,0.3134765625,0.3916015625,0.3740234375},{18,0.5244140625,0.5009765625,0.6533203125,0.5615234375},{18,0.6552734375,0.5009765625,0.7841796875,0.5615234375},{18,0.7861328125,0.5009765625,0.9150390625,0.5615234375},{18,0.3935546875,0.5634765625,0.5224609375,0.6240234375},{18,0.3935546875,0.6259765625,0.5224609375,0.6865234375},{18,0.3935546875,0.6884765625,0.5224609375,0.7490234375},{18,0.3935546875,0.7509765625,0.5224609375,0.8115234375},{18,0.3935546875,0.8134765625,0.5224609375,0.8740234375},{18,0.3935546875,0.8759765625,0.5224609375,0.9365234375},{18,0.3935546875,0.9384765625,0.5224609375,0.9990234375},{6,0.8701171875,0.6201171875,0.9990234375,0.6806640625}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{18,0.5244140625,0.5634765625,0.6533203125,0.625},{18,0.6552734375,0.5634765625,0.7841796875,0.625},{18,0.7861328125,0.5634765625,0.9150390625,0.625},{18,0.5244140625,0.626953125,0.6533203125,0.6884765625},{18,0.6552734375,0.626953125,0.7841796875,0.6884765625},{18,0.7861328125,0.626953125,0.9150390625,0.6884765625},{18,0.5244140625,0.6904296875,0.6533203125,0.751953125},{18,0.5244140625,0.75390625,0.6533203125,0.8154296875},{18,0.5244140625,0.8173828125,0.6533203125,0.87890625},{18,0.5244140625,0.880859375,0.6533203125,0.9423828125},{18,0.6552734375,0.6904296875,0.7841796875,0.751953125},{18,0.7861328125,0.6904296875,0.9150390625,0.751953125}},["hold"]={{18,0.7861328125,0.6904296875,0.9150390625,0.751953125},{18,0.6552734375,0.75390625,0.7841796875,0.8154296875},{18,0.7861328125,0.75390625,0.9150390625,0.8154296875},{18,0.6552734375,0.8173828125,0.7841796875,0.87890625},{18,0.6552734375,0.880859375,0.7841796875,0.9423828125},{18,0.7861328125,0.8173828125,0.9150390625,0.87890625},{18,0.7861328125,0.880859375,0.9150390625,0.9423828125},{19,0.0009765625,0.0009765625,0.1298828125,0.0625},{19,0.1318359375,0.0009765625,0.2607421875,0.0625},{19,0.2626953125,0.0009765625,0.3916015625,0.0625},{19,0.3935546875,0.0009765625,0.5224609375,0.0625},{19,0.5244140625,0.0009765625,0.6533203125,0.0625},{19,0.6552734375,0.0009765625,0.7841796875,0.0625},{19,0.7861328125,0.0009765625,0.9150390625,0.0625},{19,0.0009765625,0.064453125,0.1298828125,0.1259765625},{19,0.1318359375,0.064453125,0.2607421875,0.1259765625},{19,0.2626953125,0.064453125,0.3916015625,0.1259765625},{19,0.3935546875,0.064453125,0.5224609375,0.1259765625},{19,0.5244140625,0.064453125,0.6533203125,0.1259765625},{19,0.6552734375,0.064453125,0.7841796875,0.1259765625},{19,0.7861328125,0.064453125,0.9150390625,0.1259765625},{19,0.0009765625,0.1279296875,0.1298828125,0.189453125},{19,0.1318359375,0.1279296875,0.2607421875,0.189453125},{19,0.2626953125,0.1279296875,0.3916015625,0.189453125}},["ending"]={{18,0.7861328125,0.6904296875,0.9150390625,0.751953125},{18,0.6552734375,0.6904296875,0.7841796875,0.751953125},{18,0.5244140625,0.880859375,0.6533203125,0.9423828125},{18,0.5244140625,0.8173828125,0.6533203125,0.87890625},{18,0.5244140625,0.75390625,0.6533203125,0.8154296875},{18,0.5244140625,0.6904296875,0.6533203125,0.751953125},{18,0.7861328125,0.626953125,0.9150390625,0.6884765625},{18,0.6552734375,0.626953125,0.7841796875,0.6884765625},{18,0.5244140625,0.626953125,0.6533203125,0.6884765625},{18,0.7861328125,0.5634765625,0.9150390625,0.625},{18,0.6552734375,0.5634765625,0.7841796875,0.625},{18,0.5244140625,0.5634765625,0.6533203125,0.625}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{18,0.5244140625,0.5634765625,0.6533203125,0.625},{19,0.3935546875,0.1279296875,0.5224609375,0.189453125},{19,0.5244140625,0.1279296875,0.6533203125,0.189453125},{19,0.6552734375,0.1279296875,0.7841796875,0.189453125},{19,0.7861328125,0.1279296875,0.9150390625,0.189453125},{19,0.0009765625,0.19140625,0.1298828125,0.2529296875},{19,0.0009765625,0.2548828125,0.1298828125,0.31640625},{19,0.0009765625,0.318359375,0.1298828125,0.3798828125},{19,0.0009765625,0.3818359375,0.1298828125,0.443359375},{19,0.0009765625,0.4453125,0.1298828125,0.5068359375},{19,0.0009765625,0.5087890625,0.1298828125,0.5703125},{19,0.0009765625,0.572265625,0.1298828125,0.6337890625}},["hold"]={{19,0.0009765625,0.572265625,0.1298828125,0.6337890625},{19,0.0009765625,0.6357421875,0.1298828125,0.697265625},{19,0.0009765625,0.69921875,0.1298828125,0.7607421875},{19,0.0009765625,0.7626953125,0.1298828125,0.82421875},{19,0.0009765625,0.826171875,0.1298828125,0.8876953125},{19,0.0009765625,0.8896484375,0.1298828125,0.951171875},{19,0.1318359375,0.19140625,0.2607421875,0.2529296875},{19,0.2626953125,0.19140625,0.3916015625,0.2529296875},{19,0.3935546875,0.19140625,0.5224609375,0.2529296875},{19,0.5244140625,0.19140625,0.6533203125,0.2529296875},{19,0.6552734375,0.19140625,0.7841796875,0.2529296875},{19,0.7861328125,0.19140625,0.9150390625,0.2529296875},{19,0.1318359375,0.2548828125,0.2607421875,0.31640625},{19,0.2626953125,0.2548828125,0.3916015625,0.31640625},{19,0.3935546875,0.2548828125,0.5224609375,0.31640625},{19,0.5244140625,0.2548828125,0.6533203125,0.31640625},{19,0.6552734375,0.2548828125,0.7841796875,0.31640625},{19,0.7861328125,0.2548828125,0.9150390625,0.31640625},{19,0.1318359375,0.318359375,0.2607421875,0.3798828125},{19,0.1318359375,0.3818359375,0.2607421875,0.443359375},{19,0.1318359375,0.4453125,0.2607421875,0.5068359375},{19,0.1318359375,0.5087890625,0.2607421875,0.5703125},{19,0.1318359375,0.572265625,0.2607421875,0.6337890625},{19,0.1318359375,0.6357421875,0.2607421875,0.697265625}},["ending"]={{19,0.0009765625,0.572265625,0.1298828125,0.6337890625},{19,0.1318359375,0.69921875,0.2607421875,0.7607421875},{19,0.1318359375,0.7626953125,0.2607421875,0.82421875},{19,0.1318359375,0.826171875,0.2607421875,0.8876953125},{19,0.1318359375,0.8896484375,0.2607421875,0.951171875},{19,0.2626953125,0.318359375,0.3916015625,0.3798828125},{19,0.3935546875,0.318359375,0.5224609375,0.3798828125},{19,0.5244140625,0.318359375,0.6533203125,0.3798828125},{19,0.6552734375,0.318359375,0.7841796875,0.3798828125},{19,0.7861328125,0.318359375,0.9150390625,0.3798828125},{19,0.2626953125,0.3818359375,0.3916015625,0.443359375},{18,0.5244140625,0.5634765625,0.6533203125,0.625}},["idle"]={["intro"]={{18,0.5244140625,0.5634765625,0.6533203125,0.625},{19,0.3935546875,0.3818359375,0.5224609375,0.443359375},{19,0.5244140625,0.3818359375,0.6533203125,0.443359375},{19,0.6552734375,0.3818359375,0.7841796875,0.443359375},{19,0.7861328125,0.3818359375,0.9150390625,0.443359375},{19,0.2626953125,0.4453125,0.3916015625,0.5068359375},{19,0.2626953125,0.5087890625,0.3916015625,0.5703125},{19,0.2626953125,0.572265625,0.3916015625,0.6337890625},{19,0.2626953125,0.6357421875,0.3916015625,0.697265625},{19,0.2626953125,0.69921875,0.3916015625,0.7607421875},{19,0.2626953125,0.7626953125,0.3916015625,0.82421875},{19,0.2626953125,0.826171875,0.3916015625,0.8876953125}},["hold"]={{19,0.2626953125,0.826171875,0.3916015625,0.8876953125},{19,0.2626953125,0.8896484375,0.3916015625,0.951171875},{19,0.3935546875,0.4453125,0.5224609375,0.5068359375},{19,0.5244140625,0.4453125,0.6533203125,0.5068359375},{19,0.6552734375,0.4453125,0.7841796875,0.5068359375},{19,0.7861328125,0.4453125,0.9150390625,0.5068359375},{19,0.3935546875,0.5087890625,0.5224609375,0.5703125},{19,0.5244140625,0.5087890625,0.6533203125,0.5703125},{19,0.6552734375,0.5087890625,0.7841796875,0.5703125},{19,0.7861328125,0.5087890625,0.9150390625,0.5703125},{19,0.3935546875,0.572265625,0.5224609375,0.6337890625},{19,0.3935546875,0.6357421875,0.5224609375,0.697265625},{19,0.3935546875,0.69921875,0.5224609375,0.7607421875},{19,0.3935546875,0.7626953125,0.5224609375,0.82421875},{19,0.3935546875,0.826171875,0.5224609375,0.8876953125},{19,0.3935546875,0.8896484375,0.5224609375,0.951171875},{19,0.5244140625,0.572265625,0.6533203125,0.6337890625},{19,0.6552734375,0.572265625,0.7841796875,0.6337890625},{19,0.7861328125,0.572265625,0.9150390625,0.6337890625},{19,0.5244140625,0.6357421875,0.6533203125,0.697265625},{19,0.6552734375,0.6357421875,0.7841796875,0.697265625},{19,0.7861328125,0.6357421875,0.9150390625,0.697265625},{19,0.5244140625,0.69921875,0.6533203125,0.7607421875},{19,0.5244140625,0.7626953125,0.6533203125,0.82421875}},["ending"]={{19,0.2626953125,0.826171875,0.3916015625,0.8876953125},{19,0.5244140625,0.826171875,0.6533203125,0.8876953125},{19,0.5244140625,0.8896484375,0.6533203125,0.951171875},{19,0.6552734375,0.69921875,0.7841796875,0.7607421875},{19,0.7861328125,0.69921875,0.9150390625,0.7607421875},{19,0.6552734375,0.7626953125,0.7841796875,0.82421875},{19,0.7861328125,0.7626953125,0.9150390625,0.82421875},{19,0.6552734375,0.826171875,0.7841796875,0.8876953125},{19,0.6552734375,0.8896484375,0.7841796875,0.951171875},{19,0.7861328125,0.826171875,0.9150390625,0.8876953125},{19,0.7861328125,0.8896484375,0.9150390625,0.951171875},{18,0.5244140625,0.5634765625,0.6533203125,0.625}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{1,0.6689453125,0.7666015625,0.81640625,0.875},{2,0.6689453125,0.7666015625,0.81640625,0.875},{3,0.6689453125,0.7666015625,0.81640625,0.875},{4,0.6689453125,0.7666015625,0.81640625,0.875},{5,0.6689453125,0.7666015625,0.81640625,0.875},{1,0.6689453125,0.876953125,0.81640625,0.9853515625},{2,0.6689453125,0.876953125,0.81640625,0.9853515625},{3,0.6689453125,0.876953125,0.81640625,0.9853515625},{4,0.6689453125,0.876953125,0.81640625,0.9853515625},{5,0.6689453125,0.876953125,0.81640625,0.9853515625},{6,0.8271484375,0.21484375,0.974609375,0.3232421875},{1,0.818359375,0.8564453125,0.9658203125,0.96484375}},["hold"]={{1,0.818359375,0.8564453125,0.9658203125,0.96484375},{2,0.818359375,0.8564453125,0.9658203125,0.96484375},{3,0.818359375,0.8564453125,0.9658203125,0.96484375},{4,0.818359375,0.8564453125,0.9658203125,0.96484375},{5,0.818359375,0.8564453125,0.9658203125,0.96484375},{13,0.0009765625,0.833984375,0.1484375,0.9423828125},{16,0.7744140625,0.1953125,0.921875,0.3037109375},{16,0.7744140625,0.3056640625,0.921875,0.4140625},{16,0.3876953125,0.3896484375,0.53515625,0.498046875},{16,0.537109375,0.3896484375,0.6845703125,0.498046875},{16,0.6865234375,0.416015625,0.833984375,0.5244140625},{16,0.8359375,0.416015625,0.9833984375,0.5244140625},{16,0.3876953125,0.5,0.53515625,0.6083984375},{16,0.537109375,0.5,0.6845703125,0.6083984375},{16,0.6865234375,0.5263671875,0.833984375,0.634765625},{16,0.8359375,0.5263671875,0.9833984375,0.634765625},{16,0.3876953125,0.6103515625,0.53515625,0.71875},{16,0.537109375,0.6103515625,0.6845703125,0.71875},{16,0.6865234375,0.63671875,0.833984375,0.7451171875},{16,0.8359375,0.63671875,0.9833984375,0.7451171875},{16,0.3876953125,0.7470703125,0.53515625,0.85546875},{16,0.537109375,0.720703125,0.6845703125,0.8291015625},{16,0.3876953125,0.857421875,0.53515625,0.9658203125},{16,0.537109375,0.8310546875,0.6845703125,0.939453125}},["ending"]={{1,0.818359375,0.8564453125,0.9658203125,0.96484375},{6,0.8271484375,0.21484375,0.974609375,0.3232421875},{5,0.6689453125,0.876953125,0.81640625,0.9853515625},{4,0.6689453125,0.876953125,0.81640625,0.9853515625},{3,0.6689453125,0.876953125,0.81640625,0.9853515625},{2,0.6689453125,0.876953125,0.81640625,0.9853515625},{1,0.6689453125,0.876953125,0.81640625,0.9853515625},{5,0.6689453125,0.7666015625,0.81640625,0.875},{4,0.6689453125,0.7666015625,0.81640625,0.875},{3,0.6689453125,0.7666015625,0.81640625,0.875},{2,0.6689453125,0.7666015625,0.81640625,0.875},{1,0.6689453125,0.7666015625,0.81640625,0.875}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{1,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{1,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{1,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{1,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{1,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{2,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{2,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{2,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{2,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{2,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{2,0.5517578125,0.3837890625,0.8251953125,0.7646484375}},["hold"]={{2,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{3,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{3,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{3,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{3,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{3,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{3,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{4,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{4,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{4,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{4,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{4,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{4,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{5,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{5,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{5,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{5,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{5,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{5,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{6,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{6,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{6,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{6,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{6,0.2763671875,0.3837890625,0.5498046875,0.7646484375}},["ending"]={{2,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{2,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{2,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{2,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{2,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{2,0.0009765625,0.0009765625,0.2744140625,0.3818359375},{1,0.5517578125,0.3837890625,0.8251953125,0.7646484375},{1,0.2763671875,0.3837890625,0.5498046875,0.7646484375},{1,0.5517578125,0.0009765625,0.8251953125,0.3818359375},{1,0.2763671875,0.0009765625,0.5498046875,0.3818359375},{1,0.0009765625,0.3837890625,0.2744140625,0.7646484375},{1,0.0009765625,0.0009765625,0.2744140625,0.3818359375}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{6,0.6689453125,0.7568359375,0.8291015625,0.9677734375},{6,0.8310546875,0.7568359375,0.9912109375,0.9677734375},{7,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{7,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{7,0.3251953125,0.7470703125,0.4853515625,0.9580078125},{7,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{7,0.6494140625,0.7470703125,0.8095703125,0.9580078125},{7,0.8115234375,0.7470703125,0.9716796875,0.9580078125},{8,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{8,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{8,0.3251953125,0.7470703125,0.4853515625,0.9580078125},{8,0.4873046875,0.7470703125,0.6474609375,0.9580078125}},["hold"]={{8,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{8,0.6494140625,0.7470703125,0.8095703125,0.9580078125},{8,0.8115234375,0.7470703125,0.9716796875,0.9580078125},{9,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{9,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{9,0.3251953125,0.7470703125,0.4853515625,0.9580078125},{9,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{9,0.6494140625,0.7470703125,0.8095703125,0.9580078125},{9,0.8115234375,0.7470703125,0.9716796875,0.9580078125},{10,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{10,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{10,0.3251953125,0.7470703125,0.4853515625,0.9580078125},{10,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{10,0.6494140625,0.7470703125,0.8095703125,0.9580078125},{10,0.8115234375,0.7470703125,0.9716796875,0.9580078125},{11,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{11,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{11,0.3251953125,0.7470703125,0.4853515625,0.9580078125},{11,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{11,0.6494140625,0.7470703125,0.8095703125,0.9580078125},{11,0.8115234375,0.7470703125,0.9716796875,0.9580078125},{12,0.0009765625,0.7470703125,0.1611328125,0.9580078125},{12,0.1630859375,0.7470703125,0.3232421875,0.9580078125},{12,0.3193359375,0.3740234375,0.4794921875,0.5849609375}},["ending"]={{8,0.4873046875,0.7470703125,0.6474609375,0.9580078125},{12,0.3251953125,0.5869140625,0.4853515625,0.7978515625},{12,0.4814453125,0.3740234375,0.6416015625,0.5849609375},{12,0.6435546875,0.3740234375,0.8037109375,0.5849609375},{12,0.8056640625,0.3740234375,0.9658203125,0.5849609375},{12,0.4873046875,0.5869140625,0.6474609375,0.7978515625},{12,0.6494140625,0.5869140625,0.8095703125,0.7978515625},{12,0.8115234375,0.5869140625,0.9716796875,0.7978515625},{13,0.0009765625,0.0009765625,0.1611328125,0.2119140625},{13,0.0009765625,0.2138671875,0.1611328125,0.4248046875},{13,0.0009765625,0.4267578125,0.1611328125,0.6376953125},{6,0.6689453125,0.7568359375,0.8291015625,0.9677734375}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{6,0.8271484375,0.0009765625,0.9921875,0.212890625},{1,0.8271484375,0.0009765625,0.9921875,0.212890625},{1,0.8271484375,0.21484375,0.9921875,0.4267578125},{1,0.8271484375,0.4287109375,0.9921875,0.640625},{1,0.8271484375,0.642578125,0.9921875,0.8544921875},{2,0.8271484375,0.0009765625,0.9921875,0.212890625},{2,0.8271484375,0.21484375,0.9921875,0.4267578125},{2,0.8271484375,0.4287109375,0.9921875,0.640625},{2,0.8271484375,0.642578125,0.9921875,0.8544921875},{3,0.8271484375,0.0009765625,0.9921875,0.212890625},{3,0.8271484375,0.21484375,0.9921875,0.4267578125},{3,0.8271484375,0.4287109375,0.9921875,0.640625}},["hold"]={{3,0.8271484375,0.4287109375,0.9921875,0.640625},{3,0.8271484375,0.642578125,0.9921875,0.8544921875},{4,0.8271484375,0.0009765625,0.9921875,0.212890625},{4,0.8271484375,0.21484375,0.9921875,0.4267578125},{4,0.8271484375,0.4287109375,0.9921875,0.640625},{4,0.8271484375,0.642578125,0.9921875,0.8544921875},{5,0.8271484375,0.0009765625,0.9921875,0.212890625},{5,0.8271484375,0.21484375,0.9921875,0.4267578125},{5,0.8271484375,0.4287109375,0.9921875,0.640625},{5,0.8271484375,0.642578125,0.9921875,0.8544921875},{1,0.0009765625,0.7666015625,0.166015625,0.978515625},{1,0.16796875,0.7666015625,0.3330078125,0.978515625},{1,0.3349609375,0.7666015625,0.5,0.978515625},{1,0.501953125,0.7666015625,0.6669921875,0.978515625},{2,0.0009765625,0.7666015625,0.166015625,0.978515625},{2,0.16796875,0.7666015625,0.3330078125,0.978515625},{2,0.3349609375,0.7666015625,0.5,0.978515625},{2,0.501953125,0.7666015625,0.6669921875,0.978515625},{3,0.0009765625,0.7666015625,0.166015625,0.978515625},{3,0.16796875,0.7666015625,0.3330078125,0.978515625},{3,0.3349609375,0.7666015625,0.5,0.978515625},{3,0.501953125,0.7666015625,0.6669921875,0.978515625},{4,0.0009765625,0.7666015625,0.166015625,0.978515625},{4,0.16796875,0.7666015625,0.3330078125,0.978515625}},["ending"]={{3,0.8271484375,0.4287109375,0.9921875,0.640625},{4,0.3349609375,0.7666015625,0.5,0.978515625},{4,0.501953125,0.7666015625,0.6669921875,0.978515625},{5,0.0009765625,0.7666015625,0.166015625,0.978515625},{5,0.16796875,0.7666015625,0.3330078125,0.978515625},{5,0.3349609375,0.7666015625,0.5,0.978515625},{5,0.501953125,0.7666015625,0.6669921875,0.978515625},{6,0.0009765625,0.7666015625,0.166015625,0.978515625},{6,0.16796875,0.7666015625,0.3330078125,0.978515625},{6,0.3349609375,0.7666015625,0.5,0.978515625},{6,0.501953125,0.7666015625,0.6669921875,0.978515625},{6,0.8271484375,0.0009765625,0.9921875,0.212890625}},["pages"]={"StudioDruidRestorationChannelPlusSize480Page1.tga","StudioDruidRestorationChannelPlusSize480Page2.tga","StudioDruidRestorationChannelPlusSize480Page3.tga","StudioDruidRestorationChannelPlusSize480Page4.tga","StudioDruidRestorationChannelPlusSize480Page5.tga","StudioDruidRestorationChannelPlusSize480Page6.tga","StudioDruidRestorationChannelPlusSize480Page7.tga","StudioDruidRestorationChannelPlusSize480Page8.tga","StudioDruidRestorationChannelPlusSize480Page9.tga","StudioDruidRestorationChannelPlusSize480Page10.tga","StudioDruidRestorationChannelPlusSize480Page11.tga","StudioDruidRestorationChannelPlusSize480Page12.tga","StudioDruidRestorationChannelPlusSize480Page13.tga","StudioDruidRestorationChannelPlusSize480Page14.tga","StudioDruidRestorationChannelPlusSize480Page15.tga","StudioDruidRestorationChannelPlusSize480Page16.tga","StudioDruidRestorationChannelPlusSize480Page17.tga","StudioDruidRestorationChannelPlusSize480Page18.tga","StudioDruidRestorationChannelPlusSize480Page19.tga"}}},[576]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{7,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{7,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{7,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{7,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{8,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{8,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{8,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{8,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{9,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{9,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{9,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{9,0.3818359375,0.4482421875,0.7607421875,0.8935546875}},["hold"]={{9,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{10,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{10,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{10,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{10,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{11,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{11,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{11,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{11,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{12,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{12,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{12,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{12,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{13,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{13,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{13,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{13,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{14,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{14,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{14,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{14,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{15,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{15,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{15,0.3818359375,0.0009765625,0.7607421875,0.4462890625}},["ending"]={{9,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{9,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{9,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{9,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{8,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{8,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{8,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{8,0.0009765625,0.0009765625,0.3798828125,0.4462890625},{7,0.3818359375,0.4482421875,0.7607421875,0.8935546875},{7,0.3818359375,0.0009765625,0.7607421875,0.4462890625},{7,0.0009765625,0.4482421875,0.3798828125,0.8935546875},{7,0.0009765625,0.0009765625,0.3798828125,0.4462890625}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{6,0.861328125,0.4599609375,0.98828125,0.634765625},{6,0.861328125,0.63671875,0.98828125,0.8115234375},{6,0.861328125,0.8134765625,0.98828125,0.98828125},{24,0.8232421875,0.4677734375,0.9501953125,0.642578125},{24,0.8232421875,0.64453125,0.9501953125,0.8193359375},{24,0.8232421875,0.8212890625,0.9501953125,0.99609375},{25,0.1806640625,0.1328125,0.3076171875,0.3076171875},{25,0.1806640625,0.3095703125,0.3076171875,0.484375},{25,0.1806640625,0.486328125,0.3076171875,0.6611328125},{25,0.1806640625,0.6630859375,0.3076171875,0.837890625},{25,0.3095703125,0.1328125,0.4365234375,0.3076171875},{25,0.4384765625,0.1328125,0.5654296875,0.3076171875}},["hold"]={{25,0.4384765625,0.1328125,0.5654296875,0.3076171875},{25,0.5673828125,0.1328125,0.6943359375,0.3076171875},{25,0.6962890625,0.1328125,0.8232421875,0.3076171875},{25,0.8251953125,0.1328125,0.9521484375,0.3076171875},{25,0.3095703125,0.3095703125,0.4365234375,0.484375},{25,0.3095703125,0.486328125,0.4365234375,0.6611328125},{25,0.3095703125,0.6630859375,0.4365234375,0.837890625},{25,0.4384765625,0.3095703125,0.5654296875,0.484375},{25,0.5673828125,0.3095703125,0.6943359375,0.484375},{25,0.6962890625,0.3095703125,0.8232421875,0.484375},{25,0.8251953125,0.3095703125,0.9521484375,0.484375},{25,0.4384765625,0.486328125,0.5654296875,0.6611328125},{25,0.4384765625,0.6630859375,0.5654296875,0.837890625},{25,0.5673828125,0.486328125,0.6943359375,0.6611328125},{25,0.5673828125,0.6630859375,0.6943359375,0.837890625},{25,0.6962890625,0.486328125,0.8232421875,0.6611328125},{25,0.8251953125,0.486328125,0.9521484375,0.6611328125},{25,0.6962890625,0.6630859375,0.8232421875,0.837890625},{25,0.8251953125,0.6630859375,0.9521484375,0.837890625},{26,0.0009765625,0.0009765625,0.1279296875,0.17578125},{26,0.0009765625,0.177734375,0.1279296875,0.3525390625},{26,0.0009765625,0.3544921875,0.1279296875,0.529296875},{26,0.0009765625,0.53125,0.1279296875,0.7060546875},{26,0.0009765625,0.7080078125,0.1279296875,0.8828125}},["ending"]={{25,0.4384765625,0.1328125,0.5654296875,0.3076171875},{26,0.1298828125,0.0009765625,0.2568359375,0.17578125},{26,0.2587890625,0.0009765625,0.3857421875,0.17578125},{26,0.3876953125,0.0009765625,0.5146484375,0.17578125},{26,0.5166015625,0.0009765625,0.6435546875,0.17578125},{26,0.6455078125,0.0009765625,0.7724609375,0.17578125},{26,0.7744140625,0.0009765625,0.9013671875,0.17578125},{26,0.1298828125,0.177734375,0.2568359375,0.3525390625},{26,0.1298828125,0.3544921875,0.2568359375,0.529296875},{26,0.1298828125,0.53125,0.2568359375,0.7060546875},{26,0.1298828125,0.7080078125,0.2568359375,0.8828125},{6,0.861328125,0.4599609375,0.98828125,0.634765625}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{17,0.0009765625,0.767578125,0.23046875,0.9990234375},{17,0.232421875,0.767578125,0.4619140625,0.9990234375},{17,0.4638671875,0.765625,0.693359375,0.9970703125},{17,0.6953125,0.765625,0.9248046875,0.9970703125},{18,0.0009765625,0.765625,0.23046875,0.9970703125},{18,0.232421875,0.765625,0.4619140625,0.9970703125},{18,0.4638671875,0.765625,0.693359375,0.9970703125},{18,0.6953125,0.765625,0.9248046875,0.9970703125},{19,0.0009765625,0.765625,0.23046875,0.9970703125},{19,0.232421875,0.765625,0.4619140625,0.9970703125},{19,0.4638671875,0.765625,0.693359375,0.9970703125},{19,0.5810546875,0.5107421875,0.810546875,0.7421875}},["hold"]={{19,0.5810546875,0.5107421875,0.810546875,0.7421875},{19,0.6953125,0.744140625,0.9248046875,0.9755859375},{20,0.0009765625,0.0009765625,0.23046875,0.232421875},{20,0.0009765625,0.234375,0.23046875,0.4658203125},{20,0.0009765625,0.4677734375,0.23046875,0.69921875},{20,0.0009765625,0.701171875,0.23046875,0.9326171875},{20,0.232421875,0.0009765625,0.4619140625,0.232421875},{20,0.4638671875,0.0009765625,0.693359375,0.232421875},{20,0.6953125,0.0009765625,0.9248046875,0.232421875},{20,0.232421875,0.234375,0.4619140625,0.4658203125},{20,0.232421875,0.4677734375,0.4619140625,0.69921875},{20,0.232421875,0.701171875,0.4619140625,0.9326171875},{20,0.4638671875,0.234375,0.693359375,0.4658203125},{20,0.6953125,0.234375,0.9248046875,0.4658203125},{20,0.4638671875,0.4677734375,0.693359375,0.69921875},{20,0.4638671875,0.701171875,0.693359375,0.9326171875},{20,0.6953125,0.4677734375,0.9248046875,0.69921875},{20,0.6953125,0.701171875,0.9248046875,0.9326171875},{21,0.0009765625,0.0009765625,0.23046875,0.232421875},{21,0.0009765625,0.234375,0.23046875,0.4658203125},{21,0.0009765625,0.4677734375,0.23046875,0.69921875},{21,0.0009765625,0.701171875,0.23046875,0.9326171875},{21,0.232421875,0.0009765625,0.4619140625,0.232421875},{21,0.4638671875,0.0009765625,0.693359375,0.232421875}},["ending"]={{19,0.5810546875,0.5107421875,0.810546875,0.7421875},{21,0.6953125,0.0009765625,0.9248046875,0.232421875},{21,0.232421875,0.234375,0.4619140625,0.4658203125},{21,0.232421875,0.4677734375,0.4619140625,0.69921875},{21,0.232421875,0.701171875,0.4619140625,0.9326171875},{21,0.4638671875,0.234375,0.693359375,0.4658203125},{21,0.6953125,0.234375,0.9248046875,0.4658203125},{21,0.4638671875,0.4677734375,0.693359375,0.69921875},{21,0.4638671875,0.701171875,0.693359375,0.9326171875},{21,0.6953125,0.4677734375,0.9248046875,0.69921875},{21,0.6953125,0.701171875,0.9248046875,0.9326171875},{17,0.0009765625,0.767578125,0.23046875,0.9990234375}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"},["matched"]={["layer"]="treant",["intro"]={{17,0.0009765625,0.767578125,0.23046875,0.9990234375},{22,0.0009765625,0.0009765625,0.23046875,0.232421875},{22,0.0009765625,0.234375,0.23046875,0.4658203125},{22,0.0009765625,0.4677734375,0.23046875,0.69921875},{22,0.0009765625,0.701171875,0.23046875,0.9326171875},{22,0.232421875,0.0009765625,0.4619140625,0.232421875},{22,0.4638671875,0.0009765625,0.693359375,0.232421875},{22,0.6953125,0.0009765625,0.9248046875,0.232421875},{22,0.232421875,0.234375,0.4619140625,0.4658203125},{22,0.232421875,0.4677734375,0.4619140625,0.69921875},{22,0.232421875,0.701171875,0.4619140625,0.9326171875},{22,0.4638671875,0.234375,0.693359375,0.4658203125}},["hold"]={{22,0.4638671875,0.234375,0.693359375,0.4658203125},{22,0.6953125,0.234375,0.9248046875,0.4658203125},{22,0.4638671875,0.4677734375,0.693359375,0.69921875},{22,0.4638671875,0.701171875,0.693359375,0.9326171875},{22,0.6953125,0.4677734375,0.9248046875,0.69921875},{22,0.6953125,0.701171875,0.9248046875,0.9326171875},{23,0.0009765625,0.0009765625,0.23046875,0.232421875},{23,0.0009765625,0.234375,0.23046875,0.4658203125},{23,0.0009765625,0.4677734375,0.23046875,0.69921875},{23,0.0009765625,0.701171875,0.23046875,0.9326171875},{23,0.232421875,0.0009765625,0.4619140625,0.232421875},{23,0.4638671875,0.0009765625,0.693359375,0.232421875},{23,0.6953125,0.0009765625,0.9248046875,0.232421875},{23,0.232421875,0.234375,0.4619140625,0.4658203125},{23,0.232421875,0.4677734375,0.4619140625,0.69921875},{23,0.232421875,0.701171875,0.4619140625,0.9326171875},{23,0.4638671875,0.234375,0.693359375,0.4658203125},{23,0.6953125,0.234375,0.9248046875,0.4658203125},{23,0.4638671875,0.4677734375,0.693359375,0.69921875},{23,0.4638671875,0.701171875,0.693359375,0.9326171875},{23,0.6953125,0.4677734375,0.9248046875,0.69921875},{23,0.6953125,0.701171875,0.9248046875,0.9326171875},{24,0.0009765625,0.0009765625,0.23046875,0.232421875},{24,0.0009765625,0.234375,0.23046875,0.4658203125}},["ending"]={{22,0.4638671875,0.234375,0.693359375,0.4658203125},{24,0.0009765625,0.4677734375,0.23046875,0.69921875},{24,0.0009765625,0.701171875,0.23046875,0.9326171875},{24,0.232421875,0.0009765625,0.4619140625,0.232421875},{24,0.4638671875,0.0009765625,0.693359375,0.232421875},{24,0.6953125,0.0009765625,0.9248046875,0.232421875},{24,0.232421875,0.234375,0.4619140625,0.4658203125},{24,0.232421875,0.4677734375,0.4619140625,0.69921875},{24,0.232421875,0.701171875,0.4619140625,0.9326171875},{24,0.4638671875,0.234375,0.693359375,0.4658203125},{24,0.6953125,0.234375,0.9248046875,0.4658203125},{17,0.0009765625,0.767578125,0.23046875,0.9990234375}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{25,0.0009765625,0.923828125,0.1552734375,0.99609375},{25,0.1572265625,0.923828125,0.3115234375,0.99609375},{6,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{6,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{6,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{6,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{1,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{1,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{1,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{1,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{1,0.6259765625,0.9189453125,0.7802734375,0.9912109375},{1,0.7822265625,0.9189453125,0.9365234375,0.9912109375}},["hold"]={{1,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{2,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{2,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{2,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{2,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{2,0.6259765625,0.9189453125,0.7802734375,0.9912109375},{2,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{3,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{3,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{3,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{3,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{3,0.6259765625,0.9189453125,0.7802734375,0.9912109375},{3,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{4,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{4,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{4,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{4,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{4,0.6259765625,0.9189453125,0.7802734375,0.9912109375},{4,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{5,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{5,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{5,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{5,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{5,0.6259765625,0.9189453125,0.7802734375,0.9912109375}},["ending"]={{1,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{1,0.6259765625,0.9189453125,0.7802734375,0.9912109375},{1,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{1,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{1,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{1,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{6,0.4697265625,0.9189453125,0.6240234375,0.9912109375},{6,0.3134765625,0.9189453125,0.4677734375,0.9912109375},{6,0.1572265625,0.9189453125,0.3115234375,0.9912109375},{6,0.0009765625,0.9189453125,0.1552734375,0.9912109375},{25,0.1572265625,0.923828125,0.3115234375,0.99609375},{25,0.0009765625,0.923828125,0.1552734375,0.99609375}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{25,0.0009765625,0.923828125,0.1552734375,0.99609375},{5,0.7822265625,0.9189453125,0.9365234375,0.9912109375},{25,0.1806640625,0.83984375,0.3349609375,0.912109375},{25,0.3134765625,0.9140625,0.4677734375,0.986328125},{25,0.3369140625,0.83984375,0.4912109375,0.912109375},{25,0.4697265625,0.9140625,0.6240234375,0.986328125},{25,0.4931640625,0.83984375,0.6474609375,0.912109375},{25,0.6259765625,0.9140625,0.7802734375,0.986328125},{25,0.6494140625,0.83984375,0.8037109375,0.912109375},{25,0.7822265625,0.9140625,0.9365234375,0.986328125},{25,0.8056640625,0.83984375,0.9599609375,0.912109375},{15,0.58203125,0.9033203125,0.736328125,0.9755859375}},["hold"]={{15,0.58203125,0.9033203125,0.736328125,0.9755859375},{15,0.73828125,0.9033203125,0.892578125,0.9755859375},{7,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{7,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{7,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{7,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{7,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{7,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{8,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{8,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{8,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{8,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{8,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{8,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{9,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{9,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{9,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{9,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{9,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{9,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{10,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{10,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{10,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{10,0.4697265625,0.9033203125,0.6240234375,0.9755859375}},["ending"]={{15,0.58203125,0.9033203125,0.736328125,0.9755859375},{10,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{10,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{11,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{11,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{11,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{11,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{11,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{11,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{12,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{12,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{25,0.0009765625,0.923828125,0.1552734375,0.99609375}},["idle"]={["intro"]={{25,0.0009765625,0.923828125,0.1552734375,0.99609375},{12,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{12,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{12,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{12,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{13,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{13,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{13,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{13,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{13,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{13,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{14,0.0009765625,0.9033203125,0.1552734375,0.9755859375}},["hold"]={{14,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{14,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{14,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{14,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{14,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{14,0.7822265625,0.9033203125,0.9365234375,0.9755859375},{16,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{16,0.1572265625,0.9033203125,0.3115234375,0.9755859375},{16,0.3134765625,0.9033203125,0.4677734375,0.9755859375},{16,0.4697265625,0.9033203125,0.6240234375,0.9755859375},{16,0.6259765625,0.9033203125,0.7802734375,0.9755859375},{19,0.8125,0.642578125,0.966796875,0.71484375},{16,0.7822265625,0.8974609375,0.9365234375,0.9697265625},{15,0.0009765625,0.8955078125,0.1552734375,0.9677734375},{15,0.1572265625,0.8955078125,0.3115234375,0.9677734375},{26,0.0009765625,0.884765625,0.1552734375,0.95703125},{26,0.1572265625,0.884765625,0.3115234375,0.95703125},{26,0.3134765625,0.177734375,0.4677734375,0.25},{26,0.4697265625,0.177734375,0.6240234375,0.25},{26,0.6259765625,0.177734375,0.7802734375,0.25},{26,0.7822265625,0.177734375,0.9365234375,0.25},{26,0.3134765625,0.251953125,0.4677734375,0.32421875},{26,0.4697265625,0.251953125,0.6240234375,0.32421875},{26,0.6259765625,0.251953125,0.7802734375,0.32421875}},["ending"]={{14,0.0009765625,0.9033203125,0.1552734375,0.9755859375},{26,0.7822265625,0.251953125,0.9365234375,0.32421875},{26,0.2587890625,0.326171875,0.4130859375,0.3984375},{26,0.2587890625,0.400390625,0.4130859375,0.47265625},{26,0.2587890625,0.474609375,0.4130859375,0.546875},{26,0.2587890625,0.548828125,0.4130859375,0.62109375},{26,0.2587890625,0.623046875,0.4130859375,0.6953125},{26,0.2587890625,0.697265625,0.4130859375,0.76953125},{26,0.2587890625,0.771484375,0.4130859375,0.84375},{26,0.3134765625,0.845703125,0.4677734375,0.91796875},{26,0.3134765625,0.919921875,0.4677734375,0.9921875},{25,0.0009765625,0.923828125,0.1552734375,0.99609375}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{26,0.4697265625,0.326171875,0.6240234375,0.3994140625},{26,0.6259765625,0.326171875,0.7802734375,0.3994140625},{26,0.7822265625,0.326171875,0.9365234375,0.3994140625},{26,0.4150390625,0.4013671875,0.5693359375,0.474609375},{26,0.5712890625,0.4013671875,0.7255859375,0.474609375},{26,0.7275390625,0.4013671875,0.8818359375,0.474609375},{26,0.4150390625,0.4765625,0.5693359375,0.5498046875},{26,0.4150390625,0.5517578125,0.5693359375,0.625},{26,0.4150390625,0.626953125,0.5693359375,0.7001953125},{26,0.4150390625,0.7021484375,0.5693359375,0.775390625},{26,0.4697265625,0.77734375,0.6240234375,0.8505859375},{26,0.4697265625,0.8525390625,0.6240234375,0.92578125}},["hold"]={{26,0.4697265625,0.8525390625,0.6240234375,0.92578125},{26,0.6259765625,0.4765625,0.7802734375,0.5498046875},{26,0.7822265625,0.4765625,0.9365234375,0.5498046875},{26,0.5712890625,0.5517578125,0.7255859375,0.625},{26,0.5712890625,0.626953125,0.7255859375,0.7001953125},{26,0.5712890625,0.7021484375,0.7255859375,0.775390625},{26,0.7275390625,0.5517578125,0.8818359375,0.625},{26,0.7275390625,0.626953125,0.8818359375,0.7001953125},{26,0.7275390625,0.7021484375,0.8818359375,0.775390625},{26,0.6259765625,0.77734375,0.7802734375,0.8505859375},{26,0.7822265625,0.77734375,0.9365234375,0.8505859375},{26,0.6259765625,0.8525390625,0.7802734375,0.92578125},{26,0.7822265625,0.8525390625,0.9365234375,0.92578125},{27,0.0009765625,0.0009765625,0.1552734375,0.07421875},{27,0.1572265625,0.0009765625,0.3115234375,0.07421875},{27,0.3134765625,0.0009765625,0.4677734375,0.07421875},{27,0.4697265625,0.0009765625,0.6240234375,0.07421875},{27,0.6259765625,0.0009765625,0.7802734375,0.07421875},{27,0.7822265625,0.0009765625,0.9365234375,0.07421875},{27,0.0009765625,0.076171875,0.1552734375,0.1494140625},{27,0.1572265625,0.076171875,0.3115234375,0.1494140625},{27,0.3134765625,0.076171875,0.4677734375,0.1494140625},{27,0.4697265625,0.076171875,0.6240234375,0.1494140625},{27,0.6259765625,0.076171875,0.7802734375,0.1494140625}},["ending"]={{26,0.4697265625,0.8525390625,0.6240234375,0.92578125},{26,0.4697265625,0.77734375,0.6240234375,0.8505859375},{26,0.4150390625,0.7021484375,0.5693359375,0.775390625},{26,0.4150390625,0.626953125,0.5693359375,0.7001953125},{26,0.4150390625,0.5517578125,0.5693359375,0.625},{26,0.4150390625,0.4765625,0.5693359375,0.5498046875},{26,0.7275390625,0.4013671875,0.8818359375,0.474609375},{26,0.5712890625,0.4013671875,0.7255859375,0.474609375},{26,0.4150390625,0.4013671875,0.5693359375,0.474609375},{26,0.7822265625,0.326171875,0.9365234375,0.3994140625},{26,0.6259765625,0.326171875,0.7802734375,0.3994140625},{26,0.4697265625,0.326171875,0.6240234375,0.3994140625}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{26,0.4697265625,0.326171875,0.6240234375,0.3994140625},{27,0.7822265625,0.076171875,0.9365234375,0.1494140625},{27,0.0009765625,0.1513671875,0.1552734375,0.224609375},{27,0.1572265625,0.1513671875,0.3115234375,0.224609375},{27,0.3134765625,0.1513671875,0.4677734375,0.224609375},{27,0.4697265625,0.1513671875,0.6240234375,0.224609375},{27,0.6259765625,0.1513671875,0.7802734375,0.224609375},{27,0.7822265625,0.1513671875,0.9365234375,0.224609375},{27,0.0009765625,0.2265625,0.1552734375,0.2998046875},{27,0.0009765625,0.3017578125,0.1552734375,0.375},{27,0.0009765625,0.376953125,0.1552734375,0.4501953125},{27,0.0009765625,0.4521484375,0.1552734375,0.525390625}},["hold"]={{27,0.0009765625,0.4521484375,0.1552734375,0.525390625},{27,0.0009765625,0.52734375,0.1552734375,0.6005859375},{27,0.0009765625,0.6025390625,0.1552734375,0.67578125},{27,0.0009765625,0.677734375,0.1552734375,0.7509765625},{27,0.0009765625,0.7529296875,0.1552734375,0.826171875},{27,0.0009765625,0.828125,0.1552734375,0.9013671875},{27,0.0009765625,0.9033203125,0.1552734375,0.9765625},{27,0.1572265625,0.2265625,0.3115234375,0.2998046875},{27,0.3134765625,0.2265625,0.4677734375,0.2998046875},{27,0.4697265625,0.2265625,0.6240234375,0.2998046875},{27,0.6259765625,0.2265625,0.7802734375,0.2998046875},{27,0.7822265625,0.2265625,0.9365234375,0.2998046875},{27,0.1572265625,0.3017578125,0.3115234375,0.375},{27,0.3134765625,0.3017578125,0.4677734375,0.375},{27,0.4697265625,0.3017578125,0.6240234375,0.375},{27,0.6259765625,0.3017578125,0.7802734375,0.375},{27,0.7822265625,0.3017578125,0.9365234375,0.375},{27,0.1572265625,0.376953125,0.3115234375,0.4501953125},{27,0.1572265625,0.4521484375,0.3115234375,0.525390625},{27,0.1572265625,0.52734375,0.3115234375,0.6005859375},{27,0.1572265625,0.6025390625,0.3115234375,0.67578125},{27,0.1572265625,0.677734375,0.3115234375,0.7509765625},{27,0.1572265625,0.7529296875,0.3115234375,0.826171875},{27,0.1572265625,0.828125,0.3115234375,0.9013671875}},["ending"]={{27,0.0009765625,0.4521484375,0.1552734375,0.525390625},{27,0.1572265625,0.9033203125,0.3115234375,0.9765625},{27,0.3134765625,0.376953125,0.4677734375,0.4501953125},{27,0.4697265625,0.376953125,0.6240234375,0.4501953125},{27,0.6259765625,0.376953125,0.7802734375,0.4501953125},{27,0.7822265625,0.376953125,0.9365234375,0.4501953125},{27,0.3134765625,0.4521484375,0.4677734375,0.525390625},{27,0.4697265625,0.4521484375,0.6240234375,0.525390625},{27,0.6259765625,0.4521484375,0.7802734375,0.525390625},{27,0.7822265625,0.4521484375,0.9365234375,0.525390625},{27,0.3134765625,0.52734375,0.4677734375,0.6005859375},{26,0.4697265625,0.326171875,0.6240234375,0.3994140625}},["idle"]={["intro"]={{26,0.4697265625,0.326171875,0.6240234375,0.3994140625},{27,0.3134765625,0.6025390625,0.4677734375,0.67578125},{27,0.3134765625,0.677734375,0.4677734375,0.7509765625},{27,0.3134765625,0.7529296875,0.4677734375,0.826171875},{27,0.3134765625,0.828125,0.4677734375,0.9013671875},{27,0.3134765625,0.9033203125,0.4677734375,0.9765625},{27,0.4697265625,0.52734375,0.6240234375,0.6005859375},{27,0.6259765625,0.52734375,0.7802734375,0.6005859375},{27,0.7822265625,0.52734375,0.9365234375,0.6005859375},{27,0.4697265625,0.6025390625,0.6240234375,0.67578125},{27,0.6259765625,0.6025390625,0.7802734375,0.67578125},{27,0.7822265625,0.6025390625,0.9365234375,0.67578125}},["hold"]={{27,0.7822265625,0.6025390625,0.9365234375,0.67578125},{27,0.4697265625,0.677734375,0.6240234375,0.7509765625},{27,0.4697265625,0.7529296875,0.6240234375,0.826171875},{27,0.4697265625,0.828125,0.6240234375,0.9013671875},{27,0.4697265625,0.9033203125,0.6240234375,0.9765625},{27,0.6259765625,0.677734375,0.7802734375,0.7509765625},{27,0.7822265625,0.677734375,0.9365234375,0.7509765625},{27,0.6259765625,0.7529296875,0.7802734375,0.826171875},{27,0.7822265625,0.7529296875,0.9365234375,0.826171875},{27,0.6259765625,0.828125,0.7802734375,0.9013671875},{27,0.6259765625,0.9033203125,0.7802734375,0.9765625},{27,0.7822265625,0.828125,0.9365234375,0.9013671875},{27,0.7822265625,0.9033203125,0.9365234375,0.9765625},{28,0.0009765625,0.0009765625,0.1552734375,0.07421875},{28,0.1572265625,0.0009765625,0.3115234375,0.07421875},{28,0.3134765625,0.0009765625,0.4677734375,0.07421875},{28,0.4697265625,0.0009765625,0.6240234375,0.07421875},{28,0.6259765625,0.0009765625,0.7802734375,0.07421875},{28,0.7822265625,0.0009765625,0.9365234375,0.07421875},{28,0.0009765625,0.076171875,0.1552734375,0.1494140625},{28,0.1572265625,0.076171875,0.3115234375,0.1494140625},{28,0.3134765625,0.076171875,0.4677734375,0.1494140625},{28,0.4697265625,0.076171875,0.6240234375,0.1494140625},{28,0.6259765625,0.076171875,0.7802734375,0.1494140625}},["ending"]={{27,0.7822265625,0.6025390625,0.9365234375,0.67578125},{28,0.7822265625,0.076171875,0.9365234375,0.1494140625},{28,0.0009765625,0.1513671875,0.1552734375,0.224609375},{28,0.1572265625,0.1513671875,0.3115234375,0.224609375},{28,0.3134765625,0.1513671875,0.4677734375,0.224609375},{28,0.4697265625,0.1513671875,0.6240234375,0.224609375},{28,0.6259765625,0.1513671875,0.7802734375,0.224609375},{28,0.7822265625,0.1513671875,0.9365234375,0.224609375},{28,0.0009765625,0.2265625,0.1552734375,0.2998046875},{28,0.0009765625,0.3017578125,0.1552734375,0.375},{28,0.0009765625,0.376953125,0.1552734375,0.4501953125},{26,0.4697265625,0.326171875,0.6240234375,0.3994140625}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{19,0.8125,0.5107421875,0.990234375,0.640625},{16,0.8017578125,0.765625,0.9794921875,0.8955078125},{7,0.7626953125,0.771484375,0.9404296875,0.9013671875},{8,0.7626953125,0.771484375,0.9404296875,0.9013671875},{9,0.7626953125,0.771484375,0.9404296875,0.9013671875},{10,0.7626953125,0.771484375,0.9404296875,0.9013671875},{11,0.7626953125,0.771484375,0.9404296875,0.9013671875},{12,0.7626953125,0.771484375,0.9404296875,0.9013671875},{13,0.7626953125,0.771484375,0.9404296875,0.9013671875},{14,0.7626953125,0.771484375,0.9404296875,0.9013671875},{15,0.58203125,0.771484375,0.759765625,0.9013671875},{15,0.76171875,0.771484375,0.939453125,0.9013671875}},["hold"]={{15,0.76171875,0.771484375,0.939453125,0.9013671875},{16,0.0009765625,0.771484375,0.1787109375,0.9013671875},{16,0.1806640625,0.771484375,0.3583984375,0.9013671875},{16,0.3603515625,0.771484375,0.5380859375,0.9013671875},{16,0.5400390625,0.771484375,0.7177734375,0.9013671875},{24,0.4638671875,0.4677734375,0.6416015625,0.59765625},{24,0.6435546875,0.4677734375,0.8212890625,0.59765625},{24,0.4638671875,0.599609375,0.6416015625,0.7294921875},{24,0.4638671875,0.7314453125,0.6416015625,0.861328125},{24,0.4638671875,0.86328125,0.6416015625,0.9931640625},{24,0.6435546875,0.599609375,0.8212890625,0.7294921875},{24,0.6435546875,0.7314453125,0.8212890625,0.861328125},{24,0.6435546875,0.86328125,0.8212890625,0.9931640625},{25,0.0009765625,0.0009765625,0.1787109375,0.130859375},{25,0.1806640625,0.0009765625,0.3583984375,0.130859375},{25,0.3603515625,0.0009765625,0.5380859375,0.130859375},{25,0.5400390625,0.0009765625,0.7177734375,0.130859375},{25,0.7197265625,0.0009765625,0.8974609375,0.130859375},{25,0.0009765625,0.1328125,0.1787109375,0.2626953125},{25,0.0009765625,0.2646484375,0.1787109375,0.39453125},{25,0.0009765625,0.396484375,0.1787109375,0.5263671875},{25,0.0009765625,0.5283203125,0.1787109375,0.658203125},{25,0.0009765625,0.66015625,0.1787109375,0.7900390625},{25,0.0009765625,0.7919921875,0.1787109375,0.921875}},["ending"]={{15,0.76171875,0.771484375,0.939453125,0.9013671875},{15,0.58203125,0.771484375,0.759765625,0.9013671875},{14,0.7626953125,0.771484375,0.9404296875,0.9013671875},{13,0.7626953125,0.771484375,0.9404296875,0.9013671875},{12,0.7626953125,0.771484375,0.9404296875,0.9013671875},{11,0.7626953125,0.771484375,0.9404296875,0.9013671875},{10,0.7626953125,0.771484375,0.9404296875,0.9013671875},{9,0.7626953125,0.771484375,0.9404296875,0.9013671875},{8,0.7626953125,0.771484375,0.9404296875,0.9013671875},{7,0.7626953125,0.771484375,0.9404296875,0.9013671875},{16,0.8017578125,0.765625,0.9794921875,0.8955078125},{19,0.8125,0.5107421875,0.990234375,0.640625}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{1,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{1,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{1,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{1,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{1,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{2,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{2,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{2,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{2,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{2,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{2,0.6611328125,0.4599609375,0.9892578125,0.9169921875}},["hold"]={{2,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{3,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{3,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{3,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{3,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{3,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{3,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{4,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{4,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{4,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{4,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{4,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{4,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{5,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{5,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{5,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{5,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{5,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{5,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{6,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{6,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{6,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{6,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{6,0.3310546875,0.4599609375,0.6591796875,0.9169921875}},["ending"]={{2,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{2,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{2,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{2,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{2,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{2,0.0009765625,0.0009765625,0.3291015625,0.4580078125},{1,0.6611328125,0.4599609375,0.9892578125,0.9169921875},{1,0.3310546875,0.4599609375,0.6591796875,0.9169921875},{1,0.6611328125,0.0009765625,0.9892578125,0.4580078125},{1,0.3310546875,0.0009765625,0.6591796875,0.4580078125},{1,0.0009765625,0.4599609375,0.3291015625,0.9169921875},{1,0.0009765625,0.0009765625,0.3291015625,0.4580078125}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{16,0.8017578125,0.0009765625,0.9931640625,0.25390625},{16,0.8017578125,0.255859375,0.9931640625,0.5087890625},{16,0.8017578125,0.5107421875,0.9931640625,0.763671875},{17,0.0009765625,0.2578125,0.1923828125,0.5107421875},{17,0.0009765625,0.5126953125,0.1923828125,0.765625},{17,0.1943359375,0.2578125,0.3857421875,0.5107421875},{17,0.201171875,0.0009765625,0.392578125,0.25390625},{17,0.1943359375,0.5126953125,0.3857421875,0.765625},{17,0.39453125,0.0009765625,0.5859375,0.25390625},{17,0.587890625,0.0009765625,0.779296875,0.25390625},{17,0.78125,0.0009765625,0.97265625,0.25390625},{17,0.3876953125,0.255859375,0.5791015625,0.5087890625}},["hold"]={{17,0.3876953125,0.255859375,0.5791015625,0.5087890625},{17,0.5810546875,0.255859375,0.7724609375,0.5087890625},{17,0.7744140625,0.255859375,0.9658203125,0.5087890625},{17,0.3876953125,0.5107421875,0.5791015625,0.763671875},{17,0.5810546875,0.5107421875,0.7724609375,0.763671875},{17,0.7744140625,0.5107421875,0.9658203125,0.763671875},{18,0.0009765625,0.0009765625,0.1923828125,0.25390625},{18,0.0009765625,0.255859375,0.1923828125,0.5087890625},{18,0.0009765625,0.5107421875,0.1923828125,0.763671875},{18,0.1943359375,0.0009765625,0.3857421875,0.25390625},{18,0.3876953125,0.0009765625,0.5791015625,0.25390625},{18,0.5810546875,0.0009765625,0.7724609375,0.25390625},{18,0.7744140625,0.0009765625,0.9658203125,0.25390625},{18,0.1943359375,0.255859375,0.3857421875,0.5087890625},{18,0.1943359375,0.5107421875,0.3857421875,0.763671875},{18,0.3876953125,0.255859375,0.5791015625,0.5087890625},{18,0.5810546875,0.255859375,0.7724609375,0.5087890625},{18,0.7744140625,0.255859375,0.9658203125,0.5087890625},{18,0.3876953125,0.5107421875,0.5791015625,0.763671875},{18,0.5810546875,0.5107421875,0.7724609375,0.763671875},{18,0.7744140625,0.5107421875,0.9658203125,0.763671875},{19,0.0009765625,0.0009765625,0.1923828125,0.25390625},{19,0.0009765625,0.255859375,0.1923828125,0.5087890625},{19,0.0009765625,0.5107421875,0.1923828125,0.763671875}},["ending"]={{17,0.3876953125,0.255859375,0.5791015625,0.5087890625},{19,0.1943359375,0.0009765625,0.3857421875,0.25390625},{19,0.3876953125,0.0009765625,0.5791015625,0.25390625},{19,0.5810546875,0.0009765625,0.7724609375,0.25390625},{19,0.7744140625,0.0009765625,0.9658203125,0.25390625},{19,0.1943359375,0.255859375,0.3857421875,0.5087890625},{19,0.1943359375,0.5107421875,0.3857421875,0.763671875},{19,0.3876953125,0.255859375,0.5791015625,0.5087890625},{19,0.5810546875,0.255859375,0.7724609375,0.5087890625},{19,0.7744140625,0.255859375,0.9658203125,0.5087890625},{19,0.3876953125,0.5107421875,0.5791015625,0.763671875},{16,0.8017578125,0.0009765625,0.9931640625,0.25390625}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{7,0.7626953125,0.0009765625,0.9609375,0.255859375},{7,0.7626953125,0.2578125,0.9609375,0.5126953125},{7,0.7626953125,0.5146484375,0.9609375,0.76953125},{8,0.7626953125,0.0009765625,0.9609375,0.255859375},{8,0.7626953125,0.2578125,0.9609375,0.5126953125},{8,0.7626953125,0.5146484375,0.9609375,0.76953125},{9,0.7626953125,0.0009765625,0.9609375,0.255859375},{9,0.7626953125,0.2578125,0.9609375,0.5126953125},{9,0.7626953125,0.5146484375,0.9609375,0.76953125},{10,0.7626953125,0.0009765625,0.9609375,0.255859375},{10,0.7626953125,0.2578125,0.9609375,0.5126953125},{10,0.7626953125,0.5146484375,0.9609375,0.76953125}},["hold"]={{10,0.7626953125,0.5146484375,0.9609375,0.76953125},{11,0.7626953125,0.0009765625,0.9609375,0.255859375},{11,0.7626953125,0.2578125,0.9609375,0.5126953125},{11,0.7626953125,0.5146484375,0.9609375,0.76953125},{12,0.7626953125,0.0009765625,0.9609375,0.255859375},{12,0.7626953125,0.2578125,0.9609375,0.5126953125},{12,0.7626953125,0.5146484375,0.9609375,0.76953125},{13,0.7626953125,0.0009765625,0.9609375,0.255859375},{13,0.7626953125,0.2578125,0.9609375,0.5126953125},{13,0.7626953125,0.5146484375,0.9609375,0.76953125},{14,0.7626953125,0.0009765625,0.9609375,0.255859375},{14,0.7626953125,0.2578125,0.9609375,0.5126953125},{14,0.7626953125,0.5146484375,0.9609375,0.76953125},{15,0.7626953125,0.0009765625,0.9609375,0.255859375},{15,0.7626953125,0.2578125,0.9609375,0.5126953125},{6,0.6611328125,0.4599609375,0.859375,0.71484375},{6,0.6611328125,0.716796875,0.859375,0.9716796875},{15,0.3818359375,0.4482421875,0.580078125,0.703125},{15,0.3818359375,0.705078125,0.580078125,0.9599609375},{15,0.58203125,0.5146484375,0.7802734375,0.76953125},{15,0.7822265625,0.5146484375,0.98046875,0.76953125},{16,0.0009765625,0.0009765625,0.19921875,0.255859375},{16,0.0009765625,0.2578125,0.19921875,0.5126953125},{16,0.0009765625,0.5146484375,0.19921875,0.76953125}},["ending"]={{10,0.7626953125,0.5146484375,0.9609375,0.76953125},{16,0.201171875,0.0009765625,0.3994140625,0.255859375},{16,0.4013671875,0.0009765625,0.599609375,0.255859375},{16,0.6015625,0.0009765625,0.7998046875,0.255859375},{16,0.201171875,0.2578125,0.3994140625,0.5126953125},{16,0.201171875,0.5146484375,0.3994140625,0.76953125},{16,0.4013671875,0.2578125,0.599609375,0.5126953125},{16,0.6015625,0.2578125,0.7998046875,0.5126953125},{16,0.4013671875,0.5146484375,0.599609375,0.76953125},{16,0.6015625,0.5146484375,0.7998046875,0.76953125},{17,0.0009765625,0.0009765625,0.19921875,0.255859375},{7,0.7626953125,0.0009765625,0.9609375,0.255859375}},["pages"]={"StudioDruidRestorationChannelPlusSize576Page1.tga","StudioDruidRestorationChannelPlusSize576Page2.tga","StudioDruidRestorationChannelPlusSize576Page3.tga","StudioDruidRestorationChannelPlusSize576Page4.tga","StudioDruidRestorationChannelPlusSize576Page5.tga","StudioDruidRestorationChannelPlusSize576Page6.tga","StudioDruidRestorationChannelPlusSize576Page7.tga","StudioDruidRestorationChannelPlusSize576Page8.tga","StudioDruidRestorationChannelPlusSize576Page9.tga","StudioDruidRestorationChannelPlusSize576Page10.tga","StudioDruidRestorationChannelPlusSize576Page11.tga","StudioDruidRestorationChannelPlusSize576Page12.tga","StudioDruidRestorationChannelPlusSize576Page13.tga","StudioDruidRestorationChannelPlusSize576Page14.tga","StudioDruidRestorationChannelPlusSize576Page15.tga","StudioDruidRestorationChannelPlusSize576Page16.tga","StudioDruidRestorationChannelPlusSize576Page17.tga","StudioDruidRestorationChannelPlusSize576Page18.tga","StudioDruidRestorationChannelPlusSize576Page19.tga","StudioDruidRestorationChannelPlusSize576Page20.tga","StudioDruidRestorationChannelPlusSize576Page21.tga","StudioDruidRestorationChannelPlusSize576Page22.tga","StudioDruidRestorationChannelPlusSize576Page23.tga","StudioDruidRestorationChannelPlusSize576Page24.tga","StudioDruidRestorationChannelPlusSize576Page25.tga","StudioDruidRestorationChannelPlusSize576Page26.tga","StudioDruidRestorationChannelPlusSize576Page27.tga","StudioDruidRestorationChannelPlusSize576Page28.tga"}}},[660]={["boughs"]={["mode"]="replace",["fps"]=24,["rect"]={0.1696969696969697,0.17727272727272728,0.6742424242424242,0.5943181818181819},["intro"]={{18,0.37890625,0.0009765625,0.8134765625,0.51171875},{19,0.0009765625,0.0009765625,0.435546875,0.51171875},{19,0.4375,0.0009765625,0.8720703125,0.51171875},{20,0.0009765625,0.0009765625,0.435546875,0.51171875},{20,0.4375,0.0009765625,0.8720703125,0.51171875},{21,0.0009765625,0.0009765625,0.435546875,0.51171875},{21,0.4375,0.0009765625,0.8720703125,0.51171875},{22,0.0009765625,0.0009765625,0.435546875,0.51171875},{22,0.4375,0.0009765625,0.8720703125,0.51171875},{23,0.0009765625,0.0009765625,0.435546875,0.51171875},{23,0.4375,0.0009765625,0.8720703125,0.51171875},{24,0.0009765625,0.0009765625,0.435546875,0.51171875}},["hold"]={{24,0.0009765625,0.0009765625,0.435546875,0.51171875},{24,0.4375,0.0009765625,0.8720703125,0.51171875},{25,0.0009765625,0.0009765625,0.435546875,0.51171875},{25,0.4375,0.0009765625,0.8720703125,0.51171875},{26,0.0009765625,0.0009765625,0.435546875,0.51171875},{26,0.4375,0.0009765625,0.8720703125,0.51171875},{27,0.0009765625,0.0009765625,0.435546875,0.51171875},{27,0.4375,0.0009765625,0.8720703125,0.51171875},{28,0.0009765625,0.0009765625,0.435546875,0.51171875},{28,0.4375,0.0009765625,0.8720703125,0.51171875},{29,0.0009765625,0.0009765625,0.435546875,0.51171875},{29,0.4375,0.0009765625,0.8720703125,0.51171875},{30,0.0009765625,0.0009765625,0.435546875,0.51171875},{30,0.4375,0.0009765625,0.8720703125,0.51171875},{31,0.0009765625,0.0009765625,0.435546875,0.51171875},{31,0.4375,0.0009765625,0.8720703125,0.51171875},{32,0.0009765625,0.0009765625,0.435546875,0.51171875},{32,0.4375,0.0009765625,0.8720703125,0.51171875},{33,0.0009765625,0.0009765625,0.435546875,0.51171875},{33,0.4375,0.0009765625,0.8720703125,0.51171875},{34,0.0009765625,0.0009765625,0.435546875,0.51171875},{34,0.4375,0.0009765625,0.8720703125,0.51171875},{35,0.0009765625,0.0009765625,0.435546875,0.51171875},{35,0.4375,0.0009765625,0.8720703125,0.51171875}},["ending"]={{24,0.0009765625,0.0009765625,0.435546875,0.51171875},{23,0.4375,0.0009765625,0.8720703125,0.51171875},{23,0.0009765625,0.0009765625,0.435546875,0.51171875},{22,0.4375,0.0009765625,0.8720703125,0.51171875},{22,0.0009765625,0.0009765625,0.435546875,0.51171875},{21,0.4375,0.0009765625,0.8720703125,0.51171875},{21,0.0009765625,0.0009765625,0.435546875,0.51171875},{20,0.4375,0.0009765625,0.8720703125,0.51171875},{20,0.0009765625,0.0009765625,0.435546875,0.51171875},{19,0.4375,0.0009765625,0.8720703125,0.51171875},{19,0.0009765625,0.0009765625,0.435546875,0.51171875},{18,0.37890625,0.0009765625,0.8134765625,0.51171875}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}},["treant"]={["mode"]="replace",["fps"]=24,["rect"]={0.3939393939393939,0.5636363636363636,0.22575757575757577,0.23295454545454544},["intro"]={{18,0.0009765625,0.79296875,0.146484375,0.9931640625},{18,0.1484375,0.79296875,0.2939453125,0.9931640625},{18,0.2958984375,0.79296875,0.44140625,0.9931640625},{18,0.443359375,0.79296875,0.5888671875,0.9931640625},{18,0.5908203125,0.7802734375,0.736328125,0.98046875},{19,0.0009765625,0.7802734375,0.146484375,0.98046875},{19,0.1484375,0.7802734375,0.2939453125,0.98046875},{19,0.2958984375,0.7802734375,0.44140625,0.98046875},{19,0.443359375,0.7802734375,0.5888671875,0.98046875},{19,0.5908203125,0.7802734375,0.736328125,0.98046875},{20,0.0009765625,0.7802734375,0.146484375,0.98046875},{20,0.1484375,0.7802734375,0.2939453125,0.98046875}},["hold"]={{20,0.1484375,0.7802734375,0.2939453125,0.98046875},{20,0.2958984375,0.7802734375,0.44140625,0.98046875},{20,0.443359375,0.7802734375,0.5888671875,0.98046875},{20,0.5908203125,0.7802734375,0.736328125,0.98046875},{21,0.0009765625,0.7802734375,0.146484375,0.98046875},{21,0.1484375,0.7802734375,0.2939453125,0.98046875},{21,0.2958984375,0.7802734375,0.44140625,0.98046875},{21,0.443359375,0.7802734375,0.5888671875,0.98046875},{21,0.5908203125,0.7802734375,0.736328125,0.98046875},{22,0.0009765625,0.7802734375,0.146484375,0.98046875},{22,0.1484375,0.7802734375,0.2939453125,0.98046875},{22,0.2958984375,0.7802734375,0.44140625,0.98046875},{22,0.443359375,0.7802734375,0.5888671875,0.98046875},{22,0.5908203125,0.7802734375,0.736328125,0.98046875},{23,0.0009765625,0.7802734375,0.146484375,0.98046875},{23,0.1484375,0.7802734375,0.2939453125,0.98046875},{23,0.2958984375,0.7802734375,0.44140625,0.98046875},{23,0.443359375,0.7802734375,0.5888671875,0.98046875},{23,0.5908203125,0.7802734375,0.736328125,0.98046875},{24,0.0009765625,0.7802734375,0.146484375,0.98046875},{24,0.1484375,0.7802734375,0.2939453125,0.98046875},{24,0.2958984375,0.7802734375,0.44140625,0.98046875},{24,0.443359375,0.7802734375,0.5888671875,0.98046875},{24,0.5908203125,0.7802734375,0.736328125,0.98046875}},["ending"]={{20,0.1484375,0.7802734375,0.2939453125,0.98046875},{25,0.0009765625,0.7802734375,0.146484375,0.98046875},{25,0.1484375,0.7802734375,0.2939453125,0.98046875},{25,0.2958984375,0.7802734375,0.44140625,0.98046875},{25,0.443359375,0.7802734375,0.5888671875,0.98046875},{25,0.5908203125,0.7802734375,0.736328125,0.98046875},{26,0.0009765625,0.7802734375,0.146484375,0.98046875},{26,0.1484375,0.7802734375,0.2939453125,0.98046875},{26,0.2958984375,0.7802734375,0.44140625,0.98046875},{26,0.443359375,0.7802734375,0.5888671875,0.98046875},{26,0.5908203125,0.7802734375,0.736328125,0.98046875},{18,0.0009765625,0.79296875,0.146484375,0.9931640625}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}},["roots"]={["mode"]="replace",["fps"]=24,["rect"]={0.30757575757575756,0.6295454545454545,0.4075757575757576,0.3079545454545455},["intro"]={{15,0.0009765625,0.5888671875,0.263671875,0.853515625},{15,0.265625,0.5888671875,0.5283203125,0.853515625},{15,0.5302734375,0.5888671875,0.79296875,0.853515625},{16,0.0009765625,0.5888671875,0.263671875,0.853515625},{16,0.265625,0.5888671875,0.5283203125,0.853515625},{16,0.5302734375,0.5888671875,0.79296875,0.853515625},{17,0.0009765625,0.5888671875,0.263671875,0.853515625},{17,0.265625,0.5888671875,0.5283203125,0.853515625},{17,0.5302734375,0.5888671875,0.79296875,0.853515625},{18,0.0009765625,0.5263671875,0.263671875,0.791015625},{18,0.265625,0.5263671875,0.5283203125,0.791015625},{18,0.5302734375,0.513671875,0.79296875,0.7783203125}},["hold"]={{18,0.5302734375,0.513671875,0.79296875,0.7783203125},{19,0.0009765625,0.513671875,0.263671875,0.7783203125},{19,0.265625,0.513671875,0.5283203125,0.7783203125},{19,0.5302734375,0.513671875,0.79296875,0.7783203125},{20,0.0009765625,0.513671875,0.263671875,0.7783203125},{20,0.265625,0.513671875,0.5283203125,0.7783203125},{20,0.5302734375,0.513671875,0.79296875,0.7783203125},{21,0.0009765625,0.513671875,0.263671875,0.7783203125},{21,0.265625,0.513671875,0.5283203125,0.7783203125},{21,0.5302734375,0.513671875,0.79296875,0.7783203125},{22,0.0009765625,0.513671875,0.263671875,0.7783203125},{22,0.265625,0.513671875,0.5283203125,0.7783203125},{22,0.5302734375,0.513671875,0.79296875,0.7783203125},{23,0.0009765625,0.513671875,0.263671875,0.7783203125},{23,0.265625,0.513671875,0.5283203125,0.7783203125},{23,0.5302734375,0.513671875,0.79296875,0.7783203125},{24,0.0009765625,0.513671875,0.263671875,0.7783203125},{24,0.265625,0.513671875,0.5283203125,0.7783203125},{24,0.5302734375,0.513671875,0.79296875,0.7783203125},{25,0.0009765625,0.513671875,0.263671875,0.7783203125},{25,0.265625,0.513671875,0.5283203125,0.7783203125},{25,0.5302734375,0.513671875,0.79296875,0.7783203125},{26,0.0009765625,0.513671875,0.263671875,0.7783203125},{26,0.265625,0.513671875,0.5283203125,0.7783203125}},["ending"]={{18,0.5302734375,0.513671875,0.79296875,0.7783203125},{26,0.5302734375,0.513671875,0.79296875,0.7783203125},{27,0.0009765625,0.513671875,0.263671875,0.7783203125},{27,0.265625,0.513671875,0.5283203125,0.7783203125},{27,0.5302734375,0.513671875,0.79296875,0.7783203125},{28,0.0009765625,0.513671875,0.263671875,0.7783203125},{28,0.265625,0.513671875,0.5283203125,0.7783203125},{28,0.5302734375,0.513671875,0.79296875,0.7783203125},{29,0.0009765625,0.513671875,0.263671875,0.7783203125},{29,0.265625,0.513671875,0.5283203125,0.7783203125},{29,0.5302734375,0.513671875,0.79296875,0.7783203125},{15,0.0009765625,0.5888671875,0.263671875,0.853515625}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"},["matched"]={["layer"]="treant",["intro"]={{15,0.0009765625,0.5888671875,0.263671875,0.853515625},{30,0.0009765625,0.513671875,0.263671875,0.7783203125},{30,0.265625,0.513671875,0.5283203125,0.7783203125},{30,0.5302734375,0.513671875,0.79296875,0.7783203125},{31,0.0009765625,0.513671875,0.263671875,0.7783203125},{31,0.265625,0.513671875,0.5283203125,0.7783203125},{31,0.5302734375,0.513671875,0.79296875,0.7783203125},{32,0.0009765625,0.513671875,0.263671875,0.7783203125},{32,0.265625,0.513671875,0.5283203125,0.7783203125},{32,0.5302734375,0.513671875,0.79296875,0.7783203125},{33,0.0009765625,0.513671875,0.263671875,0.7783203125},{33,0.265625,0.513671875,0.5283203125,0.7783203125}},["hold"]={{33,0.265625,0.513671875,0.5283203125,0.7783203125},{33,0.5302734375,0.513671875,0.79296875,0.7783203125},{34,0.0009765625,0.513671875,0.263671875,0.7783203125},{34,0.265625,0.513671875,0.5283203125,0.7783203125},{34,0.5302734375,0.513671875,0.79296875,0.7783203125},{35,0.0009765625,0.513671875,0.263671875,0.7783203125},{35,0.265625,0.513671875,0.5283203125,0.7783203125},{35,0.5302734375,0.513671875,0.79296875,0.7783203125},{36,0.0009765625,0.0009765625,0.263671875,0.265625},{36,0.0009765625,0.267578125,0.263671875,0.5322265625},{36,0.0009765625,0.5341796875,0.263671875,0.798828125},{36,0.265625,0.0009765625,0.5283203125,0.265625},{36,0.5302734375,0.0009765625,0.79296875,0.265625},{36,0.265625,0.267578125,0.5283203125,0.5322265625},{36,0.265625,0.5341796875,0.5283203125,0.798828125},{36,0.5302734375,0.267578125,0.79296875,0.5322265625},{36,0.5302734375,0.5341796875,0.79296875,0.798828125},{37,0.0009765625,0.0009765625,0.263671875,0.265625},{37,0.0009765625,0.267578125,0.263671875,0.5322265625},{37,0.0009765625,0.5341796875,0.263671875,0.798828125},{37,0.265625,0.0009765625,0.5283203125,0.265625},{37,0.5302734375,0.0009765625,0.79296875,0.265625},{37,0.265625,0.267578125,0.5283203125,0.5322265625},{37,0.265625,0.5341796875,0.5283203125,0.798828125}},["ending"]={{33,0.265625,0.513671875,0.5283203125,0.7783203125},{37,0.5302734375,0.267578125,0.79296875,0.5322265625},{37,0.5302734375,0.5341796875,0.79296875,0.798828125},{38,0.0009765625,0.0009765625,0.263671875,0.265625},{38,0.0009765625,0.267578125,0.263671875,0.5322265625},{38,0.0009765625,0.5341796875,0.263671875,0.798828125},{38,0.265625,0.0009765625,0.5283203125,0.265625},{38,0.5302734375,0.0009765625,0.79296875,0.265625},{38,0.265625,0.267578125,0.5283203125,0.5322265625},{38,0.265625,0.5341796875,0.5283203125,0.798828125},{38,0.5302734375,0.267578125,0.79296875,0.5322265625},{15,0.0009765625,0.5888671875,0.263671875,0.853515625}}}},["leftSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.13787878787878788,0.5625,0.27424242424242423,0.09659090909090909},["intro"]={{18,0.8154296875,0.0009765625,0.9921875,0.083984375},{18,0.8154296875,0.0859375,0.9921875,0.1689453125},{18,0.8154296875,0.1708984375,0.9921875,0.25390625},{18,0.8154296875,0.255859375,0.9921875,0.3388671875},{18,0.8154296875,0.3408203125,0.9921875,0.423828125},{18,0.8154296875,0.42578125,0.9921875,0.5087890625},{15,0.0009765625,0.8896484375,0.177734375,0.97265625},{15,0.1796875,0.8896484375,0.3564453125,0.97265625},{15,0.3583984375,0.8896484375,0.53515625,0.97265625},{15,0.537109375,0.8896484375,0.7138671875,0.97265625},{15,0.7158203125,0.8896484375,0.892578125,0.97265625},{16,0.0009765625,0.8896484375,0.177734375,0.97265625}},["hold"]={{16,0.0009765625,0.8896484375,0.177734375,0.97265625},{16,0.1796875,0.8896484375,0.3564453125,0.97265625},{16,0.3583984375,0.8896484375,0.53515625,0.97265625},{16,0.537109375,0.8896484375,0.7138671875,0.97265625},{16,0.7158203125,0.8896484375,0.892578125,0.97265625},{17,0.0009765625,0.8896484375,0.177734375,0.97265625},{17,0.1796875,0.8896484375,0.3564453125,0.97265625},{17,0.3583984375,0.8896484375,0.53515625,0.97265625},{17,0.537109375,0.8896484375,0.7138671875,0.97265625},{17,0.7158203125,0.8896484375,0.892578125,0.97265625},{32,0.794921875,0.6640625,0.9716796875,0.7470703125},{32,0.794921875,0.7490234375,0.9716796875,0.83203125},{33,0.794921875,0.513671875,0.9716796875,0.5966796875},{33,0.794921875,0.5986328125,0.9716796875,0.681640625},{33,0.794921875,0.68359375,0.9716796875,0.7666015625},{33,0.794921875,0.7685546875,0.9716796875,0.8515625},{34,0.794921875,0.513671875,0.9716796875,0.5966796875},{34,0.794921875,0.5986328125,0.9716796875,0.681640625},{34,0.794921875,0.68359375,0.9716796875,0.7666015625},{34,0.794921875,0.7685546875,0.9716796875,0.8515625},{35,0.794921875,0.513671875,0.9716796875,0.5966796875},{35,0.794921875,0.5986328125,0.9716796875,0.681640625},{35,0.794921875,0.68359375,0.9716796875,0.7666015625},{35,0.794921875,0.7685546875,0.9716796875,0.8515625}},["ending"]={{16,0.0009765625,0.8896484375,0.177734375,0.97265625},{15,0.7158203125,0.8896484375,0.892578125,0.97265625},{15,0.537109375,0.8896484375,0.7138671875,0.97265625},{15,0.3583984375,0.8896484375,0.53515625,0.97265625},{15,0.1796875,0.8896484375,0.3564453125,0.97265625},{15,0.0009765625,0.8896484375,0.177734375,0.97265625},{18,0.8154296875,0.42578125,0.9921875,0.5087890625},{18,0.8154296875,0.3408203125,0.9921875,0.423828125},{18,0.8154296875,0.255859375,0.9921875,0.3388671875},{18,0.8154296875,0.1708984375,0.9921875,0.25390625},{18,0.8154296875,0.0859375,0.9921875,0.1689453125},{18,0.8154296875,0.0009765625,0.9921875,0.083984375}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"},["matched"]={["layer"]="leftBanner",["intro"]={{18,0.8154296875,0.0009765625,0.9921875,0.083984375},{36,0.794921875,0.0009765625,0.9716796875,0.083984375},{36,0.794921875,0.0859375,0.9716796875,0.1689453125},{36,0.794921875,0.1708984375,0.9716796875,0.25390625},{36,0.794921875,0.255859375,0.9716796875,0.3388671875},{36,0.794921875,0.3408203125,0.9716796875,0.423828125},{36,0.794921875,0.42578125,0.9716796875,0.5087890625},{36,0.794921875,0.5107421875,0.9716796875,0.59375},{36,0.794921875,0.595703125,0.9716796875,0.6787109375},{36,0.794921875,0.6806640625,0.9716796875,0.763671875},{36,0.794921875,0.765625,0.9716796875,0.8486328125},{37,0.794921875,0.0009765625,0.9716796875,0.083984375}},["hold"]={{37,0.794921875,0.0009765625,0.9716796875,0.083984375},{37,0.794921875,0.0859375,0.9716796875,0.1689453125},{37,0.794921875,0.1708984375,0.9716796875,0.25390625},{37,0.794921875,0.255859375,0.9716796875,0.3388671875},{37,0.794921875,0.3408203125,0.9716796875,0.423828125},{37,0.794921875,0.42578125,0.9716796875,0.5087890625},{37,0.794921875,0.5107421875,0.9716796875,0.59375},{37,0.794921875,0.595703125,0.9716796875,0.6787109375},{37,0.794921875,0.6806640625,0.9716796875,0.763671875},{37,0.794921875,0.765625,0.9716796875,0.8486328125},{38,0.794921875,0.0009765625,0.9716796875,0.083984375},{38,0.794921875,0.0859375,0.9716796875,0.1689453125},{38,0.794921875,0.1708984375,0.9716796875,0.25390625},{38,0.794921875,0.255859375,0.9716796875,0.3388671875},{38,0.794921875,0.3408203125,0.9716796875,0.423828125},{38,0.794921875,0.42578125,0.9716796875,0.5087890625},{38,0.794921875,0.5107421875,0.9716796875,0.59375},{1,0.0009765625,0.8828125,0.177734375,0.9658203125},{1,0.1796875,0.8828125,0.3564453125,0.9658203125},{1,0.3583984375,0.8828125,0.53515625,0.9658203125},{1,0.537109375,0.8828125,0.7138671875,0.9658203125},{1,0.7158203125,0.8828125,0.892578125,0.9658203125},{2,0.0009765625,0.8828125,0.177734375,0.9658203125},{2,0.1796875,0.8828125,0.3564453125,0.9658203125}},["ending"]={{37,0.794921875,0.0009765625,0.9716796875,0.083984375},{2,0.3583984375,0.8828125,0.53515625,0.9658203125},{2,0.537109375,0.8828125,0.7138671875,0.9658203125},{2,0.7158203125,0.8828125,0.892578125,0.9658203125},{3,0.0009765625,0.8828125,0.177734375,0.9658203125},{3,0.1796875,0.8828125,0.3564453125,0.9658203125},{3,0.3583984375,0.8828125,0.53515625,0.9658203125},{3,0.537109375,0.880859375,0.7138671875,0.9638671875},{3,0.7158203125,0.880859375,0.892578125,0.9638671875},{4,0.0009765625,0.880859375,0.177734375,0.9638671875},{4,0.1796875,0.880859375,0.3564453125,0.9638671875},{18,0.8154296875,0.0009765625,0.9921875,0.083984375}},["idle"]={["intro"]={{18,0.8154296875,0.0009765625,0.9921875,0.083984375},{4,0.3583984375,0.880859375,0.53515625,0.9638671875},{4,0.537109375,0.880859375,0.7138671875,0.9638671875},{4,0.7158203125,0.880859375,0.892578125,0.9638671875},{5,0.0009765625,0.880859375,0.177734375,0.9638671875},{5,0.1796875,0.880859375,0.3564453125,0.9638671875},{5,0.3583984375,0.880859375,0.53515625,0.9638671875},{5,0.537109375,0.880859375,0.7138671875,0.9638671875},{5,0.7158203125,0.880859375,0.892578125,0.9638671875},{6,0.0009765625,0.880859375,0.177734375,0.9638671875},{6,0.1796875,0.880859375,0.3564453125,0.9638671875},{6,0.3583984375,0.880859375,0.53515625,0.9638671875}},["hold"]={{6,0.3583984375,0.880859375,0.53515625,0.9638671875},{6,0.537109375,0.880859375,0.7138671875,0.9638671875},{6,0.7158203125,0.880859375,0.892578125,0.9638671875},{7,0.0009765625,0.880859375,0.177734375,0.9638671875},{7,0.1796875,0.880859375,0.3564453125,0.9638671875},{7,0.3583984375,0.880859375,0.53515625,0.9638671875},{7,0.537109375,0.880859375,0.7138671875,0.9638671875},{7,0.7158203125,0.880859375,0.892578125,0.9638671875},{8,0.0009765625,0.880859375,0.177734375,0.9638671875},{8,0.1796875,0.880859375,0.3564453125,0.9638671875},{8,0.3583984375,0.880859375,0.53515625,0.9638671875},{8,0.537109375,0.880859375,0.7138671875,0.9638671875},{8,0.7158203125,0.880859375,0.892578125,0.9638671875},{9,0.0009765625,0.880859375,0.177734375,0.9638671875},{9,0.1796875,0.880859375,0.3564453125,0.9638671875},{9,0.3583984375,0.880859375,0.53515625,0.9638671875},{9,0.537109375,0.880859375,0.7138671875,0.9638671875},{9,0.7158203125,0.880859375,0.892578125,0.9638671875},{10,0.0009765625,0.880859375,0.177734375,0.9638671875},{10,0.1796875,0.880859375,0.3564453125,0.9638671875},{10,0.3583984375,0.880859375,0.53515625,0.9638671875},{10,0.537109375,0.880859375,0.7138671875,0.9638671875},{10,0.7158203125,0.880859375,0.892578125,0.9638671875},{11,0.0009765625,0.880859375,0.177734375,0.9638671875}},["ending"]={{6,0.3583984375,0.880859375,0.53515625,0.9638671875},{11,0.1796875,0.880859375,0.3564453125,0.9638671875},{11,0.3583984375,0.880859375,0.53515625,0.9638671875},{11,0.537109375,0.880859375,0.7138671875,0.9638671875},{11,0.7158203125,0.880859375,0.892578125,0.9638671875},{12,0.0009765625,0.880859375,0.177734375,0.9638671875},{12,0.1796875,0.880859375,0.3564453125,0.9638671875},{12,0.3583984375,0.880859375,0.53515625,0.9638671875},{12,0.537109375,0.880859375,0.7138671875,0.9638671875},{12,0.7158203125,0.880859375,0.892578125,0.9638671875},{13,0.0009765625,0.880859375,0.177734375,0.9638671875},{18,0.8154296875,0.0009765625,0.9921875,0.083984375}}}}},["rightSlats"]={["mode"]="replace",["fps"]=24,["rect"]={0.5893939393939394,0.5625,0.27424242424242423,0.09772727272727273},["intro"]={{13,0.1796875,0.880859375,0.3564453125,0.96484375},{13,0.3583984375,0.880859375,0.53515625,0.96484375},{13,0.537109375,0.880859375,0.7138671875,0.96484375},{13,0.7158203125,0.880859375,0.892578125,0.96484375},{14,0.0009765625,0.880859375,0.177734375,0.96484375},{14,0.1796875,0.880859375,0.3564453125,0.96484375},{14,0.3583984375,0.880859375,0.53515625,0.96484375},{14,0.537109375,0.880859375,0.7138671875,0.96484375},{14,0.7158203125,0.880859375,0.892578125,0.96484375},{33,0.0009765625,0.853515625,0.177734375,0.9375},{33,0.1796875,0.853515625,0.3564453125,0.9375},{33,0.3583984375,0.853515625,0.53515625,0.9375}},["hold"]={{33,0.3583984375,0.853515625,0.53515625,0.9375},{33,0.537109375,0.853515625,0.7138671875,0.9375},{33,0.7158203125,0.853515625,0.892578125,0.9375},{34,0.0009765625,0.853515625,0.177734375,0.9375},{34,0.1796875,0.853515625,0.3564453125,0.9375},{34,0.3583984375,0.853515625,0.53515625,0.9375},{34,0.537109375,0.853515625,0.7138671875,0.9375},{34,0.7158203125,0.853515625,0.892578125,0.9375},{35,0.0009765625,0.853515625,0.177734375,0.9375},{35,0.1796875,0.853515625,0.3564453125,0.9375},{35,0.3583984375,0.853515625,0.53515625,0.9375},{35,0.537109375,0.853515625,0.7138671875,0.9375},{35,0.7158203125,0.853515625,0.892578125,0.9375},{36,0.0009765625,0.8505859375,0.177734375,0.9345703125},{36,0.1796875,0.8505859375,0.3564453125,0.9345703125},{36,0.3583984375,0.8505859375,0.53515625,0.9345703125},{36,0.537109375,0.8505859375,0.7138671875,0.9345703125},{36,0.7158203125,0.8505859375,0.892578125,0.9345703125},{37,0.0009765625,0.8505859375,0.177734375,0.9345703125},{37,0.1796875,0.8505859375,0.3564453125,0.9345703125},{37,0.3583984375,0.8505859375,0.53515625,0.9345703125},{37,0.537109375,0.8505859375,0.7138671875,0.9345703125},{37,0.7158203125,0.8505859375,0.892578125,0.9345703125},{32,0.0009765625,0.833984375,0.177734375,0.91796875}},["ending"]={{33,0.3583984375,0.853515625,0.53515625,0.9375},{33,0.1796875,0.853515625,0.3564453125,0.9375},{33,0.0009765625,0.853515625,0.177734375,0.9375},{14,0.7158203125,0.880859375,0.892578125,0.96484375},{14,0.537109375,0.880859375,0.7138671875,0.96484375},{14,0.3583984375,0.880859375,0.53515625,0.96484375},{14,0.1796875,0.880859375,0.3564453125,0.96484375},{14,0.0009765625,0.880859375,0.177734375,0.96484375},{13,0.7158203125,0.880859375,0.892578125,0.96484375},{13,0.537109375,0.880859375,0.7138671875,0.96484375},{13,0.3583984375,0.880859375,0.53515625,0.96484375},{13,0.1796875,0.880859375,0.3564453125,0.96484375}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"},["matched"]={["layer"]="rightBanner",["intro"]={{13,0.1796875,0.880859375,0.3564453125,0.96484375},{32,0.1796875,0.833984375,0.3564453125,0.91796875},{32,0.3583984375,0.833984375,0.53515625,0.91796875},{32,0.537109375,0.7802734375,0.7138671875,0.8642578125},{32,0.537109375,0.8662109375,0.7138671875,0.9501953125},{32,0.7158203125,0.833984375,0.892578125,0.91796875},{18,0.73828125,0.814453125,0.9150390625,0.8984375},{18,0.73828125,0.900390625,0.9150390625,0.984375},{19,0.73828125,0.814453125,0.9150390625,0.8984375},{19,0.73828125,0.900390625,0.9150390625,0.984375},{20,0.73828125,0.814453125,0.9150390625,0.8984375},{20,0.73828125,0.900390625,0.9150390625,0.984375}},["hold"]={{20,0.73828125,0.900390625,0.9150390625,0.984375},{21,0.73828125,0.814453125,0.9150390625,0.8984375},{21,0.73828125,0.900390625,0.9150390625,0.984375},{22,0.73828125,0.814453125,0.9150390625,0.8984375},{22,0.73828125,0.900390625,0.9150390625,0.984375},{23,0.73828125,0.814453125,0.9150390625,0.8984375},{23,0.73828125,0.900390625,0.9150390625,0.984375},{24,0.73828125,0.814453125,0.9150390625,0.8984375},{24,0.73828125,0.900390625,0.9150390625,0.984375},{25,0.73828125,0.814453125,0.9150390625,0.8984375},{25,0.73828125,0.900390625,0.9150390625,0.984375},{26,0.73828125,0.814453125,0.9150390625,0.8984375},{26,0.73828125,0.900390625,0.9150390625,0.984375},{38,0.5302734375,0.5341796875,0.70703125,0.6181640625},{27,0.0009765625,0.814453125,0.177734375,0.8984375},{27,0.0009765625,0.900390625,0.177734375,0.984375},{27,0.1796875,0.814453125,0.3564453125,0.8984375},{27,0.1796875,0.900390625,0.3564453125,0.984375},{27,0.3583984375,0.814453125,0.53515625,0.8984375},{27,0.3583984375,0.900390625,0.53515625,0.984375},{27,0.537109375,0.7802734375,0.7138671875,0.8642578125},{27,0.537109375,0.8662109375,0.7138671875,0.9501953125},{27,0.7158203125,0.814453125,0.892578125,0.8984375},{27,0.7158203125,0.900390625,0.892578125,0.984375}},["ending"]={{20,0.73828125,0.900390625,0.9150390625,0.984375},{28,0.0009765625,0.814453125,0.177734375,0.8984375},{28,0.0009765625,0.900390625,0.177734375,0.984375},{28,0.1796875,0.814453125,0.3564453125,0.8984375},{28,0.1796875,0.900390625,0.3564453125,0.984375},{28,0.3583984375,0.814453125,0.53515625,0.8984375},{28,0.3583984375,0.900390625,0.53515625,0.984375},{28,0.537109375,0.7802734375,0.7138671875,0.8642578125},{28,0.537109375,0.8662109375,0.7138671875,0.9501953125},{28,0.7158203125,0.814453125,0.892578125,0.8984375},{28,0.7158203125,0.900390625,0.892578125,0.984375},{13,0.1796875,0.880859375,0.3564453125,0.96484375}},["idle"]={["intro"]={{13,0.1796875,0.880859375,0.3564453125,0.96484375},{29,0.0009765625,0.814453125,0.177734375,0.8984375},{29,0.0009765625,0.900390625,0.177734375,0.984375},{29,0.1796875,0.814453125,0.3564453125,0.8984375},{29,0.1796875,0.900390625,0.3564453125,0.984375},{29,0.3583984375,0.814453125,0.53515625,0.8984375},{29,0.3583984375,0.900390625,0.53515625,0.984375},{29,0.537109375,0.7802734375,0.7138671875,0.8642578125},{29,0.537109375,0.8662109375,0.7138671875,0.9501953125},{29,0.7158203125,0.814453125,0.892578125,0.8984375},{29,0.7158203125,0.900390625,0.892578125,0.984375},{30,0.0009765625,0.814453125,0.177734375,0.8984375}},["hold"]={{30,0.0009765625,0.814453125,0.177734375,0.8984375},{30,0.0009765625,0.900390625,0.177734375,0.984375},{30,0.1796875,0.814453125,0.3564453125,0.8984375},{30,0.1796875,0.900390625,0.3564453125,0.984375},{30,0.3583984375,0.814453125,0.53515625,0.8984375},{30,0.3583984375,0.900390625,0.53515625,0.984375},{30,0.537109375,0.7802734375,0.7138671875,0.8642578125},{30,0.537109375,0.8662109375,0.7138671875,0.9501953125},{30,0.7158203125,0.814453125,0.892578125,0.8984375},{30,0.7158203125,0.900390625,0.892578125,0.984375},{31,0.0009765625,0.814453125,0.177734375,0.8984375},{31,0.0009765625,0.900390625,0.177734375,0.984375},{31,0.1796875,0.814453125,0.3564453125,0.8984375},{31,0.1796875,0.900390625,0.3564453125,0.984375},{31,0.3583984375,0.814453125,0.53515625,0.8984375},{31,0.3583984375,0.900390625,0.53515625,0.984375},{31,0.537109375,0.7802734375,0.7138671875,0.8642578125},{31,0.537109375,0.8662109375,0.7138671875,0.9501953125},{31,0.7158203125,0.814453125,0.892578125,0.8984375},{31,0.7158203125,0.900390625,0.892578125,0.984375},{38,0.708984375,0.595703125,0.8857421875,0.6796875},{38,0.5302734375,0.6201171875,0.70703125,0.7041015625},{38,0.708984375,0.681640625,0.8857421875,0.765625},{38,0.5302734375,0.7060546875,0.70703125,0.7900390625}},["ending"]={{30,0.0009765625,0.814453125,0.177734375,0.8984375},{38,0.708984375,0.767578125,0.8857421875,0.8515625},{38,0.5302734375,0.7919921875,0.70703125,0.8759765625},{38,0.0009765625,0.8779296875,0.177734375,0.9619140625},{38,0.1796875,0.8779296875,0.3564453125,0.9619140625},{38,0.3583984375,0.8779296875,0.53515625,0.9619140625},{38,0.537109375,0.8779296875,0.7138671875,0.9619140625},{38,0.7158203125,0.853515625,0.892578125,0.9375},{39,0.0009765625,0.0009765625,0.177734375,0.0849609375},{39,0.1796875,0.0009765625,0.3564453125,0.0849609375},{39,0.3583984375,0.0009765625,0.53515625,0.0849609375},{13,0.1796875,0.880859375,0.3564453125,0.96484375}}}}},["sproutFork"]={["mode"]="replace",["fps"]=24,["rect"]={0.346969696969697,0.45454545454545453,0.3151515151515151,0.17272727272727273},["intro"]={{15,0.794921875,0.5888671875,0.998046875,0.7373046875},{15,0.794921875,0.7392578125,0.998046875,0.8876953125},{16,0.794921875,0.5888671875,0.998046875,0.7373046875},{16,0.794921875,0.7392578125,0.998046875,0.8876953125},{17,0.794921875,0.5888671875,0.998046875,0.7373046875},{17,0.794921875,0.7392578125,0.998046875,0.8876953125},{18,0.794921875,0.513671875,0.998046875,0.662109375},{18,0.794921875,0.6640625,0.998046875,0.8125},{19,0.794921875,0.513671875,0.998046875,0.662109375},{19,0.794921875,0.6640625,0.998046875,0.8125},{20,0.794921875,0.513671875,0.998046875,0.662109375},{20,0.794921875,0.6640625,0.998046875,0.8125}},["hold"]={{20,0.794921875,0.6640625,0.998046875,0.8125},{21,0.794921875,0.513671875,0.998046875,0.662109375},{21,0.794921875,0.6640625,0.998046875,0.8125},{22,0.794921875,0.513671875,0.998046875,0.662109375},{22,0.794921875,0.6640625,0.998046875,0.8125},{23,0.794921875,0.513671875,0.998046875,0.662109375},{23,0.794921875,0.6640625,0.998046875,0.8125},{24,0.794921875,0.513671875,0.998046875,0.662109375},{24,0.794921875,0.6640625,0.998046875,0.8125},{25,0.794921875,0.513671875,0.998046875,0.662109375},{25,0.794921875,0.6640625,0.998046875,0.8125},{26,0.794921875,0.513671875,0.998046875,0.662109375},{26,0.794921875,0.6640625,0.998046875,0.8125},{27,0.794921875,0.513671875,0.998046875,0.662109375},{27,0.794921875,0.6640625,0.998046875,0.8125},{28,0.794921875,0.513671875,0.998046875,0.662109375},{28,0.794921875,0.6640625,0.998046875,0.8125},{29,0.794921875,0.513671875,0.998046875,0.662109375},{29,0.794921875,0.6640625,0.998046875,0.8125},{30,0.794921875,0.513671875,0.998046875,0.662109375},{30,0.794921875,0.6640625,0.998046875,0.8125},{31,0.794921875,0.513671875,0.998046875,0.662109375},{31,0.794921875,0.6640625,0.998046875,0.8125},{32,0.794921875,0.513671875,0.998046875,0.662109375}},["ending"]={{20,0.794921875,0.6640625,0.998046875,0.8125},{20,0.794921875,0.513671875,0.998046875,0.662109375},{19,0.794921875,0.6640625,0.998046875,0.8125},{19,0.794921875,0.513671875,0.998046875,0.662109375},{18,0.794921875,0.6640625,0.998046875,0.8125},{18,0.794921875,0.513671875,0.998046875,0.662109375},{17,0.794921875,0.7392578125,0.998046875,0.8876953125},{17,0.794921875,0.5888671875,0.998046875,0.7373046875},{16,0.794921875,0.7392578125,0.998046875,0.8876953125},{16,0.794921875,0.5888671875,0.998046875,0.7373046875},{15,0.794921875,0.7392578125,0.998046875,0.8876953125},{15,0.794921875,0.5888671875,0.998046875,0.7373046875}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}},["backboard"]={["mode"]="replace",["fps"]=24,["rect"]={0.21212121212121213,0.14204545454545456,0.5833333333333334,0.6090909090909091},["intro"]={{1,0.0009765625,0.0009765625,0.376953125,0.5244140625},{1,0.37890625,0.0009765625,0.7548828125,0.5244140625},{2,0.0009765625,0.0009765625,0.376953125,0.5244140625},{2,0.37890625,0.0009765625,0.7548828125,0.5244140625},{3,0.0009765625,0.0009765625,0.376953125,0.5244140625},{3,0.37890625,0.0009765625,0.7548828125,0.5244140625},{4,0.0009765625,0.0009765625,0.376953125,0.5244140625},{4,0.37890625,0.0009765625,0.7548828125,0.5244140625},{5,0.0009765625,0.0009765625,0.376953125,0.5244140625},{5,0.37890625,0.0009765625,0.7548828125,0.5244140625},{6,0.0009765625,0.0009765625,0.376953125,0.5244140625},{6,0.37890625,0.0009765625,0.7548828125,0.5244140625}},["hold"]={{6,0.37890625,0.0009765625,0.7548828125,0.5244140625},{7,0.0009765625,0.0009765625,0.376953125,0.5244140625},{7,0.37890625,0.0009765625,0.7548828125,0.5244140625},{8,0.0009765625,0.0009765625,0.376953125,0.5244140625},{8,0.37890625,0.0009765625,0.7548828125,0.5244140625},{9,0.0009765625,0.0009765625,0.376953125,0.5244140625},{9,0.37890625,0.0009765625,0.7548828125,0.5244140625},{10,0.0009765625,0.0009765625,0.376953125,0.5244140625},{10,0.37890625,0.0009765625,0.7548828125,0.5244140625},{11,0.0009765625,0.0009765625,0.376953125,0.5244140625},{11,0.37890625,0.0009765625,0.7548828125,0.5244140625},{12,0.0009765625,0.0009765625,0.376953125,0.5244140625},{12,0.37890625,0.0009765625,0.7548828125,0.5244140625},{13,0.0009765625,0.0009765625,0.376953125,0.5244140625},{13,0.37890625,0.0009765625,0.7548828125,0.5244140625},{14,0.0009765625,0.0009765625,0.376953125,0.5244140625},{14,0.37890625,0.0009765625,0.7548828125,0.5244140625},{15,0.0009765625,0.0009765625,0.376953125,0.5244140625},{15,0.37890625,0.0009765625,0.7548828125,0.5244140625},{16,0.0009765625,0.0009765625,0.376953125,0.5244140625},{16,0.37890625,0.0009765625,0.7548828125,0.5244140625},{17,0.0009765625,0.0009765625,0.376953125,0.5244140625},{17,0.37890625,0.0009765625,0.7548828125,0.5244140625},{18,0.0009765625,0.0009765625,0.376953125,0.5244140625}},["ending"]={{6,0.37890625,0.0009765625,0.7548828125,0.5244140625},{6,0.0009765625,0.0009765625,0.376953125,0.5244140625},{5,0.37890625,0.0009765625,0.7548828125,0.5244140625},{5,0.0009765625,0.0009765625,0.376953125,0.5244140625},{4,0.37890625,0.0009765625,0.7548828125,0.5244140625},{4,0.0009765625,0.0009765625,0.376953125,0.5244140625},{3,0.37890625,0.0009765625,0.7548828125,0.5244140625},{3,0.0009765625,0.0009765625,0.376953125,0.5244140625},{2,0.37890625,0.0009765625,0.7548828125,0.5244140625},{2,0.0009765625,0.0009765625,0.376953125,0.5244140625},{1,0.37890625,0.0009765625,0.7548828125,0.5244140625},{1,0.0009765625,0.0009765625,0.376953125,0.5244140625}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}},["leftBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.08787878787878788,0.3306818181818182,0.3409090909090909,0.3375},["intro"]={{3,0.689453125,0.5888671875,0.9091796875,0.87890625},{4,0.0009765625,0.5888671875,0.220703125,0.87890625},{4,0.22265625,0.5888671875,0.4423828125,0.87890625},{4,0.4443359375,0.5263671875,0.6640625,0.81640625},{4,0.666015625,0.5888671875,0.8857421875,0.87890625},{5,0.0009765625,0.5888671875,0.220703125,0.87890625},{5,0.22265625,0.5888671875,0.4423828125,0.87890625},{5,0.4443359375,0.5263671875,0.6640625,0.81640625},{5,0.666015625,0.5888671875,0.8857421875,0.87890625},{6,0.0009765625,0.5888671875,0.220703125,0.87890625},{6,0.22265625,0.5888671875,0.4423828125,0.87890625},{6,0.4443359375,0.5263671875,0.6640625,0.81640625}},["hold"]={{6,0.4443359375,0.5263671875,0.6640625,0.81640625},{6,0.666015625,0.5888671875,0.8857421875,0.87890625},{7,0.0009765625,0.5888671875,0.220703125,0.87890625},{7,0.22265625,0.5888671875,0.4423828125,0.87890625},{7,0.4443359375,0.5263671875,0.6640625,0.81640625},{7,0.666015625,0.5888671875,0.8857421875,0.87890625},{8,0.0009765625,0.5888671875,0.220703125,0.87890625},{8,0.22265625,0.5888671875,0.4423828125,0.87890625},{8,0.4443359375,0.5263671875,0.6640625,0.81640625},{8,0.666015625,0.5888671875,0.8857421875,0.87890625},{9,0.0009765625,0.5888671875,0.220703125,0.87890625},{9,0.22265625,0.5888671875,0.4423828125,0.87890625},{9,0.4443359375,0.5263671875,0.6640625,0.81640625},{9,0.666015625,0.5888671875,0.8857421875,0.87890625},{10,0.0009765625,0.5888671875,0.220703125,0.87890625},{10,0.22265625,0.5888671875,0.4423828125,0.87890625},{10,0.4443359375,0.5263671875,0.6640625,0.81640625},{10,0.666015625,0.5888671875,0.8857421875,0.87890625},{11,0.0009765625,0.5888671875,0.220703125,0.87890625},{11,0.22265625,0.5888671875,0.4423828125,0.87890625},{11,0.4443359375,0.5263671875,0.6640625,0.81640625},{11,0.666015625,0.5888671875,0.8857421875,0.87890625},{12,0.0009765625,0.5888671875,0.220703125,0.87890625},{12,0.22265625,0.5888671875,0.4423828125,0.87890625}},["ending"]={{6,0.4443359375,0.5263671875,0.6640625,0.81640625},{12,0.4443359375,0.5263671875,0.6640625,0.81640625},{12,0.666015625,0.5888671875,0.8857421875,0.87890625},{13,0.0009765625,0.5888671875,0.220703125,0.87890625},{13,0.22265625,0.5888671875,0.4423828125,0.87890625},{13,0.4443359375,0.5263671875,0.6640625,0.81640625},{13,0.666015625,0.5888671875,0.8857421875,0.87890625},{14,0.0009765625,0.5888671875,0.220703125,0.87890625},{14,0.22265625,0.5888671875,0.4423828125,0.87890625},{14,0.4443359375,0.5263671875,0.6640625,0.81640625},{14,0.666015625,0.5888671875,0.8857421875,0.87890625},{3,0.689453125,0.5888671875,0.9091796875,0.87890625}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}},["rightBanner"]={["mode"]="replace",["fps"]=24,["rect"]={0.5727272727272728,0.32840909090909093,0.353030303030303,0.3397727272727273},["intro"]={{1,0.7568359375,0.0009765625,0.984375,0.29296875},{1,0.7568359375,0.294921875,0.984375,0.5869140625},{2,0.7568359375,0.0009765625,0.984375,0.29296875},{2,0.7568359375,0.294921875,0.984375,0.5869140625},{3,0.7568359375,0.0009765625,0.984375,0.29296875},{3,0.7568359375,0.294921875,0.984375,0.5869140625},{4,0.7568359375,0.0009765625,0.984375,0.29296875},{4,0.7568359375,0.294921875,0.984375,0.5869140625},{5,0.7568359375,0.0009765625,0.984375,0.29296875},{5,0.7568359375,0.294921875,0.984375,0.5869140625},{6,0.7568359375,0.0009765625,0.984375,0.29296875},{6,0.7568359375,0.294921875,0.984375,0.5869140625}},["hold"]={{6,0.7568359375,0.294921875,0.984375,0.5869140625},{7,0.7568359375,0.0009765625,0.984375,0.29296875},{7,0.7568359375,0.294921875,0.984375,0.5869140625},{8,0.7568359375,0.0009765625,0.984375,0.29296875},{8,0.7568359375,0.294921875,0.984375,0.5869140625},{9,0.7568359375,0.0009765625,0.984375,0.29296875},{9,0.7568359375,0.294921875,0.984375,0.5869140625},{10,0.7568359375,0.0009765625,0.984375,0.29296875},{10,0.7568359375,0.294921875,0.984375,0.5869140625},{11,0.7568359375,0.0009765625,0.984375,0.29296875},{11,0.7568359375,0.294921875,0.984375,0.5869140625},{12,0.7568359375,0.0009765625,0.984375,0.29296875},{12,0.7568359375,0.294921875,0.984375,0.5869140625},{13,0.7568359375,0.0009765625,0.984375,0.29296875},{13,0.7568359375,0.294921875,0.984375,0.5869140625},{14,0.7568359375,0.0009765625,0.984375,0.29296875},{14,0.7568359375,0.294921875,0.984375,0.5869140625},{15,0.7568359375,0.0009765625,0.984375,0.29296875},{15,0.7568359375,0.294921875,0.984375,0.5869140625},{16,0.7568359375,0.0009765625,0.984375,0.29296875},{16,0.7568359375,0.294921875,0.984375,0.5869140625},{17,0.7568359375,0.0009765625,0.984375,0.29296875},{17,0.7568359375,0.294921875,0.984375,0.5869140625},{1,0.0009765625,0.5888671875,0.228515625,0.880859375}},["ending"]={{6,0.7568359375,0.294921875,0.984375,0.5869140625},{1,0.23046875,0.5888671875,0.4580078125,0.880859375},{1,0.4599609375,0.5263671875,0.6875,0.818359375},{1,0.689453125,0.5888671875,0.9169921875,0.880859375},{2,0.0009765625,0.5888671875,0.228515625,0.880859375},{2,0.23046875,0.5888671875,0.4580078125,0.880859375},{2,0.4599609375,0.5263671875,0.6875,0.818359375},{2,0.689453125,0.5888671875,0.9169921875,0.880859375},{3,0.0009765625,0.5888671875,0.228515625,0.880859375},{3,0.23046875,0.5888671875,0.4580078125,0.880859375},{3,0.4599609375,0.5263671875,0.6875,0.818359375},{1,0.7568359375,0.0009765625,0.984375,0.29296875}},["pages"]={"StudioDruidRestorationChannelPlusSize660Page1.tga","StudioDruidRestorationChannelPlusSize660Page2.tga","StudioDruidRestorationChannelPlusSize660Page3.tga","StudioDruidRestorationChannelPlusSize660Page4.tga","StudioDruidRestorationChannelPlusSize660Page5.tga","StudioDruidRestorationChannelPlusSize660Page6.tga","StudioDruidRestorationChannelPlusSize660Page7.tga","StudioDruidRestorationChannelPlusSize660Page8.tga","StudioDruidRestorationChannelPlusSize660Page9.tga","StudioDruidRestorationChannelPlusSize660Page10.tga","StudioDruidRestorationChannelPlusSize660Page11.tga","StudioDruidRestorationChannelPlusSize660Page12.tga","StudioDruidRestorationChannelPlusSize660Page13.tga","StudioDruidRestorationChannelPlusSize660Page14.tga","StudioDruidRestorationChannelPlusSize660Page15.tga","StudioDruidRestorationChannelPlusSize660Page16.tga","StudioDruidRestorationChannelPlusSize660Page17.tga","StudioDruidRestorationChannelPlusSize660Page18.tga","StudioDruidRestorationChannelPlusSize660Page19.tga","StudioDruidRestorationChannelPlusSize660Page20.tga","StudioDruidRestorationChannelPlusSize660Page21.tga","StudioDruidRestorationChannelPlusSize660Page22.tga","StudioDruidRestorationChannelPlusSize660Page23.tga","StudioDruidRestorationChannelPlusSize660Page24.tga","StudioDruidRestorationChannelPlusSize660Page25.tga","StudioDruidRestorationChannelPlusSize660Page26.tga","StudioDruidRestorationChannelPlusSize660Page27.tga","StudioDruidRestorationChannelPlusSize660Page28.tga","StudioDruidRestorationChannelPlusSize660Page29.tga","StudioDruidRestorationChannelPlusSize660Page30.tga","StudioDruidRestorationChannelPlusSize660Page31.tga","StudioDruidRestorationChannelPlusSize660Page32.tga","StudioDruidRestorationChannelPlusSize660Page33.tga","StudioDruidRestorationChannelPlusSize660Page34.tga","StudioDruidRestorationChannelPlusSize660Page35.tga","StudioDruidRestorationChannelPlusSize660Page36.tga","StudioDruidRestorationChannelPlusSize660Page37.tga","StudioDruidRestorationChannelPlusSize660Page38.tga","StudioDruidRestorationChannelPlusSize660Page39.tga"}}}}

do
    local expanded = {["StudioDruidRestorationChannelPlusSize288Page1.tga"]=true,["StudioDruidRestorationChannelPlusSize288Page2.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page1.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page2.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page3.tga"]=true}
    local seen = {}
    local function adjust(pages, tiles)
        for _,tile in ipairs(tiles) do
            if expanded[pages[tile[1]]] and not seen[tile] then
                seen[tile] = true
                for i=2,5 do tile[i]=tile[i]/2 end
            end
        end
    end
    for _,bank in pairs(E.ArtworkChannelPlusBanks["DRUID:restoration"]) do
        for _,track in pairs(bank) do
            for _,stage in ipairs({"intro","hold","ending"}) do
                adjust(track.pages,track[stage])
                if track.matched then adjust(track.pages,track.matched[stage]) end
            end
            if track.matched and track.matched.idle then
                for _,tiles in pairs(track.matched.idle) do adjust(track.pages,tiles) end
            end
        end
    end
end

local starlightPages={
{"StudioDruidRestorationChannelPlusSize288Page1.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize288Page2.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page1.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page2.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page3.tga",2048,2048},
}
local starlightHigh={pixels=144,pages=starlightPages,bands={
{
{3,1365,2,36,165,-90,-41},
{3,1780,2,36,176,-90,-44},
{3,1640,177,35,185,-89,-47},
{3,1403,229,35,194,-89,-48},
{3,1066,237,35,201,-89,-49},
{3,1365,388,34,206,-88,-48},
{3,1804,409,34,208,-88,-46},
{3,1879,593,33,210,-87,-42},
{3,1840,623,33,210,-87,-38},
{3,1994,718,32,208,-88,-34},
{3,1300,815,32,207,-88,-31},
{3,1620,890,31,206,-87,-28},
{3,1257,984,31,203,-87,-25},
{3,1336,1010,31,202,-87,-22},
{3,628,1026,30,198,-86,-20},
{3,1292,1026,32,197,-88,-17},
{3,1443,1096,32,195,-88,-17},
{3,915,1173,32,172,-88,-38},
{3,1479,1217,32,175,-88,-33},
{3,769,1243,33,176,-89,-28},
{3,992,1283,33,179,-89,-23},
{3,1984,1331,34,181,-90,-19},
{3,1847,1388,34,184,-90,-14},
{3,404,1418,34,184,-90,-10},
{3,929,1432,34,185,-90,-7},
{3,75,1460,34,186,-90,-4},
{3,1513,1519,34,185,-90,-1},
{3,1282,1599,33,184,-89,0},
{3,914,1621,33,182,-89,2},
{3,854,1669,33,180,-89,2},
{3,1951,1690,33,177,-89,3},
{3,1690,1771,32,176,-90,4},
{3,473,1781,32,174,-90,6},
{3,107,1816,32,176,-90,10},
{4,1331,2,32,176,-90,14},
{4,1737,2,32,177,-90,17},
{4,1806,166,32,176,-90,20},
{4,1302,182,33,189,-91,7},
{4,1915,219,31,193,-93,3},
{4,1555,372,31,196,-91,-2},
{4,2008,389,33,200,-91,-6},
{4,1662,513,33,200,-91,-10},
{4,1551,572,33,200,-91,-12},
{4,1094,606,34,201,-90,-15},
{4,1660,717,34,200,-90,-18},
{4,2007,784,34,199,-90,-19},
{4,1328,899,34,191,-90,-23},
{4,1612,975,35,165,-89,-45},
{4,231,1026,35,165,-89,-41},
{4,646,1026,35,176,-89,-44},
{4,1879,1070,35,186,-89,-46},
{4,1684,1153,35,195,-89,-49},
{4,1565,1181,34,201,-88,-49},
{4,132,1193,34,206,-88,-48},
{4,646,1206,34,209,-88,-45},
{4,830,1236,34,209,-88,-43},
{4,1384,1340,35,209,-87,-39},
{4,903,1364,35,209,-87,-35},
{4,207,1391,35,208,-87,-32},
{4,1882,1440,34,206,-86,-28},
{4,73,1448,34,204,-86,-26},
{4,1957,1552,34,201,-86,-23},
{4,1995,1577,32,199,-84,-21},
{4,204,1603,36,197,-88,-17},
{4,1637,1646,36,194,-88,-14},
{4,1784,1747,36,189,-88,-13},
{4,633,1780,36,169,-88,-27},
{5,1405,2,37,168,-89,-20},
{5,1825,2,37,168,-89,-14},
{5,1368,197,38,171,-90,-9},
{5,1929,224,39,172,-89,-4},
{5,1199,342,39,173,-89,1},
{5,1972,399,39,173,-89,5},
{5,1092,456,39,174,-89,6},
{5,1961,576,39,176,-89,6},
{5,2004,601,38,178,-90,6},
{5,1955,756,38,178,-90,6},
{5,1404,879,38,178,-90,4},
{5,1344,959,38,178,-90,4},
{5,105,1026,38,178,-90,2},
{5,527,1026,38,179,-90,3},
{5,909,1026,38,182,-90,6},
{5,1856,1096,37,184,-91,8},
{5,1332,1141,37,185,-91,9},
{5,527,1209,37,184,-91,10},
{5,167,1220,36,189,-90,7},
{5,1373,1261,30,193,-96,3},
{5,1629,1278,35,197,-91,-1},
{5,406,1362,35,200,-91,-6},
{5,1407,1391,35,201,-91,-9},
{5,1798,1414,35,200,-91,-12},
{5,1837,1475,36,200,-90,-16},
{5,349,1520,36,200,-90,-18},
{5,1089,1553,36,199,-90,-19},
{5,138,1598,36,192,-90,-24},
{5,1358,1649,36,163,-90,-47},
},
{
{3,1286,2,37,191,-33,-29},
{3,1739,2,37,192,-33,-24},
{3,1226,176,35,194,-35,-20},
{3,1326,212,35,195,-35,-15},
{3,1026,237,36,197,-34,-11},
{3,1266,378,37,197,-33,-7},
{3,1307,411,37,197,-33,-5},
{3,1266,579,37,198,-33,-4},
{3,1307,612,37,199,-33,-5},
{3,1953,718,37,200,-33,-6},
{3,1259,781,37,199,-33,-5},
{3,1497,864,37,196,-33,-4},
{3,1996,930,37,193,-33,-3},
{3,188,1026,37,197,-33,-7},
{3,553,1026,37,199,-33,-13},
{3,952,1026,37,201,-33,-17},
{3,1111,1066,37,200,-33,-20},
{3,1996,1127,37,200,-33,-18},
{3,423,1215,37,199,-33,-17},
{3,951,1231,37,197,-33,-15},
{3,1362,1245,37,194,-33,-12},
{3,1437,1295,36,191,-32,-9},
{3,1807,1364,36,190,-32,-8},
{3,1301,1405,36,190,-32,-10},
{3,363,1427,36,191,-32,-11},
{3,1374,1457,36,190,-32,-10},
{3,1587,1519,36,164,-32,-32},
{3,1447,1599,36,164,-32,-30},
{3,1191,1626,36,166,-32,-30},
{3,814,1669,36,167,-32,-29},
{3,1587,1687,36,168,-32,-30},
{3,1547,1718,36,168,-32,-28},
{3,1627,1787,36,168,-32,-28},
{3,891,1807,35,167,-31,-25},
{4,1292,2,35,167,-31,-23},
{4,1698,2,35,167,-31,-21},
{4,1227,168,35,167,-31,-19},
{4,1339,189,35,168,-31,-16},
{4,1597,301,35,167,-31,-15},
{4,1821,375,34,167,-30,-13},
{4,1412,425,34,167,-30,-11},
{4,1821,546,34,166,-30,-10},
{4,1411,596,34,165,-30,-7},
{4,1813,716,34,164,-30,-6},
{4,1416,765,33,163,-29,-5},
{4,1585,809,33,162,-29,-4},
{4,1656,921,33,160,-29,-2},
{4,1218,974,33,160,-29,0},
{4,270,1026,33,159,-29,3},
{4,685,1026,33,161,-29,7},
{4,1918,1070,33,164,-29,12},
{4,1723,1153,33,164,-29,16},
{4,955,1184,32,188,-28,-2},
{4,231,1195,32,192,-28,-2},
{4,759,1236,32,195,-28,-3},
{4,607,1241,32,197,-28,-5},
{4,1603,1362,32,198,-28,-6},
{4,2017,1372,24,201,-20,-5},
{4,1854,1440,24,199,-20,-5},
{4,1639,1445,34,197,-30,-5},
{4,714,1448,33,200,-29,-8},
{4,1677,1557,33,202,-29,-12},
{4,936,1577,33,205,-29,-17},
{4,148,1637,32,207,-30,-21},
{4,1863,1650,33,208,-31,-28},
{4,1900,1738,33,211,-31,-31},
{4,1677,1763,33,215,-31,-33},
{5,1297,2,32,217,-32,-35},
{5,1717,2,32,220,-32,-38},
{5,2000,2,33,221,-33,-39},
{5,1854,224,33,223,-33,-41},
{5,1544,334,33,223,-33,-43},
{5,1160,369,33,223,-33,-43},
{5,1854,451,33,221,-33,-45},
{5,1135,596,33,199,-33,-67},
{5,1096,634,33,200,-33,-64},
{5,1172,720,34,199,-32,-63},
{5,1820,852,34,199,-32,-61},
{5,1160,923,35,199,-33,-59},
{5,66,1026,35,198,-33,-58},
{5,488,1026,35,198,-33,-58},
{5,951,1026,35,196,-33,-58},
{5,1386,1061,35,196,-33,-56},
{5,1095,1165,35,194,-33,-56},
{5,604,1194,35,194,-33,-54},
{5,1814,1223,35,187,-33,-59},
{5,64,1228,35,187,-33,-57},
{5,1853,1284,36,187,-32,-55},
{5,1090,1363,36,186,-32,-52},
{5,943,1407,36,187,-32,-49},
{5,540,1425,36,189,-32,-45},
{5,1130,1479,36,191,-32,-41},
{5,1963,1539,36,192,-32,-38},
{5,98,1559,36,193,-32,-35},
{5,1795,1618,36,192,-32,-32},
{5,1030,1634,37,191,-33,-31},
},
{
{3,1405,2,30,184,36,-14},
{3,1820,2,30,186,36,-18},
{3,1980,180,29,173,37,-35},
{3,2013,180,29,175,37,-35},
{3,1567,354,24,177,42,-35},
{3,1879,408,30,177,36,-35},
{3,1098,453,30,177,36,-33},
{3,1348,598,30,179,36,-27},
{3,1098,634,30,184,36,-24},
{3,1586,748,30,189,36,-23},
{3,1152,837,30,193,36,-21},
{3,1655,890,30,196,36,-18},
{3,1795,1009,30,199,36,-11},
{3,229,1026,30,200,36,-6},
{3,594,1026,30,201,36,-1},
{3,1152,1034,30,200,36,4},
{3,1599,1100,30,199,36,7},
{3,881,1173,30,199,36,9},
{3,518,1175,30,202,36,6},
{3,1152,1238,30,206,36,2},
{3,1403,1245,30,208,36,-2},
{3,464,1347,29,208,37,-6},
{3,1885,1388,29,207,37,-7},
{3,672,1424,29,203,37,-9},
{3,1341,1443,29,198,37,-8},
{3,1414,1490,29,195,37,-7},
{3,442,1559,29,190,37,-8},
{3,2,1605,29,186,37,-8},
{3,1231,1626,29,162,37,-28},
{3,1093,1665,29,164,37,-24},
{3,1988,1690,29,167,37,-23},
{3,1726,1771,29,171,37,-23},
{3,38,1799,29,177,39,-27},
{3,143,1816,29,180,39,-30},
{4,1367,2,29,183,39,-33},
{4,1773,2,29,183,39,-33},
{4,1400,168,29,180,39,-32},
{4,1771,189,29,177,39,-31},
{4,1672,336,29,173,39,-31},
{4,1859,375,29,169,39,-31},
{4,1450,425,29,164,39,-30},
{4,1378,520,29,162,39,-32},
{4,1449,596,30,160,40,-34},
{4,1973,641,30,160,40,-34},
{4,1551,776,30,153,40,-37},
{4,1622,809,30,152,40,-36},
{4,1098,811,29,150,41,-32},
{4,1769,982,29,158,41,-32},
{4,307,1026,29,164,41,-34},
{4,722,1026,29,170,41,-34},
{4,1651,1085,29,174,41,-34},
{4,1403,1160,29,176,41,-34},
{4,1975,805,28,177,42,-35},
{4,1094,1205,31,177,39,-35},
{4,795,1236,31,177,39,-33},
{4,1648,1263,31,178,39,-28},
{4,868,1364,31,184,39,-26},
{4,1326,1384,31,188,39,-24},
{4,132,1403,31,193,39,-21},
{4,607,1442,31,197,39,-17},
{4,1791,1544,31,199,39,-13},
{4,1602,1564,31,199,39,-7},
{4,1555,1582,31,200,39,-2},
{4,599,1643,30,200,38,4},
{4,709,1652,30,199,38,7},
{4,1937,1757,30,198,38,10},
{4,1590,1767,30,203,38,5},
{5,1333,2,31,206,37,2},
{5,1753,2,31,208,37,-2},
{5,1647,168,31,209,37,-5},
{5,1682,168,31,207,37,-7},
{5,1242,342,31,203,37,-9},
{5,2015,399,31,198,37,-8},
{5,1581,537,31,194,37,-8},
{5,1369,574,31,190,37,-8},
{5,1442,682,31,188,37,-6},
{5,1369,768,31,187,37,-3},
{5,1649,885,31,184,37,0},
{5,1992,977,31,184,37,2},
{5,186,1026,31,190,37,-4},
{5,569,1026,31,195,37,-9},
{5,990,1026,31,199,37,-13},
{5,1649,1073,31,201,37,-15},
{5,1991,1165,31,201,37,-15},
{5,908,1212,31,199,37,-15},
{5,568,1225,31,196,37,-12},
{5,1594,1237,31,194,37,-10},
{5,2,1337,31,190,37,-8},
{5,445,1390,30,188,36,-6},
{5,983,1407,30,187,36,-7},
{5,1594,1435,31,186,37,-8},
{5,242,1482,31,186,37,-8},
{5,2,1531,31,184,37,-8},
{5,1401,1596,31,180,37,-8},
{5,995,1634,31,177,37,-5},
{5,216,1672,30,180,36,-10},
},
{
{3,1327,2,34,206,92,-10},
{3,1701,2,34,210,92,-8},
{3,1365,171,34,213,92,-5},
{3,1804,192,34,213,92,-3},
{3,1105,237,33,212,93,0},
{3,1842,408,33,211,93,1},
{3,1403,427,33,208,93,2},
{3,1916,593,33,206,93,4},
{3,1382,639,32,201,92,5},
{3,1551,748,31,196,93,6},
{3,1336,815,31,191,93,5},
{3,1689,890,31,186,93,6},
{3,1829,1009,31,181,93,7},
{3,263,1026,31,177,93,7},
{3,662,1026,31,145,93,-27},
{3,1497,1064,31,149,93,-25},
{3,1532,1122,32,159,92,-27},
{3,482,1175,32,168,92,-30},
{3,821,1217,32,178,92,-32},
{3,733,1243,32,184,92,-34},
{3,1111,1270,32,191,92,-35},
{3,1709,1331,32,196,92,-36},
{3,497,1381,33,199,91,-35},
{3,1477,1396,32,199,90,-33},
{3,705,1431,32,198,90,-30},
{3,1093,1465,32,196,90,-28},
{3,1551,1519,32,195,90,-25},
{3,475,1584,32,193,90,-23},
{3,35,1605,32,190,90,-20},
{3,71,1650,32,188,90,-18},
{3,1383,1689,32,185,90,-15},
{3,437,1753,32,183,90,-13},
{3,2,1799,32,164,90,-26},
{3,176,1816,32,163,90,-21},
{4,1400,2,32,162,90,-16},
{4,1806,2,32,160,90,-12},
{4,1266,173,32,162,90,-10},
{4,1561,197,32,171,90,-21},
{4,1636,301,32,174,90,-24},
{4,1287,375,32,177,90,-27},
{4,1098,423,32,179,90,-31},
{4,1342,520,32,181,90,-31},
{4,2008,593,33,187,91,-29},
{4,1342,705,33,190,91,-26},
{4,1379,765,33,192,91,-20},
{4,1769,785,33,193,91,-15},
{4,1806,884,33,198,91,-12},
{4,1366,961,33,203,91,-11},
{4,195,1026,32,207,90,-9},
{4,610,1026,32,211,90,-7},
{4,1843,1070,32,214,90,-4},
{4,1612,1144,32,214,90,-2},
{4,1347,1168,33,212,89,0},
{4,685,1191,33,211,89,1},
{4,722,1236,33,208,89,2},
{4,170,1237,33,205,89,5},
{4,1683,1352,33,201,89,5},
{4,942,1376,33,197,89,7},
{4,1565,1386,33,192,89,6},
{4,167,1446,33,187,89,7},
{4,1920,1552,33,182,89,6},
{4,899,1577,33,177,89,7},
{4,111,1600,33,175,89,3},
{4,1826,1643,33,171,89,-7},
{4,72,1656,33,175,89,-11},
{4,887,1758,32,181,90,-17},
{4,109,1779,32,187,90,-23},
{5,1368,2,33,191,89,-27},
{5,1788,2,33,195,89,-31},
{5,1160,167,35,198,89,-34},
{5,1891,224,34,197,88,-35},
{5,1581,334,34,199,88,-33},
{5,1367,372,34,198,88,-30},
{5,1197,519,34,197,88,-27},
{5,1539,561,34,195,88,-25},
{5,1404,682,34,193,88,-23},
{5,1997,783,34,190,88,-20},
{5,1611,885,34,188,88,-18},
{5,1096,976,34,185,88,-15},
{5,147,1026,35,183,89,-13},
{5,604,1026,35,164,89,-26},
{5,1817,1055,35,164,89,-22},
{5,1134,1126,35,168,89,-22},
{5,424,1167,34,170,90,-22},
{5,1425,1215,34,172,90,-20},
{5,943,1226,35,172,91,-20},
{5,982,1229,35,174,91,-24},
{5,1134,1298,35,177,91,-27},
{5,103,1377,35,178,91,-32},
{5,142,1413,35,181,91,-31},
{5,1362,1458,35,187,91,-29},
{5,1629,1479,35,190,91,-26},
{5,2003,1539,35,192,91,-20},
{5,37,1585,34,193,92,-15},
{5,1574,1625,34,197,92,-13},
{5,178,1647,34,202,92,-12},
},
{
{3,1226,2,56,170,-56,-8},
{3,1641,2,56,171,-56,-5},
{3,1980,2,56,174,-56,0},
{3,1265,197,57,177,-57,5},
{3,1914,231,57,179,-57,9},
{3,1595,366,57,197,-57,-1},
{3,1913,414,57,175,-57,-19},
{3,1564,567,56,177,-58,-15},
{3,1780,621,56,179,-58,-9},
{3,1490,679,57,181,-57,-5},
{3,1750,804,56,182,-58,0},
{3,1810,837,56,168,-58,-10},
{3,1538,948,57,170,-59,-6},
{3,127,1026,57,172,-59,0},
{3,423,1026,55,185,-59,-7},
{3,821,1026,56,187,-60,-1},
{3,1655,1090,57,190,-59,4},
{3,1716,1136,57,191,-59,9},
{3,1301,1227,57,174,-59,-6},
{3,672,1243,57,177,-59,-1},
{3,343,1245,57,178,-59,4},
{3,1029,1283,57,181,-59,9},
{3,1745,1364,58,192,-58,4},
{3,1918,1388,58,192,-60,10},
{3,1637,1427,59,194,-59,16},
{3,1220,1453,58,169,-60,-1},
{3,1980,1516,58,170,-60,4},
{3,1129,1597,58,159,-60,-1},
{3,1627,1625,59,158,-61,4},
{3,1319,1651,60,159,-60,7},
{3,1025,1680,60,161,-60,9},
{3,1126,1760,60,161,-60,11},
{3,1759,1771,60,162,-60,14},
{3,1313,1814,61,162,-59,18},
{4,1227,2,61,162,-59,20},
{4,1561,2,61,191,-59,-5},
{4,1964,2,61,191,-59,-1},
{4,1154,183,62,189,-58,3},
{4,1964,197,63,188,-59,8},
{4,1220,339,63,199,-59,1},
{4,1145,376,64,197,-58,7},
{4,1483,425,64,195,-58,11},
{4,1026,585,64,157,-58,-21},
{4,1483,624,64,159,-58,-15},
{4,1026,746,64,159,-56,-9},
{4,1453,787,64,160,-56,-2},
{4,1256,957,64,161,-56,5},
{4,1693,987,64,162,-56,12},
{4,127,1026,64,163,-56,17},
{4,541,1026,65,153,-55,13},
{4,955,1026,65,154,-55,20},
{4,1761,1144,67,174,-57,6},
{4,1955,1194,67,174,-57,14},
{4,470,1200,67,153,-57,-1},
{4,884,1207,67,153,-57,5},
{4,991,1292,68,157,-56,7},
{4,467,1357,68,174,-56,-4},
{4,1946,1372,67,176,-55,0},
{4,643,1419,67,177,-55,5},
{4,2,1448,67,164,-55,-6},
{4,1720,1544,67,165,-55,-1},
{4,246,1554,67,167,-55,5},
{4,642,1600,63,176,-59,2},
{4,973,1616,62,177,-58,9},
{4,821,1713,62,177,-58,15},
{4,244,1725,63,177,-57,23},
{4,2,1773,60,158,-60,10},
{5,1160,2,63,161,-55,15},
{5,1650,2,63,162,-55,20},
{5,1580,166,63,164,-55,26},
{5,1788,201,62,192,-54,4},
{5,1717,226,62,192,-54,10},
{5,1277,396,62,194,-54,16},
{5,1026,456,62,170,-54,-2},
{5,1891,597,60,171,-54,3},
{5,1823,676,60,172,-54,10},
{5,1887,772,60,134,-54,-30},
{5,1096,838,60,134,-54,-28},
{5,1928,938,60,135,-54,-25},
{5,2,1026,60,135,-54,-23},
{5,424,1026,60,137,-54,-19},
{5,846,1026,59,139,-55,-15},
{5,1928,1077,59,142,-55,-10},
{5,2,1165,58,168,-54,-28},
{5,105,1213,58,160,-54,-32},
{5,462,1228,58,158,-54,-28},
{5,712,1254,57,157,-53,-23},
{5,1302,1330,56,166,-54,-30},
{5,1967,1370,56,165,-54,-25},
{5,479,1397,57,163,-55,-21},
{5,37,1419,57,162,-55,-16},
{5,181,1482,57,161,-55,-11},
{5,1297,1513,57,160,-55,-8},
{5,861,1576,57,160,-55,-2},
{5,516,1618,56,175,-56,-9},
{5,778,1643,56,177,-56,-5},
},
{
{3,1152,2,70,203,58,19},
{3,1567,2,70,168,56,-12},
{3,1567,174,69,176,57,-14},
{3,1152,209,69,177,57,-7},
{3,1842,231,68,173,56,-5},
{3,1975,359,68,175,56,1},
{3,1026,442,68,176,56,8},
{3,1974,538,67,176,55,14},
{3,1026,622,68,178,56,20},
{3,1418,679,68,180,56,26},
{3,1877,807,68,141,56,-11},
{3,1186,837,67,184,57,36},
{3,1724,990,67,142,57,-4},
{3,1186,1025,67,188,57,46},
{3,482,1026,67,145,57,5},
{3,881,1026,67,143,57,7},
{3,1371,1096,68,145,58,11},
{3,1777,1212,68,148,58,16},
{3,127,1227,68,149,58,21},
{3,199,1230,68,152,58,26},
{3,271,1245,68,153,58,31},
{3,1637,1284,68,139,58,-21},
{3,857,1376,68,139,58,-15},
{3,769,1423,68,139,58,-9},
{3,1147,1453,69,140,59,-4},
{3,2,1460,69,141,59,1},
{3,841,1519,69,146,59,2},
{3,741,1566,69,160,59,-4},
{3,363,1622,70,161,60,1},
{3,656,1633,70,163,60,5},
{3,951,1680,70,158,60,4},
{3,730,1730,70,160,60,8},
{3,359,1787,69,162,59,14},
{3,634,1800,69,164,59,18},
{4,1154,2,69,177,59,13},
{4,1626,2,68,145,58,-17},
{4,1626,151,68,146,58,-12},
{4,1698,183,69,149,57,-7},
{4,1842,219,69,152,57,0},
{4,1339,361,69,155,57,5},
{4,1026,423,68,158,56,10},
{4,1590,479,68,159,56,15},
{4,1134,577,68,162,56,20},
{4,1588,642,68,163,56,25},
{4,1256,763,68,190,56,4},
{4,1698,785,67,198,55,2},
{4,1026,909,68,198,56,10},
{4,1541,975,67,202,57,12},
{4,1975,987,67,203,57,19},
{4,470,1026,67,170,57,-8},
{4,884,1026,67,177,57,-13},
{4,1024,1111,66,177,58,-7},
{4,541,1183,62,174,54,-4},
{4,270,1194,62,174,54,2},
{4,1129,1205,62,175,54,9},
{4,1879,1260,63,176,57,14},
{4,539,1361,64,177,58,21},
{4,267,1372,64,178,58,28},
{4,759,1435,66,178,56,34},
{4,979,1453,66,159,56,21},
{4,829,1552,66,157,56,27},
{4,1326,1576,66,156,56,32},
{4,2,1616,66,153,56,37},
{4,751,1617,66,151,56,43},
{4,1714,1713,66,150,56,48},
{4,1326,1736,66,150,56,52},
{4,743,1772,66,150,56,54},
{5,1227,2,66,145,56,33},
{5,1580,2,66,160,56,54},
{5,1227,151,66,187,56,27},
{5,1297,223,66,169,56,15},
{5,1972,227,66,168,56,20},
{5,1783,397,67,168,55,24},
{5,1891,425,66,168,56,28},
{5,1753,569,66,167,54,31},
{5,1026,634,66,166,54,36},
{5,1750,740,66,181,54,25},
{5,1026,804,66,182,54,28},
{5,1858,910,66,182,54,30},
{5,1026,990,66,160,54,8},
{5,354,1026,66,163,54,13},
{5,777,1026,65,155,55,5},
{5,1579,1077,65,156,55,8},
{5,1025,1154,66,157,56,11},
{5,354,1193,66,165,56,5},
{5,1897,1223,66,165,56,9},
{5,643,1254,65,150,57,0},
{5,1021,1315,65,152,57,6},
{5,337,1362,65,154,57,10},
{5,1893,1392,66,156,58,16},
{5,861,1415,68,157,56,21},
{5,1017,1471,68,159,56,27},
{5,277,1520,68,190,56,2},
{5,1877,1552,69,198,57,2},
{5,922,1598,69,198,57,10},
{5,703,1643,71,201,57,13},
},
{
{3,1026,2,122,231,-2,-9},
{3,1439,2,124,223,-2,-17},
{3,1854,2,122,225,-2,-15},
{3,1679,216,121,221,-1,-19},
{3,1442,229,121,223,-1,-21},
{3,1142,390,120,221,0,-19},
{3,1656,441,120,220,0,-18},
{3,1440,456,120,219,0,-19},
{3,1132,615,123,218,3,-20},
{3,1624,665,122,221,4,-17},
{3,1026,837,122,225,4,-13},
{3,1371,864,122,228,4,-10},
{3,1870,952,122,216,4,-22},
{3,2,1026,121,215,3,-23},
{3,298,1026,121,215,3,-23},
{3,697,1026,120,213,0,-23},
{3,993,1066,114,213,-2,-23},
{3,1864,1172,116,212,-6,-24},
{3,1186,1227,111,222,-3,-14},
{3,552,1231,116,211,2,-25},
{3,2,1245,113,211,-5,-25},
{3,1515,1303,118,212,4,-24},
{3,119,1386,118,216,4,-20},
{3,241,1427,118,216,4,-20},
{3,534,1446,118,222,4,-14},
{3,967,1468,122,208,2,-28},
{3,1700,1560,124,207,0,-29},
{3,1828,1599,119,207,5,-29},
{3,113,1606,119,206,5,-30},
{3,236,1647,119,205,5,-31},
{3,511,1672,119,205,5,-31},
{3,1419,1767,124,205,0,-31},
{3,1190,1796,119,209,5,-27},
{3,1823,1810,119,209,-5,-27},
{4,1026,2,124,209,0,-29},
{4,1436,2,121,211,-3,-27},
{4,1842,2,118,213,-6,-25},
{4,1026,215,115,204,-3,-34},
{4,1433,217,118,204,-6,-34},
{4,1705,370,112,204,-12,-34},
{4,1892,416,112,221,-12,-17},
{4,1213,556,125,203,1,-35},
{4,1699,578,110,203,-10,-35},
{4,1859,641,110,212,-10,-28},
{4,1132,763,120,207,-4,-33},
{4,1851,857,120,209,-2,-31},
{4,1416,951,121,205,-3,-35},
{4,1098,974,116,227,-8,-13},
{4,2,1026,121,206,-3,-34},
{4,340,1026,126,206,0,-34},
{4,755,1026,125,206,-1,-34},
{4,1218,1138,125,209,-1,-31},
{4,1436,1181,125,208,-1,-34},
{4,2,1236,126,208,-2,-34},
{4,336,1236,127,208,-3,-34},
{4,1723,1322,127,218,-3,-24},
{4,1195,1351,127,214,-3,-36},
{4,1063,1386,127,211,-3,-33},
{4,1423,1393,128,228,-4,-16},
{4,335,1448,128,212,-4,-32},
{4,467,1542,128,217,-4,-27},
{4,1194,1569,128,219,-4,-25},
{4,1049,1601,128,222,-4,-22},
{4,1396,1625,129,219,-5,-25},
{4,317,1664,129,226,-5,-18},
{4,450,1763,129,222,-5,-22},
{4,1181,1792,128,225,-6,-19},
{5,1026,2,130,226,-6,-18},
{5,1446,2,130,218,-6,-26},
{5,1866,2,130,218,-6,-26},
{5,1410,224,130,220,-6,-24},
{5,1026,232,130,220,-6,-24},
{5,1619,422,130,226,-6,-18},
{5,1405,448,130,230,-6,-14},
{5,1235,594,130,221,-6,-23},
{5,1616,652,130,229,-6,-31},
{5,1477,760,130,222,-6,-22},
{5,1210,819,130,233,-6,-25},
{5,1684,925,129,223,-5,-21},
{5,1446,986,129,225,-5,-23},
{5,221,1026,129,223,-5,-21},
{5,643,1026,130,224,-4,-20},
{5,1199,1056,129,224,-3,-20},
{5,1684,1152,126,224,-6,-20},
{5,777,1185,127,226,-5,-22},
{5,1463,1237,127,225,-5,-19},
{5,207,1253,126,225,-6,-19},
{5,1173,1284,125,225,-5,-19},
{5,1668,1380,126,224,-4,-18},
{5,603,1415,125,224,-5,-18},
{5,732,1415,125,224,-5,-18},
{5,1446,1466,124,224,-4,-18},
{5,1170,1513,123,224,-3,-18},
{5,389,1582,123,223,-3,-17},
{5,1668,1608,123,223,-3,-17},
{5,576,1643,123,222,-3,-18},
},
}}
local starlightLow={pixels=96,pages=starlightPages,bands={
{
{1,1263,2,24,111,-60,-27},
{1,1552,2,24,118,-60,-30},
{1,1810,2,24,124,-60,-32},
{1,1164,121,24,130,-60,-32},
{1,1523,134,23,135,-59,-33},
{1,1837,135,23,138,-59,-32},
{1,1374,154,23,139,-59,-31},
{1,1163,255,23,140,-59,-28},
{1,1864,276,23,140,-59,-26},
{1,1761,293,22,139,-58,-23},
{1,1233,391,22,138,-58,-22},
{1,1524,396,22,137,-58,-19},
{1,1618,431,22,136,-58,-18},
{1,1550,513,22,135,-58,-15},
{1,1686,528,21,133,-57,-13},
{1,1576,560,23,130,-59,-12},
{1,1408,591,23,131,-59,-11},
{1,1681,665,23,115,-59,-25},
{1,1106,686,23,116,-59,-22},
{1,1373,722,23,117,-59,-19},
{1,1529,768,23,120,-59,-16},
{1,1758,808,23,121,-59,-13},
{1,1271,830,23,122,-59,-10},
{1,1458,883,23,123,-59,-7},
{1,1751,933,23,123,-59,-5},
{1,1368,947,23,123,-59,-3},
{1,1592,982,23,123,-59,-1},
{1,46,1026,23,122,-59,0},
{1,324,1026,23,121,-59,1},
{1,605,1026,23,121,-59,1},
{1,912,1026,22,118,-60,2},
{1,1321,1064,22,118,-60,2},
{1,2024,1077,22,116,-60,4},
{1,1255,1090,22,117,-60,7},
{1,1281,1134,22,118,-60,10},
{1,73,1140,22,118,-60,12},
{1,917,1148,22,117,-60,13},
{1,631,1156,22,127,-60,5},
{1,1747,1177,21,129,-61,1},
{1,1096,1198,22,131,-60,-1},
{1,1384,1217,22,133,-60,-5},
{1,372,1242,22,134,-60,-6},
{1,917,1269,22,134,-60,-8},
{1,1503,1276,22,134,-60,-10},
{1,886,1294,23,134,-59,-12},
{1,1475,1310,23,133,-59,-13},
{1,1175,1345,23,128,-59,-16},
{1,528,1362,23,111,-59,-31},
{1,354,1380,23,111,-59,-27},
{1,50,1405,24,118,-60,-30},
{1,679,1414,23,125,-59,-31},
{1,2005,1429,23,130,-59,-32},
{1,1068,1445,23,135,-59,-33},
{1,1764,1473,23,138,-59,-32},
{1,1575,1481,24,139,-58,-31},
{1,2,1512,24,140,-58,-28},
{1,484,1525,24,140,-58,-26},
{1,1392,1559,24,139,-58,-23},
{1,884,1578,24,138,-58,-22},
{1,1921,1594,24,137,-58,-19},
{1,1420,1605,24,136,-58,-18},
{1,1565,1624,24,135,-58,-15},
{1,2,1656,23,133,-57,-13},
{1,473,1669,25,131,-59,-11},
{1,280,1689,25,129,-59,-9},
{1,747,1697,25,126,-59,-8},
{1,1908,1735,25,112,-59,-18},
{1,1733,1752,25,112,-59,-14},
{1,1474,1783,26,113,-60,-9},
{1,1684,1796,26,114,-60,-6},
{1,1504,1823,26,115,-60,-3},
{1,1372,1837,26,116,-60,0},
{1,493,1861,26,115,-60,3},
{1,1402,1877,26,116,-60,4},
{2,1239,2,26,118,-60,4},
{2,1533,2,26,118,-60,4},
{2,1828,2,26,119,-60,3},
{2,1116,119,26,119,-60,3},
{2,1828,125,26,118,-60,2},
{2,1315,155,26,118,-60,0},
{2,1393,212,26,119,-60,1},
{2,1815,247,26,121,-60,3},
{2,1345,269,26,123,-60,5},
{2,1248,292,26,123,-60,5},
{2,1143,363,26,123,-60,7},
{2,1341,396,26,127,-60,5},
{2,1639,442,21,129,-63,1},
{2,1664,453,24,131,-60,-1},
{2,1115,506,24,133,-60,-3},
{2,1604,531,24,134,-60,-6},
{2,1489,591,24,134,-60,-8},
{2,1114,643,24,134,-60,-10},
{2,1919,667,24,134,-60,-12},
{2,1477,729,24,133,-60,-13},
{2,1238,778,24,129,-60,-15},
{2,1411,808,24,110,-60,-32},
},
{
{1,1234,2,25,127,-21,-19},
{1,1523,2,25,128,-21,-16},
{1,1838,2,23,129,-23,-13},
{1,1443,121,23,130,-23,-10},
{1,1234,133,25,130,-23,-8},
{1,1470,147,26,131,-22,-5},
{1,1935,154,26,130,-22,-4},
{1,1426,255,26,132,-22,-4},
{1,1800,276,26,132,-22,-4},
{1,1917,288,26,133,-22,-5},
{1,1550,377,26,132,-22,-4},
{1,1160,399,26,131,-22,-3},
{1,1711,428,26,130,-22,-2},
{1,1784,511,26,131,-22,-5},
{1,1814,532,26,133,-22,-9},
{1,1242,540,26,135,-22,-11},
{1,1603,571,25,133,-21,-13},
{1,1435,661,25,134,-21,-12},
{1,1500,675,25,133,-21,-11},
{1,1576,708,25,132,-21,-10},
{1,1400,726,25,130,-21,-8},
{1,1429,799,25,128,-21,-6},
{1,1488,812,25,127,-21,-5},
{1,1398,860,25,127,-21,-7},
{1,1183,917,25,127,-21,-7},
{1,1485,943,25,127,-21,-7},
{1,1395,991,25,109,-21,-21},
{1,73,1026,25,110,-21,-20},
{1,351,1026,25,111,-21,-19},
{1,576,1026,25,112,-21,-20},
{1,857,1026,25,112,-21,-20},
{1,1747,1060,25,113,-21,-19},
{1,1479,1074,25,112,-21,-18},
{1,1990,1086,25,112,-21,-16},
{1,1591,1109,24,112,-20,-16},
{1,2,1137,24,112,-20,-14},
{1,1449,1143,24,112,-20,-12},
{1,278,1157,24,113,-20,-11},
{1,1419,1185,24,112,-20,-10},
{1,1230,1211,24,112,-20,-8},
{1,1581,1225,24,111,-20,-7},
{1,1447,1259,24,111,-20,-7},
{1,299,1276,24,110,-20,-6},
{1,1867,1290,24,109,-20,-5},
{1,1410,1301,23,108,-19,-4},
{1,1072,1333,23,108,-19,-2},
{1,1202,1345,23,107,-19,-1},
{1,1772,1363,23,106,-19,0},
{1,1257,1381,23,106,-19,2},
{1,913,1407,23,108,-19,4},
{1,1502,1414,23,110,-19,8},
{1,407,1431,23,110,-19,10},
{1,1462,1447,23,126,-19,-2},
{1,528,1477,23,128,-19,-2},
{1,940,1499,23,130,-19,-2},
{1,913,1519,23,131,-19,-3},
{1,601,1541,22,133,-18,-3},
{1,2028,397,17,134,-13,-4},
{1,2028,785,17,133,-13,-3},
{1,312,1602,24,131,-20,-3},
{1,512,1609,24,132,-20,-6},
{1,1229,1620,23,135,-19,-9},
{1,912,1654,23,136,-21,-12},
{1,587,1678,23,138,-21,-14},
{1,783,1694,23,139,-21,-19},
{1,174,1697,23,142,-21,-20},
{1,883,1720,23,144,-21,-22},
{1,441,1742,23,145,-21,-23},
{1,1563,1763,23,147,-21,-25},
{1,2,1793,23,148,-21,-26},
{1,144,1819,23,149,-21,-27},
{1,1444,1836,23,149,-21,-29},
{1,1191,1860,24,149,-22,-29},
{1,882,1868,24,132,-22,-46},
{2,1211,2,24,133,-22,-45},
{2,1505,2,24,133,-22,-43},
{2,1800,2,24,134,-22,-42},
{2,1755,93,24,133,-22,-41},
{2,1533,124,24,132,-22,-40},
{2,1287,135,24,132,-22,-40},
{2,1956,155,24,132,-22,-38},
{2,1115,242,24,131,-22,-37},
{2,1287,271,24,131,-22,-37},
{2,1649,309,24,129,-22,-37},
{2,1962,365,24,130,-22,-36},
{2,1115,377,24,125,-22,-39},
{2,1306,415,25,125,-21,-37},
{2,1371,473,25,124,-21,-36},
{2,1271,525,25,125,-21,-35},
{2,1931,539,25,124,-21,-34},
{2,1780,598,25,126,-21,-30},
{2,1237,648,25,126,-21,-28},
{2,1292,669,25,128,-21,-26},
{2,1355,729,25,129,-21,-23},
{2,1077,770,25,128,-21,-22},
{2,1591,801,25,128,-21,-20},
},
{
{1,1291,2,21,123,25,-9},
{1,1580,2,21,124,25,-12},
{1,1865,2,20,114,24,-24},
{1,2025,2,20,116,24,-24},
{1,1865,120,16,117,28,-25},
{1,2025,122,21,118,23,-24},
{1,1401,242,21,118,23,-22},
{1,1234,267,21,120,23,-18},
{1,1830,277,21,123,23,-17},
{1,1593,305,21,126,23,-16},
{1,1499,396,21,129,23,-15},
{1,1259,404,21,132,23,-12},
{1,1372,432,22,133,24,-9},
{1,1448,524,22,133,24,-5},
{1,1216,533,22,133,24,-1},
{1,1524,537,22,134,24,2},
{1,1322,606,21,133,25,5},
{1,2024,649,21,132,25,6},
{1,1236,679,21,135,25,3},
{1,1605,708,20,137,24,1},
{1,1464,740,20,139,24,-1},
{1,1816,773,20,139,24,-3},
{1,1556,844,20,138,24,-4},
{1,1517,892,20,135,24,-5},
{1,1104,940,20,132,24,-6},
{1,1917,952,20,130,24,-6},
{1,1297,1003,20,127,24,-5},
{1,102,1026,20,122,24,-8},
{1,380,1026,20,107,24,-19},
{1,658,1026,21,109,25,-17},
{1,938,1026,21,112,25,-16},
{1,1424,1067,21,114,25,-16},
{1,1103,1076,21,118,25,-18},
{1,1128,1104,20,121,26,-21},
{1,254,1136,20,122,26,-22},
{1,658,1139,20,122,26,-22},
{1,324,1151,20,121,26,-21},
{1,402,1168,20,119,26,-21},
{1,2019,1197,20,116,26,-20},
{1,1645,1213,20,112,26,-20},
{1,348,1242,20,109,26,-19},
{1,248,1262,20,109,26,-21},
{1,657,1265,20,107,26,-23},
{1,398,1291,21,106,27,-24},
{1,681,1307,21,103,27,-25},
{1,1747,1310,21,102,27,-24},
{1,1099,1352,21,101,27,-21},
{1,1437,1374,21,105,27,-21},
{1,1799,1400,21,109,27,-23},
{1,993,1408,21,113,27,-23},
{1,1739,1416,21,116,27,-24},
{1,1124,1352,20,117,28,-23},
{1,1955,1451,20,118,28,-24},
{1,1145,1481,22,118,26,-24},
{1,1436,1483,22,118,26,-22},
{1,967,1499,22,120,26,-18},
{1,679,1543,22,123,26,-17},
{1,783,1562,22,126,26,-16},
{1,1462,1577,22,130,26,-14},
{1,340,1602,22,132,26,-12},
{1,1743,1615,22,133,26,-9},
{1,1256,1634,22,133,26,-5},
{1,1367,1612,21,133,25,-1},
{1,722,1688,21,134,25,2},
{1,810,1694,21,133,25,5},
{1,1392,1702,21,131,25,7},
{1,1117,1731,21,134,25,4},
{1,549,1749,21,137,25,1},
{1,29,1772,21,139,25,-1},
{1,468,1804,21,139,25,-3},
{1,1534,1823,21,139,25,-5},
{1,171,1843,21,135,25,-5},
{1,523,1861,21,132,25,-6},
{1,1996,1880,21,130,25,-6},
{2,1296,2,21,127,25,-5},
{2,1590,2,21,126,25,-4},
{2,1885,2,22,124,24,-2},
{2,1173,121,22,124,24,0},
{2,1885,130,22,123,24,1},
{2,1858,133,22,127,24,-3},
{2,1423,212,22,130,24,-6},
{2,1173,249,22,133,24,-9},
{2,1315,277,22,134,24,-10},
{2,1375,335,22,134,24,-10},
{2,1990,365,22,132,24,-10},
{2,1217,401,22,131,24,-9},
{2,1934,406,22,129,24,-7},
{2,1143,490,22,127,24,-5},
{2,1578,531,22,125,24,-5},
{2,1842,571,22,125,24,-5},
{2,1363,601,22,124,24,-6},
{2,1266,654,22,124,24,-6},
{2,1675,696,22,122,24,-6},
{2,1169,760,22,121,24,-5},
{2,1321,781,22,118,24,-4},
{2,1439,808,21,120,25,-6},
},
{
{1,1207,2,23,139,61,-7},
{1,1496,2,23,141,61,-5},
{1,1783,2,23,142,61,-4},
{1,1263,117,23,142,61,-2},
{1,1810,130,23,142,61,0},
{1,1774,148,22,141,62,1},
{1,1069,156,22,138,62,2},
{1,1263,263,22,137,62,3},
{1,1891,276,22,134,62,4},
{1,1374,297,22,131,62,3},
{1,1190,395,22,128,62,4},
{1,1837,404,22,124,62,4},
{1,1580,435,22,121,62,5},
{1,1190,527,22,119,62,5},
{1,1160,534,22,98,62,-18},
{1,2024,545,22,100,62,-16},
{1,1474,630,22,106,62,-18},
{1,1550,652,22,112,62,-20},
{1,1924,692,22,119,62,-21},
{1,1347,722,22,123,62,-23},
{1,1791,773,21,127,61,-23},
{1,1106,806,22,130,60,-24},
{1,1921,815,22,133,60,-23},
{1,1298,866,22,133,60,-21},
{1,1427,931,22,132,60,-20},
{1,2024,943,22,130,60,-18},
{1,1271,956,22,130,60,-16},
{1,1453,1010,22,129,60,-15},
{1,298,1026,22,127,60,-13},
{1,632,1026,22,126,60,-12},
{1,886,1026,22,124,60,-10},
{1,1514,1031,22,122,60,-8},
{1,1964,1086,22,108,60,-18},
{1,1393,1104,22,109,60,-15},
{1,532,1136,22,108,60,-12},
{1,558,1142,22,107,60,-9},
{1,30,1152,22,108,60,-8},
{1,1508,1157,22,115,60,-15},
{1,1477,1190,22,116,60,-16},
{1,1619,1213,22,118,60,-18},
{1,1122,1229,22,119,60,-21},
{1,1258,1256,22,121,60,-21},
{1,272,1274,23,125,61,-19},
{1,625,1287,23,127,61,-17},
{1,423,1299,23,128,61,-14},
{1,1230,1327,23,130,61,-10},
{1,1148,1345,23,132,61,-8},
{1,327,1355,23,135,61,-7},
{1,652,1376,23,138,61,-6},
{1,381,1401,22,141,60,-5},
{1,1410,1413,22,142,60,-4},
{1,1979,1429,22,142,60,-2},
{1,886,1432,23,142,59,0},
{1,1365,1467,23,141,59,1},
{1,1256,1491,23,139,59,1},
{1,652,1518,23,137,59,3},
{1,1489,1528,23,134,59,4},
{1,756,1562,23,131,59,3},
{1,809,1562,23,128,59,4},
{1,1126,1603,23,124,59,4},
{1,1202,1620,23,121,59,5},
{1,30,1650,23,118,59,4},
{1,1488,1666,22,113,60,-3},
{1,208,1689,22,115,60,-5},
{1,148,1697,22,117,60,-7},
{1,1448,1711,22,121,60,-11},
{1,415,1742,22,125,60,-15},
{1,1417,1745,23,128,59,-18},
{1,1251,1771,23,130,59,-20},
{1,910,1794,24,132,60,-22},
{1,574,1820,23,133,59,-23},
{1,797,1837,23,132,59,-22},
{1,1219,1860,23,132,59,-20},
{1,402,1871,23,131,59,-19},
{2,1269,2,23,129,59,-17},
{2,1563,2,23,128,59,-16},
{2,1858,2,23,127,59,-13},
{2,1146,121,23,126,59,-12},
{2,1999,128,23,124,59,-10},
{2,1504,139,24,122,60,-8},
{2,1698,223,24,109,60,-19},
{2,1143,251,24,108,60,-16},
{2,1934,291,24,111,60,-15},
{2,1677,336,24,113,60,-15},
{2,2016,365,24,115,60,-15},
{2,1278,406,24,115,60,-15},
{2,1243,419,24,116,60,-16},
{2,2016,484,24,118,60,-18},
{2,1335,527,24,119,60,-21},
{2,1300,544,24,121,60,-21},
{2,1809,598,23,125,61,-19},
{2,1328,650,23,127,61,-17},
{2,1868,680,23,129,61,-13},
{2,1142,736,23,130,61,-10},
{2,1106,781,23,132,61,-8},
{2,1384,808,23,136,61,-8},
},
{
{1,1164,2,39,115,-37,-5},
{1,1453,2,39,115,-37,-3},
{1,1741,2,38,116,-38,0},
{1,1401,119,38,119,-38,3},
{1,1552,130,38,120,-38,6},
{1,1192,145,38,122,-38,-4},
{1,1026,156,39,118,-39,-12},
{1,1550,254,39,119,-39,-9},
{1,1190,271,39,120,-39,-6},
{1,1456,282,39,121,-39,-3},
{1,1618,305,39,122,-39,0},
{1,1450,407,39,113,-39,-7},
{1,1026,423,39,114,-39,-4},
{1,1741,436,39,116,-39,0},
{1,1644,528,38,124,-40,-4},
{1,1026,541,39,127,-39,-1},
{1,1365,591,39,127,-39,3},
{1,1150,650,39,128,-39,6},
{1,1193,670,39,117,-39,-3},
{1,1261,708,39,118,-39,0},
{1,1304,743,39,119,-39,3},
{1,1184,791,39,122,-39,6},
{1,1227,830,40,129,-40,3},
{1,1580,849,40,129,-40,7},
{1,1707,905,40,130,-40,10},
{1,1324,947,40,113,-40,-1},
{1,1128,987,40,113,-40,3},
{1,2,1026,40,107,-40,-1},
{1,254,1026,40,106,-40,2},
{1,532,1026,40,106,-40,4},
{1,811,1026,42,108,-40,6},
{1,1701,1039,42,108,-40,8},
{1,1347,1074,42,109,-40,9},
{1,1776,1114,42,109,-40,11},
{1,963,1138,42,109,-40,13},
{1,481,1140,42,129,-40,-3},
{1,584,1151,43,128,-39,0},
{1,99,1168,43,127,-39,3},
{1,426,1168,43,127,-39,5},
{1,1534,1202,43,133,-39,1},
{1,1772,1227,43,132,-39,4},
{1,527,1253,44,105,-38,-19},
{1,473,1273,44,106,-38,-14},
{1,1819,1290,44,106,-38,-10},
{1,79,1299,44,107,-38,-5},
{1,1979,1317,44,108,-38,-2},
{1,196,1340,44,109,-38,3},
{1,1362,1354,44,109,-38,7},
{1,555,1396,43,110,-37,12},
{1,2,1405,44,103,-36,9},
{1,78,1410,44,103,-36,13},
{1,836,1426,46,117,-38,5},
{1,706,1444,46,117,-38,9},
{1,1095,1473,46,103,-38,-1},
{1,323,1495,46,103,-38,3},
{1,434,1525,46,105,-38,5},
{1,993,1525,46,117,-38,-3},
{1,373,1546,47,118,-37,0},
{1,705,1565,45,119,-37,3},
{1,1603,1593,46,110,-36,-4},
{1,1516,1603,45,111,-37,-1},
{1,540,1632,43,113,-39,3},
{1,627,1659,43,119,-39,1},
{1,836,1670,43,119,-39,7},
{1,234,1689,42,119,-40,11},
{1,1860,1705,44,119,-38,15},
{1,309,1738,40,107,-40,7},
{1,502,1749,43,108,-37,10},
{1,614,1782,43,109,-37,13},
{1,835,1793,43,111,-37,17},
{1,201,1812,42,129,-36,3},
{1,1852,1828,42,129,-36,7},
{1,296,1849,42,130,-36,10},
{1,1714,1868,42,114,-36,-2},
{2,1165,2,42,115,-36,3},
{2,1459,2,42,115,-36,7},
{2,1755,2,41,87,-35,-17},
{2,1410,118,42,90,-36,-18},
{2,1706,128,42,91,-36,-17},
{2,1783,140,41,91,-37,-15},
{2,1911,155,41,92,-37,-12},
{2,1561,246,40,94,-36,-10},
{2,1498,265,40,95,-36,-7},
{2,1605,309,40,113,-36,-19},
{2,1490,364,40,107,-36,-21},
{2,1173,401,40,106,-36,-18},
{2,1534,450,40,105,-36,-15},
{2,1490,475,38,112,-36,-20},
{2,1169,511,38,111,-36,-17},
{2,1532,559,38,110,-36,-14},
{2,1632,588,39,109,-37,-11},
{2,1194,648,39,108,-37,-8},
{2,1517,673,39,107,-37,-5},
{2,1625,701,39,107,-37,-1},
{2,1195,778,39,118,-37,-6},
{2,1895,805,39,119,-37,-3},
},
{
{1,1112,2,48,136,38,12},
{1,1401,2,48,113,38,-7},
{1,1690,2,47,119,37,-9},
{1,1974,2,47,119,37,-5},
{1,1974,125,47,117,37,-3},
{1,1112,142,47,117,37,1},
{1,1885,154,46,118,36,6},
{1,1095,263,46,118,36,10},
{1,1500,273,46,119,36,13},
{1,1026,298,47,121,37,17},
{1,1400,391,46,95,38,-7},
{1,1787,412,46,95,38,-5},
{1,1661,428,46,96,38,-2},
{1,1398,490,46,97,38,1},
{1,1474,529,46,97,38,3},
{1,1711,562,46,96,38,4},
{1,1272,606,46,98,38,8},
{1,1632,656,45,99,39,11},
{1,1791,669,46,100,38,14},
{1,1950,692,47,102,39,18},
{1,1133,782,47,103,39,21},
{1,1707,808,47,93,39,-15},
{1,1347,849,47,94,39,-10},
{1,1132,889,47,94,39,-6},
{1,1785,916,47,94,39,-2},
{1,1212,963,47,96,39,0},
{1,1541,986,47,98,39,2},
{1,1778,1014,47,96,39,8},
{1,203,1026,47,109,39,1},
{1,481,1026,47,110,39,4},
{1,760,1026,47,106,39,2},
{1,963,1026,47,108,39,6},
{1,1913,1086,47,109,39,9},
{1,1540,1088,47,110,39,12},
{1,203,1139,47,88,39,-8},
{1,351,1141,47,97,39,-11},
{1,1696,1151,47,98,39,-8},
{1,146,1168,47,100,37,-4},
{1,1905,1199,47,102,37,0},
{1,1956,1202,47,103,37,3},
{1,197,1231,47,105,37,7},
{1,943,1251,47,107,37,9},
{1,146,1272,46,109,38,13},
{1,575,1283,46,109,38,17},
{1,836,1294,46,128,38,2},
{1,706,1307,46,133,38,1},
{1,1609,1335,46,133,38,7},
{1,943,1362,46,133,38,11},
{1,127,1385,46,136,38,12},
{1,1824,1403,46,113,38,-7},
{1,1018,1408,46,113,38,-3},
{1,602,1418,46,119,38,-5},
{1,177,1453,42,117,36,-3},
{1,1608,1472,42,117,36,1},
{1,1529,1481,42,118,36,6},
{1,555,1510,42,118,36,10},
{1,30,1527,44,119,38,15},
{1,836,1547,44,119,38,19},
{1,160,1574,44,119,38,23},
{1,1872,1594,45,107,37,15},
{1,1153,1620,45,106,37,18},
{1,424,1634,45,104,37,22},
{1,366,1668,45,103,37,25},
{1,674,1688,44,101,38,29},
{1,1684,1692,45,100,37,32},
{1,1514,1718,45,101,37,35},
{1,1153,1730,45,101,37,37},
{1,1202,1759,45,97,37,21},
{1,353,1775,45,108,37,36},
{1,661,1793,45,115,37,7},
{1,247,1822,45,114,37,10},
{1,1142,1835,45,113,37,13},
{1,1898,1851,45,112,37,16},
{1,1947,1880,45,114,37,18},
{2,1116,2,45,113,37,21},
{2,1410,2,45,112,37,24},
{2,1706,2,45,122,37,16},
{2,1999,2,45,122,37,18},
{2,1456,121,44,108,36,6},
{2,1561,134,44,108,36,6},
{2,1345,155,44,110,36,8},
{2,1449,233,45,104,37,4},
{2,1984,256,45,105,37,5},
{2,1199,292,45,105,37,7},
{2,1542,344,45,102,37,-6},
{2,1794,388,45,100,37,-4},
{2,1591,426,44,101,38,-1},
{2,1794,492,44,102,38,4},
{2,1960,501,44,103,38,7},
{2,1211,539,44,105,38,11},
{2,1868,571,47,105,37,15},
{2,1143,626,47,106,37,18},
{2,1574,669,47,128,37,2},
{2,1809,727,47,133,37,1},
{2,1026,770,47,133,37,7},
{2,1266,801,48,135,38,9},
},
{
{1,1026,2,82,150,-2,-12},
{1,1316,2,81,148,-1,-12},
{1,1605,2,81,148,-1,-12},
{1,1889,2,81,148,-1,-12},
{1,1690,125,80,148,-2,-12},
{1,1290,154,80,147,-2,-13},
{1,1594,154,80,147,-2,-13},
{1,1965,246,79,147,-1,-13},
{1,1678,277,79,147,-1,-13},
{1,1289,305,79,149,-1,-11},
{1,1077,385,79,150,-1,-8},
{1,1947,397,77,144,-1,-14},
{1,1863,425,77,144,-1,-14},
{1,1284,458,77,144,-1,-14},
{1,1069,539,77,143,-1,-15},
{1,1944,545,76,143,-2,-15},
{1,1844,573,76,142,-2,-16},
{1,1711,662,76,142,-2,-16},
{1,1026,686,76,149,-2,-9},
{1,1841,719,76,141,-2,-17},
{1,1629,784,74,141,-2,-17},
{1,1950,798,74,141,-2,-17},
{1,1026,839,74,140,-2,-18},
{1,1840,864,73,140,-3,-18},
{1,1624,929,73,139,-3,-19},
{1,1947,943,73,139,-3,-19},
{1,1026,983,73,139,-3,-19},
{1,1836,1008,73,138,-3,-20},
{1,126,1026,73,138,-3,-20},
{1,404,1026,73,138,-5,-20},
{1,683,1026,73,137,-5,-21},
{1,1172,1063,79,137,1,-21},
{1,1619,1072,73,137,-5,-21},
{1,1014,1126,78,137,0,-21},
{1,760,1138,77,136,-1,-22},
{1,1822,1150,79,136,1,-22},
{1,841,1154,72,136,-6,-22},
{1,682,1167,72,136,-6,-22},
{1,1307,1187,73,136,-7,-22},
{1,1152,1204,74,137,-6,-23},
{1,1669,1253,74,148,-6,-12},
{1,2,1264,73,137,-7,-23},
{1,994,1267,74,137,-8,-23},
{1,758,1278,74,137,-8,-23},
{1,1895,1309,80,138,-2,-22},
{1,1284,1327,74,140,-8,-20},
{1,1529,1340,75,137,-7,-23},
{1,450,1383,74,138,-8,-22},
{1,244,1403,75,138,-9,-24},
{1,1659,1405,76,138,-8,-24},
{1,756,1419,76,139,-8,-23},
{1,1874,1451,77,139,-9,-23},
{1,1284,1471,77,139,-9,-23},
{1,1175,1477,77,139,-9,-23},
{1,1791,1520,77,140,-9,-22},
{1,78,1525,78,140,-8,-22},
{1,223,1545,85,140,-3,-22},
{1,1654,1547,85,141,-3,-21},
{1,1955,1575,79,152,-9,-10},
{1,1043,1584,79,142,-9,-20},
{1,1283,1614,80,142,-8,-20},
{1,940,1646,87,142,-3,-20},
{1,1769,1664,87,143,-3,-19},
{1,57,1669,87,146,-3,-16},
{1,1593,1707,87,146,-3,-18},
{1,1031,1730,82,145,-8,-19},
{1,1949,1731,86,145,-4,-19},
{1,1282,1760,86,152,-4,-12},
{1,939,1792,87,146,-3,-18},
{1,1762,1811,86,147,-4,-17},
{1,54,1819,86,147,-4,-17},
{1,710,1837,83,147,-7,-17},
{1,1590,1857,83,147,-7,-17},
{1,1030,1879,86,148,-4,-16},
{2,1026,2,86,148,-4,-16},
{2,1321,2,85,149,-5,-15},
{2,1615,2,87,149,-3,-15},
{2,1911,2,84,149,-6,-15},
{2,1199,139,84,149,-6,-15},
{2,1026,154,85,150,-5,-14},
{2,1609,155,85,150,-5,-14},
{2,1726,235,85,149,-5,-13},
{2,1845,264,85,149,-5,-13},
{2,1026,308,85,150,-5,-12},
{2,1401,346,85,150,-3,-12},
{2,1705,388,85,150,-3,-12},
{2,1843,417,84,150,-4,-12},
{2,1026,462,85,150,-3,-12},
{2,1400,500,85,150,-3,-12},
{2,1692,542,84,150,-2,-12},
{2,1960,608,84,150,-2,-12},
{2,1026,616,84,150,-2,-12},
{2,1389,654,84,150,-2,-12},
{2,1701,728,84,150,-2,-12},
{2,1947,762,82,150,-2,-12},
{2,1505,801,82,150,-2,-12},
},
}}
E.TranquilityStarlight={fps=48,stride=2,intro=36,hold=192,ending=54,width=400,startOpacity={{0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0090459,0.0345007,0.0738400,0.1245393,0.1840741,0.2499200,0.3195526,0.3904474,0.4600800,0.5259259,0.5854607,0.6361600,0.6754993,0.7009541,0.7100000,0.7128924,0.7210971,0.7339060,0.7506106,0.7705027,0.7928740,0.8170161,0.8422207,0.8677794,0.8929839,0.9171260,0.9394972,0.9593894,0.9760940,0.9889029,0.9971077,1.0000000},{0.0000000,0.0000000,0.0090459,0.0345007,0.0738400,0.1245393,0.1840741,0.2499200,0.3195526,0.3904474,0.4600800,0.5259259,0.5854607,0.6361600,0.6754993,0.7009541,0.7100000,0.7121025,0.7181200,0.7276175,0.7401600,0.7553125,0.7726400,0.7917075,0.8120800,0.8333225,0.8550000,0.8766775,0.8979200,0.9182925,0.9373600,0.9546875,0.9698400,0.9823825,0.9918800,0.9978975,1.0000000},{0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0090459,0.0345007,0.0738400,0.1245393,0.1840741,0.2499200,0.3195526,0.3904474,0.4600800,0.5259259,0.5854607,0.6361600,0.6754993,0.7009541,0.7100000,0.7142274,0.7260641,0.7442420,0.7674927,0.7945481,0.8241400,0.8550000,0.8858601,0.9154519,0.9425073,0.9657580,0.9839358,0.9957726,1.0000000},{0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0090459,0.0345007,0.0738400,0.1245393,0.1840741,0.2499200,0.3195526,0.3904474,0.4600800,0.5259259,0.5854607,0.6361600,0.6754993,0.7009541,0.7100000,0.7157060,0.7314815,0.7553125,0.7851852,0.8190857,0.8550000,0.8909144,0.9248148,0.9546875,0.9785185,0.9942940,1.0000000},{0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0079788,0.0306127,0.0659475,0.1120293,0.1669041,0.2286180,0.2952168,0.3647466,0.4352534,0.5047832,0.5713820,0.6330959,0.6879707,0.7340525,0.7693874,0.7920212,0.8000000,0.8046582,0.8174305,0.8365139,0.8601052,0.8864012,0.9135988,0.9398948,0.9634861,0.9825695,0.9953418,1.0000000},{0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0079788,0.0306127,0.0659475,0.1120293,0.1669041,0.2286180,0.2952168,0.3647466,0.4352534,0.5047832,0.5713820,0.6330959,0.6879707,0.7340525,0.7693874,0.7920212,0.8000000,0.8068587,0.8252401,0.8518519,0.8834019,0.9165981,0.9481481,0.9747599,0.9931413,1.0000000},{0.0000000,0.0250000,0.0800000,0.1350000,0.1600000,0.1660631,0.1833196,0.2103704,0.2458162,0.2882579,0.3362963,0.3885322,0.4435665,0.5000000,0.5564335,0.6114678,0.6637037,0.7117421,0.7541838,0.7896296,0.8166804,0.8339369,0.8400000,0.8423324,0.8488629,0.8588921,0.8717201,0.8866472,0.9029738,0.9200000,0.9370263,0.9533527,0.9682799,0.9811079,0.9911370,0.9976676,1.0000000}},endOpacity={{1.0000000,0.9953125,0.9850000,0.9746875,0.9700000,0.9674771,0.9601849,0.9485382,0.9329517,0.9138400,0.8916179,0.8667002,0.8395014,0.8104365,0.7799200,0.7483667,0.7161914,0.6838086,0.6516333,0.6200800,0.5895635,0.5604985,0.5332999,0.5083821,0.4861600,0.4670483,0.4514618,0.4398150,0.4325229,0.4300000,0.4265520,0.4167094,0.4012247,0.3808500,0.3563377,0.3284400,0.2979093,0.2654979,0.2319580,0.1980420,0.1645021,0.1320907,0.1015600,0.0736623,0.0491500,0.0287753,0.0132906,0.0034480,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000},{1.0000000,0.9989712,0.9962140,0.9922222,0.9874897,0.9825103,0.9777778,0.9737860,0.9710288,0.9700000,0.9674771,0.9601849,0.9485382,0.9329517,0.9138400,0.8916179,0.8667002,0.8395014,0.8104365,0.7799200,0.7483667,0.7161914,0.6838086,0.6516333,0.6200800,0.5895635,0.5604985,0.5332999,0.5083821,0.4861600,0.4670483,0.4514618,0.4398150,0.4325229,0.4300000,0.4265520,0.4167094,0.4012247,0.3808500,0.3563377,0.3284400,0.2979093,0.2654979,0.2319580,0.1980420,0.1645021,0.1320907,0.1015600,0.0736623,0.0491500,0.0287753,0.0132906,0.0034480,0.0000000,0.0000000},{1.0000000,0.9983382,0.9940525,0.9881924,0.9818076,0.9759475,0.9716618,0.9700000,0.9674771,0.9601849,0.9485382,0.9329517,0.9138400,0.8916179,0.8667002,0.8395014,0.8104365,0.7799200,0.7483667,0.7161914,0.6838086,0.6516333,0.6200800,0.5895635,0.5604985,0.5332999,0.5083821,0.4861600,0.4670483,0.4514618,0.4398150,0.4325229,0.4300000,0.4265520,0.4167094,0.4012247,0.3808500,0.3563377,0.3284400,0.2979093,0.2654979,0.2319580,0.1980420,0.1645021,0.1320907,0.1015600,0.0736623,0.0491500,0.0287753,0.0132906,0.0034480,0.0000000,0.0000000,0.0000000,0.0000000},{1.0000000,0.9968800,0.9894400,0.9805600,0.9731200,0.9700000,0.9674771,0.9601849,0.9485382,0.9329517,0.9138400,0.8916179,0.8667002,0.8395014,0.8104365,0.7799200,0.7483667,0.7161914,0.6838086,0.6516333,0.6200800,0.5895635,0.5604985,0.5332999,0.5083821,0.4861600,0.4670483,0.4514618,0.4398150,0.4325229,0.4300000,0.4265520,0.4167094,0.4012247,0.3808500,0.3563377,0.3284400,0.2979093,0.2654979,0.2319580,0.1980420,0.1645021,0.1320907,0.1015600,0.0736623,0.0491500,0.0287753,0.0132906,0.0034480,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000,0.0000000},{1.0000000,0.9992130,0.9970371,0.9937500,0.9896296,0.9849537,0.9800000,0.9750463,0.9703704,0.9662500,0.9629630,0.9607871,0.9600000,0.9578043,0.9514240,0.9411690,0.9273492,0.9102747,0.8902555,0.8676014,0.8426225,0.8156288,0.7869301,0.7568367,0.7256583,0.6937050,0.6612867,0.6287134,0.5962951,0.5643417,0.5331633,0.5030698,0.4743712,0.4473775,0.4223986,0.3997446,0.3797253,0.3626508,0.3488310,0.3385760,0.3321957,0.3300000,0.3244424,0.3089713,0.2853892,0.2554984,0.2211015,0.1840009,0.1459991,0.1088985,0.0745016,0.0446108,0.0210287,0.0055576,0.0000000},{1.0000000,0.9992130,0.9970371,0.9937500,0.9896296,0.9849537,0.9800000,0.9750463,0.9703704,0.9662500,0.9629630,0.9607871,0.9600000,0.9578043,0.9514240,0.9411690,0.9273492,0.9102747,0.8902555,0.8676014,0.8426225,0.8156288,0.7869301,0.7568367,0.7256583,0.6937050,0.6612867,0.6287134,0.5962951,0.5643417,0.5331633,0.5030698,0.4743712,0.4473775,0.4223986,0.3997446,0.3797253,0.3626508,0.3488310,0.3385760,0.3321957,0.3300000,0.3244424,0.3089713,0.2853892,0.2554984,0.2211015,0.1840009,0.1459991,0.1088985,0.0745016,0.0446108,0.0210287,0.0055576,0.0000000},{1.0000000,0.9983200,0.9937600,0.9870400,0.9788800,0.9700000,0.9611200,0.9529600,0.9462400,0.9416800,0.9400000,0.9364757,0.9263237,0.9101751,0.8886611,0.8624131,0.8320621,0.7982395,0.7615764,0.7227041,0.6822537,0.6408564,0.5991436,0.5577464,0.5172960,0.4784236,0.4417605,0.4079379,0.3775869,0.3513389,0.3298249,0.3136763,0.3035243,0.3000000,0.2975944,0.2907275,0.2799242,0.2657093,0.2486077,0.2291442,0.2078437,0.1852311,0.1618312,0.1381688,0.1147689,0.0921563,0.0708558,0.0513923,0.0342907,0.0200758,0.0092725,0.0024056,0.0000000,0.0000000,0.0000000}},banks={[192]=starlightLow,[288]=starlightLow,[384]=starlightHigh,[480]=starlightHigh,[576]=starlightHigh,[660]=starlightHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.TranquilityStarlight.banks)

do
    local expanded = {["StudioDruidRestorationChannelPlusSize288Page3.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page4.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page5.tga"]=true}
    local seen = {}
    local function adjust(pages, tiles)
        for _,tile in ipairs(tiles) do
            if expanded[pages[tile[1]]] and not seen[tile] then
                seen[tile] = true
                for i=2,5 do tile[i]=tile[i]/2 end
            end
        end
    end
    for _,bank in pairs(E.ArtworkChannelPlusBanks["DRUID:restoration"]) do
        for _,track in pairs(bank) do
            for _,stage in ipairs({"intro","hold","ending"}) do
                adjust(track.pages,track[stage])
                if track.matched then adjust(track.pages,track.matched[stage]) end
            end
            if track.matched and track.matched.idle then
                for _,tiles in pairs(track.matched.idle) do adjust(track.pages,tiles) end
            end
        end
    end
end

local vigilPages={
{"StudioDruidRestorationChannelPlusSize288Page3.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page4.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page5.tga",2048,2048},
}
local vigilLow={pixels=112,pages=vigilPages,tiles={
{1,1026,2,86,131,0,-9},
{1,1116,2,86,131,0,-9},
{1,1206,2,89,131,-3,-9},
{1,1299,2,85,131,3,-9},
{1,1388,2,84,131,4,-9},
{1,1476,2,87,130,1,-10},
{1,1567,2,88,130,0,-10},
{1,1659,2,87,131,1,-9},
{1,1750,2,89,131,-1,-9},
{1,1843,2,85,130,3,-10},
{1,1932,2,86,130,2,-10},
{1,1476,136,86,130,2,-10},
{1,1566,136,86,129,2,-11},
{1,1843,136,86,129,2,-11},
{1,1933,136,86,130,2,-10},
{1,1026,137,87,129,1,-9},
{1,1117,137,87,127,1,-11},
{1,1208,137,87,127,1,-11},
{1,1299,137,87,127,1,-11},
{1,1656,137,87,126,1,-12},
{1,1747,137,87,125,1,-13},
{1,1747,266,87,126,1,-12},
{1,1656,267,87,127,1,-11},
{1,1117,268,87,127,1,-11},
{1,1208,268,87,125,1,-13},
{1,1299,268,87,124,1,-14},
{1,1838,269,87,124,1,-14},
{1,1026,270,87,126,1,-12},
{1,1390,270,87,128,1,-10},
{1,1481,270,87,128,-1,-10},
{1,1929,270,87,126,-1,-12},
{1,1299,396,87,124,-1,-14},
{1,1747,397,88,125,-2,-13},
{1,1572,398,88,127,-2,-11},
{1,1117,399,88,128,-2,-10},
{1,1026,400,87,128,-3,-10},
{1,1839,400,87,127,-3,-11},
{1,1930,400,88,125,-4,-13},
{1,1390,402,88,126,-4,-12},
{1,1209,524,88,128,-4,-10},
{1,1664,526,88,129,-4,-9},
{1,1482,529,88,129,-4,-9},
{1,1301,524,83,127,1,-11},
{1,1574,529,83,126,1,-12},
{1,1930,529,83,126,1,-12},
{1,1117,531,83,128,1,-10},
{1,1390,137,81,129,1,-9},
{1,1756,531,81,129,1,-9},
{1,1841,531,81,129,1,-11},
{1,1026,532,80,127,2,-13},
{1,1388,532,80,127,2,-13},
{1,1301,655,79,128,1,-12},
{1,1204,656,79,129,1,-11},
{1,1574,659,79,129,1,-11},
{1,1657,659,79,128,1,-12},
{1,1926,659,78,126,0,-14},
{1,1472,662,78,126,0,-14},
{1,1026,663,78,127,0,-13},
{1,1108,663,78,128,-2,-12},
{1,1384,663,78,128,-2,-12},
{1,1740,664,78,127,-2,-13},
{1,1572,269,77,125,-3,-15},
{1,1822,664,77,125,-3,-15},
{1,1287,787,77,125,-3,-15},
{1,1190,789,77,125,-3,-15},
{1,1903,789,77,126,-3,-14},
{1,1657,791,77,125,-3,-15},
{1,1664,398,77,124,-3,-16},
{1,1466,792,77,125,-3,-15},
{1,1547,792,77,125,-3,-15},
{1,1822,793,77,125,-3,-15},
{1,1026,794,77,125,-3,-15},
{1,1107,795,77,125,-3,-15},
{1,1368,795,76,125,-4,-15},
{1,1738,795,79,125,-1,-15},
{1,1271,916,76,125,-4,-15},
{1,1188,918,76,125,-4,-15},
{1,1903,919,77,125,-5,-15},
{1,1628,920,78,124,-4,-16},
{1,1448,921,79,125,-3,-15},
{1,1531,921,81,125,-1,-15},
{1,1821,922,78,125,-4,-15},
{1,1026,924,78,125,-4,-15},
{1,1351,924,78,125,-4,-15},
{1,1710,924,79,125,-3,-15},
{1,2,1026,80,125,-2,-15},
{1,86,1026,81,126,-1,-14},
{1,171,1026,77,126,-5,-14},
{1,252,1026,77,126,-5,-14},
{1,333,1026,77,126,-5,-14},
{1,414,1026,78,126,-4,-14},
{1,496,1026,78,127,-4,-13},
{1,578,1026,79,127,-3,-13},
{1,661,1026,79,127,-3,-13},
{1,744,1026,79,127,-3,-13},
{1,827,1026,80,127,-2,-13},
{1,911,1026,80,127,-2,-13},
{1,1108,1047,81,127,-1,-13},
{1,1193,1047,81,128,-1,-12},
{1,1616,1048,81,128,1,-12},
{1,1903,1048,81,128,1,-12},
{1,1433,1050,82,128,2,-12},
{1,1519,1050,82,128,2,-12},
{1,1793,1051,83,128,3,-12},
{1,995,1053,83,128,3,-12},
{1,1278,1053,84,129,4,-11},
{1,1701,1053,84,129,4,-11},
{1,2,1156,85,129,5,-11},
{1,91,1156,85,129,5,-11},
{1,180,1156,86,129,6,-11},
{1,270,1156,86,129,6,-11},
{1,360,1156,87,129,7,-11},
{1,451,1157,87,129,7,-11},
{1,542,1157,88,129,8,-11},
{1,634,1157,88,129,8,-11},
{1,726,1157,89,129,9,-11},
{1,819,1157,89,130,9,-10},
{1,1082,1178,90,130,10,-10},
{1,1176,1179,89,130,11,-10},
{1,1605,1180,88,130,10,-10},
{1,1880,1180,88,130,10,-10},
{1,912,1157,78,130,0,-10},
{1,1366,1182,78,130,0,-10},
{1,1448,1182,78,130,0,-10},
{1,1789,1183,78,130,0,-10},
{1,994,1185,78,130,0,-10},
{1,1269,1186,80,130,0,-10},
{1,1697,1186,81,130,-1,-10},
{1,2,1289,81,130,-1,-10},
{1,87,1289,82,130,-2,-10},
{1,173,1289,82,129,-2,-11},
{1,259,1289,83,131,-1,-9},
{1,346,1289,80,130,2,-10},
{1,430,1290,80,129,2,-11},
{1,514,1290,80,129,2,-11},
{1,598,1290,82,129,2,-11},
{1,684,1290,82,130,2,-10},
{1,770,1291,82,131,2,-9},
{1,856,1291,83,130,1,-10},
{1,1076,1312,83,129,1,-11},
{1,1163,1313,86,130,0,-10},
{1,1530,1314,85,129,1,-11},
{1,1871,1314,85,130,1,-10},
{1,1960,1314,86,131,0,-9},
}}
local vigilHigh={pixels=192,pages=vigilPages,tiles={
{2,1026,2,146,223,0,-15},
{2,1176,2,147,223,1,-15},
{2,1327,2,151,222,-3,-16},
{2,1482,2,143,222,5,-16},
{2,1629,2,142,222,6,-16},
{2,1775,2,146,221,2,-17},
{2,1775,227,149,222,1,-16},
{2,1327,228,148,223,2,-15},
{2,1479,228,151,223,-1,-15},
{2,1026,229,145,221,5,-17},
{2,1175,229,146,221,4,-17},
{2,1634,453,146,221,4,-17},
{2,1784,453,146,220,4,-18},
{2,1026,454,147,219,3,-19},
{2,1177,455,147,220,3,-18},
{2,1328,455,147,219,3,-17},
{2,1479,455,148,216,2,-20},
{2,1479,675,148,216,2,-20},
{2,1784,677,148,215,2,-21},
{2,1631,678,148,214,2,-22},
{2,1026,679,148,214,2,-22},
{2,1178,679,149,214,1,-22},
{2,1331,895,149,217,1,-19},
{2,1484,896,149,216,1,-20},
{2,1637,896,149,213,1,-23},
{2,1790,896,148,212,0,-24},
{2,1026,897,148,212,0,-24},
{2,1178,897,148,215,0,-21},
{2,2,1026,147,217,1,-19},
{2,153,1026,148,217,0,-19},
{2,305,1026,148,214,-2,-22},
{2,457,1026,148,212,-2,-24},
{2,609,1026,148,212,-2,-24},
{2,761,1026,149,216,-3,-20},
{2,1790,1112,148,219,-4,-17},
{2,914,1113,149,219,-5,-17},
{2,1637,1113,149,216,-5,-20},
{2,1067,1116,148,213,-6,-23},
{2,1219,1116,149,214,-7,-22},
{2,1372,1116,149,217,-7,-19},
{2,457,1242,148,220,-8,-16},
{2,609,1242,148,220,-8,-16},
{2,305,1244,140,217,0,-19},
{2,761,1246,140,214,0,-22},
{2,2,1247,139,215,1,-21},
{2,145,1247,139,218,1,-18},
{2,1067,1333,139,220,1,-16},
{2,1634,228,137,220,1,-16},
{2,1525,1333,136,218,2,-20},
{2,1210,1334,135,215,3,-23},
{2,1665,1335,134,215,2,-23},
{2,1803,1335,134,218,2,-20},
{2,905,1336,134,219,2,-19},
{2,1349,1337,133,220,1,-18},
{2,761,1464,133,217,1,-21},
{2,288,1465,133,214,-1,-24},
{2,2,1466,133,214,-1,-24},
{2,425,1466,132,215,-2,-23},
{2,561,1466,132,217,-2,-21},
{2,139,1469,131,218,-3,-20},
{2,1210,1553,131,215,-3,-23},
{2,1331,678,130,213,-4,-25},
{2,1665,1554,130,212,-4,-26},
{2,1486,1555,131,212,-5,-26},
{2,1043,1557,131,213,-5,-25},
{2,1799,1557,131,215,-5,-23},
{2,898,1559,131,212,-5,-26},
{2,1345,1561,131,211,-5,-27},
{2,274,1683,131,212,-5,-26},
{2,2,1684,131,212,-5,-26},
{2,409,1685,130,212,-6,-26},
{2,697,1685,130,212,-6,-26},
{2,543,1687,130,212,-6,-26},
{2,137,1691,130,212,-8,-26},
{2,1621,1770,134,212,-4,-26},
{2,1480,1771,129,213,-9,-25},
{2,1178,1772,129,213,-9,-25},
{2,1033,1774,130,212,-8,-26},
{2,831,1775,132,212,-6,-26},
{2,1311,1776,134,212,-4,-26},
{2,1759,1776,136,212,-2,-26},
{2,1899,1776,132,212,-6,-26},
{3,1026,2,132,213,-6,-25},
{3,1162,2,132,213,-6,-25},
{3,1298,2,132,213,-6,-25},
{3,1434,2,134,214,-4,-24},
{3,1572,2,136,214,-2,-24},
{3,1712,2,131,214,-7,-24},
{3,1847,2,130,214,-8,-24},
{3,1026,219,131,215,-7,-23},
{3,1161,219,131,215,-7,-23},
{3,1296,219,132,215,-6,-23},
{3,1432,220,133,216,-5,-22},
{3,1569,220,133,216,-5,-22},
{3,1706,220,134,216,-4,-22},
{3,1844,220,134,216,-4,-22},
{3,1026,438,135,217,-3,-21},
{3,1165,438,136,217,-2,-21},
{3,1305,440,137,217,-1,-21},
{3,1446,440,138,217,0,-21},
{3,1588,440,139,218,1,-20},
{3,1731,440,140,218,2,-20},
{3,1875,440,140,218,2,-20},
{3,1026,659,141,218,3,-20},
{3,1171,661,141,219,5,-19},
{3,1316,661,142,219,6,-19},
{3,1462,662,143,220,7,-20},
{3,1609,662,144,220,8,-20},
{3,1757,662,145,220,9,-20},
{3,1026,884,146,220,10,-20},
{3,1176,884,147,221,11,-19},
{3,1327,886,148,221,12,-19},
{3,1479,886,149,221,13,-19},
{3,1632,886,148,221,14,-19},
{3,1784,886,149,221,15,-19},
{3,2,1026,150,221,16,-19},
{3,156,1026,151,221,17,-19},
{3,311,1026,151,221,17,-19},
{3,466,1026,151,221,17,-19},
{3,621,1026,151,221,17,-19},
{3,776,1026,150,220,16,-18},
{3,930,1108,141,220,9,-18},
{3,1906,662,132,220,0,-18},
{3,1075,1109,132,220,0,-18},
{3,1211,1111,132,220,0,-18},
{3,1347,1111,134,221,0,-17},
{3,1485,1111,134,220,0,-18},
{3,1623,1111,136,220,0,-18},
{3,1763,1111,137,220,-1,-18},
{3,1904,1111,138,220,-2,-18},
{3,776,1250,140,220,-2,-18},
{3,2,1251,141,223,-3,-15},
{3,147,1251,141,221,-3,-17},
{3,292,1251,136,220,4,-18},
{3,432,1251,137,220,3,-18},
{3,573,1251,139,220,3,-18},
{3,920,1332,139,221,3,-17},
{3,1063,1333,140,223,2,-15},
{3,1485,1335,142,221,2,-17},
{3,1631,1335,142,219,2,-19},
{3,1777,1335,145,220,-1,-18},
{3,1207,1336,143,220,1,-18},
{3,716,1474,145,221,1,-17},
{3,292,1475,146,222,0,-16},
}}
E.VigilFireflies={fps=48,frames=144,width=325,aspect=1.5,banks={[192]=vigilLow,[288]=vigilLow,[384]=vigilHigh,[480]=vigilHigh,[576]=vigilHigh,[660]=vigilHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.VigilFireflies.banks)

do
    local expanded = {["StudioDruidRestorationChannelPlusSize288Page4.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page6.tga"]=true}
    local seen = {}
    local function adjust(pages, tiles)
        for _,tile in ipairs(tiles) do
            if expanded[pages[tile[1]]] and not seen[tile] then
                seen[tile] = true
                for i=2,5 do tile[i]=tile[i]/2 end
            end
        end
    end
    for _,bank in pairs(E.ArtworkChannelPlusBanks["DRUID:restoration"]) do
        for _,track in pairs(bank) do
            for _,stage in ipairs({"intro","hold","ending"}) do
                adjust(track.pages,track[stage])
                if track.matched then adjust(track.pages,track.matched[stage]) end
            end
            if track.matched and track.matched.idle then
                for _,tiles in pairs(track.matched.idle) do adjust(track.pages,tiles) end
            end
        end
    end
end

local lifebloomPages={
{"StudioDruidRestorationChannelPlusSize288Page4.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page6.tga",2048,2048},
}
local lifebloomLow={pixels=128,pages=lifebloomPages,tiles={
{1,1026,2,1,1,1,-1},
{1,1031,2,1,1,1,-1},
{1,1036,2,1,1,1,-1},
{1,1041,2,1,1,1,-1},
{1,1046,2,8,5,0,-55},
{1,1058,2,21,24,-9,-40},
{1,1083,2,21,26,-9,-38},
{1,1108,2,22,28,-8,-34},
{1,1134,2,23,30,-7,-30},
{1,1161,2,24,33,-6,-25},
{1,1189,2,26,38,-4,-20},
{1,1219,2,29,47,-3,-19},
{1,1252,2,31,57,-1,-19},
{1,1287,2,34,66,2,-18},
{1,1325,2,39,75,3,-19},
{1,1368,2,45,83,3,-17},
{1,1417,2,51,90,1,-16},
{1,1472,2,57,95,1,-15},
{1,1533,2,62,98,0,-16},
{1,1599,2,67,99,-1,-15},
{1,1670,2,70,100,-2,-14},
{1,1744,2,74,101,-2,-15},
{1,1822,2,77,101,-1,-13},
{1,1903,2,80,101,0,-13},
{1,1026,34,82,102,0,-12},
{1,1112,44,84,101,0,-11},
{1,1200,72,84,102,0,-10},
{1,1288,89,84,103,0,-11},
{1,1376,96,84,103,0,-11},
{1,1464,104,84,104,0,-10},
{1,1552,105,84,104,0,-10},
{1,1640,106,84,104,0,-8},
{1,1728,107,82,104,0,-8},
{1,1814,107,82,103,-2,-7},
{1,1900,107,82,103,-2,-7},
{1,1026,140,80,102,-4,-6},
{1,1110,149,79,101,-5,-7},
{1,1193,178,81,100,-5,-6},
{1,1278,196,81,100,-5,-6},
{1,1363,203,81,98,-5,-4},
{1,1448,212,82,96,-6,-4},
{1,1534,213,82,93,-6,-3},
{1,1620,214,83,90,-5,-2},
{1,1814,214,83,87,-5,-1},
{1,1901,214,83,82,-5,0},
{1,1707,215,82,77,-6,1},
{1,1026,246,65,72,-3,2},
{1,1095,254,65,67,-3,3},
{1,1987,2,53,62,9,4},
{1,1987,68,55,61,9,3},
{1,1986,133,56,58,10,2},
{1,1988,195,57,57,9,1},
{1,1164,282,59,54,9,0},
{1,1707,296,61,52,9,-2},
{1,1227,300,62,53,8,1},
{1,1293,300,64,52,8,2},
{1,1901,300,65,53,7,3},
{1,1970,300,66,54,6,6},
{1,1361,305,67,55,5,9},
{1,1772,305,67,55,5,11},
{1,1620,308,68,55,4,13},
{1,1534,310,69,57,3,15},
{1,1432,312,70,52,2,12},
{1,1026,325,71,52,1,14},
{1,1101,340,72,53,0,17},
{1,1692,352,72,53,0,19},
{1,1177,357,73,53,-1,21},
{1,1254,357,73,53,-1,23},
{1,1843,357,74,53,-2,25},
{1,1921,358,74,50,-2,22},
{1,1331,364,75,45,-3,19},
{1,1607,367,75,45,-3,21},
{1,1410,368,75,45,-3,23},
{1,1768,364,69,44,-9,24},
{1,1489,371,69,45,-9,25},
{1,1026,381,69,39,-9,21},
{1,1099,397,69,40,-9,24},
{1,1686,409,69,40,-9,26},
{1,1759,412,69,41,-9,27},
{1,1921,412,69,41,-9,29},
{1,1331,413,69,41,-9,31},
{1,1172,414,65,42,-11,32},
{1,1241,414,65,42,-11,34},
{1,1832,414,65,40,-11,32},
{1,1562,416,65,40,-11,34},
{1,1404,417,65,40,-11,36},
{1,1473,420,65,41,-11,37},
{1,1026,424,65,41,-11,39},
{1,1095,441,65,42,-11,40},
{1,1631,453,65,41,-11,41},
{1,1988,256,51,40,3,42},
{1,1843,305,51,41,3,43},
{1,1994,412,51,41,3,45},
{1,1700,453,50,41,4,45},
{1,1754,457,50,41,4,47},
{1,1999,358,39,20,15,28},
{1,1562,371,39,20,15,28},
{1,1999,382,39,20,15,30},
{1,1631,416,38,20,14,30},
{1,1026,7,3,3,49,15},
{1,1033,7,3,4,49,16},
{1,1040,11,3,3,49,17},
{1,2044,2,1,1,1,-1},
{1,2044,7,1,1,1,-1},
{1,1047,11,1,1,1,-1},
{1,1052,11,1,1,1,-1},
{1,2044,12,1,1,1,-1},
{1,1026,14,1,1,1,-1},
{1,1031,15,1,1,1,-1},
{1,1047,16,1,1,1,-1},
{1,1052,16,1,1,1,-1},
{1,2044,17,1,1,1,-1},
{1,1036,18,1,1,1,-1},
{1,1041,18,1,1,1,-1},
{1,1026,19,1,1,1,-1},
{1,1031,20,1,1,1,-1},
{1,1046,21,1,1,1,-1},
{1,1051,21,1,1,1,-1},
{1,2044,22,1,1,1,-1},
{1,1036,23,1,1,1,-1},
}}
local lifebloomHigh={pixels=224,pages=lifebloomPages,tiles={
{2,1026,2,1,1,1,-1},
{2,1031,2,1,1,1,-1},
{2,1036,2,1,1,1,-1},
{2,1041,2,1,1,1,-1},
{2,1046,2,26,37,-12,-69},
{2,1076,2,34,41,-16,-69},
{2,1114,2,35,44,-15,-66},
{2,1153,2,36,48,-14,-60},
{2,1193,2,38,52,-12,-52},
{2,1235,2,40,58,-10,-42},
{2,1279,2,44,66,-8,-34},
{2,1327,2,48,82,-4,-34},
{2,1379,2,53,99,-1,-33},
{2,1436,2,58,116,2,-32},
{2,1498,2,66,131,4,-31},
{2,1568,2,76,145,4,-31},
{2,1648,2,87,157,3,-29},
{2,1739,2,98,166,2,-28},
{2,1841,2,107,171,1,-27},
{2,1026,50,116,173,-2,-25},
{2,1146,64,122,175,-4,-25},
{2,1272,105,128,176,-4,-26},
{2,1404,137,134,177,-2,-25},
{2,1542,163,138,177,0,-23},
{2,1684,172,142,177,0,-21},
{2,1830,177,146,178,0,-20},
{2,1026,243,146,178,0,-18},
{2,1176,285,146,179,0,-19},
{2,1326,318,146,181,0,-19},
{2,1476,344,146,182,0,-18},
{2,1626,353,146,182,0,-16},
{2,1776,359,144,182,0,-14},
{2,1026,425,143,181,-1,-13},
{2,1173,468,142,181,-2,-13},
{2,1319,503,142,180,-4,-12},
{2,1465,530,140,179,-6,-11},
{2,1609,539,138,177,-10,-11},
{2,1751,545,139,175,-9,-11},
{2,1894,545,140,174,-10,-10},
{2,1026,610,140,172,-10,-8},
{2,1170,653,141,167,-9,-7},
{2,1315,687,142,163,-10,-5},
{2,1461,713,142,157,-10,-3},
{2,1894,723,143,151,-9,-1},
{2,1607,724,143,143,-9,1},
{2,1026,824,142,135,-10,3},
{2,1924,359,112,126,-6,4},
{2,1754,724,112,118,-6,6},
{2,1952,2,90,109,16,9},
{2,1172,824,92,104,16,6},
{2,1754,846,96,102,16,4},
{2,1268,854,98,98,16,2},
{2,1607,871,101,94,15,0},
{2,1370,874,104,90,16,-2},
{2,1478,874,106,90,14,2},
{2,1854,878,109,88,13,2},
{2,1712,952,111,90,13,6},
{2,1172,956,113,91,11,11},
{2,1026,963,114,93,10,15},
{2,1289,968,116,94,8,18},
{2,1409,968,117,95,7,23},
{2,1530,969,119,96,5,26},
{2,1827,970,120,96,4,30},
{2,2,1026,122,89,2,25},
{2,128,1026,123,89,1,29},
{2,255,1026,124,90,0,32},
{2,383,1026,125,90,-1,36},
{2,512,1026,126,90,-2,40},
{2,642,1026,127,91,-3,43},
{2,773,1026,128,90,-4,46},
{2,1653,1046,128,84,-4,42},
{2,1144,1051,129,77,-5,37},
{2,905,1060,129,76,-5,40},
{2,1277,1066,118,75,-16,41},
{2,1399,1067,118,76,-16,44},
{2,1521,1069,118,66,-16,38},
{2,1785,1070,118,67,-16,41},
{2,1907,1070,118,67,-16,45},
{2,2,1119,117,68,-15,48},
{2,123,1119,117,69,-15,51},
{2,244,1120,117,70,-15,54},
{2,365,1120,112,71,-20,57},
{2,481,1120,112,72,-20,60},
{2,773,1120,112,72,-20,62},
{2,597,1121,112,68,-20,60},
{2,1038,1132,111,68,-19,62},
{2,1153,1132,111,69,-19,65},
{2,1643,1134,111,70,-19,68},
{2,1521,1139,111,70,-19,70},
{2,889,1140,111,71,-19,73},
{2,1758,1141,111,70,-19,76},
{2,1873,1141,111,70,-19,78},
{2,1951,970,85,69,5,79},
{2,1268,1145,85,69,5,81},
{2,1357,1147,85,69,5,83},
{2,2,1191,85,69,5,85},
{2,1952,115,65,32,25,50},
{2,1980,151,65,32,25,52},
{2,1980,187,65,33,25,53},
{2,1026,7,4,4,86,26},
{2,1034,7,4,4,86,28},
{2,1026,15,4,3,86,29},
{2,1034,15,1,1,1,-1},
{2,1039,15,3,3,85,31},
{2,1034,20,1,1,1,-1},
{2,1026,22,1,1,1,-1},
{2,1039,22,1,1,1,-1},
{2,1031,25,1,1,1,-1},
{2,1026,27,1,1,1,-1},
{2,1036,27,1,1,1,-1},
{2,1041,27,1,1,1,-1},
{2,1031,30,1,1,1,-1},
{2,1026,32,1,1,1,-1},
{2,1036,32,1,1,1,-1},
{2,1041,32,1,1,1,-1},
{2,1031,35,1,1,1,-1},
{2,1026,37,1,1,1,-1},
{2,1036,37,1,1,1,-1},
{2,1041,37,1,1,1,-1},
{2,1031,40,1,1,1,-1},
}}
E.LifebloomImpact={fps=48,frames=120,width=360,anchorV=.53,banks={[192]=lifebloomLow,[288]=lifebloomLow,[384]=lifebloomHigh,[480]=lifebloomHigh,[576]=lifebloomHigh,[660]=lifebloomHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.LifebloomImpact.banks)

do
    local expanded = {["StudioDruidRestorationChannelPlusSize288Page5.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page7.tga"]=true}
    local seen = {}
    local function adjust(pages, tiles)
        for _,tile in ipairs(tiles) do
            if expanded[pages[tile[1]]] and not seen[tile] then
                seen[tile] = true
                for i=2,5 do tile[i]=tile[i]/2 end
            end
        end
    end
    for _,bank in pairs(E.ArtworkChannelPlusBanks["DRUID:restoration"]) do
        for _,track in pairs(bank) do
            for _,stage in ipairs({"intro","hold","ending"}) do
                adjust(track.pages,track[stage])
                if track.matched then adjust(track.pages,track.matched[stage]) end
            end
            if track.matched and track.matched.idle then
                for _,tiles in pairs(track.matched.idle) do adjust(track.pages,tiles) end
            end
        end
    end
end

local wildGrowthManePages={
{"StudioDruidRestorationChannelPlusSize288Page5.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page7.tga",2048,2048},
}
local wildGrowthManeLow={pixels=112,pages=wildGrowthManePages,tiles={
{1,1026,2,1,1,1,-1},
{1,1031,2,55,24,7,-2},
{1,1090,2,66,39,-2,-3},
{1,1160,2,74,41,-4,-1},
{1,1238,2,76,44,-2,-4},
{1,1318,2,77,44,-1,-4},
{1,1399,2,85,46,7,-6},
{1,1488,2,85,46,7,-6},
{1,1577,2,85,47,7,-5},
{1,1666,2,95,47,-3,-5},
{1,1765,2,95,47,-3,-5},
{1,1864,2,95,47,-3,-5},
{1,1026,45,95,52,-3,-10},
{1,1125,47,95,52,-3,-10},
{1,1224,50,95,52,-3,-10},
{1,1323,52,95,55,-3,-7},
{1,1422,52,95,55,-3,-7},
{1,1521,53,95,55,-3,-7},
{1,1620,53,95,55,-3,-7},
{1,1719,53,96,55,-2,-7},
{1,1819,53,96,55,-2,-7},
{1,1919,53,96,55,-2,-7},
{1,1026,103,96,55,-2,-7},
{1,1126,106,96,55,-2,-7},
{1,1226,111,96,56,-2,-6},
{1,1326,111,96,57,-2,-5},
{1,1426,112,96,57,-2,-5},
{1,1526,112,97,57,-1,-5},
{1,1627,112,98,58,0,-6},
{1,1729,112,98,58,0,-6},
{1,1831,112,98,57,0,-5},
{1,1933,112,99,58,1,-4},
{1,1026,165,99,60,1,-6},
{1,1129,171,99,60,1,-6},
{1,1232,172,100,60,0,-6},
{1,1336,173,101,61,1,-5},
{1,1441,173,101,61,1,-5},
{1,1546,174,101,61,1,-5},
{1,1651,174,101,61,1,-5},
{1,1756,174,101,61,1,-5},
{1,1861,174,101,61,1,-5},
{1,1026,235,101,61,1,-5},
{1,1131,236,101,61,1,-5},
{1,1236,238,101,61,1,-5},
{1,1341,238,101,61,1,-5},
{1,1446,239,102,62,0,-4},
{1,1552,239,102,62,0,-4},
{1,1658,239,102,62,0,-4},
{1,1764,239,102,63,0,-3},
{1,1870,239,102,63,0,-3},
{1,1026,301,102,63,0,-3},
{1,1132,303,102,63,0,-3},
{1,1238,303,102,63,0,-3},
{1,1344,305,102,63,0,-3},
{1,1450,305,102,63,0,-3},
{1,1556,305,102,61,0,-5},
{1,1662,306,102,61,0,-5},
{1,1768,306,102,61,0,-5},
{1,1874,306,102,61,0,-5},
{1,1026,368,102,61,0,-5},
{1,1132,370,102,61,0,-5},
{1,1238,370,101,61,1,-5},
{1,1556,370,101,61,1,-5},
{1,1661,371,101,61,1,-5},
{1,1766,371,101,61,1,-5},
{1,1871,371,101,61,1,-5},
{1,1343,372,101,61,1,-5},
{1,1448,372,101,61,1,-5},
{1,1026,433,101,61,1,-5},
{1,1131,435,101,61,1,-5},
{1,1236,435,101,61,1,-5},
{1,1553,435,101,61,1,-5},
{1,1658,436,101,61,1,-5},
{1,1763,436,101,61,1,-5},
{1,1868,436,101,61,1,-5},
{1,1341,437,101,61,1,-5},
{1,1446,437,101,61,1,-5},
{1,1026,498,101,61,1,-5},
{1,1131,500,101,61,1,-5},
{1,1236,500,101,61,1,-5},
{1,1551,500,101,61,1,-5},
{1,1656,501,100,61,0,-5},
{1,1760,501,100,60,0,-6},
{1,1864,501,100,58,0,-6},
{1,1341,502,100,58,0,-6},
{1,1445,502,100,55,0,-3},
{1,1445,561,98,54,0,-2},
{1,1026,563,98,54,0,-2},
{1,1864,563,98,53,0,-1},
{1,1341,564,98,53,0,-1},
{1,1128,565,98,52,0,0},
{1,1230,565,98,52,0,0},
{1,1547,565,96,48,0,4},
{1,1760,565,96,42,0,-2},
{1,1963,2,1,1,1,-1},
{1,1968,2,1,1,1,-1},
}}
local wildGrowthManeHigh={pixels=192,pages=wildGrowthManePages,tiles={
{2,1026,2,1,1,1,-1},
{2,1031,2,128,83,4,-21},
{2,1163,2,147,91,-11,-13},
{2,1314,2,147,93,-11,-11},
{2,1465,2,157,93,-1,-11},
{2,1626,2,157,93,-1,-11},
{2,1787,2,158,94,0,-10},
{2,1026,97,158,95,0,-11},
{2,1188,99,162,95,-4,-11},
{2,1354,99,162,95,-4,-11},
{2,1520,99,162,95,-4,-11},
{2,1686,100,162,95,-4,-11},
{2,1852,100,162,95,-4,-11},
{2,1026,198,162,95,-4,-11},
{2,1192,198,162,95,-4,-11},
{2,1358,198,166,95,0,-11},
{2,1528,199,166,95,0,-11},
{2,1698,199,166,95,0,-11},
{2,1868,199,166,95,0,-11},
{2,1026,297,166,95,0,-11},
{2,1196,297,166,95,0,-11},
{2,1366,298,166,95,0,-11},
{2,1536,298,166,95,0,-11},
{2,1706,298,166,96,0,-10},
{2,1876,298,166,96,0,-10},
{2,1026,396,166,96,0,-10},
{2,1196,396,166,97,0,-9},
{2,1366,397,166,97,0,-9},
{2,1536,398,167,98,1,-10},
{2,1707,398,167,98,1,-10},
{2,1878,398,167,98,1,-10},
{2,1026,497,167,99,1,-9},
{2,1197,498,168,100,0,-10},
{2,1369,500,168,100,0,-10},
{2,1541,500,170,102,2,-10},
{2,1715,500,170,102,2,-10},
{2,1026,602,170,102,2,-10},
{2,1200,604,171,102,1,-10},
{2,1375,606,171,102,1,-10},
{2,1550,606,171,102,1,-10},
{2,1725,606,171,102,1,-10},
{2,1026,710,171,102,1,-10},
{2,1201,712,171,102,1,-10},
{2,1376,712,171,103,1,-9},
{2,1551,712,171,103,1,-9},
{2,1726,712,171,104,1,-8},
{2,1026,816,171,104,1,-8},
{2,1201,818,171,105,1,-7},
{2,1376,819,171,105,1,-7},
{2,1551,819,171,106,1,-6},
{2,1726,820,171,106,1,-6},
{2,1026,924,171,107,1,-5},
{2,1201,927,171,107,1,-5},
{2,1376,928,171,107,1,-5},
{2,1551,929,171,107,1,-5},
{2,1726,930,171,102,1,-10},
{2,2,1026,171,102,1,-10},
{2,177,1026,171,102,1,-10},
{2,352,1026,171,102,1,-10},
{2,527,1026,171,102,1,-10},
{2,702,1026,171,102,1,-10},
{2,877,1035,171,102,1,-10},
{2,1726,1036,171,102,1,-10},
{2,1052,1038,171,102,1,-10},
{2,1227,1039,171,102,1,-10},
{2,1402,1040,171,102,1,-10},
{2,2,1132,171,102,1,-10},
{2,177,1132,171,102,1,-10},
{2,352,1132,171,102,1,-10},
{2,527,1132,171,102,1,-10},
{2,702,1132,171,102,1,-10},
{2,877,1141,171,102,1,-10},
{2,1577,1142,171,102,1,-10},
{2,1752,1142,171,102,1,-10},
{2,1052,1144,171,102,1,-10},
{2,1227,1145,171,102,1,-10},
{2,1402,1146,171,102,1,-10},
{2,2,1238,171,102,1,-10},
{2,177,1238,171,102,1,-10},
{2,352,1238,171,102,1,-10},
{2,527,1238,171,102,1,-10},
{2,702,1238,171,101,1,-9},
{2,877,1247,169,101,-1,-9},
{2,1577,1248,168,100,0,-8},
{2,1749,1248,168,97,0,-11},
{2,1050,1250,168,96,0,-10},
{2,1222,1251,168,95,0,-9},
{2,1394,1252,167,95,-1,-9},
{2,702,1343,166,95,0,-9},
{2,2,1344,166,95,0,-9},
{2,172,1344,167,96,1,-8},
{2,343,1344,165,88,1,0},
{2,512,1344,162,86,0,2},
{2,1749,1349,162,70,0,-4},
{2,1050,1350,162,4,0,46},
{2,1949,2,1,1,1,-1},
}}
E.WildGrowthMane={fps=48,frames=96,width=416,anchorV=.5,banks={[192]=wildGrowthManeLow,[288]=wildGrowthManeLow,[384]=wildGrowthManeHigh,[480]=wildGrowthManeHigh,[576]=wildGrowthManeHigh,[660]=wildGrowthManeHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.WildGrowthMane.banks)

do
    local expanded = {["StudioDruidRestorationChannelPlusSize288Page6.tga"]=true,["StudioDruidRestorationChannelPlusSize480Page8.tga"]=true}
    local seen = {}
    local function adjust(pages, tiles)
        for _,tile in ipairs(tiles) do
            if expanded[pages[tile[1]]] and not seen[tile] then
                seen[tile] = true
                for i=2,5 do tile[i]=tile[i]/2 end
            end
        end
    end
    for _,bank in pairs(E.ArtworkChannelPlusBanks["DRUID:restoration"]) do
        for _,track in pairs(bank) do
            for _,stage in ipairs({"intro","hold","ending"}) do
                adjust(track.pages,track[stage])
                if track.matched then adjust(track.pages,track.matched[stage]) end
            end
            if track.matched and track.matched.idle then
                for _,tiles in pairs(track.matched.idle) do adjust(track.pages,tiles) end
            end
        end
    end
end

local wildGrowthManeLitePages={
{"StudioDruidRestorationChannelPlusSize288Page6.tga",2048,2048},
{"StudioDruidRestorationChannelPlusSize480Page8.tga",2048,2048},
}
local wildGrowthManeLiteLow={pixels=112,pages=wildGrowthManeLitePages,tiles={
{1,1026,2,1,1,1,-1},
{1,1031,2,44,3,0,-3},
{1,1079,2,46,10,0,2},
{1,1129,2,46,11,0,3},
{1,1179,2,48,18,0,-4},
{1,1231,2,50,20,0,-2},
{1,1285,2,52,22,0,-2},
{1,1341,2,56,25,2,1},
{1,1401,2,60,27,0,3},
{1,1465,2,66,27,0,3},
{1,1535,2,78,31,0,3},
{1,1617,2,83,35,1,5},
{1,1704,2,89,39,3,3},
{1,1797,2,96,42,2,0},
{1,1897,2,99,44,-1,0},
{1,1026,17,100,46,0,-2},
{1,1130,26,100,47,0,-3},
{1,1234,28,100,47,0,-3},
{1,1338,33,100,47,0,-3},
{1,1442,37,100,47,0,-3},
{1,1546,41,100,47,0,-3},
{1,1650,45,100,47,0,-3},
{1,1754,48,100,47,0,-3},
{1,1858,50,100,47,0,-3},
{1,1026,67,100,47,0,-3},
{1,1130,77,100,47,0,-3},
{1,1234,79,100,47,0,-3},
{1,1338,84,100,46,0,-2},
{1,1442,88,100,46,0,-2},
{1,1546,92,100,46,0,-2},
{1,1650,96,100,46,0,-2},
{1,1754,99,100,46,0,-2},
{1,1858,101,100,46,0,-2},
{1,1026,118,100,46,0,-2},
{1,1130,128,100,46,0,-2},
{1,1234,130,100,45,0,-1},
{1,1338,134,100,45,0,-1},
{1,1442,138,100,46,0,-2},
{1,1546,142,100,46,0,-2},
{1,1650,146,100,46,0,-2},
{1,1754,149,100,46,0,-2},
{1,1858,151,100,46,0,-2},
{1,1026,168,100,46,0,-2},
{1,1130,178,100,46,0,-2},
{1,1234,179,100,46,0,-2},
{1,1338,183,100,46,0,-2},
{1,1442,188,100,46,0,-2},
{1,1546,192,100,45,0,-3},
{1,1650,196,100,45,0,-3},
{1,1754,199,100,45,0,-3},
{1,1858,201,100,45,0,-3},
{1,1026,218,100,45,0,-3},
{1,1130,228,100,45,0,-3},
{1,1234,229,100,45,0,-3},
{1,1338,233,100,45,0,-3},
{1,1442,238,100,45,0,-3},
{1,1546,241,100,45,0,-3},
{1,1650,245,100,45,0,-3},
{1,1754,248,100,45,0,-3},
{1,1858,250,100,45,0,-3},
{1,1026,267,100,45,0,-3},
{1,1130,277,100,45,0,-3},
{1,1234,278,100,46,0,-2},
{1,1338,282,100,47,0,-3},
{1,1442,287,100,47,0,-3},
{1,1546,290,100,47,0,-3},
{1,1650,294,100,47,0,-3},
{1,1754,297,100,47,0,-3},
{1,1858,299,100,47,0,-3},
{1,1026,316,100,47,0,-3},
{1,1130,326,100,47,0,-3},
{1,1234,328,100,47,0,-3},
{1,1338,333,100,47,0,-3},
{1,1442,338,100,47,0,-3},
{1,1546,341,100,46,0,-2},
{1,1650,345,100,46,0,-2},
{1,1754,348,100,46,0,-2},
{1,1858,350,100,45,0,-1},
{1,1026,367,94,44,0,0},
{1,1124,377,86,35,0,-1},
{1,1962,50,74,31,-2,1},
{1,1962,85,67,25,3,1},
{1,1962,114,61,24,-3,0},
{1,1962,142,62,23,-4,1},
{1,1962,169,62,20,-4,-2},
{1,1962,193,56,6,-10,-4},
{1,2000,2,44,4,0,-4},
{1,1214,379,100,46,0,-2},
{1,1318,384,100,46,0,-2},
{1,1422,389,100,46,0,-2},
{1,1526,391,100,45,0,-1},
{1,1630,395,100,46,0,-2},
{1,1734,398,99,45,1,-1},
{1,1837,399,94,44,0,0},
{1,1935,399,86,35,0,-1},
{1,1962,203,73,30,-3,0},
{1,1962,237,62,26,-4,0},
{1,1962,267,62,22,-4,-2},
{1,1962,293,63,21,-3,-1},
{1,1962,318,64,21,-4,-1},
{1,1962,343,57,5,-11,-3},
{1,1026,9,44,4,0,-4},
{1,1026,416,100,45,0,-1},
{1,1130,429,100,46,0,-2},
{1,1234,434,100,46,0,-2},
{1,1935,438,100,46,0,-2},
{1,1338,439,100,46,0,-2},
{1,1442,440,100,45,0,-1},
{1,1546,445,94,43,0,-1},
{1,1644,445,85,35,-1,-1},
{1,1962,352,74,30,-4,0},
{1,1733,447,65,25,-3,1},
{1,1802,447,65,23,-3,-1},
{1,1026,465,64,23,-4,-1},
{1,1802,474,64,22,-4,0},
{1,1962,386,57,5,-11,-3},
{1,2000,10,44,4,0,-4},
{1,1094,479,100,46,0,-2},
{1,1198,484,100,46,0,-2},
{1,1644,484,100,46,0,-2},
{1,1870,488,100,45,0,-3},
{1,1302,489,100,45,0,-3},
{1,1406,489,100,44,0,-2},
{1,1510,492,94,43,0,-1},
{1,1748,500,85,35,-1,-1},
{1,1026,529,73,30,-3,0},
{1,1974,488,67,25,-3,1},
{1,1974,517,67,24,-3,0},
{1,1103,529,65,24,-5,0},
{1,1871,447,59,18,-11,-4},
{1,1871,469,50,11,-4,3},
{1,1130,17,44,4,0,-4},
{1,1172,534,100,45,0,-3},
{1,1608,534,100,45,0,-3},
{1,1406,537,100,45,0,-3},
{1,1837,537,100,45,0,-3},
{1,1276,538,100,45,0,-3},
{1,1712,539,100,45,0,-3},
{1,1510,539,93,44,-1,-2},
{1,1941,545,86,35,0,-1},
{1,1026,563,73,29,-3,1},
{1,1103,583,68,25,-2,1},
{1,1175,583,68,22,-2,-2},
{1,1026,492,60,20,-10,-4},
{1,1103,557,52,19,-4,-3},
{1,1607,583,51,12,-5,4},
{1,2000,18,44,4,0,-4},
{1,1941,584,100,45,0,-3},
{1,1380,586,100,45,0,-3},
{1,1816,586,100,45,0,-3},
{1,1247,587,100,45,0,-3},
{1,1484,587,100,46,0,-2},
{1,1662,588,99,46,-1,-2},
{1,1026,612,93,46,-1,-2},
{1,1123,612,85,36,-1,-2},
{1,1920,633,74,30,-2,2},
{1,1588,599,69,25,-1,1},
{1,1588,628,62,22,6,-2},
{1,1351,635,54,21,-4,-3},
{1,1409,635,53,20,-5,-2},
{1,1765,635,52,13,-6,5},
{1,2000,26,44,4,0,-4},
{1,1212,636,100,45,0,-3},
{1,1466,637,100,46,0,-2},
{1,1654,638,100,47,0,-3},
{1,1758,652,100,47,0,-3},
{1,1316,660,100,47,0,-3},
{1,1026,662,99,47,-1,-3},
{1,1862,667,94,46,0,-2},
{1,1960,667,86,36,0,0},
{1,1129,652,74,30,-2,2},
{1,1570,654,67,26,3,2},
{1,1570,684,64,22,6,-2},
{1,1207,685,56,21,-2,-1},
{1,1129,686,57,21,-3,-1},
{1,1748,476,50,11,4,3},
{1,2000,34,44,4,0,-4},
{1,1420,687,100,47,0,-3},
{1,1638,689,100,47,0,-3},
{1,1742,703,100,47,0,-3},
{1,1190,710,100,47,0,-3},
{1,1524,710,100,47,0,-3},
{1,1294,711,100,46,0,-2},
{1,1026,713,94,45,0,-1},
{1,1960,707,86,36,0,0},
{1,1846,717,74,30,-2,2},
{1,1398,738,67,26,3,2},
{1,1628,740,66,23,4,-1},
{1,1124,713,60,22,-4,0},
{1,1124,739,60,22,-4,0},
{1,1924,747,60,14,-4,2},
{1,2000,42,44,4,0,-4},
}}
local wildGrowthManeLiteHigh={pixels=192,pages=wildGrowthManeLitePages,tiles={
{2,1026,2,1,1,1,-1},
{2,1031,2,74,4,0,-6},
{2,1109,2,74,14,0,4},
{2,1187,2,76,17,0,5},
{2,1267,2,80,29,0,-7},
{2,1351,2,84,33,0,-3},
{2,1439,2,88,37,0,-1},
{2,1531,2,95,40,3,2},
{2,1630,2,100,44,0,4},
{2,1734,2,112,45,0,5},
{2,1850,2,131,52,-1,4},
{2,1026,20,145,59,-1,9},
{2,1175,35,151,66,5,6},
{2,1330,43,162,71,4,1},
{2,1496,50,168,73,0,-1},
{2,1668,51,169,76,-1,-4},
{2,1841,58,169,77,-1,-5},
{2,1026,105,169,77,-1,-5},
{2,1199,118,169,77,-1,-5},
{2,1372,127,169,77,-1,-5},
{2,1545,131,169,77,-1,-5},
{2,1718,139,169,78,-1,-4},
{2,1026,186,169,78,-1,-4},
{2,1199,199,169,78,-1,-4},
{2,1372,208,169,78,-1,-4},
{2,1545,212,169,78,-1,-4},
{2,1718,221,169,78,-1,-4},
{2,1026,268,169,78,-1,-4},
{2,1199,281,168,77,0,-3},
{2,1371,290,168,77,0,-3},
{2,1543,294,169,77,1,-3},
{2,1716,303,169,77,1,-3},
{2,1026,350,169,77,1,-3},
{2,1199,371,169,76,1,-2},
{2,1372,375,169,76,1,-2},
{2,1545,384,169,76,1,-2},
{2,1718,384,169,76,1,-2},
{2,1026,431,169,76,1,-2},
{2,1199,451,169,77,1,-3},
{2,1372,455,169,77,1,-3},
{2,1545,464,169,76,1,-4},
{2,1718,464,169,76,1,-4},
{2,1026,511,169,76,1,-4},
{2,1199,532,169,76,1,-4},
{2,1372,536,169,76,1,-4},
{2,1545,544,169,76,1,-4},
{2,1718,544,169,76,1,-4},
{2,1026,591,169,76,1,-4},
{2,1199,612,169,76,1,-4},
{2,1372,624,170,76,0,-4},
{2,1546,624,170,76,0,-4},
{2,1720,624,170,76,0,-4},
{2,1026,692,170,75,0,-5},
{2,1200,704,170,75,0,-5},
{2,1374,704,170,75,0,-5},
{2,1548,704,170,75,0,-5},
{2,1722,704,170,75,0,-5},
{2,1026,771,169,75,-1,-5},
{2,1199,783,169,75,-1,-5},
{2,1372,783,169,76,-1,-4},
{2,1545,783,169,76,-1,-4},
{2,1718,783,169,76,-1,-4},
{2,1026,850,169,77,-1,-5},
{2,1199,862,169,77,-1,-5},
{2,1372,863,169,77,-1,-5},
{2,1545,863,169,77,-1,-5},
{2,1718,863,169,77,-1,-5},
{2,1026,931,169,77,-1,-5},
{2,1199,943,169,77,-1,-5},
{2,1372,944,169,78,-1,-4},
{2,1545,944,169,78,-1,-4},
{2,1718,944,169,78,-1,-4},
{2,1026,1012,169,78,-1,-4},
{2,1199,1024,169,78,-1,-4},
{2,2,1026,168,77,0,-3},
{2,174,1026,169,77,1,-3},
{2,347,1026,169,77,1,-3},
{2,520,1026,168,76,0,-2},
{2,692,1026,158,74,0,0},
{2,1891,139,146,58,0,0},
{2,1891,201,124,51,-4,1},
{2,1891,256,113,42,5,2},
{2,1891,302,102,38,-6,0},
{2,1891,344,103,37,-7,1},
{2,1891,385,103,33,-7,-3},
{2,1891,422,104,23,-6,7},
{2,1026,10,74,4,0,-6},
{2,1372,1026,169,77,1,-3},
{2,1545,1026,169,77,1,-3},
{2,1718,1026,169,76,1,-2},
{2,854,1094,169,76,1,-2},
{2,520,1106,169,77,1,-3},
{2,1027,1094,168,74,0,-2},
{2,1199,1106,158,73,0,-1},
{2,1891,449,146,59,0,-3},
{2,1891,512,123,50,-5,0},
{2,1891,566,107,41,-3,1},
{2,1894,611,105,36,-7,-4},
{2,1894,651,105,34,-7,-2},
{2,1896,689,106,35,-6,-1},
{2,1896,728,107,23,-7,11},
{2,1175,23,74,4,0,-6},
{2,1718,1106,169,76,1,-2},
{2,2,1107,169,77,1,-3},
{2,175,1107,169,76,1,-4},
{2,1361,1107,169,76,1,-4},
{2,1534,1107,169,76,1,-4},
{2,348,1107,168,75,0,-3},
{2,1027,1172,159,73,1,-1},
{2,1896,755,145,58,-1,-4},
{2,1891,817,125,49,-7,-1},
{2,1891,870,109,41,-5,1},
{2,1891,915,110,37,-4,-1},
{2,1891,956,107,36,-7,0},
{2,1891,996,108,37,-8,1},
{2,1026,83,96,5,-20,-5},
{2,1026,92,74,4,0,-6},
{2,693,1174,169,76,1,-4},
{2,1707,1186,169,76,1,-4},
{2,175,1187,169,76,1,-4},
{2,348,1187,169,76,1,-4},
{2,1190,1187,170,76,0,-4},
{2,521,1187,168,74,0,-4},
{2,1880,1186,158,73,0,-3},
{2,854,1026,146,57,0,-3},
{2,1891,1037,124,48,-6,0},
{2,1891,1089,112,41,-4,1},
{2,693,1104,112,38,-4,0},
{2,1891,1134,109,39,-7,1},
{2,866,1174,99,29,-19,-7},
{2,1026,671,96,16,-20,6},
{2,1199,105,74,4,0,-6},
{2,1364,1187,169,76,1,-4},
{2,866,1249,170,76,0,-4},
{2,521,1265,170,75,0,-5},
{2,1537,1266,170,75,0,-5},
{2,2,1188,169,75,-1,-5},
{2,1711,1266,168,75,0,-5},
{2,1537,1187,159,75,-1,-3},
{2,1040,1249,146,59,0,-3},
{2,695,1254,125,49,-5,1},
{2,1883,1263,115,41,-3,1},
{2,866,1207,115,35,-3,-3},
{2,2,1267,101,31,-17,-7},
{2,107,1267,99,31,-19,-5},
{2,693,1146,85,18,-9,8},
{2,1372,118,74,4,0,-6},
{2,210,1267,170,75,0,-5},
{2,1190,1267,170,75,0,-5},
{2,1364,1267,169,75,-1,-5},
{2,2,1302,169,76,-1,-4},
{2,695,1329,169,77,-1,-5},
{2,868,1329,168,77,0,-5},
{2,1883,1308,158,76,0,-4},
{2,1040,1312,146,59,-2,-3},
{2,384,1267,125,50,-5,2},
{2,384,1321,116,42,-2,2},
{2,504,1344,104,35,10,-3},
{2,1537,1345,90,33,-6,-5},
{2,1631,1345,91,33,-5,-3},
{2,1726,1345,86,20,-10,10},
{2,1718,131,74,4,0,-6},
{2,175,1346,169,76,-1,-4},
{2,1190,1346,169,77,-1,-5},
{2,1363,1346,169,77,-1,-5},
{2,2,1382,169,77,-1,-5},
{2,1536,1382,169,77,-1,-5},
{2,1709,1382,167,78,-1,-4},
{2,348,1383,158,77,0,-3},
{2,1040,1375,146,60,0,-2},
{2,510,1383,125,50,-5,2},
{2,1880,1388,111,42,5,2},
{2,639,1410,107,35,9,-3},
{2,750,1410,94,34,-4,-2},
{2,848,1410,94,34,-4,-2},
{2,175,1426,95,22,-3,12},
{2,1199,362,74,4,0,-6},
{2,1190,1427,169,77,-1,-5},
{2,1363,1427,169,77,-1,-5},
{2,946,1439,169,78,-1,-4},
{2,750,1448,169,78,-1,-4},
{2,510,1449,168,78,0,-4},
{2,175,1452,168,77,0,-3},
{2,1880,1434,158,76,0,-2},
{2,2,1463,145,58,-1,0},
{2,1536,1463,125,50,-5,2},
{2,347,1464,112,43,6,3},
{2,1665,1464,111,36,7,-2},
{2,1665,1504,100,36,-6,0},
{2,1769,1504,100,36,-6,0},
{2,1119,1508,101,28,-7,8},
{2,1277,362,74,4,0,-6},
}}
E.WildGrowthManeLite={fps=48,frames=192,width=208,intro=24,hold=48,outFrames=15,phaseStep=6,outStride=2,banks={[192]=wildGrowthManeLiteLow,[288]=wildGrowthManeLiteLow,[384]=wildGrowthManeLiteHigh,[480]=wildGrowthManeLiteHigh,[576]=wildGrowthManeLiteHigh,[660]=wildGrowthManeLiteHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.WildGrowthManeLite.banks)

local gustPages={
{"StudioDruidRestorationChannelPlusSize288Page91.tga",2048,1024},
{"StudioDruidRestorationChannelPlusSize480Page91.tga",2048,1024},
{"StudioDruidRestorationChannelPlusSize480Page92.tga",2048,1024},
}
local gustLow={pixels=88,pages=gustPages,bands={
{
{1,2,2,1,1,1,-1},
{1,12,2,1,1,1,-1},
{1,22,2,4,4,38,2},
{1,35,2,48,13,-2,-5},
{1,92,2,60,27,-10,1},
{1,161,2,61,28,-7,2},
{1,257,2,64,28,-6,2},
{1,389,2,67,30,-5,2},
{1,525,2,67,30,-3,2},
{1,671,2,69,36,-1,8},
{1,815,2,69,35,-1,7},
{1,963,2,70,35,0,7},
{1,1113,2,72,39,2,3},
{1,1263,2,70,38,0,4},
{1,1408,2,73,39,-1,3},
{1,1554,2,72,41,0,-1},
{1,1699,2,72,40,2,0},
{1,1849,2,74,39,2,1},
{1,2,19,76,39,2,3},
{1,152,34,76,39,4,3},
{1,304,37,75,37,5,1},
{1,458,37,74,37,4,3},
{1,536,40,73,38,5,4},
{1,956,41,71,39,3,5},
{1,613,42,70,39,2,5},
{1,1775,42,69,40,3,6},
{1,1189,43,69,39,5,7},
{1,1106,45,67,39,5,7},
{1,1414,45,72,38,-2,8},
{1,1630,46,72,38,0,10},
{1,2,62,74,37,2,11},
{1,1920,76,75,37,1,9},
{1,304,78,75,37,1,9},
{1,761,78,75,38,-1,8},
{1,840,78,76,36,-2,4},
{1,1262,79,75,36,-3,4},
{1,533,82,74,40,-2,0},
{1,1177,86,73,39,-1,1},
{1,611,85,72,38,0,4},
{1,1706,86,70,38,2,6},
{1,1780,86,72,39,0,7},
{1,1565,88,70,38,-2,8},
{1,2,103,71,41,-1,5},
{1,996,113,73,41,-1,5},
{1,383,114,73,39,-1,5},
{1,77,117,74,39,-2,5},
{1,1932,117,73,38,-3,4},
{1,301,119,73,39,-3,3},
{1,1254,119,73,38,-1,4},
{1,1403,119,73,38,1,6},
{1,1480,119,70,38,2,6},
{1,915,120,73,42,-1,4},
{1,531,126,72,41,0,5},
{1,1639,128,69,40,-3,6},
{1,1712,129,70,39,-2,7},
{1,1554,130,70,39,-2,5},
{1,224,149,70,37,-2,7},
{1,378,157,70,36,-2,8},
{1,1855,157,71,36,-1,8},
{1,992,158,70,35,0,7},
{1,70,160,72,39,2,3},
{1,1216,161,70,38,0,4},
{1,1402,161,73,39,-1,3},
{1,298,162,72,41,0,-1},
{1,1066,165,72,40,2,0},
{1,531,171,74,39,2,1},
{1,1628,172,76,39,2,3},
{1,1548,173,76,39,4,3},
{1,452,185,75,37,5,1},
{1,823,193,74,37,4,3},
{1,676,194,72,38,4,4},
{1,980,197,70,39,2,5},
{1,1290,199,68,38,2,6},
{1,146,201,67,37,5,7},
{1,73,203,69,36,5,8},
{1,1565,47,58,31,-2,5},
{1,1639,88,62,26,-10,4},
{1,1856,84,60,28,-12,2},
{1,901,206,59,27,-9,3},
{1,2000,28,44,19,8,5},
{1,295,207,74,39,2,1},
{1,1054,209,76,39,2,3},
{1,531,214,76,39,4,3},
{1,1548,216,75,37,5,1},
{1,217,233,74,37,4,3},
{1,822,234,73,38,5,4},
{1,1917,234,71,39,3,5},
{1,611,236,70,39,2,5},
{1,899,237,69,40,3,6},
{1,685,238,69,39,5,7},
{1,2,237,67,38,5,8},
{1,73,243,68,37,-6,9},
{1,1134,248,67,36,-5,10},
{1,1700,250,65,30,-7,4},
{1,520,257,64,30,-6,6},
{1,1360,241,62,26,-4,4},
{1,1574,260,62,25,-2,5},
{1,436,269,61,24,1,6},
{1,1999,51,18,7,-36,-9},
{1,1205,271,74,37,4,3},
{1,1837,272,73,38,5,4},
{1,217,274,71,39,3,5},
{1,1283,275,70,39,2,5},
{1,1914,277,69,40,3,6},
{1,660,281,69,39,5,7},
{1,2,279,67,39,5,7},
{1,1640,284,71,38,-3,8},
{1,501,291,71,37,-1,9},
{1,1715,295,71,36,-1,10},
{1,1499,296,71,36,-1,10},
{1,733,311,70,37,-2,9},
{1,909,311,68,33,-2,5},
{1,1428,310,66,32,0,6},
{1,1357,313,64,32,2,8},
{1,807,315,64,34,6,4},
{1,758,238,59,27,7,13},
{1,1999,62,45,14,-5,2},
{1,1999,80,43,12,-1,4},
{1,73,318,69,40,3,6},
{1,1860,321,69,39,5,7},
{1,2,322,67,39,5,7},
{1,1574,326,72,38,-2,8},
{1,441,332,72,38,0,10},
{1,283,334,74,37,2,11},
{1,361,344,75,37,1,9},
{1,1724,347,74,37,0,9},
{1,146,348,74,38,-2,8},
{1,875,348,73,36,-3,4},
{1,722,352,72,36,-2,4},
{1,1260,352,70,35,0,5},
{1,1933,355,68,39,4,1},
{1,73,362,65,38,5,4},
{1,2,365,64,37,8,7},
{1,1123,366,62,37,-10,9},
{1,1572,368,63,36,-7,10},
{1,1574,289,59,22,-7,-2},
{1,996,84,22,10,-10,4},
{1,440,374,72,38,0,10},
{1,952,375,74,37,2,11},
{1,1639,376,75,37,1,9},
{1,1334,384,75,37,1,9},
{1,299,385,75,38,-1,8},
{1,1718,388,76,36,-2,4},
{1,1189,391,75,36,-3,4},
{1,590,392,74,40,-2,0},
{1,1798,395,73,39,-1,1},
{1,1875,398,71,38,1,4},
{1,70,404,68,38,4,6},
{1,378,416,72,38,0,8},
{1,945,416,66,38,-4,8},
{1,1485,417,67,37,-5,9},
{1,1629,417,64,34,-6,8},
{1,1413,422,65,34,-5,8},
{1,522,424,64,31,-2,7},
{1,146,319,64,22,0,0},
{1,2006,159,39,21,-13,1},
{1,1268,425,75,38,-1,8},
{1,288,427,76,36,-2,4},
{1,1697,428,75,36,-3,4},
{1,1015,431,74,40,-2,0},
{1,590,436,73,39,-1,1},
{1,1776,438,72,38,0,4},
{1,2,446,70,38,2,6},
{1,1556,455,72,39,0,7},
{1,811,457,68,38,-4,8},
{1,883,458,69,39,-3,7},
{1,1482,458,69,41,-3,5},
{1,1347,460,67,39,-3,5},
{1,667,464,66,38,-2,4},
{1,285,467,66,38,0,4},
{1,147,462,65,34,3,8},
{1,1632,468,65,33,5,9},
{1,1418,460,60,34,4,10},
{1,1998,199,47,22,-5,4},
{1,1427,204,39,21,-1,5},
{1,1013,475,73,39,-1,1},
{1,1773,480,72,38,0,4},
{1,2,488,70,38,2,6},
{1,355,488,72,39,0,7},
{1,431,495,70,38,-2,8},
{1,1555,498,71,41,-1,5},
{1,76,500,71,41,-1,5},
{1,1311,503,72,39,-2,5},
{1,1458,503,71,39,-3,5},
{1,1925,504,70,38,-2,4},
{1,663,506,69,39,1,3},
{1,1230,507,68,38,4,4},
{1,1705,506,64,38,4,6},
{1,1090,510,63,37,7,7},
{1,951,518,61,38,7,8},
{1,1773,522,66,36,-4,10},
{1,291,509,60,35,-8,9},
{1,1870,364,59,27,-5,3},
{1,1640,260,39,20,11,10},
{1,2,530,70,38,-2,8},
{1,804,535,71,41,-1,5},
{1,1533,543,73,41,-1,5},
{1,1843,544,73,39,-1,5},
{1,1302,546,74,39,-2,5},
{1,1920,546,73,38,-3,4},
{1,151,547,73,39,-3,3},
{1,228,548,72,38,0,4},
{1,1686,548,71,38,3,6},
{1,1229,549,68,38,4,6},
{1,1016,559,72,38,-2,8},
{1,304,561,71,41,1,5},
{1,2,572,67,40,-1,6},
{1,379,573,63,38,-7,8},
{1,948,573,63,36,-5,8},
{1,791,580,65,35,-5,9},
{1,73,585,65,34,-1,10},
{1,1347,425,59,26,1,4},
{1,2005,355,39,24,-11,6},
{1,1092,585,74,39,-2,5},
{1,1831,587,73,38,-3,4},
{1,1523,588,73,39,-3,3},
{1,1908,588,73,38,-1,4},
{1,142,590,73,38,1,6},
{1,1685,590,70,38,2,6},
{1,446,601,72,42,-2,4},
{1,1015,601,72,41,0,5},
{1,288,606,69,40,-3,6},
{1,1373,608,66,39,-4,7},
{1,929,613,67,38,-5,6},
{1,2,616,67,37,-3,7},
{1,1443,625,67,36,-1,8},
{1,595,627,67,34,1,8},
{1,1242,628,67,33,3,9},
{1,73,623,64,33,4,9},
{1,1985,588,60,26,4,6},
{1,219,629,60,25,6,7},
{1,744,392,39,22,1,6},
{1,1899,630,73,38,1,6},
{1,141,632,70,38,2,6},
{1,1743,640,73,42,-1,4},
{1,666,642,72,41,0,5},
{1,855,646,69,40,-3,6},
{1,429,647,69,39,-3,7},
{1,352,650,69,39,-3,5},
{1,1976,651,69,37,-3,7},
{1,928,655,68,36,-2,8},
{1,1069,662,68,36,0,8},
{1,1820,662,68,35,2,7},
{1,593,665,68,34,4,8},
{1,1457,670,66,38,4,4},
{1,73,660,63,37,5,5},
{1,140,674,70,35,0,1},
{1,1658,675,58,31,-10,-1},
{1,1000,685,57,30,-9,0},
{1,278,687,56,29,-6,1},
{1,1995,464,39,20,13,8},
{1,665,687,69,40,-3,6},
{1,818,690,70,39,-2,7},
{1,1960,692,70,39,-2,5},
{1,338,693,70,37,-2,7},
{1,1527,696,70,36,-2,8},
{1,1784,701,70,36,-2,8},
{1,572,703,70,35,0,7},
{1,1209,706,71,39,3,3},
{1,73,713,68,38,2,4},
{1,1858,713,73,38,-1,4},
{1,968,719,72,37,0,3},
{1,216,720,68,40,-2,0},
{1,1284,723,67,39,-5,1},
{1,738,728,66,38,-4,2},
{1,412,729,65,36,-5,0},
{1,808,733,64,36,-4,2},
{1,288,734,63,30,-3,-2},
{1,1526,736,62,29,0,-1},
{1,1999,488,41,23,-13,-1},
{1,1044,737,70,36,-2,8},
{1,568,742,71,36,-1,8},
{1,1204,749,70,35,0,7},
{1,1430,753,72,39,2,3},
{1,1816,755,70,38,0,4},
{1,938,760,73,38,-1,4},
{1,481,762,72,41,0,-1},
{1,1278,766,72,40,2,0},
{1,1506,769,73,39,1,1},
{1,289,771,75,39,1,3},
{1,368,771,73,39,1,3},
{1,1890,774,71,36,1,2},
{1,643,775,69,37,1,3},
{1,1015,777,67,37,1,5},
{1,1354,780,64,37,2,5},
{1,1189,788,65,28,5,0},
{1,146,795,63,27,7,1},
{1,1999,515,45,26,-7,2},
{1,1999,545,44,23,-4,1},
},
{
{1,7,2,1,1,1,-1},
{1,17,2,1,1,1,-1},
{1,30,2,1,1,1,-1},
{1,87,2,1,1,1,-1},
{1,156,2,1,1,1,-1},
{1,226,2,27,21,-37,-9},
{1,325,2,60,31,0,5},
{1,460,2,61,31,5,5},
{1,596,2,71,34,-1,0},
{1,744,2,67,32,-3,0},
{1,888,2,71,31,-1,-1},
{1,1037,2,72,36,0,-6},
{1,1189,2,70,37,2,-5},
{1,1337,2,67,37,3,-3},
{1,1485,2,65,37,-7,-1},
{1,1630,2,65,37,-1,1},
{1,1775,2,70,36,-2,2},
{1,1927,2,69,36,3,4},
{1,82,33,66,35,4,7},
{1,232,34,68,41,-2,1},
{1,383,37,71,39,-1,3},
{1,888,37,64,37,-6,3},
{1,744,38,67,34,-5,4},
{1,815,41,69,33,-3,3},
{1,1031,42,71,31,-1,5},
{1,1927,42,68,30,-2,6},
{1,1262,44,72,30,-2,6},
{1,1338,45,72,30,2,8},
{1,1848,45,68,35,-2,5},
{1,1490,47,71,38,-1,2},
{1,687,76,70,37,0,5},
{1,80,77,70,36,0,6},
{1,154,77,68,34,4,8},
{1,1031,77,70,32,-2,8},
{1,458,78,71,32,1,8},
{1,226,79,66,30,0,8},
{1,920,84,72,32,0,2},
{1,383,80,70,30,0,2},
{1,1706,46,65,28,-1,2},
{1,1341,79,65,27,3,3},
{1,1410,87,64,28,8,4},
{1,1478,89,71,26,1,4},
{1,226,113,71,32,-1,-2},
{1,1105,88,67,32,-3,0},
{1,460,114,67,31,1,1},
{1,1856,117,72,36,0,-4},
{1,840,118,71,36,1,-2},
{1,687,117,68,35,-4,-3},
{1,1331,119,68,35,0,-1},
{1,155,115,65,35,-5,1},
{1,759,120,68,39,-4,-1},
{1,1073,124,70,37,-2,1},
{1,607,127,67,37,-3,3},
{1,1147,129,65,35,1,5},
{1,1786,129,65,33,5,5},
{1,2,148,64,32,8,4},
{1,678,156,72,34,0,0},
{1,460,149,67,32,-3,0},
{1,831,158,71,31,-1,-1},
{1,1930,159,72,36,0,-6},
{1,146,160,70,37,2,-5},
{1,1331,158,67,37,3,-3},
{1,1479,161,65,37,-7,-1},
{1,754,163,65,37,-1,1},
{1,906,166,70,36,-2,2},
{1,1142,168,69,36,3,4},
{1,1708,172,66,35,4,7},
{1,1778,172,68,41,-2,1},
{1,220,190,71,39,-1,3},
{1,609,168,63,37,-7,3},
{1,374,197,67,34,-5,4},
{1,1850,197,69,33,-3,3},
{1,1923,199,71,31,-1,5},
{1,2,203,67,30,-1,6},
{1,1215,203,67,29,1,7},
{1,752,204,66,30,-4,8},
{1,1479,202,65,29,1,9},
{1,1362,204,61,30,1,10},
{1,2000,2,42,22,-14,4},
{1,2,7,3,3,1,25},
{1,1142,208,69,36,3,4},
{1,1708,211,66,35,4,7},
{1,1628,215,68,41,-2,1},
{1,445,226,71,39,-1,3},
{1,1778,217,64,37,-6,3},
{1,1846,234,67,34,-5,4},
{1,1427,235,69,33,-3,3},
{1,1215,236,71,31,-1,5},
{1,373,235,68,30,-2,6},
{1,972,240,72,30,-2,6},
{1,1290,241,66,30,-4,8},
{1,145,243,68,34,-2,4},
{1,295,250,71,38,-1,2},
{1,1048,252,67,36,-1,4},
{1,1500,257,70,35,0,5},
{1,1769,258,64,33,0,7},
{1,370,269,62,31,-6,7},
{1,687,42,51,27,-13,5},
{1,9,7,3,3,19,27},
{1,1360,272,64,37,-6,3},
{1,1428,272,67,34,-5,4},
{1,972,274,69,33,-3,3},
{1,758,276,71,31,-1,5},
{1,588,279,68,30,-2,6},
{1,833,281,72,30,-2,6},
{1,73,284,71,30,1,8},
{1,1119,288,68,35,-2,5},
{1,292,292,71,38,-1,2},
{1,1045,292,69,37,1,5},
{1,367,304,70,36,0,6},
{1,148,281,64,34,0,8},
{1,1191,312,69,32,-1,8},
{1,576,313,66,31,-4,7},
{1,1790,314,66,29,0,7},
{1,216,317,63,27,3,7},
{1,1987,277,56,24,2,6},
{1,611,209,50,22,2,6},
{1,16,10,3,3,37,23},
{1,1264,318,68,30,-2,6},
{1,1933,321,72,30,-2,6},
{1,646,324,72,30,2,8},
{1,1118,327,68,35,-2,5},
{1,981,333,71,38,-1,2},
{1,1650,335,70,37,0,5},
{1,1498,336,70,36,0,6},
{1,1425,346,68,34,4,8},
{1,517,348,70,32,-2,8},
{1,1336,349,71,31,1,7},
{1,1190,348,66,29,0,7},
{1,798,353,69,32,-3,2},
{1,591,358,70,30,0,2},
{1,1802,364,64,27,-2,1},
{1,1056,366,63,27,3,3},
{1,909,281,58,25,2,3},
{1,1992,234,54,25,2,3},
{1,441,297,50,24,4,4},
{1,30,7,1,1,1,-1},
{1,224,375,71,38,-1,2},
{1,1497,376,70,37,0,5},
{1,516,384,70,36,0,6},
{1,1413,384,68,34,4,8},
{1,871,388,70,32,-2,8},
{1,142,390,71,32,1,8},
{1,798,389,66,29,0,7},
{1,668,392,72,32,0,2},
{1,1030,397,70,30,0,2},
{1,1950,398,65,28,-1,2},
{1,1104,407,65,27,3,3},
{1,2,406,63,27,7,3},
{1,217,417,67,25,-1,3},
{1,1556,417,69,32,-1,-2},
{1,744,422,67,31,-3,-1},
{1,454,424,64,31,0,1},
{1,815,424,64,29,4,3},
{1,1056,333,56,26,2,4},
{1,23,10,3,3,29,7},
{1,142,426,70,32,-2,8},
{1,668,428,71,32,1,8},
{1,1950,430,66,30,0,8},
{1,1173,431,72,32,0,2},
{1,1093,438,70,30,0,2},
{1,1852,440,65,28,-1,2},
{1,216,446,65,27,3,3},
{1,743,457,64,28,8,4},
{1,368,458,71,26,1,4},
{1,443,459,71,32,-1,-2},
{1,518,459,67,32,-3,0},
{1,76,462,67,31,1,1},
{1,1921,464,70,36,-2,-4},
{1,1167,467,71,36,1,-2},
{1,1242,467,65,34,-1,-2},
{1,1701,468,68,34,0,0},
{1,1093,472,61,34,-3,2},
{1,956,458,53,33,1,3},
{1,82,19,3,3,-43,-1},
{1,589,479,70,30,0,2},
{1,1852,472,65,28,-1,2},
{1,216,477,65,27,3,3},
{1,737,489,64,28,8,4},
{1,505,495,71,26,1,4},
{1,805,499,71,32,-1,-2},
{1,880,501,67,32,-3,0},
{1,1387,503,67,31,1,1},
{1,1849,504,72,36,0,-4},
{1,1630,506,71,36,1,-2},
{1,1158,507,68,35,-4,-3},
{1,151,508,68,35,0,-1},
{1,223,509,64,34,-4,2},
{1,580,513,65,33,-1,3},
{1,1016,518,68,37,0,1},
{1,736,521,64,35,-2,3},
{1,505,525,65,34,1,4},
{1,665,358,51,27,9,9},
{1,87,7,1,1,1,-1},
{1,355,531,71,26,1,4},
{1,430,537,71,32,-1,-2},
{1,879,537,67,32,-3,0},
{1,1387,538,67,31,1,1},
{1,1610,546,72,36,0,-4},
{1,76,545,71,36,1,-2},
{1,1157,546,68,35,-4,-3},
{1,1458,546,68,35,0,-1},
{1,649,549,65,35,-5,1},
{1,574,550,68,39,-4,-1},
{1,718,560,69,37,-1,1},
{1,1761,562,66,36,-4,2},
{1,505,563,65,34,1,4},
{1,879,573,65,32,5,6},
{1,1380,573,63,31,7,5},
{1,1268,391,56,30,4,4},
{1,883,424,56,29,8,3},
{1,224,348,49,22,11,6},
{1,156,7,1,1,1,-1},
{1,1447,585,72,36,0,-4},
{1,1610,586,71,36,1,-2},
{1,646,588,68,35,-4,-3},
{1,1301,589,68,35,0,-1},
{1,219,590,65,35,-5,1},
{1,1170,591,68,39,-4,-1},
{1,522,601,69,37,-1,1},
{1,718,601,67,37,-3,3},
{1,1759,602,65,34,1,4},
{1,860,609,65,33,5,5},
{1,361,615,64,31,8,5},
{1,789,619,62,30,10,4},
{1,1600,626,67,32,-3,0},
{1,1091,628,71,30,-1,0},
{1,1828,629,67,29,-1,1},
{1,1092,551,56,29,-8,3},
{1,1985,618,56,29,-4,5},
{1,378,385,49,25,3,7},
{1,30,12,1,1,1,-1},
{1,1514,631,65,35,-5,1},
{1,1671,632,68,39,-4,-1},
{1,1166,634,70,37,-2,1},
{1,522,642,67,37,-3,3},
{1,1000,646,65,35,1,5},
{1,283,650,65,33,5,5},
{1,1313,651,64,32,8,4},
{1,742,653,72,34,0,0},
{1,2,657,67,32,-3,0},
{1,1583,662,71,30,-1,0},
{1,1381,665,72,36,0,-6},
{1,1240,665,69,37,1,-5},
{1,215,658,59,37,-5,-3},
{1,1892,672,64,37,-6,-1},
{1,1141,675,64,36,-2,0},
{1,502,683,66,35,-4,1},
{1,1720,686,60,34,-6,4},
{1,1242,591,52,29,-10,11},
{1,87,12,1,1,1,-1},
{1,425,690,65,35,1,5},
{1,738,691,65,33,5,5},
{1,1313,687,64,32,8,4},
{1,892,695,72,34,0,0},
{1,2,693,67,32,-3,0},
{1,1061,702,71,31,-1,-1},
{1,1381,705,72,36,0,-6},
{1,1601,710,70,37,2,-5},
{1,145,713,67,37,3,-3},
{1,1457,712,65,37,-7,-1},
{1,1136,715,64,37,-2,1},
{1,494,722,70,36,-2,2},
{1,1675,724,66,34,0,4},
{1,2,729,66,34,4,6},
{1,646,731,67,40,-1,0},
{1,876,733,58,38,-6,2},
{1,1935,735,62,35,-6,3},
{1,355,734,52,33,-2,5},
{1,82,26,3,3,-35,11},
{1,1745,741,67,32,-3,0},
{1,1355,745,71,31,-1,-1},
{1,1592,751,72,36,0,-6},
{1,72,755,70,37,2,-5},
{1,1118,756,67,37,3,-3},
{1,146,754,65,37,-7,-1},
{1,1668,762,65,37,-1,1},
{1,215,768,70,36,-2,2},
{1,717,770,69,35,3,5},
{1,2,767,66,34,4,6},
{1,790,773,68,41,-2,1},
{1,1965,774,71,38,-1,2},
{1,862,775,63,37,-7,3},
{1,1737,777,66,34,-6,4},
{1,557,782,66,31,-2,5},
{1,1583,791,63,31,-3,5},
{1,72,796,66,28,-2,6},
{1,1422,796,57,20,-7,0},
{1,226,27,3,3,-17,17},
},
}}
gustLow.lanes={}
for i,tiles in ipairs(gustLow.bands) do
    gustLow.lanes[i]={pixels=88,pages=gustPages,tiles=tiles}
end
local gustHigh={pixels=140,pages=gustPages,bands={
{
{2,2,2,1,1,1,-1},
{2,12,2,1,1,1,-1},
{2,22,2,4,4,60,4},
{2,35,2,92,28,14,2},
{2,136,2,94,41,-16,1},
{2,239,2,95,42,-11,2},
{2,424,2,101,43,-9,3},
{2,630,2,106,45,-8,3},
{2,841,2,106,48,-4,2},
{2,1067,2,108,55,-2,11},
{2,1288,2,108,54,0,12},
{2,1515,2,110,62,0,4},
{2,1745,2,112,61,2,5},
{2,2,34,110,59,0,7},
{2,226,54,115,65,-1,-1},
{2,345,54,112,64,0,0},
{2,736,54,116,62,0,0},
{2,856,58,115,60,3,2},
{2,975,61,119,60,5,4},
{2,1861,63,119,59,7,5},
{2,2,108,118,57,8,3},
{2,566,112,117,58,9,4},
{2,1098,119,115,59,7,5},
{2,687,120,113,60,5,6},
{2,345,122,111,60,5,8},
{2,124,123,109,61,5,9},
{2,1855,126,108,60,6,10},
{2,1503,133,115,59,-1,11},
{2,1328,171,113,59,-3,13},
{2,804,175,114,57,0,15},
{2,1622,180,116,57,2,17},
{2,1155,182,118,58,2,16},
{2,237,186,119,60,1,12},
{2,1742,190,119,61,-1,11},
{2,1865,190,119,60,-3,10},
{2,360,230,118,55,-4,7},
{2,482,234,117,62,-5,0},
{2,804,238,116,61,-2,3},
{2,603,241,112,60,0,6},
{2,113,243,115,59,-1,9},
{2,1038,243,113,60,-1,10},
{2,1393,248,112,59,-4,13},
{2,1865,254,113,63,-1,9},
{2,1272,288,115,63,-1,9},
{2,1509,289,116,60,-2,6},
{2,463,300,116,63,-4,3},
{2,835,303,116,62,-4,4},
{2,2,306,116,60,-4,4},
{2,955,307,115,59,-3,7},
{2,1740,309,114,59,2,9},
{2,1858,321,110,59,2,11},
{2,1074,349,113,65,-1,5},
{2,1506,353,112,63,0,7},
{2,699,362,109,61,-5,9},
{2,583,365,110,62,-4,8},
{2,453,367,111,60,-3,10},
{2,1622,367,111,57,-3,11},
{2,1306,369,111,56,-3,12},
{2,928,370,112,55,-2,11},
{2,1852,384,111,62,-1,4},
{2,112,413,112,61,2,5},
{2,1044,418,110,59,0,7},
{2,697,427,115,65,-1,-1},
{2,1531,428,112,64,0,0},
{2,816,429,116,62,0,0},
{2,352,431,115,60,3,2},
{2,1842,450,119,60,5,4},
{2,1158,476,119,59,7,5},
{2,936,481,118,57,8,3},
{2,1647,484,116,58,8,4},
{2,1281,488,114,59,6,5},
{2,344,495,110,59,4,7},
{2,693,496,108,59,4,9},
{2,580,498,109,59,5,11},
{2,1876,514,107,57,7,13},
{2,936,429,103,47,9,9},
{2,2,534,102,44,-10,10},
{2,122,306,97,41,-15,3},
{2,360,186,93,40,-15,4},
{2,1058,481,92,35,-10,1},
{2,927,542,115,60,3,2},
{2,1633,546,119,60,5,4},
{2,1275,551,119,59,7,5},
{2,805,550,118,57,8,3},
{2,568,561,117,58,9,4},
{2,1756,564,115,59,7,5},
{2,1875,575,113,60,5,6},
{2,1046,595,111,60,5,8},
{2,1161,595,109,61,5,9},
{2,1398,610,108,60,6,10},
{2,802,611,115,59,-1,11},
{2,442,613,107,57,-9,15},
{2,689,617,105,56,-7,16},
{2,331,619,107,47,-5,9},
{2,117,638,102,46,-6,10},
{2,223,638,98,40,-6,6},
{2,921,656,97,39,-3,7},
{2,1625,659,96,38,2,10},
{2,1974,36,66,20,-20,-4},
{2,1224,670,117,58,9,4},
{2,325,674,115,59,7,5},
{2,798,674,113,60,5,6},
{2,669,677,111,60,5,8},
{2,1725,687,109,61,5,9},
{2,1838,697,108,60,6,10},
{2,1031,710,115,59,-1,11},
{2,1571,723,112,59,-4,13},
{2,1262,732,112,57,-2,15},
{2,338,737,113,57,-1,17},
{2,2,738,112,56,-2,16},
{2,568,741,109,60,-3,12},
{2,897,760,107,57,-3,13},
{2,1918,761,104,54,0,6},
{2,1378,773,101,55,3,7},
{2,118,738,99,54,9,8},
{2,681,741,98,53,14,9},
{2,117,601,89,33,13,17},
{2,1098,61,66,18,0,6},
{2,1218,793,109,61,5,9},
{2,783,796,108,60,6,10},
{2,118,800,115,59,-1,11},
{2,569,805,113,59,-3,13},
{2,1702,814,114,57,0,15},
{2,895,824,116,57,2,17},
{2,1331,832,118,58,2,16},
{2,1453,834,118,60,0,12},
{2,356,855,118,61,-2,11},
{2,1132,858,116,55,-4,5},
{2,116,863,113,55,-3,7},
{2,478,868,110,62,0,0},
{2,1936,878,107,60,7,2},
{2,802,885,106,59,6,7},
{2,1016,893,102,58,10,10},
{2,1355,898,104,58,-8,12},
{2,1463,898,98,57,-10,13},
{2,2,902,92,48,-12,10},
{2,1098,83,68,19,16,11},
{2,233,905,114,57,0,15},
{2,1122,917,116,57,2,17},
{2,351,920,118,58,2,16},
{2,1682,932,119,60,1,12},
{2,1924,942,119,61,-1,11},
{2,708,948,119,60,-3,10},
{2,947,955,118,55,-4,7},
{2,1353,960,117,62,-5,0},
{3,2,2,115,61,-1,3},
{3,235,2,111,60,1,6},
{3,461,2,115,59,-1,9},
{3,684,2,113,59,-1,11},
{3,904,2,106,59,-6,13},
{3,1123,2,104,57,-8,15},
{3,1345,2,108,62,-4,8},
{3,1566,2,100,59,-8,7},
{3,1778,2,100,49,-4,11},
{3,1014,45,100,47,0,13},
{3,801,47,65,31,-17,1},
{3,1882,50,119,61,-1,11},
{3,1670,55,119,60,-3,10},
{3,350,65,118,55,-4,7},
{3,680,65,117,62,-5,0},
{3,1457,65,116,61,-2,3},
{3,2,67,112,60,0,6},
{3,472,90,115,59,-1,9},
{3,118,107,113,60,-1,10},
{3,1207,115,108,59,-6,13},
{3,1908,115,109,63,-5,9},
{3,1319,116,109,63,-5,9},
{3,1577,119,106,60,-4,6},
{3,1432,130,104,59,-2,7},
{3,591,131,103,59,1,7},
{3,1687,119,102,57,4,7},
{3,1793,158,101,51,9,15},
{3,698,131,97,52,9,16},
{3,115,171,92,48,10,20},
{3,1793,55,70,34,-2,8},
{3,1135,178,116,61,-2,3},
{3,1898,182,112,60,0,6},
{3,1540,183,115,59,-1,9},
{3,1367,193,113,60,-1,10},
{3,898,201,112,59,-4,13},
{3,1014,218,113,63,-1,9},
{3,116,223,114,63,-2,9},
{3,1775,226,113,60,-3,6},
{3,234,232,112,63,-4,3},
{3,1131,243,111,62,-3,4},
{3,1484,246,108,60,0,4},
{3,350,252,107,59,5,7},
{3,804,264,104,58,4,10},
{3,1596,279,103,58,9,10},
{3,680,286,112,58,-2,12},
{3,1022,285,104,56,-6,14},
{3,461,252,93,55,-13,15},
{3,558,299,93,40,-9,4},
{3,1810,303,92,40,-4,6},
{3,1906,303,112,59,-4,13},
{3,1473,310,113,63,-1,9},
{3,324,315,115,63,-1,9},
{3,443,343,116,60,-2,6},
{3,912,347,116,63,-4,3},
{3,1590,348,116,62,-4,4},
{3,2,351,115,60,-5,4},
{3,121,354,114,59,-2,7},
{3,1826,366,112,59,4,9},
{3,1368,377,108,59,4,11},
{3,794,379,112,65,-2,5},
{3,563,402,111,63,1,7},
{3,352,407,109,61,-5,9},
{3,1710,408,99,58,-11,12},
{3,1137,412,102,56,-10,14},
{3,1590,414,103,54,-7,14},
{3,101,417,103,52,-3,14},
{3,1243,426,102,42,2,6},
{3,591,90,84,37,6,9},
{3,1349,440,116,63,-4,3},
{3,208,444,116,62,-4,4},
{3,1012,463,116,60,-4,4},
{3,465,469,115,59,-3,7},
{3,328,472,114,59,2,9},
{3,1132,472,110,59,2,11},
{3,2,473,113,65,-1,5},
{3,1925,478,112,63,0,7},
{3,1246,507,109,61,-5,9},
{3,695,508,105,59,-9,11},
{3,804,524,106,60,-8,10},
{3,584,527,105,57,-5,11},
{3,1696,528,105,56,-1,12},
{3,327,535,103,54,1,12},
{3,1584,535,104,52,6,14},
{3,2,542,100,51,6,15},
{3,1465,559,99,50,11,14},
{3,1144,535,93,38,11,10},
{3,698,187,61,34,1,12},
{3,106,564,114,59,2,9},
{3,914,584,110,59,2,11},
{3,1028,585,113,65,-1,5},
{3,547,588,112,63,0,7},
{3,1568,591,109,61,-5,9},
{3,316,593,109,62,-5,8},
{3,1913,605,109,60,-5,10},
{3,1356,621,108,57,-4,11},
{3,118,627,108,56,-2,12},
{3,663,634,106,54,0,12},
{3,887,647,107,54,3,12},
{3,1681,648,107,54,7,12},
{3,998,654,103,59,7,7},
{3,545,655,102,56,12,8},
{3,230,659,111,57,-1,5},
{3,1254,682,100,54,-8,4},
{3,1145,577,92,49,-18,-3},
{3,1254,630,92,48,-14,-2},
{3,801,82,61,31,21,13},
{3,109,687,109,61,-5,9},
{3,757,692,110,62,-4,8},
{3,1667,706,111,60,-3,10},
{3,1782,708,111,57,-3,11},
{3,1469,716,111,56,-3,12},
{3,222,720,110,55,-2,11},
{3,1087,738,110,62,0,4},
{3,1318,740,111,61,3,5},
{3,2,752,107,59,3,7},
{3,788,759,115,65,-1,-1},
{3,1584,770,112,64,0,0},
{3,1700,770,114,62,0,0},
{3,440,772,105,60,-7,2},
{3,218,779,107,59,-7,3},
{3,1925,781,103,55,-9,1},
{3,1019,804,101,55,-7,3},
{3,549,810,98,55,-4,5},
{3,2,815,98,44,0,-2},
{3,329,821,95,38,3,-4},
{3,746,828,111,56,-3,12},
{3,1410,832,112,55,-2,11},
{3,1700,836,111,62,-1,4},
{3,1815,840,112,61,2,5},
{3,215,842,110,59,0,7},
{3,971,863,115,65,-1,-1},
{3,1195,868,112,64,0,0},
{3,329,888,116,62,0,0},
{3,760,888,115,60,3,2},
{3,1423,899,117,60,3,4},
{3,1931,901,115,59,3,5},
{3,112,905,113,57,3,3},
{3,449,929,108,57,2,5},
{3,879,932,105,57,1,7},
{3,1095,936,101,57,3,9},
{3,561,947,101,56,7,12},
{3,666,952,99,47,13,7},
{3,695,464,69,39,-11,3},
{3,230,611,68,34,-6,2},
},
{
{2,7,2,1,1,1,-1},
{2,17,2,1,1,1,-1},
{2,30,2,1,1,1,-1},
{2,131,2,1,1,1,-1},
{2,234,2,1,1,1,-1},
{2,338,2,82,48,-18,4},
{2,529,2,97,48,5,8},
{2,740,2,97,48,11,8},
{2,951,2,112,52,0,0},
{2,1179,2,105,50,-5,0},
{2,1400,2,111,48,-3,0},
{2,1629,2,112,56,0,-10},
{2,1861,2,109,57,3,-7},
{2,116,47,106,57,6,-5},
{2,630,51,102,57,-10,-3},
{2,461,54,101,56,-3,0},
{2,1400,54,108,55,-2,3},
{2,1179,60,108,55,4,7},
{2,1629,62,112,64,-2,0},
{2,1745,67,106,63,-2,3},
{2,1512,68,113,61,-3,5},
{2,1291,60,99,57,-9,5},
{2,1394,113,105,54,-9,6},
{2,1217,121,107,51,-5,5},
{2,804,122,111,48,-3,8},
{2,919,125,112,46,4,10},
{2,1629,130,112,46,-4,10},
{2,2,169,111,46,3,12},
{2,460,174,108,52,-4,8},
{2,922,175,112,59,-2,3},
{2,1038,182,113,57,-3,7},
{2,572,174,109,56,1,10},
{2,685,184,115,53,-1,11},
{2,117,188,110,51,-2,13},
{2,1445,196,112,48,2,12},
{2,2,219,107,45,5,11},
{2,1277,234,112,50,0,4},
{2,924,238,110,46,0,4},
{2,1561,241,108,44,6,4},
{2,461,114,101,42,5,4},
{2,1155,244,113,42,-1,6},
{2,232,250,111,39,3,5},
{2,1673,255,110,50,-2,-4},
{2,347,289,112,49,2,-1},
{2,1155,290,111,55,-5,-5},
{2,719,303,112,55,0,-5},
{2,583,305,112,56,2,-4},
{2,232,293,106,54,-6,-4},
{2,1629,309,107,54,1,-2},
{2,1391,311,111,54,3,2},
{2,342,342,107,59,-7,-1},
{2,122,351,109,58,-1,2},
{2,1191,355,111,56,3,4},
{2,237,123,102,53,2,7},
{2,1745,134,102,50,8,8},
{2,235,351,100,49,12,7},
{2,812,369,112,53,0,1},
{2,2,370,106,50,-4,0},
{2,1737,372,111,48,-3,0},
{2,235,405,113,57,1,-9},
{2,1191,415,109,57,3,-7},
{2,1421,420,106,57,6,-5},
{2,2,424,102,57,-10,-3},
{2,1737,424,101,56,-3,0},
{2,1304,429,108,55,-2,3},
{2,471,431,108,55,4,7},
{2,228,466,112,64,-2,0},
{2,583,431,106,63,-2,3},
{2,108,478,113,60,-3,4},
{2,1416,481,98,57,-10,5},
{2,471,490,105,52,-9,6},
{2,816,495,107,51,-5,5},
{2,1518,496,111,47,-3,7},
{2,1767,514,105,46,-3,10},
{2,225,534,111,45,-3,9},
{2,2,485,102,45,-6,11},
{2,1058,539,107,52,-3,8},
{2,1169,539,102,52,-2,10},
{2,2,268,94,33,8,7},
{2,1974,2,24,30,-20,12},
{2,108,542,108,55,4,7},
{2,1399,542,112,64,-2,0},
{2,458,546,106,63,-2,3},
{2,1515,547,113,61,-3,5},
{2,340,558,98,57,-10,5},
{2,693,559,105,54,-9,6},
{2,220,583,107,51,-5,5},
{2,2,601,111,48,-3,8},
{2,927,606,111,46,3,10},
{2,1632,610,112,45,-4,9},
{2,1510,612,111,46,3,12},
{2,1274,614,108,52,-4,8},
{2,553,623,112,58,-2,4},
{2,1748,627,108,56,0,6},
{2,1860,639,108,54,0,10},
{2,2,653,100,51,0,11},
{2,1022,659,98,47,-10,13},
{2,1124,660,96,45,-4,13},
{2,2002,2,10,25,24,21},
{2,1510,662,99,57,-9,5},
{2,444,674,105,54,-9,6},
{2,1345,674,107,51,-5,5},
{2,553,685,111,48,-3,8},
{2,106,688,112,46,4,10},
{2,915,710,112,46,-4,10},
{2,1456,723,111,46,3,12},
{2,1150,732,108,52,-4,8},
{2,222,737,112,59,-2,3},
{2,455,737,109,57,1,7},
{2,784,738,109,54,1,10},
{2,1687,752,114,52,0,12},
{2,1805,761,109,49,-3,13},
{2,1008,773,107,47,-3,11},
{2,1483,786,103,44,1,12},
{2,223,682,98,41,6,11},
{2,1950,697,87,35,3,9},
{2,1119,788,95,40,-3,2},
{2,566,54,60,29,2,11},
{2,2,798,112,46,4,10},
{2,338,798,112,46,-4,10},
{2,454,805,111,46,3,12},
{2,1590,808,108,52,-4,8},
{2,1820,819,112,59,-2,3},
{2,1015,832,113,57,-3,7},
{2,1936,819,109,55,1,9},
{2,237,848,115,53,-1,11},
{2,2,848,110,50,-2,12},
{2,686,860,112,48,2,12},
{2,1575,864,103,45,1,11},
{2,1682,875,112,50,0,4},
{2,1798,882,110,46,0,4},
{2,912,893,100,41,-2,3},
{2,1252,894,99,40,5,4},
{2,237,800,96,38,10,4},
{2,686,798,90,37,10,5},
{2,1967,126,78,38,6,6},
{2,1984,60,39,21,51,23},
{2,592,912,112,59,-2,3},
{2,1565,913,113,57,-3,7},
{2,98,922,109,56,1,10},
{2,1805,932,115,53,-1,11},
{2,473,934,110,50,-2,12},
{2,831,948,112,48,2,12},
{2,1242,938,107,45,5,11},
{2,211,966,112,50,0,4},
{3,121,2,110,46,0,4},
{3,350,2,107,42,5,4},
{3,580,2,100,40,4,4},
{3,801,2,99,41,11,7},
{3,1014,2,105,39,-3,5},
{3,1231,2,110,48,-2,-4},
{3,1457,2,105,48,-5,-2},
{3,1670,2,104,46,2,2},
{3,1882,2,99,44,7,4},
{3,580,46,96,40,12,6},
{3,1985,2,27,18,31,26},
{3,121,52,110,51,-2,13},
{3,1118,63,112,48,2,12},
{3,1234,54,107,45,5,11},
{3,870,65,112,50,0,4},
{3,235,66,110,46,0,4},
{3,1345,68,107,44,5,4},
{3,986,96,100,42,4,4},
{3,1090,115,113,42,-1,6},
{3,1793,115,111,39,3,5},
{3,235,116,110,50,-2,-4},
{3,801,119,105,49,-5,-1},
{3,349,124,110,54,-4,-6},
{3,2,131,109,55,-3,-5},
{3,910,142,111,55,1,-3},
{3,463,153,105,52,-7,-4},
{3,1025,161,106,53,0,-1},
{3,235,170,96,52,-4,2},
{3,799,172,95,51,3,5},
{3,1577,65,79,22,7,18},
{3,335,182,110,46,0,4},
{3,1255,183,108,44,6,4},
{3,1687,180,101,42,5,4},
{3,572,194,113,42,-1,6},
{3,449,209,111,39,3,5},
{3,2,223,110,50,-2,-4},
{3,1659,226,112,49,2,-1},
{3,689,227,111,55,-5,-5},
{3,564,240,112,55,0,-5},
{3,1246,243,112,56,2,-4},
{3,1892,246,106,53,-6,-5},
{3,1362,257,107,53,1,-1},
{3,2,277,100,52,-8,2},
{3,912,285,106,58,-6,-2},
{3,106,290,108,57,-2,1},
{3,1703,290,103,54,-5,4},
{3,218,299,102,51,2,7},
{3,1246,303,97,47,5,9},
{3,2016,2,3,4,-39,22},
{3,1130,309,111,39,3,5},
{3,1347,314,110,50,-2,-4},
{3,796,326,112,49,2,-1},
{3,563,343,111,55,-5,-5},
{3,678,348,112,55,0,-5},
{3,1710,348,112,56,2,-4},
{3,1032,352,106,54,-6,-4},
{3,1142,354,107,54,1,-2},
{3,1253,368,111,54,3,2},
{3,1480,377,106,59,-6,-1},
{3,239,382,109,58,-1,2},
{3,1942,366,103,55,-5,5},
{3,678,407,102,53,2,7},
{3,1032,410,101,49,9,9},
{3,910,414,98,48,12,8},
{3,2,415,95,45,15,7},
{3,1942,425,102,49,-2,1},
{3,1813,429,97,44,-3,-2},
{3,2023,2,1,1,1,-1},
{3,1469,440,112,55,0,-5},
{3,784,448,112,56,2,-4},
{3,900,466,106,54,-6,-4},
{3,584,469,107,54,1,-2},
{3,1697,470,111,54,3,2},
{3,1585,472,107,59,-7,-1},
{3,1812,477,109,58,-1,2},
{3,1469,499,111,56,3,4},
{3,1359,507,102,53,2,7},
{3,119,510,101,50,9,8},
{3,224,510,99,48,13,8},
{3,914,527,112,53,0,1},
{3,446,532,105,50,-5,0},
{3,1030,535,110,46,-2,0},
{3,1805,539,105,43,-1,1},
{3,1914,545,107,56,1,-8},
{3,465,407,88,44,-6,6},
{3,224,562,88,45,2,9},
{3,2028,2,3,3,-83,-51},
{3,1241,572,111,54,3,2},
{3,693,571,107,59,-7,-1},
{3,434,586,109,58,-1,2},
{3,1692,588,111,56,3,4},
{3,1359,564,102,53,2,7},
{3,1807,586,102,50,8,8},
{3,804,588,100,48,12,8},
{3,2,627,112,53,0,1},
{3,1145,630,105,50,-5,0},
{3,773,640,110,48,-2,0},
{3,429,648,112,56,0,-10},
{3,1792,648,109,56,3,-8},
{3,1468,613,91,57,-9,-5},
{3,1563,656,100,56,-10,-2},
{3,1905,669,100,56,-2,0},
{3,1358,682,107,54,-3,4},
{3,2,684,103,52,-1,6},
{3,1105,684,95,50,-1,10},
{3,2035,2,1,1,1,-1},
{3,651,692,102,53,2,7},
{3,871,705,102,50,8,8},
{3,345,708,100,49,12,7},
{3,449,715,112,53,0,1},
{3,977,717,106,50,-4,0},
{3,1897,729,111,48,-3,0},
{3,1201,740,113,56,1,-10},
{3,565,749,109,57,3,-7},
{3,678,758,106,57,6,-5},
{3,113,752,101,57,-9,-3},
{3,336,761,100,56,-2,0},
{3,907,771,108,55,-2,3},
{3,1433,776,108,52,4,6},
{3,1818,781,103,52,7,10},
{3,1201,800,105,61,-3,1},
{3,1310,805,96,59,-16,3},
{3,113,813,98,55,-10,5},
{3,651,819,91,51,-9,7},
{3,2016,10,28,8,-32,12},
{3,861,830,106,50,-4,0},
{3,428,836,111,48,-3,0},
{3,1526,838,113,57,1,-9},
{3,1931,840,109,57,3,-7},
{3,2,863,106,57,6,-5},
{3,1090,863,101,57,-9,-3},
{3,543,869,101,56,-3,0},
{3,648,888,108,55,-2,3},
{3,1311,891,108,53,4,7},
{3,1544,899,112,63,-2,-1},
{3,1660,902,105,62,-3,2},
{3,1769,905,113,59,-3,3},
{3,2,924,98,56,-10,4},
{3,988,932,103,51,-9,7},
{3,1200,936,107,50,-5,4},
{3,1311,948,106,47,2,7},
{3,769,952,104,44,-4,10},
{3,229,905,95,43,-5,11},
{3,2,190,79,28,1,2},
},
}}
gustHigh.lanes={}
for i,tiles in ipairs(gustHigh.bands) do
    gustHigh.lanes[i]={pixels=140,pages=gustPages,tiles=tiles}
end
E.AutumnGust={fps=24,width=512,intro=13,hold=48,ending=19,phaseStep=4,banks={[192]=gustLow,[288]=gustLow,[384]=gustHigh,[480]=gustHigh,[576]=gustHigh,[660]=gustHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.AutumnGust.banks)

do
local auraPages={
{"StudioDruidRestorationChannelPlusSize288Page101.tga",512,1024},
{"StudioDruidRestorationChannelPlusSize480Page101.tga",1024,1024},
{"StudioDruidRestorationChannelPlusSize480Page102.tga",256,128},
}
local NatureAuraSoftLow={pixels=64,pages=auraPages,tiles={
{1,496,2,1,1,1,-1},
{1,501,2,1,1,1,-1},
{1,492,593,18,7,0,-35},
{1,148,698,28,40,6,-2},
{1,44,652,38,44,-2,0},
{1,192,646,40,47,-4,-1},
{1,148,646,40,48,-4,0},
{1,447,593,41,54,-5,-2},
{1,100,586,41,55,-3,-1},
{1,2,593,42,55,-2,1},
{1,351,584,42,56,-2,2},
{1,2,532,45,57,-1,3},
{1,51,532,45,57,-1,3},
{1,251,645,44,51,0,-1},
{1,299,645,44,51,0,1},
{1,398,644,44,52,0,2},
{1,304,475,44,52,0,4},
{1,100,476,44,51,0,5},
{1,2,64,44,57,0,1},
{1,2,2,44,58,0,0},
{1,152,245,44,54,0,-2},
{1,354,185,44,55,0,-1},
{1,402,185,45,55,1,1},
{1,200,245,45,54,1,2},
{1,399,531,45,48,1,-2},
{1,352,475,46,52,2,-6},
{1,305,361,46,53,2,-5},
{1,355,361,46,53,2,-3},
{1,405,361,46,53,2,-1},
{1,451,185,46,55,2,-1},
{1,105,125,46,56,2,-2},
{1,148,476,46,51,2,-5},
{1,148,531,46,50,2,-4},
{1,198,531,47,50,3,-2},
{1,249,531,47,50,3,0},
{1,300,531,47,50,3,2},
{1,249,245,47,54,3,-2},
{1,2,186,47,55,3,-1},
{1,300,245,45,54,1,0},
{1,455,361,44,53,0,1},
{1,2,362,45,53,1,3},
{1,51,362,44,53,0,5},
{1,402,475,44,52,0,4},
{1,351,531,44,49,0,-1},
{1,305,418,44,53,0,-3},
{1,353,418,44,53,0,-1},
{1,152,303,44,54,0,0},
{1,401,418,44,53,0,1},
{1,50,2,44,58,0,-2},
{1,155,125,45,56,-1,-2},
{1,53,186,45,55,-1,-3},
{1,200,303,45,54,-1,-2},
{1,249,303,45,54,-1,0},
{1,449,418,45,53,-1,1},
{1,198,476,45,51,-1,1},
{1,204,125,45,56,-1,-2},
{1,253,125,44,56,0,0},
{1,50,64,45,57,-1,1},
{1,301,125,45,56,-1,2},
{1,99,64,45,57,-1,3},
{1,148,64,45,57,-1,3},
{1,247,476,44,51,0,-1},
{1,100,531,44,51,0,1},
{1,450,475,44,52,0,2},
}}
local NatureAuraSoftHigh={pixels=116,pages=auraPages,tiles={
{2,1011,2,1,1,1,-1},
{2,1016,2,1,1,1,-1},
{2,354,176,32,10,0,-64},
{3,74,2,62,78,-4,2},
{3,2,2,68,81,-6,3},
{2,758,924,70,85,-8,-3},
{2,603,623,70,86,-8,0},
{2,511,920,72,96,-8,-4},
{2,947,421,73,98,-5,-2},
{2,511,817,74,99,-4,1},
{2,259,818,76,99,-4,5},
{2,428,817,79,101,-1,5},
{2,176,818,79,101,-1,5},
{2,336,924,78,90,0,-2},
{2,428,922,78,91,0,1},
{2,176,923,78,91,0,3},
{2,346,721,78,92,0,6},
{2,428,721,78,92,0,10},
{2,419,2,78,104,0,0},
{2,2,2,78,105,0,1},
{2,775,319,78,98,0,-4},
{2,857,319,78,98,0,-2},
{2,939,319,79,98,1,2},
{2,346,422,81,97,3,5},
{2,679,816,79,86,1,-4},
{2,176,721,80,93,2,-11},
{2,89,623,81,94,3,-8},
{2,174,623,82,94,4,-6},
{2,853,523,82,95,4,-3},
{2,263,216,82,99,4,-3},
{2,505,215,81,100,3,-2},
{2,260,721,82,93,4,-7},
{2,2,722,82,89,4,-7},
{2,2,815,82,89,4,-5},
{2,922,815,83,89,5,-1},
{2,592,816,83,89,5,3},
{2,431,422,83,97,5,-3},
{2,2,320,83,98,5,-2},
{2,686,422,79,96,1,-2},
{2,686,522,78,96,0,2},
{2,939,523,79,95,1,5},
{2,2,524,78,95,0,7},
{2,510,721,78,92,0,8},
{2,592,721,78,91,0,-5},
{2,84,524,78,95,0,-5},
{2,166,524,78,95,0,-3},
{2,346,523,78,96,0,0},
{2,248,524,78,95,0,3},
{2,501,2,79,104,-1,-4},
{2,755,109,80,102,-2,-4},
{2,518,422,80,97,-2,-5},
{2,602,422,80,97,-2,-3},
{2,428,523,79,96,-1,0},
{2,511,523,79,96,-1,2},
{2,674,721,80,91,-2,1},
{2,349,216,81,99,-3,-3},
{2,590,215,80,100,-2,-2},
{2,674,215,79,100,-1,2},
{2,505,110,79,101,-1,5},
{2,755,2,79,103,-1,5},
{2,839,109,79,102,-1,6},
{2,922,721,78,90,0,-2},
{2,758,721,78,91,0,1},
{2,840,721,78,91,0,3},
}}
E.NatureAuraSoft={width=390,fps=24,intro=16,hold=48,ending=20,introLevels={0.00000,0.00000,0.00105,0.00560,0.02028,0.05605,0.11738,0.20652,0.31074,0.42614,0.54545,0.66313,0.76962,0.86262,0.93532,0.98263},banks={[192]=NatureAuraSoftLow,[288]=NatureAuraSoftLow,[384]=NatureAuraSoftHigh,[480]=NatureAuraSoftHigh,[576]=NatureAuraSoftHigh,[660]=NatureAuraSoftHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.NatureAuraSoft.banks)
local NatureAuraStrongLow={pixels=64,pages=auraPages,tiles={
{1,506,2,1,1,1,-1},
{1,496,7,1,1,1,-1},
{1,44,700,30,34,10,-8},
{1,192,697,35,42,11,-2},
{1,2,652,38,45,8,1},
{1,446,651,38,47,6,1},
{1,105,304,40,53,4,-3},
{1,251,585,43,56,1,-2},
{1,399,583,44,57,0,-3},
{1,48,593,44,55,-2,-3},
{1,349,644,45,54,-1,0},
{1,96,645,48,52,0,2},
{1,148,585,47,57,1,-1},
{1,199,585,48,57,2,3},
{1,448,531,48,58,2,4},
{1,298,585,47,56,1,0},
{1,298,303,46,54,0,2},
{1,98,2,44,58,0,0},
{1,350,125,44,56,0,-2},
{1,354,244,45,55,1,1},
{1,2,476,45,52,1,2},
{1,403,244,46,55,2,-3},
{1,2,419,46,53,2,-1},
{1,197,64,47,57,3,-1},
{1,52,419,47,53,3,-1},
{1,103,419,46,53,2,3},
{1,146,2,46,58,2,0},
{1,398,125,45,56,1,0},
{1,348,303,45,54,1,2},
{1,397,303,46,54,2,4},
{1,248,64,46,57,2,-5},
{1,447,125,44,56,0,-2},
{1,196,2,45,58,-1,-2},
{1,453,244,46,55,-2,-3},
{1,447,303,45,54,-1,0},
{1,2,304,48,54,0,0},
{1,298,64,47,57,1,-1},
{1,349,64,48,57,2,3},
{1,245,2,45,58,-1,4},
{1,105,185,46,56,0,0},
{1,54,304,47,54,1,2},
{1,294,2,47,58,3,0},
{1,155,185,47,56,3,-2},
{1,2,245,46,55,2,1},
{1,51,476,45,52,1,2},
{1,52,245,46,55,2,-3},
{1,153,419,46,53,2,-1},
{1,401,64,47,57,3,-1},
{1,203,419,47,53,3,-1},
{1,254,419,46,53,2,3},
{1,345,2,46,58,2,0},
{1,206,185,45,56,1,0},
{1,105,361,45,54,1,2},
{1,154,361,46,54,2,4},
{1,452,64,46,57,2,-5},
{1,255,185,44,56,0,-2},
{1,395,2,45,58,-1,-2},
{1,102,245,46,55,-2,-3},
{1,204,361,45,54,-1,0},
{1,253,361,48,54,0,0},
{1,2,125,47,57,1,-1},
{1,53,125,48,57,2,3},
{1,444,2,48,58,2,4},
{1,303,185,47,56,1,0},
}}
local NatureAuraStrongHigh={pixels=116,pages=auraPages,tiles={
{2,1021,2,1,1,1,-1},
{2,1011,7,1,1,1,-1},
{2,354,111,53,61,17,-15},
{3,140,2,62,75,20,-3},
{2,434,216,67,80,15,2},
{2,850,816,68,86,12,2},
{2,259,921,73,96,3,-6},
{2,679,906,75,98,1,-4},
{2,346,817,78,103,-2,-3},
{2,2,908,78,97,-4,-5},
{2,589,909,79,97,-1,1},
{2,84,924,85,93,1,3},
{2,88,819,84,101,2,-1},
{2,850,908,84,101,4,5},
{2,762,816,84,104,4,6},
{2,938,908,84,100,2,0},
{2,594,523,80,96,0,2},
{2,84,2,78,105,0,-1},
{2,263,319,78,99,0,-5},
{2,345,319,80,99,2,1},
{2,260,623,80,94,2,4},
{2,429,319,82,99,4,-5},
{2,678,622,82,95,4,-3},
{2,757,215,83,100,5,-2},
{2,344,623,84,94,6,-2},
{2,432,623,82,94,4,4},
{2,838,2,82,103,4,1},
{2,844,215,80,100,2,2},
{2,89,320,80,98,2,4},
{2,853,622,82,95,4,9},
{2,922,109,81,102,3,-8},
{2,588,110,78,101,0,-5},
{2,166,2,79,105,-1,-3},
{2,173,320,81,98,-3,-6},
{2,775,421,79,98,-1,0},
{2,858,421,85,98,1,0},
{2,2,111,84,101,2,-1},
{2,90,111,84,101,4,5},
{2,584,2,79,104,-1,6},
{2,928,215,81,100,-1,0},
{2,768,523,81,96,3,2},
{2,249,2,82,105,4,-1},
{2,515,319,83,99,3,-5},
{2,602,319,82,99,2,1},
{2,518,623,81,94,1,4},
{2,688,319,83,99,3,-5},
{2,939,622,83,95,3,-3},
{2,2,216,84,100,4,-2},
{2,764,623,85,94,5,-2},
{2,89,721,83,94,3,4},
{2,924,2,83,103,3,1},
{2,90,216,81,100,1,2},
{2,2,422,81,98,1,4},
{2,2,623,83,95,3,9},
{2,419,110,82,102,2,-8},
{2,670,110,80,101,0,-5},
{2,335,2,80,105,0,-3},
{2,87,422,82,98,-2,-6},
{2,173,422,80,98,0,0},
{2,257,422,85,98,1,0},
{2,178,111,84,101,2,-1},
{2,266,111,84,101,4,5},
{2,667,2,84,104,4,6},
{2,175,216,84,100,2,0},
}}
E.NatureAuraStrong={width=390,fps=24,intro=16,hold=48,ending=20,introLevels={0.00000,0.00000,0.00212,0.00954,0.02962,0.06670,0.12479,0.20575,0.30337,0.41520,0.53548,0.65661,0.76855,0.86391,0.93594,0.98244},banks={[192]=NatureAuraStrongLow,[288]=NatureAuraStrongLow,[384]=NatureAuraStrongHigh,[480]=NatureAuraStrongHigh,[576]=NatureAuraStrongHigh,[660]=NatureAuraStrongHigh}}
table.insert(E.RestorationAdditionalEffectBanks,E.NatureAuraStrong.banks)
end
