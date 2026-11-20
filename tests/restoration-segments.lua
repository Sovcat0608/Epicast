local E=...
Mock.class="DRUID"
Mock.event("ADDON_LOADED","Epicast");Mock.advance(0)
E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest("spells","restoration");E.EffectLibrary.Open()
local p=E.EffectLibrary.window
local s=p.layerControls
p.tabs.config:Click()
local c=E.GetEffectLibraryTarget()
E.SetCrestEnabled(E.draft,"spells","restoration",true)
local studio=E.EditStudioState(c)
studio.artworkBindings={}
E.PreviewLibraryChange();p.RefreshTarget();Mock.advance(0)

local function row(items,key,id)
 for _,button in ipairs(items)do
  if button:IsShown()and button[key]==id then return button end
 end
 error("Missing visible row "..id)
end
local function position(id)return E.FindStudioLayer(c,id).rank end
local function showLayer(id)
 s.selectedID=id;s.noLayer=false;s.Reveal();s.Refresh()
 return row(s.rows,"layerID",id)
end
local function render(entry)
 entry.restorationSegments.driver:emit("OnUpdate")
end
assert(#E.GetArtworkLayers(c)==22 and p.crestPreview.artworkSegmentsActive)
assert(not p.crestPreview.restorationSegments.layers.leftCheek.frame:IsShown())
assert(not p.crestPreview.restorationSegments.layers.rightCheek.frame:IsShown())
assert(p.crestPreview.restorationSegments.layers.treant.idle.texture)
assert(#E.GetStudioLayers(c)==22+#E.GetAddedEffects(c))
s.filters.all:Click();assert(s.filter=="all")
showLayer("backboard"):Click()
assert(s.filter=="all" and not s.up.enabled and not s.down.enabled)
assert(not E.MoveStudioLayer(c,"backboard",1))
local effect=E.GetStudioLayers(c)[#E.GetStudioLayers(c)]
assert(effect.kind=="effect")
showLayer(effect.id):Click()
while position(effect.id)>position("backboard")+1 do
 assert(s.down.enabled);s.down:Click()
end
assert(position("backboard")<position(effect.id) and position(effect.id)<position("roots"))
local preview=p.crestPreview
local layer=E.FindStudioLayer(c,effect.id)
local scene=preview.addedEffectSlots[layer.index].nativeSmoke.slots[1].scene
local rendered=preview.restorationSegments.layers
assert(rendered.backboard.frame:GetFrameLevel()<scene:GetFrameLevel())
assert(scene:GetFrameLevel()<rendered.roots.frame:GetFrameLevel())

local touch=E.AddStudioSpell(c,"5185")
local regrowth=E.AddStudioSpell(c,"8936")
local clearcasting=E.AddStudioSpell(c,"16870")
s.Changed()
local function revealSpell(id)
 s.spells.revealSpell=id;s.Refresh()
end
showLayer("leftFeathers"):Click()
s.spells.enterBinding:Click()
revealSpell(touch)
row(s.spells.rows,"spellID",touch):Click()
revealSpell(regrowth)
row(s.spells.rows,"spellID",regrowth):Click()
s.spells.saveBinding:Click()
assert(s.filter=="all" and not s.quick and s.selectedID=="leftFeathers")
revealSpell(touch)
assert(row(s.spells.rows,"spellID",touch).relationship=="blue")
assert(E.StudioSpellUsage(c,"5185")==1)
local function openMapping(id)
 if s.spells.mappingID==id then return end
 revealSpell(id)
 row(s.spells.gears,"spellID",id):Click()
 assert(s.spells.mapping:IsVisible())
end
local function mappingRow(layerID)
 s.spells.mappingPage=1;s.spells.RefreshMapping()
 repeat
  for _,button in ipairs(s.spells.mappingRows)do
   if button:IsShown()and button.layerID==layerID then return button end
  end
  if not s.spells.mappingNext.enabled then break end
  s.spells.mappingNext:Click()
 until false
 error("Missing mapped layer "..layerID)
end
local function map(spell,layerID,state,trigger)
 openMapping(spell)
 s.spells.triggers[trigger]:Click()
 local option=mappingRow(layerID)[state]
 assert(option:IsVisible() and not option:GetChecked())
 option:Click();assert(option:GetChecked())
end
map(regrowth,"leftFeathers","impact","success")
map(touch,"leftFeathers","channel","cast")
row(s.spells.gears,"spellID",touch):Click()
assert(not s.spells.mapping:IsShown())
assert(not E.BindStudioSpells(c,{backboard=true},{[regrowth]=true}))
assert(E.StudioSpellUsage(c,"8936")==1 and not E.RemoveStudioSpell(c,regrowth))
local function bindMore()
 revealSpell(touch)
 if s.spells.selected~=touch then row(s.spells.rows,"spellID",touch):Click()end
 s.spells.enterBinding:Click()
 -- One spell can drive a native effect and several independent segments.
 local function pick(id)
  s.selectedID=id;s.Reveal();s.selectedID=nil;s.Refresh()
  row(s.rows,"layerID",id):Click()
 end
 pick("leftSlats");pick("rightFeathers");pick(effect.id)
 s.spells.saveBinding:Click()
end
bindMore()
assert(E.StudioSpellUsage(c,"5185")==4)
map(touch,"leftSlats","channel","cast")
map(touch,"rightFeathers","channel","cast")
assert(not mappingRow("leftSlats").impact:IsShown())

Mock.advance(0)
local live=E.GetEntry("spells","restoration")
assert(live.artworkSegmentsActive)
rendered=live.restorationSegments.layers
assert(rendered.backboard.idle:IsShown() and not rendered.backboard.parts[3]:IsShown())
Mock.event("UNIT_SPELLCAST_START","player","cast-a",5185)
Mock.advance(.25);render(live)
assert(rendered.leftFeathers.response.kind=="channel" and rendered.rightFeathers.response.kind=="channel")
assert(rendered.leftSlats.action:IsShown()and rendered.leftSlats.offset<0)
assert(not rendered.rightSlats.response and not rendered.treant.response)
local halfStep=rendered.leftSlats.contactStep
assert(halfStep>0 and halfStep<#rendered.leftSlats.contacts.channel)
assert(rendered.leftSlats.idle.coords==rendered.leftSlats.contacts.idle[halfStep])
assert(rendered.leftSlats.action.coords==rendered.leftSlats.contacts.channel[halfStep])
for _,id in ipairs({"backboard","roots"})do
 local receiver=rendered[id]
 assert(not receiver.idle:IsShown() and receiver.parts[3]:IsShown() and receiver.parts[4]:IsShown())
 assert(receiver.parts[3].coords==receiver.contacts.left[halfStep])
 assert(receiver.parts[4].coords==receiver.receiverFrame)
end
Mock.advance(.25);render(live)
local holdStep=#rendered.leftSlats.contacts.channel
assert(rendered.leftSlats.contactStep==holdStep and rendered.roots.parts[3].coords==rendered.roots.contacts.left[holdStep])
Mock.event("UNIT_SPELLCAST_SUCCEEDED","player","cast-b",8936);render(live)
assert(rendered.leftFeathers.response.kind=="impact")
Mock.event("UNIT_SPELLCAST_INTERRUPTED","player","cast-a",5185)
assert(rendered.rightFeathers.response.ending==Mock.now)
assert(rendered.leftFeathers.response.kind=="impact")
Mock.advance(.25);render(live)
assert(rendered.leftSlats.contactStep==halfStep and rendered.backboard.parts[3].coords==rendered.backboard.contacts.left[halfStep])
Mock.advance(1.125);render(live)
assert(not rendered.leftFeathers.response and not rendered.rightFeathers.response and rendered.leftSlats.offset==0)
assert(rendered.leftFeathers.idle:IsShown())
assert(rendered.backboard.idle:IsShown() and not rendered.backboard.parts[3]:IsShown())
local roots=rendered.roots
assert(roots.idle:IsShown() or (roots.treantParts[5]:IsShown() and roots.parts[3].coords==roots.idleFrame))

assert(E.TestRestorationSegment(preview,"leftFeathers",{kind="channel"}))
assert(preview.restorationSegments.layers.leftFeathers.response.test and not rendered.leftFeathers.response)
E.StopBoundTests();render(preview)
assert(not preview.restorationSegments.layers.leftFeathers.response)
c.flip=true
E.PreviewLibraryChange();p.RefreshTarget()
assert(E.TestRestorationSegment(preview,"rightSlats",{kind="channel"}))
Mock.advance(.5);render(preview)
local flipped=preview.restorationSegments.layers
assert(flipped.rightSlats.offset<0 and flipped.rightSlats.action.mirrored)
assert(flipped.rightSlats.fabricAction.mirrored and flipped.rightSlats.fabricAction:IsShown())
assert(flipped.backboard.parts[3].coords==flipped.backboard.receiverFrame)
assert(flipped.backboard.parts[4].coords==flipped.backboard.contacts.right[holdStep])
assert(flipped.backboard.parts[4].point[4]==0 and flipped.backboard.parts[4].mirrored)
E.StopBoundTests();render(preview)
assert(flipped.backboard.idle:IsShown() and not flipped.backboard.parts[4]:IsShown())
c.flip=false

assert(E.BindStudioSpells(c,{treant=true},{[touch]=true}))
assert(E.StudioSpellUsage(c,"5185")==5)
s.Changed()
map(touch,"treant","channel","cast")
map(touch,"treant","channel","channel")
map(touch,"treant","impact","success")
assert(#E.GetStudioLayerBindings(E.FindStudioLayer(c,"treant"))==1)
assert(not E.SetStudioArtworkMapping(c,"leftSlats","5185","impact","success",true))
assert(not E.SetStudioArtworkMapping(c,effect.id,"5185","impact","success",true))
showLayer("treant"):Click()
s.tabs.playback:Click()
s.test:Click()
assert(#Mock.menu==2 and Mock.menu[1].name=="Test Channel" and Mock.menu[2].name=="Test Impact")
Mock.menu[2].choose()
assert(preview.restorationSegments.layers.treant.response.kind=="impact")
E.StopBoundTests()
local face=live.restorationSegments.layers.treant
for _,id in ipairs({"crownGlyph","rejuvenation"}) do
    local layer=live.restorationSegments.layers[id]
    assert(layer.data.hover and #layer.data.clips.idle.frames>1)
    assert(#layer.data.clips.channel.frames>1 and #layer.data.clips.impact.frames>1)
    assert(layer.lift and layer.lift~=0)
end
local faceRoots=live.restorationSegments.layers.roots
local faceChannel=face.data.clips.channel
assert(faceChannel.stages.holdFirst==9 and faceChannel.stages.releaseFirst==25 and #faceChannel.frames==33)
local function checkJawContact(kind,cel)
    local shadow=faceRoots.treantParts[5]
    assert(shadow:IsShown() and shadow.coords==faceRoots.contacts.treant.clips[kind][cel])
end
local function signal(event,guid)Mock.event("UNIT_SPELLCAST_"..event,"player",guid,5185);render(live)end
local function advance(dt)Mock.advance(dt);render(live)end
signal("START","ordinary")
assert(face.actionCel==1)
advance(.25);assert(face.response.kind=="channel" and face.action:IsShown())
assert(face.actionCel>=4 and face.actionCel<faceChannel.stages.holdFirst)
advance(.31);assert(face.actionCel>=faceChannel.stages.holdFirst and face.actionCel<faceChannel.stages.releaseFirst)
checkJawContact("channel",face.actionCel)
signal("SUCCEEDED","ordinary")
assert(face.response.kind=="impact" and not face.sustained)
signal("STOP","ordinary");assert(face.response.kind=="impact")
advance(.17);checkJawContact("impact",face.actionCel)
advance(1);assert(not face.response and face.idleCel==1 and not faceRoots.treantParts[5]:IsShown())

signal("START","interrupt")
advance(.25)
local releaseFrom=face.actionCel
signal("INTERRUPTED","interrupt")
assert(face.response.kind=="channel" and face.response.ending)
assert(face.releaseFromCel==releaseFrom)
checkJawContact("channel",releaseFrom)
advance(.22);assert(face.actionCel>=faceChannel.stages.releaseFirst)
checkJawContact("channel",face.actionCel)
advance(.4);assert(not face.response and face.idleCel==1 and not faceRoots.treantParts[5]:IsShown())

signal("CHANNEL_START","channel-first")
advance(.25);assert(face.response.kind=="channel" and face.sustained)
signal("SUCCEEDED","channel-first")
assert(face.response.kind=="impact" and face.sustained)
advance(1.1);assert(face.response.kind=="channel" and not face.response.ending)
signal("SUCCEEDED","channel-first");assert(face.response.kind=="channel")
signal("CHANNEL_STOP","channel-first");advance(.6);assert(not face.response and not face.sustained)

signal("SUCCEEDED","success-first")
signal("CHANNEL_START","success-first")
assert(face.response.kind=="impact" and face.sustained)
signal("STOP","success-first");assert(face.sustained)
signal("CHANNEL_STOP","success-first")
assert(face.response.kind=="impact" and not face.sustained)
advance(1.1);assert(not face.response)

assert(E.SetStudioArtworkMapping(c,"treant","5185","channel","success",true));s.Changed()
signal("SUCCEEDED","two-states");assert(face.response.kind=="impact")
advance(1.1);assert(face.response.kind=="channel")
advance(.55);assert(face.action:IsShown() and not face.response.ending)
advance(1);advance(.6);assert(not face.response)
assert(E.SetStudioArtworkMapping(c,"treant","5185","channel","success",false))
assert(E.SetStudioArtworkMapping(c,"treant","5185","channel","cast",false))
assert(E.SetStudioArtworkMapping(c,"treant","5185","channel","cast",true))
assert(E.BindStudioSpells(c,{treant=true},{[touch]=true}))

assert(E.BindStudioSpells(c,{leftFeathers=true,rightFeathers=true,rightSlats=true},{[clearcasting]=true}))
s.Changed()
map(clearcasting,"leftFeathers","channel","buff")
map(clearcasting,"rightFeathers","channel","buff")
map(clearcasting,"rightFeathers","impact","proc")
local nativeBuff=true
E.ReadCooldownBuff=function(_,key)
 if key=="druidClearcasting"then return nativeBuff,"matched"end
end
advance(.11);advance(.25)
assert(rendered.leftFeathers.response.kind=="channel" and rendered.rightFeathers.response.kind=="channel")
assert(not rendered.rightSlats.response)
assert(rendered.leftFeathers.action:IsShown() and rendered.rightFeathers.action:IsShown())
advance(.2);Mock.event("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",16870);render(live)
assert(rendered.rightFeathers.response.kind=="impact" and rendered.leftFeathers.response.kind=="channel")
advance(1.1);assert(rendered.rightFeathers.response.kind=="channel")
Mock.event("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",16870)
nativeBuff=false;advance(.11);advance(.6)
assert(not rendered.leftFeathers.response and not rendered.rightFeathers.response)
nativeBuff=nil;Mock.aura={spellId=16870}
Mock.event("UNIT_AURA","player");render(live)
assert(rendered.leftFeathers.response.kind=="channel")
Mock.aura=nil;Mock.event("UNIT_AURA","player");advance(.6)
assert(not rendered.leftFeathers.response)
map(clearcasting,"leftFeathers","channel","proc")
mappingRow("leftFeathers").channel:Click()
assert(not mappingRow("leftFeathers").channel:GetChecked())
assert(E.StudioSpellUsage(c,"16870")>=2)

-- The two independently clocked layers must select the same contact pose that
-- the cloth is drawing, regardless of which response started first.
E.SetArtworkSignalController(live.restorationSegments)
local function verifyFabric(shard,banner,pose)
 local data=shard.contacts.fabric
 assert(data.banner==banner and shard.offset~=nil)
 local frames=shard.frameOpacity==1 and data.channel or data.idle
 local patch=shard.frameOpacity==1 and shard.fabricAction or shard.fabricIdle
 assert(patch:IsShown() and patch.coords==frames[shard.contactStep*data.poseCount+pose])
 if shard.frameOpacity>0 and shard.frameOpacity<1 then
  assert(shard.fabricAction.coords==data.channel[shard.contactStep*data.poseCount+pose])
 end
end
local leftWood,rightWood=rendered.leftSlats,rendered.rightSlats
local leftCloth,rightCloth=rendered.leftBanner,rendered.rightBanner
local leftData,rightData=leftWood.contacts.fabric,rightWood.contacts.fabric
local function channel(art,age)
 art.sustained=true;art.response={kind="channel",at=Mock.now-age}
end
render(live)
verifyFabric(leftWood,"leftBanner",leftCloth.idleCel)
verifyFabric(rightWood,"rightBanner",rightCloth.idleCel)
channel(leftWood,.7);render(live)
verifyFabric(leftWood,"leftBanner",leftCloth.idleCel)
channel(leftCloth,.25);channel(rightCloth,.73);render(live)
local half=leftData.offsets.channel+leftCloth.actionCel
verifyFabric(leftWood,"leftBanner",half)
verifyFabric(rightWood,"rightBanner",rightData.offsets.channel+rightData.channelFrames+rightCloth.actionCel)
channel(rightWood,.25);advance(.28)
verifyFabric(leftWood,"leftBanner",leftData.offsets.channel+leftData.channelFrames+leftCloth.actionCel)
verifyFabric(rightWood,"rightBanner",rightData.offsets.channel+rightData.channelFrames+rightCloth.actionCel)

leftCloth.response={kind="impact",at=Mock.now-.09}
render(live)
verifyFabric(leftWood,"leftBanner",leftData.offsets.impact+leftCloth.actionCel)
verifyFabric(rightWood,"rightBanner",rightData.offsets.channel+rightData.channelFrames+rightCloth.actionCel)
leftWood.sustained=nil;advance(.2)
verifyFabric(leftWood,"leftBanner",leftData.offsets.impact+leftCloth.actionCel)
advance(.28)
assert(leftWood.contactStep>0 and leftWood.contactStep<holdStep)
verifyFabric(leftWood,"leftBanner",leftData.offsets.impact+leftCloth.actionCel)
advance(.6)
assert(leftWood.contactStep==0 and leftCloth.actionState=="channel")
leftCloth.sustained=nil;render(live);advance(.65)
verifyFabric(leftWood,"leftBanner",leftCloth.idleCel)
rightCloth.enabled=false;render(live)
verifyFabric(rightWood,"rightBanner",rightData.offsets.hidden)
assert(rightWood.contactStep==holdStep)
rightCloth.enabled=true;rightCloth.sustained=nil;rightWood.sustained=nil
render(live);advance(.65)
verifyFabric(rightWood,"rightBanner",rightCloth.idleCel)

-- The returning hems and their casts show exactly one pose right up to
-- the handoff. Each side then continues from its own matched Idle cel.
for _,side in ipairs({{leftCloth,leftWood,"leftBanner"},{rightCloth,rightWood,"rightBanner"}}) do
 local cloth,wood,id=unpack(side)
 cloth.response={kind="impact",at=Mock.now};cloth.sustained=false
 for i=1,12 do
  render(live)
  assert(cloth.actionCel==i and cloth.frameOpacity==1 and not cloth.idle:IsShown())
  verifyFabric(wood,id,wood.contacts.fabric.offsets.impact+i)
  advance(1/12+.000001)
 end
 assert(not cloth.response and cloth.idleCel==cloth.data.clips.impact.restIdleCel)
 verifyFabric(wood,id,cloth.idleCel)
end

local reju=rendered.rejuvenation
local function checkLeafRelease(age)
 channel(reju,age);render(live)
 local before=reju.actionCel
 reju.sustained=false;render(live)
 assert(reju.actionCel==before or (before==1 and reju.actionCel==33) or (before==17 and reju.actionCel==40))
 advance(.49)
 if age<.5 then assert(reju.actionCel==47)
 else assert(reju.actionCel==39 or reju.actionCel==46) end
 assert(not reju.idle:IsShown())
 advance(.02)
 assert(not reju.response and reju.idleCel==1 and reju.idle:IsShown() and not reju.action:IsShown())
 advance(.13);assert(reju.idleCel==2)
end
-- The painted Start advances at 24 fps, then Hold carries on from pose 13.
for i=0,11 do
 local age=(i+.1)/24
 channel(reju,age);render(live)
 assert(reju.actionCel==47+i and not reju.idle:IsShown())
 checkLeafRelease(age)
end
channel(reju,.501);render(live)
assert(reju.actionCel==13)
for i=0,31 do checkLeafRelease(.5+(i+.1)*reju.data.clips.channel.period/32) end
channel(reju,.82);render(live)
reju.response={kind="impact",at=Mock.now};reju.sustained=false
advance(.96)
assert(reju.actionCel==12 and reju.actionState=="impact" and not reju.idle:IsShown())
advance(.05)
assert(not reju.response and reju.idleCel==1)

local leafIDs={"leftAutumn","rightCrown","leftShoulder","rightShoulder","leftInner","rightInner"}
for _,bank in pairs(E.RestorationSegmentBanks) do
 for _,id in ipairs(leafIDs) do
  local clips=bank[id].clips
  assert(clips.idle.period==2 and #clips.idle.frames==16)
  assert(math.abs(clips.channel.period-1/3)<.000001 and #clips.channel.frames==16)
  assert(clips.impact.period==1 and #clips.impact.frames==12)
  assert(clips.impact.envelope[2]==1 and clips.impact.envelope[12]==0)
 end
end
for _,id in ipairs(leafIDs) do
 local leaf=preview.restorationSegments.layers[id]
 assert(E.TestRestorationSegment(preview,id,{kind="channel"}))
 Mock.advance(.54);render(preview)
 local channelCel=leaf.actionCel
 assert(leaf.action:IsShown() and channelCel>1 and leaf.action.coords==leaf.data.clips.channel.frames[channelCel])
 assert(E.TestRestorationSegment(preview,id,{kind="impact"}))
 assert(leaf.actionState=="impact" and leaf.actionCel==1)
 Mock.advance(.09);render(preview)
 assert(leaf.actionCel==2 and leaf.action.coords==leaf.data.clips.impact.frames[2])
 Mock.advance(.92);render(preview)
 assert(not leaf.action:IsShown() and leaf.idle:IsShown())
end

local json=E.ExportCrestBake(c)
assert(json:find('"version":5',1,true)and json:find('"artworkBindings"',1,true))
EpicastSegmentTestExport=json
print("PASS: state mappings, Clearcasting polling and aura fallback, and shard contact shading through cloth Idle, Channel, Impact and visibility changes")

