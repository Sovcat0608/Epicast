local _,E=...
-- Read-only bridge to Forever's native tracked-buff viewers. Never inspect aura
-- instances, hook native updates, or treat a visible icon as an active proc.
local function readable(v)
    return not(issecretvalue and issecretvalue(v))
        and not(type(v)=="table" and issecrettable and issecrettable(v))
end
local function call(fn,...)
    if not readable(fn) or type(fn)~="function" then return nil,"unavailable" end
    local ok,v=pcall(fn,...)
    if not ok then return nil,"error" end
    if not readable(v) then return nil,"restricted" end
    return v,"readable"
end
local function field(object,key)
    if not readable(object) then return nil,"restricted" end
    if type(object)~="table" and type(object)~="userdata" then return nil,"unavailable" end
    return call(function()return object[key]end)
end
local function method(object,key,...)
    local fn,status=field(object,key)
    if status~="readable" then return nil,status end
    return call(fn,object,...)
end
local profiles={
    {key="barrage",label="Barrage",ids={400588,400589},names={"missile barrage"},track="Missile Barrage"},
    {key="druidClearcasting",label="Clearcasting",class="DRUID",ids={16864,16870},names={"clearcasting","omen of clarity"},track="Omen of Clarity / Clearcasting"},
}
local function knownID(profile,id)
    if not readable(id) or type(id)~="number" then return false end
    for _,known in ipairs(profile.ids)do if id==known then return true end end
    return false
end
local function profileFor(b,anyKind)
    if not b or (not anyKind and b.kind~="buff") then return end
    local id=tonumber(b.spell)
    local spell=b.spell:lower()
    for _,profile in ipairs(profiles)do
        local class=profile.class and call(E.ActiveClass)
        if not profile.class or class==profile.class then
            if id then
                if knownID(profile,id) then return profile end
            else
                for _,name in ipairs(profile.names)do if spell==name then return profile end end
                for _,known in ipairs(profile.ids)do
                    local name=call(field(C_Spell,"GetSpellName"),known)
                    if type(name)=="string" and name:lower()==spell then return profile end
                end
            end
        end
    end
end
function E.IsCooldownBuffBinding(b)
    local profile=profileFor(b)
    return profile~=nil,profile and profile.key
end
function E.CooldownBuffHint(b)
    local profile=profileFor(b,true)
    if not profile then return end
    if b.kind=="proc" then return "Use While buff active for "..profile.label.."." end
    if b.kind=="buff" then return "Track "..profile.track.." in Tracked Buffs or Bars (Always). Epicast may hide the display." end
end
local function matches(info,profile)
    for _,key in ipairs({"spellID","overrideSpellID","overrideTooltipSpellID"}) do
        if knownID(profile,field(info,key)) then return true end
    end
    local linked=field(info,"linkedSpellIDs")
    if type(linked)=="table" then
        for _,id in ipairs(linked) do if knownID(profile,id) then return true end end
    end
    return false
end
local function identify(item,profile)
    local id=method(item,"GetCooldownID")
    if type(id)~="number" then id=field(item,"cooldownID") end
    -- Pool releases clear the cooldown ID; reassignment is resolved afresh.
    -- The native API specifies a number; do not assume zero is invalid.
    if type(id)~="number" or id~=id or id==math.huge or id==-math.huge then return nil,"untracked" end
    local info,status=call(field(C_CooldownViewer,"GetCooldownViewerCooldownInfo"),id)
    local source="api"
    if type(info)~="table" then
        -- GetCooldownInfo only returns the item's cached metadata; it does not
        -- query auras or refresh native state. Reject mismatched pooled data.
        local cached=method(item,"GetCooldownInfo")
        if type(cached)=="table" then
            local cachedID,cachedStatus=field(cached,"cooldownID")
            if cachedStatus=="readable"and cachedID==id then info=cached;source="item" end
        end
    end
    if type(info)~="table" then return nil,status=="readable" and "untracked" or status,id end
    -- selfAura describes the catalog entry (which may be a talent), not the
    -- current active buff. Exact mapped IDs in a buff viewer identify the proc.
    return matches(info,profile),"identified",id,info,source
end
local function readActive(item)
    local preview,previewStatus=method(item,"HasEditModeData")
    if preview==true then return nil,"preview" end
    if previewStatus=="restricted" or previewStatus=="error" then return nil,previewStatus end
    local value,activeStatus=method(item,"IsActive")
    if type(value)~="boolean" then
        local fallbackStatus;value,fallbackStatus=field(item,"isActive")
        if fallbackStatus~="readable" then activeStatus=fallbackStatus end
    end
    if type(value)=="boolean" then return value,value and "active" or "inactive" end
    return nil,activeStatus=="restricted" and "restricted" or activeStatus=="error" and "error" or "unknown"
end
local priority={unavailable=1,hidden=2,untracked=3,preview=4,unknown=5,error=6,restricted=7}
local function items(viewer)
    local list,status=method(viewer,"GetItemFrames")
    if type(list)=="table" then return list,"layout" end
    local fn=field(viewer,"GetChildren")
    local children,childStatus=call(function()
        if type(fn)=="function" then return {fn(viewer)} end
    end)
    if type(children)=="table" then return children,"children" end
    return nil,childStatus=="readable" and status or childStatus
end
local function describe(value)
    if not readable(value) then return "restricted" end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    return "unknown"
end
function E.ReadCooldownBuff(detailed,profileKey)
    local profile
    for _,candidate in ipairs(profiles)do if candidate.key==(profileKey or "barrage")then profile=candidate;break end end
    if not profile then return nil,"unavailable",{} end
    local result,reason,conflict=nil,"unavailable",false
    local reports={}
    local function note(status)
        if (priority[status] or 0)>(priority[reason] or 0) then reason=status end
    end
    for _,key in ipairs({"BuffIconCooldownViewer","BuffBarCooldownViewer"}) do
        local viewer=field(_G,key)
        local visible,status=method(viewer,"IsVisible")
        local report={name=key,visible=describe(visible),status=status,count=0,matches=0,items={}}
        reports[#reports+1]=report
        local function scan(accept)
            local children,childStatus=items(viewer);report.discovery=childStatus
            if type(children)~="table" then if accept then note(childStatus)end;report.status=childStatus;return end
            local rowResult,rowConflict,rowReason=nil,false,"untracked"
            for _,item in ipairs(children)do
                report.count=report.count+1
                local matched,itemStatus,id,info,source=identify(item,profile)
                local value
                if matched then
                    report.matches=report.matches+1
                    value,itemStatus=readActive(item)
                    if type(value)=="boolean" then
                        if rowResult~=nil and rowResult~=value then rowConflict=true end
                        rowResult=value
                        if accept then
                            if result~=nil and result~=value then conflict=true end
                            result=value
                        end
                    end
                elseif matched==false then itemStatus="untracked" end
                if (priority[itemStatus]or 0)>(priority[rowReason]or 0)then rowReason=itemStatus end
                if accept and value==nil then note(itemStatus)end
                if detailed and id~=nil then
                    local spells={}
                    for _,fieldKey in ipairs({"spellID","overrideSpellID","overrideTooltipSpellID"})do spells[#spells+1]=describe(field(info,fieldKey))end
                    local linked=field(info,"linkedSpellIDs")
                    if type(linked)=="table" then for _,spell in ipairs(linked)do if #spells<16 then spells[#spells+1]=describe(spell)end end end
                    report.items[#report.items+1]=string.format("id=%s spells=%s selfAura=%s metadata=%s %s=%s state=%s",
                        describe(id),table.concat(spells,"/"),describe(field(info,"selfAura")),source or"none",profile.key,tostring(matched==true),itemStatus)
                end
            end
            report.status=rowConflict and"conflict"or(rowResult~=nil and(rowResult and"active"or"inactive")or rowReason)
            if accept then note(rowReason)end
        end
        if visible==true then
            local editing,editStatus=method(viewer,"IsEditing")
            if editing==true then note("preview");report.status="preview"
            elseif editStatus=="restricted" or editStatus=="error" then note(editStatus);report.status=editStatus
            else scan(true)end
        elseif visible==false then
            note("hidden");if detailed then scan(false)end;report.status="hidden"
        else note(status);report.status=status end
    end
    if conflict then return nil,"conflict",reports end
    if result~=nil then return result,result and "active" or "inactive",reports end
    return nil,reason,reports
end
function E.PrintCooldownBuffStatus(keys)
    keys=keys or {barrage=true}
    for _,profile in ipairs(profiles)do if keys[profile.key] then
        local _,status,reports=E.ReadCooldownBuff(true,profile.key)
        E.Message(profile.label.." native sample: "..status.."; hidden-row states are diagnostic only")
        for _,report in ipairs(reports)do
            E.Message(string.format("%s: visible=%s, state=%s, items=%d, %s matches=%d, scan=%s",
                report.name,report.visible,report.status,report.count,profile.label,report.matches,report.discovery or"none"))
            for index,item in ipairs(report.items)do if index<=24 then E.Message("  "..item)end end
        end
    end end
end
