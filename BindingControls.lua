local _,E=...
function E.CreateBindingControls(panel,state,button,label,gold,muted)
    local ui={tab="placement",pages={placement=state.placement},tabs={}};state.bindingUI=ui
    local function target()
        if InCombatLockdown() then return end
        local c=E.GetEffectLibraryTarget();if c then return E.GetLibraryRows(c)[state.selected],c end
    end
    local function changed()E.PreviewLibraryChange();state.Refresh()end
    local function edit(fn)
        local row,c=target();if not row or not row.addedIndex or c.role=="resources" then return end
        E.SetLayerBehavior(c,row.addedIndex,"bound");fn(E.EditAddedEffects(c)[row.addedIndex]);changed()
    end
    for i,key in ipairs({"placement","trigger","animation"})do
        local b=button(panel,key:sub(1,1):upper()..key:sub(2),94);b:SetPoint("TOPLEFT",845+(i-1)*100,-125);ui.tabs[key]=b
        if key~="placement" then local page=CreateFrame("Frame",nil,panel);page:SetPoint("TOPLEFT",845,-168);page:SetSize(300,340);ui.pages[key]=page end
        b:SetScript("OnClick",function()ui.tab=key;state.Refresh()end)
    end
    local function text(parent,value,x,y)
        local t=label(parent,"GameFontHighlightSmall",muted);t:SetPoint("TOPLEFT",x or 0,y);t:SetWidth(290);t:SetText(value);return t
    end
    local function input(parent,title,y,width)
        text(parent,title,0,y)
        local b=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");b:SetSize(width or 285,24);b:SetPoint("TOPLEFT",5,y-23);b:SetAutoFocus(false);b:SetMaxLetters(100)
        if not b.SetEnabled then function b:SetEnabled(v)if v then self:Enable()else self:Disable();self:ClearFocus()end;self:SetAlpha(v and 1 or .5)end end
        b:SetScript("OnEscapePressed",function(self)self:ClearFocus();state.Refresh()end);return b
    end
    local trigger=ui.pages.trigger
    ui.static=button(trigger,"Static",140);ui.static:SetPoint("TOPLEFT",0,0)
    ui.bound=button(trigger,"Bound",140);ui.bound:SetPoint("TOPLEFT",150,0)
    ui.static:SetScript("OnClick",function()local r,c=target();if r and r.addedIndex then E.SetLayerBehavior(c,r.addedIndex,"static");changed()end end)
    ui.bound:SetScript("OnClick",function()edit(function()end)end)
    ui.kind=button(trigger,"Cast succeeds",290);ui.kind:SetPoint("TOPLEFT",0,-43)
    ui.kind:SetScript("OnClick",function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            local row,c=target();if not row or not row.addedIndex then return end
            local current=E.GetLayerBinding(c.art,row)
            MenuUtil.CreateContextMenu(self,function(_,root)
                for _,v in ipairs(E.BindingKinds)do
                    local key=v[1]
                    root:CreateRadio(v[2],function()return current and current.kind==key end,function()edit(function(r)r.binding.kind=key end)end)
                end
            end)
            return
        end
        edit(function(r)
        local i=1;for n,v in ipairs(E.BindingKinds)do if v[1]==r.binding.kind then i=n end end
        r.binding.kind=E.BindingKinds[i%#E.BindingKinds+1][1]
        end)
    end)
    ui.spell=input(trigger,"Player spell / buff name or exact ID",-83)
    ui.feedback=text(trigger,"",0,-140)
    ui.bind=button(trigger,"Bind spell",140);ui.bind:SetPoint("TOPLEFT",0,-184)
    local function bind()
        local v=ui.spell:GetText():match("^%s*(.-)%s*$");edit(function(r)r.binding.spell=v end);ui.spell:ClearFocus()
    end
    ui.bind:SetScript("OnClick",bind);ui.spell:SetScript("OnEnterPressed",bind)
    ui.duration=input(trigger,"Burst length in seconds (Enter to apply)",-224,100)
    ui.duration:SetScript("OnEnterPressed",function(self)
        local n=tonumber(self:GetText());if n and n>=.05 and n<=60 then edit(function(r)r.binding.duration=n end)end
        self:ClearFocus();state.Refresh()
    end)
    text(trigger,"Names match ranks; IDs match exactly. Proc tracks the spell whose button glows. Pulses need matching channel success events.",0,-287)
    local animation=ui.pages.animation
    ui.summary=text(animation,"",0,0)
    ui.sequence=input(animation,"Main animation ID (Enter to apply)",-62,100)
    local function sequence(r,c,n)
        if not r.behavior and E.GetLayerBinding(c.art,r) then E.SetLayerBehavior(c,r.addedIndex,"bound")end
        E.EditAddedEffects(c)[r.addedIndex].animation=n;changed()
    end
    ui.sequence:SetScript("OnEnterPressed",function(self)
        local r,c=target();local n=tonumber(self:GetText())
        if r and r.addedIndex and n and n==math.floor(n) and n>=0 and n<=65535 and E.AnimationAvailable(r.fileID,n) then
            sequence(r,c,n)
        end
        self:ClearFocus();state.Refresh()
    end)
    ui.segments={}
    for i,v in ipairs({{"Stand / intro",0},{"Hold",158},{"End",159}})do
        local b=button(animation,v[1],94);b:SetPoint("TOPLEFT",(i-1)*100,-120);ui.segments[v[2]]=b
        b:SetScript("OnClick",function()local r,c=target();if r and r.addedIndex and E.AnimationAvailable(r.fileID,v[2]) then
            sequence(r,c,v[2])
        end end)
    end
    for i,v in ipairs({{"intro","Intro before main",0},{"outro","End when inactive",159}})do
        local key=v[1];local box=CreateFrame("CheckButton",nil,animation,"UICheckButtonTemplate");box:SetPoint("TOPLEFT",0,-163-(i-1)*40);ui[key]=box
        local t=text(animation,v[2],30,-171-(i-1)*40)
        box:SetScript("OnClick",function(self)edit(function(r)
            r.binding[key]=self:GetChecked()==true
            local meta=E.EffectAnimations and E.EffectAnimations[r.fileID]
            if meta and meta[v[3]] then r.binding[key.."Duration"]=math.max(.05,math.min(10,meta[v[3]]))end
        end)end)
    end
    ui.timing=input(animation,"Intro / end seconds (e.g. 0.5 / 0.5)",-257)
    ui.timing:SetScript("OnEnterPressed",function(self)
        local a,b=self:GetText():match("^%s*([%d%.]+)%s*/%s*([%d%.]+)%s*$");a,b=tonumber(a),tonumber(b)
        if a and b and a>=.05 and a<=10 and b>=.05 and b<=10 then edit(function(r)r.binding.introDuration=a;r.binding.outroDuration=b end)end
        self:ClearFocus();state.Refresh()
    end)
    local title=text(panel,"Layers on this sister",18,-471);title:SetTextColor(unpack(gold))
    ui.layers={}
    for i=1,5 do local b=button(panel,"",290);b:SetPoint("TOPLEFT",18,-497-(i-1)*27);ui.layers[i]=b
        b:SetScript("OnClick",function()if target() then state.selected=b.index;state.Refresh()end end)
    end
    function ui.Refresh(row,c,enabled)
        for key,page in pairs(ui.pages)do page:SetShown(ui.tab==key);ui.tabs[key]:SetEnabled(ui.tab~=key)end
        local b=row and E.GetLayerBinding(c.art,row);local editable=enabled and row.addedIndex~=nil
        ui.static:SetEnabled(editable and b~=nil);ui.bound:SetEnabled(editable and b==nil and c.role~="resources")
        for _,control in ipairs({ui.kind,ui.spell,ui.bind,ui.duration,ui.timing})do control:SetEnabled(editable and b~=nil)end
        ui.duration:SetEnabled(editable and b~=nil and (b.kind=="success" or b.kind=="pulse"))
        ui.sequence:SetEnabled(editable)
        if not ui.spell:HasFocus()then ui.spell:SetText(b and b.spell or "")end
        if not ui.duration:HasFocus()then ui.duration:SetText(tostring(b and b.duration or 1))end
        ui.sequence:SetText(tostring(row and row.animation or 0))
        ui.timing:SetText(string.format("%g / %g",b and b.introDuration or .5,b and b.outroDuration or .5))
        ui.kind:SetText("Choose trigger >")
        for _,v in ipairs(E.BindingKinds)do if b and b.kind==v[1] then ui.kind:SetText(v[2].."  >")end end
        ui.summary:SetText(row and E.AnimationSummary(row.fileID) or "Select an effect")
        for id,button in pairs(ui.segments)do button:SetEnabled(editable and E.AnimationAvailable(row.fileID,id))end
        for _,key in ipairs({"intro","outro"})do ui[key]:SetChecked(b and b[key] or false);ui[key]:SetEnabled(editable and b~=nil and E.AnimationAvailable(row.fileID,key=="intro" and 0 or 159))end
        local display=b and b.spell or "";local resolved
        if display~="" and C_Spell and C_Spell.GetSpellInfo then
            local ok,v=pcall(C_Spell.GetSpellInfo,tonumber(display)or display)
            if ok and not(issecretvalue and issecretvalue(v)) and type(v)=="table" and not(issecrettable and issecrettable(v)) and not(issecretvalue and issecretvalue(v.name)) then resolved=v.name end
        end
        ui.feedback:SetText(c.role=="resources" and "Resource layers follow the selected health / power level. Spell bindings belong to the Spellcasting set." or not b and "Always active. The native animation continues playing." or display=="" and "Enter a spell or buff, then Bind spell." or resolved and ("Tracking: "..resolved) or "Saved name / ID. Not found in spellbook; buff names can still match.")
        local rows=E.GetLibraryRows(c);local first=math.floor((state.selected-1)/5)*5+1
        for i,button in ipairs(ui.layers)do local index=first+i-1;local r=rows[index];button.index=index;button:SetShown(r~=nil)
            if r then button:SetText((index==state.selected and "> " or "")..index.." · "..(E.GetLayerBinding(c.art,r) and "Bound" or "Static").." · "..r.name);button:SetEnabled(not InCombatLockdown())end
        end
    end
    return ui
end
