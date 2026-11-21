-- Shared, display-first navigation. World coordinates: UnitPosition yards.
local N={version=1,MAX_NODES=20000,MAX_EDGES=120000,providers={}}
_G.WorldNavigation=N
function N:Finite(v)return not(issecretvalue and issecretvalue(v))and type(v)=='number'and v==v and math.abs(v)<10000000 end
function N:Location(p)return type(p)=='table'and self:Finite(p.x)and self:Finite(p.y)and (p.z==nil or self:Finite(p.z))and self:Finite(p.map)and p.map>=0 end
function N:Point(p)return self:Location(p)and self:Finite(p.z)end
function N:Read(fn,...)
 if type(fn)~='function'then return end
 local ok,a,b,c,d=pcall(fn,...);if not ok then return end
 for _,v in pairs({a,b,c,d})do if issecretvalue and issecretvalue(v)then return end end
 return a,b,c,d
end
function N:Position(unit)
 local x,y,z,map=self:Read(UnitPosition,unit or 'player');local p={x=x,y=y,z=z,map=map}
 if self:Point(p)then return p end
end
function N:Distance(a,b)if not self:Location(a)or not self:Location(b)or a.map~=b.map then return math.huge end;local dz=self:Finite(a.z)and self:Finite(b.z)and a.z-b.z or 0;return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+dz*dz)end
function N:Copy(p)return {x=p.x,y=p.y,z=p.z,map=p.map}end
function N:DB()
 WorldNavigationDB=type(WorldNavigationDB)=='table'and WorldNavigationDB or {}
 local root=WorldNavigationDB;root.realms=type(root.realms)=='table'and root.realms or {}
 local key=(self:Read(GetRealmName)or 'Unknown')..':'..(self:Read(UnitFactionGroup,'player')or 'Unknown')
 if type(root.realms[key])~='table'then root.realms[key]={}end
 local db=root.realms[key]
 if type(db.graph)~='table'then db.graph={nodes={},edges={}}end
 if type(db.hazards)~='table'then db.hazards={}end
 if type(db.blocks)~='table'then db.blocks={}end
 -- Repair stale/malformed local records once per realm table, never during every edge visit.
 if not self.validatedDB or not self.validatedDB[db]then
  self.validatedDB=self.validatedDB or setmetatable({},{__mode='k'})
  local hazards,blocks={},{}
  for k,h in pairs(db.hazards)do
   if type(h)=='table'and self:Location(h)and self:Finite(h.radius)and h.radius>0 and h.radius<=1000 and self:Finite(h.expires)and h.expires>=0 and (h.maxMob==nil or self:Finite(h.maxMob)and h.maxMob>=0)then hazards[k]=h end
  end
  for _,b in ipairs(db.blocks)do if #blocks<200 and type(b)=='table'and self:Location(b)and self:Finite(b.radius)and b.radius>0 and b.radius<=1000 then blocks[#blocks+1]=b end end
  db.hazards,db.blocks=hazards,blocks;self.validatedDB[db]=true
 end
 return root.realms[key]
end
function N:Validate(g,tick)
 if type(g)~='table'or type(g.nodes)~='table'or type(g.edges)~='table'or #g.nodes>self.MAX_NODES or #g.edges>self.MAX_EDGES then return false end
 local count=0
 for i,p in pairs(g.nodes)do if tick then tick()end;count=count+1;if type(i)~='number'or i%1~=0 or i<1 or i>#g.nodes or not self:Point(p)then return false end end
 if count~=#g.nodes then return false end
 count=0
 for i in pairs(g.edges)do count=count+1;if type(i)~='number'or i%1~=0 or i<1 or i>#g.edges then return false end end
 if count~=#g.edges then return false end
 for _,e in ipairs(g.edges)do
  if tick then tick()end
  if type(e)~='table'or type(e.from)~='number'or type(e.to)~='number'or e.from%1~=0 or e.to%1~=0 then return false end
  local a,b=g.nodes[e.from],g.nodes[e.to]
  if not a or not b or a.map~=b.map or e.from==e.to or (e.kind~='road'and e.kind~='ground')or e.verified~=true then return false end
  if e.maxMob~=nil and(not self:Finite(e.maxMob)or e.maxMob<0)then return false end
 end
 return true
end
function N:Nearest(g,p,tolerance,tick)
 local id,d
 for i,v in ipairs(g.nodes)do if tick then tick()end;local distance=self:Distance(p,v);if distance<=tolerance and(not d or distance<d)then id,d=i,distance end end
 return id,d
end
function N:RegisterTerrainPack(g)
 if not self:Validate(g)or type(g.source)~='string'then return false end
 self.terrainPacks=self.terrainPacks or {};self.terrainPacks[#self.terrainPacks+1]=g;return true
end
function N:SegmentDistance(p,a,b)
 if p.map~=a.map or a.map~=b.map then return math.huge end
 local useZ=self:Finite(p.z)and self:Finite(a.z)and self:Finite(b.z)
 local az=useZ and a.z or 0;local bz=useZ and b.z or 0;local pz=useZ and p.z or 0
 local dx,dy,dz=b.x-a.x,b.y-a.y,bz-az;local sq=dx*dx+dy*dy+dz*dz
 local t=sq>0 and math.max(0,math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy+(pz-az)*dz)/sq))or 0
 return self:Distance(p,{x=a.x+t*dx,y=a.y+t*dy,z=useZ and az+t*dz or nil,map=a.map})
end
function N:EdgeCost(g,e,level,now,tick)
 if e.blocked then return nil end
 local a,b=g.nodes[e.from],g.nodes[e.to];local db=self:DB()
 for _,v in ipairs(db.blocks)do if tick then tick()end;if self:SegmentDistance(v,a,b)<=v.radius then return nil end end
 local factor=e.kind=='road'and 1 or 4;local risk=1
 if e.kind=='ground'and self:Finite(level)and self:Finite(e.maxMob)and level>=e.maxMob+5 then factor=1.15 end
 for _,h in pairs(db.hazards)do
  if tick then tick()end
  if h.expires>now and self:SegmentDistance(h,a,b)<h.radius then
   risk=math.max(risk,(self:Finite(level)and h.maxMob and level>=h.maxMob+5 and not h.elite)and 2 or 30)
  end
 end
 return self:Distance(a,b)*factor*risk
end
-- Binary heap + A*. Roads are cheapest; terrain blocks never become shortcuts.
function N:Plan(g,from,to,level,now,tick)
 if not self:Validate(g,tick)or not self:Point(from)or not self:Point(to)or (issecretvalue and issecretvalue(now))or type(now)~='number'or now~=now or now<0 or now>1000000000000 then return nil,'Invalid route data.'end
 local start=self:Nearest(g,from,1.5,tick);local goal=self:Nearest(g,to,1.5,tick)
 if not start or not goal then return nil,'No mapped connection at an endpoint. Record the approach or load terrain data.'end
 local heap={};local function push(id,cost)
  local i=#heap+1;heap[i]={id=id,cost=cost};while i>1 do local p=math.floor(i/2);if heap[p].cost<=heap[i].cost then break end;heap[p],heap[i]=heap[i],heap[p];i=p end
 end
 local function pop()
  local top=heap[1];local last=table.remove(heap);if #heap>0 then heap[1]=last;local i=1;while i*2<=#heap do local j=i*2;if j<#heap and heap[j+1].cost<heap[j].cost then j=j+1 end;if heap[i].cost<=heap[j].cost then break end;heap[i],heap[j]=heap[j],heap[i];i=j end end;return top.id
 end
 local adjacency={};for i,e in ipairs(g.edges)do if tick then tick()end;adjacency[e.from]=adjacency[e.from]or {};adjacency[e.from][#adjacency[e.from]+1]=i end
 local costs,parent,closed={[start]=0},{},{};push(start,0)
 while #heap>0 do
  if tick then tick()end
  local at=pop()
  if at==goal then
   local ids={goal};while at~=start do if tick then tick()end;at=g.edges[parent[at]].from;ids[#ids+1]=at end
   local points={};for i=#ids,1,-1 do if tick then tick()end;points[#points+1]=self:Copy(g.nodes[ids[i]])end
   return {points=points,cost=costs[goal],source='Recorded / imported terrain graph'}
  end
  if not closed[at]then
   closed[at]=true
   for _,index in ipairs(adjacency[at]or {})do
    local e=g.edges[index];local weight=self:EdgeCost(g,e,level,now,tick)
    if weight and(not costs[e.to]or costs[at]+weight<costs[e.to])then costs[e.to]=costs[at]+weight;parent[e.to]=index;push(e.to,costs[e.to]+self:Distance(g.nodes[e.to],g.nodes[goal]))end
   end
  end
 end
 return nil,'No mapped route around terrain barriers or manual no-pass areas.'
end
function N:Hazard(p,level,elite)
 if not self:Point(p)then return false end
 local db=self:DB();local now=self:Read(GetServerTime)or 0
 local key=table.concat({p.map,math.floor(p.x/16),math.floor(p.y/16),math.floor(p.z/8)},':')
 local h=db.hazards[key];if not h or h.expires<=now then h=self:Copy(p)end
 h.unknown=h.unknown or not(self:Finite(level)and level>=1)
 h.radius=28;h.expires=now+1800;h.maxMob=not h.unknown and math.max(h.maxMob or 0,level)or nil;h.elite=h.elite or elite==true;db.hazards[key]=h
 local keys={};for k,v in pairs(db.hazards)do if v.expires<=now then db.hazards[k]=nil else keys[#keys+1]=k end end
 if #keys>500 then table.sort(keys,function(a,b)return db.hazards[a].expires<db.hazards[b].expires end);for i=1,#keys-500 do db.hazards[keys[i]]=nil end end
 return true
end
function N:AddBlock(p)
 if not self:Point(p)then return false end
 local b=self:DB().blocks;if #b>=200 then return false end
 local v=self:Copy(p);v.radius=6;b[#b+1]=v;return true
end
function N:Request(from,to,callback)
 local cancelled,finished=false,false;local pending;local work=0
 local function tick()work=work+1;if work>=256 then work=0;coroutine.yield()end end
 local function finish(route,why)if not cancelled and not finished then finished=true;callback(route,why)end end
 local function fallback(reason)
  local task={}
  task.run=coroutine.create(function()
   local best,why
   -- Generated terrain is primary; recordings are only an optional last fallback.
   for _,g in ipairs(self.terrainPacks or {})do
    local destination=to
    if self:Location(to)and to.z==nil then
     local distance=math.huge
     for _,node in ipairs(g.nodes or {})do
      tick()
      if node.map==to.map then local d=(node.x-to.x)^2+(node.y-to.y)^2
       if d<=2.25 and d<distance then distance=d;destination=node end
      end
     end
    end
    local route,problem=self:Plan(g,from,destination,self:Read(UnitLevel,'player'),self:Read(GetServerTime)or 0,tick)
    if route and(not best or route.cost<best.cost)then best=route;best.source=g.source end
    why=problem or why
   end
   if best then finish(best);return end
   if self.ImagePlan then local image,problem=self:ImagePlan(from,to,tick);if image then finish(image);return end;why=problem or why end
   finish(nil,reason or why or 'No terrain or image-map coverage for these endpoints.')
  end)
  task.failed=function()finish(nil,'Automatic terrain data could not be processed. Check the terrain provider or imported map pack.')end
  self.tasks=self.tasks or {};self.tasks[#self.tasks+1]=task
  return task
 end
 local task
 if self.TerrainRoute then
  pending=self:TerrainRoute(from,to,function(route,reason)
   if cancelled or finished then return end
   if route then finish(route)else task=fallback(reason)end
  end)
 end
 if not pending and not finished and not task then task=fallback()end
 return function()cancelled=true;if task then task.cancelled=true end;if pending then pending()end end
end
function N:Pump()
 local tasks=self.tasks or {};local task=table.remove(tasks,1)
 if task and not task.cancelled then
  local ok=coroutine.resume(task.run)
  if not ok then task.failed()elseif coroutine.status(task.run)~='dead'then tasks[#tasks+1]=task end
 end
end
local frame=CreateFrame('Frame');local elapsed=0
frame:SetScript('OnUpdate',function(_,dt)
 N:Pump()
 elapsed=elapsed+dt;if elapsed<.5 then return end;elapsed=0

 -- Remember only positioned, currently visible hostile NPCs; never infer unseen packs.
 local plates=N:Read(C_NamePlate and C_NamePlate.GetNamePlates)
 for i,p in ipairs(type(plates)=='table'and plates or {})do
  if i>100 then break end;local unit=p.namePlateUnitToken
  if unit and N:Read(UnitIsPlayer,unit)==false and N:Read(UnitCanAttack,'player',unit)==true and N:Read(UnitIsDeadOrGhost,unit)==false then
   N:Hazard(N:Position(unit),N:Read(UnitLevel,unit),N:Read(UnitClassification,unit)~='normal')
  end
 end
end)
