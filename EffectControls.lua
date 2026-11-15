local _,E=...
function E.GetLibraryRows(config)
    local result={}
    local count=#result
    for index,row in ipairs(E.GetAddedEffects(config)) do
        local copy={};for k,v in pairs(row) do copy[k]=v end
        copy.addedIndex=index;result[#result+1]=copy
    end
    return result,count
end
local function write(config,row,key,value)E.EditAddedEffects(config)[row.addedIndex][key]=value end
function E.CreateLibraryControls(panel,button,label,title,gold,muted)
    local state={selected=1,sliders={}}
    panel.layerControls=state
    local outer=panel
    local host=CreateFrame("Frame",nil,outer);host:SetAllPoints();state.host=host;panel=host
    local placement=CreateFrame("Frame",nil,panel);placement:SetAllPoints();state.placement=placement
    local heading=label(panel,"GameFontNormal",gold);heading:SetPoint("TOPLEFT",845,-55);heading:SetText("Native effect layers")
    local caption=label(panel,"GameFontHighlightSmall",muted);caption:SetPoint("TOPLEFT",875,-84);caption:SetWidth(220);caption:SetMaxLines(2)
    local previous=button(panel,"<",24);previous:SetPoint("TOPLEFT",845,-80)
    local next=button(panel,">",24);next:SetPoint("TOPLEFT",1110,-80)
    local remove=button(panel,"Remove layer",130);remove:SetPoint("TOPLEFT",845,-565);state.remove=remove
    local left=button(outer,"Left sister",95);left:SetPoint("TOPLEFT",570,-11)
    local right=button(outer,"Right sister",95);right:SetPoint("TOPLEFT",670,-11)
    left:SetScript("OnClick",function()E.SelectCapSide("left")end)
    right:SetScript("OnClick",function()E.SelectCapSide("right")end)
    local behind=CreateFrame("CheckButton",nil,placement,"UICheckButtonTemplate");behind:SetPoint("TOPLEFT",845,-405);state.behind=behind
    local behindText=label(placement,"GameFontHighlightSmall",muted);behindText:SetPoint("LEFT",behind,"RIGHT",0,0);behindText:SetText("Behind art")
    local function target()
        if InCombatLockdown() then return end
        local c=E.GetEffectLibraryTarget();if not c then return end
        return E.GetLibraryRows(c)[state.selected],c
    end
    for i,spec in ipairs(E.devEffectFields) do
        local key,text,low,high=unpack(spec);local y=-168-(i-1)*49
        local name=label(placement,"GameFontHighlightSmall",muted);name:SetPoint("TOPLEFT",845,y);name:SetText(text)
        local control=CreateFrame("Frame",nil,placement,"MinimalSliderWithSteppersTemplate")
        control:SetPoint("TOPLEFT",847,y-21);control:SetSize(238,20)
        control:Init(low,low,high,high-low,{[MinimalSliderWithSteppersMixin.Label.Right]=function(v)return string.format("%g",v)end})
        local slider=control.Slider;slider.control=control;state.sliders[key]=slider
        slider:EnableMouseWheel(true)
        slider:SetScript("OnMouseWheel",function(self,delta)if target() then self:SetValue(self:GetValue()+delta) end end)
        slider:HookScript("OnValueChanged",function(_,value)
            if state.refreshing then return end
            local row,c=target();if not row then return end
            write(c,row,key,math.max(low,math.min(high,math.floor(value+.5))));E.PreviewLibraryChange()
        end)
    end
    behind:SetScript("OnClick",function(self)
        local row,c=target();if not row then return end
        write(c,row,"effectLayer",self:GetChecked() and "back" or "front");E.PreviewLibraryChange()
    end)
    remove:SetScript("OnClick",function()
        local row,c=target();if not row then return end
        E.RemoveLibraryEffect(c,row.addedIndex)
        E.PreviewLibraryChange();state.Refresh()
    end)
    previous:SetScript("OnClick",function()
        local _,c=target();if not c then return end
        local n=#E.GetLibraryRows(c);if n>0 then state.selected=(state.selected-2)%n+1;state.Refresh() end
    end)
    next:SetScript("OnClick",function()
        local _,c=target();if not c then return end
        local n=#E.GetLibraryRows(c);if n>0 then state.selected=state.selected%n+1;state.Refresh() end
    end)
    local reset=button(placement,"Reset placement",140);reset:SetPoint("TOPLEFT",845,-448);state.reset=reset
    reset:SetScript("OnClick",function()
        local row,c=target();if not row then return end
        for _,spec in ipairs(E.devEffectFields) do row[spec[1]]=nil end
        local normalized=E.NormalizeAddedEffect(row)
        for _,spec in ipairs(E.devEffectFields) do write(c,row,spec[1],normalized[spec[1]]) end
        write(c,row,"effectLayer","front");E.PreviewLibraryChange();state.Refresh()
    end)
    local report=button(placement,"Print values",140);report:SetPoint("TOPLEFT",995,-448);state.report=report
    report:SetScript("OnClick",function()
        local row=target();if not row then return end
        local _,side,mode=E.GetEffectLibraryTarget()
        E.Message(string.format("%s %s layer %d: %s (%d), size=%g%%, angle=%g, X=%g, Y=%g, opacity=%g%%, %s",mode,side,state.selected,row.name,row.fileID,row.trailSize,row.trailAngle,row.trailX,row.trailY,row.trailOpacity,row.effectLayer))
    end)
    local trigger=button(panel,"Test trigger",140);trigger:SetPoint("TOPLEFT",845,-527);state.trigger=trigger
    local stopTest=button(panel,"Stop test",140);stopTest:SetPoint("TOPLEFT",995,-527);state.stopTest=stopTest
    trigger:SetScript("OnClick",function()
        local row,c=target();if not row or not E.GetLayerBinding(c.art,row) then return end
        local _,side=E.GetEffectLibraryTarget()
        if not E.TestCastEffect(side,c.art,row.addedIndex) then E.Message("Effect is not ready or is disabled. Enable the cap's effects and try again.") end
    end)
    stopTest:SetScript("OnClick",function()if E.StopCastEffectTests then E.StopCastEffectTests() end end)
    local note=label(panel,"GameFontHighlightSmall",muted);note:SetPoint("TOPLEFT",845,-602);note:SetText("Use Epicast Save / Cancel to finish.");note:SetWidth(290)
    state.Refresh=function()
        local c,side,mode=E.GetEffectLibraryTarget();if not c then return end
        local context=mode..":"..side..":"..c.art
        if state.context~=context then state.selected=1;state.context=context end
        local rows=E.GetLibraryRows(c);state.selected=math.max(1,math.min(#rows,state.selected));local row=rows[state.selected]
        local testContext=context..":"..state.selected..":"..(row and row.fileID or 0)
        if state.testContext~=testContext or InCombatLockdown() then
            if E.StopCastEffectTests then E.StopCastEffectTests() end
            state.testContext=testContext
        end
        title:SetText("Effects: "..E.SetLabels[mode].." / "..side.." / "..E.artworkByID[c.art].name)
        caption:SetText(row and (state.selected.."/"..#rows.."  "..row.name.." ("..row.fileID..")") or "No added layers")
        local binding=row and E.GetLayerBinding(c.art,row)
        note:SetText(binding and ("Bound: "..binding.kind.." / "..binding.spell) or "Use Epicast Save / Cancel to finish.")
        local enabled=row~=nil and not InCombatLockdown()
        trigger:SetShown(binding~=nil);stopTest:SetShown(binding~=nil)
        trigger:SetEnabled(enabled and binding~=nil);stopTest:SetEnabled(enabled and binding~=nil)
        remove:SetEnabled(enabled);behind:SetEnabled(enabled);reset:SetEnabled(enabled);report:SetEnabled(enabled)
        if state.bindingControls then state.bindingControls.Refresh(row,c,enabled) end
        remove:SetText("Remove layer")
        previous:SetEnabled(enabled and #rows>1);next:SetEnabled(enabled and #rows>1)
        left:SetEnabled(side~="left" and not InCombatLockdown());right:SetEnabled(side~="right" and not InCombatLockdown())
        state.refreshing=true
        for key,slider in pairs(state.sliders) do slider.control:SetEnabled(enabled);if row then slider:SetValue(row[key]) end end
        behind:SetChecked(row and row.effectLayer=="back" or false);state.refreshing=false
    end
    state.bindingControls=E.CreateBindingControls(panel,state,button,label,gold,muted)
    state.previous=previous;state.next=next;state.left=left;state.right=right
    return state
end
