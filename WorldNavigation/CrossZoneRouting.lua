-- Cross-zone search over the union of native-georeferenced image rasters.
local N=WorldNavigation
function N:MultiImagePlan(from,to,tick)
 if not CreateVector2D or not C_Map or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not CreateVector2D or not C_Map or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not CreateVector2D or not C_Map or not C_Map.GetWorldPosFromMapPos then return nil,'Native map projection APIs are unavailable.'end
 if not self:Location(from)or not self:Location(to)or from.map~=to.map then return nil,'Endpoints are on different continents.'end
 local packs={}
 local function world(map,x,y)
  local continent,v=self:Read(C_Map and C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
  if continent~=from.map or not v or not v.GetXY then return end
  local a,b=self:Read(v.GetXY,v);if self:Finite(a)and self:Finite(b)then return a,b end
 end
 for _,pack in ipairs(self.imageMaps or {})do
  if tick then tick()end
  if pack.uiMapID then
   local ax,ay=world(pack.uiMapID,0,0);local bx,by=world(pack.uiMapID,1,0);local cx,cy=world(pack.uiMapID,0,1)
   if ax and bx and cx then
    local ux,uy,vx,vy=bx-ax,by-ay,cx-ax,cy-ay;local determinant=ux*vy-uy*vx
    if math.abs(determinant)>1 then packs[#packs+1]={image=pack,x=ax,y=ay,ux=ux,uy=uy,vx=vx,vy=vy,det=determinant,area=math.abs(determinant)}end
   end
  end
 end
 table.sort(packs,function(a,b)return a.area<b.area end)
 if #packs==0 then return nil,'No image maps can be aligned to this continent on the current client.'end
 local db=self:DB();local hazards={};local level=self:Read(UnitLevel,'player');local now=self:Read(GetServerTime)or 0
 for _,p in pairs(db.hazards or {})do if p.map==from.map and p.expires>now then hazards[#hazards+1]={x=p.x,y=p.y,r=p.radius,cost=self:Finite(level)and p.maxMob and level>=p.maxMob+5 and not p.elite and 2 or 30}end end
 local function field(x,y)
  local cost
  for _,p in ipairs(packs)do
   local dx,dy=x-p.x,y-p.y;local u=(dx*p.vy-dy*p.vx)/p.det;local v=(p.ux*dy-p.uy*dx)/p.det
   if u>=0 and u<=1 and v>=0 and v<=1 then
    local image=p.image;local column=math.min(image.width,math.floor(u*image.width)+1);local row=math.min(image.height,math.floor(v*image.height)+1)
    local value=tonumber(image.rows[row]:sub(column,column),16)
    -- Another overlapping zone can supply real pixels where an image's artificial border is zero.
    if value and value>0 then cost=value;break end
   end
  end
  if not cost then return 0 end
  for _,p in ipairs(db.blocks or {})do if p.map==from.map and (x-p.x)^2+(y-p.y)^2<(p.radius or 6)^2 then return 0 end end
  for _,p in ipairs(hazards)do if (x-p.x)^2+(y-p.y)^2<(p.r+8)^2 then cost=cost*p.cost end end
  return cost
 end
 if field(from.x,from.y)==0 then return nil,'Start position has no traversable image coverage; images loaded, but native alignment/blocked pixels need review.'end
 if field(to.x,to.y)==0 then return nil,'Destination has no traversable image coverage; images loaded, but native alignment/blocked pixels need review.'end
 local step=16;local gx=math.floor((to.x-from.x)/step+.5);local gy=math.floor((to.y-from.y)/step+.5)
 local minx,maxx=math.min(0,gx)-128,math.max(0,gx)+128;local miny,maxy=math.min(0,gy)-128,math.max(0,gy)+128
 local width=maxx-minx+1
 local function id(x,y)return (y-miny)*width+(x-minx)+1 end
 local function coords(key)local n=key-1;return n%width+minx,math.floor(n/width)+miny end
 local costs={}
 local function weight(key)
  if costs[key]~=nil then return costs[key]end
  local x,y=coords(key);local value=field(from.x+x*step,from.y+y*step);costs[key]=value;return value
 end
 local function segment(ax,ay,bx,by)
  local length=math.sqrt((bx-ax)^2+(by-ay)^2);local count=math.max(1,math.ceil(length/4));local sum=0
  for i=1,count do local cost=field(ax+(bx-ax)*i/count,ay+(by-ay)*i/count);if cost==0 then return end;sum=sum+cost end
  return sum/count
 end
 local goal,best
 for dx=-2,2 do for dy=-2,2 do local x,y=gx+dx,gy+dy;local wx,wy=from.x+x*step,from.y+y*step;local distance=(wx-to.x)^2+(wy-to.y)^2
  if (not best or distance<best)and weight(id(x,y))>0 and segment(wx,wy,to.x,to.y)then goal=id(x,y);best=distance end
 end end
 if not goal then return nil,'No image-covered approach connects to the destination.'end
 local start=id(0,0);local goalx,goaly=coords(goal);local heap={}
 local function estimate(x,y)return math.abs(x-goalx)+math.abs(y-goaly)end
 local function push(key,cost)
  local i=#heap+1;heap[i]={id=key,cost=cost};while i>1 do local parent=math.floor(i/2);if heap[parent].cost<=cost then break end;heap[i],heap[parent]=heap[parent],heap[i];i=parent end
 end
 local function pop()
  local first=heap[1];local last=table.remove(heap)
  if #heap>0 then heap[1]=last;local i=1;while i*2<=#heap do local c=i*2;if c<#heap and heap[c+1].cost<heap[c].cost then c=c+1 end;if heap[i].cost<=heap[c].cost then break end;heap[i],heap[c]=heap[c],heap[i];i=c end end
  return first.id
 end
 local distance,parent,closed={[start]=0},{},{};push(start,estimate(0,0));local expanded=0
 while #heap>0 do
  if tick then tick()end
  local key=pop()
  if not closed[key]then
   closed[key]=true;expanded=expanded+1
   if expanded>750000 then return nil,'Cross-zone image search budget reached; choose an intermediate flight stop.'end
   if key==goal then
    local reverse={key};while key~=start do key=parent[key];reverse[#reverse+1]=key end
    local points={self:Copy(from)}
    local function append(x,y)
     local a=points[#points];local dx,dy=x-a.x,y-a.y;local count=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/4))
     if #points+count>20000 then return false end
     for i=1,count do if tick then tick()end;points[#points+1]={x=a.x+dx*i/count,y=a.y+dy*i/count,map=from.map}end
     return true
    end
    for i=#reverse-1,1,-1 do local x,y=coords(reverse[i]);if not append(from.x+x*step,from.y+y*step)then return nil,'Image route exceeds point budget.'end end
    if not append(to.x,to.y)then return nil,'Image route exceeds point budget.'end
    return {points=points,cost=distance[goal],imageBased=true,terrainVerified=false,source='Cross-zone map-image estimate; native alignment, road/texture weights, elevation unknown'}
   end
   local x,y=coords(key)
   for _,offset in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=x+offset[1],y+offset[2]
    if nx>=minx and nx<=maxx and ny>=miny and ny<=maxy then
     local neighbor=id(nx,ny)
     if not closed[neighbor]and weight(neighbor)>0 then
      local cost=segment(from.x+x*step,from.y+y*step,from.x+nx*step,from.y+ny*step)
      if cost then local total=distance[key]+cost;if not distance[neighbor]or total<distance[neighbor]then distance[neighbor]=total;parent[neighbor]=key;push(neighbor,total+estimate(nx,ny))end end
     end
    end
   end
  end
 end
 return nil,'Image maps are loaded, but no continuous traversable image connection was found between these zones.'
end
