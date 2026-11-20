local E=...
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true
end
Mock.class='DRUID'
local names={[8936]='Regrowth',[5185]='Healing Touch',[774]='Rejuvenation',[18562]='Swiftmend'}
local previous=C_Spell.GetSpellName
C_Spell.GetSpellName=function(id)return names[id]or previous(id)end
C_Spell.GetSpellInfo=function(v)for id,name in pairs(names)do if v==id or type(v)=='string'and v:lower()==name:lower()then return{name=name,spellID=id}end end end
EpicastDB=E.Normalize(nil);EpicastDB.content.classes.DRUID.configured=true
local c=EpicastDB.content.classes.DRUID.slots.restoration;c.x=175;c.y=23;c.size=121
c.addedEffects={};EpicastDB.version=5
Mock.event('ADDON_LOADED','Epicast');Mock.advance(0)
c=EpicastDB.content.classes.DRUID.slots.restoration
assert(c.x==175 and c.y==23 and c.size==121 and c.addedEffects==nil)
local shipped=E.CrestBakes['DRUID:restoration']
local expected=E.Copy(shipped.effects or shipped)
expected.studio=E.Copy(shipped.studio)
assert(#expected==9 and equal(E.GetAddedEffects(c),expected))
assert(#E.GetAddedEffects(EpicastDB.content.classes.DRUID.slots.balance)==0)
assert(#E.GetAddedEffects(EpicastDB.content.classes.DRUID.slots.feral)==0)
assert(#E.GetAddedEffects(EpicastDB.content.classes.MAGE.slots.arcane)==12)
local entry=E.GetEntry('spells','restoration');local fx=entry.addedEffectSlots
assert(entry.frame:IsVisible()and #fx==9)
for _,i in ipairs({4,9})do assert(not fx[i].boundConfig and fx[i].nativeSmoke.slots[1].scene:IsVisible())end
local saved=E.Copy(EpicastDB);local allocations=#Mock.frames
for _,row in ipairs(fx)do for _,slot in ipairs(row.nativeSmoke.slots)do slot.actor.SetModelByFileID=function()error('Cast-time model reload')end end end
for i=1,3 do
 Mock.event('UNIT_SPELLCAST_START','player','regrowth'..i,8936);assert(fx[6].castVisible and fx[6].boundSegment==0)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','regrowth'..i,8936);assert(fx[1].castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','regrowth'..i,8936);assert(not fx[6].castVisible)
 Mock.advance(1.1);assert(not fx[1].castVisible)
 Mock.event('UNIT_SPELLCAST_START','player','touch'..i,5185);assert(fx[2].castVisible and fx[2].boundSegment==0)
 Mock.advance(.51);assert(fx[2].boundSegment==158)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','touch'..i,5185);assert(fx[3].castVisible)
 Mock.event('UNIT_SPELLCAST_STOP','player','touch'..i,5185);assert(fx[2].boundSegment==159)
 Mock.advance(.51);assert(not fx[2].castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','rejuvenation'..i,774);assert(fx[5].castVisible and fx[7].castVisible)
 Mock.event('UNIT_SPELLCAST_SUCCEEDED','player','swiftmend'..i,18562);assert(fx[8].castVisible)
 Mock.advance(2);Mock.advance(.6)
end
assert(#Mock.frames==allocations and equal(saved,EpicastDB),'Recovered spell triggers changed frames or player preferences')
print('PASS: exact nine-layer Restoration bake, preference retention/class isolation, static accents and repeated Regrowth/Healing Touch/Rejuvenation/Swiftmend without cast-time reloads')
