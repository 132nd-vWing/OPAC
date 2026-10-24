-- OPAC Carrier Ops 1.2.0 | OPAC_0.7.1.139 | 2026-10-24
-- Self-contained. Load once AFTER the mission's Moose.lua.
-- Read README_NO.txt: old launch triggers must be removed; pool flights must be uncontrolled.
-- Flights 1-3: shared finite CAP/QRA pool. Flight 4: mission designer owns tasking.
local CONFIG = {
  key = "XIL_CSG_1", globalName = "OPAC_CARRIER_XIL_CSG_1",
  groupName = "XIL_CSG_1", unitName = "XIL_CSG_1-1", coalition = 1, enemyCoalition = 2,
  aircraft = {
    ["AB_XIL_Carrier1_Flight1"] = "POOL",
    ["AB_XIL_Carrier1_Flight2"] = "POOL",
    ["AB_XIL_Carrier1_Flight3"] = "POOL",
    ["AB_XIL_Carrier1_Flight4"] = "EXTERNAL",
  },
  station = {
    zone = nil, x = nil, z = nil, headingDeg = nil,
    radiusNm = 25, resumeRadiusNm = 8, legNm = 8, cruiseKts = 22,
    maxContinuousWindSec = 45*60,
  },
  cycle = {
    enabled = true, periodSec = 3600, startMinute = 20,
    openSec = 25*60, closeBufferSec = 2*60,
    -- DCS mission clock: turn HH:20; routine window HH:30-HH:55, buffer to HH:57.
  },
  deck = {
    preparationSec = 10*60, windOverDeckKts = 25, minimumHeadwindKts = 20,
    maximumCrosswindKts = 5, maximumShipKts = 28, angleDeg = 0,
    windHeightM = 18, headingToleranceDeg = 5, stableSec = 30,
    radiusM = 400, heightToleranceM = 80, parkedRelativeSpeedMps = 0.8,
    parkedConfirmSec = 30, launchTimeoutSec = 20*60, requestTimeoutSec = 30*60,
    launchSeparationSec = 120, departureClearSec = 90, recoveryClearSec = 120,
    windowLeaseSec = 180,
  },
  cap = {
    enabled = true, startSec = 0, allowOffCycle = true,
    offsetNm = 35, bearingDeg = 290, headingDeg = 290, legNm = 20,
    altitudeFt = 23000, speedKtas = 440,
    retaskSec = 120, relocateNm = 10,
    reliefFuel = 0.50, reliefSortieSec = 60*60, minimumReliefAgeSec = 10*60,
    onStationRadiusNm = 12, minimumOnStationAgeSec = 30, reserveReadyForQRA = 1,
  },
  qra = {
    enabled = true, startSec = 0, zoneName = "XIL_CSG1_QRA_Zone",
    detectionMode = "SENSOR", -- Strict own CSG + own airborne CAP; no zone-only activation.
    maxFlights = 2, hostilesPerFighter = 1, retaskSec = 120,
    altitudeFt = 23000, speedKtas = 500, overrideRecenter = true,
    -- NO alert/countdown delay. Queue immediately; deck readiness/traffic still apply.
  },
  detection = {
    intervalSec = 5, maxContactAgeSec = 10,
    methods = {"RADAR", "VISUAL", "IRST", "OPTIC"},
    -- Only own CSG units and own POOL flights currently flying a CAP sortie.
    -- No QRA-only, external/manual, other-CSG, AWACS, DLINK, RWR or Skynet inputs.
    -- Contacts must be currently detected, not merely remembered by DCS.
  },
  recovery = {
    returnFuel = 0.30, criticalFuel = 0.15, returnLife = 0.80,
    maxSortieSec = 90*60, pursuitLimitNm = 150, requestTimeoutSec = 35*60,
    holdDistanceNm = 20, holdAltitudeFt = 6000, approachDistanceNm = 8,
    finalProtectionNm = 15,
  },
  inventory = {
    minimumLaunchFuel = 0.45, minimumLaunchLife = 0.80,
    turnaroundSec = 30*60, repairExtraSec = 60*60, missingGraceSec = 15, spawnCheckSec = 10,
  },
  external = {
    minimumSortieSec = 10*60, inboundRadiusNm = 70,
    inboundMaxAltitudeFt = 18000, minimumClosurePerTickM = 250,
    -- Flight 4 receives no automatic task/Start/respawn. Use RequestLaunch/Recovery for notice.
  },
  runtime = {
    tickSec = 5, initializationRetrySec = 10, initializationAttempts = 120,
    maxConsecutiveErrors = 3,
  },
}

-- OPAC Carrier Ops 1.2.0. Lua 5.1-compatible mission-side code.
-- CONFIG is intentionally local and unique to this file/carrier.
-- Uses the mission's MOOSE NAVYGROUP. Aircraft use native DCS controllers.
local C = CONFIG
local VERSION = "1.2.0"
if rawget(_G, C.globalName) then
  env.info("[OPAC_CARRIER " .. C.key .. "] DUPLICATE_LOAD ignored")
  return
end
OPAC_CARRIER_OWNERS = OPAC_CARRIER_OWNERS or {}
local O = {Config=C, version=VERSION, flights={}, byUnit={}, contacts={},
  running=true, initialized=false, attempts=0, errors=0, nextSensor=0,
  nextLaunch=0, lastStatus={}, manualUntil=0, retiredIds={}}
_G[C.globalName] = O
local NM, KT, FT = 1852, 0.51444444444444, 0.3048
local function now() return timer.getTime() end
local function log(code, detail)
  env.info("[OPAC_CARRIER " .. VERSION .. " " .. C.key .. "] " .. code .. " " .. tostring(detail or ""))
end
local function warn(code, detail)
  local t=now()
  if not O.lastStatus[code] or t-O.lastStatus[code]>=60 then
    O.lastStatus[code]=t; log(code,detail)
  end
end
local function copy(v)
  if type(v)~="table" then return v end
  local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function call(object, method, ...)
  if not object or type(object[method])~="function" then return nil end
  local ok,a,b,c=pcall(object[method],object,...)
  if ok then return a,b,c end
  return nil
end
local function live(u)
  return u and call(u,"isExist")==true and (call(u,"getLife") or 0)>0
end
local function unit(name) local u=Unit.getByName(name); if live(u) then return u end end
local function group(name)
  local g=Group.getByName(name)
  if g and call(g,"isExist")==true then return g end
end
local function dist(a,b)
  if not a or not b then return math.huge end
  return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
local function atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x>0 then return math.atan(y/x) end
  if x<0 then return math.atan(y/x)+(y>=0 and math.pi or -math.pi) end
  return y>0 and math.pi/2 or (y<0 and -math.pi/2 or 0)
end
local function bearing(a,b) return (math.deg(atan2(b.z-a.z,b.x-a.x))+360)%360 end
local function delta(a,b) return math.abs((a-b+180)%360-180) end
local function shift(p,nm,deg)
  return {x=p.x+nm*NM*math.cos(math.rad(deg)), y=p.y or 0,
    z=p.z+nm*NM*math.sin(math.rad(deg))}
end
local function heading(u)
  local p=call(u,"getPosition")
  return p and (math.deg(atan2(p.x.z,p.x.x))+360)%360 or 0
end
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
local function point(u) return call(u,"getPoint") end
local function onDeck(u)
  local p,s=point(u),point(O.ship)
  return p and s and not call(u,"inAir") and dist(p,s)<C.deck.radiusM
    and math.abs(p.y-s.y)<C.deck.heightToleranceM
end
local function relativeSpeed(u)
  local a,b=call(u,"getVelocity"),call(O.ship,"getVelocity")
  if not a or not b then return math.huge end
  return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function aam(u)
  local ammo=call(u,"getAmmo")
  if type(ammo)~="table" then return nil end
  local n=0
  for _,a in pairs(ammo) do
    local d=a.desc or {}
    if d.category==Weapon.Category.MISSILE and d.missileCategory==Weapon.MissileCategory.AAM then
      n=n+(a.count or 0)
    end
  end
  return n
end
local function setTask(r,task)
  local g=group(r.name); local ctrl=call(g,"getController")
  if not ctrl then return false end
  local ok,err=pcall(ctrl.setTask,ctrl,task)
  if not ok then log("TASK_ERROR",r.name.." "..tostring(err)) end
  return ok
end
local function setOptions(r,engaging)
  local ctrl=call(group(r.name),"getController")
  if r.role~="POOL" or not ctrl then return false end
  local ids,vals=AI.Option.Air.id,AI.Option.Air.val
  local roe=engaging and vals.ROE.OPEN_FIRE or vals.ROE.WEAPON_HOLD
  local ok=pcall(ctrl.setOption,ctrl,ids.ROE,roe)
  if not ok then log("ROE_ERROR",r.name);return false end
  r.roe=engaging and "OPEN_FIRE" or "WEAPON_HOLD"
  if ids.RTB_ON_BINGO then call(ctrl,"setOption",ids.RTB_ON_BINGO,true) end
  return true
end
local function wp(p,alt,speed,tasks)
  return {x=p.x,y=p.z,alt=alt,alt_type="BARO",type="Turning Point",action="Turning Point",
    speed=speed,speed_locked=true,ETA=0,ETA_locked=false,
    task={id="ComboTask",params={tasks=tasks or {}}}}
end
local function leadPoint(r)
  for _,f in ipairs(r.frames) do local u=unit(f.name); if u then return point(u) end end
end
local function mission(points) return {id="Mission",params={route={points=points}}} end

function O:Status()
  local rows={}
  for _,r in ipairs(self.flights) do
    rows[#rows+1]={name=r.name,role=r.role,sortieRole=r.sortieRole,capMode=r.capMode,roe=r.roe,targetGroupId=r.target and r.target.groupId,state=r.state,alive=r.stats and r.stats.alive or 0,
      airborne=r.stats and r.stats.air or 0,readyIn=math.max(0,(r.readyAt or 0)-now())}
    log("FLIGHT_STATUS",r.name.." "..r.state.." alive="..tostring(rows[#rows].alive))
  end
  log("STATUS","running="..tostring(self.running).." deck="..tostring(self.deckReady)..
    " wind="..tostring(self.window~=nil).." stationNm="..string.format("%.1f",dist(point(self.ship),self.station)/NM))
  return {version=VERSION,initialized=self.initialized,running=self.running,
    deckReady=self.deckReady,qraZone=self.qraZone and self.qraZone.name,
    detectionMode=C.qra.detectionMode,flights=rows}
end

local function snapshot(r,t)
  local s={alive=0,air=0,deck=0,parked=0,fuel=math.huge,life=1,empty=false,ammoKnown=true,
    minDistance=math.huge,maxDistance=0,allStationary=true}
  for _,f in ipairs(r.frames) do
    local u=unit(f.name)
    if u and not f.lost then
      f.seen=true; f.lastSeen=t; f.objectId=call(u,"getID")
      local airborne=call(u,"inAir")==true
      local d=dist(point(u),point(O.ship))
      s.alive=s.alive+1; s.minDistance=math.min(s.minDistance,d); s.maxDistance=math.max(s.maxDistance,d)
      s.fuel=math.min(s.fuel,call(u,"getFuel") or 0)
      local life=(call(u,"getLife") or 0)/math.max(call(u,"getLife0") or 1,1)
      s.life=math.min(s.life,life); if life<0.99 then r.damaged=true end
      local n=aam(u); if n==nil then s.ammoKnown=false elseif n==0 then s.empty=true end
      if airborne then
        s.air=s.air+1; f.wasAir=true; f.landed=false; f.shutdown=false; f.parked=false
        f.stationarySince=nil
      elseif onDeck(u) then
        s.deck=s.deck+1
        if relativeSpeed(u)<=C.deck.parkedRelativeSpeedMps then
          f.stationarySince=f.stationarySince or t
          if f.landed and f.shutdown and t-f.stationarySince>=C.deck.parkedConfirmSec then
            f.parked=true
          end
        else f.stationarySince=nil; s.allStationary=false; f.parked=false end
      else s.allStationary=false; f.parked=false end
      if f.parked then s.parked=s.parked+1 end
    elseif f.seen and not f.lost and not f.recovered and not r.spawning and
      r.state~="SERVICE" and t-(f.lastSeen or t)>C.inventory.missingGraceSec then
      -- Disappearance alone is never proof of a successful recovery.
      if f.parked then f.recovered=true
      else f.lost=true; log("LOSS",f.name.." disappeared without verified parking") end
    end
  end
  r.stats=s
  return s
end

local function committed(r,role)
  return r.role=="POOL" and r.sortieRole==role and
    (r.state=="QUEUED" or r.state=="STARTING" or r.state=="SPAWNING" or r.state=="ACTIVE"
      or r.state=="EXTERNAL_STARTING")
end
local function readyPool()
  local pool={}
  for _,r in ipairs(O.flights) do
    if r.role=="POOL" and (r.state=="READY" or r.state=="HANGAR") then
      local s=r.stats
      if r.state=="HANGAR" or (s and s.alive>0 and s.deck==s.alive and
        s.fuel>=C.inventory.minimumLaunchFuel and s.life>=C.inventory.minimumLaunchLife and
        not s.empty and s.ammoKnown) then pool[#pool+1]=r end
    end
  end
  -- Rotate finite aircraft fairly, with deterministic first flight selection.
  table.sort(pool,function(a,b)
    if (a.sorties or 0)==(b.sorties or 0) then return a.name<b.name end
    return (a.sorties or 0)<(b.sorties or 0)
  end)
  return pool
end
local function capacity(r)
  local count=0
  for _,f in ipairs(r.frames) do if not f.lost then count=count+1 end end
  return count*C.qra.hostilesPerFighter
end
local function queue(r,role,t,target,notBefore)
  if not r or (r.state~="READY" and r.state~="HANGAR") then return false end
  r.fromHangar=r.state=="HANGAR"; r.state="QUEUED"; r.sortieRole=role
  r.queuedAt=t; r.notBefore=notBefore or t; r.target=target
  r.launchRequestedAt=nil; r.launchExpires=nil; r.tasked=false; r.relieves=nil; r.onStation=false; r.capMode=nil; r.engagedSignature=nil
  log("QUEUED",r.name.." "..role)
  return true
end
local function closeQueue(r,why)
  r.state=r.fromHangar and "HANGAR" or "READY"; r.target=nil
  r.launchRequestedAt=nil; r.launchExpires=nil; r.sortieRole=nil; r.relieves=nil; r.fromHangar=false
  log("QUEUE_CANCEL",r.name.." "..why)
end

local function capTask(r,t)
  local shipPoint=point(O.ship); local p=leadPoint(r)
  if not p or not shipPoint then return false end
  local center=shift(shipPoint,C.cap.offsetNm,C.cap.bearingDeg)
  local a=shift(center,C.cap.legNm/2,C.cap.headingDeg)
  local b=shift(center,C.cap.legNm/2,C.cap.headingDeg+180)
  local alt,speed=C.cap.altitudeFt*FT,C.cap.speedKtas*KT
  local orbit={id="Orbit",enabled=true,auto=false,number=1,
    params={pattern="Race-Track",point={x=a.x,y=a.z},point2={x=b.x,y=b.z},speed=speed,altitude=alt}}
  if not setOptions(r,false) then return false end
  local ok=setTask(r,mission({wp(p,math.max(p.y,alt),speed),wp(a,alt,speed,{orbit}),wp(b,alt,speed)}))
  if ok then
    r.tasked=true;r.capMode="PATROL";r.target=nil;r.engagedSignature=nil
    r.lastCapTask=t;r.capCenter=center;log("CAP_ASSIGN",r.name.." patrol; sensor-gated engagement")
  end
  return ok
end
local function interceptTask(r,t)
  local target=r.target;local p=leadPoint(r)
  if not target or not p then return false end
  local tasks={}
  for _,contact in ipairs(target.units) do
    if O:IsTargetAuthorized(r.name,contact.name,contact.unitId) then
      local condition=string.format("not %s:IsTargetAuthorized(%q,%q,%d)",
        C.globalName,r.name,contact.name,contact.unitId)
      tasks[#tasks+1]={id="ControlledTask",enabled=true,auto=false,number=#tasks+1,
        params={task={id="EngageUnit",params={unitId=contact.unitId,priority=0}},
          stopCondition={condition=condition}}}
    end
  end
  if #tasks==0 or not setOptions(r,false) then return false end
  local alt,speed=C.qra.altitudeFt*FT,C.qra.speedKtas*KT
  local orbit={id="Orbit",enabled=true,auto=false,number=1,
    params={pattern="Circle",point={x=target.point.x,y=target.point.z},speed=speed,altitude=alt}}
  local ok=setTask(r,mission({wp(p,math.max(p.y,alt),speed,tasks),wp(target.point,alt,speed,{orbit})}))
  if ok then
    -- OPEN_FIRE permits assigned targets; do not enable WEAPON_FREE.
    if not setOptions(r,true) then return false end
    r.tasked=true;r.lastIntercept=t;r.engagedSignature=target.signature
    if r.sortieRole=="CAP" then r.capMode="INTERCEPT";r.onStation=false end
    log(r.sortieRole=="CAP" and "CAP_INTERCEPT" or "INTERCEPT",r.name.." authorizedUnits="..#tasks)
  end
  return ok
end
local function holdTask(r)
  local p=leadPoint(r); if not p then return false end
  local a=shift(point(O.ship),C.recovery.holdDistanceNm,(O.windHeading or heading(O.ship))+180)
  local slot=1
  for _,x in ipairs(O.flights) do
    if x==r then break end
    if x.state=="RETURN_WAIT" or x.state=="RETURNING" then slot=slot+1 end
  end
  local alt=(C.recovery.holdAltitudeFt+(slot-1)*2000)*FT
  local orbit={id="Orbit",enabled=true,auto=false,number=1,
    params={pattern="Circle",point={x=a.x,y=a.z},altitude=alt,speed=300*KT}}
  return setTask(r,mission({wp(p,math.max(p.y,alt),350*KT),wp(a,alt,300*KT,{orbit})}))
end
local function landTask(r)
  local p,s=leadPoint(r),point(O.ship); if not p or not s then return false end
  local a=shift(s,C.recovery.approachDistanceNm,(O.windHeading or heading(O.ship))+180)
  local l=wp(s,0,140*KT)
  l.type="Land"; l.action="Landing"; l.linkUnit=O.ship:getID(); l.helipadId=O.ship:getID()
  return setTask(r,mission({wp(p,math.max(p.y,2000*FT),350*KT),wp(a,2000*FT,250*KT),l}))
end

function O:RequestRecovery(name)
  local r=self.byName and self.byName[name]
  if not r then log("UNKNOWN_FLIGHT",name); return false end
  if r.state=="RETURN_WAIT" or r.state=="RETURNING" then return true end
  local s=r.stats or snapshot(r,now())
  if s.air==0 then return false end
  local t=now(); r.returnAt=t; r.recoveryExpires=t+C.recovery.requestTimeoutSec
  r.wasRecoveryRequested=true; r.recoveryTimedOut=false
  if r.role=="EXTERNAL" then
    r.externalRecovery=true; log("EXTERNAL_RECOVERY",name); return true
  end
  setOptions(r,false);r.target=nil;r.capMode=nil;r.engagedSignature=nil
  r.state="RETURN_WAIT"; r.holdTasked=false
  log("RTB_REQUEST",name)
  return true
end
function O:RTB(name) return self:RequestRecovery(name) end
function O:RegisterFlight(name,willRecoverHere)
  if not self.initialized then return false end
  if self.byName[name] then return true end
  if OPAC_CARRIER_OWNERS[name] and OPAC_CARRIER_OWNERS[name]~=C.key then return false end
  local g=group(name);local us=call(g,"getUnits") or {}
  if #us==0 then return false end
  local r={name=name,role="EXTERNAL",state="READY",frames={},hasHomeLanding=willRecoverHere~=false}
  for _,u in ipairs(us) do
    local d=call(u,"getDesc") or {}
    if call(u,"getCoalition")~=C.coalition or call(u,"getPlayerName") or d.category~=Unit.Category.AIRPLANE then return false end
    r.frames[#r.frames+1]={name=u:getName(),lost=false}
  end
  self.flights[#self.flights+1]=r;self.byName[name]=r;OPAC_CARRIER_OWNERS[name]=C.key
  for _,f in ipairs(r.frames) do self.byUnit[f.name]={record=r,frame=f} end
  local s=snapshot(r,now())
  if s.air>0 then r.state="ACTIVE";r.sortieAt=now() end
  log("REGISTER_EXTERNAL",name);return true
end
function O:RequestLaunch(name)
  local r=self.byName and self.byName[name]
  if not r then log("UNKNOWN_FLIGHT",name); return false end
  if r.state=="QUEUED" or r.state=="STARTING" or r.state=="SPAWNING" then return true end
  if r.role~="EXTERNAL" then
    log("OWNED_FLIGHT",name.." is controlled by CAP/QRA; use EnableCAP/SetQRA")
    return false
  end
  return queue(r,"EXTERNAL",now())
end
local function enableRole(role,enabled)
  local cfg=role=="CAP" and C.cap or C.qra; cfg.enabled=enabled~=false
  if not cfg.enabled then
    for _,r in ipairs(O.flights) do
      if committed(r,role) and r.state=="QUEUED" then closeQueue(r,role.." disabled") end
    end
  end
  return true
end
function O:EnableCAP(enabled) return enableRole("CAP",enabled) end
function O:SetQRA(enabled) return enableRole("QRA",enabled) end
function O:OpenWindow(minutes)
  local n=tonumber(minutes) or 15
  self.manualUntil=math.max(self.manualUntil,now()+math.min(math.max(n,1),60)*60)
end
function O:Start() self.running=true; log("RESUME") end
function O:Stop()
  self.running=false; self.manualUntil=0
  for _,r in ipairs(self.flights) do
    if r.role~="EXTERNAL" then
      if r.state=="QUEUED" then closeQueue(r,"controller paused")
      elseif r.state=="ACTIVE" then self:RequestRecovery(r.name) end
    end
  end
  log("PAUSE","aircraft recovery and external deck requests remain monitored")
end

local function zoneGeometry()
  local z=O.qraZone
  if not z then return nil end
  local p={x=tonumber(z.x),y=0,z=tonumber(z.y)}
  if z.linkUnit then
    -- Linked ME zones store an offset and the link heading at authoring time.
    -- Rotate that offset with the ship; never treat it as a world-map coordinate.
    local s=point(O.ship); local a=math.rad(heading(O.ship))-(tonumber(z.heading) or 0)
    local dx,dz=p.x,p.z
    p={x=s.x+dx*math.cos(a)-dz*math.sin(a),y=s.y,z=s.z+dx*math.sin(a)+dz*math.cos(a)}
  end
  return p,tonumber(z.radius)
end
function O:ZoneGeometry()
  local p,r=zoneGeometry(); return p and {name=C.qra.zoneName,point=p,radius=r} or nil
end
local function inQRAZone(p)
  local center,radius=zoneGeometry()
  return center and p and dist(p,center)<=radius
end
local unpackArgs=unpack or table.unpack
local function validSensor(name)
  local u=unit(name)
  if not u or call(u,"getCoalition")~=C.coalition then return false end
  if call(call(u,"getGroup"),"getName")==C.groupName then return true end
  local x=O.byUnit[name];local r=x and x.record
  return r and r.role=="POOL" and r.sortieRole=="CAP" and call(u,"inAir")==true and
    (r.state=="STARTING" or r.state=="EXTERNAL_STARTING" or r.state=="ACTIVE" or
      r.state=="RETURN_WAIT" or r.state=="RETURNING") or false
end
local function authorizedContact(c,t)
  if not c or t-c.seen>C.detection.maxContactAgeSec or not inQRAZone(c.point) then return false end
  local u=unit(c.name)
  if not u or call(u,"getID")~=c.unitId or call(u,"getCoalition")~=C.enemyCoalition or
    not call(u,"inAir") or not inQRAZone(point(u)) then return false end
  -- Current position is used only as a veto for an already detected contact.
  -- It cannot acquire an unseen contact or extend the life of a lost track.
  for source in pairs(c.sources) do if validSensor(source) then return true end end
  return false
end
function O:IsTargetAuthorized(flightName,targetName,targetId)
  if not self.initialized or not self.running or not live(self.ship) then return false end
  local r=self.byName and self.byName[flightName]
  if not r or r.role~="POOL" or r.state~="ACTIVE" or
    (r.sortieRole~="CAP" and r.sortieRole~="QRA") then return false end
  local c=self.contacts[targetName]
  return c~=nil and c.unitId==targetId and authorizedContact(c,now())
end
local function recordContact(u,t,source,contacts)
  if not live(u) or call(u,"getCoalition")~=C.enemyCoalition or not call(u,"inAir") then return end
  local desc=call(u,"getDesc") or {};local p=point(u)
  if (desc.category~=Unit.Category.AIRPLANE and desc.category~=Unit.Category.HELICOPTER) or
    not p or not inQRAZone(p) then return end
  local g=call(u,"getGroup");local name=call(u,"getName");local id=call(u,"getID")
  if not g or not name or not id then return end
  local c=contacts[name]
  if not c then
    c={name=name,unitId=id,groupId=call(g,"getID"),point=copy(p),seen=t,sources={}}
    contacts[name]=c
  end
  c.sources[source]=true
end
local function observeContacts(t)
  if t<O.nextSensor then return end
  O.nextSensor=t+C.detection.intervalSec
  local sensors={};local seen={};local contacts={}
  local function add(u)
    local name=call(u,"getName")
    if name and not seen[name] and validSensor(name) then
      seen[name]=true;sensors[#sensors+1]=u
    end
  end
  for _,u in pairs(call(group(C.groupName),"getUnits") or {}) do add(u) end
  for _,r in ipairs(O.flights) do
    if r.role=="POOL" and r.sortieRole=="CAP" then
      for _,f in ipairs(r.frames) do local u=unit(f.name);if u then add(u) end end
    end
  end
  for _,sensor in ipairs(sensors) do
    local detected=call(call(sensor,"getController"),"getDetectedTargets",unpackArgs(O.detectionMethods)) or {}
    for _,d in pairs(detected) do
      -- DCS also reports remembered contacts: only a current detection can authorize combat.
      if d.visible==true then recordContact(d.object,t,sensor:getName(),contacts) end
    end
  end
  for name,c in pairs(contacts) do
    if not O.contacts[name] then
      local sources={};for source in pairs(c.sources) do sources[#sources+1]=source end;table.sort(sources)
      log("CONTACT_ACQUIRED",name.." sensors="..table.concat(sources,","))
    end
  end
  for name in pairs(O.contacts) do
    if not contacts[name] then log("CONTACT_LOST",name.." no current organic detection inside own QRA zone") end
  end
  O.contacts=contacts
end
local function threatGroups()
  local result,byId={},{}
  for _,c in pairs(O.contacts) do
    if authorizedContact(c,now()) then
      local g=byId[c.groupId];local distance=dist(c.point,point(O.ship))
      if not g then
        g={name=c.name,groupId=c.groupId,point=copy(c.point),count=0,distance=distance,units={}}
        byId[c.groupId]=g;result[#result+1]=g
      end
      g.units[#g.units+1]=c;g.count=g.count+1
      if distance<g.distance then g.distance=distance;g.point=copy(c.point);g.name=c.name end
    end
  end
  for _,g in ipairs(result) do
    table.sort(g.units,function(a,b)return a.unitId<b.unitId end)
    local ids={};for _,c in ipairs(g.units) do ids[#ids+1]=tostring(c.unitId) end
    g.signature=table.concat(ids,",")
  end
  table.sort(result,function(a,b)
    if a.distance==b.distance then return a.groupId<b.groupId end
    return a.distance<b.distance
  end)
  return result,byId
end

local function requests(t)
  if not O.running then return end
  -- Keep one CAP commitment. A returning flight is no longer CAP cover.
  local caps,pending={},false
  for _,r in ipairs(O.flights) do
    if committed(r,"CAP") then
      caps[#caps+1]=r
      if r.state~="ACTIVE" then pending=true end
      if r.state=="ACTIVE" and r.onStation and r.relieves then
        local old=O.byName[r.relieves]
        if old and old.state=="ACTIVE" and old.sortieRole=="CAP" then
          log("CAP_HANDOVER",old.name.." -> "..r.name);O:RequestRecovery(old.name)
        end
        r.relieves=nil
      end
    end
  end
  local relief
  for _,r in ipairs(caps) do
    if r.state=="ACTIVE" and t-(r.sortieAt or t)>=C.cap.minimumReliefAgeSec and
      (r.stats.fuel<=C.cap.reliefFuel or t-(r.sortieAt or t)>=C.cap.reliefSortieSec) then
      relief=relief or r
    end
  end
  if C.cap.enabled and t>=C.cap.startSec and (#caps==0 or (relief and #caps==1 and not pending)) then
    local ready=readyPool()
    if #ready>0 and (#caps==0 or #ready>C.cap.reserveReadyForQRA) then
      queue(ready[1],"CAP",t)
      ready[1].relieves=relief and relief.name or nil
      if relief then log("CAP_RELIEF",relief.name.." replacement="..ready[1].name) end
    elseif #caps==0 then warn("CAP_UNAVAILABLE","no ready finite-inventory flight") end
  end

  local targets,byId=threatGroups()
  for _,r in ipairs(O.flights) do
    if committed(r,"CAP") and r.state=="ACTIVE" and r.stats.air==r.stats.alive then
      local target=(r.target and byId[r.target.groupId]) or targets[1]
      if target then
        local changed=r.engagedSignature~=target.signature
        r.target=target
        if r.capMode~="INTERCEPT" or changed or t-(r.lastIntercept or 0)>=C.qra.retaskSec then
          interceptTask(r,t)
        end
      elseif r.capMode=="INTERCEPT" or r.target then
        setOptions(r,false);r.target=nil;r.engagedSignature=nil;r.tasked=false
        log("CAP_DISENGAGE",r.name.." no fresh authorized contact inside own QRA zone")
        if not capTask(r,t) then r.capMode="RETURN_TO_CAP" end
      end
    end
  end
  local assigned={}; local qras={}
  for _,r in ipairs(O.flights) do if committed(r,"QRA") then qras[#qras+1]=r end end
  table.sort(qras,function(a,b)
    local function rank(r) return r.state=="ACTIVE" and 0 or r.state=="QUEUED" and 2 or 1 end
    if rank(a)==rank(b) then return a.name<b.name end;return rank(a)<rank(b)
  end)
  local function selectTarget(previous)
    local keep=previous and byId[previous.groupId]
    if keep and (assigned[keep.groupId] or 0)<keep.count then return keep end
    for _,target in ipairs(targets) do
      if (assigned[target.groupId] or 0)<target.count then return target end
    end
  end
  local function assign(r,target)
    local changed=r.engagedSignature~=target.signature
    r.target=target;assigned[target.groupId]=(assigned[target.groupId] or 0)+capacity(r)
    if changed then r.tasked=false;log("QRA_TARGET",r.name.." group="..target.groupId) end
    if r.state=="ACTIVE" and (not r.tasked or t-(r.lastIntercept or 0)>=C.qra.retaskSec) then
      interceptTask(r,t)
    end
  end
  local count=0
  for _,r in ipairs(qras) do
    local target=selectTarget(r.target)
    if target then assign(r,target);count=count+1
    elseif r.state=="QUEUED" then closeQueue(r,"no uncovered threat in QRA zone")
    elseif r.state=="ACTIVE" then r.target=nil;O:RequestRecovery(r.name)
    else r.target=nil;count=count+1 end -- already taxiing: do not erase a live departure
  end
  if C.qra.enabled and t>=C.qra.startSec then
    while count<C.qra.maxFlights do
      local target=selectTarget(nil); if not target then break end
      local ready=readyPool(); local r=ready[1]
      if not r then
        -- Unstarted relief yields to raids. With only one usable flight, the first
        -- urgent QRA also takes precedence over an unstarted initial CAP.
        for _,candidate in ipairs(O.flights) do
          local old=candidate.relieves and O.byName[candidate.relieves]
          if committed(candidate,"CAP") and candidate.state=="QUEUED" and
            ((old and old.state=="ACTIVE" and old.sortieRole=="CAP") or count==0) then
            closeQueue(candidate,"urgent QRA preempts CAP relief/initial queue")
            r=readyPool()[1];break
          end
        end
      end
      if not r then warn("QRA_UNAVAILABLE","threat in zone; no ready pool flight");break end
      queue(r,"QRA",t,target,t); r.windNotBefore=t
      assign(r,target);count=count+1
      log("QRA_ALERT",r.name.." immediate; sensor-confirmed target="..target.groupId.."; zone="..C.qra.zoneName)
    end
  end
end

local function retire(r,t)
  local survivors={}; local s=r.stats
  if s.air>0 then return false end
  for _,f in ipairs(r.frames) do
    if not f.lost then
      local u=unit(f.name)
      if u then
        if not f.parked or not onDeck(u) or relativeSpeed(u)>C.deck.parkedRelativeSpeedMps then return false end
      elseif not f.recovered then return false end
      survivors[#survivors+1]=f
    end
  end
  if #survivors==0 then r.state="LOST"; return false end
  -- Confirmed parked survivors move into a simulated hangar during service.
  for _,f in ipairs(survivors) do
    if f.objectId then O.retiredIds[f.objectId]=true end
    f.recovered=true
  end
  local g=group(r.name)
  if g then
    local ok=pcall(g.destroy,g)
    if not ok then r.state="QUARANTINE"; log("RETIRE_FAILED",r.name); return false end
  end
  r.state="SERVICE"; r.readyAt=t+C.inventory.turnaroundSec+(r.damaged and C.inventory.repairExtraSec or 0)
  r.externalRecovery=false; r.launchExpires=nil; r.recoveryExpires=nil
  log("RECOVERED",r.name.." survivors="..#survivors.." serviceSeconds="..(r.readyAt-t))
  return true
end
local function freeParking(count)
  local b=Airbase.getByName(C.unitName); local slots={}; local used={}
  if not b then return nil end
  for _,p in pairs(call(b,"getParking",true) or {}) do
    if p.Term_Index and p.Term_Type~=16 and p.TO_AC~=true and not used[p.Term_Index] then
      slots[#slots+1]=p.Term_Index; used[p.Term_Index]=true
    end
  end
  table.sort(slots)
  if #slots>=count then return slots end
end
local function respawn(r,t)
  if group(r.name) then warn("SPAWN_WAIT",r.name.." old group still exists"); return false end
  local count=0; for _,f in ipairs(r.frames) do if not f.lost and f.recovered then count=count+1 end end
  local parking=freeParking(count)
  if not parking then warn("SPAWN_WAIT",r.name.." no reported free deck parking"); return false end
  local template=copy(r.template); local p=point(O.ship); local units={}
  local byName={}; for _,u in ipairs(template.units) do byName[u.name]=u end
  for _,f in ipairs(r.frames) do
    if not f.lost and f.recovered then
      local u=byName[f.name]; u.unitId=nil; u.x=p.x; u.y=p.z; u.alt=p.y
      u.heading=math.rad(heading(O.ship)); u.psi=-u.heading; u.speed=0
      u.parking=parking[#units+1]; u.parking_id=nil; units[#units+1]=u
      f.seen=false; f.parked=false; f.shutdown=false; f.landed=false; f.wasAir=false
      f.recovered=false; f.lastSeen=nil; f.stationarySince=nil; f.objectId=nil
    end
  end
  if #units==0 then r.state="LOST"; return false end
  template.units=units; template.groupId=nil; template.lateActivation=false
  template.uncontrolled=true; template.start_time=0; template.x=p.x; template.y=p.z
  local outbound=shift(p,12,O.windHeading or heading(O.ship))
  local hold={id="Orbit",enabled=true,auto=false,number=1,
    params={pattern="Circle",point={x=outbound.x,y=outbound.z},altitude=10000*FT,speed=350*KT}}
  -- A takeoff-only route can leave DCS with no reason to taxi/depart.
  -- This climb-out holds the first airborne member until the whole flight is up.
  template.tasks={}; template.route={points={wp(p,0,0),wp(outbound,10000*FT,350*KT,{hold})}}
  local first=template.route.points[1]
  first.type="TakeOffParking"; first.action="From Parking Area"
  first.linkUnit=O.ship:getID(); first.helipadId=O.ship:getID()
  r.spawning=true; r.spawnExpected=#units
  local ok,g=pcall(coalition.addGroup,r.country,Group.Category.AIRPLANE,template)
  if not ok or not g then
    r.spawning=false; r.state="QUARANTINE"; log("SPAWN_FAILED",r.name.." no automatic retry"); return false
  end
  r.state="SPAWNING"; r.spawnedAt=t; r.damaged=false
  log("DECK_RESPAWN",r.name.." survivors="..#units)
  return true
end
local function departureTask(r)
  local p=point(O.ship); local out=shift(p,12,O.windHeading or heading(O.ship))
  local first=copy(r.template.route.points[1])
  first.x=p.x; first.y=p.z; first.linkUnit=O.ship:getID(); first.helipadId=O.ship:getID()
  first.task={id="ComboTask",params={tasks={}}}
  local orbit={id="Orbit",enabled=true,auto=false,number=1,
    params={pattern="Circle",point={x=out.x,y=out.z},altitude=10000*FT,speed=350*KT}}
  return mission({first,wp(out,10000*FT,350*KT,{orbit})})
end
local function startFlight(r,t)
  local g=group(r.name); local ctrl=call(g,"getController")
  if not ctrl then return false end
  if r.role=="POOL" and (not setOptions(r,false) or not setTask(r,departureTask(r))) then return false end
  local ok,err=pcall(ctrl.setCommand,ctrl,{id="Start",params={}})
  if not ok then log("START_FAILED",r.name.." "..tostring(err)); return false end
  r.state="STARTING"; r.startedAt=t; r.sortieAt=t; r.tasked=false; r.onStation=false
  r.sorties=(r.sorties or 0)+1
  r.launchExpires=t+C.deck.launchTimeoutSec; r.wasRecoveryRequested=false
  r.lateLogged=false; r.recoveryTimedOut=false; r.externalRecovery=false
  log("START",r.name.." "..tostring(r.sortieRole))
  return true
end

local function updateFlights(t)
  for _,r in ipairs(O.flights) do
    local s=snapshot(r,t)
    if r.state=="SERVICE" and t>=r.readyAt then
      r.state="HANGAR"; log("READY_AGAIN",r.name)
    elseif r.state=="MISSING" then
      -- Missing templates are reported at init; never silently manufacture aircraft.
    elseif r.state=="READY" and s.alive==0 then
      r.state="LOST"; log("NO_AIRFRAMES",r.name)
    elseif r.state=="SPAWNING" and t-r.spawnedAt>=C.inventory.spawnCheckSec then
      r.spawning=false
      if s.alive==r.spawnExpected and s.deck==s.alive and s.air==0 then
        r.state="QUEUED"; r.fromHangar=false
      else r.state="QUARANTINE"; log("SPAWN_INVALID",r.name.." no retry/no teleport") end
    elseif r.state=="QUEUED" then
      if r.state=="QUEUED" and r.launchExpires and t>=r.launchExpires then
        r.state="QUARANTINE"; log("LAUNCH_REQUEST_TIMEOUT",r.name)
      end
    elseif r.state=="STARTING" or r.state=="EXTERNAL_STARTING" then
      if s.alive>0 and s.air==s.alive then
        r.state="ACTIVE"; r.airborneAt=t; r.sortieAt=r.sortieAt or t
        r.clearUntil=t+C.deck.departureClearSec; r.launchExpires=nil
        log("AIRBORNE",r.name)
        if not O.running and r.role~="EXTERNAL" then O:RequestRecovery(r.name) end
      elseif r.launchExpires and t>=r.launchExpires then
        r.state="QUARANTINE"; r.launchExpires=nil
        log("LAUNCH_BLOCKED",r.name.." no deletion; check deck/ATC")
      end
    elseif r.state=="ACTIVE" and r.role~="EXTERNAL" then
      if s.air==0 and s.alive>0 then retire(r,t)
      elseif s.air>0 then
        if s.fuel<=C.recovery.returnFuel or s.empty or s.life<C.recovery.returnLife or
          t-(r.sortieAt or t)>=C.recovery.maxSortieSec or s.maxDistance>C.recovery.pursuitLimitNm*NM then
          O:RequestRecovery(r.name)
        elseif r.sortieRole=="CAP" then
          local c=shift(point(O.ship),C.cap.offsetNm,C.cap.bearingDeg)
          if r.capMode~="INTERCEPT" then
            if not r.tasked then capTask(r,t)
            elseif t-(r.lastCapTask or 0)>=C.cap.retaskSec and dist(c,r.capCenter)>C.cap.relocateNm*NM then
              capTask(r,t)
            end
          end
          r.onStation=r.capMode=="PATROL" and r.capCenter~=nil and
            dist(leadPoint(r),r.capCenter)<=C.cap.onStationRadiusNm*NM and
            t-(r.airborneAt or t)>=C.cap.minimumOnStationAgeSec
        end
      end
    elseif r.state=="RETURN_WAIT" or r.state=="RETURNING" then
      if s.air==0 then retire(r,t) end
      if r.recoveryExpires and t>=r.recoveryExpires and not r.recoveryTimedOut then
        r.recoveryTimedOut=true; log("RECOVERY_TIMEOUT",r.name.." inspect ATC; no respawn")
      end
    end
    if r.role=="EXTERNAL" and s.air>0 then
      r.sortieAt=r.sortieAt or t
      local p=leadPoint(r); local last=r.lastExternalPoint
      local closing=last and dist(last,point(O.ship))-dist(p,point(O.ship)) or 0
      -- DCS exposes no reliable inbound-intent API. Explicit RequestRecovery is authoritative.
      if r.hasHomeLanding and not r.externalRecovery and not r.recoveryTimedOut and
        t-r.sortieAt>C.external.minimumSortieSec and closing>C.external.minimumClosurePerTickM and
        s.minDistance<C.external.inboundRadiusNm*NM and p.y<C.external.inboundMaxAltitudeFt*FT then
        O:RequestRecovery(r.name)
      end
      r.lastExternalPoint=copy(p)
    end
    if r.externalRecovery and ((s.air==0 and s.deck==s.alive) or t>=(r.recoveryExpires or 0)) then
      r.externalRecovery=false; r.clearUntil=t+C.deck.recoveryClearSec
      if s.air>0 then r.recoveryTimedOut=true; log("EXTERNAL_RECOVERY_TIMEOUT",r.name) end
    end
    if s.alive==0 and r.state~="SERVICE" and r.state~="HANGAR" and r.state~="SPAWNING" and
      r.state~="MISSING" and r.state~="QUARANTINE" and not (r.state=="QUEUED" and r.fromHangar) then
      local retained=false
      for _,f in ipairs(r.frames) do if not f.lost and (f.recovered or f.parked) then retained=true end end
      if retained and r.role~="EXTERNAL" then retire(r,t)
      elseif not retained and r.state~="LOST" then r.state="LOST"; log("FLIGHT_LOST",r.name) end
    end
  end
end

local function phase(t)
  local abs=timer.getAbsTime()
  local start=math.floor(abs/C.cycle.periodSec)*C.cycle.periodSec+C.cycle.startMinute*60
  if start>abs then start=start-C.cycle.periodSec end
  local age=abs-start
  return C.cycle.enabled and O.running and age>=0 and age<C.deck.preparationSec+C.cycle.openSec+C.cycle.closeBufferSec,
    age, start
end
local function launchBusy()
  for _,r in ipairs(O.flights) do
    if r.state=="STARTING" or r.state=="EXTERNAL_STARTING" or r.state=="SPAWNING" then return true end
  end
  return false
end
local function finalBusy()
  for _,r in ipairs(O.flights) do
    if (r.state=="RETURNING" or r.externalRecovery) and r.stats and r.stats.air>0 and
      r.stats.minDistance<C.recovery.finalProtectionNm*NM then return true end
    if (r.clearUntil or 0)>now() then return true end
  end
  return false
end
local function requestWind(t)
  local scheduled,age=phase(t); local needed=scheduled or t<O.manualUntil
  for _,r in ipairs(O.flights) do
    if r.state=="QUEUED" then
      local eligible=(r.sortieRole~="CAP" or scheduled or C.cap.allowOffCycle)
      if eligible and t>=(r.windNotBefore or 0) then
        r.launchRequestedAt=r.launchRequestedAt or t
        r.launchExpires=r.launchExpires or t+C.deck.requestTimeoutSec
        needed=true
      end
    elseif r.state=="STARTING" or r.state=="EXTERNAL_STARTING" or r.state=="SPAWNING" then needed=true
    elseif (r.state=="RETURN_WAIT" or r.state=="RETURNING" or r.externalRecovery) and
      not r.recoveryTimedOut then needed=true end
    if (r.clearUntil or 0)>t then needed=true end
  end
  local stationDistance=dist(point(O.ship),O.station)/NM
  local protected=launchBusy() or finalBusy()
  local urgent=false
  if C.qra.overrideRecenter then
    for _,r in ipairs(O.flights) do
      if committed(r,"QRA") and r.state=="QUEUED" then urgent=true end
    end
  end
  -- A timeout must never turn the ship underneath a real final approach.
  if protected then needed=true end
  if O.window and O.window.Over then O.window=nil; O.readySince=nil end
  if O.window and (t-O.windowStarted>=C.station.maxContinuousWindSec or
    stationDistance>C.station.radiusNm) and not protected and not urgent then
    needed=false; O.recenter=true
    log("RECENTER","new launches wait until ship returns to station")
  end
  if O.recenter then
    if stationDistance<=C.station.resumeRadiusNm then O.recenter=false
    elseif not protected and not urgent then needed=false end
  end
  if needed and not O.window then
    O.window=O.navy:AddTurnIntoWind(nil,C.deck.windowLeaseSec,C.deck.windOverDeckKts,true,C.deck.angleDeg)
    if not O.window or not O.window.Id then error("NAVYGROUP rejected turn-into-wind window") end
    O.windowStarted=t; O.readySince=nil
    log("TURN_IN",scheduled and "scheduled cycle" or "off-cycle traffic")
  elseif needed and O.window then
    local remain=O.window.Tstop-timer.getAbsTime()
    if remain<C.deck.windowLeaseSec/2 then O.navy:ExtendTurnIntoWind(C.deck.windowLeaseSec,O.window) end
  elseif not needed and O.window then
    O.navy:RemoveTurnIntoWind(O.window); O.window=nil; O.readySince=nil
    log("TURN_OUT","U-turn to departure point, then station patrol")
  end
  O.deckReady=false
  if O.window and O.window.Open and O.window.Heading then
    O.windHeading=O.window.Heading
    local v=call(O.ship,"getVelocity") or {x=0,z=0}
    local p=point(O.ship); p={x=p.x,y=p.y+C.deck.windHeightM,z=p.z}
    local wind=atmosphere.getWind(p)
    local h=math.rad(heading(O.ship)+C.deck.angleDeg)
    local rel={x=v.x-wind.x,z=v.z-wind.z}
    local head=(rel.x*math.cos(h)+rel.z*math.sin(h))/KT
    local cross=math.abs(-rel.x*math.sin(h)+rel.z*math.cos(h))/KT
    local aligned=delta(heading(O.ship),O.windHeading)<=C.deck.headingToleranceDeg and
      head>=C.deck.minimumHeadwindKts and cross<=C.deck.maximumCrosswindKts and not O.navy:IsTurning()
    if aligned then O.readySince=O.readySince or t else O.readySince=nil end
    O.deckReady=O.readySince~=nil and t-O.readySince>=C.deck.stableSec
    if not O.deckReady then warn("DECK_WAIT",string.format("headwind %.1f crosswind %.1f kt",head,cross)) end
  end
  O.scheduled=scheduled; O.cycleAge=age
end

local function dispatch(t)
  local recoveryBusy=false; local waiting={}
  for _,r in ipairs(O.flights) do
    if (r.state=="RETURNING" or r.externalRecovery) and r.stats.air>0 then recoveryBusy=true end
    if r.state=="RETURN_WAIT" and r.stats.air>0 then waiting[#waiting+1]=r end
  end
  table.sort(waiting,function(a,b) return a.stats.fuel<b.stats.fuel end)
  for i,r in ipairs(waiting) do
    if not r.holdTasked then r.holdTasked=holdTask(r) end
    local emergency=r.stats.fuel<=C.recovery.criticalFuel
    if i==1 and not launchBusy() and (O.deckReady or emergency) and (not recoveryBusy or emergency) then
      if landTask(r) then
        r.state="RETURNING"; recoveryBusy=true; log("RECOVERY_RELEASE",r.name..(emergency and " critical fuel" or ""))
      end
    end
  end
  if not O.deckReady or launchBusy() or recoveryBusy or #waiting>0 or finalBusy() or t<O.nextLaunch then return end
  local selected
  for _,r in ipairs(O.flights) do
    if r.state=="QUEUED" and r.launchRequestedAt and t>=r.notBefore then
      if r.sortieRole~="CAP" or (O.scheduled and O.cycleAge>=C.deck.preparationSec) or C.cap.allowOffCycle then
        if not selected or (r.sortieRole=="QRA" and selected.sortieRole~="QRA") or
          (r.sortieRole==selected.sortieRole and r.queuedAt<selected.queuedAt) then selected=r end
      end
    end
  end
  if selected then
    if selected.fromHangar then
      respawn(selected,t) -- SPAWNING owns the deck slot; separation starts at engine start.
    elseif selected.stats.alive>0 and selected.stats.deck==selected.stats.alive then
      if startFlight(selected,t) then O.nextLaunch=t+C.deck.launchSeparationSec end
    end
  end
end

local function indexMission()
  local templates={}; local shipId
  for side,co in pairs(env.mission.coalition or {}) do
    if type(co)=="table" then
      for _,country in pairs(co.country or {}) do
        for _,g in pairs((country.ship or {}).group or {}) do
          if g.name==C.groupName then
            O.shipTemplate=g
            for _,u in pairs(g.units or {}) do if u.name==C.unitName then shipId=u.unitId end end
          end
        end
        for _,g in pairs((country.plane or {}).group or {}) do templates[g.name]={template=g,country=country.id,side=side} end
      end
    end
  end
  if not shipId then error("Configured carrier unit/group not found in env.mission") end
  O.shipMissionId=shipId
  for _,z in pairs((env.mission.triggers or {}).zones or {}) do
    if z.name==C.qra.zoneName then O.qraZone=copy(z) end
  end
  if not O.qraZone or tonumber(O.qraZone.type)~=0 or not tonumber(O.qraZone.radius) or
    tonumber(O.qraZone.radius)<=0 then error("Missing/invalid circular QRA zone "..C.qra.zoneName) end
  if O.qraZone.linkUnit and tonumber(O.qraZone.linkUnit)~=shipId then
    error("QRA zone linked to another unit: "..C.qra.zoneName)
  end
  if C.qra.detectionMode~="SENSOR" then error("1.2 requires SENSOR mode; the zone is only a geographic limit") end
  if not AI or not AI.Option or not AI.Option.Air or not AI.Option.Air.id or
    not AI.Option.Air.val or not AI.Option.Air.val.ROE or
    AI.Option.Air.id.ROE==nil or AI.Option.Air.val.ROE.WEAPON_HOLD==nil or
    AI.Option.Air.val.ROE.OPEN_FIRE==nil then error("DCS air ROE options unavailable") end
  if not Controller or not Controller.Detection then error("DCS detection API unavailable") end
  O.detectionMethods={}
  local organic={RADAR=true,VISUAL=true,IRST=true,OPTIC=true}
  for _,method in ipairs(C.detection.methods) do
    if not organic[method] then error("Only organic detection methods are allowed") end
    if Controller.Detection[method]~=nil then
      O.detectionMethods[#O.detectionMethods+1]=Controller.Detection[method]
    end
  end
  if #O.detectionMethods==0 then error("No supported organic detection methods") end
  local selected={}; for name,role in pairs(C.aircraft) do selected[name]=role end
  for name,x in pairs(templates) do
    for _,p in pairs((x.template.route or {}).points or {}) do
      if p.linkUnit==shipId or p.helipadId==shipId then selected[name]=selected[name] or "EXTERNAL" end
    end
  end
  O.byName={}
  local names={};for name in pairs(selected) do names[#names+1]=name end; table.sort(names)
  for _,name in ipairs(names) do
    local x=templates[name]; local role=selected[name]
    if not x then log("MISSING_TEMPLATE",name.."; carrier still operates, this role is unavailable")
    else
      local valid=x.side=="red"; local linked=false; local human=false; local home=false
      local first=x.template.route and x.template.route.points[1]
      if first then linked=first.linkUnit==shipId or first.helipadId==shipId end
      for _,p in pairs((x.template.route or {}).points or {}) do
        if p.type=="Land" and (p.linkUnit==shipId or p.helipadId==shipId) then home=true end
      end
      for _,u in ipairs(x.template.units or {}) do if u.skill=="Client" or u.skill=="Player" then human=true end end
      if OPAC_CARRIER_OWNERS[name] and OPAC_CARRIER_OWNERS[name]~=C.key then valid=false end
      if not linked or human then valid=false end
      if role=="POOL" and (not x.template.uncontrolled or x.template.lateActivation) then
        log("POOL_CONFIGURATION_ERROR",name.." must be uncontrolled and not late activated; traffic monitoring only")
        role="EXTERNAL"
      end
      if not valid then log("INVALID_TEMPLATE",name.." requires own carrier, RED AI, uncontrolled, not late activated")
      else
        local r={name=name,role=role,state="READY",country=x.country,template=copy(x.template),
          frames={},hasHomeLanding=home,damaged=false}
        for _,u in ipairs(x.template.units) do
          local f={name=u.name,lost=false};r.frames[#r.frames+1]=f;O.byUnit[u.name]={record=r,frame=f}
        end
        O.flights[#O.flights+1]=r;O.byName[name]=r;OPAC_CARRIER_OWNERS[name]=C.key
        log("REGISTER",name.." "..role)
      end
    end
  end
end

local function eventHandler(e)
  if not e.initiator then return end
  local id=call(e.initiator,"getID")
  if id and O.retiredIds[id] then return end
  local x=O.byUnit[call(e.initiator,"getName") or ""]
  if not x and e.id==world.event.S_EVENT_BIRTH and O.initialized and onDeck(e.initiator) then
    local g=call(e.initiator,"getGroup")
    if g then O:RegisterFlight(g:getName(),true); x=O.byUnit[call(e.initiator,"getName") or ""] end
  end
  if not x then return end
  local r,f=x.record,x.frame; local ev=world.event; local t=now()
  if e.id==ev.S_EVENT_DEAD or e.id==ev.S_EVENT_CRASH or e.id==ev.S_EVENT_PILOT_DEAD
    or (ev.S_EVENT_UNIT_LOST and e.id==ev.S_EVENT_UNIT_LOST) then
    f.lost=true;f.parked=false;f.recovered=false;log("LOSS",f.name)
  elseif e.id==ev.S_EVENT_ENGINE_STARTUP then
    f.shutdown=false
    if onDeck(e.initiator) and r.state~="STARTING" and r.state~="SPAWNING" then
      r.state="EXTERNAL_STARTING";r.startedAt=t;r.sortieAt=t;r.sortieRole=r.sortieRole or (r.role=="POOL" and "CAP" or "EXTERNAL")
      r.launchExpires=t+C.deck.launchTimeoutSec;r.tasked=false
      log("UNANNOUNCED_START",r.name.." request wind immediately")
    end
  elseif e.id==ev.S_EVENT_TAKEOFF then
    f.wasAir=true;f.landed=false;f.shutdown=false;f.parked=false
    if r.state=="READY" or r.state=="QUEUED" or r.state=="QUARANTINE" then
      r.state="EXTERNAL_STARTING";r.sortieAt=t;r.sortieRole=r.sortieRole or (r.role=="POOL" and "CAP" or "EXTERNAL")
      r.launchExpires=t+C.deck.launchTimeoutSec;log("UNANNOUNCED_TAKEOFF",r.name)
    end
  elseif e.id==ev.S_EVENT_LAND then
    local place=call(e.place,"getName")
    if place==C.unitName or onDeck(e.initiator) then
      f.landed=true;f.stationarySince=nil
      r.clearUntil=t+C.deck.recoveryClearSec
      log("LANDED",f.name.." waiting for parking/shutdown")
    end
  elseif e.id==ev.S_EVENT_ENGINE_SHUTDOWN then
    if f.landed and onDeck(e.initiator) then f.shutdown=true;log("ENGINE_STOP",f.name) end
  end
end

function O:Init()
  if not NAVYGROUP or not COORDINATE or not _DATABASE then return false,"MOOSE not ready" end
  self.ship=unit(C.unitName)
  if not self.ship then return false,"carrier absent/late activation" end
  if self.ship:getCoalition()~=C.coalition then error("Carrier coalition mismatch") end
  local existing=_DATABASE:GetOpsGroup(C.groupName)
  if existing then error("Another OPS controller already owns "..C.groupName) end
  indexMission()
  local p=point(self.ship)
  self.station={x=C.station.x or p.x,y=p.y,z=C.station.z or p.z}
  if C.station.zone then
    local z=trigger.misc.getZone(C.station.zone)
    if not z then error("Missing station zone "..C.station.zone) end
    self.station=copy(z.point);C.station.radiusNm=z.radius/NM
  end
  local hd=C.station.headingDeg or heading(self.ship)
  local a,b=shift(self.station,C.station.legNm/2,hd),shift(self.station,C.station.legNm/2,hd+180)
  for _,dest in ipairs({a,b,self.station}) do
    for i=0,20 do
      local q={x=p.x+(dest.x-p.x)*i/20,y=p.z+(dest.z-p.z)*i/20}
      local surface=land.getSurfaceType(q)
      if surface~=land.SurfaceType.WATER and surface~=land.SurfaceType.SHALLOW_WATER then
        error("Station patrol crosses land; configure a tested sea zone/track")
      end
    end
  end
  self.navy=NAVYGROUP:New(C.groupName)
  for _,method in ipairs({"ClearWaypoints","AddWaypoint","AddTurnIntoWind","ExtendTurnIntoWind",
    "RemoveTurnIntoWind","GetHeadingIntoWind","SetPatrolAdInfinitum","IsTurning"}) do
    if type(self.navy[method])~="function" then error("MOOSE missing "..method) end
  end
  self.navy:SetDefaultSpeed(C.station.cruiseKts):SetPatrolAdInfinitum(true)
  -- Keep original initial waypoint/UID; replace the long transit legs in runtime only.
  self.navy:ClearWaypoints(2)
  self.navy:AddWaypoint(COORDINATE:NewFromVec3(a),C.station.cruiseKts,nil,0,false)
  self.navy:AddWaypoint(COORDINATE:NewFromVec3(b),C.station.cruiseKts,nil,0,true)
  self.navy:SetPathfindingOn()
  -- Guard MOOSE's zero-wind/zero-angle divisions, on THIS instance only.
  local nativeHeading=self.navy.GetHeadingIntoWind
  self.navy.GetHeadingIntoWind=function(n,angle,wod)
    local windFrom,speed=n:GetWind(C.deck.windHeightM)
    local maxSpeed=math.min(C.deck.maximumShipKts,(n.speedMax or C.deck.maximumShipKts*1.852)/1.852)
    if speed<0.1 or math.abs(angle or 0)<0.001 then
      return (speed<0.1 and heading(O.ship) or windFrom)%360,
        math.min(maxSpeed,math.max(4,wod-speed/KT))
    end
    local h,v=nativeHeading(n,angle,wod)
    if not finite(h) or not finite(v) then h=windFrom-(angle or 0);v=wod-speed/KT end
    return h%360,math.min(maxSpeed,math.max(4,v))
  end
  self.handler={onEvent=function(_,e)
    local ok,err=pcall(eventHandler,e);if not ok then warn("EVENT_ERROR",err) end
  end}
  world.addEventHandler(self.handler)
  for _,r in ipairs(self.flights) do
    local s=snapshot(r,now())
    for _,f in ipairs(r.frames) do
      if not f.seen then f.lost=true;log("INITIAL_LOSS",f.name) end
    end
    if s.alive==0 then r.state="LOST";log("INITIAL_MISSING",r.name)
    elseif s.air>0 then
      r.state="ACTIVE";r.sortieRole=r.sortieRole or (r.role=="POOL" and "CAP" or "EXTERNAL");r.sortieAt=now()
    elseif r.role=="EXTERNAL" and r.template and not r.template.uncontrolled and
      not r.template.lateActivation and s.deck>0 then
      r.state="EXTERNAL_STARTING";r.sortieRole="EXTERNAL";r.startedAt=now();r.sortieAt=now()
      r.launchExpires=now()+C.deck.launchTimeoutSec
      log("UNCONTROLLED_OFF",r.name.." may start autonomously; reserving departure course")
    end
  end
  for _,tr in pairs(env.mission.trigrules or {}) do
    for _,action in pairs(tr.actions or {}) do
      local id=action.ai_task and action.ai_task[1]
      for _,r in ipairs(self.flights) do
        if id and r.template and id==r.template.groupId and C.aircraft[r.name]=="POOL" then
          log("LEGACY_TRIGGER_CONFLICT",tostring(tr.comment).." -> "..r.name)
        end
      end
    end
  end
  for _,r in ipairs(self.flights) do if r.role=="POOL" then setOptions(r,false) end end
  self.initialized=true
  log("READY","mission clock cycles; station patrol; finite inventory; no server changes")
  return true
end

function O:Tick(t)
  if not self.initialized then
    self.attempts=self.attempts+1
    local ok,why=self:Init()
    if not ok then
      if self.attempts>=C.runtime.initializationAttempts then log("INIT_FAILED",why);return nil end
      warn("INIT_WAIT",why);return t+C.runtime.initializationRetrySec
    end
  end
  self.ship=unit(C.unitName)
  if not self.ship then
    log("CARRIER_LOST","controller stopped; no new launches; DCS handles airborne survivors")
    if self.handler then world.removeEventHandler(self.handler) end
    self.running=false;return nil
  end
  observeContacts(t)
  updateFlights(t)
  requests(t)
  requestWind(t)
  dispatch(t)
  return t+C.runtime.tickSec
end
timer.scheduleFunction(function(_,t)
  local ok,nextTime=pcall(O.Tick,O,t)
  if ok then O.errors=0;return nextTime end
  O.errors=O.errors+1;log("TICK_ERROR",nextTime)
  if O.errors>=C.runtime.maxConsecutiveErrors then
    O.running=false
    for _,r in ipairs(O.flights) do if r.role=="POOL" then setOptions(r,false) end end
    log("HALTED","repeated runtime errors; own aircraft weapons hold; inspect dcs.log")
    if O.handler then world.removeEventHandler(O.handler) end
    return nil
  end
  return t+C.runtime.initializationRetrySec
end,nil,now()+1)
log("LOADED",C.groupName.." / "..C.unitName)
