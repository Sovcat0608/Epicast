local E=...
local function eq(a,b)if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end;for k,v in pairs(a)do if not eq(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function text(box,value)box:SetFocus();box:SetText(value);box:emit("OnTextChanged",true)end
EpicastDB=nil;Mock.event("ADDON_LOADED","Epicast");Mock.advance(0);E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest("spells","arcane")
local before=E.Copy(EpicastDB);E.EffectLibrary.Open();Mock.advance(.4)
local p=E.EffectLibrary.window;local s=p.layerControls;local c=E.GetEffectLibraryTarget()
local function spellRow(spell)
 local id
 for _,item in ipairs(E.GetStudioState(c).spells)do if item.spell==spell then id=item.id;break end end
 for _,b in ipairs(s.spells.rows)do if b:IsShown()and b.spellID==id then return b end end
end
assert(p.tab=="library"and p.pages.library:IsVisible()and not p.pages.config:IsVisible())
assert(p.add:GetText()=="Add effect layer"and not p.addBound and not p.custom)
p.tabs.config:Click();assert(p.tab=="config"and p.crestPreview.frame:IsVisible()and not p.preview.scene:IsShown())
assert(#E.GetStudioLayers(c)==13 and #E.GetStudioState(c).spells==4 and not E.HasChanges())
assert(p.crestPreview~=E.GetEntry("spells","arcane")and p.crestPreview.addedEffectSlots[1].nativeSmoke~=E.GetEntry("spells","arcane").addedEffectSlots[1].nativeSmoke)
local liveArcane=E.GetEntry("spells","arcane")
assert(E.GetArtworkPhase(liveArcane.artworkLayers.artwork)==E.GetArtworkPhase(p.crestPreview.artworkLayers.artwork))
local function checkViewports()
 for i,preview in ipairs(p.crestPreview.addedEffectSlots)do
  local previewSlot=preview.nativeSmoke.slots[1]
  local liveSlot=liveArcane.addedEffectSlots[i].nativeSmoke.slots[1]
  local a,b=previewSlot.scene,liveSlot.scene
  assert(a.width==b.width and a.height==b.height and a.width==a.height)
  assert(eq(a.SetCameraFieldOfViewArgs,b.SetCameraFieldOfViewArgs))
  assert(eq(a.SetCameraOrientationByAxisVectorsArgs,b.SetCameraOrientationByAxisVectorsArgs))
  assert(eq(a.SetViewInsetsArgs,b.SetViewInsetsArgs)and eq(a.SetViewTranslationArgs,b.SetViewTranslationArgs))
  assert(a.point[2]==p.crestPreview.art and a.point[4]==b.point[4] and a.point[5]==b.point[5])
  assert(previewSlot.actor.scale==liveSlot.actor.scale and eq(previewSlot.actor.SetPositionArgs,liveSlot.actor.SetPositionArgs))
 end
end
checkViewports();s.zoomIn:Click();s.zoomIn:Click();checkViewports()
p.crestStage.GetEffectiveScale=function()return .5 end
s.actualSize:Click();assert(p.crestPreview.frame.scale==2 and s.zoomLabel:GetText()=="Game · 100%");checkViewports()
s.fit:Click()
s.Select("fx2")
local staticPreview=p.crestPreview.addedEffectSlots[2].nativeSmoke.slots[1].scene
local staticLive=liveArcane.addedEffectSlots[2].nativeSmoke.slots[1].scene
local originalAlpha=staticLive:GetAlpha()
local function projectedX(scene)return scene.point[4]+scene.SetViewTranslationArgs[1]end
local function projectedY(scene)return scene.point[5]+scene.SetViewTranslationArgs[2]end
local originalX=projectedX(staticPreview)
text(s.inputs.trailX,"79.5");Mock.advance(0)
assert(projectedX(staticPreview)==originalX and not E.HasChanges())
text(s.inputs.trailX,"79");Mock.advance(0)
assert(projectedX(staticPreview)~=originalX and not E.HasChanges())
s.inputs.trailX:emit("OnEscapePressed");Mock.advance(0);assert(projectedX(staticPreview)==originalX)
text(s.inputs.trailOpacity,"0");Mock.advance(0)
assert(staticPreview:GetAlpha()==0 and staticLive:GetAlpha()==originalAlpha and not E.HasChanges())
text(s.inputs.trailOpacity,"-");Mock.advance(0);assert(staticPreview:GetAlpha()==originalAlpha)
s.inputs.trailOpacity:emit("OnEscapePressed");Mock.advance(0)
local originalLiveX=staticLive.point[4]
local originalSize=staticLive.width
local originalAngle=staticLive.SetCameraOrientationByAxisVectorsArgs
s.inputs.trailX.slider.Slider:SetValue(79)
s.inputs.trailY.slider.Slider:SetValue(-37);s.inputs.trailY.slider.Forward:Click()
s.inputs.trailOpacity.slider.Slider:SetValue(25);s.inputs.trailOpacity.slider.Back:Click()
s.inputs.trailSize.slider.Slider:SetValue(139);s.inputs.trailSize.slider.Forward:Click()
s.inputs.trailAngle.slider.Slider:SetValue(-30);s.inputs.trailAngle.slider.Back:Click()
Mock.advance(0)
assert(tonumber(s.inputs.trailY:GetText())==-36 and staticPreview:GetAlpha()==.24)
assert(tonumber(s.inputs.trailSize:GetText())==140 and tonumber(s.inputs.trailAngle:GetText())==-31)
assert(staticPreview.width~=originalSize and not eq(staticPreview.SetCameraOrientationByAxisVectorsArgs,originalAngle))
assert(staticLive.width==originalSize and eq(staticLive.SetCameraOrientationByAxisVectorsArgs,originalAngle))
assert(staticLive.point[4]==originalLiveX and staticLive:GetAlpha()==originalAlpha and p.saveAll:IsEnabled())
local savedPreviewX,savedPreviewY=projectedX(staticPreview),projectedY(staticPreview)
p.saveAll:Click();c=E.GetEffectLibraryTarget()
local savedLayer=E.GetAddedEffects(c)[2]
assert(savedLayer.trailX==79 and savedLayer.trailY==-36 and savedLayer.trailOpacity==24)
assert(savedLayer.trailSize==140 and savedLayer.trailAngle==-31)
assert(projectedX(staticPreview)==savedPreviewX and projectedY(staticPreview)==savedPreviewY and not E.HasChanges())
local function checkProjectionAndAlpha()
 checkViewports()
 assert(staticLive:GetAlpha()==.24 and staticPreview:GetAlpha()==.24)
end
checkProjectionAndAlpha();s.zoomIn:Click();checkProjectionAndAlpha();s.fit:Click()
s.inputs.trailSize.slider.Slider:SetValue(6);s.inputs.trailSize.slider.Back:Click();Mock.advance(0)
assert(tonumber(s.inputs.trailSize:GetText())==5 and staticPreview.width>0)
p.saveAll:Click();c=E.GetEffectLibraryTarget()
assert(E.GetAddedEffects(c)[2].trailSize==5 and staticPreview.width==staticLive.width)
E.CancelEffectStudio();c=E.GetEffectLibraryTarget();assert(not E.HasChanges())
s.Select("fx4")
local barrage=E.GetAddedEffects(c)[4].binding.spell
assert(not s.quick and not s.spells.selected and s.unbind.enabled)
assert(spellRow(barrage).relationship=="blue"and not spellRow(barrage).selected)
local boundPreview=p.crestPreview.addedEffectSlots[4]
assert(boundPreview.previewBound and not boundPreview.boundConfig and boundPreview.nativeSmoke.slots[1].scene:IsShown())
assert(liveArcane.addedEffectSlots[4].boundConfig and not liveArcane.addedEffectSlots[4].nativeSmoke.slots[1].scene:IsShown())
s.tabs.playback:Click();assert(boundPreview.boundConfig and not boundPreview.nativeSmoke.slots[1].scene:IsShown())
s.tabs.placement:Click();assert(boundPreview.previewBound and boundPreview.nativeSmoke.slots[1].scene:IsShown())
s.filters.bound:Click();assert(s.selectedID=="fx4"and not E.HasChanges()and p.crestPreview.addedEffectSlots[1].nativeSmoke)
for i,b in ipairs(s.rows)do assert(b:IsShown()==(i<=6));if b:IsShown()then assert(b.detail:GetText():match("^Bound"))end end
s.filters.static:Click();assert(s.selectedID~="fx4"and not s.unbind.enabled and not E.HasChanges())
assert(not s.spells.selected and not s.spells.saveBinding.enabled)
for i,b in ipairs(s.rows)do assert(b:IsShown()==(i<=6));if b:IsShown()then assert(b.detail:GetText()=="Static · always active")end end
s.filters.artwork:Click();assert(s.rows[1].layerID=="artwork"and not s.rows[2]:IsShown());s.Select("fx4")
s.unbind:Click();assert(E.GetAddedEffects(c)[4].behavior=="static"and not E.GetAddedEffects(c)[4].binding)
assert(not s.spells.selected and #E.GetStudioState(c).spells==4)
s.Select("fx4");s.spells.enterBinding:Click();spellRow(barrage):Click();s.spells.saveBinding:Click()
assert(E.GetAddedEffects(c)[4].binding.kind=="success")
E.CancelEffectStudio();c=E.GetEffectLibraryTarget();assert(not E.HasChanges())
-- Waiting room is usable on an empty crest, before adding any model.
E.SelectCrest("spells","fire");c=E.GetEffectLibraryTarget();assert(#E.GetAddedEffects(c)==0)
s.filters.bound:Click();assert(not s.selectedID and s.empty:GetText()=="No bound layers"and not s.remove.enabled)
text(s.spells.input,"1449");s.spells.add:Click();assert(#E.GetStudioState(c).spells==1 and #E.GetAddedEffects(c)==0 and not s.spells.saveBinding.enabled)
assert(not s.spells.selected);p.tabs.library:Click();p.search:SetText("166602");p.rows[1]:Click();Mock.advance(0);assert(p.add.enabled);p.add:Click()
c=E.GetEffectLibraryTarget();local row=E.GetAddedEffects(c)[1];assert(p.tab=="config"and row.behavior=="static"and not row.binding and row.layerID)
local id=row.layerID;assert(s.filter=="static"and s.selectedID==id and not s.spells.selected and not s.spells.saveBinding.enabled)
s.spells.enterBinding:Click()
s.spells.rows[1]:Click();assert(not s.spells.selected and s.spells.rows[1].selected and s.spells.saveBinding.enabled)
s.spells.rows[1]:Click();assert(s.selectedID==id and not s.spells.rows[1].selected and not s.spells.saveBinding.enabled)
s.spells.rows[1]:Click()
s.spells.saveBinding:Click();assert(row.behavior=="bound"and row.binding.spell=="1449"and row.binding.kind=="success")
s.tabs.playback:Click()
assert(not s.intro.enabled and not s.outro.enabled and row.animation==0)
s.test:Click();local previewFX=p.crestPreview.addedEffectSlots[1];assert(previewFX.boundTest)
assert(previewFX.nativeSmoke.slots[1].scene:GetParent()==p.crestPreview.frame)
local live=E.GetEntry("spells","fire");for _,fx in ipairs(live.addedEffectSlots or{})do assert(not fx.boundTest)end
s.stop:Click();assert(not previewFX.boundTest)
-- Save a bound effect from Placement, then compare both renderers on a real spell signal.
E.SetCrestEnabled(E.draft,"spells","fire",true);E.Apply()
s.tabs.placement:Click();s.inputs.trailOpacity.slider.Slider:SetValue(28);Mock.advance(0)
assert(previewFX.nativeSmoke.slots[1].scene:GetAlpha()==.28)
p.saveAll:Click();c=E.GetEffectLibraryTarget();row=E.GetAddedEffects(c)[1]
local liveFX=live.addedEffectSlots[1]
assert(liveFX.boundConfig and not liveFX.nativeSmoke.slots[1].scene:IsShown())
s.tabs.playback:Click()
-- A real event drives both renderers, without allocating a frame or reloading.
local frames=#Mock.frames;local actor=previewFX.nativeSmoke.slots[1].actor;local load=actor.SetModelByFileID;local reloads=0
actor.SetModelByFileID=function(...)reloads=reloads+1;return load(...)end
for i=1,4 do
 Mock.event("UNIT_SPELLCAST_SUCCEEDED","player","g"..i,1449)
 assert(previewFX.castVisible and liveFX.castVisible and liveFX.nativeSmoke.slots[1].scene:GetAlpha()==.28)
 Mock.advance(1.1)
end
assert(reloads==0 and #Mock.frames==frames)
-- Stable identities survive reordering and crossing the artwork's depth.
s.tabs.placement:Click();s.down:Click();assert(s.selectedID==id and E.GetStudioLayers(c)[1].id==id)
local scene=previewFX.nativeSmoke.slots[1].scene;local art=p.crestPreview.artworkLayers.artwork
assert(scene:GetFrameLevel()<art.host:GetFrameLevel());s.up:Click();assert(scene:GetFrameLevel()>art.host:GetFrameLevel())
s.lock:Click();assert(row.followArtwork=="artwork"and previewFX.motionSource==art)
local function updateFrames()
 for _,frame in ipairs(Mock.frames)do if frame:IsVisible()then frame:emit("OnUpdate",.1)end end
end
local motionSlot=previewFX.nativeSmoke.slots[1];local baseY=motionSlot.anchorY
local amplitude=art.host:GetHeight()*.012
local function sampleArtwork(source,phase,progress)
 source.startedAt=Mock.now;source.elapsed=phase
 source.legs[phase<3 and 1 or 2].GetSmoothProgress=function()return progress end
end
sampleArtwork(art,0,0);updateFrames();assert(scene.point[5]==baseY-amplitude)
sampleArtwork(art,1,.25);updateFrames();assert(scene.point[5]==baseY-amplitude*.5)
sampleArtwork(art,3,0);updateFrames();assert(scene.point[5]==baseY+amplitude)
s.lock:Click();updateFrames();assert(scene.point[5]==baseY and not row.followArtwork)
s.lock:Click();s.tabs.playback:Click();s.test:Click()
sampleArtwork(art,4,.75);updateFrames();assert(scene.point[5]==baseY-amplitude*.5)
s.stop:Click();assert(not scene:IsShown());local stoppedY=scene.point[5]
sampleArtwork(art,5,1);updateFrames();assert(scene.point[5]==stoppedY)
s.tabs.placement:Click();s.Select("artwork");assert(not s.remove.enabled and not s.lock.enabled and not s.spells.saveBinding.enabled)
text(s.inputs.trailOpacity,"43");Mock.advance(0);assert(E.GetStudioState(c).artwork.artwork.opacity==100 and art.host:GetAlpha()==.43)
s.inputs.trailOpacity:emit("OnEnterPressed");assert(E.GetStudioState(c).artwork.artwork.opacity==43 and art.host:GetAlpha()==.43)
s.enabled:Click();assert(art.host:GetAlpha()==0);s.enabled:Click();assert(art.host:GetAlpha()==.43)
s.Select(id);text(s.inputs.trailX,"31");E.SelectCrest("spells","frost");assert(E.GetAddedEffects(c)[1].trailX==31 and #E.GetAddedEffects(E.GetEffectLibraryTarget())==0)
E.SelectCrest("spells","fire");c=E.GetEffectLibraryTarget();s.Select(id);text(s.inputs.trailX,"invalid");E.SelectCrest("spells","frost");assert(E.editorSide=="fire")
s.inputs.trailX:emit("OnEscapePressed");assert(not s.inputs.trailX.dirty)
-- Add/remove/reorder does not remap selected/bound/motion identities.
p.tabs.library:Click();p.search:SetText("166009");p.rows[1]:Click();Mock.advance(0);p.add:Click()
local second=s.selectedID;assert(second~=id);s.Select(id);s.remove:Click();assert(#E.GetAddedEffects(c)==1 and E.GetAddedEffects(c)[1].layerID==second)
assert(E.StudioSpellUsage(c,"1449")==0 and #E.GetStudioState(c).spells==1)
local queued=E.AddStudioSpell(c,"Regrowth");assert(queued);E.PreviewLibraryChange();p.RefreshTarget()
s.Select(second);s.lock:Click();assert(E.GetAddedEffects(c)[1].followArtwork=="artwork")
-- Export/Save/Cancel all include waiting spells and artwork ordering, never preferences.
EpicastStudioTestExport=E.ExportCrestBake(c);assert(EpicastStudioTestExport:find('"version":2',1,true))
p.saveAll:Click();assert(not E.HasChanges()and eq(before,EpicastDB)==false) -- first-use configured flag only
local saved=E.Copy(EpicastDB);c=E.GetEffectLibraryTarget();local committed=E.Copy(E.GetAddedEffects(c))
text(s.inputs.trailY,"71");p.cancel:Click();assert(eq(E.GetAddedEffects(E.GetEffectLibraryTarget()),committed)and eq(saved,EpicastDB))
assert(not s.inputs.trailY.dirty)
E.SelectCrest("resources","left");assert(not s.spells.input.enabled and not s.spells.add.enabled and not s.lock.enabled)
assert(not E.AddStudioSpell(E.GetEffectLibraryTarget(),"1449"))
local resourceSlot=p.crestPreview.addedEffectSlots[1].nativeSmoke.slots[1]
assert(resourceSlot.scene:GetAlpha()>0)
p.crestPreview.addedEffectSlots[1].nativeWanted=false;Mock.event("UNIT_HEALTH","player");assert(resourceSlot.scene:GetAlpha()==0)
E.SelectCrest("spells","fire");c=E.GetEffectLibraryTarget();s.Select(second)
Mock.combat=true;Mock.event("PLAYER_REGEN_DISABLED");assert(not p.add.enabled and not p.saveAll.enabled and not s.enabled.enabled and not s.lock.enabled and not s.spells.saveBinding.enabled)
local old=E.Copy(E.GetAddedEffects(c));s.enabled:Click();s.lock:Click();p.tabs.library:Click();assert(eq(old,E.GetAddedEffects(c)))
Mock.combat=false;Mock.event("PLAYER_REGEN_ENABLED");Mock.advance(0)
p.close:Click();assert(not p:IsShown()and not p.crestPreview.frame:IsShown());for _,fx in ipairs(p.crestPreview.addedEffectSlots)do assert(not fx.boundConfig and not fx.nativeWanted and not fx.nativeSmoke.slots[1].scene:IsShown())end
E.panel:Hide();assert(#E.GetAddedEffects(E.GetSide(EpicastDB,"spells","fire"))==0 and eq(saved,EpicastDB))
-- A newly shipped v2 definition applies outside developer mode as well.
local shipped=E.Copy(committed);local studio=shipped.studio;shipped.studio=nil
E.CrestBakes["MAGE:fire"]={effects=shipped,studio=studio};E.authorSession=nil;E.authorDraft=nil;E.devMode=false
assert(loadfile("CrestEffects.lua"))("Epicast",E);E.SetCrestEnabled(EpicastDB,"spells","fire",true);E.Apply()
local installed=E.GetEntry("spells","fire");assert(E.GetAddedEffects(installed.config)[1].layerID==second and installed.mageReboot.host:GetAlpha()==.43)
assert(installed.addedEffectSlots[1].nativeSmoke.slots[1].scene:GetFrameLevel()>installed.mageReboot.host:GetFrameLevel())
local gameEffect=installed.addedEffectSlots[1];local gameSlot=gameEffect.nativeSmoke.slots[1]
assert(gameEffect.motionSource==installed.mageReboot)
sampleArtwork(installed.mageReboot,0,0);updateFrames();assert(gameSlot.scene.point[5]==gameSlot.anchorY-amplitude)
sampleArtwork(installed.mageReboot,3,0);updateFrames();assert(gameSlot.scene.point[5]==gameSlot.anchorY+amplitude)
assert(#E.GetStudioState(installed.config).spells==2)
print("PASS: two-tab effect workflow, unified depth/artwork selection, waiting-room binding, exact input ownership, live isolated preview, native motion phase, session transactions and combat/close cleanup")
