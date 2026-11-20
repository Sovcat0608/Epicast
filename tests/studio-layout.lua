local E=...
EpicastDB=nil;Mock.event("ADDON_LOADED","Epicast");Mock.advance(0);E.OpenOptions();E.SetDeveloperMode(true);E.SelectCrest("spells","arcane");E.EffectLibrary.Open();Mock.advance(0)
local p=E.EffectLibrary.window;local s=p.layerControls
local function belongs(f)while f do if f==p then return true end;f=f.parent end end
local function anchor(key,w,h)return key:find("LEFT")and 0 or key:find("RIGHT")and w or w/2,key:find("TOP")and 0 or key:find("BOTTOM")and h or h/2 end
local function bounds(f)
 if f==p then return 0,0,p.width,p.height end
 if f.allPoints then return bounds(f.allPoints)end
 local a=f.point or{"TOPLEFT",0,0};local relative=type(a[2])=="table"and a[2]or f.parent
 local at=type(a[2])=="table"and a[3]or a[1];local dx=type(a[2])=="table"and a[4]or a[2];local dy=type(a[2])=="table"and a[5]or a[3]
 local x,y,w,h=bounds(relative);local ax,ay=anchor(at,w,h);local bx,by=anchor(a[1],f.width,f.height)
 return x+ax+(dx or 0)-bx,y+ay-(dy or 0)-by,f.width,f.height
end
local function check()
 local inputs={}
 for _,f in ipairs(Mock.frames)do if belongs(f)and f:IsVisible()and(f.kind=="Button"or f.kind=="EditBox"or f.kind=="CheckButton"or f.kind=="Slider")then
  local x,y,w,h=bounds(f);assert(x>=0 and y>=0 and x+w<=p.width+.001 and y+h<=p.height+.001,"Control outside studio: "..f:GetText())
  inputs[#inputs+1]={x,y,w,h,f}
 end end
 for i,a in ipairs(inputs)do for j=i+1,#inputs do local b=inputs[j]
  assert(a[1]+a[3]<=b[1]+.01 or b[1]+b[3]<=a[1]+.01 or a[2]+a[4]<=b[2]+.01 or b[2]+b[4]<=a[2]+.01,"Overlapping controls: "..a[5]:GetText().." / "..b[5]:GetText())
 end end
end
check();p.tabs.config:Click();check();s.tabs.playback:Click();check();s.Select("artwork");s.tabs.placement:Click();check()
-- All 32 effects + artwork can be reached; selected layers stay in view as
-- they cross a page boundary or move past the artwork.
E.SelectCrest("spells","frost");local c=E.GetEffectLibraryTarget();E.EditStudioState(c)
for i=1,32 do assert(E.AddLibraryEffect(c,{fileID=166009,name="Layer "..i})==i)end
assert(not E.AddLibraryEffect(c,{fileID=166009}));E.PreviewLibraryChange();p.RefreshTarget()
local seen={}
assert(s.filter=="artwork"and s.rows[1].layerID=="artwork"and not s.rows[2]:IsShown());check()
s.filters.static:Click()
for i=1,4 do s.page=i;s.Refresh();check();for _,b in ipairs(s.rows)do if b:IsShown()then seen[b.layerID]=true end end end
local count=0;for _ in pairs(seen)do count=count+1 end;assert(count==32 and not seen.artwork)
s.Select("fx23");assert(s.page==1);s.down:Click();assert(s.page==2 and s.selectedID=="fx23")
for i=1,64 do assert(E.AddStudioSpell(c,"Waiting "..i))end
assert(not E.AddStudioSpell(c,"Overflow"));p.RefreshTarget();seen={}
for i=1,10 do s.spells.page=i;s.Refresh();for _,b in ipairs(s.spells.rows)do if b:IsShown()then seen[b.spellID]=true end end end
count=0;for _ in pairs(seen)do count=count+1 end;assert(count==64)
s.spells.enterBinding:Click();s.spells.rows[1]:Click();assert(s.spells.saveBinding.enabled);check()
s.spells.saveBinding:Click();check()
local lastSpell=s.spells.rows[1].spellID
local targets={}
for _,layer in ipairs(E.GetStudioLayers(c))do if layer.kind=="effect"then targets[layer.id]=true end end
assert(E.BindStudioSpells(c,targets,{[lastSpell]=true}));s.Changed()
s.spells.gears[1]:Click();assert(s.spells.mapping:IsVisible());check()
local assignments={}
for page=1,6 do
 s.spells.mappingPage=page;s.Refresh();check()
 for _,row in ipairs(s.spells.mappingRows)do if row:IsShown()then
  assert(not assignments[row.layerID])
  assignments[row.layerID]=true
 end end
end
for id in pairs(targets)do assert(assignments[id],id.." missing from spell mappings")end
assert(not s.spells.mappingNext.enabled and not s.spells.next.enabled)
for _,size in ipairs({{1920,1080},{1280,720},{800,600}})do
 UIParent:SetSize(unpack(size));Mock.tabFontExtra=40;Mock.event("DISPLAY_SIZE_CHANGED");check()
 assert(p.width*p.scale<=size[1]-23 and p.height*p.scale<=size[2]-23)
 assert(p.tabs.config.point[2]==p.tabs.library and p.tabs.config.point[3]=="TOPRIGHT")
end
s.spells.gears[1]:Click();assert(not s.spells.mapping:IsShown()and p.width==1220);check()
-- The stage has its own viewport, separate from the game-sized model scenes.
local preview=p.crestPreview;local viewport=preview.canvas:GetParent()
assert(viewport.kind=="ScrollFrame" and viewport.allPoints==p.crestStage)
assert(viewport.SetScrollChildArgs[1]==preview.canvas and preview.frame:GetParent()==preview.canvas)
print("PASS: studio geometry, adjacent tabs, 33 layers, 64 spells, a 32-effect mapping sidebar, screen scaling and preview viewport")
