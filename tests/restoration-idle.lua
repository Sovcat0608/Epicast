local E = ...
local function near(a, b)
    assert(math.abs(a-b) < 1e-8, tostring(a) .. " ~= " .. tostring(b))
end

Mock.class = "DRUID"
-- Exercise the fallback even when the shipped Restoration bake uses segments.
E.RestorationSegmentBanks = nil
EpicastDB = E.Normalize(nil)
local bank = E.ClassBank(EpicastDB)
bank.configured = true
bank.active.restoration = true
bank.active.balance = true
Mock.event("ADDON_LOADED", "Epicast")
bank = E.ClassBank(EpicastDB)
local config = bank.slots.restoration
local entry = E.GetEntry("spells", "restoration")
local state = entry.druidSister
local idle = state.restorationIdle
local balance = E.GetEntry("spells", "balance").druidSister
assert(not balance.restorationIdle and balance.texture:IsShown())
assert(idle.active and idle.cel == 0 and idle.bank == E.RestorationIdleBanks[288])
assert(#idle.pages == idle.bank.count and idle.page.texture:match("CASSize288Page01%.tga$"))
assert(state.hover.playing and idle.page:IsVisible() and not state.texture:IsShown())

local function tick(seconds)
    Mock.advance(seconds)
    state.host:emit("OnUpdate")
end
tick(.125)
assert(idle.cel == 1 and idle.page == idle.pages[1])
near(idle.page.uv[1], idle.bank.width)
tick(.375)
assert(idle.cel == 4 and idle.page == idle.pages[2] and not idle.pages[1]:IsShown())
tick(3.375)
assert(idle.cel == 31 and idle.page == idle.pages[idle.bank.count])
tick(.125)
assert(idle.cel == 0 and idle.page == idle.pages[1])

tick(.625)
local oldPage = idle.page
config.size, config.flip = 175, true
E.Apply()
assert(idle.cel == 5 and idle.page ~= oldPage and idle.bank == E.RestorationIdleBanks[480])
assert(idle.page.texture:match("CASSize480Page03%.tga$") and not oldPage:IsShown())
near(state.host:GetWidth(), 162*1.75)
near(idle.page.uv[1], 960/1024)
entry.frame:Hide()
assert(not idle.started and not state.host.scripts.OnUpdate and not idle.page:IsVisible())
tick(2)
entry.frame:Show()
assert(idle.cel == 5 and idle.started == Mock.now and idle.page:IsVisible())
tick(.125)
assert(idle.cel == 6)

config.effects = false
E.Apply()
assert(idle.cel == 0 and idle.page:IsVisible() and not state.hover.playing and not state.host.scripts.OnUpdate)
tick(1)
assert(idle.cel == 0)
config.effects = true
E.Apply()
assert(idle.cel == 6 and state.hover.playing)
for _, pair in ipairs({{75,192},{100,288},{150,384},{190,480},{225,576},{275,660},{75,192}}) do
    config.size = pair[1]
    E.Apply()
    assert(idle.cel == 6 and idle.bank == E.RestorationIdleBanks[pair[2]])
    assert(idle.pages[idle.bank.count].texture and not (idle.pages[idle.bank.count+1] or {}).texture)
    assert(state.hover.playing and state.legs[1].SetDurationArgs[1] == 3)
end
local getScreen = GetPhysicalScreenSize
GetPhysicalScreenSize = nil
E.Apply()
assert(idle.cel == 6 and idle.bank == E.RestorationIdleBanks[660])
GetPhysicalScreenSize = getScreen
bank.active.restoration = false
E.Apply()
assert(not idle.started and not state.host.scripts.OnUpdate and not idle.page:IsVisible())

local fallback = { host = CreateFrame("Frame"), animate = true }
fallback.texture = fallback.host:CreateTexture(nil, "ARTWORK")
local create = fallback.host.CreateTexture
function fallback.host:CreateTexture(...)
    local page = create(self, ...)
    function page:SetTexture()
        return false
    end
    return page
end
E.ConfigureRestorationIdle(fallback, 384, false)
E.PlayRestorationIdle(fallback)
assert(fallback.restorationIdle.unavailable and fallback.texture:IsShown())
assert(not fallback.host.scripts.OnUpdate)
print("PASS: Restoration idle cadence, six size banks, missing screen metrics, flip, hide/resume and missing-media fallback")
