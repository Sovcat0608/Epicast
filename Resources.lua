local _,E=...
local function value(fn,...)
 if not fn then return end;local ok,v=pcall(fn,...)
 if ok and not(issecretvalue and issecretvalue(v))and type(v)=="number"and v==v then return v end
end
function E.ReadResource(kind)
 local label,id
 for _,r in ipairs(E.ResourceKinds)do if r[1]==kind then label,id=r[2],r[3]end end
 local current,maximum
 if kind=="health"then current=value(UnitHealth,"player");maximum=value(UnitHealthMax,"player")
 else
  if kind=="power"then id=value(UnitPowerType,"player")end
  if id then current=value(UnitPower,"player",id);maximum=value(UnitPowerMax,"player",id)end
 end
 if not current or not maximum or maximum<=0 then return nil,label or"Resource"end
 return math.max(0,math.min(1,current/maximum)),label
end
function E.UpdateResource(entry,c)
 local enabled=c.role=="resources"and entry.frame:IsShown()
 local bar=entry.resourceBar
 if not enabled then if bar then bar:Hide()end;return end
 if not bar then
  bar=CreateFrame("StatusBar",nil,entry.frame);entry.resourceBar=bar;bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");bar:SetMinMaxValues(0,1)
  local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.06,.04,.12,.85)
  bar.text=bar:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");bar.text:SetPoint("BOTTOM",bar,"TOP",0,3)
 end
 local ratio,label=E.ReadResource(c.resource);entry.resourceRatio=ratio
 bar:SetSize(math.max(60,entry.frame:GetWidth()*.75),5);bar:ClearAllPoints();bar:SetPoint("BOTTOM",entry.frame,"BOTTOM",0,3);bar:SetFrameLevel(entry.frame:GetFrameLevel()+30)
 if c.resource=="health"then bar:SetStatusBarColor(.3,.85,.55)else bar:SetStatusBarColor(.48,.35,1)end
 bar:SetValue(ratio or 0);bar.text:SetText(label..(ratio and string.format(" %d%%",math.floor(ratio*100+.5))or" —"));bar:SetShown(c.showMeter)
 -- Native effect intensity follows the resource level.
 local intensity=ratio and(.12+.88*ratio)or .12
 for _,fx in ipairs(entry.addedEffectSlots or{})do
  local s=fx.nativeSmoke;for _,slot in ipairs(s and s.slots or{})do slot.scene:SetAlpha(s.status=="ready"and entry.alpha*(fx.resourceOpacity or 0)*intensity or 0)end
 end
end
function E.RefreshResources()
 for _,entries in pairs(E.instances or{})do for _,entry in pairs(entries)do if entry.config then E.UpdateResource(entry,entry.config)end end end
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_POWER_UPDATE","UNIT_POWER_FREQUENT","UNIT_MAXPOWER","UNIT_DISPLAYPOWER"})do frame:RegisterUnitEvent(event,"player")end
frame:SetScript("OnEvent",function()E.RefreshResources()end)
