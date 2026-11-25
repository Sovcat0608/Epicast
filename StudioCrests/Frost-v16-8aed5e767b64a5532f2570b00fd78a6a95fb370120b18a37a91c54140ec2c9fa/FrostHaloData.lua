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
E.FrostHaloData = {["ratio"]=1.390749601275917,["origin"]=0.19537480063795853,["phases"]={["frostColdSnap"]=1.5,["frostShards"]=2.35,["frostShoulders"]=4.5,["frostBaseFloaters"]=5.35},["travel"]={["frostShards"]=0.0075},["period"]=40,["pivot"]={0.5,0.5470494417862839},["banks"]={["192"]={["uv"]=0.75,["halo"]="FrostHaloSize192Page1.tga",["page"]="FrostHaloSize192Page2.tga",["tiles"]={["artwork"]={{0.14606741573033707,0.005208333333333333,0.8539325842696629,1.0,0.001953125,0.0078125,0.1865234375,0.75390625,2}},["contact:artwork:0"]={{0.2209737827715356,0.18229166666666666,0.7790262172284644,0.9375,0.1904296875,0.0078125,0.3359375,0.57421875,2}},["frostShoulders"]={{0.018726591760299626,0.2916666666666667,0.1647940074906367,0.78125,0.33984375,0.0078125,0.3779296875,0.375,2},{0.8352059925093633,0.3020833333333333,0.9925093632958801,0.7916666666666666,0.3818359375,0.0078125,0.4228515625,0.375,2}},["coldSnapBack"]={{0.41198501872659177,0.057291666666666664,0.5917602996254682,0.3541666666666667,0.4267578125,0.0078125,0.4736328125,0.23046875,2}},["frostColdSnap"]={{0.41947565543071164,0.0625,0.5805243445692884,0.3385416666666667,0.4775390625,0.0078125,0.51953125,0.21484375,2}},["frostBaseFloaters"]={{0.6779026217228464,0.71875,0.846441947565543,0.9791666666666666,0.5234375,0.0078125,0.5673828125,0.203125,2},{0.149812734082397,0.71875,0.3146067415730337,0.9739583333333334,0.5712890625,0.0078125,0.6142578125,0.19921875,2}},["frostShards"]={{0.6591760299625468,0.0,0.8127340823970037,0.19270833333333334,0.6181640625,0.0078125,0.658203125,0.15234375,2},{0.1947565543071161,0.010416666666666666,0.3333333333333333,0.18229166666666666,0.662109375,0.0078125,0.6982421875,0.13671875,2}},["contact:frostColdSnap:-16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.7021484375,0.0078125,0.75,0.09375,2}},["contact:frostColdSnap:-8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.75390625,0.0078125,0.8017578125,0.09375,2}},["contact:frostColdSnap:0"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.8056640625,0.0078125,0.853515625,0.09375,2}},["contact:frostColdSnap:8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.857421875,0.0078125,0.9052734375,0.09375,2}},["contact:frostColdSnap:16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.9091796875,0.0078125,0.95703125,0.09375,2}}}},["288"]={["uv"]=0.5625,["halo"]="FrostHaloSize288Page1.tga",["page"]="FrostHaloSize288Page2.tga",["tiles"]={["artwork"]={{0.14713216957605985,0.006944444444444444,0.8503740648379052,0.9965277777777778,0.001953125,0.00390625,0.27734375,0.560546875,2}},["contact:artwork:0"]={{0.2209737827715356,0.18229166666666666,0.7790262172284644,0.9375,0.28125,0.00390625,0.4267578125,0.287109375,2}},["frostShoulders"]={{0.0199501246882793,0.2951388888888889,0.16209476309226933,0.7777777777777778,0.4306640625,0.00390625,0.486328125,0.275390625,2},{0.8379052369077307,0.3055555555555556,0.9900249376558603,0.7881944444444444,0.490234375,0.00390625,0.5498046875,0.275390625,2}},["frostColdSnap"]={{0.41895261845386533,0.0625,0.5810473815461347,0.3368055555555556,0.5537109375,0.00390625,0.6171875,0.158203125,2}},["frostBaseFloaters"]={{0.1546134663341646,0.7152777777777778,0.3117206982543641,0.9722222222222222,0.62109375,0.00390625,0.6826171875,0.1484375,2},{0.6807980049875312,0.7222222222222222,0.8453865336658354,0.9756944444444444,0.6865234375,0.00390625,0.7509765625,0.146484375,2}},["coldSnapBack"]={{0.41198501872659177,0.057291666666666664,0.5917602996254682,0.3541666666666667,0.7548828125,0.00390625,0.8017578125,0.115234375,2}},["frostShards"]={{0.6608478802992519,0.003472222222222222,0.8104738154613467,0.1875,0.8056640625,0.00390625,0.8642578125,0.107421875,2},{0.1970074812967581,0.010416666666666666,0.3341645885286783,0.1840277777777778,0.8681640625,0.00390625,0.921875,0.1015625,2}},["contact:frostColdSnap:-16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.92578125,0.00390625,0.9736328125,0.046875,2}},["contact:frostColdSnap:-8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.92578125,0.0546875,0.9736328125,0.09765625,2}},["contact:frostColdSnap:0"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.92578125,0.10546875,0.9736328125,0.1484375,2}},["contact:frostColdSnap:8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.8681640625,0.109375,0.916015625,0.15234375,2}},["contact:frostColdSnap:16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.8056640625,0.115234375,0.853515625,0.158203125,2}}}},["384"]={["uv"]=0.75,["halo"]="FrostHaloSize384Page1.tga",["page"]="FrostHaloSize384Page2.tga",["tiles"]={["artwork"]={{0.14794007490636704,0.0078125,0.850187265917603,0.9973958333333334,0.001953125,0.00390625,0.3681640625,0.74609375,2}},["frostShoulders"]={{0.8408239700374532,0.3072916666666667,0.9887640449438202,0.7890625,0.3720703125,0.00390625,0.44921875,0.365234375,2},{0.020599250936329586,0.296875,0.16104868913857678,0.7760416666666666,0.453125,0.00390625,0.5263671875,0.36328125,2}},["contact:artwork:0"]={{0.2209737827715356,0.18229166666666666,0.7790262172284644,0.9375,0.5302734375,0.00390625,0.67578125,0.287109375,2}},["frostColdSnap"]={{0.42134831460674155,0.06510416666666667,0.5786516853932584,0.3359375,0.6796875,0.00390625,0.76171875,0.20703125,2}},["frostBaseFloaters"]={{0.15543071161048688,0.7161458333333334,0.3089887640449438,0.96875,0.765625,0.00390625,0.845703125,0.193359375,2},{0.6816479400749064,0.7213541666666666,0.8445692883895131,0.9739583333333334,0.849609375,0.00390625,0.9345703125,0.193359375,2}},["frostShards"]={{0.6610486891385767,0.005208333333333333,0.8108614232209738,0.1875,0.765625,0.201171875,0.84375,0.337890625,2},{0.1947565543071161,0.013020833333333334,0.3333333333333333,0.18229166666666666,0.84765625,0.201171875,0.919921875,0.328125,2}},["coldSnapBack"]={{0.41198501872659177,0.057291666666666664,0.5917602996254682,0.3541666666666667,0.9384765625,0.00390625,0.9853515625,0.115234375,2}},["contact:frostColdSnap:-16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.9384765625,0.123046875,0.986328125,0.166015625,2}},["contact:frostColdSnap:-8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.9384765625,0.173828125,0.986328125,0.216796875,2}},["contact:frostColdSnap:0"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.6796875,0.21484375,0.7275390625,0.2578125,2}},["contact:frostColdSnap:8"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.923828125,0.224609375,0.9716796875,0.267578125,2}},["contact:frostColdSnap:16"]={{0.40823970037453183,0.15625,0.5917602996254682,0.2708333333333333,0.6796875,0.265625,0.7275390625,0.30859375,2}}}},["480"]={["uv"]=0.9375,["halo"]="FrostHaloSize480Page1.tga",["page"]="FrostHaloSize480Page2.tga",["tiles"]={["artwork"]={{0.14820359281437126,0.008333333333333333,0.8502994011976048,0.9958333333333333,0.001953125,0.00390625,0.4599609375,0.9296875,2}},["frostShoulders"]={{0.02245508982035928,0.29791666666666666,0.16167664670658682,0.7770833333333333,0.4638671875,0.00390625,0.5546875,0.453125,2},{0.8413173652694611,0.30833333333333335,0.9880239520958084,0.7875,0.55859375,0.00390625,0.654296875,0.453125,2}},["contact:artwork:0"]={{0.218562874251497,0.18333333333333332,0.781437125748503,0.9375,0.658203125,0.00390625,0.841796875,0.357421875,2}},["frostColdSnap"]={{0.4221556886227545,0.06458333333333334,0.5778443113772455,0.33541666666666664,0.845703125,0.00390625,0.947265625,0.2578125,2}},["frostBaseFloaters"]={{0.15568862275449102,0.7166666666666667,0.30988023952095806,0.96875,0.845703125,0.265625,0.9462890625,0.501953125,2},{0.6826347305389222,0.7229166666666667,0.844311377245509,0.9729166666666667,0.658203125,0.365234375,0.763671875,0.599609375,2}},["frostShards"]={{0.6616766467065869,0.00625,0.8098802395209581,0.1875,0.4638671875,0.4609375,0.560546875,0.630859375,2},{0.19610778443113772,0.014583333333333334,0.3338323353293413,0.18125,0.564453125,0.4609375,0.654296875,0.6171875,2}},["coldSnapBack"]={{0.41317365269461076,0.058333333333333334,0.5898203592814372,0.3541666666666667,0.767578125,0.365234375,0.8251953125,0.50390625,2}},["contact:frostColdSnap:-8"]={{0.40718562874251496,0.15833333333333333,0.592814371257485,0.2708333333333333,0.8291015625,0.509765625,0.8896484375,0.5625,2}},["contact:frostColdSnap:0"]={{0.40718562874251496,0.15833333333333333,0.592814371257485,0.2708333333333333,0.8935546875,0.509765625,0.9541015625,0.5625,2}},["contact:frostColdSnap:8"]={{0.40718562874251496,0.15833333333333333,0.592814371257485,0.2708333333333333,0.767578125,0.5703125,0.828125,0.623046875,2}},["contact:frostColdSnap:16"]={{0.40718562874251496,0.15833333333333333,0.592814371257485,0.2708333333333333,0.83203125,0.5703125,0.892578125,0.623046875,2}},["contact:frostColdSnap:-16"]={{0.40718562874251496,0.15833333333333333,0.592814371257485,0.26666666666666666,0.896484375,0.5703125,0.95703125,0.62109375,2}}}},["576"]={["uv"]=0.5625,["halo"]="FrostHaloSize576Page1.tga",["page"]="FrostHaloSize576Page2.tga",["tiles"]={["artwork"]={{0.14856429463171036,0.010416666666666666,0.850187265917603,0.9947916666666666,0.001953125,0.001953125,0.55078125,0.5556640625,2}},["frostShoulders"]={{0.02247191011235955,0.2986111111111111,0.16104868913857678,0.7760416666666666,0.5546875,0.001953125,0.6630859375,0.2705078125,2},{0.8414481897627965,0.3090277777777778,0.9887640449438202,0.7864583333333334,0.6669921875,0.001953125,0.7822265625,0.2705078125,2}},["contact:artwork:0"]={{0.21910112359550563,0.18359375,0.7808988764044944,0.9375,0.7861328125,0.001953125,0.9814453125,0.1904296875,2}},["frostColdSnap"]={{0.42197253433208487,0.06597222222222222,0.5780274656679151,0.3350694444444444,0.7861328125,0.1943359375,0.908203125,0.345703125,2}},["frostBaseFloaters"]={{0.15355805243445692,0.7170138888888888,0.3083645443196005,0.96875,0.5546875,0.2744140625,0.67578125,0.416015625,2},{0.6816479400749064,0.7204861111111112,0.8439450686641697,0.9722222222222222,0.6796875,0.349609375,0.806640625,0.4912109375,2}},["frostShards"]={{0.66167290886392,0.005208333333333333,0.8089887640449438,0.1857638888888889,0.810546875,0.349609375,0.92578125,0.451171875,2},{0.19600499375780275,0.013888888888888888,0.3333333333333333,0.18055555555555555,0.5546875,0.419921875,0.662109375,0.513671875,2}},["coldSnapBack"]={{0.41292134831460675,0.0546875,0.5898876404494382,0.3515625,0.912109375,0.1943359375,0.9736328125,0.2685546875,2}},["contact:frostColdSnap:-16"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.912109375,0.2724609375,0.9765625,0.30078125,2}},["contact:frostColdSnap:-8"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.6796875,0.2744140625,0.744140625,0.302734375,2}},["contact:frostColdSnap:0"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.912109375,0.3046875,0.9765625,0.3330078125,2}},["contact:frostColdSnap:8"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.6796875,0.306640625,0.744140625,0.3349609375,2}},["contact:frostColdSnap:16"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.9296875,0.3369140625,0.994140625,0.365234375,2}}}},["768"]={["uv"]=0.75,["halo"]="FrostHaloSize768Page1.tga",["page"]="FrostHaloSize768Page2.tga",["tiles"]={["artwork"]={{0.14887640449438203,0.010416666666666666,0.850187265917603,0.9947916666666666,0.001953125,0.001953125,0.7333984375,0.740234375,2}},["frostShoulders"]={{0.02247191011235955,0.2981770833333333,0.1601123595505618,0.7747395833333334,0.7373046875,0.001953125,0.880859375,0.359375,2},{0.8417602996254682,0.3098958333333333,0.9878277153558053,0.7864583333333334,0.7373046875,0.36328125,0.8896484375,0.720703125,2}},["frostColdSnap"]={{0.42228464419475653,0.06640625,0.5777153558052435,0.3333333333333333,0.7373046875,0.724609375,0.8994140625,0.9248046875,2}},["frostBaseFloaters"]={{0.6825842696629213,0.7213541666666666,0.8445692883895131,0.9739583333333334,0.001953125,0.744140625,0.1708984375,0.93359375,2},{0.1544943820224719,0.7174479166666666,0.3089887640449438,0.9674479166666666,0.1748046875,0.744140625,0.3359375,0.931640625,2}},["frostShards"]={{0.6619850187265918,0.005208333333333333,0.8089887640449438,0.18619791666666666,0.33984375,0.744140625,0.4931640625,0.8798828125,2},{0.1956928838951311,0.013020833333333334,0.3333333333333333,0.18098958333333334,0.4970703125,0.744140625,0.640625,0.8701171875,2}},["contact:artwork:0"]={{0.21910112359550563,0.18359375,0.7808988764044944,0.9375,0.75390625,0.001953125,0.94921875,0.1904296875,1}},["coldSnapBack"]={{0.41292134831460675,0.0546875,0.5898876404494382,0.3515625,0.75390625,0.1943359375,0.8154296875,0.2685546875,1}},["contact:frostColdSnap:-16"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.8193359375,0.1943359375,0.8837890625,0.22265625,1}},["contact:frostColdSnap:-8"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.8876953125,0.1943359375,0.9521484375,0.22265625,1}},["contact:frostColdSnap:0"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.8193359375,0.2265625,0.8837890625,0.2548828125,1}},["contact:frostColdSnap:8"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.8876953125,0.2265625,0.9521484375,0.2548828125,1}},["contact:frostColdSnap:16"]={{0.40730337078651685,0.15625,0.5926966292134831,0.26953125,0.8193359375,0.2587890625,0.8837890625,0.287109375,1}}}}},["contactPoses"]={-16,-8,0,8,16},["contactCasters"]={"artwork","frostColdSnap"}}
