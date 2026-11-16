local _,E=...
-- Stable authoring banks for all nine Forever classes.
E.ClassOrder={"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}
E.ClassSpecs={
 DRUID={name="Druid",slots={{"balance","Balance","druidBalance"},{"feral","Feral","druidFeral"},{"restoration","Restoration","druidRestoration"}}},
 HUNTER={name="Hunter",slots={{"beastMastery","Beast Mastery"},{"marksmanship","Marksmanship"},{"survival","Survival"}}},
 MAGE={name="Mage",slots={{"fire","Fire","mageFire"},{"frost","Frost","mageFrost"},{"arcane","Arcane","mageArcane"}}},
 PALADIN={name="Paladin",slots={{"holy","Holy"},{"protection","Protection"},{"retribution","Retribution"}}},
 PRIEST={name="Priest",slots={{"discipline","Discipline"},{"holy","Holy"},{"shadow","Shadow"}}},
 ROGUE={name="Rogue",slots={{"assassination","Assassination"},{"combat","Combat"},{"subtlety","Subtlety"}}},
 SHAMAN={name="Shaman",slots={{"elemental","Elemental"},{"enhancement","Enhancement"},{"restoration","Restoration"}}},
 WARLOCK={name="Warlock",slots={{"affliction","Affliction"},{"demonology","Demonology"},{"destruction","Destruction"}}},
 WARRIOR={name="Warrior",slots={{"arms","Arms"},{"fury","Fury"},{"protection","Protection"}}},
}
E.PhysicalSides={"left","middle","right"}
function E.PlayerClass()local _,class=UnitClass("player");return class end
function E.ActiveClass()
 if E.devMode and E.previewClass and E.draft and E.panel and E.panel:IsShown()then return E.previewClass end
 return E.PlayerClass()
end
function E.ClassBank(db,class)return db.content.classes[class or E.ActiveClass()]end
function E.ActiveSpecs(db,class)
 class=class or E.ActiveClass();local definition=E.ClassSpecs[class];local bank=E.ClassBank(db,class);local result={}
 if definition and bank then for _,spec in ipairs(definition.slots)do if bank.active[spec[1]]then result[#result+1]=spec[1]end end end
 return result
end
function E.DisplaySides(db,setKey)
 if db.sets[setKey].role=="resources"or not E.ClassBank(db)then return {"left","right"}end
 local count=#E.ActiveSpecs(db)
 if count==3 then return {"left","middle","right"}elseif count==2 then return {"left","right"}elseif count==1 then return {"left"}end
 return {}
end
function E.SelectSpec(db,class,key,enabled)
 local bank=E.ClassBank(db,class);if not bank or not bank.slots[key]then return false end
 bank.active[key]=enabled==true;bank.configured=true;return true
end
function E.NormalizeClasses(content)
 local result={};local old=type(content.druid)=="table"and content.druid or{}
 local classes=type(content.classes)=="table"and content.classes or{}
 for _,class in ipairs(E.ClassOrder)do local definition=E.ClassSpecs[class]
  do
   local prior=type(classes[class])=="table"and classes[class]or{};local slots=type(prior.slots)=="table"and prior.slots or{}
   local active=type(prior.active)=="table"and prior.active or nil
   local bank={slots={},active={},configured=prior.configured==true};result[class]=bank
   for i,spec in ipairs(definition.slots)do
    local value=slots[spec[1]]
    if class=="MAGE"and spec[1]=="arcane"and value==nil then
     -- Migrate once, in memory at addon load. Retain both lists, including
     -- duplicates and explicit empty arrays. Keep intrinsic model fitting;
     -- reset the five user placement fields just like Reset placement.
     local merged={addedEffects={}};local legacy=type(content.spells)=="table"and content.spells or{}
     for _,side in ipairs({"left","right"})do
      local source=E.NormalizeSide(legacy[side],side,"spells")
      for _,row in ipairs(source.addedEffects)do
       local r=E.Copy(row);for _,field in ipairs(E.devEffectFields)do r[field[1]]=nil end
       r.effectLayer="front";merged.addedEffects[#merged.addedEffects+1]=E.NormalizeAddedEffect(r)
      end
     end
     value=merged
    end
    if class=="DRUID"and value==nil then
     local legacyArt=spec[1]=="balance"and"moonwarden"or(spec[1]=="restoration"and"groveheart")
     if legacyArt then for _,side in ipairs({"left","right"})do
      local candidate=old[side]
      if type(candidate)=="table"and (candidate.art==legacyArt or candidate.art==nil and side==(legacyArt=="moonwarden"and"left"or"right"))then value=candidate;break end
     end end
    end
    bank.slots[spec[1]]=E.NormalizeSide(value,"left","spells",spec[3]or"none")
    if active then bank.active[spec[1]]=active[spec[1]]==true
    else bank.active[spec[1]]=class=="DRUID"and spec[1]~="feral"or class=="MAGE"and spec[1]=="arcane"or class~="DRUID"and class~="MAGE"and i==1 end
   end
  end
 end
 return result
end
