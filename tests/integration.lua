local E=...
local original={marker='EndCapper stays independent'};EndCapperDB=original
Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
assert(E.ready and EpicastDB.version==1 and E.instances.central.left.frame:IsShown()and not E.instances.edge.left.frame:IsShown())
assert(#E.artworks==2 and #E.EffectLibrary.Search('')==11 and #E.EffectLibrary.Search('166011')==0)
assert(EpicastDB.sets.central.role=='spells'and EpicastDB.sets.edge.role=='resources')
for _,central in ipairs({false,true})do for _,edge in ipairs({false,true})do for _,role in ipairs({'spells','resources'})do
 local d=E.Normalize(nil);d.sets.central.enabled=central;d.sets.edge.enabled=edge;E.AssignRole(d,'central',role)
 assert(d.sets.central.role~=d.sets.edge.role);assert(E.Normalize(d).sets.central.enabled==central and E.Normalize(d).sets.edge.enabled==edge)
end end end
local invalid=E.Normalize({sets={central={role='spells'},edge={role='spells'}}});assert(invalid.sets.edge.role=='resources')
local source=E.Copy(EpicastDB);source.content.spells.left.addedEffects[1].trailX=67;E.SwapRoles(source)
assert(E.GetSide(source,'edge','left').addedEffects[1].trailX==67 and source.sets.central.role=='resources')
assert(not E.NormalizeAddedEffect({fileID=166011}))
print('PASS: fresh defaults, exclusivity, all enabled/assignment combinations, role-following settings and Arcane-only scope')
E.devMode=true;E.OpenOptions();local p=E.panel
assert(p:IsShown()and not E.HasChanges());p.active.edge:Click();assert(E.draft.sets.edge.enabled and E.instances.edge.left.frame:IsShown())
local resource=E.instances.edge.left;assert(resource.resourceRatio==.7 and resource.resourceBar.value==.7)
Mock.health=15;Mock.event('UNIT_HEALTH','player');assert(resource.resourceRatio==.15)
local secret={};issecretvalue=function(v)return v==secret end;Mock.health=secret;Mock.event('UNIT_HEALTH','player');assert(resource.resourceRatio==nil and resource.resourceBar.text.text=='Health —')
Mock.health=70;issecretvalue=nil
do
 p.tabs.edge:Click()
 local left,right=E.instances.edge.left,E.instances.edge.right
 local rightSeal=right.mageSigils.host
 assert(rightSeal:IsShown())
 p.swapArt:Click()
 assert(left.config.art=='arcaneScroll' and right.config.art=='arcaneTome')
 assert(left.resourceBar.text.text=='Mana 40%' and right.resourceBar.text.text=='Health 70%')
 local leftSeal=left.mageSigils.host
 assert(leftSeal:IsShown() and not rightSeal:IsShown())
 Mock.mana=25;Mock.event('UNIT_POWER_UPDATE','player')
 assert(left.resourceBar.text.text=='Mana 25%' and math.abs(leftSeal:GetAlpha()-.3*(.12+.88*.25))<1e-9)
 Mock.mana=40
 p.swapArt:Click()
 assert(right.mageSigils.host==rightSeal and rightSeal:IsShown() and not leftSeal:IsShown())
 assert(left.resourceBar.text.text=='Health 70%' and right.resourceBar.text.text=='Mana 40%')
 p.tabs.central:Click()
end
p.swapRoles:Click();assert(E.draft.sets.central.role=='resources'and E.draft.sets.edge.role=='spells')
assert(E.instances.central.left.resourceRatio==.7 and E.instances.edge.left.config.role=='spells')
assert(not E.instances.central.left.addedEffectSlots[1].boundConfig)
E.SaveEffectStudio();assert(not E.HasChanges()and EpicastDB.sets.central.role=='resources')
p.sliders.y:SetValue(50);assert(E.HasChanges());E.CancelEffectStudio();assert(E.draft.sets.central.y==0 and not E.HasChanges())
print('PASS: real options, both sets, resource reaction/secrecy, sister and role swaps, Save/Cancel and resource spell exclusion')
E.editorSet='edge';E.editorSide='left';E.RefreshOptions();E.EffectLibrary.Open();Mock.advance(0)
local studio=E.EffectLibrary.window;assert(studio:IsShown()and studio.preview.state=='ready')
local c=E.GetEffectLibraryTarget();local count=#c.addedEffects;studio.addBound:Click();assert(#c.addedEffects==count+1)
local ui=studio.layerControls.bindingUI;ui.spell:SetText('Arcane Explosion');ui.bind:Click();assert(c.addedEffects[count+1].binding.spell=='Arcane Explosion')
ui.kind:Click();assert(#Mock.menu==6);Mock.menu[5].choose();assert(c.addedEffects[count+1].binding.kind=='buff')
ui.tabs.animation:Click();ui.segments[0]:Click();studio.custom:Click();assert(p.custom.parent==studio and p.custom:IsShown())
studio.custom:Click();assert(not p.custom:IsShown());studio:Hide();assert(p.custom.parent==p and p.custom:IsShown())
E.editorSet='central';E.RefreshOptions();E.EffectLibrary.Open();assert(not studio.addBound.enabled)
assert(not E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166009,behavior='bound'}))
studio:Hide();E.CancelEffectStudio();E.editorSet='edge';E.RefreshOptions()
print('PASS: studio opens on allowed model, spell/buff authoring, segment selection, custom docking and resource restrictions')
local entry=E.instances.edge.left;local fx=entry.addedEffectSlots[4]
Mock.event('UNIT_SPELLCAST_START','player','blast',30451);assert(fx.castVisible)
Mock.event('UNIT_SPELLCAST_STOP','player','blast',30451);assert(not fx.castVisible)
local proc=entry.addedEffectSlots[5]
for i=1,3 do Mock.aura={name='Missile Barrage',spellId=400589};Mock.event('UNIT_AURA','player');assert(proc.castVisible);Mock.aura=nil;Mock.event('UNIT_AURA','player');assert(not proc.castVisible)end
local scroll=E.instances.edge.right;local channel=scroll.addedEffectSlots[7];local pulse=scroll.addedEffectSlots[6]
Mock.event('UNIT_SPELLCAST_CHANNEL_START','player',nil,5143);assert(channel.castVisible)
for i=1,5 do Mock.advance(.5);Mock.event('UNIT_SPELLCAST_SUCCEEDED','player',nil,7268);assert(pulse.castVisible)end
Mock.event('UNIT_SPELLCAST_INTERRUPTED','player',nil,5143);assert(not channel.castVisible and not pulse.castVisible)
Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED');assert(not entry.handle:IsShown())
local prior=E.draft.sets.edge.enabled;p.active.edge:Click();assert(E.draft.sets.edge.enabled==prior)
E.Apply();assert(E.pending);Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED');Mock.advance(0);assert(not E.pending)
print('PASS: live event routing, repeated buff procs, five observed missiles, interruption, combat edit guards and deferred reconciliation')
local tex=CreateFrame('Texture');tex:SetAlpha(.7);MainActionBar={EndCaps={LeftEndCap={Texture=tex}}}
E.UpdateBlizzardVisibility();assert(tex:GetAlpha()==.7)
E.draft.hideBlizzard=true;E.Apply();assert(tex:GetAlpha()==0)
tex:SetAlpha(.4);Mock.advance(0);assert(tex:GetAlpha()==0)
E.draft.hideBlizzard=false;E.Apply();assert(tex:GetAlpha()==.4)
E.SaveEffectStudio();p:Hide();assert(E.draft==nil and EndCapperDB==original)
assert(E.instances.edge.left.frame.parent==UIParent and E.instances.central.left.frame.parent==UIParent)
Mock.class='WARRIOR';E.Apply();assert(not E.instances.edge.left.frame:IsShown())
Mock.class='MAGE';E.Apply();assert(E.instances.edge.left.frame:IsShown())
local book=E.instances.edge.left.mageBooks
assert(book.book.SetSnapToPixelGridArgs[1]==false and book.book.SetTexelSnappingBiasArgs[1]==0)
assert(book.motions[1].legs[1].SetDurationArgs[1]==3 and book.motions[1].legs[2].SetDurationArgs[1]==3)
assert(#book.frameTextures==2 and book.textureSize>=192)
print('PASS: optional native hide/restore, no EndCapper state writes, independent UIParent ownership, class gating and inherited floating fidelity')
-- A manual test must target the selected physical set, even when both sets
-- display the same artwork. Disabling or removing a layer cancels its timers.
E.OpenOptions();E.editorSet='central';E.editorSide='left'
assert(not E.TestBoundEffect('left','arcaneTome',4))
E.editorSet='edge';assert(E.TestBoundEffect('left','arcaneTome',4))
local target=E.instances.edge.left.addedEffectSlots[4]
assert(target.boundTest and target.castVisible)
E.draft.sets.edge.enabled=false;E.Apply();Mock.advance(5)
assert(not target.castVisible and not target.boundPlaying)
Mock.event('UNIT_SPELLCAST_START','player','hidden-blast',30451)
assert(not target.castVisible)
Mock.event('UNIT_SPELLCAST_STOP','player','hidden-blast',30451)
E.draft.sets.edge.enabled=true;E.Apply()
local c=E.GetEffectLibraryTarget();local row=c.addedEffects[4]
row.binding.intro=true;row.binding.outro=true;row.binding.introDuration=.2;row.binding.outroDuration=.2
E.Apply();assert(E.TestBoundEffect('left','arcaneTome',4))
Mock.advance(.25);assert(target.castVisible)
table.remove(c.addedEffects,4);E.Apply();Mock.advance(5)
assert(not target.boundTest and not target.castVisible)
E.CancelEffectStudio();assert(#E.GetEffectLibraryTarget().addedEffects==6)
print('PASS: manual trigger isolation, disabled-set event isolation, removal/intro timer cancellation and restored bindings')
-- Persistence normalization is idempotent, including deliberate empty effect
-- lists, disabled sets and per-role resource tuning.
local d=E.Normalize(nil);d.sets.central.enabled=false;d.sets.edge.enabled=true
d.content.spells.left.addedEffects={};d.content.resources.left.resource='energy'
d.sets.edge.leftX=123;d.sets.edge.y=44;E.SwapRoles(d)
EpicastDB=E.Normalize(d);E.draft=nil;E.Begin();assert(not E.HasChanges())
assert(#E.draft.content.spells.left.addedEffects==0 and E.draft.content.resources.left.resource=='energy')
assert(E.draft.sets.edge.leftX==123 and E.draft.sets.edge.y==44 and not E.draft.sets.central.enabled)
local bad=E.Normalize({sets={central={size=0/0,x=math.huge}},content={resources={left={addedEffects={E.AddedEffectDefaults.arcaneTome[4]}}}}})
assert(bad.sets.central.size==100 and bad.sets.central.x==0)
assert(bad.content.resources.left.addedEffects[1].behavior=='static'and bad.content.resources.left.addedEffects[1].binding==nil)
E.Apply();local edge=E.instances.edge.left;local oldX=E.draft.sets.edge.leftX
Mock.cursorX=100;Mock.cursorY=100;edge.handle:emit('OnDragStart')
Mock.cursorX=127;Mock.cursorY=112;edge.handle:emit('OnUpdate');edge.handle:emit('OnDragStop')
assert(E.draft.sets.edge.leftX==oldX+27 and E.HasChanges())
E.CancelEffectStudio();assert(E.draft.sets.edge.leftX==oldX)
Mock.maximum=0;assert(E.ReadResource('mana')==nil);Mock.maximum=100
print('PASS: reload-equivalent persistence, empty-list preservation, malformed-value recovery, resource binding removal and drag rollback')
