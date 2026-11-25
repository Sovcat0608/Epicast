local _, E = ...
local media = "Interface\\AddOns\\Epicast\\Media\\"
local active = setmetatable({}, { __mode = "k" })
local ramp = .5
local channelBurst = 1+ramp
local receivers = {"backboard", "roots"}
local place

local function ease(value)
    local t = math.max(0, math.min(1, value))
    return t*t*(3-2*t)
end

local function stagedChannelCel(clip, age)
    local hold, release = clip.stages.holdFirst, clip.stages.releaseFirst
    if age < ramp then return 1+math.floor(math.max(0,age)/ramp*(hold-1)) end
    return hold+math.floor((age-ramp)%clip.period/clip.period*(release-hold))
end

local function finishResponse(layer, now)
    local response = layer.response
    layer.response = nil
    local clips = layer.data and layer.data.clips
    if clips and clips.channel and (clips.channel.stages or clips.channel.restRamp) then
        layer.idleStarted = now
    elseif clips and response and response.kind=="impact" and clips.impact.restIdleCel then
        layer.idleStarted = now - (clips.impact.restIdleCel-1)*clips.idle.period/#clips.idle.frames
    end
end

-- Two upright crossings in the approved wave have a short painted strip
-- from that lit pose to the same unlit rest. Indices here are zero-based.
local function leafChannelCel(clip, age, releaseAge)
    local strip = clip.restRamp
    local start = clip.startFrames
    local hold = #clip.frames-2*strip-start
    local function rampCel(side,t)
        return 1+hold+side*strip+math.floor(t*(strip-1)+.5)
    end
    if age < ramp then
        local step = math.floor(math.max(0,age)/ramp*start)
        if releaseAge then step = math.floor(step*(1-math.min(1,releaseAge/ramp))+.5) end
        return 1+hold+2*strip+step
    end
    local cel = (start+math.floor(((age-ramp)%clip.period)/clip.period*hold))%hold
    if not releaseAge then return 1+cel end
    local crossing = math.floor(cel/(hold/2)+.5)*(hold/2)
    local travel = math.min(ramp*.52,math.abs(crossing-cel)*clip.period/hold)
    if releaseAge < travel then
        return 1+math.floor(cel+(crossing-cel)*releaseAge/travel+.5)%hold
    end
    return rampCel(crossing%hold==0 and 0 or 1, math.min(1,(releaseAge-travel)/(ramp-travel)))
end

local function endChannel(layer, now)
    local response = layer.response
    if not response or response.kind ~= "channel" or response.ending then return end
    response.level = ease((now-response.at)/ramp)
    local clip = layer.data.clips.channel
    if clip.stages then response.releaseFrom = stagedChannelCel(clip, now-response.at) end
    response.ending = now
end

local function resetPlayback(layer)
    layer.response, layer.sustained, layer.burstUntil, layer.burstPending = nil, nil, nil, nil
    layer.signalLevels, layer.burstSignals = {}, {}
    layer.idleStarted = nil
end

local function reconcile(layer, now)
    local response=layer.response
    if response and response.kind=="impact" and now-response.at>=layer.data.clips.impact.period then
        finishResponse(layer,now);response=nil
    end
    if response and (response.test or response.kind=="impact") then return end
    if layer.burstPending then
        layer.burstUntil=now+channelBurst
        layer.burstPending=nil
    end
    if layer.sustained or (layer.burstUntil and now<layer.burstUntil) then
        if not response or response.ending then layer.response={kind="channel",at=now} end
    elseif response then
        endChannel(layer,now)
    end
end

function E.SyncRestorationSignals(controller,isActive,isBurst,key,reset)
    local now=GetTime()
    for _,layer in pairs(controller.layers) do
        if reset then resetPlayback(layer)
        elseif layer.enabled and #layer.bindings>0 then
            local sustain,impact,burst=false,false,false
            for i,binding in ipairs(layer.bindings) do
                if binding.kind=="success" or binding.kind=="pulse" then
                    if isBurst and isBurst(binding) then
                        local prev=layer.burstSignals[i]
                        if not prev or (now-prev.time>.05 and (not key or key~=prev.key or binding.kind=="pulse")) then
                            layer.burstSignals[i]={time=now,key=key}
                            if binding.state=="impact" then impact=true else burst=true end
                        end
                    end
                else
                    local on=isActive(binding)
                    if binding.state=="channel" then sustain=sustain or on
                    elseif on and not layer.signalLevels[i] then impact=true end
                    layer.signalLevels[i]=on
                end
            end
            layer.sustained=sustain
            if not (layer.response and layer.response.test) then
                if impact then
                    layer.response={kind="impact",at=now}
                    layer.burstUntil,layer.burstPending=nil,nil
                end
                if burst then layer.burstPending=true end
                reconcile(layer,now)
            end
        end
    end
end

local function draw(texture, frame, size, flip, family, window)
    local page,u,v,right,bottom = unpack(frame)
    family = family or "Segments"
    local key = family .. ":" .. size .. ":" .. page
    if texture.pageKey ~= key then
        texture:SetTexture(media..string.format("Restoration%sCASSize%dPage%d.tga", family, size, page))
        texture.pageKey = key
    end
    if texture.coords ~= frame or texture.mirrored ~= flip or texture.window ~= window then
        if window then
            local w,h = right-u,bottom-v
            u,v,right,bottom = u+window[1]*w,v+window[2]*h,u+window[3]*w,v+window[4]*h
        end
        texture:SetTexCoord(E.UV({u,v,u,bottom,right,v,right,bottom}, flip))
        texture.coords, texture.mirrored, texture.window = frame, flip, window
    end
    texture:Show()
end

local function indexAt(clip, seconds)
    return math.min(#clip.frames, 1 + math.floor(seconds / clip.period * #clip.frames))
end

local function drawReceiver(controller, layer, frame)
    local bands = layer.contacts
    local left, right = controller.layers.leftSlats, controller.layers.rightSlats
    local leftStep = left.enabled and left.opacity > 0 and left.contactStep or #bands.left
    local rightStep = right.enabled and right.opacity > 0 and right.contactStep or #bands.right
    local face = controller.layers.treant
    local cast = bands.treant
    local faceFrame
    if cast and face.enabled and face.opacity>0 then
        if face.actionCel and face.frameOpacity>=.5 then
            faceFrame = cast.clips[face.actionState][face.actionCel]
        elseif face.releaseFromCel then
            faceFrame = cast.clips.channel[face.releaseFromCel]
        elseif face.idleCel~=1 then
            faceFrame = cast.clips.idle[face.idleCel]
        end
    end
    if layer.treantParts then
        local split = layer.treantParts
        if faceFrame then
            for i,window in ipairs(cast.remainder) do
                local part = split[i]
                if window[4]>window[2] and window[3]>window[1] then
                    place(part,layer,window,controller.flip)
                    draw(part,frame,controller.size,controller.flip,nil,window)
                else part:Hide() end
            end
            place(split[5],layer,cast.window,controller.flip)
            draw(split[5],faceFrame,controller.size,controller.flip,"TreantContacts")
        else
            for _,part in ipairs(split) do part:Hide() end
        end
    end
    if leftStep == 0 and rightStep == 0 and not faceFrame then
        if layer.partsShown then
            for _, part in ipairs(layer.parts) do part:Hide() end
            layer.partsShown = false
        end
        draw(layer.idle, frame, controller.size, controller.flip)
        return
    end

    layer.idle:Hide()
    layer.partsShown = true
    for i, part in ipairs(layer.parts) do
        local window = bands.windows[i]
        if window[4] > window[2] and (i~=2 or not faceFrame) then
            local replacement = i == 3 and bands.left[leftStep] or i == 4 and bands.right[rightStep]
            draw(part,replacement or frame,controller.size,controller.flip,replacement and "ShardContacts" or nil,
                not replacement and window or nil)
        else
            part:Hide()
        end
    end
end

local function updatePose(layer, now, elapsed, animate)
    reconcile(layer,now)
    local data, response = layer.data, layer.response
    local idle = data.clips.idle
    local opacity, activeClip, activeCel, slide = 0, nil, nil, 0
    local releaseFrom
    if response and animate then
        local age = now-response.at
        activeClip = data.clips[response.kind]
        if response.kind == "channel" then
            if response.test and age >= 2.5 then endChannel(layer, response.at+2.5) end
            if activeClip.restRamp then
                local releaseAge = response.ending and now-response.ending
                if releaseAge and releaseAge >= ramp then
                    finishResponse(layer,now)
                    response = nil
                else
                    activeCel = leafChannelCel(activeClip, response.ending and response.ending-response.at or age, releaseAge)
                    opacity = 1
                end
            elseif activeClip.stages then
                if response.ending then
                    local progress = (now-response.ending)/ramp
                    if progress >= 1 then
                        finishResponse(layer,now)
                        response = nil
                    else
                        local first = activeClip.stages.releaseFirst
                        local position = 1-(1-progress)*response.level
                        activeCel = first+math.floor(position*(#activeClip.frames-first)+.5)
                        releaseFrom = response.releaseFrom
                        opacity = ease(progress/.28)
                    end
                else
                    activeCel = stagedChannelCel(activeClip,age)
                    opacity = 1
                end
            else
                opacity = response.ending and response.level*(1-ease((now-response.ending)/ramp)) or ease(age/ramp)
                if response.ending and opacity <= 0 then finishResponse(layer,now) end
                activeCel = indexAt(activeClip, age % activeClip.period)
                slide = opacity * (layer.slide or 0)
            end
        else
            activeCel = indexAt(activeClip, age)
            opacity = activeClip.envelope and activeClip.envelope[activeCel] or 1
        end
    end
    layer.frameOpacity = opacity
    layer.actionState = response and response.kind
    layer.actionCel = activeCel
    local idleAge = animate and layer.idleStarted and now-layer.idleStarted or elapsed
    layer.idleCel = indexAt(idle,idleAge%idle.period)
    layer.idleFrame = releaseFrom and activeClip.frames[releaseFrom] or idle.frames[layer.idleCel]
    layer.releaseFromCel = releaseFrom
    layer.actionFrame = activeCel and activeClip.frames[activeCel]
    local hover, lift = data.hover, 0
    if animate and hover then
        lift = -math.sin(2*math.pi*(elapsed+hover[3])/hover[1])*hover[2]*layer.host:GetHeight()
    end
    if layer.offset ~= slide or layer.lift ~= lift then
        layer.offset,layer.lift = slide,lift
        layer.frame:SetPoint("TOPLEFT",layer.host,"TOPLEFT",layer.x+slide,layer.y+lift)
    end
end

place = function(texture, layer, window, flip)
    if texture.placedWindow==window and texture.placedFlip==flip
        and (not window or (texture.placedWidth==layer.width and texture.placedHeight==layer.height)) then return end
    texture:ClearAllPoints()
    if window then
        local l,t,r,b=unpack(window)
        local w,h=layer.width,layer.height
        texture.placedWidth,texture.placedHeight=w,h
        texture:SetPoint("TOPLEFT",layer.frame,"TOPLEFT",w*(flip and 1-r or l),-h*t)
        texture:SetSize(w*(r-l),h*(b-t))
    else
        texture:SetAllPoints(layer.frame)
    end
    texture.placedWindow,texture.placedFlip=window,flip
end

local function fabricPose(banner,fabric)
    if not banner.enabled or banner.opacity==0 then return fabric.offsets.hidden end
    if banner.actionCel then
        if banner.actionState=="channel" then
            local level = math.floor(banner.frameOpacity*banner.opacity*fabric.levels+.5)
            if level>0 then return fabric.offsets.channel+(level-1)*fabric.channelFrames+banner.actionCel end
        elseif banner.frameOpacity>0 then
            return fabric.offsets.impact+banner.actionCel
        end
    end
    return banner.idleCel
end

local function drawShardMaterial(controller,layer,state,alpha,step,pose)
    local contacts=layer.contacts
    local fabric = contacts.fabric
    local lit=state=="channel"
    local texture=lit and layer.action or layer.idle
    local patch=lit and layer.fabricAction or layer.fabricIdle
    local base=lit and layer.actionFrame or layer.idleFrame
    if base and alpha>0 then
        local remainder=fabric.remainder
        local hidden=pose==fabric.offsets.hidden
        if not hidden and remainder[3]>remainder[1] then
            local shadow=contacts[state][step]
            place(texture,layer,remainder,controller.flip)
            draw(texture,shadow or base,controller.size,controller.flip,shadow and "ShardContacts" or nil,remainder)
            texture:SetAlpha(alpha)
        else
            texture:Hide()
        end
        local window
        if not hidden then window=fabric.window end
        place(patch,layer,window,controller.flip)
        draw(patch,fabric[state][step*fabric.poseCount+pose],controller.size,controller.flip,"FabricContacts")
        patch:SetAlpha(alpha)
    else
        texture:Hide();patch:Hide()
    end
end

local function drawShard(controller,layer,step)
    local opacity=layer.frameOpacity
    local fabric=layer.contacts.fabric
    local pose=fabricPose(controller.layers[fabric.banner],fabric)
    drawShardMaterial(controller,layer,"idle",opacity<1 and 1 or 0,step,pose)
    drawShardMaterial(controller,layer,"channel",opacity,step,pose)
end

local function render(controller)
    if not controller.host:IsVisible() then return end
    local now = GetTime()
    local elapsed = controller.animate and (controller.elapsed + now-controller.started) or 0
    -- Resolve both banner poses before drawing either shard, independent of layer order.
    for _, layer in pairs(controller.layers) do
        if layer.enabled then updatePose(layer,now,elapsed,controller.animate) end
    end
    for _, layer in pairs(controller.layers) do
        if layer.enabled then
            local contacts = layer.contacts
            local opacity = layer.frameOpacity
            if contacts and contacts.windows then
                layer.receiverFrame = layer.idleFrame
            elseif contacts and contacts.fabric then
                layer.contactStep = math.floor(opacity*#contacts.idle+.5)
                drawShard(controller,layer,layer.contactStep)
            else
                if opacity<1 then draw(layer.idle,layer.idleFrame,controller.size,controller.flip) else layer.idle:Hide() end
                if layer.actionFrame and opacity>0 then
                    draw(layer.action,layer.actionFrame,controller.size,controller.flip)
                    layer.action:SetAlpha(opacity)
                else layer.action:Hide() end
            end
        end
    end
    for _, id in ipairs(receivers) do
        local layer = controller.layers[id]
        if layer.enabled and layer.contacts then drawReceiver(controller, layer, layer.receiverFrame) end
    end
end

local function texture(parent, level)
    local art = parent:CreateTexture(nil, "ARTWORK", nil, level)
    art:SetAllPoints(parent)
    -- Large cels cross atlas pages. Present the requested page and UVs together.
    if art.SetBlockingLoadsRequested then art:SetBlockingLoadsRequested(true) end
    if art.SetSnapToPixelGrid then art:SetSnapToPixelGrid(false) end
    if art.SetTexelSnappingBias then art:SetTexelSnappingBias(0) end
    if art.SetDesaturation then art:SetDesaturation(E.DruidArtworkDesaturation) end
    return art
end

function E.UseRestorationSegments(entry, config)
    if config.art ~= "druidRestoration" or not E.RestorationSegmentBanks then return false end
    local studio = E.GetAddedEffects(config).studio
    return entry.preview or (studio and studio.artworkBindings ~= nil)
end

function E.HideRestorationSegments(entry)
    local controller = entry.restorationSegments
    if not controller then return end
    active[controller] = nil
    E.SetArtworkSignalController(controller)
    controller.driver:Hide()
    if controller.started then
        controller.elapsed = (controller.elapsed + GetTime()-controller.started)%4
        controller.started = nil
    end
    for _, layer in pairs(controller.layers) do
        layer.frame:Hide()
        resetPlayback(layer)
    end
    entry.artworkSegmentsActive = false
end

function E.ApplyRestorationSegments(entry, config, artwork)
    if not E.UseRestorationSegments(entry, config) then
        E.HideRestorationSegments(entry)
        return false
    end
    local controller = entry.restorationSegments
    if not controller then
        controller = { host = artwork.host, driver = CreateFrame("Frame",nil,artwork.host), layers = {}, elapsed = 0 }
        entry.restorationSegments = controller
        controller.driver:SetScript("OnUpdate", function() render(controller) end)
    end
    local bank = E.RestorationSegmentBanks[artwork.textureSize]
    if not bank then return false end
    local contacts = E.RestorationShardContactBanks[artwork.textureSize]
    controller.preview, controller.animate = entry.preview, artwork.animate
    controller.size, controller.flip = artwork.textureSize, config.flip
    if controller.animate then controller.started = controller.started or GetTime()
    else
        if controller.started then
            controller.elapsed = (controller.elapsed + GetTime()-controller.started)%4
            controller.started = nil
        end
    end
    local width, height = artwork.host:GetWidth(), artwork.host:GetHeight()
    artwork.host:SetFrameLevel(entry.frame:GetFrameLevel()+1)
    artwork.host:SetAlpha(entry.alpha)
    local signals={}
    for _, info in ipairs(E.GetStudioLayers(config)) do
        if info.kind == "artwork" then
            local id = info.id
            local layer = controller.layers[id]
            if not layer then
                local frame = CreateFrame("Frame", nil, artwork.host)
                layer = { host = artwork.host, frame = frame, idle = texture(frame, 0), action = texture(frame, 1) }
                controller.layers[id] = layer
            end
            layer.data = bank[id]
            layer.contacts = contacts[id]
            layer.enabled = info.settings.enabled ~= false
            local signature,bindings = {},{}
            for _, link in ipairs(info.bindings) do
                for _,mapping in ipairs(link.mappings) do
                    local binding={spell=link.spell,state=mapping.state,kind=mapping.kind}
                    bindings[#bindings+1]=binding
                    signature[#signature+1]=mapping.state.."|"..mapping.kind.."|"..link.spell
                    if layer.enabled then signals[#signals+1]=binding end
                end
            end
            local key = table.concat(signature, "\n")
            if key ~= layer.signature or not layer.enabled or not controller.animate then resetPlayback(layer) end
            layer.signature, layer.bindings = key, bindings
            local x,y,w,h = unpack(layer.data.rect)
            layer.x, layer.y = width*(config.flip and 1-x-w or x), -height*y
            local offset = (id == "leftSlats" and -1 or id == "rightSlats" and 1 or 0)
            layer.slide = offset * (config.flip and -1 or 1) * E.RestorationShardTravel * width
            layer.offset = nil
            layer.frame:ClearAllPoints()
            layer.frame:SetPoint("TOPLEFT", artwork.host, "TOPLEFT", layer.x, layer.y)
            layer.width,layer.height=width*w,height*h
            layer.frame:SetSize(layer.width,layer.height)
            if layer.contacts and layer.contacts.fabric then
                if not layer.fabricIdle then
                    layer.fabricIdle,layer.fabricAction=texture(layer.frame,0),texture(layer.frame,1)
                end
            end
            layer.frame:SetFrameLevel(entry.frame:GetFrameLevel()+info.rank*2)
            local pending=entry.placementLayerID==id and entry.pendingPlacement
            layer.opacity = (pending and pending.trailOpacity or info.settings.opacity)/100
            layer.frame:SetAlpha(layer.opacity)
            if layer.contacts and layer.contacts.windows then
                layer.parts = layer.parts or {}
                for i, window in ipairs(layer.contacts.windows) do
                    local part = layer.parts[i] or texture(layer.frame, 0)
                    place(part,layer,window,config.flip)
                    if not layer.parts[i] then part:Hide() end
                    layer.parts[i] = part
                end
            end
            if layer.contacts and layer.contacts.treant and not layer.treantParts then
                layer.treantParts = {}
                for i=1,5 do
                    local part=texture(layer.frame,0)
                    part:Hide()
                    layer.treantParts[i]=part
                end
            end
            layer.frame:SetShown(layer.enabled)
            if not layer.motion then layer.motion = { segment = layer } end
            layer.motion.root, layer.motion.animate = artwork, artwork.animate
            entry.artworkLayers[id] = layer.motion
        end
    end
    artwork.texture:Hide()
    entry.artworkSegmentsActive = true
    active[controller] = true
    E.SetArtworkSignalController(controller,controller.animate and signals or nil)
    render(controller)
    controller.driver:SetShown(controller.animate)
    return true
end

function E.TestRestorationSegment(entry, id, binding)
    if InCombatLockdown() or not entry.preview or not binding then return false end
    local controller = entry.restorationSegments
    local layer = controller and controller.layers[id]
    if not layer or not controller.animate or not layer.enabled or not layer.data.clips[binding.kind]
        or binding.kind == "idle" then return false end
    E.StopBoundTests()
    layer.response={kind=binding.kind,at=GetTime(),test=true}
    render(controller)
    return true
end

function E.StopArtworkTests()
    for controller in pairs(active) do
        if controller.preview then
            for _, layer in pairs(controller.layers) do
                if layer.response and layer.response.test then finishResponse(layer,GetTime()) end
            end
        end
    end
end

