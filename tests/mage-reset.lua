local E=...
-- In-memory fixtures only. Artwork retirement must not discard native effects.
assert(E.UpdateMageBooks==nil and E.UpdateMageCrests==nil and E.UpdateMageSigils==nil)
for _,id in ipairs({'arcaneTome','arcaneScroll'})do
 local art=E.artworkByID[id];assert(art.pending and art.path==nil)
 assert(not E.HasCustomArtwork({art=id}))
end
local original=E.Normalize(nil)
for _,key in ipairs({'fire','frost','arcane'})do
 local c=original.content.classes.MAGE.slots[key]
 c.size=137;c.x=415;c.y=93;c.flip=true
 c.floatingScroll={size=125,x=19,y=-87}
 c.addedEffects={{fileID=166009,behavior='bound',trailX=42,trailOpacity=31,scale=1.7,
  binding={kind=key=='arcane'and'proc'or'success',spell=key=='arcane'and'400588'or'1449'}}}
 original.content.classes.MAGE.active[key]=true
end
local result=E.Normalize(original)
for _,key in ipairs({'fire','frost','arcane'})do
 local c=result.content.classes.MAGE.slots[key];local fx=c.addedEffects[1]
 assert(c.size==137 and c.x==415 and c.y==93 and c.flip and result.content.classes.MAGE.active[key])
 assert(c.floatingScroll==nil and original.content.classes.MAGE.slots[key].floatingScroll.x==19)
 assert(#c.addedEffects==1 and fx.fileID==166009 and fx.trailX==42 and fx.trailOpacity==31 and fx.scale==1.7)
 assert(fx.binding.kind==(key=='arcane'and'buff'or'success'))
 assert(fx.binding.spell==(key=='arcane'and'400589'or'1449'))
end
assert(E.CrestLabel(result,'resources','left')=='Resource 1'and E.CrestLabel(result,'resources','right')=='Resource 2')
E.SetAuthoringClass('DRUID');E.SetCrestEnabled(E.draft,'spells','balance',true);E.SelectCrest('spells','balance');E.Apply()
assert(E.GetEntry('spells','balance').druidSister.host:IsVisible())
for _,frame in ipairs(Mock.frames)do
 local texture=frame.texture
 if type(texture)=='string'then
  for _,name in ipairs({'MageFire','MageFrost','MageArcane','Arcane'})do assert(not texture:find('Media\\'..name,1,true),'Retired Mage texture was requested: '..texture)end
 end
end
print('PASS: retired Mage artwork absent, native tuning/selection preserved, Barrage repaired, retired overlay settings dropped, and Druid rendering retained')
