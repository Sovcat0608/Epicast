local _, E = ...
local media = "Interface\\AddOns\\Epicast\\StudioCrests\\DruidBalance-v16-1bd2290f4b636d3e1e3d195a9af945ab57406a8f7959ee121fad8246e9f15239\\"
local seals = E.BalanceSealAtlases
local intro, hold, outro = .5, 3, .5
local defaultPeriod = 32
local ids = {"nightSeal", "natureSeal"}
local descriptors = {
    {id="nightSeal", name="EC-NightSeal"},
    {id="natureSeal", name="EC-NatureSeal"},
}
for _, descriptor in ipairs(descriptors) do
    descriptor.libraryOnly = true
    descriptor.previewSeconds = intro + hold + outro
    descriptor.defaults = {
        enabled=true, size=100, opacity=100, x=0, y=0, angle=0, depth=0,
        rotate=true, period=defaultPeriod, reverse=false, playStart=true, hold=true, playEnd=true,
    }
end

-- Registration is deferred until the library reads it. Legacy packs append
-- or replace their own lists during loading, before this read occurs.
local readDefinitions = E.ReadCustomEffectDefinitions
function E.ReadCustomEffectDefinitions()
    E.DesktopCustomEffects = E.DesktopCustomEffects or {}
    local registry = E.DesktopCustomEffects
    for class, spec in pairs(E.ClassSpecs) do
        for _, slot in ipairs(spec.slots) do
            local key = class..":"..slot[1]
            local entries = registry[key] or {}
            registry[key] = entries
            for _, descriptor in ipairs(descriptors) do
                local present = false
                for _, effect in ipairs(entries) do
                    if effect.id==descriptor.id then present=true;break end
                end
                if not present then entries[#entries+1]=descriptor end
            end
        end
    end
    return readDefinitions()
end

local function eased(t)
    t=math.max(0,math.min(1,t))
    return t*t*(3-2*t)
end

local function seconds(clock, now)
    return (clock.elapsed + (clock.at and math.max(0,now-clock.at) or 0))%clock.period
end

local corners={{-1,1},{-1,-1},{1,1},{1,-1}}
local function orientation(art,angle)
    if Desktop or not art.SetVertexOffset then return end
    local w,h=art:GetSize()
    local state=art.sealOrientation
    if state and state[1]==angle and state[2]==w and state[3]==h then return end
    local a=-math.rad(angle)
    local c,s=math.cos(a),math.sin(a)
    for i,corner in ipairs(corners) do
        local x,y=corner[1]*w/2,corner[2]*h/2
        art:SetVertexOffset(i,c*x-s*y-x,s*x+c*y-y)
    end
    art.sealOrientation={angle,w,h}
end

local function stop(frame)
    frame.spin:Stop()
    frame.clock.at,frame.clock.elapsed=nil,0
    frame.art.epicastDesktopRotation=nil
    frame.started,frame.releasing,frame.releaseFrom=nil,nil,nil
    frame.envelope,frame.cel=0,1
    frame:Hide()
end

local function spin(frame,settings,flip,now)
    local clock=frame.clock
    local side=flip and -1 or 1
    if settings.reverse then side=-side end
    local period=settings.period or defaultPeriod
    local rotate=settings.rotate~=false
    if period~=clock.period or clock.direction~=side or rotate~=(clock.at~=nil) then
        local elapsed=seconds(clock,now)
        local phase=elapsed/clock.period*clock.direction/side
        frame.spin:Stop()
        clock.elapsed,clock.period,clock.direction=phase%1*period,period,side
        frame.turn:SetDuration(period)
        frame.turn:SetDegrees(-360*side)
        if rotate then
            clock.at=now
            frame.spin:Play(false,clock.elapsed)
        else
            clock.at=nil
        end
    end
    local angle=settings.angle or 0
    if Desktop then
        frame.art.epicastDesktopRotation={
            pivot={.5,.5},period=clock.period,direction=clock.direction,angle=angle,
            elapsed=clock.elapsed,startedAt=clock.at,
        }
    else
        orientation(frame.art,angle+(clock.at and 0 or 360*clock.elapsed/clock.period*clock.direction))
    end
end

local function setCel(frame,index)
    local bank=frame.bank
    local tile=bank.frames[frame.effectID][index]
    local art=frame.art
    local page=bank.pages[tile[1]]
    if art.sealPage~=page then
        art:SetTexture(media..page)
        art.sealPage=page
    end
    if art.sealTile~=tile or art.sealFlip~=frame.flip then
        local _,l,t,r,b=unpack(tile)
        art:SetTexCoord(E.UV({l,t,l,b,r,t,r,b},frame.flip))
        art.sealTile,art.sealFlip=tile,frame.flip
    end
end

local function release(frame,now)
    if not frame.releasing and frame.started then
        frame.releasing,frame.releaseFrom=now,frame.envelope
    end
end

local function tick(frame)
    local now = GetTime()
    local settings = frame.settings
    local age = math.max(0,now-frame.started)
    local rise = settings.playStart==false and 0 or intro
    if frame.library and age>=rise+hold then release(frame,frame.started+rise+hold) end
    if frame.releasing then
        local fade=settings.playEnd==false and 0 or outro
        if fade==0 or now-frame.releasing>=fade then stop(frame);return end
        frame.envelope=frame.releaseFrom*(1-eased((now-frame.releasing)/fade))
    else
        frame.envelope=rise>0 and eased(age/rise) or 1
        local holdAge=math.max(0,age-rise)
        frame.cel=settings.hold==false and 1 or 1+math.floor(holdAge*24+1e-7)%72
    end
    setCel(frame,frame.cel)
    frame.art:SetAlpha(frame.envelope*settings.opacity/100)
end

local function create(canvas,id)
    local frame=CreateFrame("Frame",nil,canvas)
    frame:EnableMouse(false)
    frame.effectID=id
    frame.art=frame:CreateTexture(nil,"ARTWORK")
    frame.art:SetAllPoints(frame)
    frame.art:SetBlendMode("ADD")
    if frame.art.SetBlockingLoadsRequested then frame.art:SetBlockingLoadsRequested(true) end
    if frame.art.SetSnapToPixelGrid then frame.art:SetSnapToPixelGrid(false) end
    if frame.art.SetTexelSnappingBias then frame.art:SetTexelSnappingBias(0) end
    frame.spin=frame.art:CreateAnimationGroup()
    frame.spin:SetLooping("REPEAT")
    frame.turn=frame.spin:CreateAnimation("Rotation")
    frame.turn:SetOrder(1)
    frame.turn:SetDuration(defaultPeriod)
    frame.turn:SetDegrees(-360)
    frame.turn:SetOrigin("CENTER",0,0)
    frame.turn:SetSmoothing("NONE")
    frame.clock={period=defaultPeriod,direction=1,elapsed=0}
    frame:SetScript("OnUpdate",function(self) if self.started then tick(self) end end)
    stop(frame)
    return frame
end

local sizes={192,288,384,480,576,660}
local function bankAt(request)
    for _, size in ipairs(sizes) do
        if request<=size then return seals[size] end
    end
    return seals[sizes[#sizes]]
end

local function draw(target,crest,id,config)
    local owner=target.customEffectOwner or target
    local settings=E.GetCustomEffectSettings(crest,id)
    local frame=target[id]
    if not settings or (not settings.enabled and (not frame or not frame.started)) then
        if frame then stop(frame) end
        return frame
    end
    local root=owner.mageReboot
    if not root or not root.enabled then root=owner.druidSister end
    local host=root and root.enabled and root.host or owner.art
    local w,h=host:GetSize()
    if w<=0 or h<=0 then return frame end
    local canvas=E.GetCustomEffectCanvas(owner,w,h)
    if not frame then
        frame=create(canvas,id)
        target[id]=frame
        if target.preparingEffect then return frame end
    end
    local size=settings.size or 100
    frame.bank=bankAt((root and root.enabled and root.textureSize or 480)*math.max(1,size/100))
    local diameter=math.min(w,h)*.5*size/100*(frame.bank.displayScale or 1)
    frame:SetSize(diameter,diameter)
    frame.art:SetSize(diameter,diameter)
    frame:SetFrameLevel(math.max(0,canvas:GetFrameLevel()+12+2*math.floor(settings.depth or 0)))
    E.AnchorCustomEffect(owner,frame,w,h,w*.5+settings.x*w/660,-h*.5+settings.y*w/660)
    frame.settings,frame.flip,frame.library=settings,E.GetCustomEffectFlip(config.flip),owner.libraryPreview
    local now=GetTime()
    if not frame.started then
        frame.started,frame.cel,frame.envelope=now,1,0
        frame:Show()
    end
    if not settings.enabled then release(frame,now) end
    spin(frame,settings,config.flip,now)
    tick(frame)
    return frame
end

local apply=E.ApplyStudioArtwork
function E.ApplyStudioArtwork(entry,config)
    apply(entry,config)
    local crest=E.GetCrestBakeKey(config)
    if not crest then return end
    -- This pack carries the shared effect once. The existing Balance
    -- texture uses the same verified bytes under the delivery namespace.
    local owner=entry.druidSister
    if crest=="DRUID:balance" and config.art=="druidBalance" and owner and owner.enabled then
        local file=media.."StudioDruidBalanceSize"..owner.textureSize.."Page0.tga"
        if not owner.texture.GetTexture or owner.texture:GetTexture()~=file then owner.texture:SetTexture(file) end
    end
    for _,id in ipairs(ids) do
        E.RenderCustomEffectInstances(entry,crest,id,function(target)
            return draw(target,crest,id,config)
        end)
    end
end



local _, E = ...
E.ArtworkChannelPlusMedia = E.ArtworkChannelPlusMedia or {}
E.ArtworkChannelPlusMedia["DRUID:balance"] = "Interface\\AddOns\\Epicast\\StudioCrests\\DruidBalance-v16-1bd2290f4b636d3e1e3d195a9af945ab57406a8f7959ee121fad8246e9f15239\\"
