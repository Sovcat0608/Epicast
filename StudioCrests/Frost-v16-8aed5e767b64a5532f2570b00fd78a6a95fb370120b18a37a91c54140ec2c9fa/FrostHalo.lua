-- The Frost review bank shares native FrameXML motion between Studio and WoW.
local _, E = ...
local data = E.FrostHaloData
local media = "Interface\\AddOns\\Epicast\\StudioCrests\\Frost-v16-8aed5e767b64a5532f2570b00fd78a6a95fb370120b18a37a91c54140ec2c9fa\\"

local definitions = {
    {id="artwork", name="Frost Spellbook", motion="Crest hover"},
    {id="frostHalo", name="Rear halo", motion="40-second rotation"},
    {id="frostColdSnap", name="Cold Snap", motion="Six-second hover"},
    {id="frostShards", name="Ice shards", motion="Six-second hover"},
    {id="frostShoulders", name="Shoulder floaters", motion="Six-second hover"},
    {id="frostBaseFloaters", name="Base floaters", motion="Six-second hover"},
}

local getLayers = E.GetArtworkLayers
function E.GetArtworkLayers(config)
    if config.art == "mageFrost" then return definitions end
    return getLayers(config)
end

local getState = E.GetStudioState
function E.GetStudioState(config)
    local state = getState(config)
    if config.art ~= "mageFrost" then return state end
    if state.artwork.frostHalo then
        if not E.GetAddedEffects(config).studio then
            for i, id in ipairs(state.order) do
                if id == "frostHalo" and state.order[i-1] == "artwork" then
                    state.order[i-1], state.order[i] = id, "artwork"
                    break
                end
            end
        end
        return state
    end
    local expanded = E.Copy(state)
    local index = 1
    for i, id in ipairs(expanded.order) do
        if id == "artwork" then
            index = i
            table.remove(expanded.order, i)
            break
        end
    end
    local shared = state.artwork.artwork or {enabled=true, opacity=100}
    table.insert(expanded.order, index, "frostHalo")
    for _, layer in ipairs(definitions) do
        if layer.id ~= "frostHalo" then
            index = index + 1
            table.insert(expanded.order, index, layer.id)
        end
        expanded.artwork[layer.id] = E.Copy(shared)
    end
    return expanded
end

local function stopClock(clock)
    if not clock.startedAt then return end
    clock.elapsed = (clock.elapsed + math.max(0, GetTime() - clock.startedAt)) % clock.period
    clock.startedAt = nil
    clock.animation:Stop()
end

local function playClock(clock)
    if clock.startedAt then return end
    clock.startedAt = GetTime()
    clock.animation:Play(false, clock.elapsed)
end

local function frame(parent)
    local host = CreateFrame("Frame", nil, parent)
    host:EnableMouse(false)
    return host
end

local function texture(host, drawLayer)
    local paint = host:CreateTexture(nil, drawLayer or "ARTWORK")
    if paint.SetSnapToPixelGrid then paint:SetSnapToPixelGrid(false) end
    if paint.SetTexelSnappingBias then paint:SetTexelSnappingBias(0) end
    if paint.SetBlockingLoadsRequested then paint:SetBlockingLoadsRequested(true) end
    return paint
end

local function placeTile(s, paint, host, tile)
    local l,t,r,b,u,v,ur,vb,page = unpack(tile)
    local left = s.flip and (1-r*data.ratio+data.origin) or (l*data.ratio-data.origin)
    paint:ClearAllPoints()
    paint:SetPoint("TOPLEFT", host, "TOPLEFT", left*s.width, -t*s.height)
    paint:SetSize((r-l)*data.ratio*s.width, (b-t)*s.height)
    paint:SetTexture(media .. (page == 1 and s.bank.halo or s.bank.page))
    paint:SetTexCoord(E.UV({u,v,u,vb,ur,v,ur,vb}, s.flip))
end

local function showContact(s, patch, caster, offset, opacity)
    local tiles = s.bank.tiles["contact:" .. caster .. ":" .. offset]
    local tile = tiles and tiles[1]
    patch.paint:SetShown(tile ~= nil and opacity > .0001)
    if tile and opacity > .0001 then
        if patch.tile ~= tile then
            patch.tile = tile
            placeTile(s, patch.paint, s.contactHost, tile)
        end
        patch.paint:SetAlpha(opacity)
    end
end

local function drawContacts(s)
    local poses = data.contactPoses
    for _, id in ipairs(data.contactCasters) do
        local layer = s.layers[id]
        local opacity = layer.host:IsShown() and layer.host:GetAlpha() or 0
        local patches = s.contacts[id]
        if id == "artwork" then
            showContact(s, patches[1], id, "0", opacity)
        else
            local phase = E.GetArtworkPhase(layer)
            local dy = 0
            if phase then
                local rising = phase < 3
                local leg = layer.legs[rising and 1 or 2]
                local t = (phase % 3)/3
                local smooth = leg.GetSmoothProgress and leg:GetSmoothProgress() or t*t*(3-2*t)
                local lift = rising and (1-2*smooth) or (2*smooth-1)
                dy = lift * (data.travel[id] or .012) * 1254
            end
            local step = (dy-poses[1])/(poses[2]-poses[1])
            local index = math.max(1, math.min(#poses-1, math.floor(step)+1))
            local u = math.max(0, math.min(1, step-index+1))
            showContact(s, patches[1], id, tostring(poses[index]), opacity*(1-u))
            showContact(s, patches[2], id, tostring(poses[index+1]), opacity*u)
        end
    end
end

local function create(root)
    local s = {root=root, layers={}}
    for _, def in ipairs(definitions) do
        local host = frame(root.host)
        local layer = {host=host, textures={}}
        local phase = data.phases[def.id]
        if phase then
            local hover = host:CreateAnimationGroup()
            hover:SetLooping("REPEAT")
            layer.hover, layer.animation = hover, hover
            layer.period, layer.elapsed, layer.legs = 6, phase, {}
            for index = 1, 2 do
                local leg = hover:CreateAnimation("Translation")
                leg:SetOrder(index)
                leg:SetDuration(3)
                leg:SetSmoothing("IN_OUT")
                layer.legs[index] = leg
            end
            -- Uses the same Studio geometry bridge as the native Mage crest hover.
            host.desktopHover = layer
        end
        s.layers[def.id] = layer
    end
    local halo = s.layers.frostHalo
    halo.paint = texture(halo.host)
    halo.paint:SetAllPoints(halo.host)
    local spin = halo.paint:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local rotation = spin:CreateAnimation("Rotation")
    rotation:SetOrder(1)
    rotation:SetDuration(data.period)
    rotation:SetSmoothing("NONE")
    halo.clock = {animation=spin, elapsed=0, period=data.period, pivot=data.pivot}
    halo.rotation = rotation
    s.halo = halo.paint
    s.backBlur = texture(s.layers.frostColdSnap.host, "BACKGROUND")
    s.contactHost = frame(halo.host)
    s.contactHost:SetAllPoints(halo.host)
    s.contactDriver = frame(s.contactHost)
    s.contactDriver:SetScript("OnUpdate", function() drawContacts(s) end)
    s.contactDriver:Hide()
    s.contacts = {}
    for _, id in ipairs(data.contactCasters) do
        s.contacts[id] = {}
        for i = 1, id == "artwork" and 1 or 2 do
            s.contacts[id][i] = {paint=texture(s.contactHost)}
        end
    end
    return s
end

local function setVisibility(s)
    local live = s.active and s.root.animate and s.root.host:IsVisible()
    for _, layer in pairs(s.layers) do
        local clock = layer.clock or (layer.hover and layer)
        if clock then
            if live and layer.host:IsShown() then playClock(clock) else stopClock(clock) end
        end
    end
    if s.bank then
        drawContacts(s)
        s.contactDriver:SetShown(live and s.layers.frostHalo.host:IsShown())
    end
end

local function stop(s)
    for _, layer in pairs(s.layers) do
        local clock = layer.clock or (layer.hover and layer)
        if clock then stopClock(clock) end
    end
    s.contactDriver:Hide()
end

local function present(s, entry, config, bank)
    local parent = s.root.host
    local width, height = parent:GetWidth(), parent:GetHeight()
    local animate = s.root.animate
    local direction = config.flip and -1 or 1
    if s.width ~= width or s.height ~= height or s.animated ~= animate or s.direction ~= direction then
        stop(s)
    end
    local layoutChanged = s.width ~= width or s.height ~= height or s.direction ~= direction or s.bank ~= bank
    s.width, s.height, s.animated, s.direction = width, height, animate, direction
    s.bank, s.flip = bank, config.flip
    local halo = s.layers.frostHalo
    halo.clock.direction = direction
    halo.rotation:SetOrigin("CENTER", (data.pivot[1]-.5)*width, (.5-data.pivot[2])*height)
    halo.rotation:SetDegrees(-360*direction)
    halo.paint.epicastDesktopRotation = animate and halo.clock or nil
    local uv = bank.uv
    halo.paint:SetTexture(media .. bank.halo)
    halo.paint:SetTexCoord(E.UV({0,0,0,uv,uv,0,uv,uv}, config.flip))
    for _, info in ipairs(E.GetStudioLayers(config)) do
        local layer = s.layers[info.id]
        if layer then
            local host = layer.host
            local pending = entry.placementLayerID == info.id and entry.pendingPlacement
            local alpha = (pending and pending.trailOpacity or info.settings.opacity) / 100
            local travel = data.travel[info.id] or .012
            -- Keep the desktop's existing 1.2%-of-host-height translation formula.
            -- Only the shard host is shorter; the sprites still use the full crest coordinates.
            local motionHeight = height * travel / .012
            local amplitude = layer.hover and animate and motionHeight*.012 or 0
            host:SetSize(width, motionHeight)
            host:ClearAllPoints()
            host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -amplitude)
            host:SetFrameLevel(entry.frame:GetFrameLevel() + info.rank*2)
            host:SetAlpha(alpha)
            host:SetShown(info.settings.enabled ~= false and alpha > 0)
            if layer.hover then
                layer.animate = animate
                layer.legs[1]:SetOffset(0, amplitude*2)
                layer.legs[2]:SetOffset(0, -amplitude*2)
                entry.artworkLayers[info.id] = layer
            end
            for i, tile in ipairs(bank.tiles[info.id] or {}) do
                local paint = layer.textures[i] or texture(host)
                layer.textures[i] = paint
                placeTile(s, paint, host, tile)
            end
        end
    end
    s.contactHost:SetFrameLevel(halo.host:GetFrameLevel()+1)
    if layoutChanged then
        local back = bank.tiles.coldSnapBack
        if back then placeTile(s, s.backBlur, s.layers.frostColdSnap.host, back[1]) end
        s.backBlur:SetShown(back ~= nil)
        for _, patches in pairs(s.contacts) do
            for _, patch in ipairs(patches) do patch.tile = nil end
        end
    end
    s.paint = s.layers.artwork.textures[1]
    setVisibility(s)
end

local apply = E.ApplyStudioArtwork
function E.ApplyStudioArtwork(entry, config)
    apply(entry, config)
    local s = entry.frostHalo
    local root = entry.mageReboot
    local bank = config.art == "mageFrost" and root and root.enabled and data.banks[tostring(root.textureSize)]
    if not bank then
        if s and s.active then
            s.active = false
            stop(s)
            for _, layer in pairs(s.layers) do layer.host:Hide() end
            s.root.texture:Show()
        end
        return
    end
    if not s then
        s = create(root)
        entry.frostHalo = s
    end
    s.active = true
    root.texture:Hide()
    root.host:SetAlpha(entry.alpha)
    present(s, entry, config, bank)
end

local stopCrest, playCrest = E.StopMageReboot, E.PlayMageReboot
function E.StopMageReboot(entry)
    if entry.frostHalo then stop(entry.frostHalo) end
    stopCrest(entry)
end

function E.PlayMageReboot(entry)
    playCrest(entry)
    local s = entry.frostHalo
    if s and s.root.art == "mageFrost" then setVisibility(s) end
end

local _, E = ...
E.ArtworkChannelPlusMedia = E.ArtworkChannelPlusMedia or {}
E.ArtworkChannelPlusMedia["MAGE:frost"] = "Interface\\AddOns\\Epicast\\StudioCrests\\Frost-v16-8aed5e767b64a5532f2570b00fd78a6a95fb370120b18a37a91c54140ec2c9fa\\"
