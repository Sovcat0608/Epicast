local _,E=...
local prefix="Interface\\AddOns\\Epicast\\Media\\"
local function sampleSize(entry,width,art)
 local scale=entry.frame.GetEffectiveScale and entry.frame:GetEffectiveScale()
 local _,height;if GetPhysicalScreenSize then _,height=GetPhysicalScreenSize()end
 local chosen=art.sizes[#art.sizes]
 if scale and scale>0 and height and height>0 then
  local pixels=width*scale*height/768
  for _,size in ipairs(art.sizes)do if size>=pixels then chosen=size;break end end
 end
 local backing=1;while backing<chosen do backing=backing*2 end
 local uv=chosen/backing
 return chosen,{0,0,0,uv,uv,0,uv,uv}
end
function E.StopMageReboot(entry)
 local s=entry.mageReboot;if not s then return end
 if s.startedAt then s.elapsed=(s.elapsed+math.max(0,GetTime()-s.startedAt))%6;s.startedAt=nil end
 s.hover:Stop();s.host:Hide()
end
function E.PlayMageReboot(entry)
 local s=entry.mageReboot;if not s or not s.enabled or not entry.frame:IsVisible()then return end
 s.host:Show()
 if s.animate and not s.startedAt then s.startedAt=GetTime();s.hover:Play(false,s.elapsed%6)end
end
function E.UpdateMageReboot(entry,c)
 local art=E.MageRebootArtworks[c.art];local s=entry.mageReboot
 if not art then if s then s.enabled=false;E.StopMageReboot(entry)end;return end
 if not s then
  local host=CreateFrame("Frame",nil,entry.frame);host:EnableMouse(false);host:Hide()
  local texture=host:CreateTexture(nil,"ARTWORK")
  if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false)end
  if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0)end
  s={host=host,texture=texture,elapsed=0,legs={}};entry.mageReboot=s
  s.hover=host:CreateAnimationGroup();s.hover:SetLooping("REPEAT")
  for order=1,2 do local leg=s.hover:CreateAnimation("Translation");leg:SetOrder(order);leg:SetDuration(3);leg:SetSmoothing("IN_OUT");s.legs[order]=leg end
 end
 E.StopMageReboot(entry)
 if s.art~=c.art then s.elapsed=0 end
 s.art=c.art;s.enabled=true;s.animate=c.effects~=false
 local width,height=art.width*c.size/100,art.height*c.size/100
 local amplitude=s.animate and height*.012 or 0
 local size,uv=sampleSize(entry,width,art);s.textureSize=size
 s.host:SetSize(width,height);s.host:SetFrameLevel(entry.frame:GetFrameLevel()+4);s.host:SetAlpha(entry.alpha)
 s.host:ClearAllPoints();s.host:SetPoint("CENTER",entry.art,"CENTER",0,30*c.size/100-amplitude)
 s.texture:SetTexture(prefix..art.name.."CASSize"..size..".tga");s.texture:SetSize(width,height)
 s.texture:ClearAllPoints();s.texture:SetPoint("CENTER",s.host,"CENTER",0,0);s.texture:SetTexCoord(E.UV(uv,c.flip))
 s.legs[1]:SetOffset(0,amplitude*2);s.legs[2]:SetOffset(0,-amplitude*2)
 E.PlayMageReboot(entry)
end
