unpack=table.unpack;tinsert=table.insert
Mock={frames={},now=0,timers={},combat=false,health=70,mana=40,maximum=100,class="MAGE"}
function GetTime()return Mock.now end
function InCombatLockdown()return Mock.combat end
function GetPhysicalScreenSize()return 1920,1080 end
function GetCursorPosition()return Mock.cursorX or 0,Mock.cursorY or 0 end
function UnitClass()return"Mage",Mock.class end
function UnitHealth()return Mock.health end
function UnitHealthMax()return Mock.maximum end
function UnitPower()return Mock.mana end
function UnitPowerMax()return Mock.maximum end
function UnitPowerType()return 0 end
C_Timer={After=function(delay,fn)Mock.timers[#Mock.timers+1]={at=Mock.now+delay,fn=fn}end}
function Mock.advance(dt)
 Mock.now=Mock.now+dt
 for pass=1,30 do local old=Mock.timers;Mock.timers={};local ran=false
  for _,t in ipairs(old)do if t.at<=Mock.now then t.fn();ran=true else Mock.timers[#Mock.timers+1]=t end end
  if not ran then return end
 end;error('Timer loop')
end
function hooksecurefunc(object,key,fn)local old=object[key];object[key]=function(self,...)local value=old(self,...);fn(self,...);return value end end
local function widget(kind,parent,name)
 local w={kind=kind,parent=parent,name=name,shown=true,enabled=true,scripts={},events={},width=100,height=100,alpha=1,level=1,text=""}
 for method in ([=[EnableMouse EnableMouseWheel RegisterForDrag SetFrameStrata SetMovable SetClampedToScreen SetBackdrop SetBackdropColor SetBackdropBorderColor SetColorTexture SetAutoFocus SetMaxLetters SetMaxLines SetTextColor SetJustifyH SetNormalTexture SetHighlightTexture SetDisabledTexture SetFontString SetDisabledFontObject SetDrawLayer SetCameraNearClip SetCameraFarClip SetCameraFieldOfView SetLightAmbientColor SetLightDiffuseColor SetDesaturation SetNumeric SetBlendMode SetSnapToPixelGrid SetTexelSnappingBias SetCameraPosition SetCameraOrientationByAxisVectors SetPosition SetPitch SetYaw SetRoll SetViewInsets SetViewTranslation SetPaused SetStatusBarTexture SetStatusBarColor SetSmoothing SetOrder SetDuration SetOffset SetOrigin SetDegrees SetLooping]=]):gmatch('%S+')do
  local key=method;w[key]=function(self,...)self[key..'Args']={...}end
 end
 function w:GetName()return self.name end
 function w:SetSize(a,b)self.width=a;self.height=b end
 function w:GetSize()return self.width,self.height end
 function w:SetWidth(a)self.width=a end;function w:SetHeight(a)self.height=a end
 function w:GetWidth()return self.width end;function w:GetHeight()return self.height end
 function w:SetScale(s)self.scale=s end;function w:GetEffectiveScale()return self.scale or 1 end
 function w:SetAlpha(a)self.alpha=a end;function w:GetAlpha()return self.alpha end
 function w:SetFrameLevel(a)self.level=a end;function w:GetFrameLevel()return self.level end
 function w:SetParent(p)self.parent=p end
 function w:SetPoint(...)self.point={...}end;function w:ClearAllPoints()self.point=nil end
 function w:SetAllPoints(p)self.allPoints=p or self.parent end
 function w:SetScript(k,fn)self.scripts[k]=fn end
 function w:HookScript(k,fn)local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;fn(...)end end
 function w:emit(k,...)if self.scripts[k]then self.scripts[k](self,...)end end
 function w:Show()local old=self.shown;self.shown=true;if not old then self:emit('OnShow')end end
 function w:Hide()local old=self.shown;self.shown=false;if old then self:emit('OnHide')end end
 function w:IsShown()return self.shown end
 function w:IsVisible()return self.shown and(not self.parent or self.parent:IsVisible())end
 function w:SetShown(v)if v then self:Show()else self:Hide()end end
 function w:SetEnabled(v)self.enabled=v end
 function w:Enable()self.enabled=true end;function w:Disable()self.enabled=false end
 if kind=='EditBox'then w.SetEnabled=nil end
 function w:SetText(v)self.text=v;self:emit('OnTextChanged',false)end;function w:GetText()return self.text end
 function w:SetChecked(v)self.checked=v end;function w:GetChecked()return self.checked end
 function w:HasFocus()return self.focus end;function w:SetFocus()self.focus=true end;function w:ClearFocus()self.focus=false end;function w:HighlightText()end
 function w:StartMoving()end;function w:StopMovingOrSizing()end
 function w:SetValue(v)self.value=v;self:emit('OnValueChanged',v)end;function w:GetValue()return self.value end
 function w:SetMinMaxValues(a,b)self.minimum=a;self.maximum=b end
 function w:Click()if self.enabled then if self.kind=='CheckButton'then self.checked=not self.checked end;self:emit('OnClick')end end
 function w:RegisterEvent(e)self.events[e]=true end;function w:RegisterUnitEvent(e,u)self.events[e]=u end
 function w:CreateTexture()return widget('Texture',self)end;function w:CreateFontString()return widget('FontString',self)end
 function w:SetTexture(t)self.texture=t end;function w:SetTexCoord(...)self.uv={...}end
 function w:CreateAnimationGroup()local g=widget('AnimationGroup',self);g.animations={};self.groups=self.groups or{};table.insert(self.groups,g);return g end
 function w:CreateAnimation(kind)local a=widget(kind,self);self.animations[#self.animations+1]=a;return a end
 function w:Play(_,elapsed)self.playing=true;self.elapsed=elapsed end;function w:Stop()self.playing=false end
 function w:SetAllowOverlappedModels(v)self.overlap=v end;function w:GetAllowOverlappedModels()return self.overlap end
 function w:CreateActor()local a=widget('Actor',self);self.actor=a;return a end
 function w:IsLoaded()return self.loaded end
 function w:GetModelFileID()return self.modelID end
 function w:ClearModel()self.loaded=false;self.modelID=nil end
 function w:SetModelByFileID(id)self.modelID=id;self.loaded=not Mock.loading;if self.epicastOnModelLoaded then self.epicastOnModelLoaded()end;if self.epicastLibraryLoaded then self.epicastLibraryLoaded()end;return true end
 function w:SetAnimation(...)self.animation={...};self.animationStarts=(self.animationStarts or 0)+1 end
 function w:GetMaxBoundingBox()return -1,-1,-1,1,1,1 end
 Mock.frames[#Mock.frames+1]=w;return w
end
function CreateFrame(kind,name,parent,template)
 local w=widget(kind,parent,name)
 if template=='MinimalSliderWithSteppersTemplate'then w.Slider=widget('Slider',w);function w:Init(v,lo,hi)self.Slider.minimum=lo;self.Slider.maximum=hi;self.Slider.value=v end end
 return w
end
UIParent=widget('Frame');UIParent:SetSize(1920,1080)
UISpecialFrames={};SlashCmdList={};MinimalSliderWithSteppersMixin={Label={Right=1}}
MenuUtil={CreateContextMenu=function(owner,fn)Mock.menu={};fn(owner,{CreateRadio=function(_,name,selected,callback)Mock.menu[#Mock.menu+1]={name=name,selected=selected,choose=callback}end})end}
function Mock.event(event,...)
 local snapshot={};for _,f in ipairs(Mock.frames)do snapshot[#snapshot+1]=f end
 for _,f in ipairs(snapshot)do if f.events[event]then f:emit('OnEvent',event,...)end end
end
local names={[30451]='Arcane Blast',[1449]='Arcane Explosion',[5143]='Arcane Missiles',[7268]='Arcane Missiles',[400588]='Missile Barrage',[400589]='Missile Barrage'}
C_Spell={GetSpellName=function(id)return names[id]end,GetSpellInfo=function(value)for id,name in pairs(names)do if name==value or id==value then return{name=name,spellID=id}end end end}
C_UnitAuras={GetPlayerAuraBySpellID=function()return Mock.aura end,GetAuraDataBySpellName=function()return Mock.aura end}
C_SpellActivationOverlay={IsSpellOverlayed=function()return Mock.proc end}
return Mock
