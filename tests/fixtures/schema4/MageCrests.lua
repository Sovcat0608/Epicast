local _,E=...
local prefix="Interface\\AddOns\\Epicast\\Media\\"
local function createLayer(entry,level)
 local host=CreateFrame("Frame",nil,entry.frame);host:EnableMouse(false);host:SetFrameLevel(entry.frame:GetFrameLevel()+level);host:Hide()
 local texture=host:CreateTexture(nil,"ARTWORK")
 if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false)end
 if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0)end
 local layer={host=host,texture=texture,hover=host:CreateAnimationGroup(),legs={}}
 layer.hover:SetLooping("REPEAT")
 for order=1,2 do local leg=layer.hover:CreateAnimation("Translation");leg:SetOrder(order);leg:SetDuration(3);leg:SetSmoothing("IN_OUT");layer.legs[order]=leg end
 return layer
end
local function configure(layer,entry,c,art,width,height,x,y,amplitude)
 local scale=entry.frame.GetEffectiveScale and entry.frame:GetEffectiveScale();local _,screen
 if GetPhysicalScreenSize then _,screen=GetPhysicalScreenSize()end
 local chosen=art.sizes[#art.sizes]
 if scale and scale>0 and screen and screen>0 then for _,size in ipairs(art.sizes)do if size>=width*scale*screen/768 then chosen=size;break end end end
 local contentH=chosen*art.height/art.width;local tw,th=1,1
 while tw<chosen do tw=tw*2 end;while th<contentH do th=th*2 end
 layer.textureSize=chosen;layer.host:SetSize(width,height);layer.host:SetAlpha(entry.alpha)
 layer.host:ClearAllPoints();layer.host:SetPoint("CENTER",entry.art,"CENTER",x,y-amplitude)
 layer.texture:SetTexture(prefix..art.name.."CASSize"..chosen..".tga");layer.texture:SetSize(width,height)
 layer.texture:ClearAllPoints();layer.texture:SetPoint("CENTER",layer.host,"CENTER",0,0)
 layer.texture:SetTexCoord(E.UV({0,0,0,contentH/th,chosen/tw,0,chosen/tw,contentH/th},c.flip))
 layer.legs[1]:SetOffset(0,amplitude*2);layer.legs[2]:SetOffset(0,-amplitude*2)
end
function E.StopMageCrests(entry)
 local s=entry.mageCrest;if not s then return end
 if s.startedAt then s.elapsed=(s.elapsed+math.max(0,GetTime()-s.startedAt))%6;s.startedAt=nil end
 for _,layer in ipairs({s.book,s.scroll})do layer.hover:Stop();layer.host:Hide()end
end
function E.PlayMageCrests(entry)
 local s=entry.mageCrest;if not s or not s.enabled or not entry.frame:IsVisible()then return end
 s.book.host:Show();s.scroll.host:Show()
 if s.animate and not s.startedAt then
  s.startedAt=GetTime();s.book.hover:Play(false,s.elapsed%6);s.scroll.hover:Play(false,(s.elapsed-1)%6)
 end
end
function E.UpdateMageCrests(entry,c)
 local art=E.MageCrestArtworks[c.art];local s=entry.mageCrest
 if not art then if s then s.enabled=false;E.StopMageCrests(entry)end;return end
 if not s then s={book=createLayer(entry,4),scroll=createLayer(entry,6),elapsed=0};entry.mageCrest=s end
 E.StopMageCrests(entry);if s.art~=c.art then s.elapsed=0 end
 s.art=c.art;s.enabled=true;s.animate=c.effects~=false
 local w=entry.art:GetWidth()*.72;local h=w*4/3;local amplitude=s.animate and h*.012 or 0
 local t=E.GetFloatingScrollConfig(c);local sw=w*.82*t.size/100
 configure(s.book,entry,c,art.book,w,h,0,0,amplitude)
 configure(s.scroll,entry,c,art.scroll,sw,sw,t.x*c.size/100*(c.flip and -1 or 1),t.y*c.size/100,amplitude)
 E.PlayMageCrests(entry)
end
