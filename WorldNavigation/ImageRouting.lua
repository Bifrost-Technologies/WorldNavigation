local N=WorldNavigation
function N:RegisterImageMap(pack)
 if type(pack)~='table'or type(pack.width)~='number'or type(pack.height)~='number'or pack.width%1~=0 or pack.height%1~=0 or pack.width<2 or pack.height<2 or pack.width*pack.height>100000 or type(pack.rows)~='table'or #pack.rows~=pack.height then return false end
 for _,row in ipairs(pack.rows)do if type(row)~='string'or #row~=pack.width or row:find('[^0-9a-f]')then return false end end
 self.imageMaps=self.imageMaps or {};self.imageMaps[#self.imageMaps+1]=pack;return true
end
function N:ImagePlan(from,to,tick)
 if not CreateVector2D or not C_Map or not C_Map.GetMapPosFromWorldPos or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not CreateVector2D or not C_Map or not C_Map.GetMapPosFromWorldPos or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not CreateVector2D or not C_Map or not C_Map.GetMapPosFromWorldPos or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not self:Location(from)or not self:Location(to)or from.map~=to.map then return end
 local function project(p,map)
  local id,pos=self:Read(C_Map and C_Map.GetMapPosFromWorldPos,p.map,CreateVector2D(p.x,p.y),map)
  if id~=map or not pos then return end
  local x,y=self:Read(pos.GetXY,pos)
  if self:Finite(x)and self:Finite(y)and x>=0 and x<=1 and y>=0 and y<=1 then return x,y end
 end
 for _,pack in ipairs(self.imageMaps or {})do
  if tick then tick()end
  -- Dungeon images without an explicit native UI-map/floor binding remain assets only.
  local map=pack.uiMapID
  if map then
   local sx,sy=project(from,map);local ex,ey=project(to,map)
   if sx and ex then
    local w,h=pack.width,pack.height
    local function cell(x,y)return math.min(h-1,math.floor(y*h))*w+math.min(w-1,math.floor(x*w))+1 end
    local marks={}
    local function world(x,y)
     local continent,pos=self:Read(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
     if continent==from.map and pos then local a,b=self:Read(pos.GetXY,pos);if self:Finite(a)and self:Finite(b)then return {x=a,y=b,map=continent}end end
    end
    local corner,right,bottom=world(0,0),world(1,0),world(0,1)
    if corner and right and bottom then
     local wx,wy=self:Distance(corner,right),self:Distance(corner,bottom)
     if wx>0 and wy>0 then
      local function mark(p,blocked,risk)
       local x,y=project(p,map)
       if x and self:Finite(p.radius)and p.radius>0 then marks[#marks+1]={x=x*w,y=y*h,rx=p.radius/wx*w+.5,ry=p.radius/wy*h+.5,blocked=blocked,risk=risk}end
      end
      local db=self:DB();for _,p in ipairs(db.blocks)do mark(p,true,1)end
      local now=self:Read(GetServerTime)or 0;local level=self:Read(UnitLevel,'player')
      for _,p in pairs(db.hazards)do if p.expires>now then mark(p,false,self:Finite(level)and p.maxMob and level>=p.maxMob+5 and not p.elite and 2 or 30)end end
     end
    end
    local weights={}
    local function weight(id)
     if weights[id]~=nil then return weights[id]end
     local x=(id-1)%w+1;local y=math.floor((id-1)/w)+1;local cost=tonumber(pack.rows[y]:sub(x,x),16)
     for _,mark in ipairs(marks)do if ((x-.5-mark.x)/mark.rx)^2+((y-.5-mark.y)/mark.ry)^2<=1 then
      if mark.blocked then cost=0;break else cost=cost*mark.risk end
     end end
     weights[id]=cost;return cost
    end
    local start,goal=cell(sx,sy),cell(ex,ey)
    if weight(start)>0 and weight(goal)>0 then
     local heap={};local function push(id,cost)
      local i=#heap+1;heap[i]={id=id,cost=cost};while i>1 do local p=math.floor(i/2);if heap[p].cost<=cost then break end;heap[i],heap[p]=heap[p],heap[i];i=p end
     end
     local function pop()
      local value=heap[1].id;local last=table.remove(heap)
      if #heap>0 then heap[1]=last;local i=1;while i*2<=#heap do local c=i*2;if c<#heap and heap[c+1].cost<heap[c].cost then c=c+1 end;if heap[i].cost<=heap[c].cost then break end;heap[i],heap[c]=heap[c],heap[i];i=c end end
      return value
     end
     local function estimate(id)return math.abs((id-1)%w-(goal-1)%w)+math.abs(math.floor((id-1)/w)-math.floor((goal-1)/w))end
     local costs,parent,closed={[start]=0},{},{};push(start,estimate(start))
     while #heap>0 do
      if tick then tick()end
      local id=pop()
      if id==goal then
       local ids={id};while id~=start do id=parent[id];ids[#ids+1]=id end
       local points={self:Copy(from)}
       local function append(p)
        local a=points[#points];local dx,dy=p.x-a.x,p.y-a.y;local steps=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/4))
        if #points+steps>20000 then return false end
        for i=1,steps do if tick then tick()end;points[#points+1]={x=a.x+dx*i/steps,y=a.y+dy*i/steps,map=p.map}end
        return true
       end
       for index=#ids-1,2,-1 do
        local c=ids[index];local x=((c-1)%w+.5)/w;local y=(math.floor((c-1)/w)+.5)/h
        local continent,pos=self:Read(C_Map and C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
        if continent~=from.map or not pos then return nil,'Map image cannot be aligned to this continent.'end
        local wx,wy=self:Read(pos.GetXY,pos);if not self:Finite(wx)or not self:Finite(wy)then return end
        if not append({x=wx,y=wy,map=continent})then return nil,'Image route exceeds point budget.'end
        if #points>20000 then return nil,'Image route exceeds point budget.'end
       end
       if not append(to)then return nil,'Image route exceeds point budget.'end
       return {points=points,cost=costs[goal],imageBased=true,terrainVerified=false,source=pack.name..' map-image estimate; roads/texture weights, elevation unknown'}
      end
      if not closed[id]then
       closed[id]=true;local x=(id-1)%w;local y=math.floor((id-1)/w)
       local neighbors={};if x>0 then neighbors[#neighbors+1]=id-1 end;if x<w-1 then neighbors[#neighbors+1]=id+1 end;if y>0 then neighbors[#neighbors+1]=id-w end;if y<h-1 then neighbors[#neighbors+1]=id+w end
       for _,nextID in ipairs(neighbors)do
        local cost=weight(nextID)
        if cost>0 and(not costs[nextID]or costs[id]+cost<costs[nextID])then costs[nextID]=costs[id]+cost;parent[nextID]=id;push(nextID,costs[nextID]+estimate(nextID))end
       end
      end
     end
    end
   end
  end
 end
 if self.MultiImagePlan then return self:MultiImagePlan(from,to,tick)end
 return nil,'Cross-zone image planner is not loaded.'
end
