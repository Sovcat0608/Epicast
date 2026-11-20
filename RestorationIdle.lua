local _, E = ...

local media = "Interface\\AddOns\\Epicast\\Media\\"
local framesPerSecond = 8
local period = 32 / framesPerSecond

local function hideCel(idle)
    if idle.page then idle.page:Hide() end
    idle.page, idle.cel = nil, nil
end

local function makePage(host)
    local page = host:CreateTexture(nil, "ARTWORK")
    page:Hide()
    page:SetAllPoints(host)
    if page.SetDesaturation then page:SetDesaturation(E.DruidArtworkDesaturation) end
    if page.SetSnapToPixelGrid then page:SetSnapToPixelGrid(false) end
    if page.SetTexelSnappingBias then page:SetTexelSnappingBias(0) end
    return page
end

local function selectBank(host, idle, bank)
    hideCel(idle)
    idle.bank, idle.unavailable = bank, false
    for index = 1, bank.count do
        local page = idle.pages[index]
        if not page then
            page = makePage(host)
            idle.pages[index] = page
        end
        if page:SetTexture(media .. string.format("%s%02d.tga", bank.stem, index)) == false then
            idle.unavailable = true
            break
        end
    end
    local loaded = idle.unavailable and 0 or bank.count
    for index = loaded + 1, #idle.pages do idle.pages[index]:SetTexture(nil) end
end

local function showCel(idle, elapsed)
    local cel = math.floor((elapsed % period) * framesPerSecond)
    if idle.cel == cel and idle.previousFlip == idle.flip then return end
    local bank = idle.bank
    local index = math.floor(cel / bank.perPage) + 1
    local cell = cel % bank.perPage
    local width, height = bank.width, bank.height
    local u, v = (cell % bank.columns) * width, math.floor(cell / bank.columns) * height
    local page = idle.pages[index]
    page:SetTexCoord(E.UV({u, v, u, v + height, u + width, v, u + width, v + height}, idle.flip))
    if idle.page and idle.page ~= page then idle.page:Hide() end
    if idle.page ~= page then page:Show() end
    idle.page, idle.cel, idle.previousFlip = page, cel, idle.flip
end

function E.ConfigureRestorationIdle(state, size, flip)
    local idle = state.restorationIdle
    local bank = E.RestorationIdleBanks[size]
    if not bank then
        if idle then
            hideCel(idle)
            idle.active = false
        end
        state.texture:Show()
        return
    end
    if not idle then
        idle = { pages = {}, elapsed = 0 }
        state.restorationIdle = idle
    end
    if idle.bank ~= bank then selectBank(state.host, idle, bank) end
    idle.active = not idle.unavailable
    state.texture:SetShown(not idle.active)
    if not idle.active then return end
    idle.flip = flip
    showCel(idle, state.animate and idle.elapsed or 0)
end

function E.StopRestorationIdle(state)
    local idle = state.restorationIdle
    if not idle or not idle.started then return end
    idle.elapsed = (idle.elapsed + math.max(0, GetTime() - idle.started)) % period
    idle.started = nil
    state.host:SetScript("OnUpdate", nil)
end

function E.PlayRestorationIdle(state)
    local idle = state.restorationIdle
    if not idle or not idle.active or not state.animate or idle.started then return end
    idle.started = GetTime()
    showCel(idle, idle.elapsed)
    state.host:SetScript("OnUpdate", function()
        showCel(idle, idle.elapsed + math.max(0, GetTime() - idle.started))
    end)
end
