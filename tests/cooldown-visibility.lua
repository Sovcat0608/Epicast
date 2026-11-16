local E=...
local function forbidden()error('Forbidden native mutation/refresh/CVar write')end
C_CVar={SetCVar=forbidden};SetCVar=forbidden
local native={}
local function widget(parent,alpha,motion,click)
 local s={parent=parent,alpha=alpha or 1,motion=motion~=false,click=click~=false,shown=true,children={},scripts={},writes=0,hooks=0,events=true}
 local f={};native[f]=s
 function f:GetAlpha()return s.alpha end
 function f:SetAlpha(v)s.alpha=v;s.writes=s.writes+1 end
 function f:IsMouseMotionEnabled()return s.motion end
 function f:SetMouseMotionEnabled(v)assert(not(Mock.combat and s.protected),'Protected mouse mutation in combat');s.motion=v;s.writes=s.writes+1 end
 function f:IsMouseClickEnabled()return s.click end
 function f:SetMouseClickEnabled(v)assert(not(Mock.combat and s.protected),'Protected click mutation in combat');s.click=v;s.writes=s.writes+1 end
 function f:IsProtected()return s.protected==true end
 function f:GetParent()return s.parent end
 function f:GetChildren()return unpack(s.children)end
 function f:IsShown()return s.shown end
 function f:IsVisible()return s.shown and(not s.parent or s.parent:IsVisible())end
 function f:IsEditing()return s.editing==true end
 function f:HookScript(key,fn)local old=s.scripts[key];s.scripts[key]=function(...)if old then old(...)end;fn(...)end;s.hooks=s.hooks+1 end
 function f:RefreshLayout()assert(s.nativeRefresh,'Addon invoked native refresh');s.nativeRefresh=false end
 function f:GetItemFrames()return s.items or{}end
 function f:GetCooldownID()return s.cooldownID end
 function f:IsActive()return s.active==true end
 function f:HasEditModeData()return false end
 for _,key in ipairs({'Hide','Show','SetShown','SetParent','SetScript','RegisterEvent','UnregisterEvent','RegisterUnitEvent','RefreshData','SetTooltipsShown','UpdateSystemSettingValue','SetIsActive'})do f[key]=forbidden end
 setmetatable(f,{__newindex=function(_,key)error('Addon wrote native Lua field: '..key)end})
 if native[parent]then table.insert(native[parent].children,f)end
 return f,s
end
local function layout(f)local s=native[f];s.nativeRefresh=true;f:RefreshLayout()end
local function shown(f,value)local s=native[f];s.shown=value;s.events=value;local fn=s.scripts[value and'OnShow'or'OnHide'];if fn then fn(f)end end
local names={'EssentialCooldownViewer','UtilityCooldownViewer','BuffIconCooldownViewer','BuffBarCooldownViewer'}
local viewers={}
for i,name in ipairs(names)do local f,s=widget(UIParent,.4+i*.1);_G[name]=f;viewers[i]=f;local container=widget(f);local item=widget(container,1,i~=2,i~=3);s.items={item}end
local icon=native[viewers[3]].items[1];native[icon].cooldownID=71
local clearcasting=native[viewers[4]].items[1];native[clearcasting].cooldownID=72
C_CooldownViewer={GetCooldownViewerCooldownInfo=function(id)
 if id==71 then return{spellID=400588,linkedSpellIDs={400589}}end
 if id==72 then return{spellID=16864,linkedSpellIDs={16870}}end
end}
EditModeManagerFrame=CreateFrame('Frame');EditModeManagerFrame:Hide()
CooldownViewerSettings=CreateFrame('Frame');CooldownViewerSettings:Hide()
EpicastDB=nil;Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
local p=E.panel
E.SelectOptionsPage('settings')
assert(EpicastDB.hideCooldownManager==false and E.Normalize({hideCooldownManager='true'}).hideCooldownManager==false)
for _,v in ipairs(viewers)do assert(native[v].writes==0 and native[v].hooks==0)end
assert(p.cooldownHelp:GetText():find('without disabling tracking',1,true)and p.cooldownHelp:GetText():find('Always',1,true))
p.hideCooldown:Click();assert(E.draft.hideCooldownManager and not EpicastDB.hideCooldownManager and p.save.enabled)
for _,v in ipairs(viewers)do
 local s=native[v];local item=s.items[1]
 assert(v:GetAlpha()==0 and v:IsVisible()and s.events,'Transparency must not stop native visibility/events')
 assert(not native[item].motion and not native[item].click,'Nested items must be non-interactive')
end
p.cancel:Click();assert(not EpicastDB.hideCooldownManager)
for i,v in ipairs(viewers)do local s=native[v];local item=native[s.items[1]];assert(s.alpha==.4+i*.1 and item.motion==(i~=2)and item.click==(i~=3))end
E.OpenOptions();p.hideCooldown:Click();p.save:Click();assert(EpicastDB.hideCooldownManager and not p.save.enabled)
p.hideCooldown:Click();assert(viewers[3]:GetAlpha()>.5);p:Hide();assert(viewers[3]:GetAlpha()==0 and EpicastDB.hideCooldownManager)
-- Native/other-addon visual intent is restored, rather than blindly setting 1.
viewers[3]:SetAlpha(.37);assert(viewers[3]:GetAlpha()==0)
icon:SetMouseMotionEnabled(false)
EditModeManagerFrame:Show();assert(viewers[3]:GetAlpha()==.37 and not native[icon].motion and not native[icon].click)
EditModeManagerFrame:Hide();assert(viewers[3]:GetAlpha()==0 and not native[icon].click)
CooldownViewerSettings:Show();assert(viewers[3]:GetAlpha()==.37)
CooldownViewerSettings:Hide();assert(viewers[3]:GetAlpha()==0)
native[viewers[3]].editing=true;layout(viewers[3]);assert(viewers[3]:GetAlpha()==.37)
native[viewers[3]].editing=false;layout(viewers[3]);assert(viewers[3]:GetAlpha()==0)
-- Native pool rebuild and reparenting require no mixin fields or refresh calls.
local added=widget(native[viewers[3]].children[1]);layout(viewers[3]);assert(not native[added].motion and not native[added].click)
native[added].parent=UIParent;E.ApplyCooldownVisibility();assert(native[added].motion and native[added].click)
-- Restricted property values are neither compared nor passed back into setters.
local secret={};issecretvalue=function(v)return v==secret end
native[viewers[2]].alpha=secret;E.ApplyCooldownVisibility();assert(native[viewers[2]].alpha==secret)
native[viewers[2]].alpha=.6;E.ApplyCooldownVisibility();assert(viewers[2]:GetAlpha()==0);issecretvalue=nil
-- Frames supplied by a load-on-demand addon after enable are handled immediately.
local old=viewers[2];UtilityCooldownViewer=nil;E.ApplyCooldownVisibility();assert(math.abs(old:GetAlpha()-.6)<1e-10)
local late=widget(UIParent,.9);UtilityCooldownViewer=late;Mock.event('ADDON_LOADED','Blizzard_CooldownViewer');assert(late:GetAlpha()==0)
print('PASS: default-off CDM toggle, real Save/Cancel/Close, four viewers, nested mouse suppression, exact restoration, native pool refresh, late load, restricted values and Edit Mode/settings reveal')

local before=E.Copy(EpicastDB);local effect=E.GetEntry('spells','arcane').addedEffectSlots[4]
C_UnitAuras={GetPlayerAuraBySpellID=function()error('restricted')end,GetAuraDataBySpellName=function()error('restricted')end}
Mock.combat=true
for i=1,3 do
 native[clearcasting].active=true;assert(E.ReadCooldownBuff(false,'druidClearcasting')==true and viewers[4]:GetAlpha()==0)
 native[icon].active=true;Mock.advance(.11);assert(E.ReadCooldownBuff()==true and effect.boundPlaying and viewers[3]:GetAlpha()==0)
 native[clearcasting].active=false;assert(E.ReadCooldownBuff(false,'druidClearcasting')==false)
 native[icon].active=false;Mock.event('UNIT_AURA','player');Mock.advance(.34);assert(E.ReadCooldownBuff()==false and not effect.castVisible)
end
-- Hidden/disabled native viewers still fail closed; Epicast must not resurrect them.
native[icon].active=true;shown(viewers[3],false);Mock.event('CVAR_UPDATE','cooldownViewerEnabled')
local state=E.ReadCooldownBuff();assert(state==nil and not viewers[3]:IsShown()and not native[viewers[3]].events)
shown(viewers[3],true);Mock.advance(.11);assert(E.ReadCooldownBuff()==true and viewers[3]:GetAlpha()==0)
-- Protect input mutations during combat and reconcile them after combat ends.
local protected,ps=widget(native[viewers[3]].children[1]);ps.protected=true;layout(viewers[3]);assert(ps.motion and ps.click)
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0);assert(not ps.motion and not ps.click)
E.OpenOptions();assert(p.hideCooldown.enabled);Mock.combat=true;E.RefreshOptions();assert(not p.hideCooldown.enabled)
p.hideCooldown:Click();assert(E.draft.hideCooldownManager)
Mock.combat=false;E.RefreshOptions();p.hideCooldown:Click();p.save:Click()
assert(not EpicastDB.hideCooldownManager and viewers[3]:GetAlpha()==.37 and late:GetAlpha()==.9)
assert(ps.motion and ps.click and not native[icon].motion,'Restore preexisting input settings')
assert(E.GetAddedEffects(before.content.classes.MAGE.slots.arcane)[4].binding.spell==E.GetAddedEffects(EpicastDB.content.classes.MAGE.slots.arcane)[4].binding.spell)
print('PASS: alpha-zero Barrage/Clearcasting tracking/retrigger, disabled-viewer rejection, no forced enable/CVar/mixin mutation, protected combat deferral and persisted toggle')
