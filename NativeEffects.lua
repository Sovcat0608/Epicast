local _,E=...
local baseHalfFovTangent = 3/8
local renderPadding = 96 -- UI units per side, within a 90-degree field of view
function E.StopNativeSmoke(entry)
    if E.StopEffectMotion then E.StopEffectMotion(entry)end
    local state = entry.nativeSmoke
    if not state then return end
    for _, slot in ipairs(state.slots) do slot.scene:Hide() end
end
local function fail(entry, reason, timedOut)
    entry.nativeSmoke.status = "unavailable"
    entry.nativeSmoke.reason = reason
    entry.nativeSmoke.timedOut = timedOut == true
    entry.nativeActive = false
    E.StopNativeSmoke(entry)
end
local function loaded(state)
    local profile=state.profile
    for _, slot in ipairs(state.slots) do
        if not slot.actor:IsLoaded() then return false end
        if profile and slot.actor.GetModelFileID and slot.actor:GetModelFileID()~=profile.fileID then return false end
    end
    return #state.slots == 1
end
local function requestRefresh(entry)
    if not entry.effectsEnabled or not entry.nativeWanted or not entry.frame:IsVisible() then return end
    if InCombatLockdown() then E.pending=true;return end
    -- Apply reads the current draft/saved configuration, never a stale snapshot.
    if entry.preview and E.ScheduleStudioPreview then E.ScheduleStudioPreview()else E.Schedule(entry.side)end
end
local function watchLoad(entry,state,slot,profile)
    local generation=state.generation
    slot.needsAnimation=true
    slot.notifiedGeneration=nil
    slot.actor.epicastOnModelLoaded=function()
        if entry.nativeSmoke~=state or state.generation~=generation or slot.notifiedGeneration==generation then return end
        if state.status=="unavailable" and not state.timedOut then return end
        if not slot.actor:IsLoaded() then return end
        if slot.actor.GetModelFileID and slot.actor:GetModelFileID()~=profile.fileID then return end
        slot.notifiedGeneration=generation
        slot.needsAnimation=true
        state.loadDirty=true
        -- The event can fire during SetModelByFileID, after an optimistic
        -- IsLoaded result, or after the bounded poll window has expired.
        -- Defer geometry/alpha/animation to the normal safe Apply path.
        requestRefresh(entry)
    end
end
local function poll(entry)
    local state = entry.nativeSmoke
    if not state or state.status ~= "loading" or state.polling then return end
    state.polling = true
    local generation = state.generation
    C_Timer.After(0.75, function()
        if generation ~= state.generation then return end
        state.polling = false
        if state.status ~= "loading" or not entry.effectsEnabled or not entry.nativeWanted then return end
        if not entry.frame:IsVisible() then return end
        if InCombatLockdown() then E.pending = true; return end
        state.attempts = state.attempts + 1
        local ok, ready = pcall(loaded, state)
        if not ok then fail(entry, "model readiness check failed")
        elseif ready then state.status = "ready"; state.reason=nil; state.timedOut=false
        elseif state.attempts >= 8 then
            if state.retries < 1 then
                -- One extra loading window for cold caches/slow storage. Keep
                -- the requested model intact; restarting it can delay loading.
                state.retries=state.retries+1; state.attempts=0
                poll(entry); return
            end
            fail(entry, "model did not load within twelve visible seconds", true)
        else poll(entry); return end
        if entry.preview and E.ScheduleStudioPreview then E.ScheduleStudioPreview()else E.Schedule(entry.side)end
    end)
end
function E.PlayNativeSmoke(entry)
    local state = entry.nativeSmoke
    if not state or not entry.effectsEnabled or not entry.nativeWanted or not entry.frame:IsVisible() then return end
    if state.loadDirty then requestRefresh(entry);return end
    if state.status == "unavailable" then
        -- A late model can become ready after the bounded polling has ended.
        -- OnShow requests the normal Apply path so alpha/visibility are refreshed.
        if state.timedOut then
            if InCombatLockdown() then E.pending=true; return end
            local ok,ready=pcall(loaded,state)
            if ok and ready then requestRefresh(entry) end
        end
        return
    end
    if state.status == "loading" then poll(entry) end
    if entry.castBinding and not entry.castVisible then E.StopNativeSmoke(entry);return end
    for _, slot in ipairs(state.slots) do slot.scene:Show() end
    if E.PlayEffectMotion then E.PlayEffectMotion(entry)end
end
local function create(entry)
    local state = {slots = {}, status = "loading", attempts = 0, retries = 0, generation = 0}
    entry.nativeSmoke = state
    for _, eye in ipairs(entry.emitters or E.EffectEmitters) do
        local scene = CreateFrame("ModelScene", nil, entry.frame)
        local slot = {scene = scene, eye = eye}
        table.insert(state.slots, slot)
        scene:Hide(); scene:SetAlpha(0); scene:EnableMouse(false)
        -- Particle viewports intentionally overlap within a cap and across
        -- caps. Opt in before loading; visible artwork bounds are much smaller
        -- than these scenes. See Blizzard ModelSceneMixin:OnLoad.
        if scene.SetAllowOverlappedModels then scene:SetAllowOverlappedModels(true) end
        scene:SetFrameLevel(entry.frame:GetFrameLevel()+1)
        scene:SetDrawLayer("OVERLAY")
        scene:SetCameraNearClip(0.01); scene:SetCameraFarClip(100)
        if scene.SetViewInsets then scene:SetViewInsets(0,0,0,0)end
        if scene.SetViewTranslation then scene:SetViewTranslation(0,0)end
        scene:SetLightAmbientColor(1,1,1); scene:SetLightDiffuseColor(0,0,0)
        local actor = scene:CreateActor(nil, "EpicastSmokeActorTemplate")
        slot.actor = actor
        if not actor or not actor.IsLoaded then error("native actor API unavailable") end
        actor:SetScale(1); actor:SetPitch(0); actor:SetYaw(0); actor:SetRoll(0); actor:Show()
    end
    return state
end
function E.UpdateNativeEffectAlpha(entry, intensity)
    local state = entry.nativeSmoke
    if not state then return end
    local alpha = 0
    if entry.nativeWanted and state.status == "ready" then
        alpha = entry.alpha * state.profile.opacity * entry.resourceOpacity * (intensity or 1)
    end
    for _, slot in ipairs(state.slots) do
        slot.scene:SetAlpha(alpha)
    end
end
function E.UpdateNativeSmoke(entry, config)
    if not entry.nativeWanted then return false end
    if InCombatLockdown() then E.pending = true; return false end
    local p=entry.libraryProfile;if not p then return false end
    local id="library:"..p.fileID..":"..p.animation
    local ok, result = pcall(function()
        local state = entry.nativeSmoke or create(entry)
        state.profile=p
        if state.profileID ~= id then
            -- Reuse the same scenes/actors and invalidate callbacks for the old selection.
            state.profileID = id
            state.generation = state.generation+1
            state.status, state.reason, state.attempts, state.polling = "loading", nil, 0, false
            state.retries=0; state.timedOut=false
            state.loadDirty=false
            for _, slot in ipairs(state.slots) do
                slot.scene:Hide(); slot.scene:SetAlpha(0)
                watchLoad(entry,state,slot,p)
                slot.actor:ClearModel()
                if not slot.actor:SetModelByFileID(p.fileID) then error("client rejected model " .. p.fileID) end
            end
        end
        -- Consume a notification even when this Apply cannot recover a failed
        -- model, so Play cannot queue an unbounded sequence of zero-time work.
        state.loadDirty=false
        if state.status=="unavailable" and not state.timedOut then E.StopNativeSmoke(entry);return false end
        local ready=loaded(state)
        if state.status=="unavailable" and not ready then E.StopNativeSmoke(entry);return false end
        if ready then
            state.status="ready"; state.reason=nil; state.timedOut=false
        elseif state.status=="ready" then
            -- A recycled actor can lose readiness after reporting a cached
            -- model ready. Resume bounded polling without reloading that model.
            state.status="loading";state.attempts=0;state.retries=0
            for _,slot in ipairs(state.slots) do slot.needsAnimation=true end
        end
        local width, height = entry.art:GetSize()
        local angle = math.rad(config.trailAngle or 14)
        local sine, cosine = math.sin(angle), math.cos(angle)
        for _, slot in ipairs(state.slots) do
            local frontLevel=8
            slot.scene:SetFrameLevel(entry.frame:GetFrameLevel()+(entry.libraryLevel or (config.effectLayer=="back" and 1 or frontLevel)))
            -- Reset pooled scenes to native colour unless this profile opts out.
            if slot.scene.SetDesaturation then
                slot.scene:SetDesaturation(p.desaturation or 0)
            end
            local x, y, direction = E.EffectAnchor(slot.eye, width, height, config)
            local artScale = (width/150)*slot.eye.scale
            local projectionSize = 576*artScale*(config.trailSize or 100)/100
            local pixelsPerUnit = projectionSize/12
            -- Add render room without changing projected size at any depth:
            -- viewport height and tan(half FOV) grow by the same ratio.
            local renderSize = math.min(projectionSize+2*renderPadding,projectionSize/baseHalfFovTangent)
            local halfFovTangent = baseHalfFovTangent*renderSize/projectionSize
            slot.scene:SetCameraFieldOfView(2*math.atan(halfFovTangent))
            -- Roll the camera instead of trusting each asset's world-space particles
            -- to follow actor pitch. Reverse the viewing side for a true mirrored view.
            local rx, rz, ux, uz = direction*sine, direction*cosine, -cosine, sine
            slot.scene:SetCameraPosition(0, -direction*8, 0)
            slot.scene:SetCameraOrientationByAxisVectors(0,direction,0, rx,0,rz, ux,0,uz)
            if p.cameraAxis=="X" then
                slot.scene:SetCameraPosition(-direction*8,0,0)
                slot.scene:SetCameraOrientationByAxisVectors(direction,0,0,
                    0,-direction*sine,direction*cosine,0,cosine,sine)
            end
            if p.cameraElevation then
                local elevation=math.rad(p.cameraElevation)
                local se,ce=math.sin(elevation),math.cos(elevation)
                slot.scene:SetCameraPosition(0,-direction*8*ce,8*se)
                slot.scene:SetCameraOrientationByAxisVectors(0,direction*ce,-se,
                    direction*sine,se*cosine,direction*ce*cosine,
                    -cosine,direction*se*sine,ce*sine)
            end
            if p.cameraAzimuth then
                -- Match EffectViewer's orbit, with the cap angle applied as camera roll.
                local az,el=math.rad(p.cameraAzimuth),math.rad(p.cameraElevation or 0)
                local sa,ca,se,ce=math.sin(az),math.cos(az),math.sin(el),math.cos(el)
                local fx,fy,fz=direction*sa*ce,direction*ca*ce,-se
                local bx,by=direction*ca,-direction*sa
                local vx,vy,vz=direction*sa*se,direction*ca*se,ce
                slot.scene:SetCameraPosition(-8*fx,-8*fy,-8*fz)
                slot.scene:SetCameraOrientationByAxisVectors(fx,fy,fz,
                    bx*sine+vx*direction*cosine,by*sine+vy*direction*cosine,vz*direction*cosine,
                    -bx*direction*cosine+vx*sine,-by*direction*cosine+vy*sine,vz*sine)
            end
            local biasX, biasY = direction*0.5, 0.15
            -- Symmetric models get a genuinely centred viewport. Preserve the
            -- approved flame's asymmetric render room and calibration.
            if p.centered then biasX,biasY=0,0 end
            slot.anchorX=x+biasX*pixelsPerUnit
            slot.anchorY=y+biasY*pixelsPerUnit
            slot.motionX=nil;slot.motionY=nil
            slot.scene:SetSize(renderSize,renderSize)
            slot.scene:ClearAllPoints()
            slot.scene:SetPoint("CENTER",entry.art,"TOPLEFT",slot.anchorX,slot.anchorY)
            -- Put the inspected origin on the chosen point and camera depth plane.
            local modelScale=p.modelScale or 1
            slot.actor:SetScale(modelScale)
            slot.actor:SetPosition(-p.emitterX*modelScale-biasX*rx-biasY*ux, -(p.emitterY or 0)*modelScale,
                -p.emitterZ*modelScale-biasX*rz-biasY*uz)
            if ready and slot.needsAnimation then
                slot.actor:SetAnimation(p.animation or 0,0,1,0)
                slot.actor:Show()
                slot.needsAnimation=false
            end
        end
        E.UpdateNativeEffectAlpha(entry)
        E.PlayNativeSmoke(entry)
        return state.status == "ready"
    end)
    if not ok then
        if entry.nativeSmoke then fail(entry, tostring(result)) end
        return false
    end
    return result
end
local function nativeStatus(entry)
    if not entry then return "artwork not attached" end
    if not entry.effectsEnabled then return "artwork effects off" end
    if not entry.nativeWanted then return "native effects disabled" end
    local state = entry.nativeSmoke
    if not state then return "not initialized" end
    local p = state.profile
    if state.status == "ready" then
        local scene=state.slots[1] and state.slots[1].scene
        local overlap="unavailable"
        if scene and scene.GetAllowOverlappedModels then
            overlap=scene:GetAllowOverlappedModels() and "on" or "off"
        end
        return p.name .. " loaded (" .. p.fileID .. "; overlap=" .. overlap .. ")"
    end
    if state.status == "loading" then return "loading native effect; no texture fallback" end
    return "native effect hidden: " .. (state.reason or "native model unavailable")
end
function E.NativeSmokeStatus(entry)return nativeStatus(entry)end
