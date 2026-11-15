local _,E=...
E.schemaVersion=1
E.ArcaneArtworks={arcaneTome="ArcaneTome",arcaneScroll="ArcaneScroll"};E.MageArtworks=E.ArcaneArtworks
E.MageSigils={arcaneScroll="Arcane seal"}
E.artworks={{id="arcaneTome",name="Arcane Tome",width=225,height=225,path="Interface\\AddOns\\Epicast\\Media\\ArcaneTomeBookCASSize887.tga"},
 {id="arcaneScroll",name="Arcane Scroll",width=225,height=225,path="Interface\\AddOns\\Epicast\\Media\\ArcaneScrollBookCASSize887.tga"}}
E.artworkByID={};for _,v in ipairs(E.artworks)do E.artworkByID[v.id]=v end
E.Designs={arcane={name="Arcane",class="MAGE",specialization="Arcane",left="arcaneTome",right="arcaneScroll"}}
E.SetLabels={central="Central set",edge="Edge set"}
E.RoleLabels={spells="Spellcasting",resources="Resources"}
E.ResourceKinds={{"health","Health"},{"mana","Mana",0},{"energy","Energy",3},{"rage","Rage",1},{"focus","Focus",2},{"runic","Runic power",6},{"power","Current power"}}
E.devEffectFields={{"trailSize","Effect size (%)",50,200},{"trailAngle","Effect angle (degrees)",-180,180},
 {"trailX","Origin X",-150,150},{"trailY","Origin Y",-150,150},{"trailOpacity","Effect opacity (%)",0,100}}
E.EmissionFields={{"opacity","Glyph / gem intensity (%)",0,200},{"cycle","Emission cycle (seconds)",2,20}}
E.SigilFields={{"size","Seal size (%)",25,250},{"x","Seal X",-200,200},{"y","Seal Y",-250,250},{"opacity","Seal opacity (%)",0,100},{"period","Seal revolution (seconds)",8,120}}
local function number(v,d,lo,hi)if type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return d end;return math.max(lo,math.min(hi,v))end
E.Number=number
function E.Copy(v)if type(v)~="table" then return v end;local t={};for k,x in pairs(v)do t[k]=E.Copy(x)end;return t end
local function equal(a,b)if type(a)~=type(b)then return false end;if type(a)~="table" then return a==b end;for k,v in pairs(a)do if not equal(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function tableOr(v)return type(v)=="table" and v or {}end
function E.GetBookConfig()return{size=100,x=0,y=30,flip=false}end
function E.MageBookHoverAmplitude(w)return w*.012+2 end
function E.UV(c,flip)if not flip then return unpack(c)end;return c[5],c[6],c[7],c[8],c[1],c[2],c[3],c[4]end
function E.GetCapGeometry(c,flip)
 local b=E.MageBookBounds[c.art];local w=225*c.size/100;local bw=w*.72
 local cx=((b[1]+b[3])/1774-.5)*bw*(flip and -1 or 1);local cy=(.5-(b[2]+b[4])/1774)*bw
 return bw*((b[3]-b[1])/887+.024),bw*(b[4]-b[2])/887+2*E.MageBookHoverAmplitude(bw),cx,30*w/225+cy
end
function E.GetEmissionConfig(c)local v=tableOr(c.emissions);return{opacity=number(v.opacity,c.art=="arcaneScroll" and 98 or 85,0,200),cycle=number(v.cycle,3,2,20)}end
function E.SetEmission(c,k,v)if not E.devMode or(k~="opacity" and k~="cycle")then return end;c.emissions=E.GetEmissionConfig(c);c.emissions[k]=v;c.emissions=E.GetEmissionConfig(c)end
function E.GetSigilConfig(c)
 if c.art~="arcaneScroll" then return end;local v=tableOr(c.sigil)
 return{size=number(v.size,125,25,250),x=number(v.x,12,-200,200),y=number(v.y,0,-250,250),opacity=number(v.opacity,30,0,100),period=number(v.period,24,8,120),flip=v.flip==true,cycle=6}
end
function E.SetSigil(c,k,v)if not E.devMode or not E.MageSigils[c.art]then return end;c.sigil=E.GetSigilConfig(c);c.sigil[k]=v;c.sigil=E.GetSigilConfig(c)end
function E.ResetSigil(c)c.sigil=nil end
E.AddedEffectLimit=16
E.AllowedEffects={};for _,list in pairs(E.AddedEffectDefaults)do for _,r in ipairs(list)do E.AllowedEffects[r.fileID]=true end end
function E.NormalizeAddedEffect(v)
 if type(v)~="table" or not E.AllowedEffects[v.fileID]then return end
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
 end;return r
end
function E.GetAddedEffects(c)return c.addedEffects or{}end
function E.EditAddedEffects(c)c.addedEffects=c.addedEffects or{};return c.addedEffects end
function E.AddLibraryEffect(c,value)
 if not E.devMode then return end;local r=E.NormalizeAddedEffect(value);if not r or(c.role=="resources"and r.behavior=="bound")then return end
 local rows=E.EditAddedEffects(c);if #rows>=E.AddedEffectLimit then return end;rows[#rows+1]=r;return #rows
end
function E.RemoveLibraryEffect(c,index)if E.devMode and type(index)=="number"and index>=1 and index<=#E.GetAddedEffects(c)then table.remove(c.addedEffects,index)end end
function E.NormalizeSide(value,side,role)
 local v=tableOr(value);role=role=="resources"and"resources"or"spells"
 local art=E.artworkByID[v.art]and v.art or(side=="left"and"arcaneTome"or"arcaneScroll")
 local kinds={};for _,k in ipairs(E.ResourceKinds)do kinds[k[1]]=true end
 local c={art=art,role=role,size=number(v.size,100,50,200),flip=type(v.flip)=="boolean"and v.flip or false,
  effects=v.effects~=false,nativeSmoke=v.nativeSmoke~=false,resource=kinds[v.resource]and v.resource or(side=="left"and"health"or"mana"),showMeter=v.showMeter~=false}
 if type(v.flip)~="boolean"then c.flip=side=="right"end
 c.emissions=E.GetEmissionConfig({art=art,emissions=v.emissions});c.sigil=E.GetSigilConfig({art=art,sigil=v.sigil})
 c.addedEffects={};local rows=v.addedEffects
 if type(rows)~="table"then
  if role=="spells"then rows=E.AddedEffectDefaults[art]
  else local glow=E.Copy(E.AddedEffectDefaults.arcaneScroll[1]);glow.trailOpacity=35;rows={glow}end
 end
 for i=1,math.min(#rows,E.AddedEffectLimit)do local r=E.NormalizeAddedEffect(rows[i]);if r then if role=="resources"then r.behavior="static";r.binding=nil end;c.addedEffects[#c.addedEffects+1]=r end end
 return c
end
function E.Normalize(value)
 local v=tableOr(value);local result={version=1,hideBlizzard=v.hideBlizzard==true,classOnly=v.classOnly~=false,sets={},content={}}
 local sets=tableOr(v.sets)
 for _,key in ipairs({"central","edge"})do
  local s=tableOr(sets[key]);result.sets[key]={role=s.role=="resources"and"resources"or(s.role=="spells"and"spells"or(key=="central"and"spells"or"resources")),
   enabled=type(s.enabled)=="boolean"and s.enabled or false,size=number(s.size,100,50,200),gap=number(s.gap,480,0,1800),x=number(s.x,0,-2000,2000),y=number(s.y,0,0,1500),swapped=s.swapped==true,
   leftX=number(s.leftX,0,-2000,2000),leftY=number(s.leftY,0,-1500,1500),rightX=number(s.rightX,0,-2000,2000),rightY=number(s.rightY,0,-1500,1500)}
  if type(s.enabled)~="boolean"then result.sets[key].enabled=key=="central"end
 end
 if result.sets.central.role==result.sets.edge.role then result.sets.edge.role=result.sets.central.role=="spells"and"resources"or"spells"end
 for _,role in ipairs({"spells","resources"})do local r=tableOr(tableOr(v.content)[role]);result.content[role]={};for _,side in ipairs({"left","right"})do result.content[role][side]=E.NormalizeSide(r[side],side,role)end end
 return result
end
function E.AssignRole(db,key,role)
 if not E.SetLabels[key]or not E.RoleLabels[role]then return end
 local other=key=="central"and"edge"or"central";local previous=db.sets[key].role
 db.sets[key].role=role;if db.sets[other].role==role then db.sets[other].role=previous end
end
function E.SwapRoles(db)db.sets.central.role,db.sets.edge.role=db.sets.edge.role,db.sets.central.role end
function E.Config()return E.draft or EpicastDB end
function E.Begin()if not E.draft then E.draft=E.Normalize(EpicastDB)end end
function E.HasChanges()return E.draft~=nil and not equal(E.Normalize(E.draft),E.Normalize(EpicastDB))end
function E.Commit()EpicastDB=E.Normalize(E.Config());E.draft=nil end
function E.Cancel()E.draft=nil end
function E.GetSide(db,setKey,side)local slot=db.sets[setKey];local source=slot.swapped and(side=="left"and"right"or"left")or side;return db.content[slot.role][source],source end
