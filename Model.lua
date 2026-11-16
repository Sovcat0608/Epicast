local _,E=...
E.schemaVersion=6
E.LegacyMageArtworks={arcaneTome=true,arcaneScroll=true}
E.MageSpecSlots={mageFire=true,mageFrost=true,mageArcane=true}
E.artworks={{id="arcaneTome",name="Resource 1",width=162,height=216,pending=true},
 {id="arcaneScroll",name="Resource 2",width=162,height=216,pending=true},
 {id="moonwarden",name="Moonwarden",width=162,height=216,path="Interface\\AddOns\\Epicast\\Media\\MoonwardenCASSize768.tga"},
 {id="groveheart",name="Groveheart",width=162,height=216,path="Interface\\AddOns\\Epicast\\Media\\GroveheartCASSize768.tga"},
 {id="druidRestoration",name="Restoration",width=162,height=216,path="Interface\\AddOns\\Epicast\\Media\\DruidRestorationCASSize660.tga"},
 {id="druidBalance",name="Balance",width=162,height=216,path="Interface\\AddOns\\Epicast\\Media\\DruidBalanceCASSize660.tga"},
 {id="druidFeral",name="Feral",width=162,height=216,path="Interface\\AddOns\\Epicast\\Media\\DruidFeralCASSize660.tga"},
 {id="none",name="Artwork pending",width=162,height=216,pending=true}}
for _,spec in ipairs({"Fire","Frost","Arcane"})do
 E.artworks[#E.artworks+1]={id="mage"..spec,name=spec,width=216,height=216,path="Interface\\AddOns\\Epicast\\Media\\MageReboot"..spec.."CASSize768.tga"}
end
E.DruidArtworks={moonwarden={name="Moonwarden",bounds={42,14,751,998}},groveheart={name="Groveheart",bounds={15,81,730,976}}}
E.DruidTextureSizes={192,288,384,480,576,768}
for _,v in ipairs({{"druidRestoration","DruidRestoration",{16,42,644,847}},{"druidBalance","DruidBalance",{30,29,630,847}},{"druidFeral","DruidFeral",{22,37,638,848}}})do
 E.DruidArtworks[v[1]]={name=v[2],bounds=v[3],sourceWidth=660,sourceHeight=880,sizes={192,288,384,480,576,660}}
end
E.artworkByID={};for _,v in ipairs(E.artworks)do E.artworkByID[v.id]=v end
E.Designs={arcane={name="Arcane",class="MAGE",specialization="Arcane",left="arcaneTome",right="arcaneScroll"},
 druid={name="Druid",class="DRUID",left="moonwarden",right="groveheart"}}
function E.SpellDesign()return E.ActiveClass()=="DRUID"and"druid"or"arcane"end
function E.SetAllowed(db,role,preview)
 local class=E.ActiveClass()
 if role=="spells"and E.ClassBank(db,class)then return true end
 return not db.classOnly or class=="MAGE"or preview
end
E.SetLabels={spells="Spellcasting",resources="Resources"}
E.RoleLabels={spells="Spellcasting",resources="Resources"}
E.ResourceKinds={{"health","Health"},{"mana","Mana",0},{"energy","Energy",3},{"rage","Rage",1},{"focus","Focus",2},{"runic","Runic power",6},{"power","Current power"}}
E.devEffectFields={{"trailSize","Effect size (%)",50,200},{"trailAngle","Effect angle (degrees)",-180,180},
 {"trailX","Origin X",-150,150},{"trailY","Origin Y",-150,150},{"trailOpacity","Effect opacity (%)",0,100}}
local function number(v,d,lo,hi)if type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return d end;return math.max(lo,math.min(hi,v))end
E.Number=number
-- Ownership is runtime metadata, never a field in saved player preferences.
E.CrestOwners=setmetatable({},{__mode="k"})
function E.Copy(v)if type(v)~="table" then return v end;local t={};for k,x in pairs(v)do t[k]=E.Copy(x)end;E.CrestOwners[t]=E.CrestOwners[v];return t end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~="table" then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function tableOr(v)return type(v)=="table" and v or {}end
function E.UV(c,flip)if not flip then return unpack(c)end;return c[5],c[6],c[7],c[8],c[1],c[2],c[3],c[4]end
function E.GetCapGeometry(c,flip)
 local mage=E.MageRebootArtworks[c.art]
 if mage then
  local b=mage.bounds;local w,h=mage.width*c.size/100,mage.height*c.size/100
  local cx=((b[1]+b[3])/(2*mage.sourceWidth)-.5)*w*(flip and -1 or 1)
  local cy=(.5-(b[2]+b[4])/(2*mage.sourceHeight))*h
  return w*(b[3]-b[1])/mage.sourceWidth,h*(b[4]-b[2])/mage.sourceHeight+2*h*.012,cx,30*c.size/100+cy
 end
 local druid=E.DruidArtworks[c.art]
 if druid then
  local b=druid.bounds;local w=162*c.size/100;local h=w*4/3
  local sw,sh=druid.sourceWidth or 768,druid.sourceHeight or 1024
  local cx=((b[1]+b[3])/(2*sw)-.5)*w*(flip and -1 or 1)
  local cy=(.5-(b[2]+b[4])/(2*sh))*h
  return w*(b[3]-b[1])/sw,h*(b[4]-b[2])/sh+2*h*.012,cx,30*c.size/100+cy
 end
 return 162*c.size/100,216*c.size/100,0,30*c.size/100
end
function E.HasCustomArtwork()return false end
E.AddedEffectLimit=32
function E.ValidEffectID(id)return type(id)=="number"and id>=1 and id<=4294967295 and id==math.floor(id)end
function E.NormalizeAddedEffect(v)
 if type(v)~="table" or not E.ValidEffectID(v.fileID)then return end
 local r={fileID=v.fileID,name=type(v.name)=="string" and v.name:sub(1,100)or("Model "..v.fileID),
 animation=math.floor(number(v.animation,0,0,65535)),scale=number(v.scale,1,.000001,10000),
 originX=number(v.originX,0,-100000,100000),originY=number(v.originY,0,-100000,100000),originZ=number(v.originZ,0,-100000,100000),
 azimuth=number(v.azimuth,0,-360,360),elevation=number(v.elevation,0,-90,90),desaturation=number(v.desaturation,0,0,1),effectLayer=v.effectLayer=="back" and "back"or"front",
 behavior=v.behavior=="bound" and "bound"or"static"}
 local defaults={100,90,0,0,70};for i,s in ipairs(E.devEffectFields)do r[s[1]]=number(v[s[1]],defaults[i],s[3],s[4])end
 if r.behavior=="bound" or type(v.binding)=="table" then
  local b=tableOr(v.binding);local kinds={cast=true,success=true,channel=true,pulse=true,buff=true,proc=true}
  r.binding={kind=kinds[b.kind]and b.kind or"success",spell=type(b.spell)=="string"and b.spell:sub(1,100):match("^%s*(.-)%s*$")or"",
   duration=number(b.duration,1,.05,60),intro=b.intro==true,outro=b.outro==true,introDuration=number(b.introDuration,.5,.05,10),outroDuration=number(b.outroDuration,.5,.05,10)}
 end
 -- This model has only Stand (0), not independent intro/hold/end segments.
 -- Preserve all placement/binding tuning while repairing earlier unverified IDs.
 if r.fileID==166602 then
  r.animation=0
  if r.binding then r.binding.intro=false;r.binding.outro=false end
 end
 return r
end
function E.AddLibraryEffect(c,value)
 if not E.devMode then return end;local r=E.NormalizeAddedEffect(value);if not r or(c.role=="resources"and r.behavior=="bound")then return end
 if not E.EffectLibrary or not E.EffectLibrary.IsAvailable(r.fileID)then return end
 local rows=E.EditAddedEffects(c);if #rows>=E.AddedEffectLimit then return end;rows[#rows+1]=r;return #rows
end
function E.RemoveLibraryEffect(c,index)if E.devMode and type(index)=="number"and index>=1 and index<=#E.GetAddedEffects(c)then table.remove(E.EditAddedEffects(c),index)end end
function E.NormalizeSide(value,side,role,designKey)
 local v=tableOr(value);role=role=="resources"and"resources"or"spells"
 local design=E.Designs[role=="spells"and designKey=="druid"and"druid"or"arcane"]
 local art=(v.art==design.left or v.art==design.right)and v.art or design[side]
 if designKey=="none"or E.DruidArtworks[designKey]or E.MageSpecSlots[designKey]then art=designKey end
 local kinds={};for _,k in ipairs(E.ResourceKinds)do kinds[k[1]]=true end
 local c={art=art,role=role,size=number(v.size,100,25,400),x=number(v.x,0,-8000,8000),y=number(v.y,0,-2000,3000),enabled=v.enabled==true,flip=type(v.flip)=="boolean"and v.flip or false,
  effects=v.effects~=false,resource=kinds[v.resource]and v.resource or(side=="left"and"health"or"mana"),showMeter=v.showMeter~=false}
 if type(v.flip)~="boolean"then c.flip=E.LegacyMageArtworks[art]~=nil and side=="right"end
 if role=="resources"then E.CrestOwners[c]="RESOURCE:"..side end
 return c
end
function E.Normalize(value)
 local v=tableOr(value);local result={version=E.schemaVersion,hideBlizzard=v.hideBlizzard==true,hideCooldownManager=v.hideCooldownManager==true,classOnly=v.classOnly~=false,content={}}
 for _,role in ipairs({"spells","resources"})do local r=tableOr(tableOr(v.content)[role]);result.content[role]={};for _,side in ipairs({"left","right"})do result.content[role][side]=E.NormalizeSide(r[side],side,role)end end
 result.content.classes=E.NormalizeClasses(tableOr(v.content))
 if not(type(v.version)=="number"and v.version>=5)then E.MigrateIndependentLayout(result,v)end
 result.content.spells=nil -- legacy geometry import is complete; no obsolete pair state in saves
 return result
end
function E.Config()return E.draft or EpicastDB end
function E.Begin()if not E.draft then E.draft=E.Normalize(EpicastDB);E.authorDraft=E.Copy(E.authorSession or{})end end
function E.HasChanges()return E.draft~=nil and(not equal(E.Normalize(E.draft),E.Normalize(EpicastDB))or E.AuthorHasChanges(equal))end
function E.Commit()EpicastDB=E.Normalize(E.Config());E.authorSession=E.Copy(E.authorDraft or{});E.draft=nil;E.authorDraft=nil end
function E.Cancel()E.draft=nil;E.authorDraft=nil end
function E.GetSide(db,setKey,side)
 if setKey=="resources"then return db.content.resources[side],side end
 local bank=setKey=="spells"and E.ClassBank(db)
 return bank and bank.slots[side]or nil,side
end
