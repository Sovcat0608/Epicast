local E=...
local Viewer=E.EffectLibrary
local all=Viewer.Search('')
assert(#all==8723,'The library must contain the inspected Forever effects')
assert(#all==Viewer.catalogCount)
local seen={}
for _,entry in ipairs(all)do assert(not seen[entry.id]and entry.path:match('%.m2$'));seen[entry.id]=true end
assert(Viewer.Search(' 166011 ')[1].name=='Fire')
assert(Viewer.Search('RED eye trail')[1].id==166011)
assert(#Viewer.Search('druid')>0 and #Viewer.Search('frost')>0 and #Viewer.Search('particles/')>0)
assert(Viewer.Search('dalaran_eye_01.m2')[1].id==243044)
assert(#Viewer.Search('[%')==0)
for _,query in ipairs({'166046','603732','4294967295','0','4294967296','999999999999999999999999999999999999'})do assert(#Viewer.Search(query)==0,'Excluded numeric ID bypassed Forever filter: '..query)end
for _,id in ipairs({0,-1,1.5,4294967296,0/0,math.huge})do assert(not E.NormalizeAddedEffect({fileID=id}))end
assert(E.NormalizeAddedEffect({fileID=166011})and E.NormalizeAddedEffect({fileID=4294967295}))
Mock.class='DRUID';Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
E.devMode=true;E.OpenOptions();E.EffectLibrary.Open();Mock.advance(0)
local window=Viewer.window;local originalMage=E.Copy(EpicastDB.content.spells)
local frames=#Mock.frames;Viewer.Search('');Viewer.Search('nature');assert(#Mock.frames==frames,'Search must not preload every model')
window.search:SetText('166011');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state=='ready'and window.preview.actor.modelID==166011 and window.add.enabled)
window.addBound:Click();local c=E.GetEffectLibraryTarget()
assert(#c.addedEffects==1 and c.addedEffects[1].fileID==166011 and c.addedEffects[1].behavior=='bound')
c.addedEffects[1].binding.spell='12345';E.SaveEffectStudio()
assert(EpicastDB.content.druid.left.addedEffects[1].fileID==166011)
local saved=E.Normalize(EpicastDB)
assert(saved.content.druid.left.addedEffects[1].fileID==166011 and saved.content.spells.left.addedEffects[4].fileID==originalMage.left.addedEffects[4].fileID)
c=E.GetEffectLibraryTarget()
-- Unknown IDs clear a previously successful selection and cannot add that old model.
local actor=window.preview.actor;local originalLoad=actor.SetModelByFileID
window.search:SetText('4294967295');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and not window.addBound.enabled)
window.add:Click();assert(#c.addedEffects==1)
assert(not E.AddLibraryEffect(c,{fileID=4294967295}))
assert(not E.AddLibraryEffect(c,{fileID=166046}))
-- An allowed model still has to complete loading.
actor.SetModelByFileID=function()return false end
window.search:SetText('166011');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and not window.addBound.enabled)
window.add:Click();assert(#c.addedEffects==1)
actor.SetModelByFileID=originalLoad;Mock.loading=true
window.search:SetText('166032');window.search:emit('OnEnterPressed')
assert(window.preview.state=='loading'and not window.add.enabled)
local stale=actor.epicastLibraryLoaded
Mock.loading=false;window.search:SetText('166062');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state=='ready'and actor.modelID==166062)
stale();Mock.advance(.5);assert(window.preview.state=='ready'and actor.modelID==166062)
-- The client may report success/requested ID while rendering the error cube.
local originalBounds,originalPath=actor.GetMaxBoundingBox,actor.GetModelPath
actor.GetMaxBoundingBox=function()local n=.1388888955116272;return -n,-n,-n,n,n,n end
window.search:SetText('166032');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and not window.addBound.enabled)
assert(#Viewer.Search('166032')==0,'Detected placeholder remained selectable')
window.addBound:Click();assert(#c.addedEffects==1)
actor.GetMaxBoundingBox=originalBounds
actor.GetModelPath=function()return 'Spells\\ErrorCube.m2' end
window.search:SetText('166033');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and #Viewer.Search('166033')==0)
actor.GetModelPath=originalPath
actor.SetModelByFileID=function(self,id)originalLoad(self,id);self.modelID=166046;return true end
window.search:SetText('166034');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and #Viewer.Search('166034')==0)
actor.SetModelByFileID=originalLoad
-- Recheck at click time, even if the client changes a previously ready actor.
window.search:SetText('166062');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state=='ready')
actor.GetMaxBoundingBox=function()local n=.1388888955116272;return -n,-n,-n,n,n,n end
window.add:Click();assert(#c.addedEffects==1 and not window.add.enabled)
actor.GetMaxBoundingBox=originalBounds
window.search:SetText('166011');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state=='ready');window.add:Click();E.SaveEffectStudio()
assert(E.Normalize(EpicastDB).content.druid.left.addedEffects[2].fileID==166011)
-- Native Vector3 results, unreadable metadata, and retry after a transient failure.
local candidate=Viewer.Search('')[10].id
actor.GetMaxBoundingBox=function()
 local n=.1388888955116272
 return {GetXYZ=function()return -n,-n,-n end},{GetXYZ=function()return n,n,n end}
end
window.search:SetText(tostring(candidate));window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and #Viewer.Search(tostring(candidate))==0)
actor.GetMaxBoundingBox=function()error('Metadata unavailable')end
window.search:SetText('166011');window.search:emit('OnEnterPressed');Mock.advance(0)
assert(window.preview.state~='ready'and not window.add.enabled and #Viewer.Search('166011')==1)
actor.GetMaxBoundingBox=originalBounds
window.search:emit('OnEnterPressed');Mock.advance(0);assert(window.preview.state=='ready'and window.add.enabled)
-- Calling the preview directly cannot bypass the catalog or leave its prior actor visible.
window.preview:Load({id=4294967295},0)
assert(window.preview.state~='ready'and not window.preview.scene:IsShown()and not window.add.enabled)
E.panel.tabs.edge:Click();assert(not window.addBound.enabled)
assert(not E.AddLibraryEffect(E.GetEffectLibraryTarget(),{fileID=166011,behavior='bound'}))
E.panel:Hide()
print('PASS: Forever catalog, numeric filter, persistence, failed/stale previews, placeholder ID/path/bounds, click-time recheck and resource restrictions')
