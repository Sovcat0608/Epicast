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
local function barrageID(id)return readable(id) and type(id)=="number" and (id==400588 or id==400589)end
function E.IsCooldownBuffBinding(b)
    if not b or b.kind~="buff" then return false end
    local id=tonumber(b.spell)
    if id then return barrageID(id) end
    local spell=b.spell:lower()
    if spell=="missile barrage" then return true end
    for _,knownID in ipairs({400588,400589}) do
        local name=call(field(C_Spell,"GetSpellName"),knownID)
        if type(name)=="string" and name:lower()==spell then return true end
    end
    return false
end
local function matches(info)
    for _,key in ipairs({"spellID","overrideSpellID","overrideTooltipSpellID"}) do
        if barrageID(field(info,key)) then return true end
    end
    local linked=field(info,"linkedSpellIDs")
    if type(linked)=="table" then
        for _,id in ipairs(linked) do if barrageID(id) then return true end end
    end
    return false
end
local function readItem(item)
    local id=method(item,"GetCooldownID")
    if type(id)~="number" then id=field(item,"cooldownID") end
    -- Pool releases clear the cooldown ID; reassignment is resolved afresh.
    if type(id)~="number" or id<=0 then return nil,"untracked" end
    local info,status=call(field(C_CooldownViewer,"GetCooldownViewerCooldownInfo"),id)
    if type(info)~="table" then return nil,status=="readable" and "untracked" or status end
    if not matches(info) or field(info,"selfAura")==false then return nil,"untracked" end
    local preview,previewStatus=method(item,"HasEditModeData")
    if preview==true then return nil,"preview" end
    if previewStatus=="restricted" or previewStatus=="error" then return nil,previewStatus end
    local value,activeStatus=method(item,"IsActive")
    if type(value)~="boolean" then value,status=field(item,"isActive")
        if status~="readable" then activeStatus=status end
    end
    if type(value)=="boolean" then return value,value and "active" or "inactive" end
    return nil,activeStatus=="restricted" and "restricted" or activeStatus=="error" and "error" or "unknown"
end
local priority={unavailable=1,untracked=2,hidden=3,preview=4,unknown=5,error=6,restricted=7}
function E.ReadCooldownBuff()
    local result,reason,conflict=nil,"unavailable",false
    local function note(status)
        if (priority[status] or 0)>(priority[reason] or 0) then reason=status end
    end
    for _,key in ipairs({"BuffIconCooldownViewer","BuffBarCooldownViewer"}) do
        local viewer=field(_G,key)
        local visible,status=method(viewer,"IsVisible")
        if visible==true then
            local editing,editStatus=method(viewer,"IsEditing")
            if editing==true then note("preview")
            elseif editStatus=="restricted" or editStatus=="error" then note(editStatus)
            else
                local fn=field(viewer,"GetChildren")
                local children,childStatus=call(function()
                    if type(fn)~="function" then return nil end
                    return {fn(viewer)}
                end)
                if type(children)=="table" then
                    note("untracked")
                    for _,item in ipairs(children) do
                        local value,itemStatus=readItem(item)
                        if type(value)=="boolean" then
                            if result~=nil and result~=value then conflict=true end
                            result=value
                        else note(itemStatus) end
                    end
                else note(childStatus=="readable" and "unavailable" or childStatus) end
            end
        elseif visible==false then note("hidden")
        else note(status) end
    end
    if conflict then return nil,"conflict" end
    if result~=nil then return result,result and "active" or "inactive" end
    return nil,reason
end
