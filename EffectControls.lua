local _,E=...
function E.GetLibraryRows(c)
 local rows={};for i,r in ipairs(E.GetAddedEffects(c))do local v=E.Copy(r);v.addedIndex=i;rows[#rows+1]=v end;return rows,0
end
function E.CreateStudioConfig(p,page)
 local U=E.StudioUI;local s={page=1,inputs={},tab="placement",filter="artwork",bindingIndex=1};p.layerControls=s
 local pageSize=10
 local function visibleLayers(layers)
  local result={}
  for _,l in ipairs(layers)do
   if s.filter=="all" or l.kind=="artwork" and s.filter=="artwork" or l.kind=="effect" and l.row.behavior==s.filter then result[#result+1]=l end
  end
  return result
 end
 local side=U.Box(page,0,0,244,618);s.sidebar=side
 U.Label(side,"LAYERS",12,-13,220,U.gold,"GameFontNormal");U.Label(side,"Front at the top · select to edit",12,-37,220)
 function s.Target()local c=E.GetEffectLibraryTarget();return c and E.FindStudioLayer(c,s.selectedID),c end
 local function currentBinding(row)
  local bindings=E.GetEffectBindings(row)
  return bindings[s.bindingIndex] or bindings[1]
 end
 function s.EndQuickBind()s.quick=nil end
 local function togglePick(id)
  local picks=s.quick.picks
  picks[id]=not picks[id] and true or nil
 end
 function s.Changed()E.PreviewLibraryChange();p.RefreshTarget()end
 function s.DiscardInputs()for _,b in pairs(s.inputs)do b.dirty=false;b.owner=nil;b:ClearFocus()end end
 local function readNumber(box)
  local value=tonumber(box:GetText())
  if value and value==value and value>=box.low and value<=box.high and (not box.integer or value==math.floor(value))then
   return value
  end
 end
 function s.PreviewPlacement(source)
  if s.tab~="placement"then return end
  local layer,c=s.Target()
  if not layer or c~=source then return end
  local values={}
  for _,field in ipairs(E.devEffectFields)do
   local key=field[1];local box=s.inputs[key]
   if box.dirty and box.owner==c and box.layerID==layer.id then values[key]=readNumber(box)end
  end
  return layer.id,values
 end
 function s.Flush()
  if InCombatLockdown()then s.DiscardInputs();return true end
  local edits={}
  for _,b in pairs(s.inputs)do if b.dirty then
   local n=readNumber(b)
   if not n then
    local kind=b.integer and"a whole number"or"a number"
    s.notice:SetText("Enter "..kind.." from "..b.low.." to "..b.high..".");b:SetFocus();return false
   end
   edits[#edits+1]={box=b,value=n}
  end end
  for _,edit in ipairs(edits)do local b=edit.box;local layer,c=s.Target();b.dirty=false
   if c==b.owner and layer and layer.id==b.layerID then b.apply(layer,c,edit.value)end;b.owner=nil;b:ClearFocus()
  end
  if #edits>0 then E.PreviewLibraryChange()end;return true
 end
 function s.Reveal()
  local c=E.GetEffectLibraryTarget();if not c then return end
  local layers=visibleLayers(E.GetStudioLayers(c))
  for i,l in ipairs(layers)do if l.id==s.selectedID then s.page=math.floor((#layers-i)/pageSize)+1;return end end
 end
 local function revealSpellEffects(c,spell)
  local filter=s.filter=="all" and "all" or "bound"
  for _,layer in ipairs(E.GetStudioLayers(c))do
   if layer.kind=="artwork"and E.StudioLayerHasSpell(layer,spell)then filter="all";break end
  end
  s.filter=filter;s.page=1
  local layers=visibleLayers(E.GetStudioLayers(c))
  for i=#layers,1,-1 do
   if E.StudioLayerHasSpell(layers[i],spell)then
    s.page=math.floor((#layers-i)/pageSize)+1
    return
   end
  end
 end
 local function setAnchor(direction,id)
  if s.quick then s.quick={direction=direction,anchor=id,picks={}}end
 end
 local function showEffectFilter(c)
  if #E.GetArtworkLayers(c)>1 then s.filter="all";s.page=1;return end
  if s.filter~="artwork" and #visibleLayers(E.GetStudioLayers(c))>0 then return end
  s.filter="static";s.page=1
  if #visibleLayers(E.GetStudioLayers(c))==0 then s.filter="bound"end
 end
 function s.BeginQuickBind()
  if s.quick or InCombatLockdown()or not s.Flush()then return end
  local layer,c=s.Target()
  if not c or c.role=="resources"then return end
  s.spells.mappingID=nil
  s.quick={picks={}}
  if s.spells.selected then
   setAnchor("spell",s.spells.selected)
   showEffectFilter(c)
  elseif E.CanBindStudioLayer(layer)then
   setAnchor("layer",layer.id)
  else
   s.selectedID=nil;s.noLayer=true
   showEffectFilter(c)
  end
  p.RefreshTarget()
 end
 function s.Select(id)
  if InCombatLockdown()or not s.Flush()then return end
  local c=E.GetEffectLibraryTarget()
  local layer=c and E.FindStudioLayer(c,id)
  if not layer then return end
  if s.quick then
   if not E.CanBindStudioLayer(layer)then return end
   if s.quick.direction=="spell"then togglePick(id);p.RefreshTarget();return end
   if s.quick.anchor==id then
    s.quick={picks={}};s.selectedID=nil;s.noLayer=true;p.RefreshTarget();return
   end
   setAnchor("layer",id)
  end
  E.StopBoundTests()
  s.selectedID=id
  s.noLayer=false;s.bindingIndex=1
  s.spells.selected=nil;s.spells.mappingID=nil
  if s.filter~="all" then s.filter=layer.kind=="artwork" and "artwork" or layer.row.behavior end
  s.Reveal()
  p.RefreshTarget()
 end
 function s.SelectSpell(id,gear)
  if InCombatLockdown()or not s.Flush()then return end
  local c=E.GetEffectLibraryTarget()
  local spell=c and E.GetStudioSpell(c,id)
  if not spell or c.role=="resources"then return end
  if gear and s.quick then return end
  if s.quick and s.quick.direction=="layer"then
   togglePick(id);p.RefreshTarget();return
  end
  E.StopBoundTests()
  s.selectedID=nil;s.noLayer=true
  if gear then
   if s.spells.mappingID==id then s.spells.mappingID=nil
   else s.spells.mappingID=id;s.spells.mappingPage=1;s.spells.trigger="cast"end
  else s.spells.mappingID=nil end
  if s.spells.selected==id and not gear then
   if s.quick then s.quick={picks={}}end
   s.spells.selected=nil
  else
   s.spells.selected=id
   setAnchor("spell",id)
   if E.StudioSpellUsage(c,spell.spell)>0 then revealSpellEffects(c,spell.spell)
   elseif s.quick then showEffectFilter(c)end
  end
  p.RefreshTarget()
 end
 function s.IsStaged(direction,id)
  return s.quick and s.quick.direction==direction and s.quick.picks[id]==true
 end
 function s.HasStaged(direction)
  return s.quick and s.quick.direction==direction and next(s.quick.picks)~=nil
 end
 function s.SaveQuickBind()
  local quick=s.quick
  if not quick or not next(quick.picks) or not s.Flush()then return end
  local c=E.GetEffectLibraryTarget();if not c then return end
  local layerFirst=quick.direction=="layer"
  local layerIDs=layerFirst and {[quick.anchor]=true} or quick.picks
  local spellIDs=layerFirst and quick.picks or {[quick.anchor]=true}
  if not E.BindStudioSpells(c,layerIDs,spellIDs)then return end
  s.EndQuickBind();s.page=1
  for id in pairs(layerIDs)do
   local layer=E.FindStudioLayer(c,id)
   if layer and layer.kind=="artwork" then s.filter="all";break end
  end
  if s.filter~="all"then s.filter="bound"end
  if layerFirst then s.Reveal()
  else
   revealSpellEffects(c,E.GetStudioSpell(c,quick.anchor).spell)
   s.spells.revealSpell=quick.anchor
  end
  s.Changed()
 end
 s.filters={}
 for i,v in ipairs({{"all","All"},{"artwork","Artwork"},{"static","Static"},{"bound","Bound"}})do local key=v[1]
  s.filters[key]=U.Pill(side,v[2],8+(i-1)*58,-55,55,function()
   if InCombatLockdown()or s.filter==key or not s.Flush()then return end
   s.filter=key;s.page=1;s.Reveal();s.Refresh();E.RefreshStudioPreview()
  end)
 end
 s.empty=U.Label(side,"",12,-91,220)
 s.rows={};for i=1,pageSize do s.rows[i]=U.Row(side,8,-85-(i-1)*44,228,function(b)s.Select(b.layerID)end);s.rows[i]:SetHeight(41)end
 s.count=U.Label(side,"",64,-533,116)
 s.prev=U.Button(side,"<",8,-526,42,function()if s.Flush()then s.page=s.page-1;s.Refresh()end end)
 s.next=U.Button(side,">",194,-526,42,function()if s.Flush()then s.page=s.page+1;s.Refresh()end end)
 side:EnableMouseWheel(true);side:SetScript("OnMouseWheel",function(_,d)s.page=s.page-d;s.Refresh()end)
 local function move(delta)local l,c=s.Target();if l and s.Flush()and E.MoveStudioLayer(c,l.id,delta)then s.Reveal();s.Changed()end end
 s.up=U.Button(side,"Forward",8,-560,110,function()move(1)end);s.down=U.Button(side,"Backward",126,-560,110,function()move(-1)end)
 U.Label(side,"Artwork positions are locked.",12,-596,220)
 local center=U.Box(page,256,0,656,618);s.center=center
 s.heading=U.Label(center,"",14,-12,620,U.gold,"GameFontNormal")
 s.heading:SetMaxLines(1)
 local stage=U.Box(center,12,-39,632,310);p.crestStage=stage;p.crestPreview=E.CreateStudioPreview(stage)
 s.previewHint=U.Label(center,"",14,-355,320)
 s.zoomLabel=U.Label(center,"Fit · 100%",346,-361,105)
 s.zoomOut=U.Button(center,"-",455,-353,36,function()p.previewZoom=math.max(.5,(p.previewZoom or 1)-.1);s.Refresh();E.RefreshStudioPreview()end)
 s.fit=U.Button(center,"Fit",496,-353,46,function()p.previewActualSize=false;p.previewZoom=1;s.Refresh();E.RefreshStudioPreview()end)
 s.actualSize=U.Button(center,"1:1",547,-353,49,function()p.previewActualSize=true;p.previewZoom=1;s.Refresh();E.RefreshStudioPreview()end)
 s.zoomIn=U.Button(center,"+",601,-353,36,function()p.previewZoom=math.min(2,(p.previewZoom or 1)+.1);s.Refresh();E.RefreshStudioPreview()end)
 local controls=CreateFrame("Frame",nil,center);controls:SetPoint("TOPLEFT",12,-390);controls:SetSize(632,216)
 s.tabs={};s.pages={};local previous
 for _,v in ipairs({{"placement","Placement"},{"playback","Playback"}})do local key=v[1]
  s.tabs[key]=U.Tab(controls,v[2],previous,0,0,function()if s.Flush()then s.tab=key;s.Refresh();E.RefreshStudioPreview()end end);previous=s.tabs[key]
  local f=CreateFrame("Frame",nil,controls);f:SetPoint("TOPLEFT",0,-34);f:SetSize(632,180);s.pages[key]=f
 end
 local placement,playback=s.pages.placement,s.pages.playback
 local function syncSlider(box,value)
  if not box.slider or not value then return end
  box.syncingSlider=true
  box.slider:SetValue(value)
  box.syncingSlider=false
 end
 local function stageInput(box,preview)
  local layer,c=s.Target()
  if not layer then return end
  box.owner=c;box.layerID=layer.id;box.dirty=true
  E.UpdateSaveButton()
  if preview then E.ScheduleStudioPreview()end
 end
 local function numeric(parent,key,title,x,y,lo,hi,apply,integer)
  local hasSlider=parent==placement
  U.Label(parent,title,x,y,hasSlider and 86 or 175)
  local b=U.Input(parent,x+(hasSlider and 242 or 183),y+7,hasSlider and 60 or 102)
  s.inputs[key]=b;b.low=lo;b.high=hi;b.integer=hasSlider or integer;b.apply=apply
  if hasSlider then
   local slider=CreateFrame("Frame",nil,parent,"MinimalSliderWithSteppersTemplate")
   slider:SetPoint("TOPLEFT",x+89,y+4);slider:SetSize(143,20)
   slider:Init(lo,lo,hi,hi-lo,{})
   b.slider=slider
   slider.Slider:HookScript("OnValueChanged",function(_,value)
    if b.syncingSlider or InCombatLockdown()or not b:IsEnabled()then return end
    b:SetText(tostring(math.floor(value+.5)))
    stageInput(b,true)
   end)
  end
  b:SetScript("OnTextChanged",function(self,user)
   if not user or InCombatLockdown()then return end
   syncSlider(self,readNumber(self))
   stageInput(self,parent==placement)
  end)
  b:SetScript("OnEnterPressed",function()if s.Flush()then s.Changed()end end)
  b:SetScript("OnEditFocusLost",function(self)if self.dirty and not s.flushing then s.flushing=true;s.Flush();s.flushing=false end end)
  b:SetScript("OnEscapePressed",function(self)self.dirty=false;self.owner=nil;self:ClearFocus();s.Refresh();E.ScheduleStudioPreview();E.UpdateSaveButton()end)
  b:EnableMouseWheel(true);b:SetScript("OnMouseWheel",function(self,delta)
   if InCombatLockdown()or not self:IsEnabled()or not s.Flush()then return end
   local l,c=s.Target();local n=tonumber(self:GetText());if not l or not n then return end
   local step=lo==.05 and .1 or 1;if IsShiftKeyDown and IsShiftKeyDown()then step=step*10 end
   local value=n+delta*step
   if hasSlider then value=math.floor(value+.5)end
   self.apply(l,c,math.max(lo,math.min(hi,value)));s.Changed()
  end)
 end
 local placementLabels={trailSize="Size (%)",trailAngle="Angle (°)",trailOpacity="Opacity (%)"}
 for i,v in ipairs(E.devEffectFields)do local key=v[1]
  numeric(placement,key,placementLabels[key]or v[2],i%2==1 and 0 or 326,-14-math.floor((i-1)/2)*37,v[3],v[4],function(l,c,n)
   if l.kind=="effect"then E.EditAddedEffects(c)[l.index][key]=n elseif key=="trailOpacity"then E.EditStudioState(c).artwork[l.id].opacity=n end
  end)
 end
 s.lock=U.Check(placement,"Follow artwork motion",326,-80,function(self)
  local l,c=s.Target();if not l or l.kind~="effect"or InCombatLockdown()then return end
  E.EditStudioState(c);local choices=E.GetArtworkLayers(c);E.EditAddedEffects(c)[l.index].followArtwork=self:GetChecked()and choices[1]and choices[1].id or nil;s.Changed()
 end)
 s.axis=U.Button(placement,"Choose artwork layer",331,-113,285,function(self)
  local l,c=s.Target();if not l or l.kind~="effect"then return end
  local choices={};for _,a in ipairs(E.GetArtworkLayers(c))do choices[#choices+1]={a.id,a.name.." · "..a.motion}end
  U.Menu(self,choices,l.row.followArtwork,function(id)E.EditStudioState(c);E.EditAddedEffects(c)[l.index].followArtwork=id;s.Changed()end)
 end)
 s.enabled=U.Check(placement,"Layer visible",0,-110,function(self)
  local l,c=s.Target();if not l or InCombatLockdown()then return end
  local meta,rows=E.EditStudioState(c);if l.kind=="effect"then rows[l.index].enabled=self:GetChecked()and true or false else meta.artwork[l.id].enabled=self:GetChecked()==true end;s.Changed()
 end)
 s.remove=U.Button(placement,"Remove effect",0,-147,140,function()
  local l,c=s.Target();if not l or l.kind~="effect"or InCombatLockdown()then return end
  s.DiscardInputs();s.EndQuickBind();E.RemoveLibraryEffect(c,l.index);s.selectedID=nil;s.Changed()
 end)
 s.unbind=U.Button(placement,"Unbind spell",151,-147,140,function(self)
  local l,c=s.Target();if not l or not s.Flush()then return end
  local bindings=E.GetStudioLayerBindings(l)
  local function remove(spell)
   if E.UnbindStudioLayer(c,l.id,spell)then
    s.EndQuickBind();s.bindingIndex=1
    if l.kind=="effect" and s.filter~="all"and E.FindStudioLayer(c,l.id).row.behavior=="static"then s.filter="static";s.Reveal()end
    s.Changed()
   end
  end
  if #bindings<2 then remove()
  else
   local choices={}
   for _,b in ipairs(bindings)do choices[#choices+1]={b.spell,E.StudioSpellLabel(b.spell)}end
   U.Menu(self,choices,nil,remove)
  end
 end)
 s.notice=U.Label(placement,"",326,-150,300);s.notice:SetMaxLines(2)
 numeric(playback,"animation","Main animation ID",0,-14,0,65535,function(l,c,n)if l.kind=="effect"and E.AnimationAvailable(l.row.fileID,n)then E.EditAddedEffects(c)[l.index].animation=n end end,true)
 local function editBinding(l,c)
  if not currentBinding(l.row)then return end
  return currentBinding(E.EditAddedEffects(c)[l.index])
 end
 numeric(playback,"duration","Burst seconds",326,-14,.05,60,function(l,c,n)
  local b=editBinding(l,c);if b then b.duration=n end
 end)
 for i,v in ipairs({{"intro","Play intro first"},{"outro","Play end on stop"}})do local key=v[1];local x=(i-1)*326
  s[key]=U.Check(playback,v[2],x,-42,function(self)
   local l,c=s.Target();if not l or InCombatLockdown()or not s.Flush()then return end
   local b=editBinding(l,c);if b then b[key]=self:GetChecked()==true;s.Changed()end
  end)
  numeric(playback,key.."Duration",i==1 and"Intro seconds"or"End seconds",x,-86,.05,10,function(l,c,n)
   local b=editBinding(l,c);if b then b[key.."Duration"]=n end
  end)
 end
 s.sequenceMenu=U.Button(playback,"Animation presets  v",0,-115,170,function(self)
  local l,c=s.Target();if not l then return end
  if l.kind=="artwork"then
   if not s.Flush()then return end
   local binding=E.GetStudioLayerBindings(l)[s.bindingIndex]
   if binding then
    for _,spell in ipairs(E.GetStudioState(c).spells)do
     if spell.spell:lower()==binding.spell:lower()then
      s.spells.revealSpell=spell.id;s.SelectSpell(spell.id,true);break
     end
    end
   end
   return
  end
  local choices={};for _,v in ipairs({{0,"Stand / intro (0)"},{158,"Hold (158)"},{159,"End (159)"}})do if E.AnimationAvailable(l.row.fileID,v[1])then choices[#choices+1]=v end end
  U.Menu(self,choices,l.row.animation,function(id)E.EditAddedEffects(c)[l.index].animation=id;s.Changed()end)
 end)
 s.animationSummary=U.Label(playback,"",183,-120,437);s.animationSummary:SetMaxLines(2)
 s.test=U.Button(playback,"Test response",0,-151,142,function(self)
  local l,c=s.Target();if not l then return end
  if l.kind=="artwork"then
   local choices=E.GetStudioBindingKinds(l)
   local function play(kind)
    if E.GetEffectLibraryTarget()~=c then return end
    if not E.TestRestorationSegment(p.crestPreview,l.id,{kind=kind})then
     s.animationSummary:SetText("Enable crest animation and this layer to test its spell response.")
    end
   end
   if #choices>1 then
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(self,function(_,root)
     for _,entry in ipairs(choices)do
      local state=entry[1];root:CreateButton("Test "..entry[2],function()play(state)end)
     end
    end)
   elseif choices[1]then
    play(choices[1][1])
   end
  elseif not E.TestStudioEffect(p.crestPreview.addedEffectSlots and p.crestPreview.addedEffectSlots[l.index],s.bindingIndex)then
   s.animationSummary:SetText("Not ready. Enable crest effects and this layer; wait for its model to load.")
  end
 end)
 s.stop=U.Button(playback,"Stop test",154,-151,110,function()E.StopBoundTests()end)
 local testHint=U.Label(playback,"Test affects this preview only.",278,-159,330)
 s.playbackBinding=U.Button(playback,"Spell response",278,-151,330,function(self)
  local l=s.Target()
  if not l or not s.Flush()then return end
  local choices={}
  for i,b in ipairs(E.GetStudioLayerBindings(l))do
   choices[#choices+1]={i,E.StudioSpellLabel(b.spell)}
  end
  U.Menu(self,choices,s.bindingIndex,function(i)
   s.bindingIndex=i;E.StopBoundTests();s.Refresh();E.RefreshStudioPreview()
  end)
 end)
 s.spells=E.CreateStudioSpells(p,page,s)
 function s.Refresh()
  local c=E.GetEffectLibraryTarget();if not c then return end
  local context=E.GetCrestBakeKey(c)
  if s.context~=context then
   s.DiscardInputs();s.EndQuickBind();E.StopBoundTests()
   s.selectedID=nil;s.noLayer=false;s.bindingIndex=1;s.context=context;s.page=1
   s.spells.selected=nil;s.spells.mappingID=nil;s.spells.revealSpell=nil;s.spells.page=1;s.spells.input:SetText("")
  end
  if InCombatLockdown()then s.EndQuickBind()end
  local layers=E.GetStudioLayers(c);local visible=visibleLayers(layers);local l
  for _,item in ipairs(visible)do if item.id==s.selectedID then l=item;break end end
  if not l and s.quick and s.quick.direction=="layer"then l=E.FindStudioLayer(c,s.quick.anchor)end
  if not l and not s.noLayer and not s.spells.selected then
   if s.selectedID then E.StopBoundTests()end
   l=visible[#visible];s.selectedID=l and l.id;s.bindingIndex=1;s.page=1
  end
  local effect=l and l.kind=="effect"and l.row or nil;s.selected=l and l.index or 1
  local selectedSpell=not l and E.GetStudioSpell(c,s.spells.selected)
  local showRelationships=selectedSpell and not s.HasStaged("spell")
  local pages=math.max(1,math.ceil(#visible/pageSize));s.page=math.max(1,math.min(s.page,pages))
  for key,b in pairs(s.filters)do b:SetEnabled(not InCombatLockdown());U.PillSelected(b,s.filter==key)end
  for i,b in ipairs(s.rows)do local item=visible[#visible-(s.page-1)*pageSize-i+1];b:SetShown(item~=nil)
   if item then
    b.layerID=item.id;b.title:SetText(item.name)
    if item.kind=="artwork"then
     local count=#E.GetStudioLayerBindings(item)
     b.detail:SetText((item.settings.enabled==false and "Hidden · " or "").."Locked artwork"..(count>0 and(" · "..count.." bound")or""))
    else
     local bindings=E.GetEffectBindings(item.row)
     local detail=#bindings>1 and ("Bound · "..#bindings.." spells")
      or #bindings==1 and ("Bound · "..E.StudioSpellLabel(bindings[1].spell)) or "Static · always active"
     b.detail:SetText((item.row.enabled==false and "Hidden · " or "")..detail)
    end
    local related=showRelationships and E.StudioLayerHasSpell(item,selectedSpell.spell)
    U.RowSelected(b,item.id==s.selectedID or s.IsStaged("spell",item.id),related and "green")
    b:SetEnabled(not InCombatLockdown()and (not s.quick or E.CanBindStudioLayer(item)))
   end
  end
  local empty=s.filter=="all"and"No layers"or s.filter=="static"and"No static layers"or s.filter=="bound"and"No bound layers"or"No artwork layers"
  s.empty:SetText(#visible==0 and empty or"");s.count:SetText(s.page.." / "..pages);s.prev:SetEnabled(s.page>1);s.next:SetEnabled(s.page<pages)
  s.heading:SetText(l and(l.name..(effect and(" · "..effect.fileID)or""))or(selectedSpell and ("Binding · "..E.StudioSpellLabel(selectedSpell.spell))or "Select a layer"))
  s.zoomLabel:SetText((p.previewActualSize and"Game · "or"Fit · ")..math.floor((p.previewZoom or 1)*100+.5).."%")
  s.previewHint:SetText(c.effects==false and"Crest effects disabled in Behavior"or #E.GetArtworkLayers(c)==0 and"No artwork for this crest yet"or"Live crest · responds to player spells")
  local editable=l~=nil and not InCombatLockdown()
  local bindings=E.GetStudioLayerBindings(l)
  if s.bindingIndex>#bindings then s.bindingIndex=1 end
  local bound=bindings[s.bindingIndex]
  s.playbackBinding:SetShown(#bindings>1);s.playbackBinding:SetEnabled(editable)
  testHint:SetShown(#bindings<=1)
  if #bindings>1 then s.playbackBinding:SetText(E.StudioSpellLabel(bound.spell).."  v")end
  if c.effects~=false and c.nativeSmoke~=false and effect and bound and effect.enabled~=false and s.tab=="placement"then
   s.previewHint:SetText("Previewing selected bound layer")
  end
  s.up:SetEnabled(editable and effect~=nil and l.rank<#layers)
  s.down:SetEnabled(editable and effect~=nil and l.rank>1)
  for key,f in pairs(s.pages)do f:SetShown(s.tab==key);U.SelectTab(s.tabs[key],s.tab==key)end
  for key,b in pairs(s.inputs)do local enabled=editable and(effect~=nil or key=="trailOpacity")
   if key=="duration"then enabled=enabled and bound and(bound.kind=="success"or bound.kind=="pulse")end
   if key=="introDuration"or key=="outroDuration"then enabled=enabled and bound and effect and effect.fileID~=166602 end
   b:SetEnabled(enabled and true or false)
   if not b.dirty then b:SetText(tostring(effect and(effect[key]or bound and bound[key])or l and key=="trailOpacity"and l.settings.opacity or""))end
   if b.slider then
    local value=readNumber(b)
    if not b.dirty then value=tonumber(b:GetText())end
    syncSlider(b,value)
    b.slider:SetEnabled(enabled and true or false)
   end
  end
  s.enabled:SetEnabled(editable);s.enabled:SetChecked(l and(effect and effect.enabled~=false or not effect and l.settings.enabled~=false)or false)
  s.lock:SetEnabled(editable and effect~=nil and #E.GetArtworkLayers(c)>0);s.lock:SetChecked(effect and effect.followArtwork~=nil or false)
  local source=effect and effect.followArtwork and E.FindStudioLayer(c,effect.followArtwork)
  s.axis:SetEnabled(editable and effect~=nil and effect.followArtwork~=nil)
  s.axis:SetText(source and (source.name.."  v")or effect and effect.followArtwork and "Crest hover  v"or"Select an artwork motion source  v")
  s.remove:SetEnabled(editable and effect~=nil);s.unbind:SetEnabled(editable and bound and true or false)
  s.notice:SetText(InCombatLockdown()and"Editing paused in combat"or not l and"Select a layer to configure placement."or not effect and"Artwork size and position follow the crest."or"Drag or type to preview. Chevrons adjust by 1. Save session applies the preview.")
  local artworkSummary=bound and "Choose a game trigger for each artwork state."or"Use bind mode to add a spell."
  s.animationSummary:SetText(effect and E.AnimationSummary(effect.fileID)or E.CanBindStudioLayer(l)and
   artworkSummary or"Select an animated layer to configure playback.")
  s.sequenceMenu:SetText(effect and "Animation presets  v"or"Edit spell mappings")
  s.sequenceMenu:SetEnabled(editable and (effect~=nil or bound~=nil)and not s.quick)
  for _,key in ipairs({"intro","outro"})do s[key]:SetChecked(bound and bound[key]or false);s[key]:SetEnabled(editable and effect and bound and effect.fileID~=166602 and E.AnimationAvailable(effect.fileID,key=="intro"and 0 or 159)or false)end
  s.test:SetEnabled(editable and (effect and bound~=nil or not effect and E.CanBindStudioLayer(l)) and true or false)
  s.stop:SetEnabled(not InCombatLockdown());s.spells.Refresh(c,l)
 end
 return s
end
function E.FlushStudioInputs()local p=E.EffectLibrary.window;return not p or not p:IsShown()or not p.layerControls or p.layerControls.Flush()end
function E.DiscardStudioInputs()local p=E.EffectLibrary.window;if p and p.layerControls then p.layerControls.DiscardInputs()end end
