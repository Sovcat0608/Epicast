local _,E=...
local U={gold={1,.82,.3},muted={.68,.72,.8},white={.92,.94,.98}};E.StudioUI=U
function U.Label(parent,text,x,y,width,color,font)
 local t=parent:CreateFontString(nil,"OVERLAY",font or"GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetTextColor(unpack(color or U.muted));t:SetText(text);return t
end
function U.Button(parent,text,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(width,26);b:SetPoint("TOPLEFT",x,y);b:SetText(text);if fn then b:SetScript("OnClick",fn)end;return b
end
function U.Pill(parent,text,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent);b:SetSize(width,22);b:SetPoint("TOPLEFT",x,y)
 -- Build the rounded ends from symmetric bands; no atlas or addon media needed.
 b.fill={}
 local function band(top,height,inset)
  local t=b:CreateTexture(nil,"BACKGROUND");t:SetPoint("TOPLEFT",inset,-top);t:SetPoint("BOTTOMRIGHT",b,"TOPLEFT",width-inset,-top-height);b.fill[#b.fill+1]=t
 end
 for i,inset in ipairs({8,5.5,4,3,2,1.5,1,.5})do band(i-1,1,inset);band(22-i,1,inset)end
 band(8,6,0)
 b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");b.label:SetPoint("CENTER");b:SetFontString(b.label);b:SetText(text)
 b:SetScript("OnEnter",function(self)self.hover=true;U.PillSelected(self,self.selected)end)
 b:SetScript("OnLeave",function(self)self.hover=false;U.PillSelected(self,self.selected)end)
 b:SetScript("OnClick",fn);return b
end
function U.PillSelected(b,selected)
 b.selected=selected
 local r,g,blue=.105,.105,.15
 if selected then r,g,blue=.30,.20,.44 elseif b.hover and b:IsEnabled()then r,g,blue=.17,.15,.23 end
 for _,t in ipairs(b.fill)do t:SetColorTexture(r,g,blue,1)end
 b.label:SetTextColor(unpack(selected and U.white or U.muted))
end
function U.Input(parent,x,y,width)
 local b=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");b:SetSize(width,24);b:SetPoint("TOPLEFT",x,y);b:SetAutoFocus(false);b:SetMaxLetters(100)
 if not b.SetEnabled then function b:SetEnabled(v)if v then self:Enable()else self:Disable();self:ClearFocus()end;self:SetAlpha(v and 1 or .5)end end
 b:SetScript("OnEscapePressed",b.ClearFocus);return b
end
function U.Box(parent,x,y,width,height,name)
 local f=CreateFrame("Frame",name,parent,"BackdropTemplate");f:SetPoint("TOPLEFT",x,y);f:SetSize(width,height)
 f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});f:SetBackdropColor(.035,.035,.055,.98);f:SetBackdropBorderColor(.25,.24,.32,1);return f
end
function U.Tab(parent,text,previous,x,y,fn)
 local b=CreateFrame("Button",nil,parent,"PanelTopTabButtonTemplate");b:SetText(text)
 if previous then b:SetPoint("TOPLEFT",previous,"TOPRIGHT",12,0)else b:SetPoint("TOPLEFT",x,y)end
 PanelTemplates_TabResize(b,0);b:SetScript("OnClick",fn);return b
end
function U.SelectTab(t,selected)
 if selected then PanelTemplates_SelectTab(t)else PanelTemplates_DeselectTab(t)end
 t:SetEnabled(not selected and not InCombatLockdown())
end
function U.Check(parent,text,x,y,fn)
 local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(28,28)
 U.Label(b,text,30,-7,280);b:SetScript("OnClick",fn);return b
end
function U.Menu(owner,choices,current,choose)
 if InCombatLockdown()or not MenuUtil then return end
 MenuUtil.CreateContextMenu(owner,function(_,root)
  for _,v in ipairs(choices)do local id=v[1];root:CreateRadio(v[2],function()return id==current end,function()choose(id)end)end
 end)
end
function U.Row(parent,x,y,width,fn)
 local b=CreateFrame("Button",nil,parent,"BackdropTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,43)
 b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
 b.title=U.Label(b,"",9,-6,width-18,U.white);b.title:SetMaxLines(1)
 b.detail=U.Label(b,"",9,-24,width-18);b.detail:SetMaxLines(1);b:SetScript("OnClick",fn);return b
end
local relationshipColors={
 blue={.075,.15,.29,.30,.66,1},
 green={.06,.22,.14,.31,.86,.50},
}
function U.RowSelected(b,selected,relationship)
 b.selected=selected
 b.relationship=not selected and relationship or nil
 local color=relationshipColors[b.relationship]
 if color then
  b:SetBackdropColor(color[1],color[2],color[3],1)
  b:SetBackdropBorderColor(color[4],color[5],color[6],1)
  return
 end
 b:SetBackdropColor(selected and .18 or .065,selected and .12 or .065,selected and .25 or .09,1)
 b:SetBackdropBorderColor(selected and .7 or .19,selected and .5 or .19,selected and 1 or .25,1)
end
