local _,E=...
-- Schema 1-4 import only. Retired artwork bounds preserve old placements.
local legacyBounds={mageFire={book={bounds={25,77,634,740}},scroll={bounds={32,97,735,667}}},mageFrost={book={bounds={28,100,631,741}},scroll={bounds={26,111,742,687}}},mageArcane={book={bounds={29,91,631,741}},scroll={bounds={33,108,734,664}}}}
function E.GetLegacyCapGeometry(c,flip)
 if legacyBounds[c.art]then
  -- Stable default bounds: tuning an overlay must not move the book itself.
  local art=legacyBounds[c.art];local scale=c.size/100;local w,h=162*scale,216*scale;local a=h*.012
  local b=art.book.bounds;local l,r=(b[1]/660-.5)*w,(b[3]/660-.5)*w
  local bottom,top=(.5-b[4]/880)*h-a,(.5-b[2]/880)*h+a
  local sw=w*.82;local sb=art.scroll.bounds;local cy=-95*scale
  l=math.min(l,(sb[1]/768-.5)*sw);r=math.max(r,(sb[3]/768-.5)*sw)
  bottom=math.min(bottom,cy+(.5-sb[4]/768)*sw-a);top=math.max(top,cy+(.5-sb[2]/768)*sw+a)
  return r-l,top-bottom,(l+r)/2*(flip and -1 or 1),(bottom+top)/2
 end
 local druid=E.DruidArtworks[c.art]
 if druid then
  local b=druid.bounds;local w=162*c.size/100;local h=w*4/3
  local sw,sh=druid.sourceWidth or 768,druid.sourceHeight or 1024
  local cx=((b[1]+b[3])/(2*sw)-.5)*w*(flip and -1 or 1)
  local cy=(.5-(b[2]+b[4])/(2*sh))*h
  return w*(b[3]-b[1])/sw,h*(b[4]-b[2])/sh+2*h*.012,cx,30*c.size/100+cy
 end
 if c.art=="none"then return 162*c.size/100,216*c.size/100,0,30*c.size/100 end
 local b=E.MageBookBounds[c.art];local w=225*c.size/100;local bw=w*.72
 local cx=((b[1]+b[3])/1774-.5)*bw*(flip and -1 or 1);local cy=(.5-(b[2]+b[4])/1774)*bw
 return bw*((b[3]-b[1])/887+.024),bw*(b[4]-b[2])/887+2*(bw*.012+2),cx,30*w/225+cy
end

local function tableOr(v)return type(v)=="table"and v or{}end
local function oldSets(value)
 local sets={};local input=tableOr(value.sets)
 for _,key in ipairs({"central","edge"})do
  local v=tableOr(input[key]);local s={role=v.role=="spells"and"spells"or(v.role=="resources"and"resources"or(key=="central"and"spells"or"resources")),
   swapped=v.swapped==true}
  if type(v.enabled)=="boolean"then s.enabled=v.enabled else s.enabled=key=="central"end
  for _,f in ipairs({{"size",100,50,200},{"gap",480,0,1800},{"x",0,-2000,2000},{"y",0,0,1500}})do s[f[1]]=E.Number(v[f[1]],f[2],f[3],f[4])end
  for _,side in ipairs({"left","middle","right"})do s[side.."X"]=E.Number(v[side.."X"],0,-2000,2000);s[side.."Y"]=E.Number(v[side.."Y"],0,-1500,1500)end
  sets[key]=s
 end
 if sets.central.role==sets.edge.role then sets.edge.role=sets.central.role=="spells"and"resources"or"spells"end
 return sets
end
function E.DefaultCrestX(group,key,class)
 if group=="resources"then return key=="left"and -350 or 350 end
 if(class or E.ActiveClass())=="MAGE"then return key=="fire"and -300 or(key=="frost"and 300 or 0)end
 local definition=E.ClassSpecs[class or E.ActiveClass()]
 for i,spec in ipairs(definition and definition.slots or{})do if spec[1]==key then return(i-2)*300 end end
 return 0
end
function E.MigrateIndependentLayout(db,value)
 local sets=oldSets(value);local screen=UIParent and UIParent:GetWidth()or 1920
 local function place(group,bank,class)
  local location=sets.central.role==group and"central"or"edge";local s=sets[location]
  local keys=group=="resources"and{"left","right"}or E.ActiveSpecs(db,class)
  if s.swapped then local reversed={};for i=#keys,1,-1 do reversed[#reversed+1]=keys[i]end;keys=reversed end
  local slots=group=="resources"and db.content.resources or bank.slots
  for key,c in pairs(slots)do
   c.size=E.Number(c.size*s.size/100,100,25,400);c.x=E.DefaultCrestX(group,key,class);c.y=s.y
   if location=="edge"and E.LegacyMageArtworks[c.art]then c.flip=not c.flip end
   if group=="resources"then c.enabled=s.enabled end
  end
  local widths={};local total=s.gap*math.max(0,#keys-1)
  for i,key in ipairs(keys)do widths[i]=E.GetLegacyCapGeometry(slots[key],slots[key].flip);total=total+widths[i]end
  local cursor=s.x-total/2
  for i,key in ipairs(keys)do
   local c=slots[key];local physical=#keys==3 and({"left","middle","right"})[i]or(i==1 and"left"or"right")
   local x
   if location=="central"then x=cursor+widths[i]/2;cursor=cursor+widths[i]+s.gap
   elseif #keys==1 or physical=="middle"then x=0
   else x=physical=="left"and(-screen/2+widths[i]/2+s.x)or(screen/2-widths[i]/2-s.x)end
   c.x=E.Number(x+s[physical.."X"],0,-8000,8000);c.y=E.Number(s.y+s[physical.."Y"],0,-2000,3000)
  end
  if group=="spells"and not s.enabled then for key in pairs(bank.active)do bank.active[key]=false end end
 end
 for _,class in ipairs(E.ClassOrder)do place("spells",db.content.classes[class],class)end
 place("resources")
end
