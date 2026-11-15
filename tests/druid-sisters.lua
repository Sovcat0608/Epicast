local E=...
local function equal(a,b)
 if type(a)~='table'or type(b)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
-- Upgrade an existing account without replacing Mage tuning or placements.
local legacy=E.Normalize(nil);legacy.version=1;legacy.content.druid=nil
legacy.sets.central.x=87;legacy.sets.edge.enabled=true
legacy.content.spells.left.addedEffects[4].trailX=33
legacy.content.resources.left.resource='rage'
local mage,resources,placement=E.Copy(legacy.content.spells),E.Copy(legacy.content.resources),E.Copy(legacy.sets)
EpicastDB=legacy;Mock.class='DRUID'
Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
assert(EpicastDB.version==2 and equal(EpicastDB.content.spells,mage)and equal(EpicastDB.content.resources,resources)and equal(EpicastDB.sets,placement))
local left,right=E.instances.central.left,E.instances.central.right
assert(left.config.art=='moonwarden'and right.config.art=='groveheart')
assert(left.frame:IsVisible()and right.frame:IsVisible(),'Druid art must remain visible with options closed')
assert(not E.instances.edge.left.frame:IsVisible(),'Existing Arcane resource class gate must remain intact')
assert(#left.config.addedEffects==0 and #right.config.addedEffects==0,'Do not inherit Mage effects on Druids')
assert(not left.mageBooks and not right.mageSigils)
local state=left.druidSister
assert(state.host:IsVisible()and state.hover.playing and state.textureSize==288)
assert(state.texture.SetSnapToPixelGridArgs[1]==false and state.texture.SetTexelSnappingBiasArgs[1]==0)
assert(state.texture:GetHeight()/state.texture:GetWidth()==4/3)
assert(state.legs[1].SetDurationArgs[1]==3 and state.legs[2].SetDurationArgs[1]==3)
assert(state.legs[1].SetSmoothingArgs[1]=='IN_OUT')
assert(math.abs(state.legs[1].SetOffsetArgs[2]-state.host:GetHeight()*.024)<1e-9)
Mock.advance(1.25);E.Apply();assert(math.abs(state.elapsed-1.25)<1e-9)
assert(state.hover.elapsed==state.elapsed and state.texture.uv[7]==288/512 and state.texture.uv[8]==384/512)
left.frame:Hide();local phase=state.elapsed;Mock.advance(2);left.frame:Show();assert(state.hover.elapsed==phase)
E.devMode=true;E.OpenOptions();local p=E.panel
assert(not p.custom:IsShown()and p.subject:GetText():find('Moonwarden',1,true))
p.motion:Click();assert(not state.hover.playing and state.host:IsShown()and state.host.point[5]==30)
p.motion:Click();assert(state.hover.playing and state.hover.elapsed==phase)
p.flip:Click();assert(state.texture.uv[1]==288/512)
p.sliders.size:SetValue(200);assert(state.textureSize==480 and state.texture:GetWidth()==324)
p.swapArt:Click();assert(left.config.art=='groveheart'and right.config.art=='moonwarden')
p.swapRoles:Click();assert(E.instances.edge.left.config.art=='moonwarden'and E.instances.central.left.config.art=='arcaneScroll')
assert(E.instances.edge.right.config.flip==false,'Edge placement must not mirror the approved front-facing Druid art by default')
p.tabs.edge:Click();E.EffectLibrary.Open();Mock.advance(0)
assert(not E.EffectLibrary.window.custom.enabled and not p.custom:IsShown())
-- New Druid spell layers are authored and saved in their own bank.
local target=E.GetEffectLibraryTarget()
local index=E.AddLibraryEffect(target,{fileID=166009,behavior='bound',binding={kind='success',spell='12345',duration=.2}})
assert(index==1);E.PreviewLibraryChange();Mock.advance(0)
Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','druid-test',12345)
assert(E.instances.edge.left.addedEffectSlots[1].castVisible)
E.SaveEffectStudio();assert(equal(EpicastDB.content.spells,mage)and equal(EpicastDB.content.resources,resources))
assert(EpicastDB.content.druid.left.addedEffects[1].binding.spell=='12345')
E.EffectLibrary.Close();p:Hide()
Mock.class='MAGE';E.Apply();Mock.advance(1)
assert(E.instances.edge.left.config.art=='arcaneTome'and not E.instances.edge.left.druidSister.host:IsShown())
assert(E.instances.edge.left.mageBooks.bookHost:IsVisible()and #E.GetSide(EpicastDB,'edge','left').addedEffects==6)
assert(E.GetSide(EpicastDB,'edge','left').addedEffects[4].trailX==33)
Mock.class='DRUID';E.Apply()
assert(E.instances.edge.left.druidSister.host:IsVisible()and not E.instances.edge.left.mageBooks.bookHost:IsShown())
assert(not E.instances.edge.left.addedEffectSlots[4].castVisible,'Old Mage layers must stay stopped')
E.OpenOptions();p.motion:Click();E.CancelEffectStudio()
assert(E.GetSide(E.draft,'edge','left').effects==true)
local normalized=E.Normalize(EpicastDB);assert(equal(normalized,E.Normalize(normalized)))
p:Hide();Mock.class='WARRIOR';E.Apply();assert(not E.instances.edge.left.frame:IsVisible())
EpicastDB.classOnly=false;E.Apply()
assert(E.instances.edge.left.config.art=='arcaneTome'and not E.instances.edge.left.druidSister.host:IsShown(),'Class toggle must never expose Druid art to other classes')
-- A malformed save cannot insert Druid artwork into Mage or Resources banks.
local invalid=E.Copy(EpicastDB);invalid.content.spells.left.art='moonwarden';invalid.content.resources.right.art='groveheart'
local fixed=E.Normalize(invalid);assert(fixed.content.spells.left.art=='arcaneTome'and fixed.content.resources.right.art=='arcaneScroll')
Mock.class='DRUID';EpicastDB=fixed;E.Apply()
local savedScreen=GetPhysicalScreenSize;GetPhysicalScreenSize=nil;E.Apply()
assert(E.instances.edge.left.druidSister.textureSize==768)
GetPhysicalScreenSize=savedScreen
print('PASS: Druid-only automatic selection, schema-1 preservation, isolated tuning, role/sister swaps, class transitions and native hover/UV/phase/static fallback')
