-- Native FrameXML segment hosts use the same sinusoidal lift as RestorationSegments.lua.
local _, E = ...
local data = E.ArcaneFloatData
local media = "Interface\\AddOns\\Epicast\\StudioCrests\\Arcane-v16-bbac5ff74dfbee59cb58082f2eaed7957405791f4dc33402520c602e7096fa69\\"
local sealDefaults = {
    enabled=true, size=100, opacity=100, x=0, y=0, angle=0,
    period=data.seal.period, rotate=true, reverse=false, depth=0,
}
    E.DesktopCustomEffects = E.DesktopCustomEffects or {}
    E.DesktopCustomEffects["MAGE:arcane"] = {
        {id="arcaneSeal",name="Arcane Orbit Seal",defaults=sealDefaults},
    }

local definitions = {
    {id="artwork", name="Lectern and arches"},
    {id="bannerFloaters", name="Banner side floaters"},
    {id="arcaneBody", name="Book, crown and banners"},
    {id="scroll", name="Scroll assembly"},
    {id="kirinTor", name="Kirin Tor emblem"},
    {id="shards", name="Broken arcane shards"},
    {id="shoulderFloaters", name="Shoulder floaters"},
}
for _, layer in ipairs(definitions) do
    local track = data.motion[layer.id]
    layer.motion = layer.motion or (track and ("Vertical float · "..track[1].." s") or
        (layer.id=="arcaneBody" and "Banner waves" or "Crest hover"))
end
local getLayers = E.GetArtworkLayers
function E.GetArtworkLayers(config)
    if config.art == "mageArcane" then return definitions end
    return getLayers(config)
end
-- Expand a previous single-artwork bake in memory. Its spell rows and the
-- original artwork slot's relative position survive the transition.
local getState = E.GetStudioState
function E.GetStudioState(config)
    local state = getState(config)
    if config.art ~= "mageArcane" then return state end
    local expanded = E.Copy(state)
    if state.artwork.kirinTor then
        if not state.artwork.arcaneSeal then return state end
        for i, id in ipairs(expanded.order) do
            if id == "arcaneSeal" then table.remove(expanded.order,i); break end
        end
        expanded.artwork.arcaneSeal = nil
        if expanded.artworkBindings then expanded.artworkBindings.arcaneSeal = nil end
        return expanded
    end
    local index = 0
    for i, id in ipairs(expanded.order) do if id == "artwork" then index = i; break end end
    local inherited = expanded.artwork.artwork or {enabled=true,opacity=100}
    if index==0 then
        table.insert(expanded.order,1,"artwork")
        index=1
    end
    for i=2,#definitions do
        local id = definitions[i].id
        table.insert(expanded.order, index+i-1, id)
        expanded.artwork[id] = E.Copy(inherited)
    end
    return expanded
end

local function pauseSeal(seal)
    if not seal or not seal.clock.startedAt then return end
    local clock = seal.clock
    clock.elapsed = (clock.elapsed + math.max(0,GetTime()-clock.startedAt)) % clock.period
    clock.startedAt = nil
    seal.spin:Stop()
end

local function pause(c)
    for _,seal in ipairs(c.seals) do pauseSeal(seal) end
    if c.started then
        c.elapsed = c.elapsed + GetTime() - c.started
        c.started = nil
    end
    c.driver:Hide()
end

local function contactPose(dy)
    local offsets = data.contactOffsets
    for i=1,#offsets-1 do
        if dy < (offsets[i]+offsets[i+1])*.5 then return i end
    end
    return #offsets
end

local function scrollContacts(layer)
    local offsets = data.contactOffsets
    if not layer.visible then return #offsets+1 end
    local y = layer.dy
    if y <= offsets[1] then return 1 end
    for i = 1, #offsets-1 do
        if y < offsets[i+1] then
            local step = math.floor((y-offsets[i])/(offsets[i+1]-offsets[i])*8+.5)
            if step == 0 then return i end
            if step == 8 then return i+1 end
            return #offsets+1+(i-1)*7+step
        end
    end
    return #offsets
end

local tau=2*math.pi
local function nearest(values,sample)
    for i=1,#values-1 do
        if sample < (values[i]+values[i+1])*.5 then return i end
    end
    return #values
end

local function glowLevel(kind,i,t)
    local period,phase,base,depth=6.6,.8,.08,.27
    if kind=="scroll" then period,phase,base,depth=7.9,2.4,.04,.32
    elseif kind=="shoulder" then period,phase,base,depth=7.5,1.3,.04,.31
    elseif kind=="shard" then period,phase,base,depth=6.3+(i-1)*.6,(i-1)*.92,.07,.30 end
    return base+depth*(.5-.5*math.cos(tau*(t+phase)/period))
end

local shardPeriods={5.4,6.5,5.9,7.1}
local baseTilts={1.05,1.5,1.2,1.65}
local function shardMotion(i,t)
    local phase=i-1
    local period=shardPeriods[i]
    local dx=(1.65+phase*.4)*math.sin(tau*(t+phase*.92)/(period+.65))
    local dy=(2.4+phase*.52)*math.sin(tau*(t+phase*.69)/period)
    local tilt=baseTilts[i]*math.sin(tau*(t+phase*.81)/period)
    local age=(t-.6-phase*1.35)%5.4
    if age>=.78 then return dx,dy,tilt,false end
    local ramp=math.sin(math.pi*math.min(age/.13,1)*.5)^2*math.exp(-2.4*age)
    ramp=ramp*math.cos(math.pi*math.min(1,math.max(0,(age-.56)/.22))*.5)^2
    local phaseShake=tau*4.1*age
    local force=math.sin(phaseShake)*ramp*(i<3 and 1 or -1)
    return dx+9*force,dy+2.5*math.sin(phaseShake+.4)*ramp,tilt+5.2*force,true
end

local function drawSealIdle(c, seal, t)
    local idle = data.seal.idle
    local index = c.animate and 1 + math.floor(t * idle.fps) % #seal.bank.tiles or 1
    local tile = seal.bank.tiles[index]
    if seal.tile == tile then return end
    seal.tile = tile
    local page, u, v, r, b = unpack(tile)
    if seal.page ~= page then
        seal.page = page
        seal.texture:SetTexture(media.."ArcaneFloatSize"..c.size.."Page"..page..".tga")
    end
    seal.texture:SetTexCoord(E.UV({u,v,u,b,r,v,r,b},seal.mirror))
end

local function draw(c)
    local t = c.elapsed + (c.started and GetTime()-c.started or 0)
    local w,h = c.root.host:GetWidth(),c.root.host:GetHeight()
    for id,track in pairs(data.motion) do
        local layer = c.groups[id]
        -- Source coordinates grow downward. Lift in FrameXML grows upward.
        layer.dy = c.animate and math.sin(2*math.pi*(t+track[3])/track[1])*track[2] or 0
        layer.lift = -layer.dy*h/1268
        if id=="scroll" or id=="kirinTor" then
            layer.contactPose = layer.visible and contactPose(layer.dy) or #data.contactOffsets+1
        end
    end
    local gaze=c.animate and 5.5*math.sin(tau*(t+.35)/8.1) or 0
    c.irisGaze=gaze
    local irisTile=nearest(data.irisGazes,gaze)
    local eye=c.groups.kirinTor
    local eyeContact=eye.visible and ((eye.contactPose-1)*#data.irisShadowGazes+
                         nearest(data.irisShadowGazes,gaze)) or #data.contactOffsets*#data.irisShadowGazes+1
    local shards=c.shardPoses
    for i=1,4 do
        local x,y,tilt,shake=0,0,0,false
        if c.animate then x,y,tilt,shake=shardMotion(i,t) end
        local pose=shards[i]
        pose.x,pose.y,pose.tilt,pose.shaking=x,y,tilt,shake
    end
    local scrollFirst,scrollNext,scrollWeight=scrollContacts(c.groups.scroll)
    c.scrollContact={scrollFirst,scrollNext,scrollWeight}
    for i,part in ipairs(c.bank) do
        local sprite = c.sprites[i]
        local layer = c.groups[part.group]
        local index = 1
        if part.receiverFor=="iris" then
            index=eyeContact
        elseif part.receiverFor=="scroll" then
            index=scrollFirst
        elseif part.receiverFor then
            index=c.groups[part.receiverFor].contactPose
        elseif part.shard then
            index=nearest(data.angles,shards[part.shard].tilt)
        elseif part.clip=="iris" then
            index=irisTile
        elseif part.clip and c.animate then
            local clip=data.clips[part.clip]
            index=1+math.floor(((t+clip.phase)%clip.period)/clip.period*#part.tiles)
        end
        if sprite.tile ~= part.tiles[index] then
            local tile = part.tiles[index]
            sprite.tile = tile
            local page,u,v,r,b = unpack(tile)
            if sprite.page~=page then
                sprite.page=page
                sprite.texture:SetTexture(media.."ArcaneFloatSize"..c.size.."Page"..page..".tga")
            end
            sprite.texture:SetTexCoord(E.UV({u,v,u,b,r,v,r,b},c.flip))
        end
        if part.receiverFor=="scroll" then
            if scrollNext and scrollWeight>0 then
                local page,u,v,r,b=unpack(part.tiles[scrollNext])
                if c.flip then u,r=r,u end
                sprite.texture.epicastDesktopTextureBlend={
                    file="ArcaneFloatSize"..c.size.."Page"..page..".tga",
                    uv={u,v,r,b},weight=scrollWeight,
                }
            else
                sprite.texture.epicastDesktopTextureBlend=nil
            end
        end
        local dx,dy=0,layer.lift or 0
        if part.shard then
            local pose=shards[part.shard]
            dx=(c.flip and -pose.x or pose.x)*w/1268
            dy=dy-pose.y*h/1268
        end
        if sprite.lift~=dy or sprite.shift~=dx then
            sprite.frame:SetPoint("TOPLEFT",c.root.host,"TOPLEFT",sprite.x+dx,sprite.y+dy)
            sprite.lift,sprite.shift=dy,dx
        end
        if part.glow then
            local opacity=c.animate and layer.opacity*glowLevel(part.glow,part.shard,t) or 0
            if sprite.glowOpacity~=opacity then
                sprite.frame:SetAlpha(opacity)
                sprite.glowOpacity=opacity
            end
        end
    end
    for _,seal in ipairs(c.seals) do
        if seal.frame:IsVisible() then drawSealIdle(c,seal,GetTime()-(seal.idleStarted or GetTime())) end
    end
end

local function makeSprite(root)
    local frame = CreateFrame("Frame",nil,root.host)
    frame:EnableMouse(false)
    local texture = frame:CreateTexture(nil,"ARTWORK")
    texture:SetAllPoints(frame)
    if texture.SetBlockingLoadsRequested then texture:SetBlockingLoadsRequested(true) end
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return {frame=frame,texture=texture}
end

local function makeSeal(root)
    local seal = makeSprite(root)
    seal.texture:SetBlendMode("ADD")
    seal.spin = seal.texture:CreateAnimationGroup()
    seal.spin:SetLooping("REPEAT")
    seal.rotation = seal.spin:CreateAnimation("Rotation")
    seal.rotation:SetOrder(1)
    seal.rotation:SetDuration(data.seal.period)
    seal.rotation:SetSmoothing("NONE")
    seal.rotation:SetOrigin("CENTER",0,0)
    seal.clock = {pivot={.5,.5}, period=data.seal.period, elapsed=0}
    seal.frame:Hide()
    return seal
end

local function updateSealSpin(c, seal)
    local settings, clock = seal.settings, seal.clock
    if settings.rotate and c.animate and c.started and seal.frame:IsVisible() then
        if not clock.startedAt then
            clock.startedAt = GetTime()
            seal.spin:Play(false, clock.elapsed)
        end
    else
        pauseSeal(seal)
    end
    if Desktop and (clock.startedAt or settings.angle~=0) then
        seal.texture.epicastDesktopRotation = {
            pivot=clock.pivot, period=clock.period, direction=clock.direction,
            startedAt=clock.startedAt,
            elapsed=(clock.startedAt and clock.elapsed or 0)+settings.angle*clock.period/(360*clock.direction),
        }
    else
        seal.texture.epicastDesktopRotation = nil
    end
end

local function customSealSettings()
    local edited = E.GetLegacyCustomEffectSettings("MAGE:arcane","arcaneSeal")
    if type(edited)~="table" then return sealDefaults end
    return {
        enabled=edited.enabled~=false, rotate=edited.rotate~=false, reverse=edited.reverse==true,
        size=E.Number(edited.size,100,5,500), opacity=E.Number(edited.opacity,100,0,100),
        x=E.Number(edited.x,0,-1268,1268), y=E.Number(edited.y,0,-1268,1268),
        angle=E.Number(edited.angle,0,-360,360), period=E.Number(edited.period,32,1,180),
        depth=math.floor(E.Number(edited.depth,0,-32,32)),
    }
end

local function attachSeal(entry, c, seal, w, h)
    local spec = data.seal
    local settings = customSealSettings()
    seal.settings = settings
    local scroll = c.groups.scroll
    seal.bank = spec.idle.banks[tostring(c.size)]
    seal.tile,seal.page = nil,nil
    local l,t,r,b = unpack(seal.bank.rect)
    seal.mirror=E.GetCustomEffectFlip(c.flip)
    if seal.mirror then l,r=1-r,1-l end
    local x, y = unpack(spec.center)
    if c.flip then x=1268-x end
    x, y = x+settings.x, y-settings.y
    local direction = c.flip and -1 or 1
    if settings.reverse then direction=-direction end
    local clock = seal.clock
    local width = spec.width*settings.size/100
    local fullW,fullH = width*w/1268,width*h/1268
    local offsetX,offsetY = ((l+r)*.5-.5)*fullW,(.5-(t+b)*.5)*fullH
    if clock.direction ~= direction or clock.period ~= settings.period or
        clock.offsetX ~= offsetX or clock.offsetY ~= offsetY then
        pauseSeal(seal)
        local phase = clock.elapsed/clock.period
        if clock.direction and clock.direction~=direction and seal.flip==c.flip then phase=(-phase)%1 end
        clock.direction, clock.period, clock.elapsed = direction, settings.period, phase*settings.period
        clock.offsetX,clock.offsetY = offsetX,offsetY
        seal.rotation:SetDuration(settings.period)
        seal.rotation:SetDegrees(-360*direction)
        -- Atlas frames have a common tight crop. Spin around the original full-canvas center.
        seal.rotation:SetOrigin("CENTER",-offsetX,-offsetY)
    end
    clock.pivot = {(.5-l)/(r-l),(.5-t)/(b-t)}
    seal.flip=c.flip
    seal.frame:SetFrameLevel(math.max(0,scroll.level+1+2*settings.depth))
    seal.frame:SetSize((r-l)*fullW, (b-t)*fullH)
    seal.frame:SetAlpha(settings.opacity/100)
    seal.wanted = settings.enabled and settings.opacity>0
    E.AnchorCustomEffect(entry,seal.frame,w,h,x*w/1268+offsetX,-y*h/1268+offsetY)
end

local function resume(c)
    for _,seal in ipairs(c.seals) do
        seal.frame:SetShown(seal.wanted and c.root.host:IsVisible())
    end
    if c.animate and c.root.host:IsVisible() then
        c.started = c.started or GetTime()
        c.driver:Show()
    else
        pause(c)
    end
    draw(c)
    for _,seal in ipairs(c.seals) do updateSealSpin(c,seal) end
end

local apply = E.ApplyStudioArtwork
function E.ApplyStudioArtwork(entry,config)
    local c = entry.arcaneFloat
    if c and config.art ~= "mageArcane" then
        pause(c)
        c.active = false
        for _,sprite in ipairs(c.sprites) do sprite.frame:Hide() end
        for _,sprite in ipairs(c.preload) do sprite.frame:Hide() end
        for _,seal in ipairs(c.seals) do seal.frame:Hide() end
        c.root.texture:Show()
    end
    apply(entry,config)
    if config.art ~= "mageArcane" then return end
    local root = entry.mageReboot
    if not root or not root.enabled then return end
    local bank = data.banks[tostring(root.textureSize)]
    if not bank then return end
    if not c then
        c = {root=root,driver=CreateFrame("Frame",nil,root.host),elapsed=0,groups={},sprites={},
             preload={},shardPoses={{},{},{},{}}}
        entry.arcaneFloat = c
        c.driver:SetScript("OnUpdate",function() draw(c) end)
        for _,def in ipairs(definitions) do c.groups[def.id]={} end
        c.groups.foundation,c.groups.body = c.groups.artwork,c.groups.arcaneBody
        c.seals = {}
    end
    c.active,c.bank,c.size,c.flip,c.animate = true,bank,root.textureSize,config.flip,root.animate
    root.texture:Hide()
    root.host:SetAlpha(entry.alpha)
    for _,info in ipairs(E.GetStudioLayers(config)) do
        if info.kind=="artwork" then
            local layer = c.groups[info.id]
            local pending = entry.placementLayerID==info.id and entry.pendingPlacement
            layer.opacity = (pending and pending.trailOpacity or info.settings.opacity)/100
            layer.visible = info.settings.enabled~=false and layer.opacity>0
            layer.level = entry.frame:GetFrameLevel()+info.rank*2
            if info.id ~= "artwork" then
                layer.motion=layer.motion or {root=root,segment=layer}
                layer.motion.animate = c.animate
                entry.artworkLayers[info.id] = layer.motion
            end
        end
    end
    local w,h = root.host:GetWidth(),root.host:GetHeight()
    for i,part in ipairs(bank) do
        local sprite = c.sprites[i] or makeSprite(root)
        c.sprites[i] = sprite
        local l,t,r,b = unpack(part.rect)
        sprite.x = (c.flip and c.size-r or l)*w/c.size
        sprite.y = -t*h/c.size
        sprite.tile,sprite.lift,sprite.shift,sprite.page,sprite.glowOpacity=nil,nil,nil,nil,nil
        sprite.texture.epicastDesktopTextureBlend=nil
        sprite.frame:ClearAllPoints()
        sprite.frame:SetSize((r-l)*w/c.size,(b-t)*h/c.size)
        local layer=c.groups[part.group]
        sprite.frame:SetFrameLevel(layer.level)
        sprite.frame:SetAlpha(layer.opacity)
        sprite.frame:SetShown(layer.visible)
    end
    E.RenderCustomEffectInstances(entry,"MAGE:arcane","arcaneSeal",function(target)
        local settings = E.GetCustomEffectSettings("MAGE:arcane","arcaneSeal")
        local seal = target.arcaneSeal
        if not seal and (not settings or not settings.enabled) then return end
        if not seal then
            seal = makeSeal(root)
            target.arcaneSeal=seal
            if target==entry then c.seal=seal end
            c.seals[#c.seals+1]=seal
        end
        local wasWanted=seal.wanted
        attachSeal(target,c,seal,w,h)
        if seal.wanted and not wasWanted then
            pauseSeal(seal)
            seal.clock.elapsed=0
            seal.idleStarted=GetTime()
        end
        seal.frame:SetShown(seal.wanted and c.root.host:IsVisible())
        if seal.frame:IsVisible() then drawSealIdle(c,seal,GetTime()-seal.idleStarted) end
        updateSealSpin(c,seal)
        return seal.frame
    end)
    for i=#bank+1,#c.sprites do c.sprites[i].frame:Hide() end
    -- The existing viewport requests visible texture rows. Prime all pages
    -- for this selected bank with one-pixel instances outside the playfield.
    local pages=data.pages[tostring(c.size)]
    for i,page in ipairs(pages) do
        local sprite=c.preload[i] or makeSprite(root)
        c.preload[i]=sprite
        sprite.frame:SetSize(1,1)
        sprite.frame:SetPoint("TOPLEFT",root.host,"TOPLEFT",-10000,10000)
        sprite.texture:SetTexture(media.."ArcaneFloatSize"..c.size.."Page"..page..".tga")
        sprite.texture:SetTexCoord(E.UV({0,0,0,0,0,0,0,0},false))
        sprite.frame:Show()
    end
    for i=#pages+1,#c.preload do c.preload[i].frame:Hide() end
    resume(c)
end

local stop,play = E.StopMageReboot,E.PlayMageReboot
function E.StopMageReboot(entry)
    if entry.arcaneFloat then
        for _,seal in ipairs(entry.arcaneFloat.seals) do seal.frame:Hide() end
        pause(entry.arcaneFloat)
    end
    stop(entry)
end
function E.PlayMageReboot(entry)
    play(entry)
    local c = entry.arcaneFloat
    if c and c.active and c.root.art=="mageArcane" and c.root.enabled then resume(c) end
end

local _, E = ...
E.ArtworkChannelPlusMedia = E.ArtworkChannelPlusMedia or {}
E.ArtworkChannelPlusMedia["MAGE:arcane"] = "Interface\\AddOns\\Epicast\\StudioCrests\\Arcane-v16-bbac5ff74dfbee59cb58082f2eaed7957405791f4dc33402520c602e7096fa69\\"
