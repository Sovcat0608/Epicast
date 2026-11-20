local _,E=...
function E.CreateStudioSpells(p,page,layers)
 local U=E.StudioUI
 local s={page=1,rows={},gears={},mappingPage=1,trigger="cast"}
 local pageSize, mappingPageSize=7,6
 local kinds={}
 for _,entry in ipairs(E.BindingKinds)do kinds[entry[1]]=entry[2]end
 local host=U.Box(page,924,0,264,618);s.host=host
 U.Label(host,"SPELL WAITING ROOM",12,-13,240,U.gold,"GameFontNormal")
 U.Label(host,"Saved with this crest's bake",12,-37,240)
 s.input=U.Input(host,17,-64,155);s.input:SetMaxLetters(100)
 local function add()
  local c=E.GetEffectLibraryTarget();if not c or InCombatLockdown()then return end
  local id,message=E.AddStudioSpell(c,s.input:GetText())
  if not id then s.feedback:SetText(message);return end
  s.input:SetText("");s.input:ClearFocus();s.revealSpell=id
  layers.Changed()
 end
 s.add=U.Button(host,"Add spell",180,-63,76,add);s.input:SetScript("OnEnterPressed",add)
 U.Label(host,"Spell / buff name or exact ID",14,-94,236)
 for i=1,pageSize do
  local y=-118-(i-1)*46
  s.rows[i]=U.Row(host,8,y,209,function(row)layers.SelectSpell(row.spellID)end)
  local gear=U.Button(host,"",222,y-8,34,function(button)layers.SelectSpell(button.spellID,true)end)
  local icon=gear:CreateTexture(nil,"OVERLAY")
  icon:SetTexture("Interface\\Icons\\Trade_Engineering");icon:SetSize(17,17);icon:SetPoint("CENTER")
  gear:SetScript("OnEnter",function(self)
   if not GameTooltip then return end
   GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Configure spell mappings");GameTooltip:Show()
  end)
  gear:SetScript("OnLeave",function(self)if GameTooltip and GameTooltip:IsOwned(self)then GameTooltip:Hide()end end)
  s.gears[i]=gear
 end
 s.prev=U.Button(host,"<",8,-446,42,function()s.page=s.page-1;layers.Refresh()end)
 s.next=U.Button(host,">",214,-446,42,function()s.page=s.page+1;layers.Refresh()end)
 s.count=U.Label(host,"",69,-453,130)
 host:EnableMouseWheel(true);host:SetScript("OnMouseWheel",function(_,d)s.page=s.page-d;layers.Refresh()end)
 s.enterBinding=U.Button(host,"Enter bind mode",8,-481,248,layers.BeginQuickBind)
 s.saveBinding=U.Button(host,"Save binding",8,-516,120,layers.SaveQuickBind)
 s.cancelBinding=U.Button(host,"Cancel binding",136,-516,120,function()
  layers.EndQuickBind();layers.Refresh()
 end)
 s.remove=U.Button(host,"Remove unbound spell",8,-516,248,function()
  local _,c=layers.Target()
  if c and E.RemoveStudioSpell(c,s.selected)then s.selected=nil;layers.Changed()end
 end)
 s.feedback=U.Label(host,"",12,-556,240);s.feedback:SetMaxLines(3)

 local mapping=U.Box(page,1200,0,316,618);s.mapping=mapping
 s.triggers={};s.mappingRows={}
 U.Label(mapping,"SPELL MAPPINGS",12,-13,250,U.gold,"GameFontNormal")
 U.Button(mapping,"X",270,-8,34,function()s.mappingID=nil;p.RefreshTarget()end)
 local spellName=U.Label(mapping,"",12,-43,290,U.white);spellName:SetMaxLines(1)
 U.Label(mapping,"Game trigger",12,-68,290,U.gold)
 for i,entry in ipairs(E.BindingKinds)do
  local kind,label=entry[1],entry[2]
  s.triggers[kind]=U.Pill(mapping,label,12+(i-1)%2*148,-86-math.floor((i-1)/2)*28,144,function()
   s.trigger=kind;s.RefreshMapping()
  end)
 end
 local linked=U.Label(mapping,"",12,-173,292,U.gold)
 local function edit(row,state,enabled)
  if layers.quick or not layers.Flush()then return end
  local c=E.GetEffectLibraryTarget();local spell=c and E.GetStudioSpell(c,s.mappingID)
  if not spell or s.selected~=s.mappingID then return end
  local changed
  if state then changed=E.SetStudioArtworkMapping(c,row.layerID,spell.spell,state,s.trigger,enabled)
  else changed=E.SetStudioBindingKind(c,row.layerID,spell.id,s.trigger)end
  if changed then layers.Changed()else s.RefreshMapping()end
 end
 for i=1,mappingPageSize do
  local row=U.Box(mapping,8,-194-(i-1)*54,300,50)
  row.title=U.Label(row,"",9,-5,280,U.white)
  row.detail=U.Label(row,"",9,-27,150)
  row.title:SetMaxLines(1)
  row.detail:SetWidth(150)
  row.channel=U.Check(row,"Channel",8,-22,function(self)edit(row,"channel",self:GetChecked()==true)end)
  row.impact=U.Check(row,"Impact",150,-22,function(self)edit(row,"impact",self:GetChecked()==true)end)
  row.native=U.Button(row,"Use trigger",179,-18,112,function()edit(row)end)
  s.mappingRows[i]=row
 end
 local function changePage(delta)
  s.mappingPage=s.mappingPage+delta;s.RefreshMapping()
 end
 s.mappingPrev=U.Button(mapping,"<",8,-525,42,function()changePage(-1)end)
 s.mappingNext=U.Button(mapping,">",266,-525,42,function()changePage(1)end)
 local mappingCount=U.Label(mapping,"",62,-531,196)
 local mappingHint=U.Label(mapping,"",12,-560,290);mappingHint:SetMaxLines(3)
 mapping:EnableMouseWheel(true);mapping:SetScript("OnMouseWheel",function(_,d)changePage(-d)end)

 function s.RefreshMapping(c,assignments)
  c=c or E.GetEffectLibraryTarget()
  local spell=c and E.GetStudioSpell(c,s.selected)
  local shown=spell~=nil and s.mappingID==spell.id and not layers.quick and p.tab=="config" and c.role~="resources"
  mapping:SetShown(shown)
  if not shown then return end
  local links=(assignments or E.GetStudioSpellAssignments(c))[spell.spell:lower()] or {}
  local usable=not InCombatLockdown()
  spellName:SetText(E.StudioSpellLabel(spell.spell))
  linked:SetText("Linked layers · "..kinds[s.trigger])
  local counts={}
  for _,link in ipairs(links)do
   for _,b in ipairs(link.binding.mappings or {link.binding})do counts[b.kind]=(counts[b.kind] or 0)+1 end
  end
  for kind,button in pairs(s.triggers)do
   button:SetText(kinds[kind]..(counts[kind] and (" · "..counts[kind]) or ""))
   U.PillSelected(button,kind==s.trigger);button:SetEnabled(usable)
  end
  local pages=math.max(1,math.ceil(#links/mappingPageSize))
  s.mappingPage=math.max(1,math.min(s.mappingPage,pages))
  for i,row in ipairs(s.mappingRows)do
   local link=links[(s.mappingPage-1)*mappingPageSize+i]
   row:SetShown(link~=nil)
   if link then
    local layer,binding=link.layer,link.binding
    local art=layer.kind=="artwork"
    row.layerID=layer.id;row.title:SetText(layer.name)
    row.detail:SetShown(not art);row.native:SetShown(not art)
    for _,state in ipairs({"channel","impact"})do
     local control=row[state]
     control:SetShown(false)
     if art then
      for _,supported in ipairs(layer.states)do
       if supported==state then control:SetShown(true);break end
      end
      control:SetChecked(E.GetArtworkMapping(binding,state,s.trigger)~=nil)
      control:SetEnabled(usable)
     end
    end
    if not art then
     row.detail:SetText(kinds[binding.kind]);row.native:SetText(binding.kind==s.trigger and "Mapped" or "Use trigger")
     row.native:SetEnabled(usable and binding.kind~=s.trigger)
    end
   end
  end
  mappingCount:SetText(#links==0 and "No linked layers" or (#links.." layers · "..s.mappingPage.."/"..pages))
  s.mappingPrev:SetEnabled(s.mappingPage>1);s.mappingNext:SetEnabled(s.mappingPage<pages)
  local hint=E.CooldownBuffHint and E.CooldownBuffHint({kind=s.trigger,spell=spell.spell})
  mappingHint:SetText(#links==0 and "Use bind mode to link this spell to a layer." or
   hint or "Choose a trigger above, then check the artwork states it should play.")
 end

 function s.Refresh(c,layer)
  local spells=E.GetStudioState(c).spells
  local selected=E.GetStudioSpell(c,s.selected)
  if not selected then s.selected=nil end
  local quick=layers.quick
  local showRelationships=not selected and layer and not layers.HasStaged("layer")
  local usable=c.role~="resources" and not InCombatLockdown()
  local assignments=E.GetStudioSpellAssignments(c)
  if s.revealSpell then
   for i,item in ipairs(spells)do if item.id==s.revealSpell then s.page=math.floor((i-1)/pageSize)+1;break end end
   s.revealSpell=nil
  end
  local pages=math.max(1,math.ceil(#spells/pageSize))
  s.page=math.max(1,math.min(s.page,pages))
  for i,row in ipairs(s.rows)do
   local item=spells[(s.page-1)*pageSize+i]
   local gear=s.gears[i]
   row:SetShown(item~=nil)
   gear:SetShown(item~=nil and not quick)
   if item then
    local count=#(assignments[item.spell:lower()] or {})
    row.spellID=item.id;row.title:SetText(E.StudioSpellLabel(item.spell))
    row.detail:SetText(item.spell.." · "..(count==0 and "Waiting · unbound" or count.." layer(s)"))
    local related=showRelationships and E.StudioLayerHasSpell(layer,item.spell)
    U.RowSelected(row,item.id==s.selected or layers.IsStaged("layer",item.id),related and "blue")
    row:SetEnabled(usable)
    gear.spellID=item.id;gear:SetEnabled(usable and not quick)
   end
  end
  s.input:SetEnabled(usable);s.add:SetEnabled(usable)
  s.prev:SetEnabled(s.page>1);s.next:SetEnabled(s.page<pages);s.count:SetText(#spells.." spells · "..s.page.."/"..pages)
  s.enterBinding:SetText(quick and "Bind mode active" or "Enter bind mode")
  s.enterBinding:SetEnabled(usable and not quick)
  s.saveBinding:SetShown(quick~=nil);s.cancelBinding:SetShown(quick~=nil)
  s.saveBinding:SetEnabled(usable and quick~=nil and next(quick.picks)~=nil)
  s.cancelBinding:SetEnabled(usable and quick~=nil)
  s.remove:SetShown(not quick)
  s.remove:SetEnabled(usable and not quick and selected~=nil and not assignments[selected.spell:lower()])
  local hint
  if c.role=="resources"then hint="Resources use player health / power."
  elseif quick then
   local picks=0;for _ in pairs(quick.picks)do picks=picks+1 end
   if not quick.direction then hint="Select a layer or spell to start."
   elseif picks>0 then hint=picks.." selected. Save binding to apply."
   elseif quick.direction=="layer"then hint="Select one or more spells."
   else hint="Select one or more bindable layers." end
  else hint="Use a spell's gear to map triggers to its linked layers." end
  s.feedback:SetText(hint)
  s.RefreshMapping(c,assignments)
 end
 return s
end
