local N=WorldNavigation
-- Optional public engine; no upstream code or terrain assets are copied here.
-- Polestar_NavEngine uses UnitPosition coordinates and terrain-constrained walks.
function N:RouteConflict(points,blocksOnly)
 local db=self:DB();local now=self:Read(GetServerTime)or 0;local level=self:Read(UnitLevel,'player')
 for i=2,#points do
  for _,b in ipairs(db.blocks)do if self:SegmentDistance(b,points[i-1],points[i])<b.radius then return b,'manual no-pass area'end end
  for _,h in pairs(blocksOnly and {}or db.hazards)do
   -- Permit only outward progress when already inside a remembered pack.
   local prior=self:Distance(points[i-1],h)
   local escaping=self:Distance(points[1],h)<h.radius and self:Distance(points[i],h)>prior and self:SegmentDistance(h,points[i-1],points[i])>=prior-.01
   if h.expires>now and(not self:Finite(level)or not h.maxMob or level<h.maxMob+5 or h.elite)and self:SegmentDistance(h,points[i-1],points[i])<h.radius and not escaping then return h,'observed mob pack'end
  end
 end
end
function N:TerrainRoute(from,to,callback)
 if not self:Point(from)or not self:Location(to)or from.map~=to.map then return end
 if self:Read(InCombatLockdown)==true then callback(nil,'Plan terrain routes out of combat.');return function()end end
 local engine=Polestar_NavEngine
 if not engine then
  self:Read(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,'Polestar_Nav');engine=Polestar_NavEngine
 end
 if type(engine)~='table'or type(engine.Find)~='function'or type(engine.Cancel)~='function'or type(engine.Available)~='function'or self:Read(engine.Available,from.map)~=true then return end
 local cancelled,finished=false,false;local jobs={};local attempts=0
 local function finish(result,reason)if not cancelled and not finished then finished=true;callback(result,reason)end end
 if C_Timer and C_Timer.After then C_Timer.After(30,function()
  if not cancelled and not finished then for _,job in ipairs(jobs)do pcall(engine.Cancel,job)end;finish(nil,'Terrain search timed out; try a nearer recorded approach.')end
 end)end
 local function find(a,b,complete)
  local delivered=false
  local function done(...)if delivered or cancelled or finished then return end;delivered=true;complete(...)end
  local ok,job=pcall(engine.Find,a.map,a,b,function(points,cost)
   if cancelled or finished then return end
   if type(points)~='table'or #points<2 or #points>20000 then done(nil,'Terrain route unavailable: '..tostring(cost));return end
   local safe={}
   for _,p in ipairs(points)do if not N:Point(p)or p.map~=from.map then done(nil,'Terrain provider returned invalid coordinates.');return end;safe[#safe+1]=N:Copy(p)end
   local endPoint={x=b.x,y=b.y,z=b.z or safe[#safe].z,map=b.map}
   if N:Distance(safe[1],a)>1.5 or N:Distance(safe[#safe],endPoint)>1.5 then done(nil,'Terrain route did not reach the requested endpoints.');return end
   done(safe)
  end,{waterWalking=false,profile=N:Read(UnitFactionGroup,'player'),style='roads'})
  if ok and job then jobs[#jobs+1]=job else done(nil,'Terrain provider failed.');end
 end
 find(from,to,function(points,reason)
  if not points then finish(nil,reason);return end
  local hazard,kind=N:RouteConflict(points)
  if not hazard then finish({points=points,source='Polestar terrain / road preference'});return end
  -- Ask the terrain engine about four alternatives; never draw a straight detour.
  local offsets={{1,0},{0,1},{-1,0},{0,-1}}
  local function retry()
   attempts=attempts+1
   if attempts>4 then finish(nil,'No terrain route around '..kind..'. Record an alternate approach.');return end
   local v=offsets[attempts];local radius=hazard.radius+20
   local waypoint={map=hazard.map,x=hazard.x+v[1]*radius,y=hazard.y+v[2]*radius,z=hazard.z}
   find(from,waypoint,function(first)
    if not first or N:RouteConflict(first)then retry();return end
    find(waypoint,to,function(second)
     if not second or N:RouteConflict(second)then retry();return end
     for i=2,#second do first[#first+1]=second[i]end
     finish({points=first,source='Terrain route around '..kind})
    end)
   end)
  end
  retry()
 end)
 return function()cancelled=true;for _,job in ipairs(jobs)do pcall(engine.Cancel,job)end end
end
