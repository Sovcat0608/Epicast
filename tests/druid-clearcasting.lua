local E=...
Mock.class='DRUID'
Mock.event('ADDON_LOADED','Epicast');Mock.advance(0);E.panel:Hide()
local db=EpicastDB
local function layer(id,spell,kind)
 return E.NormalizeAddedEffect({fileID=id,behavior='bound',binding={kind=kind or 'buff',spell=spell,duration=1}})
end
db.content.classes.DRUID.slots.balance.addedEffects={layer(166009,'16870'),layer(166011,'Clearcasting'),layer(166062,'400589')}
db.content.classes.DRUID.slots.restoration.addedEffects={layer(166012,'Regrowth','cast'),layer(166033,'Healing Touch','success')}
E.Apply();Mock.advance(0)
local left,right=E.instances.central.left,E.instances.central.right
local first,second,barrage=unpack(left.addedEffectSlots)
local function visible(wanted)
 for _,e in ipairs({first,second})do assert(e.castVisible==wanted and e.boundPlaying==wanted,'Both Druid Clearcasting layers must follow the native buff: '..tostring(wanted))end
end
local saved=E.Copy(EpicastDB)
local function forbidden()error('Native state was mutated or private aura data inspected')end
local secret=setmetatable({},{__index=forbidden})
issecretvalue=function(v)return v==secret end
issecrettable=function(v)return v==secret end
C_UnitAuras={GetPlayerAuraBySpellID=function()error('Aura restricted in combat')end,GetAuraDataBySpellName=function()error('Aura restricted in combat')end,GetAuraDataByIndex=function()error('Aura restricted in combat')end}
local names=C_Spell.GetSpellName
C_Spell.GetSpellName=function(id)if id==16870 then return 'Clearcasting'elseif id==16864 then return 'Omen of Clarity'elseif id==8936 then return 'Regrowth'elseif id==5185 then return 'Healing Touch'else return names(id)end end
local info={
 [81]={spellID=16864,linkedSpellIDs={16870},selfAura=false},
 [82]={spellID=400588,linkedSpellIDs={400589}},
 [83]={spellID=11213,linkedSpellIDs={12536}}, -- Mage Clearcasting must never match Druid.
}
local function icon(id,active)
 local item={cooldownID=id,isActive=active}
 function item:GetCooldownID()return self.cooldownID end
 function item:IsActive()return self.isActive end
 function item:HasEditModeData()return self.preview or false end
 for _,key in ipairs({'SetIsActive','RefreshData','GetAuraDataCached','GetAuraSpellID','Show','Hide','HookScript','SetScript'})do item[key]=forbidden end
 return setmetatable(item,{__index=function(_,key)if key=='auraInstanceID'then forbidden()end end})
end
local omen,missile,mage=icon(81,false),icon(82,true),icon(83,true)
local viewer={visible=true,editing=false,items={mage,omen,missile}}
function viewer:IsVisible()return self.visible end
function viewer:IsEditing()return self.editing end
function viewer:GetItemFrames()return self.items end
for _,key in ipairs({'SetLayoutData','RefreshData','Show','Hide','HookScript','SetScript','SetAlpha'})do viewer[key]=forbidden end
BuffIconCooldownViewer=viewer
local reads=0
C_CooldownViewer={GetCooldownViewerCooldownInfo=function(id)reads=reads+1;return info[id]end,SetLayoutData=forbidden}
Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED');Mock.event('UNIT_AURA','player')
visible(false);assert(barrage.castVisible)
local reloads,applies=0,0
E.Apply=function()applies=applies+1;error('Proc called full Apply')end
for _,entry in ipairs({left,right})do for _,e in ipairs(entry.addedEffectSlots)do
 e.nativeSmoke.slots[1].actor.SetModelByFileID=function()reloads=reloads+1;error('Proc reloaded model')end
end end
-- Native updates after Epicast's UNIT_AURA; repeated gain/consumption/expiry rearm.
for cycle=1,3 do
 omen.isActive=true;missile.isActive=false;reads=0;Mock.advance(.11)
 visible(true);assert(not barrage.castVisible,'A shared Barrage snapshot contaminated Clearcasting')
 assert(reads==6,'Each distinct proc should be sampled once per poll, not once per layer')
 assert(first.boundInput=='cooldown-active'and first.boundCooldown=='active')
 Mock.event('UNIT_SPELLCAST_START','player','heal-'..cycle,8936);visible(true);assert(right.addedEffectSlots[1].castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','heal-'..cycle,8936);assert(not right.addedEffectSlots[1].castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','touch-'..cycle,5185);assert(right.addedEffectSlots[2].castVisible)
 omen.isActive=false;missile.isActive=true;Mock.advance(.11);visible(false);assert(barrage.castVisible)
 Mock.event('UNIT_AURA',secret);visible(false)
end
-- Each recognized metadata field and native bar viewer use the same exact mapping.
BuffIconCooldownViewer=nil;BuffBarCooldownViewer=viewer
for _,metadata in ipairs({{spellID=16864},{spellID=16870},{overrideSpellID=16870},{overrideTooltipSpellID=16864},{spellID=1,linkedSpellIDs={16870}}})do
 info[81]=metadata;omen.isActive=true;Mock.advance(.11);visible(true)
end
omen.cooldownID=83;Mock.advance(.11);visible(false);assert(first.boundCooldown=='untracked')
omen.cooldownID=81;info[81]={spellID=16864};Mock.advance(.11);visible(true)
viewer.visible=false;Mock.advance(.11);visible(false);assert(first.boundCooldown=='hidden')
viewer.visible=true;viewer.editing=true;Mock.advance(.11);visible(false);assert(first.boundCooldown=='preview')
viewer.editing=false;omen.preview=true;Mock.advance(.11);visible(false)
omen.preview=false;omen.isActive=secret;Mock.advance(.11);visible(false);assert(first.boundCooldown=='restricted')
omen.isActive=nil;Mock.advance(.11);visible(false);assert(first.boundCooldown=='unknown')
omen.isActive=true;Mock.advance(.11);visible(true)
local name=C_Spell.GetSpellName
C_Spell.GetSpellName=function(id)if id==16870 then return 'Idées claires'else return name(id)end end
local row=layer(166009,'Idées claires');E.ConfigureBoundEffect(first,row);E.SyncBoundEffect(first);assert(first.castVisible)
C_Spell.GetSpellName=name
E.ConfigureBoundEffect(first,db.content.classes.DRUID.slots.balance.addedEffects[1]);E.SyncBoundEffect(first)
assert(E.IsCooldownBuffBinding({kind='buff',spell='16870'}))
assert(not E.IsCooldownBuffBinding({kind='proc',spell='16870'}),'Action glow and buff state must remain distinct')
assert(E.CooldownBuffHint({kind='proc',spell='16870'}):find('While buff active',1,true))
assert(E.CooldownBuffHint({kind='buff',spell='16870'}):find('Tracked Buffs',1,true))
Mock.class='MAGE';assert(not E.IsCooldownBuffBinding({kind='buff',spell='Clearcasting'}));Mock.class='DRUID'
-- Optional bridge failures cannot disable unrelated Druid cast/success effects.
local reader=E.ReadCooldownBuff
for _,replacement in ipairs({false,function()error('Native bridge unavailable')end})do
 E.ReadCooldownBuff=replacement or nil
 Mock.event('UNIT_AURA','player');visible(false)
 Mock.event('UNIT_SPELLCAST_START','player','safe-heal',8936);assert(right.addedEffectSlots[1].castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','safe-heal',8936);assert(not right.addedEffectSlots[1].castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','safe-touch',5185);assert(right.addedEffectSlots[2].castVisible)
end
E.ReadCooldownBuff=reader;Mock.advance(.11);visible(true)
-- Hidden viewers are diagnostic only; public exact aura reads still work.
BuffBarCooldownViewer=nil
C_UnitAuras={GetPlayerAuraBySpellID=function()return {spellId=16870,name='Clearcasting'}end,GetAuraDataBySpellName=function()return {spellId=16870,name='Clearcasting'}end}
Mock.event('UNIT_AURA','player');visible(true);assert(first.boundInput=='matched')
C_UnitAuras.GetPlayerAuraBySpellID=function()return nil end;C_UnitAuras.GetAuraDataBySpellName=function()return nil end
Mock.event('UNIT_AURA','player');visible(false)
BuffIconCooldownViewer=viewer;Mock.advance(.11);visible(true)
local report={};E.Message=function(message)report[#report+1]=message end;E.PrintBoundStatus()
local text=table.concat(report,'\n')
assert(text:find('Clearcasting native sample: active',1,true),text)
assert(text:find('Clearcasting matches=1',1,true),text)
assert(text:find('Triggers 0.1.0-beta.13',1,true),text)
Mock.event('PLAYER_DEAD');visible(false);reads=0;Mock.advance(.2);assert(reads==0)
omen.isActive=false;Mock.event('PLAYER_ALIVE');visible(false)
omen.isActive=true;Mock.advance(.11);visible(true)
E.ConfigureBoundEffect(first,nil);E.ConfigureBoundEffect(second,nil);E.ConfigureBoundEffect(barrage,nil)
E.StopBoundEffect(first);E.StopBoundEffect(second);E.StopBoundEffect(barrage);reads=0;Mock.advance(.2);visible(false);assert(reads==0)
local function equal(a,b)if type(a)~='table'or type(b)~='table'then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
assert(equal(saved,EpicastDB)and applies==0 and reloads==0,'Detection changed settings or model lifecycle')
print('PASS: Druid Clearcasting mapping, per-proc snapshots, repeated gains/losses, native safety, fallback, diagnostics and no model/settings mutation')
