do
local function loadRestorationRenderer(...)
local _, E = ...
local media = "Interface\\AddOns\\Epicast\\Media" .. "\\"
local active = setmetatable({}, { __mode = "k" })
local ramp = .5
local channelBurst = 1+ramp
local receivers = {"backboard", "roots"}
local place

-- Measured against the registered Idle atlas. Channel cels nearest to the
-- unlit silhouette and the last Impact pose can have different Idle phases.
local foliageSeams = {
    leftAutumn    = {channel = 13, channelIdle = 6, impactIdle = 7},
    rightCrown    = {channel = 1, channelIdle = 11, impactIdle = 11},
    leftShoulder  = {channel = 1, channelIdle = 12, impactIdle = 12},
    rightShoulder = {channel = 1, channelIdle = 1, impactIdle = 1},
    leftInner     = {channel = 1, channelIdle = 1, impactIdle = 1},
    rightInner    = {channel = 1, channelIdle = 5, impactIdle = 5},
}
local foliageSettle = 1/12

local function startResponse(layer, kind, now, test)
    local response = {kind=kind, at=now, test=test}
    if kind == "impact" then response.entryClip, response.entryCel = layer.foliageClip, layer.foliageCel end
    layer.response = response
end

local function indexAt(clip, seconds)
    return math.min(#clip.frames, 1 + math.floor(seconds / clip.period * #clip.frames))
end

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
    if layer.foliage and response then
        layer.idleStarted = now
        layer.idleStartCel = response.kind=="impact" and layer.foliage.impactIdle or layer.foliage.channelIdle
    elseif clips and clips.channel and (clips.channel.stages or clips.channel.restRamp) then
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
    if layer.foliage then
        response.entryClip, response.entryCel = layer.foliageClip, layer.foliageCel
        response.releaseFrom = layer.foliageClip=="channel" and layer.foliageCel
            or indexAt(clip,(now-response.at)%clip.period)
    elseif clip.stages then
        response.releaseFrom = stagedChannelCel(clip, now-response.at)
    end
    response.ending = now
end

local function resetPlayback(layer)
    layer.response, layer.sustained, layer.burstUntil, layer.burstPending = nil, nil, nil, nil
    layer.signalLevels, layer.burstSignals = {}, {}
    layer.idleStarted, layer.idleStartCel = nil, nil
    layer.foliageClip, layer.foliageCel = nil, nil
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
        if not response or response.ending then startResponse(layer,"channel",now) end
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
                    startResponse(layer,"impact",now)
                    layer.burstUntil,layer.burstPending=nil,nil
                end
                if burst then layer.burstPending=true end
                reconcile(layer,now)
            end
        end
    end
end

-- Keep each base texture's requested visibility while its Channel+ replacement
-- owns presentation. Base pose and contact-shadow computation continue normally.
local function showPaint(art, shown)
    art.restorationWanted = shown
    local visible = shown and not art.restorationSuppressed
    if art.restorationVisible == visible then return end
    art.restorationVisible = visible
    if visible then art:Show() else art:Hide() end
end

function E.SuppressRestorationPaint(art, suppressed)
    art.restorationSuppressed = suppressed
    local shown = art.restorationWanted
    if shown == nil then shown = art:IsShown() end
    showPaint(art, shown)
end

local function paintAlpha(art, alpha)
    if art.restorationAlpha == alpha then return end
    art.restorationAlpha = alpha
    art:SetAlpha(alpha)
end


local function draw(texture, frame, size, flip, family, window)
    local page = frame[1]
    if texture.pageFamily ~= family or texture.pageSize ~= size or texture.pageIndex ~= page then
        texture:SetTexture(media..string.format("Restoration%sCASSize%dPage%d.tga", family or "Segments", size, page))
        texture.pageFamily, texture.pageSize, texture.pageIndex = family, size, page
    end
    if texture.coords ~= frame or texture.mirrored ~= flip or texture.window ~= window then
        local u,v,right,bottom = frame[2],frame[3],frame[4],frame[5]
        if window then
            local w,h = right-u,bottom-v
            u,v,right,bottom = u+window[1]*w,v+window[2]*h,u+window[3]*w,v+window[4]*h
        end
        texture:SetTexCoord(E.UV({u,v,u,bottom,right,v,right,bottom}, flip))
        texture.coords, texture.mirrored, texture.window = frame, flip, window
    end
    showPaint(texture, true)
end

local function foliageReleasePose(clip, seam, response, age)
    if age >= ramp-foliageSettle then return "idle",seam.channelIdle end
    -- Begin at the last visible pose, including a cast stopped before its first update.
    if response.entryClip and age < clip.period/#clip.frames then return response.entryClip,response.entryCel end
    local n, from = #clip.frames, response.releaseFrom
    local delta = (seam.channel-from + math.floor(n/2))%n - math.floor(n/2)
    local progress = ease(age/(ramp-foliageSettle))
    local step = math.floor(math.abs(delta)*progress+.5)
    return "channel",1 + (from-1 + (delta<0 and -step or step))%n
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
                else showPaint(part, false) end
            end
            place(split[5],layer,cast.window,controller.flip)
            draw(split[5],faceFrame,controller.size,controller.flip,"TreantContacts")
        else
            for _,part in ipairs(split) do showPaint(part, false) end
        end
    end
    if leftStep == 0 and rightStep == 0 and not faceFrame then
        if layer.partsShown then
            for _, part in ipairs(layer.parts) do showPaint(part, false) end
            layer.partsShown = false
        end
        draw(layer.idle, frame, controller.size, controller.flip)
        return
    end

    showPaint(layer.idle, false)
    layer.partsShown = true
    for i, part in ipairs(layer.parts) do
        local window = bands.windows[i]
        if window[4] > window[2] and (i~=2 or not faceFrame) then
            local replacement = i == 3 and bands.left[leftStep] or i == 4 and bands.right[rightStep]
            draw(part,replacement or frame,controller.size,controller.flip,replacement and "ShardContacts" or nil,
                not replacement and window or nil)
        else
            showPaint(part, false)
        end
    end
end

local function updatePose(layer, now, elapsed, animate)
    reconcile(layer,now)
    local data, response = layer.data, layer.response
    local idle = data.clips.idle
    local opacity, activeClip, activeCel, slide = 0, nil, nil, 0
    local releaseFrom, foliageClip, foliageCel
    if response and animate then
        local age = now-response.at
        activeClip = data.clips[response.kind]
        if response.kind == "channel" then
            if response.test and age >= 2.5 then endChannel(layer, response.at+2.5) end
            if layer.foliage then
                local releaseAge = response.ending and now-response.ending
                if releaseAge and releaseAge >= ramp then
                    finishResponse(layer,now)
                    response = nil
                else
                    if releaseAge then
                        foliageClip, foliageCel = foliageReleasePose(activeClip,layer.foliage,response,releaseAge)
                    else
                        foliageClip, foliageCel = "channel", indexAt(activeClip,age%activeClip.period)
                    end
                    activeCel, opacity = foliageCel, 1
                end
            elseif activeClip.restRamp then
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
            if layer.foliage then
                if activeCel == #activeClip.frames then
                    foliageClip, foliageCel = "idle", layer.foliage.impactIdle
                elseif activeCel == 1 and response.entryClip then
                    foliageClip, foliageCel = response.entryClip, response.entryCel
                else
                    foliageClip, foliageCel = "impact", activeCel
                end
                opacity = 1
            else
                opacity = activeClip.envelope and activeClip.envelope[activeCel] or 1
            end
        end
    end
    layer.frameOpacity = opacity
    layer.actionState = response and response.kind
    layer.actionCel = activeCel
    local idleAge = animate and layer.idleStarted and now-layer.idleStarted or elapsed
    layer.idleCel = indexAt(idle,idleAge%idle.period)
    if layer.idleStartCel then
        layer.idleCel = 1+(layer.idleCel+layer.idleStartCel-2)%#idle.frames
    end
    layer.idleFrame = releaseFrom and activeClip.frames[releaseFrom] or idle.frames[layer.idleCel]
    layer.releaseFromCel = releaseFrom
    if layer.foliage then
        layer.foliageClip, layer.foliageCel = foliageClip or "idle", foliageCel or layer.idleCel
    end
    layer.actionFrame = foliageClip and data.clips[foliageClip].frames[foliageCel]
        or (activeCel and activeClip.frames[activeCel])
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
            paintAlpha(texture, alpha)
        else
            showPaint(texture, false)
        end
        local window
        if not hidden then window=fabric.window end
        place(patch,layer,window,controller.flip)
        draw(patch,fabric[state][step*fabric.poseCount+pose],controller.size,controller.flip,"FabricContacts")
        paintAlpha(patch, alpha)
    else
        showPaint(texture, false);showPaint(patch, false)
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
                if opacity<1 then draw(layer.idle,layer.idleFrame,controller.size,controller.flip) else showPaint(layer.idle, false) end
                if layer.actionFrame and opacity>0 then
                    draw(layer.action,layer.actionFrame,controller.size,controller.flip)
                    paintAlpha(layer.action, opacity)
                else showPaint(layer.action, false) end
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
            layer.foliage = foliageSeams[id]
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
    startResponse(layer,binding.kind,GetTime(),true)
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


end
loadRestorationRenderer(...)
end

local _, E = ...
local media = "Interface\\AddOns\\Epicast\\StudioCrests\\DruidRestoration-v16-b434bd12da5ae179e3d0102f10f31e9530a9d126048dc02adaac3444b78a85c0\\"
local id, crest = "rejuvenationPrecast", "DRUID:restoration"
local defaults = {enabled=true, size=100, opacity=100, x=0, y=0, angle=0,
                  rotate=false, period=3, reverse=false, depth=0, playStart=true, hold=true, playEnd=true}
local baked = E.CustomEffectPlayback and E.CustomEffectPlayback[crest] and E.CustomEffectPlayback[crest][id]
for _,key in ipairs({"playStart","hold","playEnd"}) do
    if baked and type(baked[key])=="boolean" then defaults[key]=baked[key] end
end
E.DesktopCustomEffects = E.DesktopCustomEffects or {}
local descriptors = E.DesktopCustomEffects[crest] or {}
E.DesktopCustomEffects[crest] = descriptors
table.insert(descriptors, {id=id, name="EC-RejuvPrecast", libraryOnly=true, defaults=defaults})

local lengths = E.RejuvenationPrecastLengths
local fps, bridge = 48, 10/48
local function smooth(x)
    x = math.max(0,math.min(1,x))
    return x*x*(3-2*x)
end

-- Every stage uses the same moving cel. The four bands change opacity in
-- order along the paths, so release can start on any hold phase.
local banks = E.RejuvenationPrecastFlowBanks
local rise = {{0,.42},{.16,.59},{.34,.77},{.57,1}}
local fall = {{.04,.43},{.23,.66},{.39,.82},{.59,1}}
local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}

local function createVoices(frame)
    frame.voices={}
    for i=1,#rise do
        local tex=frame:CreateTexture(nil,"ARTWORK",nil,i-1)
        tex:SetBlendMode("ADD")
        if tex.SetBlockingLoadsRequested then tex:SetBlockingLoadsRequested(true) end
        if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false);tex:SetTexelSnappingBias(0) end
        tex:Hide()
        frame.voices[i]={texture=tex,weight=0}
    end
end

local function finish(frame)
    frame.phase=nil
    for _,v in ipairs(frame.voices) do v.weight=0;v.texture:Hide() end
    frame:Hide()
end

local function begin(frame,phase,_,age)
    if not phase then finish(frame);return end
    local active=frame.phase~=nil
    if not active then
        frame.cycle=phase=="intro" and -lengths.intro/fps or 0
    end
    for _,v in ipairs(frame.voices) do
        v.from=active and v.weight or (phase=="intro" and 0 or 1)
    end
    frame.phase,frame.stageAge,frame.last=phase,age or 0,GetTime()
    frame:Show()
end

local function fadeBands(frame)
    local phase=frame.phase
    local interval=phase=="intro" and rise or phase=="ending" and fall
    local progress=frame.stageAge*fps/lengths[phase]
    for i,v in ipairs(frame.voices) do
        local window=interval and interval[i]
        local ramp=window and smooth((progress-window[1])/(window[2]-window[1])) or smooth(frame.stageAge/bridge)
        v.weight=phase=="ending" and v.from*(1-ramp) or v.from+(1-v.from)*ramp
    end
end

local function paint(frame,v,atlas,tile,angle)
    local tex=v.texture
    if v.weight<=0 then tex:Hide();return end
    local page=atlas.pages[tile[1]]
    if v.page~=page then
        tex:SetTexture(media..page[1])
        v.page=page
    end
    if v.tile~=tile or v.flip~=frame.flip then
        local l,t=tile[2]/page[2],tile[3]/page[3]
        local r,b=(tile[2]+tile[4])/page[2],(tile[3]+tile[5])/page[3]
        if frame.flip then l,r=r,l end
        tex:SetTexCoord(l,t,l,b,r,t,r,b)
    end
    if v.tile~=tile or v.flip~=frame.flip or v.size~=frame.size or v.angle~=angle then
        local unit=frame.size/atlas.pixels
        local c,s=math.cos(angle),math.sin(angle)
        local dx,dy=tile[6]*unit/2*(frame.flip and -1 or 1),tile[7]*unit/2
        tex:ClearAllPoints()
        tex:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
        tex:SetSize(unit*tile[4],unit*tile[5])
        if tex.SetVertexOffset then
            for i,corner in ipairs(corners) do
                local x,y=corner[1]*tex:GetWidth()/2,corner[2]*tex:GetHeight()/2
                tex:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
            end
        end
    end
    v.tile,v.flip,v.size,v.angle=tile,frame.flip,frame.size,angle
    tex:SetAlpha(v.weight)
    tex:Show()
end

local function draw(frame)
    if not frame.phase then return end
    local now=GetTime()
    local dt=math.max(0,now-frame.last)
    frame.last=now
    frame.stageAge=frame.stageAge+dt
    if frame.animate or frame.phase~="hold" then frame.cycle=frame.cycle+dt end
    fadeBands(frame)
    local phase=frame.phase
    local overflow=frame.stageAge-lengths[phase]/fps
    if phase~="hold" and overflow>=-1e-7 then
        if phase=="intro" then
            local nextStage=frame.hold and "hold" or (frame.playEnd and "ending" or nil)
            if nextStage=="ending" and overflow>=lengths.ending/fps then nextStage=nil end
            begin(frame,nextStage,false,math.max(0,overflow))
            if not frame.phase then return end
            fadeBands(frame)
        else finish(frame);return end
    end
    frame.cel=math.floor(frame.cycle*fps+1e-7)%lengths.hold
    local atlas=banks[frame.bank]
    local spin=frame.rotation
    local seconds=spin.elapsed+(spin.startedAt and now-spin.startedAt or 0)
    local angle=-math.rad(spin.angle)-seconds*2*math.pi*spin.direction/spin.period
    for i,v in ipairs(frame.voices) do
        paint(frame,v,atlas,atlas.bands[i][frame.cel+1],angle)
    end
end

local function release(frame)
    if not frame.playEnd then finish(frame);return end
    if frame.phase and frame.phase~="ending" then begin(frame,"ending") end
end

local originalHide = E.HideRestorationSegments
function E.HideRestorationSegments(entry)
    local frame=entry.rejuvenationPrecast
    if frame then finish(frame); frame.enabled=nil end
    return originalHide(entry)
end

local originalApply = E.ApplyRestorationSegments
function E.ApplyRestorationSegments(entry,config,artwork)
    local active=originalApply(entry,config,artwork)
    E.RenderCustomEffectInstances(entry,crest,"rejuvenationPrecast",function(entry)
        local frame=entry.rejuvenationPrecast
        local controller=entry.restorationSegments
        local settings=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
        if not active or not controller or not settings or settings.opacity<=0 then
            if frame then finish(frame); frame.enabled=nil end
            return frame
        end
        if not frame and not settings.enabled then return frame end
        if not frame then
            frame=CreateFrame("Frame",nil,artwork.host)
            entry.rejuvenationPrecast=frame
            createVoices(frame)
            frame:SetScript("OnUpdate",draw)
            if entry.preparingEffect then frame:Hide(); return frame end
        end
        draw(frame)
        frame.bank,frame.flip,frame.animate=artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
        local width,height=artwork.host:GetWidth(),artwork.host:GetHeight()
        local targetX=(242+settings.x)/480
        if config.flip then targetX=1-targetX end
        local targetY=(267-settings.y)/640
        frame.size=width*(336/480)*settings.size/100
        frame:SetSize(frame.size,frame.size)
        E.AnchorCustomEffect(entry,frame,width,height,width*targetX,-height*targetY)
        local rank=artwork.host:GetFrameLevel()
        for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
        frame:SetFrameLevel(math.max(0,rank+1+2*settings.depth))
        frame:SetAlpha(settings.opacity/100)
        if not frame.rotation then frame.rotation={elapsed=0,pivot={.5,.5}} end
        local spin=frame.rotation
        if settings.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
        elseif spin.startedAt then spin.elapsed=spin.elapsed+GetTime()-spin.startedAt; spin.startedAt=nil end
        spin.angle,spin.direction,spin.period=settings.angle,settings.reverse and -1 or 1,settings.period
        for _,v in pairs(frame.voices) do v.texture.epicastDesktopRotation=spin end

        local start,hold,ending=settings.playStart~=false,settings.hold~=false,settings.playEnd~=false
        local changed=frame.playStart~=start or frame.hold~=hold or frame.playEnd~=ending
        frame.playStart,frame.hold,frame.playEnd=start,hold,ending
        if frame.enabled~=settings.enabled or (changed and not frame.phase and settings.enabled) then
            frame.enabled=settings.enabled
            if frame.enabled then
                local nextStage=start and "intro" or (hold and "hold" or (ending and "ending" or nil))
                begin(frame,nextStage,frame.phase~=nil)
            else release(frame) end
        elseif changed then
            if frame.phase=="intro" and not start then begin(frame,hold and "hold" or (ending and "ending" or nil),true)
            elseif frame.phase=="hold" and not hold then release(frame)
            elseif frame.phase=="ending" and not ending then finish(frame) end
        end
        draw(frame)
        return entry.rejuvenationPrecast
    end)
    return active
end


local function paintStudioCel(frame,voice,atlas,cel)
    local tile=atlas.tiles[cel+1]
    local page=atlas.pages[tile[1]]
    if voice.pageInfo~=page then
        voice.texture:SetTexture(media..page[1])
        voice.pageInfo=page
    end
    if voice.tile~=tile or voice.flip~=frame.flip then
        local left,top=tile[2]/page[2],tile[3]/page[3]
        local right,bottom=(tile[2]+tile[4])/page[2],(tile[3]+tile[5])/page[3]
        if frame.flip then left,right=right,left end
        voice.texture:SetTexCoord(left,top,left,bottom,right,top,right,bottom)
    end
    if voice.tile~=tile or voice.size~=frame.size then
        voice.texture:SetSize(frame.size*tile[4]/atlas.pixels,frame.size*tile[5]/atlas.pixels)
    end
    voice.tile,voice.flip,voice.size=tile,frame.flip,frame.size
end

local function registerImpact(effectID, name, banks, introEnd, holdEnd, anchorV)
    local settingsDefault = {enabled=true, size=100, opacity=100, x=0, y=0, angle=0,
        rotate=false, period=3, reverse=false, depth=0, playStart=true, hold=true, playEnd=true}
    table.insert(descriptors,{id=effectID,name=name,libraryOnly=true,defaults=settingsDefault})
    local stages = {{"playStart",0,introEnd},{"hold",introEnd,holdEnd},{"playEnd",holdEnd,144}}
    local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}

    local function stopImpact(frame)
        frame.started=nil
        frame:Hide()
    end

    local function drawImpact(frame)
        if not frame.started then return end
        local clock=GetTime()-frame.started
        local index=math.floor(clock*48+1e-7)
        for _,stage in ipairs(stages) do
            if frame[stage[1]] then
                local count=stage[3]-stage[2]
                if index<count then
                    local cel=stage[2]+index
                    local v=frame.voice
                    local atlas=banks[frame.bank]
                    paintStudioCel(frame,v,atlas,cel)
                    local rotation=frame.rotation
                    -- Move the trim rectangle around the full canvas pivot before
                    -- rotating the rectangle itself. Mirror the crop offset with its UVs.
                    local angle=-math.rad(rotation.angle)
                    if rotation.startedAt then angle=angle-clock*2*math.pi*rotation.direction/rotation.period end
                    if angle~=frame.lastAngle or v.tile~=frame.lastTile or frame.size~=frame.lastSize or frame.flip~=frame.lastFlip then
                        local c,s=math.cos(angle),math.sin(angle)
                        local unit=frame.size/(2*atlas.pixels)
                        local dx=v.tile[6]*unit*(frame.flip and -1 or 1)
                        local dy=v.tile[7]*unit
                        v.texture:ClearAllPoints()
                        v.texture:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
                        if v.texture.SetVertexOffset then
                            -- Screen Y increases downward in Studio; native frame Y increases upward.
                            for k,corner in ipairs(corners) do
                                local x=corner[1]*v.texture:GetWidth()/2
                                local y=corner[2]*v.texture:GetHeight()/2
                                v.texture:SetVertexOffset(k,c*x-s*y-x,s*x+c*y-y)
                            end
                        end
                        frame.lastAngle,frame.lastTile,frame.lastSize,frame.lastFlip=angle,v.tile,frame.size,frame.flip
                    end
                    frame.cel=cel
                    return
                end
                index=index-count
            end
        end
        stopImpact(frame)
    end

    local hideBase=E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        local frame=entry[effectID]
        if frame then stopImpact(frame);frame.enabled=false end
        return hideBase(entry)
    end

    local applyBase=E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active=applyBase(entry,config,artwork)
        E.RenderCustomEffectInstances(entry,crest,effectID,function(entry)
            local frame=entry[effectID]
            local layer=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,effectID)
            local controller=active and entry.restorationSegments
            if not active or not controller or not layer or not layer.enabled then
                if frame then stopImpact(frame);frame.enabled=false end
                return frame
            end
            if not frame then
                frame=CreateFrame("Frame",nil,artwork.host)
                entry[effectID]=frame
                local tex=frame:CreateTexture(nil,"ARTWORK")
                tex:SetBlendMode("ADD")
                tex:SetPoint("CENTER",frame,"CENTER")
                if tex.SetBlockingLoadsRequested then tex:SetBlockingLoadsRequested(true) end
                if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false);tex:SetTexelSnappingBias(0) end
                frame.voice={texture=tex}
                frame.rotation={elapsed=0,pivot={.5,.5}}
                tex.epicastDesktopRotation=frame.rotation
                frame:SetScript("OnUpdate",drawImpact)
                if entry.preparingEffect then frame:Hide(); return frame end
            end
            local restart=not frame.enabled
            for _,stage in ipairs(stages) do
                local key=stage[1]
                local selected=layer[key]~=false
                if frame[key]~=selected then restart=true end
                frame[key]=selected
            end
            frame.enabled=true
            if restart then frame.started=GetTime();frame:Show() end
            frame.bank,frame.flip=artwork.textureSize,E.GetCustomEffectFlip(config.flip)
            local w,h=artwork.host:GetWidth(),artwork.host:GetHeight()
            local u=(242+layer.x)/480
            if config.flip then u=1-u end
            frame.size=w*.7*layer.size/100
            frame:SetSize(frame.size,frame.size)
            local lift=(anchorV-.5)*frame.size
            E.AnchorCustomEffect(entry,frame,w,h,w*u,-h*(267-layer.y)/640+lift)
            local rank=artwork.host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
            frame:SetAlpha(layer.opacity/100)
            local spin=frame.rotation
            spin.angle,spin.period,spin.direction=layer.angle,layer.period,layer.reverse and -1 or 1
            spin.startedAt=layer.rotate and frame.started or nil
            drawImpact(frame)
            return entry[effectID]
        end)
        return active
    end
end

registerImpact("rejuvImpact1","EC-Rejuv_Impact_1",E.RejuvImpactBanks[1],24,78,.5)
registerImpact("rejuvImpact2","EC-Rejuv_Impact_2",E.RejuvImpactBanks[2],42,82,.5+1.01/2.68)


-- Release keeps the hold clock running under independently scaled envelopes.
local function registerFlowEffect(id, name, clip, widthAtReference)
    local crest = "DRUID:restoration"
    local defaults = {enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
                      rotate=false,period=3,reverse=false,depth=0,playStart=true,hold=true,playEnd=true}
    local baked=E.CustomEffectPlayback and E.CustomEffectPlayback[crest] and E.CustomEffectPlayback[crest][id]
    for _,key in ipairs({"playStart","hold","playEnd"}) do
        if baked and type(baked[key])=="boolean" then defaults[key]=baked[key] end
    end
    table.insert(descriptors,{id=id,name=name,libraryOnly=true,defaults=defaults})
    local bandCount=#clip.release
    local introVoice=bandCount+1
    local stride=clip.stride or 1
    local corners={{-1,1},{-1,-1},{1,1},{1,-1}}
    local fps=48
    local joinFrames=6

    local function stop(frame)
        frame.phase=nil
        frame:Hide()
        for _,v in ipairs(frame.voices) do v.texture:Hide() end
    end

    local function begin(frame,phase,age)
        if not phase then stop(frame);return end
        frame.phase,frame.age,frame.last=phase,age or 0,GetTime()
        frame:Show()
    end

    local function paint(frame,voice,atlas,tile,scale,opacity,angle)
        local tex=voice.texture
        if scale<=0 or opacity<=0 then tex:Hide();return end
        local page=atlas.pages[tile[1]]
        if voice.page~=page then
            tex:SetTexture(media..page[1])
            voice.page=page
        end
        if voice.tile~=tile or voice.flip~=frame.flip then
            local x,y,w,h=tile[2],tile[3],tile[4],tile[5]
            local l,t,r,b=x/page[2],y/page[3],(x+w)/page[2],(y+h)/page[3]
            if frame.flip then l,r=r,l end
            tex:SetTexCoord(l,t,l,b,r,t,r,b)
        end
        local unit=frame.size*scale/atlas.pixels
        if voice.tile~=tile or voice.flip~=frame.flip or voice.unit~=unit or voice.angle~=angle then
            local c,s=math.cos(angle),math.sin(angle)
            local dx,dy=tile[6]*unit/2*(frame.flip and -1 or 1),tile[7]*unit/2
            tex:ClearAllPoints()
            tex:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
            tex:SetSize(unit*tile[4],unit*tile[5])
            if tex.SetVertexOffset then
                for k,corner in ipairs(corners) do
                    local x,y=corner[1]*tex:GetWidth()/2,corner[2]*tex:GetHeight()/2
                    tex:SetVertexOffset(k,c*x-s*y-x,s*x+c*y-y)
                end
            end
        end
        voice.tile,voice.flip,voice.unit,voice.angle=tile,frame.flip,unit,angle
        tex:SetAlpha(opacity)
        tex:Show()
    end

    local function releaseScale(track,age)
        local frame=math.max(0,math.min(clip.ending,age*fps))
        local whole=math.floor(frame)
        local a=track[whole+1]
        return a+((track[whole+2] or a)-a)*(frame-whole)
    end

    local function draw(frame)
        if not frame.phase then return end
        local now=GetTime()
        local dt=math.max(0,now-frame.last)
        frame.last=now
        frame.age=frame.age+dt
        local phase=frame.phase
        if phase=="intro" and frame.age+1e-7>=clip.intro/fps then
            local extra=math.max(0,frame.age-clip.intro/fps)
            phase=frame.hold and "hold" or (frame.playEnd and "ending" or nil)
            begin(frame,phase,extra)
            frame.cycle=extra
        elseif phase=="hold" or phase=="ending" then
            if frame.animate or phase=="ending" then frame.cycle=frame.cycle+dt end
        end
        if not phase then return end
        if (phase=="ending" and frame.age+1e-7>=clip.ending/fps) or
           (phase=="tap" and frame.age>=.21) then stop(frame);return end
        local spin=frame.rotation
        local elapsed=spin.elapsed+(spin.startedAt and now-spin.startedAt or 0)
        local angle=-math.rad(spin.angle)-elapsed*math.pi*2*spin.direction/spin.period
        local intro,hold=clip.introBank[frame.bank],clip.holdBank[frame.bank]
        if phase=="intro" or phase=="tap" then
            local cel=phase=="tap" and frame.tapCel or math.min(clip.intro-1,math.floor(frame.age*fps+1e-7))
            local opacity=phase=="tap" and 1-smooth(frame.age/.21) or 1
            -- The intro is a flattened image, while Hold adds its bands
            -- separately. Crossfade their light before the phase changes.
            local mix=(frame.hold or frame.playEnd) and smooth((cel-clip.intro+joinFrames)/joinFrames) or 0
            local lead=(cel-clip.intro)%clip.hold
            frame.cel=cel
            paint(frame,frame.voices[introVoice],intro,intro.tiles[math.floor(cel/stride)+1],
                  1,opacity*(1-mix),angle)
            for i=1,bandCount do
                paint(frame,frame.voices[i],hold,hold.bands[i][math.floor(lead/stride)+1],
                      1,opacity*mix,angle)
            end
            return
        end
        frame.voices[introVoice].texture:Hide()
        local cel=math.floor(frame.cycle*fps+1e-7)%clip.hold
        frame.cel=cel
        for i=1,bandCount do
            local scale=1
            if phase=="ending" then
                scale=(frame.releaseFrom and frame.releaseFrom[i] or 1)*releaseScale(clip.release[i],frame.age)
            elseif frame.recovery then
                local t=smooth(frame.age/.19)
                scale=frame.recovery[i]+(1-frame.recovery[i])*t
            end
            frame.voices[i].scale=scale
            paint(frame,frame.voices[i],hold,hold.bands[i][math.floor(cel/stride)+1],scale,1,angle)
        end
        if phase=="hold" and frame.age>=.19 then frame.recovery=nil end
    end

    local function reset(frame)
        frame.cycle,frame.recovery,frame.releaseFrom=0,nil,nil
        begin(frame,frame.playStart and "intro" or (frame.hold and "hold" or (frame.playEnd and "ending" or nil)))
    end

    local function release(frame)
        if not frame.playEnd then stop(frame);return end
        if frame.phase=="intro" then
            frame.tapCel=frame.cel
            begin(frame,"tap")
        elseif frame.phase=="hold" then
            frame.releaseFrom={}
            for i=1,bandCount do frame.releaseFrom[i]=frame.voices[i].scale or 1 end
            frame.recovery=nil
            begin(frame,"ending")
        end
    end

    local hideBase=E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        local frame=entry[id]
        if frame then stop(frame);frame.enabled=nil end
        return hideBase(entry)
    end

    local applyBase=E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active=applyBase(entry,config,artwork)
        E.RenderCustomEffectInstances(entry,crest,id,function(entry)
            local frame=entry[id]
            local settings=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            local controller=active and entry.restorationSegments
            if not active or not controller or not settings or settings.opacity<=0 then
                if frame then stop(frame);frame.enabled=nil end
                return frame
            end
            if not frame and not settings.enabled then return frame end
            if not frame then
                frame=CreateFrame("Frame",nil,artwork.host)
                entry[id]=frame
                frame.voices={}
                frame.rotation={elapsed=0,pivot={.5,.5}}
                for i=1,introVoice do
                    local tex=frame:CreateTexture(nil,"ARTWORK",nil,i-1)
                    tex:SetBlendMode("ADD")
                    if tex.SetBlockingLoadsRequested then tex:SetBlockingLoadsRequested(true) end
                    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false);tex:SetTexelSnappingBias(0) end
                    tex.epicastDesktopRotation=frame.rotation
                    tex:Hide()
                    frame.voices[i]={texture=tex}
                end
                frame:SetScript("OnUpdate",draw)
                if entry.preparingEffect then frame:Hide(); return frame end
            end
            draw(frame)
            frame.bank,frame.flip,frame.animate=artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
            local width,height=artwork.host:GetWidth(),artwork.host:GetHeight()
            local x=(242+settings.x)/480
            if config.flip then x=1-x end
            frame.size=width*(widthAtReference/480)*settings.size/100
            frame:SetSize(frame.size,frame.size)
            E.AnchorCustomEffect(entry,frame,width,height,width*x,-height*(267-settings.y)/640)
            local rank=artwork.host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*settings.depth))
            frame:SetAlpha(settings.opacity/100)
            local spin=frame.rotation
            if settings.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
            elseif spin.startedAt then spin.elapsed=spin.elapsed+GetTime()-spin.startedAt;spin.startedAt=nil end
            spin.angle,spin.period,spin.direction=settings.angle,settings.period,settings.reverse and -1 or 1

            local start,hold,ending=settings.playStart~=false,settings.hold~=false,settings.playEnd~=false
            local changed=frame.playStart~=start or frame.hold~=hold or frame.playEnd~=ending
            frame.playStart,frame.hold,frame.playEnd=start,hold,ending
            if frame.enabled~=settings.enabled then
                frame.enabled=settings.enabled
                if frame.enabled then
                    if frame.phase=="ending" and hold then
                        frame.recovery={}
                        for i=1,bandCount do frame.recovery[i]=frame.voices[i].scale or 0 end
                        begin(frame,"hold")
                    else reset(frame) end
                else release(frame) end
            elseif changed then
                if frame.enabled and not frame.phase then reset(frame)
                elseif frame.phase=="intro" and not start then
                    frame.cycle=0
                    begin(frame,hold and "hold" or (ending and "ending" or nil))
                    frame.releaseFrom=nil
                elseif frame.phase=="hold" and not hold then release(frame)
                elseif (frame.phase=="ending" or frame.phase=="tap") and not ending then stop(frame) end
            end
            draw(frame)
            return entry[id]
        end)
        return active
    end
end

registerFlowEffect("clearcastingFlare","EC-Clearcasting",E.ClearcastingFlare,302)

registerFlowEffect("moonlightGlow","EC-MoonlightGlow",E.moonlightGlow,272)
registerFlowEffect("natureGlow","EC-NatureGlow",E.natureGlow,272)
registerImpact("restorationImpact","EC-RestorationImpact",E.restorationImpact,24,52,0.827338129496)
-- Studio can prepare atlas pages before replay. Older desktop builds only
-- enumerate the earlier Restoration banks.
if Desktop and type(Desktop.restorationEffectPages)=="function" then
    local stockPages=Desktop.restorationEffectPages
    function Desktop.restorationEffectPages()
        local names,seen=stockPages(),{}
        for _,name in ipairs(names) do seen[name]=true end
        local function addBank(banks)
            local bank=banks[Desktop.textureSize]
            if not bank then return end
            local function addTiles(tiles)
                for _,tile in ipairs(tiles) do
                    local name=bank.pages[tile[1]][1]
                    if not seen[name] then seen[name]=true;names[#names+1]=name end
                end
            end
            addTiles(bank.tiles or {})
            for _,band in ipairs(bank.bands or {}) do addTiles(band) end
        end
        local flare=E.ClearcastingFlare
        addBank(flare.introBank)
        addBank(flare.holdBank)
        for _,banks in ipairs(E.RestorationAdditionalEffectBanks) do addBank(banks) end
        table.sort(names)
        return names
    end
end


-- One authored impact. Opacity and placement remain regular layer controls.
do
    local id="natureSealBurst"
    local seconds,rate=1,48
    local defaults={enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
                    rotate=false,period=1,reverse=false,depth=0}
    table.insert(descriptors,{id=id,name="EC-NatureSealBurst",libraryOnly=true,
                              previewSeconds=seconds,defaults=defaults})
    local corners={{-1,1},{-1,-1},{1,1},{1,-1}}

    local function stop(frame)
        frame.started=nil
        frame:Hide()
    end

    local function draw(frame)
        if not frame.started then return end
        local age=math.max(0,GetTime()-frame.started)
        local cel=math.floor(age*rate+1e-7)
        if cel>=rate*seconds then stop(frame);return end
        local atlas=E.NatureSealBurstBanks[frame.bank]
        local voice,spin=frame.voice,frame.rotation
        paintStudioCel(frame,voice,atlas,cel)
        local angle=-math.rad(spin.angle)
        if spin.startedAt then angle=angle-age*2*math.pi*spin.direction/spin.period end
        local tex,tile=voice.texture,voice.tile
        if frame.cel~=cel or frame.lastSize~=frame.size or frame.lastAngle~=angle or
           frame.lastFlip~=frame.flip or frame.lastBank~=frame.bank then
            local c,s=math.cos(angle),math.sin(angle)
            local unit=frame.size/(2*atlas.pixels)
            local dx=tile[6]*unit*(frame.flip and -1 or 1)
            local dy=tile[7]*unit
            tex:ClearAllPoints()
            tex:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
            if tex.SetVertexOffset then
                for i,point in ipairs(corners) do
                    local x,y=point[1]*tex:GetWidth()/2,point[2]*tex:GetHeight()/2
                    tex:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
                end
            end
            frame.cel,frame.lastSize,frame.lastAngle,frame.lastFlip,frame.lastBank=cel,frame.size,angle,frame.flip,frame.bank
        end
    end

    local baseHide=E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        local frame=entry[id]
        if frame then stop(frame);frame.burstEnabled=false end
        for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
            if slot.frame and slot.frame~=frame then stop(slot.frame);slot.frame.burstEnabled=false end
        end
        return baseHide(entry)
    end

    local baseApply=E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active=baseApply(entry,config,artwork)
        local controller=active and entry.restorationSegments
        local function render(target)
            local frame=target[id]
            local layer=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            if not controller or not layer or not layer.enabled then
                if frame then stop(frame);frame.burstEnabled=false end
                return frame
            end
            local host=artwork.host
            local w,h=host:GetWidth(),host:GetHeight()
            local canvas=E.GetCustomEffectCanvas and E.GetCustomEffectCanvas(target,w,h) or host
            if not frame then
                frame=CreateFrame("Frame",nil,canvas)
                target[id]=frame
                local tex=frame:CreateTexture(nil,"ARTWORK")
                tex:SetBlendMode("ADD")
                tex:SetPoint("CENTER",frame,"CENTER")
                if tex.SetBlockingLoadsRequested then tex:SetBlockingLoadsRequested(true) end
                if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false);tex:SetTexelSnappingBias(0) end
                frame.voice={texture=tex}
                frame.rotation={elapsed=0,pivot={.5,.5}}
                tex.epicastDesktopRotation=frame.rotation
                frame:SetScript("OnUpdate",draw)
                if target.preparingEffect then frame:Hide(); return frame end
            elseif frame:GetParent()~=canvas then
                frame:SetParent(canvas)
            end
            frame.bank,frame.flip=artwork.textureSize,E.GetCustomEffectFlip(config.flip)
            local u=(242+layer.x)/480
            if config.flip then u=1-u end
            frame.size=w*(326/480)*layer.size/100
            frame:SetSize(frame.size,frame.size)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER",canvas,"TOPLEFT",w*u,-h*(267-layer.y)/640)
            local rank=host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
            frame:SetAlpha(layer.opacity/100)
            if not frame.burstEnabled then
                frame.burstEnabled=true
                frame.started=GetTime()
                frame:Show()
            end
            local spin=frame.rotation
            spin.angle,spin.period,spin.direction=layer.angle,layer.period,layer.reverse and -1 or 1
            spin.startedAt=layer.rotate and frame.started or nil
            draw(frame)
            if E.RegisterCustomEffectPreviewFrame then E.RegisterCustomEffectPreviewFrame(target,id,frame) end
            return frame
        end
        if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
        else render(entry) end
        return active
    end
end

-- Portrait starlight. Every stage uses the same moving cels and anchor.
do
    local id = "tranquilityStarlight"
    local clip = E.TranquilityStarlight
    local defaults = {enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
        rotate=false,period=4,reverse=false,depth=0,playStart=true,hold=true,playEnd=true}
    table.insert(descriptors,{id=id,name="EC-TranquilityStarlight",libraryOnly=true,defaults=defaults})

    local fps = clip.fps
    local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}
    local bands = #clip.startOpacity
    local views = {}
    for bank,atlas in pairs(clip.banks) do
        views[bank] = {}
        for i,tiles in ipairs(atlas.bands) do
            views[bank][i] = {pixels=atlas.pixels,pages=atlas.pages,tiles=tiles}
        end
    end

    local function transition(frame,stage,extra)
        frame.stage,frame.age,frame.last = stage,extra or 0,GetTime()
        frame:SetShown(stage ~= nil)
    end

    local function stop(frame)
        frame.recovery = false
        transition(frame,nil)
    end

    local function factor(track,t)
        local position = math.max(0,math.min(#track-1,t*fps))
        local index = math.floor(position)
        local a = track[index+1]
        return a + ((track[index+2] or a)-a)*(position-index)
    end

    local function reset(frame)
        local stage = frame.start and "intro" or (frame.hold and "hold" or (frame.ending and "release" or nil))
        frame.clock = stage=="intro" and -clip.intro/fps or 0
        frame.recovery = false
        for _,voice in ipairs(frame.voices) do voice.from=1 end
        transition(frame,stage)
    end

    local function release(frame)
        if frame.stage=="release" then return end
        if not frame.ending or not frame.stage then stop(frame);return end
        for _,voice in ipairs(frame.voices) do voice.from=voice.opacity or 0 end
        frame.recovery = false
        transition(frame,"release")
    end

    local function draw(frame)
        local stage = frame.stage
        if not stage then return end
        local now = GetTime()
        local dt = math.max(0,now-frame.last)
        frame.last = now
        frame.age = frame.age+dt
        if stage~="hold" or frame.animate then frame.clock=frame.clock+dt end
        if stage=="intro" and frame.age+1e-7>=clip.intro/fps then
            local extra = math.max(0,frame.age-clip.intro/fps)
            stage = frame.hold and "hold" or (frame.ending and "release" or nil)
            transition(frame,stage,extra)
            if not stage then return end
        end
        if stage=="release" and frame.age+1e-7>=clip.ending/fps then stop(frame);return end

        local sample = math.floor(frame.clock*fps/clip.stride+1e-7)%(clip.hold/clip.stride)
        local spin = frame.rotation
        local elapsed = spin.elapsed+(spin.startedAt and now-spin.startedAt or 0)
        local angle = -math.rad(spin.angle)-elapsed*math.pi*2*spin.direction/spin.period
        local recovery = frame.recovery and math.min(1,frame.age/.19)
        if recovery==1 then frame.recovery=false end
        for i,voice in ipairs(frame.voices) do
            local opacity=1
            if stage=="intro" then opacity=factor(clip.startOpacity[i],frame.age)
            elseif stage=="release" then opacity=voice.from*factor(clip.endOpacity[i],frame.age)
            elseif recovery then
                local mix=recovery*recovery*(3-2*recovery)
                opacity=voice.from+(1-voice.from)*mix
            end
            voice.opacity=opacity
            local texture=voice.texture
            texture:SetShown(opacity>0)
            if opacity>0 then
                local atlas=views[frame.bank][i]
                paintStudioCel(frame,voice,atlas,sample)
                local tile=voice.tile
                if voice.placement~=tile or voice.width~=frame.size or voice.angle~=angle or voice.mirror~=frame.flip then
                    local sine,cosine=math.sin(angle),math.cos(angle)
                    local unit=frame.size/(2*atlas.pixels)
                    local dx=tile[6]*unit*(frame.flip and -1 or 1)
                    local dy=tile[7]*unit
                    texture:ClearAllPoints()
                    texture:SetPoint("CENTER",frame,"CENTER",cosine*dx-sine*dy,sine*dx+cosine*dy)
                    if texture.SetVertexOffset then
                        for k,corner in ipairs(corners) do
                            local x,y=corner[1]*texture:GetWidth()/2,corner[2]*texture:GetHeight()/2
                            texture:SetVertexOffset(k,cosine*x-sine*y-x,sine*x+cosine*y-y)
                        end
                    end
                    voice.placement,voice.width,voice.angle,voice.mirror=tile,frame.size,angle,frame.flip
                end
                texture:SetAlpha(opacity)
            end
        end
    end

    local function clear(frame)
        if frame then stop(frame);frame.enabled=nil end
    end

    local hideBase = E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        clear(entry[id])
        for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
            if slot.frame~=entry[id] then clear(slot.frame) end
        end
        return hideBase(entry)
    end

    local applyBase = E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active = applyBase(entry,config,artwork)
        local controller = active and entry.restorationSegments
        local function render(target)
            local frame = target[id]
            local settings = E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            if not controller or not settings then clear(frame);return frame end
            if not frame and not settings.enabled then return end
            local host = artwork.host
            local width,height = host:GetWidth(),host:GetHeight()
            local canvas = E.GetCustomEffectCanvas and E.GetCustomEffectCanvas(target,width,height) or host
            if not frame then
                frame = CreateFrame("Frame",nil,canvas)
                target[id] = frame
                frame.voices = {}
                frame.rotation = {elapsed=0,pivot={.5,.5}}
                for i=1,bands do
                    local texture=frame:CreateTexture(nil,"ARTWORK",nil,i-1)
                    texture:SetBlendMode("ADD")
                    if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
                    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0) end
                    texture.epicastDesktopRotation=frame.rotation
                    texture:Hide()
                    frame.voices[i]={texture=texture}
                end
                frame:SetScript("OnUpdate",draw)
                if target.preparingEffect then frame:Hide(); return frame end
                frame:Hide()
            elseif frame:GetParent()~=canvas then
                frame:SetParent(canvas)
            end

            frame.bank,frame.flip,frame.animate = artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
            frame.size = width*clip.width/480*settings.size/100
            frame:SetSize(frame.size,2*frame.size)
            local position = (242+settings.x)/480
            if config.flip then position=1-position end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER",canvas,"TOPLEFT",width*position,-height*(267-settings.y)/640)
            local rank = host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*settings.depth))
            frame:SetAlpha(settings.opacity/100)
            local spin = frame.rotation
            if settings.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
            elseif spin.startedAt then spin.elapsed=spin.elapsed+GetTime()-spin.startedAt;spin.startedAt=nil end
            spin.angle,spin.period,spin.direction=settings.angle,settings.period,settings.reverse and -1 or 1

            local start,hold,ending=settings.playStart~=false,settings.hold~=false,settings.playEnd~=false
            local changed = start~=frame.start or hold~=frame.hold or ending~=frame.ending
            frame.start,frame.hold,frame.ending=start,hold,ending
            if settings.enabled~=frame.enabled then
                frame.enabled=settings.enabled
                if not frame.enabled then release(frame)
                elseif frame.stage=="release" and hold then
                    for _,voice in ipairs(frame.voices) do voice.from=voice.opacity end
                    frame.recovery=true
                    transition(frame,"hold")
                else reset(frame) end
            elseif changed then
                if frame.enabled and not frame.stage then reset(frame)
                elseif frame.stage=="intro" and not start then
                    if hold then
                        transition(frame,"hold")
                    else
                        release(frame)
                    end
                elseif frame.stage=="hold" and not hold then release(frame)
                elseif frame.stage=="release" and not ending then stop(frame) end
            end
            draw(frame)
            if E.RegisterCustomEffectPreviewFrame then E.RegisterCustomEffectPreviewFrame(target,id,frame) end
            return frame
        end
        if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
        else render(entry) end
        return active
    end
end


-- Continuous fixed-frontal channel. Replaying an instance restarts its loop.
do
    local id = "vigilFireflies"
    local clip = E.VigilFireflies
    local defaults = {enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
        rotate=false,period=3,reverse=false,depth=0}
    table.insert(descriptors,{id=id,name="EC-VigilFireflies",libraryOnly=true,defaults=defaults})

    local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}

    local function stop(frame)
        if not frame then return end
        frame.elapsed,frame.started = nil,nil
        frame.rotation.elapsed,frame.rotation.startedAt = 0,nil
        frame:Hide()
    end

    local function draw(frame)
        if not frame.elapsed then return end
        local now = GetTime()
        local elapsed = frame.elapsed+(frame.started and math.max(0,now-frame.started) or 0)
        local cel = math.floor(elapsed*clip.fps+1e-7)%clip.frames
        local atlas = clip.banks[frame.bank]
        local voice,spin = frame.voice,frame.rotation
        paintStudioCel(frame,voice,atlas,cel)
        local spinTime = spin.elapsed+(spin.startedAt and math.max(0,now-spin.startedAt) or 0)
        local angle = -math.rad(spin.angle)-spinTime*2*math.pi*spin.direction/spin.period
        local texture,tile = voice.texture,voice.tile
        if frame.tile==tile and frame.lastSize==frame.size and frame.angle==angle and frame.lastFlip==frame.flip then return end
        local c,s = math.cos(angle),math.sin(angle)
        local unit = frame.size/(2*atlas.pixels)
        local dx = tile[6]*unit*(frame.flip and -1 or 1)
        local dy = tile[7]*unit
        texture:ClearAllPoints()
        texture:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
        if texture.SetVertexOffset then
            for i,corner in ipairs(corners) do
                local x,y = corner[1]*texture:GetWidth()/2,corner[2]*texture:GetHeight()/2
                texture:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
            end
        end
        frame.tile,frame.lastSize,frame.angle,frame.lastFlip = tile,frame.size,angle,frame.flip
    end

    local hideBase = E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        stop(entry[id])
        for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
            if slot.frame~=entry[id] then stop(slot.frame) end
        end
        return hideBase(entry)
    end

    local applyBase = E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active = applyBase(entry,config,artwork)
        local controller = active and entry.restorationSegments
        local function render(target)
            local frame = target[id]
            local layer = E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            if not controller or not layer or not layer.enabled then
                stop(frame)
                return frame
            end
            local host = artwork.host
            local width,height = host:GetWidth(),host:GetHeight()
            local canvas = E.GetCustomEffectCanvas and E.GetCustomEffectCanvas(target,width,height) or host
            if not frame then
                frame = CreateFrame("Frame",nil,canvas)
                target[id] = frame
                local texture = frame:CreateTexture(nil,"ARTWORK")
                texture:SetBlendMode("ADD")
                if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
                if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0) end
                frame.voice = {texture=texture}
                frame.rotation = {elapsed=0,pivot={.5,.5}}
                texture.epicastDesktopRotation = frame.rotation
                frame:SetScript("OnUpdate",draw)
                if target.preparingEffect then frame:Hide(); return frame end
            elseif frame:GetParent()~=canvas then
                frame:SetParent(canvas)
            end
            local now = GetTime()
            frame.bank,frame.flip = artwork.textureSize,E.GetCustomEffectFlip(config.flip)
            frame.size = width*clip.width/480*layer.size/100
            frame:SetSize(frame.size,frame.size*clip.aspect)
            local u = (242+layer.x)/480
            if config.flip then u=1-u end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER",canvas,"TOPLEFT",width*u,-height*(267-layer.y)/640)
            local rank = host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
            frame:SetAlpha(layer.opacity/100)
            frame.elapsed = frame.elapsed or 0
            if artwork.animate then
                frame.started = frame.started or now
            elseif frame.started then
                frame.elapsed = frame.elapsed+math.max(0,now-frame.started)
                frame.started = nil
            end
            local spin = frame.rotation
            if layer.rotate and artwork.animate then
                spin.startedAt = spin.startedAt or now
            elseif spin.startedAt then
                spin.elapsed = spin.elapsed+math.max(0,now-spin.startedAt)
                spin.startedAt = nil
            end
            spin.angle,spin.period,spin.direction = layer.angle,layer.period,layer.reverse and -1 or 1
            frame:Show()
            draw(frame)
            if E.RegisterCustomEffectPreviewFrame then E.RegisterCustomEffectPreviewFrame(target,id,frame) end
            return frame
        end
        if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
        else render(entry) end
        return active
    end
end


-- Single additive impact. A new signal or Replay starts a new playback clock.
do
    local id = "lifebloomImpact"
    local clip = E.LifebloomImpact
    local seconds = clip.frames/clip.fps
    local defaults = {enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
        rotate=false,period=seconds,reverse=false,depth=0}
    table.insert(descriptors,{id=id,name="EC-LifebloomImpact",libraryOnly=true,
        previewSeconds=seconds,defaults=defaults})

    local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}

    local function stop(frame)
        frame.started = nil
        frame:Hide()
    end

    local function reset(frame)
        if not frame then return end
        stop(frame)
        frame.burstEnabled = false
    end

    local function draw(frame)
        if not frame.started then return end
        local age = math.max(0,GetTime()-frame.started)
        local cel = math.floor(age*clip.fps+1e-7)
        if cel>=clip.frames then stop(frame);return end
        local atlas = clip.banks[frame.bank]
        local voice,spin = frame.voice,frame.rotation
        paintStudioCel(frame,voice,atlas,cel)
        local angle = -math.rad(spin.angle)
        if spin.startedAt then angle=angle-age*2*math.pi*spin.direction/spin.period end
        local tex,tile = voice.texture,voice.tile
        if frame.tile==tile and frame.lastSize==frame.size and frame.angle==angle and frame.lastFlip==frame.flip then return end
        local c,s = math.cos(angle),math.sin(angle)
        local unit = frame.size/(2*atlas.pixels)
        local dx = tile[6]*unit*(frame.flip and -1 or 1)
        local dy = tile[7]*unit
        tex:ClearAllPoints()
        tex:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
        if tex.SetVertexOffset then
            for i,corner in ipairs(corners) do
                local x,y = corner[1]*tex:GetWidth()/2,corner[2]*tex:GetHeight()/2
                tex:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
            end
        end
        frame.tile,frame.lastSize,frame.angle,frame.lastFlip = tile,frame.size,angle,frame.flip
    end

    local hideBase = E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        reset(entry[id])
        for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
            if slot.frame~=entry[id] then reset(slot.frame) end
        end
        return hideBase(entry)
    end

    local applyBase = E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active = applyBase(entry,config,artwork)
        local controller = active and entry.restorationSegments
        local function render(target)
            local frame = target[id]
            local layer = E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            if not controller or not layer or not layer.enabled then
                reset(frame)
                return frame
            end
            local host = artwork.host
            local width,height = host:GetWidth(),host:GetHeight()
            local canvas = E.GetCustomEffectCanvas and E.GetCustomEffectCanvas(target,width,height) or host
            if not frame then
                frame = CreateFrame("Frame",nil,canvas)
                target[id] = frame
                local texture = frame:CreateTexture(nil,"ARTWORK")
                texture:SetBlendMode("ADD")
                if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
                if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0) end
                frame.voice = {texture=texture}
                frame.rotation = {elapsed=0,pivot={.5,.5}}
                texture.epicastDesktopRotation = frame.rotation
                frame:SetScript("OnUpdate",draw)
                if target.preparingEffect then frame:Hide(); return frame end
            elseif frame:GetParent()~=canvas then
                frame:SetParent(canvas)
            end
            frame.bank,frame.flip = artwork.textureSize,E.GetCustomEffectFlip(config.flip)
            local u = (242+layer.x)/480
            if config.flip then u=1-u end
            frame.size = width*clip.width/480*layer.size/100
            frame:SetSize(frame.size,frame.size)
            frame:ClearAllPoints()
            frame:SetPoint("CENTER",canvas,"TOPLEFT",width*u,
                -height*(267-layer.y)/640+frame.size*(clip.anchorV-.5))
            local rank = host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
            frame:SetAlpha(layer.opacity/100)
            if not frame.burstEnabled then
                frame.burstEnabled = true
                frame.started = GetTime()
                frame:Show()
            end
            local spin = frame.rotation
            spin.angle,spin.period,spin.direction = layer.angle,layer.period,layer.reverse and -1 or 1
            spin.startedAt = layer.rotate and frame.started or nil
            draw(frame)
            if E.RegisterCustomEffectPreviewFrame then E.RegisterCustomEffectPreviewFrame(target,id,frame) end
            return frame
        end
        if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
        else render(entry) end
        return active
    end
end



-- The impact is a single pass. The channel releases from a matching hold cel.
do
    local corners = {{-1,1},{-1,-1},{1,1},{1,-1}}

    local function hide(frame)
        frame.stage,frame.released=nil,nil
        frame:Hide()
    end

    local function advance(frame,stage,age)
        frame.stage,frame.age,frame.last=stage,age or 0,GetTime()
        frame.released=nil
        frame:SetShown(stage~=nil)
    end

    local function selectCel(frame,clip)
        local stage=frame.stage
        if not stage then return end
        local now=GetTime()
        local dt=math.max(0,now-frame.last)*clip.fps
        frame.last=now
        if stage~="hold" or frame.animate then frame.age=frame.age+dt end
        local age=frame.age
        if stage=="impact" then
            local cel=math.floor(age+1e-7)
            if cel>=clip.frames then hide(frame);return end
            return cel
        elseif stage=="intro" then
            local cel=math.floor(age+1e-7)
            if cel<clip.intro then return cel end
            if frame.hold then
                advance(frame,"hold",age-clip.intro)
            elseif frame.ending then
                advance(frame,"release",age-clip.intro)
                frame.exit=0
            else hide(frame);return end
        elseif stage=="rewind" then
            local cel=frame.reverseFrom-math.floor(age)
            if cel<=0 then hide(frame);return end
            return cel
        end
        if frame.stage=="hold" then
            if not frame.released or age<frame.released-1e-7 then
                return clip.intro+math.floor(frame.age+1e-7)%clip.hold
            end
            local exit=frame.released%clip.hold/clip.phaseStep
            advance(frame,"release",age-frame.released)
            frame.exit=exit
        end
        local cel=math.floor(frame.age/clip.outStride+1e-7)
        if cel>=clip.outFrames then hide(frame);return end
        return clip.intro+clip.hold+clip.outFrames*frame.exit+cel
    end

    local function start(frame,clip)
        if not clip.intro then advance(frame,"impact")
        elseif frame.start then advance(frame,"intro")
        elseif frame.hold then advance(frame,"hold")
        elseif frame.ending then
            advance(frame,"release")
            frame.exit=0
        else hide(frame) end
    end

    local function release(frame,clip)
        if not clip.intro or not frame.ending then hide(frame)
        elseif frame.stage=="hold" and not frame.released then
            local step=clip.phaseStep
            frame.released=math.ceil((frame.age-1e-7)/step)*step
            if not frame.animate then frame.age=frame.released end
        elseif frame.stage=="intro" then
            frame.reverseFrom=math.min(clip.intro-1,math.floor(frame.age))
            advance(frame,"rewind")
        end
    end

    local function register(id,name,clip)
        local channel=clip.intro~=nil
        local defaults={enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
            rotate=false,period=channel and 1 or clip.frames/clip.fps,reverse=false,depth=0}
        if channel then defaults.playStart,defaults.hold,defaults.playEnd=true,true,true end
        table.insert(descriptors,{id=id,name=name,libraryOnly=true,defaults=defaults,
            previewSeconds=not channel and clip.frames/clip.fps or nil})

        local function draw(frame)
            local cel=selectCel(frame,clip)
            if not cel then return end
            local atlas=clip.banks[frame.bank]
            local voice,spin=frame.voice,frame.rotation
            paintStudioCel(frame,voice,atlas,cel)
            local elapsed=spin.elapsed+(spin.startedAt and GetTime()-spin.startedAt or 0)
            local angle=-math.rad(spin.angle)-elapsed*2*math.pi*spin.direction/spin.period
            local tex,tile=voice.texture,voice.tile
            if frame.tile==tile and frame.lastSize==frame.size and frame.angle==angle and frame.lastFlip==frame.flip then return end
            local c,s=math.cos(angle),math.sin(angle)
            local unit=frame.size/(2*atlas.pixels)
            local dx=tile[6]*unit*(frame.flip and -1 or 1)
            local dy=tile[7]*unit
            tex:ClearAllPoints()
            tex:SetPoint("CENTER",frame,"CENTER",c*dx-s*dy,s*dx+c*dy)
            if tex.SetVertexOffset then
                for i,corner in ipairs(corners) do
                    local x,y=corner[1]*tex:GetWidth()/2,corner[2]*tex:GetHeight()/2
                    tex:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
                end
            end
            frame.tile,frame.lastSize,frame.angle,frame.lastFlip=tile,frame.size,angle,frame.flip
        end

        local function clear(frame)
            if frame then hide(frame);frame.wildGrowthEnabled=nil end
        end

        local hideBase=E.HideRestorationSegments
        function E.HideRestorationSegments(entry)
            clear(entry[id])
            for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
                if slot.frame~=entry[id] then clear(slot.frame) end
            end
            return hideBase(entry)
        end

        local applyBase=E.ApplyRestorationSegments
        function E.ApplyRestorationSegments(entry,config,artwork)
            local active=applyBase(entry,config,artwork)
            local controller=active and entry.restorationSegments
            local function render(target)
                local frame=target[id]
                local layer=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
                if not controller or not layer then clear(frame);return frame end
                if not frame and not layer.enabled then return end
                local host=artwork.host
                local width,height=host:GetWidth(),host:GetHeight()
                local canvas=E.GetCustomEffectCanvas and E.GetCustomEffectCanvas(target,width,height) or host
                if not frame then
                    frame=CreateFrame("Frame",nil,canvas)
                    target[id]=frame
                    local texture=frame:CreateTexture(nil,"ARTWORK")
                    texture:SetBlendMode("ADD")
                    if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
                    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0) end
                    frame.voice={texture=texture}
                    frame.rotation={elapsed=0,pivot={.5,.5}}
                    texture.epicastDesktopRotation=frame.rotation
                    frame:SetScript("OnUpdate",draw)
                    if target.preparingEffect then frame:Hide(); return frame end
                    frame:Hide()
                elseif frame:GetParent()~=canvas then
                    frame:SetParent(canvas)
                end
                frame.bank,frame.flip,frame.animate=artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
                frame.size=width*clip.width/480*layer.size/100
                frame:SetSize(frame.size,frame.size)
                local u=(240+layer.x)/480
                if config.flip then u=1-u end
                frame:ClearAllPoints()
                frame:SetPoint("CENTER",canvas,"TOPLEFT",width*u,-height*(427-layer.y)/640)
                local rank=host:GetFrameLevel()
                for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
                frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
                frame:SetAlpha(layer.opacity/100)
                local spin=frame.rotation
                if layer.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
                elseif spin.startedAt then
                    spin.elapsed=spin.elapsed+GetTime()-spin.startedAt
                    spin.startedAt=nil
                end
                spin.angle,spin.period,spin.direction=layer.angle,layer.period,layer.reverse and -1 or 1
                local showStart,hold,ending=layer.playStart~=false,layer.hold~=false,layer.playEnd~=false
                local changed=showStart~=frame.start or hold~=frame.hold or ending~=frame.ending
                frame.start,frame.hold,frame.ending=showStart,hold,ending
                if frame.wildGrowthEnabled~=layer.enabled then
                    frame.wildGrowthEnabled=layer.enabled
                    if layer.enabled then
                        spin.elapsed=0
                        if spin.startedAt then spin.startedAt=GetTime() end
                        start(frame,clip)
                    else release(frame,clip) end
                elseif channel and changed then
                    if not ending and (frame.stage=="release" or frame.stage=="rewind") then hide(frame)
                    elseif frame.wildGrowthEnabled and not frame.stage then start(frame,clip)
                    elseif frame.stage=="intro" and not showStart then start(frame,clip)
                    elseif frame.stage=="hold" and not hold then release(frame,clip) end
                end
                draw(frame)
                if E.RegisterCustomEffectPreviewFrame then E.RegisterCustomEffectPreviewFrame(target,id,frame) end
                return frame
            end
            if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
            else render(entry) end
            return active
        end
    end

    register("wildGrowthMane","EC-WildGrowthMane",E.WildGrowthMane)
    register("wildGrowthManeLite","EC-WildGrowthManeLite",E.WildGrowthManeLite)
end

-- Wind and pollen emit light. The tumbling leaves retain their painted colour.
do
    local id,clip="autumnGust",E.AutumnGust
    local defaults={enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
        rotate=false,period=2,reverse=false,depth=0,playStart=true,hold=true,playEnd=true}
    table.insert(descriptors,{id=id,name="EC-AutumnGust",libraryOnly=true,defaults=defaults})

    local corners={{-1,1},{-1,-1},{1,1},{1,-1}}

    local function switch(frame,stage,age)
        frame.stage,frame.age,frame.last=stage,age or 0,GetTime()
        frame.exitAt=nil
        frame:SetShown(stage~=nil)
    end

    local function start(frame)
        if frame.playStart then switch(frame,"intro")
        elseif frame.hold then switch(frame,"hold")
        elseif frame.playEnd then frame.branch=0;switch(frame,"outro")
        else switch(frame,nil) end
    end

    local function release(frame)
        if not frame.playEnd then switch(frame,nil)
        elseif frame.stage=="hold" and not frame.exitAt then
            local step=clip.phaseStep
            local current=math.floor(frame.age+1e-7)
            frame.exitAt=math.ceil(current/step)*step
            if not frame.animate then frame.age=frame.exitAt end
        elseif frame.stage=="intro" then
            frame.rewindFrom=math.min(clip.intro-1,math.floor(frame.age+1e-7))
            switch(frame,"rewind")
        end
    end

    local function index(frame)
        local now=GetTime()
        local stage=frame.stage
        if not stage then return end
        if stage~="hold" or frame.animate then
            frame.age=frame.age+math.max(0,now-frame.last)*clip.fps
        end
        frame.last=now
        local cel=math.floor(frame.age+1e-7)
        if stage=="intro" then
            if cel<clip.intro then return cel end
            local over=math.max(0,frame.age-clip.intro)
            if frame.hold then switch(frame,"hold",over)
            elseif frame.playEnd then frame.branch=0;switch(frame,"outro",over)
            else switch(frame,nil);return end
            cel=math.floor(frame.age+1e-7)
        elseif stage=="rewind" then
            local back=frame.rewindFrom-cel
            if back>0 then return back end
            switch(frame,nil);return
        end
        if frame.stage=="hold" then
            if not frame.exitAt or cel<frame.exitAt then return clip.intro+cel%clip.hold end
            frame.branch=frame.exitAt%clip.hold/clip.phaseStep
            local over=math.max(0,frame.age-frame.exitAt)
            switch(frame,"outro",over)
            cel=math.floor(over+1e-7)
        end
        if cel>=clip.ending then switch(frame,nil);return end
        return clip.intro+clip.hold+frame.branch*clip.ending+cel
    end

    local function draw(frame)
        local cel=index(frame)
        if not cel then return end
        local atlas=clip.banks[frame.bank]
        local spin=frame.rotation
        local elapsed=spin.elapsed+(spin.startedAt and GetTime()-spin.startedAt or 0)
        local angle=-math.rad(spin.angle)-elapsed*math.pi*2*spin.direction/spin.period
        local c,s=math.cos(angle),math.sin(angle)
        local unit=frame.size/(2*atlas.pixels)
        for i,voice in ipairs(frame.voices) do
            paintStudioCel(frame,voice,atlas.lanes[i],cel)
            local tex,tile=voice.texture,voice.tile
            if voice.placed~=tile or voice.width~=frame.size or voice.angle~=angle or voice.mirror~=frame.flip then
                -- Each trim is placed relative to the same full authored pivot.
                local x,y=tile[6]*unit*(frame.flip and -1 or 1),tile[7]*unit
                tex:ClearAllPoints()
                tex:SetPoint("CENTER",frame,"CENTER",c*x-s*y,s*x+c*y)
                if tex.SetVertexOffset then
                    for k,corner in ipairs(corners) do
                        local dx,dy=corner[1]*tex:GetWidth()/2,corner[2]*tex:GetHeight()/2
                        tex:SetVertexOffset(k,c*dx-s*dy-dx,s*dx+c*dy-dy)
                    end
                end
                voice.placed,voice.width,voice.angle,voice.mirror=tile,frame.size,angle,frame.flip
            end
        end
    end

    local function clear(frame)
        if frame then frame.gustEnabled=nil;switch(frame,nil) end
    end

    local hideBase=E.HideRestorationSegments
    function E.HideRestorationSegments(entry)
        clear(entry[id])
        for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
            if slot.frame~=entry[id] then clear(slot.frame) end
        end
        return hideBase(entry)
    end

    local applyBase=E.ApplyRestorationSegments
    function E.ApplyRestorationSegments(entry,config,artwork)
        local active=applyBase(entry,config,artwork)
        local controller=active and entry.restorationSegments
        local function render(target)
            local frame=target[id]
            local layer=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
            if not controller or not layer then clear(frame);return frame end
            if not frame and not layer.enabled then return end
            local host=artwork.host
            local width,height=host:GetWidth(),host:GetHeight()
            local canvas=E.GetCustomEffectCanvas(target,width,height)
            if not frame then
                frame=CreateFrame("Frame",nil,canvas)
                target[id]=frame
                frame.voices={}
                frame.rotation={elapsed=0,pivot={.5,.5}}
                for i,mode in ipairs({"ADD","BLEND"}) do
                    local tex=frame:CreateTexture(nil,"ARTWORK",nil,i-1)
                    tex:SetBlendMode(mode)
                    if tex.SetBlockingLoadsRequested then tex:SetBlockingLoadsRequested(true) end
                    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false);tex:SetTexelSnappingBias(0) end
                    tex.epicastDesktopRotation=frame.rotation
                    frame.voices[i]={texture=tex}
                end
                frame:SetScript("OnUpdate",draw)
                if target.preparingEffect then frame:Hide(); return frame end
                frame:Hide()
            end
            frame.bank,frame.flip,frame.animate=artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
            frame.size=width*clip.width/480*layer.size/100
            frame:SetSize(frame.size,frame.size)
            local u=(242+layer.x)/480
            if config.flip then u=1-u end
            E.AnchorCustomEffect(target,frame,width,height,width*u,-height*(267-layer.y)/640)
            local rank=host:GetFrameLevel()
            for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
            frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
            frame:SetAlpha(layer.opacity/100)

            local spin=frame.rotation
            if layer.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
            elseif spin.startedAt then spin.elapsed=spin.elapsed+GetTime()-spin.startedAt;spin.startedAt=nil end
            spin.angle,spin.period,spin.direction=layer.angle,layer.period,layer.reverse and -1 or 1
            local showStart,hold,ending=layer.playStart~=false,layer.hold~=false,layer.playEnd~=false
            local changed=showStart~=frame.playStart or hold~=frame.hold or ending~=frame.playEnd
            frame.playStart,frame.hold,frame.playEnd=showStart,hold,ending
            if frame.gustEnabled~=layer.enabled then
                frame.gustEnabled=layer.enabled
                if layer.enabled then start(frame) else release(frame) end
            elseif changed then
                if not ending and (frame.stage=="outro" or frame.stage=="rewind" or frame.exitAt) then switch(frame,nil)
                elseif frame.gustEnabled and not frame.stage then start(frame)
                elseif frame.stage=="intro" and not showStart then start(frame)
                elseif frame.stage=="hold" and not hold then release(frame) end
            end
            draw(frame)
            return frame
        end
        if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
        else render(entry) end
        return active
    end
end

-- Both auras keep the same pivot, scale, and moving hold cels through release.
do
    local corners={{-1,1},{-1,-1},{1,1},{1,-1}}
    local function hide(frame)
        frame.stage=nil
        frame:Hide()
    end

    local function stage(frame,nextStage,age)
        frame.stage,frame.age,frame.last=nextStage,age or 0,GetTime()
        frame:Show()
    end

    local function register(id,name,clip)
        local defaults={enabled=true,size=100,opacity=100,x=0,y=0,angle=0,
            rotate=false,period=2,reverse=false,depth=0,playStart=true,hold=true,playEnd=true}
        table.insert(descriptors,{id=id,name=name,libraryOnly=true,defaults=defaults})

        local function start(frame)
            frame.clock=frame.playStart and -clip.intro or 0
            frame.releaseLevel=1
            if frame.playStart then stage(frame,"intro")
            elseif frame.hold then stage(frame,"hold")
            elseif frame.playEnd then stage(frame,"outro")
            else hide(frame) end
        end

        local function release(frame)
            if not frame.playEnd then hide(frame)
            elseif frame.stage=="hold" or frame.stage=="intro" then
                local current=math.max(0,math.floor(frame.age+1e-7))
                frame.releaseLevel=frame.stage=="intro" and (clip.introLevels[current+1] or 1) or 1
                if frame.releaseLevel<=0 then hide(frame) else stage(frame,"outro") end
            end
        end

        local function sample(frame)
            local current=frame.stage
            if not current then return end
            local now=GetTime()
            local delta=math.max(0,now-frame.last)*clip.fps
            frame.last=now
            if current~="hold" or frame.animate then
                frame.clock=frame.clock+delta
                frame.age=frame.age+delta
            end
            local cel=math.floor(frame.age+1e-7)
            if current=="intro" then
                if cel<clip.intro then return cel,1 end
                local over=math.max(0,frame.age-clip.intro)
                if frame.hold then stage(frame,"hold",over)
                elseif frame.playEnd then stage(frame,"outro",over)
                else hide(frame);return end
            end
            local opacity=1
            if frame.stage=="outro" then
                local t=frame.age/clip.ending
                if t>=1 then hide(frame);return end
                opacity=frame.releaseLevel*(1-t*t*(3-2*t))
            end
            return clip.intro+math.floor(frame.clock+1e-7)%clip.hold,opacity
        end

        local function draw(frame)
            local cel,opacity=sample(frame)
            if not cel then return end
            local atlas,voice,spin=clip.banks[frame.bank],frame.voice,frame.rotation
            paintStudioCel(frame,voice,atlas,cel)
            local texture,tile=voice.texture,voice.tile
            texture:SetAlpha(opacity)
            local elapsed=spin.elapsed+(spin.startedAt and GetTime()-spin.startedAt or 0)
            local angle=-math.rad(spin.angle)-elapsed*math.pi*2*spin.direction/spin.period
            if frame.placed==tile and frame.lastSize==frame.size and frame.angle==angle and frame.mirror==frame.flip then return end
            local c,s=math.cos(angle),math.sin(angle)
            local unit=frame.size/(2*atlas.pixels)
            local x,y=tile[6]*unit*(frame.flip and -1 or 1),tile[7]*unit
            texture:ClearAllPoints()
            texture:SetPoint("CENTER",frame,"CENTER",c*x-s*y,s*x+c*y)
            if texture.SetVertexOffset then
                for i,corner in ipairs(corners) do
                    local dx,dy=corner[1]*texture:GetWidth()/2,corner[2]*texture:GetHeight()/2
                    texture:SetVertexOffset(i,c*dx-s*dy-dx,s*dx+c*dy-dy)
                end
            end
            frame.placed,frame.lastSize,frame.angle,frame.mirror=tile,frame.size,angle,frame.flip
        end

        local function clear(frame)
            if frame then frame.auraEnabled=nil;hide(frame) end
        end

        local hideBase=E.HideRestorationSegments
        function E.HideRestorationSegments(entry)
            clear(entry[id])
            for _,slot in ipairs(entry.customEffectPools and entry.customEffectPools[id] or {}) do
                if slot.frame~=entry[id] then clear(slot.frame) end
            end
            return hideBase(entry)
        end

        local applyBase=E.ApplyRestorationSegments
        function E.ApplyRestorationSegments(entry,config,artwork)
            local active=applyBase(entry,config,artwork)
            local controller=active and entry.restorationSegments
            local function render(target)
                local frame=target[id]
                local layer=E.GetCustomEffectSettings and E.GetCustomEffectSettings(crest,id)
                if not controller or not layer then clear(frame);return frame end
                if not frame and not layer.enabled then return end
                local host=artwork.host
                local width,height=host:GetWidth(),host:GetHeight()
                if not frame then
                    frame=CreateFrame("Frame",nil,E.GetCustomEffectCanvas(target,width,height))
                    target[id]=frame
                    local texture=frame:CreateTexture(nil,"ARTWORK")
                    texture:SetBlendMode("ADD")
                    if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
                    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0) end
                    frame.voice={texture=texture}
                    frame.rotation={elapsed=0,pivot={.5,.5}}
                    texture.epicastDesktopRotation=frame.rotation
                    frame:SetScript("OnUpdate",draw)
                    if target.preparingEffect then frame:Hide(); return frame end
                    frame:Hide()
                end
                frame.bank,frame.flip,frame.animate=artwork.textureSize,E.GetCustomEffectFlip(config.flip),artwork.animate
                frame.size=width*clip.width/480*layer.size/100
                frame:SetSize(frame.size,frame.size)
                local u=(242+layer.x)/480
                if config.flip then u=1-u end
                E.AnchorCustomEffect(target,frame,width,height,width*u,-height*(267-layer.y)/640)
                local rank=host:GetFrameLevel()
                for _,part in pairs(controller.layers) do rank=math.max(rank,part.frame:GetFrameLevel()) end
                frame:SetFrameLevel(math.max(0,rank+1+2*layer.depth))
                frame:SetAlpha(layer.opacity/100)
                local spin=frame.rotation
                if layer.rotate and artwork.animate then spin.startedAt=spin.startedAt or GetTime()
                elseif spin.startedAt then spin.elapsed=spin.elapsed+GetTime()-spin.startedAt;spin.startedAt=nil end
                spin.angle,spin.period,spin.direction=layer.angle,layer.period,layer.reverse and -1 or 1
                local opening,hold,ending=layer.playStart~=false,layer.hold~=false,layer.playEnd~=false
                local changed=opening~=frame.playStart or hold~=frame.hold or ending~=frame.playEnd
                frame.playStart,frame.hold,frame.playEnd=opening,hold,ending
                if frame.auraEnabled~=layer.enabled then
                    frame.auraEnabled=layer.enabled
                    if layer.enabled then start(frame) else release(frame) end
                elseif changed then
                    if frame.stage=="outro" and not ending then hide(frame)
                    elseif frame.auraEnabled and not frame.stage then start(frame)
                    elseif frame.stage=="intro" and not opening then start(frame)
                    elseif frame.stage=="hold" and not hold then release(frame) end
                end
                draw(frame)
                return frame
            end
            if E.RenderCustomEffectInstances then E.RenderCustomEffectInstances(entry,crest,id,render)
            else render(entry) end
            return active
        end
    end

    register("natureAuraSoft","EC-NatureAuraSoft",E.NatureAuraSoft)
    register("natureAuraStrong","EC-NatureAuraStrong",E.NatureAuraStrong)
end

local _, E = ...
E.ArtworkChannelPlusMedia = E.ArtworkChannelPlusMedia or {}
E.ArtworkChannelPlusMedia["DRUID:restoration"] = "Interface\\AddOns\\Epicast\\StudioCrests\\DruidRestoration-v16-b434bd12da5ae179e3d0102f10f31e9530a9d126048dc02adaac3444b78a85c0\\"
