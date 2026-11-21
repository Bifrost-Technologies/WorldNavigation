local N=WorldNavigation
function N:Show()
 if not self.statusFrame then
  local f=CreateFrame('Frame','WorldNavigationStatus',UIParent,'BackdropTemplate');self.statusFrame=f
  f:SetSize(520,190);f:SetPoint('CENTER');f:EnableMouse(true);f:SetFrameStrata('DIALOG')
  table.insert(UISpecialFrames,'WorldNavigationStatus')
  table.insert(UISpecialFrames,'WorldNavigationStatus')
  table.insert(UISpecialFrames,'WorldNavigationStatus')
  f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'});f:SetBackdropColor(.035,.05,.075,.98)
  f.text=f:CreateFontString(nil,'OVERLAY','GameFontHighlight');f.text:SetPoint('TOPLEFT',20,-20);f.text:SetSize(480,125);f.text:SetTextColor(.2,.8,1)
  local close=CreateFrame('Button',nil,f,'UIPanelCloseButton');close:SetPoint('TOPRIGHT');close:SetScript('OnClick',function()f:Hide()end)
 end
 local bound,unbound=0,0;for _,pack in ipairs(self.imageMaps or {})do if pack.uiMapID then bound=bound+1 else unbound=unbound+1 end end
 self.statusFrame.text:SetText('FLIGHT NAVIGATION / AUTOMATIC TERRAIN\nTerrain packs: '..#(self.terrainPacks or {})..'\nImage maps: '..bound..' bound / '..unbound..' image-only'..'\nRoad-weight estimates and known hazard costs. No route recording.\nImage routes use estimated color/texture weights; elevation is unknown.')
 self.statusFrame:Show()
end
SLASH_FLIGHTNAVSTATUS1='/wnav';SlashCmdList.FLIGHTNAVSTATUS=function()N:Show()end
