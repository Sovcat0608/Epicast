local _,E=...
function E.StopMageSigils(entry)
 local s=entry.mageSigils;if not s then return end
 if s.startedAt then s.elapsed=s.elapsed+math.max(0,GetTime()-s.startedAt);s.startedAt=nil end
 s.rotationGroup:Stop();s.hover:Stop();s.host:Hide()
end
function E.PlayMageSigils(entry)
 local s=entry.mageSigils;if not s or not s.enabled or not entry.frame:IsVisible()then return end
 s.host:Show();if s.startedAt then return end;s.startedAt=GetTime()
 local b=entry.mageBooks;local time=b.elapsed+(b.startedAt and math.max(0,GetTime()-b.startedAt)or 0)
 s.hover:Play(false,(time-1)%6);s.rotationGroup:Play(false,s.elapsed%s.period)
end
function E.UpdateMageSigils(entry,c)
 local t=E.GetSigilConfig(c);local s=entry.mageSigils
 if not t or c.effects==false or t.opacity==0 then if s then s.enabled=false;E.StopMageSigils(entry)end;return end
 if not s then
  local host=CreateFrame("Frame",nil,entry.frame);host:EnableMouse(false);host:Hide()
  local tex=host:CreateTexture(nil,"OVERLAY");tex:SetBlendMode("ADD")
  if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false)end;if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0)end
  s={host=host,base=tex,elapsed=0};entry.mageSigils=s
  s.hover=host:CreateAnimationGroup();s.hover:SetLooping("REPEAT");s.legs={}
  for order=1,2 do local leg=s.hover:CreateAnimation("Translation");leg:SetOrder(order);leg:SetDuration(3);leg:SetSmoothing("IN_OUT");s.legs[order]=leg end
  s.rotationGroup=tex:CreateAnimationGroup();s.rotationGroup:SetLooping("REPEAT");s.rotation=s.rotationGroup:CreateAnimation("Rotation");s.rotation:SetOrder(1);s.rotation:SetOrigin("CENTER",0,0);s.rotation:SetSmoothing("NONE")
 end
 E.StopMageSigils(entry);s.enabled=true;s.period=t.period
 local w,h=entry.art:GetSize();local bw=w*.72;local amplitude=bw*.012;local size=bw*.65*t.size/100
 s.host:SetSize(size,size);s.host:SetFrameLevel(entry.frame:GetFrameLevel()+6);s.host:ClearAllPoints()
 s.host:SetPoint("CENTER",entry.art,"CENTER",t.x*w/225*(c.flip and -1 or 1),(30+t.y)*h/225-amplitude)
 s.host:SetAlpha(entry.alpha*t.opacity/100);s.legs[1]:SetOffset(0,amplitude*2);s.legs[2]:SetOffset(0,-amplitude*2)
 local flip=(c.flip==true)~=t.flip
 s.base:SetTexture("Interface\\AddOns\\Epicast\\Media\\ArcaneSigilCASSize256.tga");s.base:SetSize(size,size);s.base:ClearAllPoints();s.base:SetPoint("CENTER",s.host,"CENTER",0,0);s.base:SetTexCoord(E.UV({0,0,0,1,1,0,1,1},flip));s.base:Show()
 s.rotation:SetDuration(t.period);s.rotation:SetDegrees(flip and 360 or -360);E.PlayMageSigils(entry)
end
