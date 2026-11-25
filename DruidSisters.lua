local _,E=...
local prefix="Interface\\AddOns\\Epicast\\Media\\"
E.DruidArtworkDesaturation=0.07
local function sampleSize(entry,width,art)
 local scale=entry.frame.GetEffectiveScale and entry.frame:GetEffectiveScale()
 local _,height;if GetPhysicalScreenSize then _,height=GetPhysicalScreenSize()end
 local sizes=art.sizes or E.DruidTextureSizes;local chosen=sizes[#sizes]
 if scale and scale>0 and height and height>0 then
  local pixels=width*scale*height/768
  for _,size in ipairs(sizes)do if size>=pixels then chosen=size;break end end
 end
 local h=chosen*4/3;local backingW,backingH=1,1
 while backingW<chosen do backingW=backingW*2 end
 while backingH<h do backingH=backingH*2 end
 return chosen,{0,0,0,h/backingH,chosen/backingW,0,chosen/backingW,h/backingH}
end
local function pause(s)
 if s.startedAt then s.elapsed=(s.elapsed+math.max(0,GetTime()-s.startedAt))%6;s.startedAt=nil end
 if s.restorationIdle then E.StopRestorationIdle(s)end
 s.hover:Stop()
end
function E.StopDruidSisters(entry)
 local s=entry.druidSister;if not s then return end
 pause(s);s.host:Hide()
end
function E.PlayDruidSisters(entry)
 local s=entry.druidSister;if not s or not s.enabled or not entry.frame:IsVisible()then return end
 s.host:Show()
 if s.animate and not s.startedAt then s.startedAt=GetTime();s.hover:Play(false,s.elapsed%6)end
 if s.restorationIdle then E.PlayRestorationIdle(s)end
end
function E.UpdateDruidSisters(entry,c)
 local art=E.DruidArtworks[c.art];local s=entry.druidSister
 if not art then if s then s.enabled=false;E.StopDruidSisters(entry)end;return end
 if not s then
  local host=CreateFrame("Frame",nil,entry.frame);host:EnableMouse(false);host:Hide()
  local texture=host:CreateTexture(nil,"ARTWORK")
  if texture.SetDesaturation then texture:SetDesaturation(E.DruidArtworkDesaturation)end
  if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false)end
  if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0)end
  s={host=host,texture=texture,elapsed=0,legs={}};entry.druidSister=s
  s.hover=host:CreateAnimationGroup();s.hover:SetLooping("REPEAT")
  for order=1,2 do local leg=s.hover:CreateAnimation("Translation");leg:SetOrder(order);leg:SetDuration(3);leg:SetSmoothing("IN_OUT");s.legs[order]=leg end
 end
 pause(s)
 if entry.artworkPhase then s.elapsed=entry.artworkPhase elseif s.art~=c.art then s.elapsed=0 end
 s.art=c.art;s.enabled=true;s.animate=c.effects~=false
 local width=entry.art:GetWidth()*.72;local height=width*4/3
 local amplitude=s.animate and height*.012 or 0
 local size,uv=sampleSize(entry,width,art);s.textureSize=size
 s.host:SetSize(width,height);s.host:SetFrameLevel(entry.frame:GetFrameLevel()+4);s.host:SetAlpha(entry.alpha)
 s.host:ClearAllPoints();s.host:SetPoint("CENTER",entry.art,"CENTER",0,30*entry.art:GetWidth()/225-amplitude)
 s.texture:SetTexture(prefix..art.name.."CASSize"..size..".tga");s.texture:SetSize(width,height)
 s.texture:ClearAllPoints();s.texture:SetPoint("CENTER",s.host,"CENTER",0,0);s.texture:SetTexCoord(E.UV(uv,c.flip))
 s.legs[1]:SetOffset(0,amplitude*2);s.legs[2]:SetOffset(0,-amplitude*2)
 if E.ConfigureRestorationIdle then
  local segmented=E.UseRestorationSegments and E.UseRestorationSegments(entry,c)
  E.ConfigureRestorationIdle(s,c.art=="druidRestoration" and not segmented and size or nil,c.flip,segmented)
 end
 E.PlayDruidSisters(entry)
end
