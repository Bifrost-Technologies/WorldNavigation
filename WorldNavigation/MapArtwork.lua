local N=WorldNavigation
function N:CaptureMapArtwork(map)
 local info=self:Read(C_Map and C_Map.GetMapInfo,map);if not info then return end
 local layers=self:Read(C_Map and C_Map.GetMapArtLayers,map)
 if type(layers)~='table'then return end
 local data={id=map,name=info.name,mapType=info.mapType,artID=self:Read(C_Map.GetMapArtID,map),layers={}}
 for index,layer in ipairs(layers)do
  local textures=self:Read(C_Map.GetMapArtLayerTextures,map,index)
  if type(textures)=='table'then data.layers[#data.layers+1]={width=layer.layerWidth,height=layer.layerHeight,tileWidth=layer.tileWidth,tileHeight=layer.tileHeight,textures=textures}end
 end
 self:DB().mapArtwork=self:DB().mapArtwork or {};self:DB().mapArtwork[map]=data
 return data
end
SLASH_WNAVMAPART1='/wnavmaps';SlashCmdList.WNAVMAPART=function(text)
 local map=tonumber(text)or N:Read(C_Map and C_Map.GetBestMapForUnit,'player')
 if not map then return end
 N:CaptureMapArtwork(map)
 for _,child in ipairs(N:Read(C_Map and C_Map.GetMapChildrenInfo,map,nil,true)or {})do N:CaptureMapArtwork(child.mapID)end
 local group=N:Read(C_Map and C_Map.GetMapGroupID,map)
 for _,floor in ipairs(group and N:Read(C_Map.GetMapGroupMembersInfo,group)or {})do N:CaptureMapArtwork(floor.mapID)end
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('Navigation: captured native map/floor texture IDs for '..map..'. Saved in WorldNavigationDB after reload/logout. Image costs are estimates; not a heightmap.')end
end

local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_ENTERING_WORLD');events:RegisterEvent('ZONE_CHANGED_NEW_AREA')
events:SetScript('OnEvent',function()
 local map=N:Read(C_Map and C_Map.GetBestMapForUnit,'player')
 if map then N:CaptureMapArtwork(map);local group=N:Read(C_Map and C_Map.GetMapGroupID,map);for _,floor in ipairs(group and N:Read(C_Map.GetMapGroupMembersInfo,group)or {})do N:CaptureMapArtwork(floor.mapID)end end
end)
