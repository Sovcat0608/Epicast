local _,E=...
-- Authoring metadata lives beside the effect rows, exclusively in crest bakes
-- and developer RAM. It never enters the player preference schema.
function E.GetArtworkLayers(c)
 if c.art=="druidRestoration" and E.RestorationSegments then return E.RestorationSegments end
 if E.DruidArtworks[c.art]or E.MageRebootArtworks[c.art]then
  return{{id="artwork",name="Crest artwork",motion="Six-second hover"}}
 end
 return{}
end
E.ArtworkBindingKinds={{"channel","Channel"},{"impact","Impact"}}
function E.GetStudioBindingKinds(layer)
 if layer.kind=="effect"then return E.BindingKinds end
 local choices={}
 for _,v in ipairs(E.ArtworkBindingKinds)do
  for _,kind in ipairs(layer.states or{})do if kind==v[1]then choices[#choices+1]=v;break end end
 end
 return choices
end
function E.CanBindStudioLayer(layer)return layer and(layer.kind=="effect"or #(layer.states or{})>0)end
function E.GetStudioLayerBindings(layer)
 if not layer then return{}end
 return layer.kind=="artwork" and layer.bindings or E.GetEffectBindings(layer.row)
end
function E.StudioLayerHasSpell(layer,spell)
 for _,binding in ipairs(E.GetStudioLayerBindings(layer))do
  if binding.spell:lower()==spell:lower()then return true end
 end
 return false
end
function E.GetArtworkMapping(link,state,kind)
 for i,mapping in ipairs(link.mappings)do
  if mapping.state==state and mapping.kind==kind then return i end
 end
end
function E.EffectLayerID(row,index)return row.layerID or("fx"..index)end
local function spellKey(s)return s:lower()end
function E.GetStudioState(c)
 local rows=E.GetAddedEffects(c)
 local segmented=c.art=="druidRestoration"and E.RestorationSegments
 if rows.studio then
  local old=rows.studio
  if not segmented or old.artworkBindings then return old end
  local state={order={},artwork={},spells=old.spells,artworkBindings={}}
  for _,id in ipairs(old.order)do
   if id=="artwork"then
    for _,a in ipairs(segmented)do
     state.order[#state.order+1]=a.id
     local shared=old.artwork.artwork
     state.artwork[a.id]={enabled=a.enabled~=false and shared.enabled~=false,opacity=shared.opacity}
    end
   else state.order[#state.order+1]=id end
  end
  return state
 end
 local state={order={},artwork={},spells={}};local seen={}
 if segmented then state.artworkBindings={}end
 for i,r in ipairs(rows)do if r.effectLayer=="back"then state.order[#state.order+1]=E.EffectLayerID(r,i)end end
 for _,a in ipairs(E.GetArtworkLayers(c))do state.order[#state.order+1]=a.id;state.artwork[a.id]={enabled=a.enabled~=false,opacity=100}end
 for i,r in ipairs(rows)do
  if r.effectLayer~="back"then state.order[#state.order+1]=E.EffectLayerID(r,i)end
  for _,b in ipairs(E.GetEffectBindings(r))do
   if b.spell~=""and not seen[spellKey(b.spell)]then
    seen[spellKey(b.spell)]=true;state.spells[#state.spells+1]={id="spell"..(#state.spells+1),spell=b.spell}
   end
  end
 end
 return state
end
function E.EditStudioState(c)
 local state=E.GetStudioState(c);local rows=E.EditAddedEffects(c)
 if not rows.studio or rows.studio~=state then
  rows.studio=E.Copy(state)
  for i,r in ipairs(rows)do r.layerID=E.EffectLayerID(r,i)end
 end
 return rows.studio,rows
end
function E.GetStudioLayers(c)
 local state=E.GetStudioState(c);local byID,result={},{}
 for _,a in ipairs(E.GetArtworkLayers(c))do
  byID[a.id]={id=a.id,name=a.name,kind="artwork",settings=state.artwork[a.id]or{enabled=a.enabled~=false,opacity=100},
   motion=a.motion or "Crest hover",states=a.states,bindings=state.artworkBindings and state.artworkBindings[a.id] or {}}
 end
 for i,r in ipairs(E.GetAddedEffects(c))do
  local id=E.EffectLayerID(r,i);byID[id]={id=id,name=r.name,kind="effect",row=r,index=i}
 end
 local function take(id)local layer=byID[id];if layer then result[#result+1]=layer;layer.rank=#result;byID[id]=nil end end
 for _,id in ipairs(state.order)do take(id)end
 -- Existing v1 bakes have implicit order. Be robust to a newly added layer.
 for _,a in ipairs(E.GetArtworkLayers(c))do take(a.id)end
 for i,r in ipairs(E.GetAddedEffects(c))do take(E.EffectLayerID(r,i))end
 return result
end
function E.FindStudioLayer(c,id)
 for _,layer in ipairs(E.GetStudioLayers(c))do if layer.id==id then return layer end end
end
function E.MoveStudioLayer(c,id,delta)
 if InCombatLockdown()then return end
 local layer=E.FindStudioLayer(c,id)
 if not layer or layer.kind~="effect"then return end
 local state=E.EditStudioState(c)
 for i,key in ipairs(state.order)do if key==id then
  local dest=i+delta;if dest<1 or dest>#state.order then return end
  table.remove(state.order,i);table.insert(state.order,dest,id);return true
 end end
end
function E.StudioEffectAdded(rows)
 if not rows.studio then return end
 local used={};for _,r in ipairs(rows)do if r.layerID then used[r.layerID]=true end end
 local n=1;while used["fx"..n]do n=n+1 end
 rows[#rows].layerID="fx"..n;table.insert(rows.studio.order,"fx"..n)
end
function E.StudioEffectRemoving(rows,index)
 if not rows.studio then return end
 local id=E.EffectLayerID(rows[index],index)
 for i,key in ipairs(rows.studio.order)do if key==id then table.remove(rows.studio.order,i);break end end
end
function E.AddStudioSpell(c,value)
 if c.role=="resources"or InCombatLockdown()then return nil,"Resource crests cannot bind spells."end
 local text=type(value)=="string"and value:match("^%s*(.-)%s*$")or""
 if text==""or #text>100 or text:find("[%z\1-\31]")then return nil,"Enter a spell or buff name, or its exact ID."end
 local state=E.GetStudioState(c)
 for _,s in ipairs(state.spells)do if spellKey(s.spell)==spellKey(text)then return s.id end end
 if #state.spells>=64 then return nil,"This crest already has 64 spells."end
 state=E.EditStudioState(c);local used={};for _,s in ipairs(state.spells)do used[s.id]=true end
 local n=1;while used["spell"..n]do n=n+1 end
 local id="spell"..n;table.insert(state.spells,{id=id,spell=text});return id
end
function E.GetStudioSpell(c,id)
 for _,item in ipairs(E.GetStudioState(c).spells)do if item.id==id then return item end end
end
local function findBinding(row,spell)
 for _,b in ipairs(E.GetEffectBindings(row))do
  if spellKey(b.spell)==spellKey(spell)then return b end
 end
end
function E.EffectHasSpell(row,spell)return findBinding(row,spell)~=nil end
function E.GetStudioSpellAssignments(c)
 local assignments={}
 local layers=E.GetStudioLayers(c)
 for i=#layers,1,-1 do
  local layer=layers[i]
  for _,binding in ipairs(E.GetStudioLayerBindings(layer))do
   local key=spellKey(binding.spell)
   if not assignments[key]then assignments[key]={}end
   local list=assignments[key]
   list[#list+1]={layer=layer,binding=binding}
  end
 end
 return assignments
end
function E.StudioSpellUsage(c,spell)
 local count=0
 for _,layer in ipairs(E.GetStudioLayers(c))do if E.StudioLayerHasSpell(layer,spell)then count=count+1 end end
 return count
end
function E.RemoveStudioSpell(c,id)
 if InCombatLockdown()then return end
 local state=E.GetStudioState(c)
 for i,s in ipairs(state.spells)do if s.id==id and E.StudioSpellUsage(c,s.spell)==0 then
  state=E.EditStudioState(c);table.remove(state.spells,i);return true
 end end
end
function E.BindStudioSpells(c,layerIDs,spellIDs)
 if c.role=="resources"or InCombatLockdown()then return end
 if not next(layerIDs)or not next(spellIDs)then return end
 local targets,spells={},{}
 for id in pairs(layerIDs)do
  local layer=E.FindStudioLayer(c,id)
  if not E.CanBindStudioLayer(layer)then return end
  targets[#targets+1]=layer
 end
 for _,item in ipairs(E.GetStudioState(c).spells)do
  if spellIDs[item.id]then spells[#spells+1]=item.spell end
 end
 for id in pairs(spellIDs)do if not E.GetStudioSpell(c,id)then return end end

 local state,rows=E.EditStudioState(c)
 for _,layer in ipairs(targets)do
  local row=rows[layer.index]
  local bindings,existing={},{}
  for _,b in ipairs(E.GetStudioLayerBindings(layer))do
   if b.spell~=""then bindings[#bindings+1]=b;existing[spellKey(b.spell)]=b end
  end
  for _,spell in ipairs(spells)do
   if not existing[spellKey(spell)]then
    if row then bindings[#bindings+1]=E.NewEffectBinding(spell,"success")
    else bindings[#bindings+1]={spell=spell,mappings={}}end
   end
  end
  if row then E.SetEffectBindings(row,bindings)else state.artworkBindings[layer.id]=bindings end
 end
 return true
end
function E.SetStudioBindingKind(c,layerID,spellID,kind)
 if c.role=="resources"or InCombatLockdown()then return end
 local layer=E.FindStudioLayer(c,layerID)
 local spell=E.GetStudioSpell(c,spellID)
 if not layer or layer.kind~="effect"or not spell then return end
 local valid=false
 for _,entry in ipairs(E.GetStudioBindingKinds(layer))do if entry[1]==kind then valid=true;break end end
 if not valid then return end
 local binding=findBinding(layer.row,spell.spell)
 if not binding or binding.kind==kind then return end
 local rows=E.EditAddedEffects(c)
 findBinding(rows[layer.index],spell.spell).kind=kind
 return true
end
function E.SetStudioArtworkMapping(c,layerID,spell,state,kind,enabled)
 if c.role=="resources"or InCombatLockdown()then return end
 local layer=E.FindStudioLayer(c,layerID)
 if not layer or layer.kind~="artwork"or not E.StudioLayerHasSpell(layer,spell)then return end
 local supportedState,supportedKind=false,false
 for _,entry in ipairs(layer.states)do if entry==state then supportedState=true;break end end
 for _,entry in ipairs(E.BindingKinds)do if entry[1]==kind then supportedKind=true;break end end
 if not supportedState or not supportedKind then return end
 local studio=E.EditStudioState(c)
 for _,link in ipairs(studio.artworkBindings[layerID])do
  if spellKey(link.spell)==spellKey(spell)then
   local index=E.GetArtworkMapping(link,state,kind)
   if enabled and not index then link.mappings[#link.mappings+1]={state=state,kind=kind};return true end
   if not enabled and index then table.remove(link.mappings,index);return true end
   return
  end
 end
end
function E.UnbindStudioLayer(c,id,spell)
 if InCombatLockdown()then return end
 local layer=E.FindStudioLayer(c,id);if not E.CanBindStudioLayer(layer)then return end
 -- Capture inherited bindings in the waiting room before clearing the row.
 local state,rows=E.EditStudioState(c)
 local row,remaining=rows[layer.index],{}
 if spell then
  for _,b in ipairs(E.GetStudioLayerBindings(layer))do
   if spellKey(b.spell)~=spellKey(spell)then remaining[#remaining+1]=b end
  end
 end
 if row then E.SetEffectBindings(row,remaining)else state.artworkBindings[id]=#remaining>0 and remaining or nil end
 return true
end
function E.StudioSpellLabel(spell)
 if C_Spell and C_Spell.GetSpellInfo then
  local ok,v=pcall(C_Spell.GetSpellInfo,tonumber(spell)or spell)
  if ok and not(issecretvalue and issecretvalue(v))and type(v)=="table"and not(issecrettable and issecrettable(v))then
   local n=v.name;if not(issecretvalue and issecretvalue(n))and type(n)=="string"then return n end
  end
 end
 return spell
end
