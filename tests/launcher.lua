local E=...
local function launchers()
 local found,count=nil,0
 for _,frame in ipairs(Mock.frames)do
  if frame:GetName()=="EpicastMinimapButton"then found=frame;count=count+1 end
 end
 return found,count
end

EpicastDB=E.Normalize(nil)
E.ClassBank(EpicastDB).configured=true
Mock.event("ADDON_LOADED","Epicast")
Mock.advance(0)
assert(E.devMode and not E.panel,"Developer mode should start enabled without opening the editor")
assert(not launchers(),"Wait for the minimap if it hasn't loaded")
Minimap=CreateFrame("Frame","Minimap",UIParent)
Mock.event("PLAYER_ENTERING_WORLD")
local button,count=launchers()
assert(count==1 and button.kind=="Button" and button:GetParent()==Minimap and button:IsShown())
assert(button:GetWidth()==31 and button:GetHeight()==31 and button.clicks[1]=="LeftButtonUp")
button:Click()
assert(E.panel:IsShown() and E.panel.openEffects:IsShown())
assert(E.panel.developer:GetChecked())
E.SetDeveloperMode(false)
E.panel.close:Click()

-- A collector can move the original button while keeping its click handler.
local collectorBar=CreateFrame("Frame",nil,UIParent)
button:SetParent(collectorBar)
Mock.event("PLAYER_ENTERING_WORLD")
Mock.advance(0)
local subsequent,afterCount=launchers()
assert(subsequent==button and afterCount==1 and button:GetParent()==collectorBar)
button:Click()
assert(E.panel:IsShown() and not E.devMode and not E.panel.openEffects:IsShown())
assert(EpicastDB.devMode==nil and EpicastDB.developerMode==nil)
print("PASS: default-on session developer mode, late minimap launcher, collector reparenting and click-to-open")
