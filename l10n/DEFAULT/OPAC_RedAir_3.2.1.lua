--[[
OPAC RED AIR 3 v1.2.1 | 132nd Virtual Wing | 2026-10-04
Mission-side Lua 5.1. MOOSE OPS + existing Skynet DetectionSetGroup.
API checks: MOOSE 2.9.18 / master-ng 802d532a (2026-10-02), plus the supplied
mission's Moose.lua build 73d3ed119 (2026-06-14).
Offline validation: Lua 5.1 behavioural tests, including selected actual MOOSE
mission/refuel/parking/spawn and FSM/OPSGROUP Stop functions, .miz inventories,
and the embedded Skynet connector. DCS/MP flight testing remains required.

I .MIZ
  1. Load current Moose.lua, then Skynet core and ALL IADS setup scripts.
  2. Disable old Red Air / Red Air 2 triggers. Never run two controllers.
  3. ONCE / TIME MORE 10 / DO SCRIPT FILE: this file. Default operations
     begin at mission elapsed 120 s; inventory monitoring starts immediately.
  4. RED land-based AI groups: AA_<number>_<description> for air-to-air,
     AG_<number>_<description> for multirole; 1..4 aircraft per group.
     Takeoff from ramp, UNCONTROLLED ON, LATE ACTIVATION OFF, armed with AAM.
     Group prefix must match CONFIG.squadrons[number].prefix. Both AA and AG
     can fly CAP/QRA; the prefix does not assign a role or change the loadout.
     No other script/trigger may start, respawn or task these groups.
     Skill, livery, fuel, pylons, radio and group composition come from ME.
  5. Trigger zones EXACTLY AA_CAP1, AA_CAP2, AA_CAP3, AA_CAP4, AA_CAP5.
     No spaces. CAP.zonePool is an unordered pool of possible patrol zones.
     Zones with no eligible assigned squadron, or invalid geometry, are skipped.
     Configured racetrack: 20 NM, centred on zone; allow additional turning
     room. Endpoints must be inside the trigger zone AND ColdBorder.
     The zone is the patrol area, not the interception boundary.
  6. Keep existing ColdBorder route polygon group; do not activate it.
     Old Cap_Severomorsk-* groups/zones are never used by this script.
  7. Operative tankers: RED AT_<number>_<description>, ME Refueling task
     (Tanker en-route task), airborne, compatible, with sufficient fuel.
     Red Air does NOT start, replace or task tankers. Late activation OK
     for tankers. Native DCS Refueling has no tanker-ID parameter: all
     operative RED tankers should use AT_. A nearer compatible non-AT
     tanker prevents a new refuelling attempt rather than being selected.
  8. Back up the mission, reimport this file into the existing DO SCRIPT FILE
     action, resave the .miz and restart it. An already running mission will
     not hot-reload this file. To roll back, reimport the previous Lua copy.

PA SERVEREN
  No hooks, files, io/lfs/os, desanitization, SRS or persistence required.
  Run the same mission on the dedicated server. State resets per mission.

PUBLIC DO SCRIPT CALLS (after file is loaded)
  OPAC_RED_AIR_3:Status()          -- readiness, readyInSec and opsAttached in dcs.log
  OPAC_RED_AIR_3:Inventory()       -- all AA/AG squadrons found in this .miz
  OPAC_RED_AIR_3:SetCAPCount(0)    -- exact count 0..5; equivalent to range 0..0
  OPAC_RED_AIR_3:SetCAPRange(1,3)  -- new draw: 1..3 zones; deselected flights RTB
  OPAC_RED_AIR_3:Stop()            -- no launches; airborne flights land
  OPAC_RED_AIR_3:Start()           -- resume, without replenishing losses
  OPAC_RED_AIR_3:RegisterTanker("AT_831_example") -- dynamically added tanker
  OPAC_RED_AIR_3:TaxiStatus()     -- per-aircraft progress/recovery log
  OPAC_RED_AIR_3:ParkingReport("Severomorsk-3") -- DCS terminal IDs in dcs.log
  OPAC_RED_AIR_3:RecoverTaxi("AA_612_SU27_Sevoromorsk3_1")
     -- manual recovery; bypasses elapsed-time/attempt limit, NOT ground,
     -- stationary, live-airframe, friendly-base or clear-parking safeguards.
     -- Optional second argument true also overrides runway/hold-zone protection.
     -- Use only a trusted mission-control DO SCRIPT action; no public F10 menu.

REUSABLE FLIGHT FIX (v1.2.1)
  MOOSE's normal OPSGROUP:Stop() refuses a live group. Earlier Red Air versions
  ignored this veto, so the old OPS owner could remain registered after respawn
  and block the next sortie even when the record reached READY.
  Red Air now retires ONLY its own OPS instance with a temporary, instance-local
  Stop guard. Old flight callbacks are fenced during cleanup. Both the Stopped
  state and removal from MOOSE's OPS database are verified BEFORE replacing
  aircraft. Failed retirement leaves the physical group intact and logs why.
  No global MOOSE methods are changed; Skynet's groups are not stopped.
  Taxi recovery after a sortie still requires 30 minutes of turnaround by
  default, plus 60 minutes if damaged. Ramp respawn is not a new launch order.
  READY means turnaround is complete. Aircraft condition, CAP demand, random
  selection and the base departure queue determine which group launches next.
  Acceptance: complete two sorties with the same group after normal parking
  and after one taxi recovery. Expect OPS_RELEASED, PARKED/TAXI_RECOVERED,
  READY_AGAIN, then START when selected. :Status() reports readyInSec and
  opsAttached; a waiting READY group should have opsAttached=false.

RANDOM CAP PLAN (v1.2.0)
  CAP.count={min=2,max=2}: inclusive integer range, 0..5. Equal values give a
  fixed count with random zones; min=1,max=3 gives a random count from 1 to 3.
  CAP.zonePool: possible AA_CAP1..5 trigger zones; list order is NOT priority.
  CAP.squadrons[id]: zones that squadron is allowed to patrol. The squadron
  must also be enabled in the master list and have an eligible physical group.
  At operationsStartSec (first running tick), after QRA reservations, draw
  the count once. Then choose uniformly among feasible sets of that size.
  A feasible set needs a DIFFERENT eligible ME group for every selected zone.
  Temporary departure queues do not exclude zones; launches can be staggered.
  If resources cannot meet the draw, select the largest feasible count below
  it and log CAP_SHORTFALL. No dead aircraft or disabled squadrons are restored.
  The count and selected zones persist for this mission, including rotations,
  losses, AAR and Stop/Start. A gap later does not silently move CAP elsewhere.
  No available group at selection means that zone is excluded for this plan.
  Explicit SetCAPRange(min,max) / SetCAPCount(n) makes a new draw after the first
  plan; before then, these calls only update the pending range. Removed flights
  RTB; retained flights keep their missions. New zones wait for usable groups.
  Each sortie still chooses a random eligible squadron, then a random group,
  while preserving the best possible coverage of other selected empty zones.
  Shared CAP/QRA squadrons remain shared; QRA reservations take priority.
  Status() reports range, requested count, selected zones and pending state.
  Do not combine the old numeric CAP.count / CAP.zoneOrder with this config.

TAXI RECOVERY (retained from v1.1.0)
  CONFIG.taxiRecovery contains the taxi monitoring and recovery options.
  A 15-second monitor tracks EACH aircraft's progress after a five-minute startup
  grace. Ground aircraft must have moved from parking or landed this sortie.
  Five minutes without progress logs a warning; ten minutes permits recovery.
  ALL surviving members must be grounded and stationary. Partial departures
  are logged but NEVER cause an airborne aircraft to be removed.
  Runway buffer and optional holdZones suppress automatic recovery and reset
  the progress timer. DCS provides no dependable ATC queue-state API: use hold
  zones for queues extending beyond the runway buffer. Missing runway geometry
  disables automatic relocation at that base, without stopping Red Air.
  Recovery first checks and reserves clear, compatible parking, then stops the
  old OPS instance and replaces only its survivors under the same names.
  Original ME loadout/fuel are serviced on the ramp; damage adds the configured
  repair time. A return from a sortie also keeps the normal turnaround time.
  Previous launch parking is avoided by default; no safe alternative = no deletion.
  Parking geometry is checked, but a free stand does NOT prove its taxi route:
  optionally restrict each base to tested terminal IDs. Terminal IDs can differ
  from Mission Editor labels. Existing AIRBASE parking black/whitelists apply too.
  One automatic recovery per group per mission; manual recovery remains available.
  A manual recovery also consumes the automatic allowance, avoiding another reset.
  Failed/misplaced respawns are logged and never retried automatically.
  A per-base departure queue admits one OWN taxiing flight, with QRA priority
  near its startup time. External AI/player traffic remains DCS controlled.
  QRA deadlines never reset while queued; a blocked runway can still make QRA late.
  MOOSE's generic stuck cancellation is disabled ONLY on Red Air's own OPS
  instances, so it cannot cancel a mission behind this controller's back.

BEHAVIOUR / LIMITS
  One original ME group = one reusable flight; no splitting/merging/filling.
  Missing/dead airframes are permanently removed, including pre-start losses.
  AAM-empty or insufficiently fuelled parked groups stay visible but unavailable.
  Survivors taxi to actual parking, then respawn there as uncontrolled AI with
  original ME loadout/fuel. Names, markings and surviving membership persist.
  A brief visual replacement is possible; damage repair is modelled by time,
  not preserved physical damage. Further losses during turnaround still count.
  A landing is NOT a recovery until parking/engine shutdown is confirmed.
  Replacements spawn only at verified parking, never on the runway or in the air.
  Stuck-flight relocation is bounded; dead airframes are never revived.
  An aircraft DCS removes before parking confirmation is unavailable, not restored.
  Diverted survivors remain visible at that base but are not reused this mission.
  Failed startups that never leave parking are logged/quarantined; taxi recovery
  handles confirmed ground movement, and mission control may request a recovery.

  QRA 15/5 minutes = target from first valid alert to ALL surviving aircraft
  airborne. Startup is ordered deadline minus estimated startup/taxi time.
  DCS controls engines, taxi and runway clearance: exact airborne time cannot
  be guaranteed. QRA_LATE logs missed deadlines, without teleporting aircraft.
  CAP refuelling holds its own CAP slot. No replacement CAP while it refuels.
  Five-minute readiness lasts through rejoin, until CAP returns to that zone.
  Existing alerts may be expedited; their deadline is never pushed backwards.

  Tanking limit is 0(off),1,2,3 successful group cycles PER SORTIE.
  All surviving receivers must reach refuelCompletePercent; an event alone
  is not success. An aborted attempt RTBs; no endless retry loop.
  QRA tanking is optional per squadron, default OFF; low-fuel QRA otherwise RTB.
  Skynet's original set is read-only; private INTEL also uses own airborne
  fighters. Only detected BLUE airborne contacts inside ColdBorder can trigger
  intercepts. Destruction of ADCC is NOT a separate global QRA shutdown switch.

DEDICATED SERVER ACCEPTANCE (offline checks do not replace these)
  Fresh load + duplicate load; 0/1/5 CAP zones; 1/2/3/4 aircraft groups;
  ground kill before operations; partial loss + two successive sorties;
  ground kill during turnaround; normal/fuel/AAM RTB and actual taxi/parking;
  1/2/3 refuels, failed/empty/destroyed tanker, CAP rejoin, no replacement CAP;
  QRA 900/300 s deadlines, pending-alert expedition, no available QRA;
  lost contact / ColdBorder exit; lost base/diversion; Stop/Start; MP late join;
  missing dependency/zone; mission restart (inventory resets from .miz).
  Taxi: normal startup/hold/slow movement; leader or wingman stuck; partial
  departure; no free parking; captured base; damaged/killed survivor; alternate
  parking; one-recovery limit; respawn failure; Stop/Start during turnaround;
  simultaneous CAP/QRA departures; manual recovery and old callback isolation.
  CAP draw: min=max, min=0, missing/disabled/unarmed squadrons, missing zones,
  shared group across several zones, insufficient groups, delayed operations,
  ground losses before selection, refuel without redraw, Stop/Start without
  redraw, explicit range change, and duplicate load without changing the plan.
  Expected logs: READY, CAP_ASSIGN, QRA_ALERT, START, AIRBORNE, REFUEL_BEGIN,
  REFUEL_OK, QRA_READINESS, RTB, PARKED, READY_AGAIN, LOSS, STATUS,
  TAXI_STUCK, TAXI_RECOVER, TAXI_RECOVERED, TAXI_RECOVERY_WAIT, DEPARTURE_WAIT.
  CAP selection logs: CAP_PLAN, CAP_ZONE_SKIPPED, CAP_SHORTFALL, CAP_STATUS.
  OPS cleanup logs: OPS_RELEASED, OPS_STOP_FAILED, PARKING_WAIT.

NAMING PLAN (mission author's updated squadron list)
  AA: 601, 602, 603, 611, 612, 613, 621, 622.
  AG: 701, 702, 711, 712, 721, 722. Old AA_7xx groups must be renamed AG_7xx.
  611/613 are newly listed; aircraft type and home base are read from ME.
  CAP/QRA lists below use the numeric ID; prefix is set once in squadrons.
  New IDs are available in the master list but role choices remain explicit.
  Actual prefixes, group composition and AAM eligibility are checked at runtime.

LATEST INPUT: OPAC_0.6.2.132(6).miz
  This mission still embedded v1.1.0. Its updated squadron assignments and all
  other configuration values are retained, with the requested v1.2 CAP schema:
  count={min=2,max=2}, zonePool=AA_CAP1..5. Two feasible zones are drawn once.
  CAP: 601 -> AA_CAP1/2; 603 -> AA_CAP3/4; 612 -> AA_CAP1/2/3/4/5.
  QRA: 621/622. Squadron 613 remains disabled in the master list.
  Actual losses, loadouts, base ownership and QRA reservations can reduce capacity.
  :Inventory() reports the actual current AA/AG catalogue from env.mission.
]]

local CONFIG = {
  autoStart = true,
  operationsStartSec = 120, -- mission elapsed seconds, NOT delay after load
  borderGroup = "ColdBorder", -- ME GROUP NAME (polygon route)
  skynetSensorSet = "DetectionSetGroup", -- existing NOTIA SET_GROUP global
  fighterSensors = true,

  -- Only these enabled IDs may be used. Comment out an entire line to disable
  -- that squadron for BOTH roles. Other settings inherit defaults.
  -- Prefix must match the ME GROUP name; missing/mismatched groups are skipped.
  squadrons = {
    [601] = { prefix = "AA" }, -- MiG-29A, Severomorsk-3
    [602] = { prefix = "AA" }, -- MiG-29A, Monchegorsk
    [603] = { prefix = "AA" }, -- MiG-29A, Afrikada
    [611] = { prefix = "AA" }, -- Su-27, Murmansk (no AAR capability)
    [612] = { prefix = "AA" }, -- Su-27, Severomorsk-3 (no AAR capability)
 --   [613] = { prefix = "AA" }, -- Su-27, Olenya(no AAR capability)  (NO MORE AC LEFT, ALL KILLED)
    [621] = { prefix = "AA" }, -- MiG-31, Olenya; DCS capability checked before any AAR
    [622] = { prefix = "AA" }, -- MiG-31, Severomorsk-3
    [701] = { prefix = "AG", maxCAPRefuels = 1 }, -- Su-30, Monchegorsk
    [702] = { prefix = "AG", maxCAPRefuels = 1 }, -- Su-30, Monchegorsk
    [711] = { prefix = "AG" }, -- MiG-29S, Severomorsk-3; review AAM loadout
    [712] = { prefix = "AG" }, -- MiG-29S, Kilpyavr; review AAM loadout

    -- Add new land-based AA/AG IDs here AND in the wanted role list below.
  },
  squadronDefaults = {
    prefix = "AA", -- override explicitly to AG for multirole squadrons
    turnaroundMinutes = 30,
    repairExtraMinutes = 60, -- added when any surviving aircraft was damaged
    allowReducedGroups = true,
    maxCAPRefuels = 0, -- 0,1,2,3 per group sortie; physical capability required
    maxQRARefuels = 0, -- optional 0,1,2,3; default QRA returns for ground refuel
    startupTaxiSec = 240, -- estimate; override per squadron to match actual base
    qraRadiusKm = 250, -- detected target distance from THIS group's home base
    minLaunchFuelPercent = 45,
  },

  CAP = {
    count = { min = 2, max = 2 }, -- inclusive 0..5; e.g. min=1,max=3
    zonePool = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
    -- Random feasible zones are selected ONCE when operations begin.
    -- Pool order gives no priority. One group per zone; no group counted twice.
    -- The lists below are independent of QRA. Random squadron, then random
    -- eligible group, on EACH new sortie. No availability = visible gap/log.
    squadrons = {
      [601] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      [602] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      [603] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      [611] = {"AA_CAP1"},
	  [612] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      -- [613] = {"AA_CAP2"},
      -- [621] = {"AA_CAP4"},
      -- [622] = {"AA_CAP5"},
	  -- [701] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      -- [702] = {"AA_CAP1", "AA_CAP2", "AA_CAP3", "AA_CAP4", "AA_CAP5"},
      -- [711] = {"AA_CAP4"},
      -- [712] = {"AA_CAP5"},
      -- [721] = {"AA_CAP3"},
      -- [722] = {"AA_CAP4"},
    },
    defaults = {altitudeFt = 25000, speedKtas = 440, headingDeg = 270, legNm = 20},
    zones = {
      AA_CAP1 = {}, AA_CAP2 = {}, AA_CAP3 = {}, AA_CAP4 = {}, AA_CAP5 = {},
      -- Example override: AA_CAP2 = {altitudeFt=28000, headingDeg=90, legNm=8}
    },
    engageRangeKm = 120, -- detected target distance from airborne CAP
    pursuitLimitKm = 185, -- CAP flight distance from assigned zone centre
    replacementDelaySec = 60, -- after previous flight recovered/lost
  },

  QRA = {
    maxFlights = 2, -- includes alerted, starting, refuelling AND returning groups
    squadrons = {
      621,
      622,
      -- 601,
      -- 602,
      -- 603,
      -- 611,
      -- 612,
      -- 613,
      -- 701,
      -- 702,
      -- 711,
      -- 712,
      -- 721,
      -- 722,
    },
    normalAirborneSec = 15 * 60,
    refuellingAirborneSec = 5 * 60,
    altitudeFt = 25000,
    speedKtas = 540,
    pursuitLimitKm = 300, -- from own home base
    retrySec = 60,
  },

  recovery = {
    lowFuelPercent = 20, -- return if AAR is disabled/unavailable or limit reached
    criticalFuelPercent = 10, -- also aborts AAR; checked every controller tick
    returnOnAnyEmptyAAM = true, -- any surviving member empty -> WHOLE flight RTB
    returnBelowLifePercent = 80,
    maxSortieMinutes = 240, -- includes tanker transit/queue; permits 1..3 tankings
    launchTimeoutSec = 20 * 60, -- quarantine blocked flight, no deletion/respawn
    parkingTimeoutSec = 30 * 60, -- log taxi problems; never restore on the runway
    respawnGraceSec = 10,
    alternateBases = {}, -- exact AIRBASE names; RED land bases only; no reuse there
  },
  refuelling = {
    requestFuelPercent = 25, -- seek tanker BEFORE normal return threshold
    completeFuelPercent = 90, -- ALL surviving receivers must reach this
    maxDistanceNm = 100,
    maxDurationSec = 25 * 60, -- transit + queue + refuel; then RTB
    tankerMinFuelPercent = 20,
    maxFlightsPerTanker = 1, -- own reservations; external traffic remains DCS-owned
  },
  taxiRecovery = {
    enabled = true,
    checkIntervalSec = 15,
    startupGraceSec = 5 * 60,
    warnAfterSec = 5 * 60, -- time without >= progressMeters displacement
    recoverAfterSec = 10 * 60,
    progressMeters = 20,
    stationarySpeedMps = 0.5,
    stationaryConfirmSec = 30, -- ALL survivors must remain stationary this long
    cooldownSec = 5 * 60,
    maxAutomaticRecoveries = 1, -- per original group, per mission (not per sortie)
    retryCheckSec = 60, -- bounded parking scans when recovery is currently blocked
    runwayBufferMeters = 200, -- extra clearance outside runway edge/end
    baseRadiusMeters = 8000, -- no recovery of off-airfield/emergency landings
    parkingScanRadiusMeters = 150,
    maxParkingCandidates = 40,
    maxParkingSpreadMeters = 500,
    avoidPreviousParking = true,
    holdZones = {}, -- optional exact trigger-zone names; suppress auto recovery
    parkingWhitelist = {}, -- empty = any clear compatible stand
    parkingBlacklist = {},
    bases = {
      ["Severomorsk-3"] = {
        parkingWhitelist = {}, -- use :ParkingReport(); select tested routes
        parkingBlacklist = {},
        holdZones = {},
      },
    },
  },
  departures = {
    enabled = true,
    maxTaxiFlightsPerBase = 1,
    minIntervalSec = 120,
    qraPriorityWindowSec = 120, -- reserve ramp capacity shortly before QRA start
  },
  contactMemorySec = 90,
  intelIntervalSec = 15,
  tickSec = 5,
  dependencyRetrySec = 10,
  dependencyAttempts = 12,
  debug = false,
}

if rawget(_G, "OPAC_RED_AIR_3") then
  env.info("[OPAC_RA3] DUPLICATE_LOAD ignored; use :Start() to resume.")
  return
end
local R = {version="1.2.1", Config=CONFIG, running=false, initialized=false,
  records={}, flights={}, slots={}, catalogue={}, tankerGroups={}, sensorNames={},
  epoch=0, attempts=0, errors=0, serial=0, nextQra=0, notices={},
  taxiParking={}, baseLastLaunch={}, taxiAvailable=false, capZones={}, capPlan=nil}
OPAC_RED_AIR_3 = R
local function log(s, bad)
  local msg="[OPAC_RA3 "..R.version.."] "..tostring(s)
  if bad then env.error(msg) else env.info(msg) end
end
local function now() return timer.getTime() end
local function nkeys(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function integer(n) return type(n)=="number" and n==math.floor(n) and n<math.huge end
local function number(n,lo,hi) return type(n)=="number" and n==n and n>=lo and n<=hi end
-- Configuration layers contain scalar values; keep validation independent of
-- MOOSE so a file loaded too early can use the bounded dependency retry path.
local function merge(a,b)
  local t={}; for k,v in pairs(a) do t[k]=v end
  for k,v in pairs(b or {}) do t[k]=v end; return t
end
local function contains(a,x) for _,v in ipairs(a or {}) do if v==x then return true end end; return false end
local function dist(a,b) return a:Get2DDistance(b) end
local function alive(g) return g and g:IsAlive()==true end
local function physical(name)
  local u=Unit.getByName(name)
  if u and u:isExist() and u:getLife()>1 then return u end
end
local function speed(u)
  local v=u:getVelocity(); return math.sqrt(v.x*v.x+v.y*v.y+v.z*v.z)
end
local function lifePercent(u)
  local initial=u:getLife0(); return initial and initial>0 and u:getLife()/initial*100 or 100
end
local function aamCount(u)
  local n=0
  for _,a in pairs(u:getAmmo() or {}) do
    if a.desc and a.desc.category==Weapon.Category.MISSILE
      and a.desc.missileCategory==Weapon.MissileCategory.AAM then n=n+(a.count or 0) end
  end
  return n
end
local function hasTask(t,id)
  if type(t)~="table" then return false end
  if t.id==id and t.enabled~=false then return true end
  for _,v in pairs(t) do if type(v)=="table" and hasTask(v,id) then return true end end
  return false
end
function R:_notice(key,msg)
  if not self.notices[key] or now()-self.notices[key]>=120 then
    self.notices[key]=now(); log(msg)
  end
end

function R:_validate()
  local c=self.Config
  local range=c.CAP.count
  assert(type(range)=="table" and integer(range.min) and integer(range.max)
    and number(range.min,0,5) and number(range.max,range.min,5),"CAP.count must be {min=0..5,max=min..5}")
  assert(c.CAP.zoneOrder==nil,"Replace CAP.zoneOrder with CAP.zonePool in v1.2.0")
  assert(type(c.CAP.zonePool)=="table" and #c.CAP.zonePool<=5,"CAP.zonePool must contain up to five zone names")
  local seen={}
  for _,z in ipairs(c.CAP.zonePool) do
    assert(type(z)=="string" and z:match("^AA_CAP[1-5]$") and not seen[z],"Invalid/duplicate CAP zone: "..tostring(z))
    assert(type(c.CAP.zones[z])=="table","Missing CAP.zones entry: "..z); seen[z]=true
  end
  assert(type(c.borderGroup)=="string" and type(c.skynetSensorSet)=="string","Invalid ME names")
  assert(number(c.operationsStartSec,0,604800),"Invalid operationsStartSec")
  for _,key in ipairs({"tickSec","intelIntervalSec","contactMemorySec","dependencyRetrySec","dependencyAttempts"}) do
    assert(number(c[key],1,3600),"Invalid "..key)
  end
  assert(integer(c.dependencyAttempts),"dependencyAttempts must be integer")
  assert(c.contactMemorySec>=c.intelIntervalSec,"Contact memory shorter than Intel interval")
  assert(integer(c.QRA.maxFlights) and number(c.QRA.maxFlights,0,20),"QRA.maxFlights must be 0..20")
  for _,key in ipairs({"normalAirborneSec","refuellingAirborneSec","altitudeFt","speedKtas","pursuitLimitKm","retrySec"}) do
    assert(number(c.QRA[key],1,60000),"Invalid QRA."..key)
  end
  assert(c.QRA.refuellingAirborneSec<=c.QRA.normalAirborneSec,"QRA refuelling deadline must not be longer")
  for _,key in ipairs({"engageRangeKm","pursuitLimitKm"}) do assert(number(c.CAP[key],1,2000),"Invalid CAP."..key) end
  assert(number(c.CAP.replacementDelaySec,0,86400),"Invalid replacement delay")
  for _,key in ipairs({"lowFuelPercent","criticalFuelPercent","returnBelowLifePercent"}) do
    assert(number(c.recovery[key],1,100),"Invalid recovery."..key)
  end
  assert(c.recovery.criticalFuelPercent<c.recovery.lowFuelPercent,"Critical fuel must be below low fuel")
  assert(number(c.refuelling.requestFuelPercent,c.recovery.lowFuelPercent,95),"AAR request fuel invalid")
  assert(number(c.refuelling.completeFuelPercent,c.refuelling.requestFuelPercent+1,100),"AAR completion fuel invalid")
  for _,key in ipairs({"maxSortieMinutes","launchTimeoutSec","parkingTimeoutSec","respawnGraceSec"}) do
    assert(number(c.recovery[key],1,86400),"Invalid recovery."..key)
  end
  assert(number(c.refuelling.maxDistanceNm,1,500) and number(c.refuelling.maxDurationSec,30,7200),"Invalid tanker range/time")
  assert(number(c.refuelling.tankerMinFuelPercent,0,99),"Invalid tanker reserve")
  assert(integer(c.refuelling.maxFlightsPerTanker) and number(c.refuelling.maxFlightsPerTanker,1,20),"Invalid tanker queue limit")
  local tx=c.taxiRecovery
  assert(type(tx)=="table" and type(tx.enabled)=="boolean","Invalid taxiRecovery")
  local function taxiSettings(s)
    for _,key in ipairs({"checkIntervalSec","startupGraceSec","warnAfterSec","recoverAfterSec",
      "progressMeters","stationarySpeedMps","stationaryConfirmSec","cooldownSec","retryCheckSec",
      "runwayBufferMeters","baseRadiusMeters","parkingScanRadiusMeters","maxParkingSpreadMeters"}) do
      assert(number(s[key],0.1,86400),"Invalid taxiRecovery."..key)
    end
    assert(s.warnAfterSec<s.recoverAfterSec,"Taxi warning must precede recovery")
    assert(integer(s.maxAutomaticRecoveries) and number(s.maxAutomaticRecoveries,0,10),"Invalid taxi recovery limit")
    assert(integer(s.maxParkingCandidates) and number(s.maxParkingCandidates,4,100),"Invalid parking scan limit")
    assert(type(s.avoidPreviousParking)=="boolean","Invalid avoidPreviousParking")
    for _,key in ipairs({"parkingWhitelist","parkingBlacklist"}) do
      assert(type(s[key])=="table","Invalid taxiRecovery."..key)
      for _,id in ipairs(s[key]) do assert(integer(id) and id>=0,"Invalid parking terminal ID") end
    end
    assert(type(s.holdZones)=="table","Invalid taxi hold zones")
    for _,z in ipairs(s.holdZones) do assert(type(z)=="string" and z~="","Invalid taxi hold-zone name") end
  end
  taxiSettings(tx)
  assert(type(tx.bases)=="table","Invalid taxiRecovery.bases")
  for base,override in pairs(tx.bases) do
    assert(type(base)=="string" and type(override)=="table","Invalid taxi base override")
    taxiSettings(merge(tx,override))
  end
  local dp=c.departures
  assert(type(dp)=="table" and type(dp.enabled)=="boolean","Invalid departures")
  assert(integer(dp.maxTaxiFlightsPerBase) and number(dp.maxTaxiFlightsPerBase,1,10),"Invalid departure capacity")
  assert(number(dp.minIntervalSec,0,3600) and number(dp.qraPriorityWindowSec,0,3600),"Invalid departure timing")
  for id,override in pairs(c.squadrons) do
    assert(integer(id) and id>=0 and type(override)=="table","Invalid squadron definition")
    local s=merge(c.squadronDefaults,override)
    assert(s.prefix=="AA" or s.prefix=="AG","Squadron "..id..": prefix must be AA or AG")
    for _,key in ipairs({"maxCAPRefuels","maxQRARefuels"}) do
      assert(integer(s[key]) and number(s[key],0,3),"Squadron "..id..": "..key.." must be 0..3")
    end
    assert(number(s.turnaroundMinutes,0,1440) and number(s.repairExtraMinutes,0,1440),"Invalid turnaround for "..id)
    assert(number(s.startupTaxiSec,0,1800) and number(s.qraRadiusKm,1,2000),"Invalid QRA settings for "..id)
    assert(number(s.minLaunchFuelPercent,c.recovery.lowFuelPercent+1,100),"Launch fuel too low for "..id)
    assert(type(s.allowReducedGroups)=="boolean","allowReducedGroups must be boolean")
  end
  for id,zones in pairs(c.CAP.squadrons) do
    assert(integer(id) and type(zones)=="table","Invalid CAP squadron")
    for _,z in ipairs(zones) do
      assert(type(z)=="string" and z:match("^AA_CAP[1-5]$") and type(c.CAP.zones[z])=="table",
        "Unknown zone in CAP squadron "..id..": "..tostring(z))
    end
  end
  local qseen={}
  for _,id in ipairs(c.QRA.squadrons) do
    assert(integer(id) and not qseen[id],"Invalid/duplicate QRA squadron"); qseen[id]=true
  end
end

function R:_dependencies()
  for _,name in ipairs({"FLIGHTGROUP","AUFTRAG","INTEL","SET_GROUP","SET_ZONE","GROUP","UNIT","AIRBASE","ZONE","ZONE_POLYGON","UTILS","ENUMS","SkynetIADS"}) do
    if type(rawget(_G,name))~="table" then return false,"Missing "..name end
  end
  for _,entry in ipairs({{FLIGHTGROUP,"LandAtAirbase"},{FLIGHTGROUP,"Refuel"},{FLIGHTGROUP,"StartUncontrolled"},
    {GROUP,"Respawn"},{AUFTRAG,"NewGCICAP"},{AUFTRAG,"NewINTERCEPT"},{UTILS,"TasToIas"}}) do
    -- FSM event methods exist on INSTANCES, not the FLIGHTGROUP class table.
    if entry[2]~="LandAtAirbase" and entry[2]~="Refuel" and type(entry[1][entry[2]])~="function" then
      return false,"MOOSE API missing: "..entry[2]
    end
  end
  if rawget(_G,"A2ADispatcher") or rawget(_G,"OPAC_RED_AIR_2") then return false,"Disable old Red Air / Red Air 2 before loading Red Air 3" end
  local source=rawget(_G,self.Config.skynetSensorSet)
  if type(source)~="table" or type(source.GetSet)~="function" then return false,"Missing Skynet set "..self.Config.skynetSensorSet end
  return true
end

function R:_zone(name)
  local z=assert(ZONE:FindByName(name),"Missing trigger zone "..name)
  local cfg=merge(self.Config.CAP.defaults,self.Config.CAP.zones[name])
  assert(number(cfg.altitudeFt,1000,60000) and number(cfg.speedKtas,150,900),"Invalid CAP altitude/speed "..name)
  assert(number(cfg.headingDeg,0,359.999) and number(cfg.legNm,0,100),"Invalid CAP heading/leg "..name)
  local centre=z:GetCoordinate()
  local a=centre:Translate(cfg.legNm*1852/2,(cfg.headingDeg+180)%360,true)
  local b=centre:Translate(cfg.legNm*1852/2,cfg.headingDeg,true)
  assert(z:IsCoordinateInZone(a) and z:IsCoordinateInZone(b),name.." too small for configured racetrack")
  assert(self.border:IsCoordinateInZone(a) and self.border:IsCoordinateInZone(b)
    and self.border:IsCoordinateInZone(centre),name.." racetrack outside ColdBorder")
  return {name=name,zone=z,centre=centre,anchor=a,config=cfg,nextLaunch=0,gap=false}
end

function R:_loss(rec,name,reason)
  if not rec.dead[name] then rec.dead[name]=true; log("LOSS "..name.." reason="..reason) end
end
function R:_units(rec)
  local list={}
  for _,t in ipairs(rec.template.units) do
    if not rec.dead[t.name] then
      local u=physical(t.name)
      if u then list[#list+1]=u else self:_loss(rec,t.name,"missing/dead") end
    end
  end
  return list
end
function R:_stopOps(f)
  local fg=f and f.fg
  if not fg then return true end
  if fg._opacRA3~=self then return false,"OPS instance is not owned by Red Air" end
  local owner=_DATABASE:GetOpsGroup(f.rec.name)
  if owner and owner~=fg then return false,"group controlled by another OPS instance" end
  if type(fg.IsStopped)~="function" then return false,"MOOSE IsStopped API unavailable" end
  if fg:IsStopped() and not owner then return true end
  -- MOOSE normally vetoes Stop while the aircraft are alive. Here only the old
  -- Red Air controller is retired; the verified physical survivors stay alive
  -- until the caller commits its parking replacement. Never alter class methods.
  local previous=rawget(fg,"onbeforeStop"); local ended=f.ended
  f.ended=true -- fence mission-cancel/arrival/dead callbacks during cleanup
  fg.onbeforeStop=function(instance)
    return instance==fg and instance._opacRA3==self and f.ended==true
  end
  local ok,err=pcall(function() fg:Stop() end)
  fg.onbeforeStop=previous; f.ended=ended
  -- FSM handlers catch their own errors, so pcall success alone proves nothing.
  if not ok then return false,"MOOSE Stop error: "..tostring(err) end
  if not fg:IsStopped() then return false,"MOOSE Stop was vetoed" end
  if _DATABASE:GetOpsGroup(f.rec.name) then return false,"MOOSE OPS registration remains after Stop" end
  log("OPS_RELEASED "..f.rec.name)
  return true
end
function R:_release(f)
  if f.slot and f.slot.flight==f then
    f.slot.flight=nil; f.slot.nextLaunch=now()+self.Config.CAP.replacementDelaySec
  end
  f.ended=true; f.refuel=nil
  self.flights[f.rec.name]=nil
  f.rec.flight=nil
  if self.sensorSet then self.sensorSet:RemoveGroupsByName({f.rec.name}); self.sensorNames[f.rec.name]=nil end
end
function R:_lostFlight(f)
  self:_release(f); f.rec.state="LOST"
  local stopped,why=self:_stopOps(f)
  if not stopped then log("OPS_STOP_FAILED "..f.rec.name.." "..tostring(why),true) end
  log("FLIGHT_END "..f.rec.name.." no surviving airframes")
end

function R:RegisterTanker(name)
  local g=GROUP:FindByName(name)
  if not alive(g) or g:GetCoalition()~=coalition.side.RED or not g:IsAir() then return false end
  for _,u in pairs(g:GetUnits() or {}) do
    if u:IsAlive() and u:IsTanker() then
      local t=g:GetTemplate()
      self.tankerGroups[name]={group=g,allowed=name:match("^AT_%d+_")~=nil,
        tasked=hasTask(t and t.route,"Tanker") or hasTask(t and t.tasks,"Tanker")}
      return true
    end
  end
  return false
end

function R:_inventory()
  for coal,c in pairs(env.mission.coalition) do
    if coal=="red" then
      for _,country in pairs(c.country or {}) do
        for _,category in ipairs({"plane","static"}) do
          for _,t in pairs(country[category] and country[category].group or {}) do
            local prefix,numberText=t.name:match("^(A[AG])_(%d+)_")
            local id=tonumber(numberText)
            if id then
              local item=self.catalogue[id] or {groups={},static=0,airframes=0,prefixes={}}
              self.catalogue[id]=item
              local named=item.prefixes[prefix] or {groups={},static=0,airframes=0}
              item.prefixes[prefix]=named
              for _,entry in ipairs({item,named}) do
                if category=="static" then entry.static=entry.static+#t.units
                else entry.groups[#entry.groups+1]=t.name; entry.airframes=entry.airframes+#t.units end
              end
            end
            if category=="plane" then
              self:RegisterTanker(t.name)
              if id and self.Config.squadrons[id]
                and (self.Config.CAP.squadrons[id] or contains(self.Config.QRA.squadrons,id)) then
                local wp=t.route and t.route.points and t.route.points[1]
                local settings=merge(self.Config.squadronDefaults,self.Config.squadrons[id])
                local reason
                if prefix~=settings.prefix then reason="expected prefix "..settings.prefix.."_"..id.."_"
                elseif not wp or not wp.airdromeId or wp.linkUnit or wp.helipadId then reason="not land-based"
                elseif t.lateActivation or not t.uncontrolled then reason="requires active UNCONTROLLED group"
                elseif wp.type~="TakeOffParking" then reason="requires cold ramp start"
                elseif #t.units<1 or #t.units>4 then reason="group must contain 1..4 units" end
                for _,u in ipairs(t.units) do if u.skill=="Client" or u.skill=="Player" then reason="player/client group" end end
                local base=wp and wp.airdromeId and AIRBASE:FindByID(wp.airdromeId)
                if not base or not base:IsAirdrome() then reason=reason or "unknown land airbase" end
                local g=GROUP:FindByName(t.name)
                if not g then reason=reason or "MOOSE group missing" end
                if reason then log("SKIP "..t.name..": "..reason)
                else
                  local template=UTILS.DeepCopy(g:GetTemplate())
                  local rec={name=t.name,id=id,prefix=prefix,template=template,originalSize=#t.units,home=base,
                    settings=settings,
                    dead={},state="READY",group=g,readyAt=0,taxiRecoveries=0}
                  self.records[t.name]=rec
                  local units=self:_units(rec)
                  for _,u in ipairs(units) do if u:inAir() then rec.state="UNAVAILABLE"; log("SKIP "..t.name..": already airborne") end end
                  if #units==0 then rec.state="LOST" end
                end
              end
            end
          end
        end
      end
    end
  end
  for id,settings in pairs(self.Config.squadrons) do
    local prefix=settings.prefix or self.Config.squadronDefaults.prefix
    local item=self.catalogue[id]
    if not item or not item.prefixes[prefix] then log("SQUADRON_ABSENT "..prefix.."_"..id.." skipped") end
  end
  self.eventHandler={onEvent=function(_,event)
    if event.id==world.event.S_EVENT_BIRTH and event.initiator then
      local ok,g=pcall(function() return event.initiator:getGroup() end)
      if ok and g then pcall(function() R:RegisterTanker(g:getName()) end) end
    end
  end}
  world.addEventHandler(self.eventHandler)
end

function R:_syncSensors()
  local source=rawget(_G,self.Config.skynetSensorSet)
  if source~=self.skynetSet then
    if not self.sensorFault then
      self.sensorFault=true; self:Stop()
      log("SENSOR_BRIDGE_REPLACED; launches stopped, recovery continues",true)
    end
    return
  end
  local wanted={}
  if self.running then
    for name,g in pairs(source:GetSet()) do if alive(g) and g:GetCoalition()==coalition.side.RED then wanted[name]=true end end
    if self.Config.fighterSensors then
      for name,f in pairs(self.flights) do
        if f.airborneAt and f.phase~="RTB" and alive(f.rec.group) then wanted[name]=true end
      end
    end
  end
  for name in pairs(self.sensorNames) do if not wanted[name] then self.sensorSet:RemoveGroupsByName({name}) end end
  local names={}; for name in pairs(wanted) do names[#names+1]=name end
  self.sensorSet:AddGroupsByName(names); self.sensorNames=wanted
end

function R:_init()
  local c=self.Config
  self.border=ZONE_POLYGON:New("OPAC_RA3_BORDER",assert(GROUP:FindByName(c.borderGroup),"Missing border group "..c.borderGroup))
  self.skynetSet=rawget(_G,c.skynetSensorSet)
  self.sensorSet=SET_GROUP:New():FilterFunction(function() return false end)
  self.intel=INTEL:New(self.sensorSet,"red","OPAC_RA3 INTEL")
  self.intel:SetAcceptZones(SET_ZONE:New():AddZone(self.border))
  self.intel:FilterCategoryGroup({Group.Category.AIRPLANE,Group.Category.HELICOPTER})
  self.intel:SetDetectionTypes(true,true,true,true,false,false)
  self.intel:SetForgetTime(c.contactMemorySec)
  self.intel:SetClusterAnalysis(false,false,false)
  self.intel:SetVerbosity(0); self.intel.statusupdate=-c.intelIntervalSec
  self:_inventory(); self:_initTaxi(); self:_syncSensors(); self.intel:Start()
  for id in pairs(c.CAP.squadrons) do
    if not c.squadrons[id] then log("CONFIG_NOTICE CAP squadron "..id.." disabled in master list") end
  end
  self.initialized=true
  log("READY groups="..nkeys(self.records).." CAPrange="..c.CAP.count.min..".."..c.CAP.count.max
    .." selection=pending QRAmax="..c.QRA.maxFlights.." operationsAt="..c.operationsStartSec)
  self:Inventory()
end

-- Taxi monitoring owns no additional timer: it is paced by the main controller.
local function groundDistance(a,b)
  return math.sqrt((a.x-b.x)^2+(a.z-b.z)^2)
end
function R:_taxiConfig(base)
  local c=self.Config.taxiRecovery
  return merge(c,c.bases[base:GetName()])
end
function R:_initTaxi()
  self.taxiAvailable=true
  for _,entry in ipairs({{AIRBASE,"GetParkingSpotsTable"},{AIRBASE,"FindFreeParkingSpotForAircraft"},
    {AIRBASE,"GetRunways"},{AIRBASE,"_CheckTerminalType"},{_DATABASE,"Spawn"}}) do
    if type(entry[1])~="table" or type(entry[1][entry[2]])~="function" then
      self.taxiAvailable=false; log("TAXI_DISABLED missing API "..entry[2],true)
    end
  end
end
function R:_departureAllowed(rec,role,own)
  local c=self.Config.departures
  if not c.enabled then return true end
  local b=rec.home; local id=b:GetID(); local last=self.baseLastLaunch[id]
  if last and now()-last<c.minIntervalSec then return false,"base departure spacing" end
  local count=0
  for _,f in pairs(self.flights) do
    if f~=own and not f.ended then
      if role=="CAP" and f.role=="QRA" and f.phase=="ALERT"
        and f.rec.home:GetID()==id and f.deadline
        and now()>=f.deadline-f.rec.settings.startupTaxiSec-c.qraPriorityWindowSec then
        return false,"QRA has departure priority"
      end
      if f.startedAt then
        for _,u in ipairs(self:_units(f.rec)) do
          if not u:inAir() and groundDistance(u:getPoint(),b:GetCoordinate())<=self:_taxiConfig(b).baseRadiusMeters then
            count=count+1; break
          end
        end
      end
    end
  end
  if count>=c.maxTaxiFlightsPerBase then return false,"another managed flight is on the ground" end
  return true
end
function R:_taxiBase(f)
  return f.destination or f.rec.home
end
function R:_taxiProtected(base,units,c)
  for _,name in ipairs(c.holdZones) do
    local z=ZONE:FindByName(name)
    if not z then return true,"missing hold zone "..name end
    for _,u in ipairs(units) do
      if not u:inAir() and z:IsCoordinateInZone(UNIT:FindByName(u:getName()):GetCoordinate()) then return true,"hold zone "..name end
    end
  end
  local runways=base:GetRunways()
  if type(runways)~="table" or not next(runways) then return true,"runway geometry unavailable" end
  local checked=false
  for _,rw in pairs(runways) do
    local a,b=rw.position,rw.endpoint
    if a and b and a.x and a.z and b.x and b.z then
      local dx,dz=b.x-a.x,b.z-a.z; local length2=dx*dx+dz*dz
      if length2>1 then
        checked=true
        for _,u in ipairs(units) do
          local p=u:getPoint()
          local t=math.max(0,math.min(1,((p.x-a.x)*dx+(p.z-a.z)*dz)/length2))
          if not u:inAir() and groundDistance(p,{x=a.x+t*dx,z=a.z+t*dz})<=c.runwayBufferMeters+(rw.width or 0)/2 then
            return true,"runway/holding buffer"
          end
        end
      end
    end
  end
  if not checked then return true,"runway geometry unavailable" end
  return false
end
function R:_taxiParkingKey(base,id) return base:GetName()..":"..tostring(id) end
function R:_freeTaxiReservations(rec)
  for key,owner in pairs(self.taxiParking) do if owner==rec.name then self.taxiParking[key]=nil end end
end
function R:_taxiParkingPlan(f,base,units,c)
  -- Use the largest surviving member, even when the original leader is dead.
  local aircraft,radius
  for _,u in ipairs(units) do
    local w=UNIT:FindByName(u:getName()); local r=w and w:GetBoundingRadius()
    if not r or r<=0 then return nil,"aircraft dimensions unavailable" end
    if not radius or r>radius then aircraft=w; radius=r end
  end
  local pool={}
  for _,p in pairs(base:GetParkingSpotsTable(AIRBASE.TerminalType.FighterAircraft) or {}) do
    local id=p.TerminalID
    if id and p.Coordinate and p.Free==true and p.TOAC~=true and not p.ClientSpot
      and AIRBASE._CheckTerminalType(p.TerminalType,AIRBASE.TerminalType.FighterAircraft)
      and (#c.parkingWhitelist==0 or contains(c.parkingWhitelist,id))
      and not contains(c.parkingBlacklist,id)
      and not self.taxiParking[self:_taxiParkingKey(base,id)]
      and not (c.avoidPreviousParking and f.launchParking and f.launchParking[id]) then
      pool[#pool+1]=p
    end
  end
  local origin=units[1]:getPoint()
  table.sort(pool,function(a,b)
    local da,db=groundDistance(a.Coordinate,origin),groundDistance(b.Coordinate,origin)
    return da<db or (da==db and a.TerminalID<b.TerminalID)
  end)
  while #pool>c.maxParkingCandidates do table.remove(pool) end
  if #pool<#units then return nil,"not enough free alternative parking" end
  local proxy={ClassName="GROUP",GetUnit=function() return aircraft end,GetSize=function() return #units end}
  local spots=base:FindFreeParkingSpotForAircraft(proxy,AIRBASE.TerminalType.FighterAircraft,
    c.parkingScanRadiusMeters,true,true,true,true,#units,pool) or {}
  if #spots<#units then return nil,"parking obstructed or incompatible" end
  for i=2,#spots do
    if groundDistance(spots[1].Coordinate,spots[i].Coordinate)>c.maxParkingSpreadMeters then
      return nil,"clear parking is too widely separated"
    end
  end
  return spots
end
function R:_recoverTaxi(f,manual,ignoreHold)
  if not self.initialized or not self.taxiAvailable then return false,"taxi recovery API unavailable" end
  if not f or f.ended or not f.startedAt then return false,"no started managed flight" end
  local rec=f.rec; local base=self:_taxiBase(f); local c=self:_taxiConfig(base)
  if not manual and (not c.enabled or (rec.taxiRecoveries or 0)>=c.maxAutomaticRecoveries) then
    return false,"automatic recovery limit reached/disabled"
  end
  if not base:IsAirdrome() or base:GetCoalition()~=coalition.side.RED then return false,"recovery base is not a friendly airfield" end
  local owner=_DATABASE:GetOpsGroup(rec.name)
  if owner and owner~=f.fg then return false,"group controlled by another OPS instance" end
  local units=self:_units(rec)
  if #units==0 then return false,"no surviving aircraft" end
  for _,u in ipairs(units) do
    if u:inAir() then return false,"a surviving member is airborne" end
    if speed(u)>c.stationarySpeedMps then return false,"a surviving member is moving" end
    if u.getPlayerName and u:getPlayerName() then return false,"player aircraft" end
    if groundDistance(u:getPoint(),base:GetCoordinate())>c.baseRadiusMeters then return false,"aircraft outside recovery airfield" end
  end
  if not f.taxi or not f.taxi.stationarySince or now()-f.taxi.stationarySince<c.stationaryConfirmSec then
    return false,"stationary confirmation pending"
  end
  if not ignoreHold then
    local protected,why=self:_taxiProtected(base,units,c)
    if protected then return false,why end
  end
  local spots,why=self:_taxiParkingPlan(f,base,units,c)
  if not spots then return false,why end
  local template=UTILS.DeepCopy(rec.template); template.units={}; template.tasks={}
  local expected={}; local damaged=false
  for _,original in ipairs(rec.template.units) do
    local u=not rec.dead[original.name] and physical(original.name)
    if u then
      -- Recheck immediately before committing; no missing member can be restored.
      if u:inAir() or speed(u)>c.stationarySpeedMps then return false,"flight moved during recovery check" end
      local spot=spots[#template.units+1]; local p=spot.Coordinate
      local data=UTILS.DeepCopy(original)
      data.x=p.x; data.y=p.z; data.alt=p.y; data.speed=0
      data.parking=spot.TerminalID; data.parking_id=nil
      template.units[#template.units+1]=data
      expected[data.name]={x=p.x,z=p.z,terminal=spot.TerminalID}
      if lifePercent(u)<99 then damaged=true end
    end
  end
  if #template.units~=#units then return false,"membership changed during recovery check" end
  local first=template.units[1]
  template.x=first.x; template.y=first.y; template.start_time=0
  template.uncontrolled=true; template.lateActivation=false
  template.route={points={{x=first.x,y=first.y,alt=first.alt,alt_type="BARO",speed=0,
    type="TakeOffParking",action="From Parking Area",airdromeId=base:GetID(),
    task={id="ComboTask",params={tasks={}}}}}}
  -- Keep the live group intact until every precondition and parking check passed.
  local stopped,err=self:_stopOps(f)
  if not stopped then return false,"OPS Stop failed: "..tostring(err) end
  self:_release(f)
  rec.taxiRecoveries=(rec.taxiRecoveries or 0)+1
  rec.diverted=base:GetID()~=rec.home:GetID()
  local delay=c.cooldownSec
  if f.airborneAt then delay=math.max(delay,rec.settings.turnaroundMinutes*60) end
  if damaged then delay=delay+rec.settings.repairExtraMinutes*60 end
  rec.readyAt=now()+delay; rec.state="RESPAWNING"
  rec.respawnDeadline=now()+self.Config.recovery.respawnGraceSec
  rec.taxiVerification=expected; rec.expected={}
  for name,p in pairs(expected) do
    rec.expected[name]=true; self.taxiParking[self:_taxiParkingKey(base,p.terminal)]=rec.name
  end
  local spawned,spawnError=pcall(function()
    -- GROUP:Respawn() normally restores current live positions. Here we must use
    -- the explicitly checked ramp template instead of the blocked taxiway.
    rec.group:Destroy(false)
    rec.group:ResetEvents()
    rec.group=assert(_DATABASE:Spawn(template),"DATABASE:Spawn returned nil")
  end)
  if not spawned then
    rec.group=GROUP:FindByName(rec.name)
    log("TAXI_SPAWN_FAILED "..rec.name.." "..tostring(spawnError).."; no automatic respawn retry",true)
  end
  local ids={}; for _,s in ipairs(spots) do ids[#ids+1]=tostring(s.TerminalID) end
  log("TAXI_RECOVER "..rec.name.." survivors="..#units.." base="..base:GetName().." parking="..table.concat(ids,",")
    .." attempt="..rec.taxiRecoveries.." manual="..tostring(manual==true).." readyAt="..math.floor(rec.readyAt))
  return true,spawned and "recovery committed; verification pending" or "spawn failed; verification pending"
end
function R:_monitorTaxi(f,units,anyAir,allAir)
  if not self.taxiAvailable or f.ended or not f.startedAt or not f.taxi then return false end
  local tx=f.taxi; local base=self:_taxiBase(f); local c=self:_taxiConfig(base); local t=now()
  if t<tx.nextCheck then return false end
  tx.nextCheck=t+c.checkIntervalSec
  if allAir then tx.units={}; tx.stationarySince=nil; tx.stuckUnit=nil; tx.protected=nil; return false end
  local stationary=not anyAir
  for _,u in ipairs(units) do if speed(u)>c.stationarySpeedMps then stationary=false end end
  if stationary then tx.stationarySince=tx.stationarySince or t else tx.stationarySince=nil end
  local protected,protection=self:_taxiProtected(base,units,c)
  tx.protected=protected and protection or nil
  local longest,blocked=0,nil
  for _,u in ipairs(units) do
    local name=u:getName(); local p=u:getPoint()
    if u:inAir() or f.arrived[name] then tx.units[name]=nil
    else
      local track=tx.units[name]
      if not track then track={anchor={x=p.x,z=p.z},lastProgress=t,moved=false}; tx.units[name]=track end
      if groundDistance(p,track.anchor)>=c.progressMeters then
        track.anchor={x=p.x,z=p.z}; track.lastProgress=t; track.moved=true
      end
      if f.landed[name] then track.moved=true end
      if protected or (not f.airborneAt and t-f.startedAt<c.startupGraceSec) then
        track.lastProgress=t
      elseif track.moved and t-track.lastProgress>longest then
        longest=t-track.lastProgress; blocked=name
      end
    end
  end
  tx.stuckUnit=blocked; tx.stuckSeconds=longest
  if blocked and longest>=c.warnAfterSec then
    local unit=physical(blocked); if not unit then return false end
    local p=unit:getPoint()
    self:_notice("taxi:"..blocked,"TAXI_STUCK "..f.rec.name.." unit="..blocked.." idle="..math.floor(longest)
      .."s x="..math.floor(p.x).." z="..math.floor(p.z)..(anyAir and " partial departure; no group reset" or ""))
  end
  if not c.enabled or not blocked or longest<c.recoverAfterSec or anyAir or not stationary
    or t-tx.lastAttempt<c.retryCheckSec then return false end
  tx.lastAttempt=t
  local ok,done,why=pcall(self._recoverTaxi,self,f,false,false)
  if not ok then why=done; done=false end
  if not done then self:_notice("taxi-recovery:"..f.rec.name,"TAXI_RECOVERY_WAIT "..f.rec.name.." "..tostring(why)) end
  return done==true
end

function R:_eligible(rec)
  if rec.state~="READY" or rec.flight or now()<rec.readyAt then return false end
  if _DATABASE:GetOpsGroup(rec.name) then
    self:_notice("owner:"..rec.name,"NOT_READY "..rec.name.." already controlled by another OPS instance")
    return false
  end
  if rec.home:GetCoalition()~=coalition.side.RED then return false end
  local units=self:_units(rec)
  if #units==0 then rec.state="LOST"; return false end
  if not rec.settings.allowReducedGroups and #units<rec.originalSize then return false end
  for _,u in ipairs(units) do
    if u:inAir() or speed(u)>1 then return false end
    if aamCount(u)<1 then self:_notice("ammo:"..rec.name,"NOT_READY "..rec.name.." missing AAM"); return false end
    if u:getFuel()*100<rec.settings.minLaunchFuelPercent or lifePercent(u)<99 then
      self:_notice("service:"..rec.name,"NOT_READY "..rec.name.." fuel/damage requires ME service"); return false
    end
  end
  return true
end
-- Maximum bipartite matching: a physical ME group can cover at most one zone.
-- At most five zone vertices; no combinatorial search over aircraft groups.
local function capCapacity(graph,names,excluded)
  local owners={}
  local function augment(zone,visited)
    for _,rec in ipairs(graph[zone] or {}) do
      if rec.name~=excluded and not visited[rec.name] then
        visited[rec.name]=true
        if not owners[rec.name] or augment(owners[rec.name],visited) then
          owners[rec.name]=zone; return true
        end
      end
    end
    return false
  end
  local count=0
  for _,name in ipairs(names) do if augment(name,{}) then count=count+1 end end
  return count
end
function R:_capGraph(names,keepFlights)
  local graph={}; for _,name in ipairs(names) do graph[name]={} end
  local records={}; for _,rec in pairs(self.records) do records[#records+1]=rec end
  table.sort(records,function(a,b) return a.name<b.name end)
  for _,rec in ipairs(records) do
    local allowed=self.Config.squadrons[rec.id] and self.Config.CAP.squadrons[rec.id]
    if allowed then
      local ready=self:_eligible(rec)
      local f=rec.flight
      -- On an explicit redraw an assigned CAP flight can keep its OWN zone.
      -- It cannot be counted as a spare for another zone, including during AAR.
      local current=keepFlights and f and not f.ended and f.role=="CAP" and f.slot
        and #self:_units(rec)>0 and f.phase~="QUARANTINED"
      for _,name in ipairs(names) do
        if contains(allowed,name) and (ready or (current and f.slot.name==name)) then
          graph[name][#graph[name]+1]=rec
        end
      end
    end
  end
  return graph
end
function R:_drawCAPPlan(minimum,maximum)
  local requested=minimum==maximum and minimum or math.random(minimum,maximum)
  local plan={minimum=minimum,maximum=maximum,requested=requested,zones={},slots={},capacity=0,selectedAt=now()}
  if requested==0 then return plan end
  local graph=self:_capGraph(self.Config.CAP.zonePool,true)
  local names={}
  for _,name in ipairs(self.Config.CAP.zonePool) do
    if #graph[name]>0 then
      local ok,slot=pcall(self._zone,self,name)
      if ok then names[#names+1]=name; plan.slots[name]=slot
      else self:_notice("cap-zone:"..name,"CAP_ZONE_SKIPPED "..name.." "..tostring(slot)) end
    else self:_notice("cap-zone:"..name,"CAP_ZONE_SKIPPED "..name.." no eligible assigned CAP group") end
  end
  table.sort(names)
  plan.capacity=capCapacity(graph,names)
  local count=math.min(requested,plan.capacity)
  if count==0 then return plan end
  -- At most C(5,2)=10 combinations for a fixed count. Each feasible set gets
  -- one entry, regardless of how many squadrons/groups can support it.
  local feasible={}
  local function combinations(first,selected)
    if #selected==count then
      if capCapacity(graph,selected)==count then feasible[#feasible+1]=UTILS.DeepCopy(selected) end
      return
    end
    for i=first,#names do
      selected[#selected+1]=names[i]; combinations(i+1,selected); selected[#selected]=nil
    end
  end
  combinations(1,{})
  assert(#feasible>0,"CAP matching produced no feasible combination")
  plan.zones=feasible[#feasible==1 and 1 or math.random(#feasible)]
  -- Also randomize allocation order; pool order must not reserve every spare
  -- for the same zone when launches have to wait for base traffic.
  for i=#plan.zones,2,-1 do
    local j=math.random(i); plan.zones[i],plan.zones[j]=plan.zones[j],plan.zones[i]
  end
  return plan
end
function R:_applyCAPPlan(plan,reason)
  local chosen={}; for _,name in ipairs(plan.zones) do chosen[name]=true end
  for name,slot in pairs(self.slots) do
    slot.active=chosen[name]==true
    if not slot.active then
      slot.gap=false
      if slot.flight then self:_rtb(slot.flight,"CAP zone deselected") end
    end
  end
  for _,name in ipairs(plan.zones) do
    self.slots[name]=self.slots[name] or plan.slots[name]
    self.slots[name].active=true
  end
  self.capPlan=plan; self.capZones=UTILS.DeepCopy(plan.zones)
  log("CAP_PLAN reason="..reason.." range="..plan.minimum..".."..plan.maximum.." requested="..plan.requested
    .." selected="..#plan.zones.." zones="..table.concat(plan.zones,","))
  if #plan.zones<plan.requested then
    log("CAP_SHORTFALL requested="..plan.requested.." available="..#plan.zones.." configuredMin="..plan.minimum
      .."; selected zones retained until an explicit new draw or mission restart")
  end
end
function R:_select(role,slot,contact)
  local candidates={}
  if role=="CAP" then
    local names,others={slot.name},{}
    for _,name in ipairs(self.capZones) do
      local pending=self.slots[name]
      if name~=slot.name and pending and pending.active and not pending.flight then
        names[#names+1]=name; others[#others+1]=name
      end
    end
    local graph=self:_capGraph(names,false)
    local capacity=capCapacity(graph,names)
    for _,rec in ipairs(graph[slot.name]) do
      if self:_departureAllowed(rec,role) and capCapacity(graph,others,rec.name)>=capacity-1 then
        candidates[#candidates+1]=rec
      end
    end
  else
    for _,rec in pairs(self.records) do
      if contains(self.Config.QRA.squadrons,rec.id) and self:_eligible(rec)
        and (not contact or self:_contact(contact,rec.settings.qraRadiusKm*1000,rec.home:GetCoordinate())) then
        candidates[#candidates+1]=rec
      end
    end
  end
  local bySquad={}
  for _,rec in ipairs(candidates) do
    bySquad[rec.id]=bySquad[rec.id] or {}; table.insert(bySquad[rec.id],rec)
  end
  local ids={}; for id in pairs(bySquad) do ids[#ids+1]=id end; table.sort(ids)
  if #ids==0 then return nil end
  local groups=bySquad[ids[math.random(#ids)]]
  table.sort(groups,function(a,b) return a.name<b.name end)
  return groups[math.random(#groups)]
end

function R:_contact(c,range,origin)
  if not c or not c.position or not c.Tdetected or not alive(c.group) then return false end
  if timer.getAbsTime()-c.Tdetected>self.Config.contactMemorySec then return false end
  if c.group:GetCoalition()~=coalition.side.BLUE or not c.group:IsAir() or not c.group:IsAirborne() then return false end
  if not self.border:IsCoordinateInZone(c.position) or not self.border:IsCoordinateInZone(c.group:GetCoordinate()) then return false end
  return not range or dist(c.position,origin)<=range
end
function R:_newMission(f,mission,target)
  local previous=f.mission
  f.mission=mission; f.target=target
  f.fg:AddMission(mission)
  if previous and not previous:IsOver() then previous:Cancel() end
end
function R:_capMission(f)
  local s=f.slot; local c=s.config
  local kias=UTILS.TasToIas(c.speedKtas,UTILS.FeetToMeters(c.altitudeFt))
  local m
  if c.legNm==0 then m=AUFTRAG:NewORBIT_CIRCLE(s.centre,c.altitudeFt,kias)
  else m=AUFTRAG:NewGCICAP(s.anchor,c.altitudeFt,kias,c.headingDeg,c.legNm) end
  m:SetMissionAltitude(c.altitudeFt); m:SetROE(ENUMS.ROE.ReturnFire); m:SetROT(ENUMS.ROT.EvadeFire)
  self:_newMission(f,m,nil)
end
function R:_intercept(f,contact)
  local c=self.Config.QRA; local m=AUFTRAG:NewINTERCEPT(contact.group)
  m:SetMissionAltitude(c.altitudeFt); m:SetEngageAltitude(c.altitudeFt)
  m:SetMissionSpeed(UTILS.TasToIas(c.speedKtas,UTILS.FeetToMeters(c.altitudeFt)))
  self:_newMission(f,m,contact.groupname)
  log("INTERCEPT "..f.rec.name.." target="..contact.groupname)
end

function R:_reserve(rec,role,slot,contact)
  self.serial=self.serial+1
  local f={rec=rec,role=role,slot=slot,serial=self.serial,phase="ALERT",alertAt=now(),
    target=contact and contact.groupname,refuels=0,landed={},arrived={},departed={},ended=false}
  rec.flight=f; rec.state="ASSIGNED"; self.flights[rec.name]=f
  if slot then slot.flight=f end
  return f
end

function R:_bind(f)
  assert(not _DATABASE:GetOpsGroup(f.rec.name),"Group already controlled by another OPS instance")
  local fg=assert(FLIGHTGROUP:New(f.rec.group),"FLIGHTGROUP:New failed")
  f.fg=fg
  assert(not fg._opacRA3 or fg._opacRA3==self,"Group already owned")
  fg._opacRA3=self
  fg:SetHomebase(f.rec.home); fg:SetDestinationbase(f.rec.home)
  fg:SetFuelLowThreshold(self.Config.recovery.lowFuelPercent); fg:SetFuelLowRTB(false)
  fg:SetFuelCriticalThreshold(self.Config.recovery.criticalFuelPercent); fg:SetFuelCriticalRTB(false)
  fg:SetFuelLowRefuel(false); fg:SetOutOfAAMRTB(false); fg:SetOutOfAGMRTB(false)
  fg:SetEngageDetectedOff()
  fg.stuckDespawn=false
  -- Red Air owns the bounded stuck-flight policy, including normal ATC holds.
  -- MOOSE otherwise cancels a taxiing mission after 15 min independently.
  function fg:_CheckStuck() return nil end
  fg.despawnAfterLanding=false; fg.despawnAfterHolding=false
  fg:_InitWaypoints(1,1) -- discard authored follow-on routes; keep physical group
  if fg.waypoints0 then fg.waypoints0={fg.waypoints0[1]} end
  fg:ClearTasks()
  -- Instance override: prevents MOOSE's internal delayed RTB path deleting a
  -- blocked ground group. ALL managed returns use our LandAtAirbase path.
  function fg:onbeforeRTB() return false end
  -- LandAtAirbase's default pre-check postpones an entire partly launched
  -- formation while its FSM still says Parking. Check actual aircraft instead;
  -- this also avoids stale currbase rejecting a diversion after base capture.
  function fg:onbeforeLandAtAirbase(_,__,___,base)
    if f.ended or f.phase~="RTB" or not base or not base:IsAirdrome()
      or base:GetCoalition()~=coalition.side.RED then return false end
    for _,u in ipairs(R:_units(f.rec)) do if u:inAir() then return true end end
    return false
  end
  function fg:OnBeforeMissionStart() return not f.ended and (f.phase=="STARTING" or f.phase=="ACTIVE" or f.phase=="REJOIN") end
  function fg:OnBeforeUpdateRoute() return not f.ended and (f.phase=="STARTING" or f.phase=="ACTIVE" or f.phase=="REJOIN") end
  function fg:OnBeforeArrived()
    if not f.ended and f.airborneAt then f.arrivalSignal=true end
    return false -- owns visible parking; veto default MOOSE arrival despawn
  end
  function fg:OnBeforeRefueled()
    if f.ended or f.phase~="REFUEL" then return false end
    f.refuelTaskDone=true
    return f.acceptRefueled==true -- controller verifies actual fuel for all units
  end
  function fg:OnBeforeElementLanded(_,__,___,element,base)
    if not f.ended and element then f.landed[element.name]=base end
    return true
  end
  function fg:OnBeforeElementArrived(_,__,___,element,base,parking)
    if not f.ended and element then f.arrived[element.name]={base=base,parking=parking} end
    return true
  end
  function fg:OnBeforeElementDead(_,__,___,element)
    if not f.ended and element then R:_loss(f.rec,element.name,"MOOSE element dead") end
    return true
  end
end

function R:_launch(f,contact)
  if f.ended then return false end
  local rec=f.rec
  local ready,why=self:_departureAllowed(rec,f.role,f)
  if not ready then
    self:_notice("depart:"..rec.name,"DEPARTURE_WAIT "..rec.name.." "..why)
    if f.role=="CAP" then self:_release(f); rec.state="READY" end
    return false -- QRA stays ALERT with its original deadline
  end
  rec.state="READY"; rec.flight=nil
  local eligible=self:_eligible(rec)
  rec.flight=f; rec.state="ASSIGNED"
  if not eligible then self:_release(f); rec.state="READY"; return false end
  local ok,err=pcall(function()
    f.phase="STARTING"; f.startedAt=now()
    self:_bind(f)
    f.taxi={units={},nextCheck=now(),lastAttempt=-math.huge}
    f.launchParking={}
    for _,u in ipairs(rec.group:GetTemplate().units or {}) do
      local terminal=tonumber(u.parking)
      if terminal then f.launchParking[terminal]=true end
    end
    for _,u in ipairs(self:_units(rec)) do
      local p=u:getPoint()
      f.taxi.units[u:getName()]={anchor={x=p.x,z=p.z},lastProgress=now(),moved=false}
    end
    if f.role=="CAP" then self:_capMission(f) else self:_intercept(f,contact) end
    f.fg:StartUncontrolled()
    self.baseLastLaunch[rec.home:GetID()]=now()
  end)
  if not ok then
    rec.state="UNAVAILABLE"; f.phase="QUARANTINED"
    log("LAUNCH_ERROR "..rec.name..": "..tostring(err),true)
    local stopped,why=self:_stopOps(f)
    if not stopped then log("OPS_STOP_FAILED "..rec.name.." "..tostring(why),true) end
    -- Preserve real aircraft; a later observed takeoff is recovered by tick.
    return false
  end
  log("START "..f.role.." "..rec.name.." airframes="..#self:_units(rec))
  return true
end

function R:_destination(f)
  if f.rec.home:GetCoalition()==coalition.side.RED then return f.rec.home end
  local best,dmin=nil,math.huge
  for _,name in ipairs(self.Config.recovery.alternateBases) do
    local b=AIRBASE:FindByName(name)
    if b and b:IsAirdrome() and b:GetCoalition()==coalition.side.RED then
      local d=dist(f.rec.group:GetCoordinate(),b:GetCoordinate())
      if d<dmin then best=b; dmin=d end
    end
  end
  return best
end
function R:_rtb(f,reason)
  if f.ended or f.phase=="RTB" then return end
  if f.phase=="ALERT" then self:_release(f); f.rec.state="READY"; return end
  f.returnReason=reason; f.target=nil; f.refuel=nil
  if not f.airborneAt then f.returnWhenAirborne=true; return end
  f.phase="RTB"; f.rtbAt=now()
  local b=self:_destination(f)
  f.destination=b
  f.fg:SetEngageDetectedOff(); f.fg:CancelAllMissions(); f.fg:ClearTasks()
  f.mission=nil
  f.rec.group:SetOption(AI.Option.Air.id.RTB_ON_BINGO,false)
  if b then
    f.fg:LandAtAirbase(b)
    log("RTB "..f.rec.name.." to="..b:GetName().." reason="..reason)
  else
    -- There is no authorized safe destination. Let native emergency RTB work;
    -- no recovery credit without a real, friendly parking observation.
    f.rec.group:SetOption(AI.Option.Air.id.RTB_ON_BINGO,true)
    log("NO_FRIENDLY_DESTINATION "..f.rec.name.."; configure alternateBases",true)
  end
end

function R:_park(f,units)
  local rec=f.rec; local base
  for _,u in ipairs(units) do
    local p=f.arrived[u:getName()]
    if u:inAir() or speed(u)>0.5 or not p or not p.base or not p.parking then return false end
    if not p.base:IsAirdrome() or p.base:GetCoalition()~=coalition.side.RED then return false end
    if base and base:GetName()~=p.base:GetName() then return false end
    base=p.base
  end
  if #units==0 or not base then return false end
  local t=UTILS.DeepCopy(rec.template); t.units={}; t.tasks={}; t.uncontrolled=true; t.lateActivation=false
  local damaged=false
  for _,old in ipairs(rec.template.units) do
    local u=not rec.dead[old.name] and physical(old.name)
    if u then
      local data=UTILS.DeepCopy(old); local pos=u:getPoint(); local orientation=u:getPosition()
      local heading=math.atan2(orientation.x.z,orientation.x.x)
      data.x=pos.x; data.y=pos.z; data.alt=pos.y; data.heading=heading; data.psi=-heading
      data.parking=f.arrived[old.name].parking.TerminalID; data.parking_id=nil
      data.speed=0; t.units[#t.units+1]=data
      if lifePercent(u)<99 then damaged=true end
    end
  end
  if #t.units==0 then return false end
  local first=t.units[1]
  t.x=first.x; t.y=first.y
  t.route={points={{x=first.x,y=first.y,alt=first.alt,alt_type="BARO",speed=0,
    type="TakeOffParking",action="From Parking Area",airdromeId=base:GetID(),
    task={id="ComboTask",params={tasks={}}}}}}
  t.start_time=0
  local stopped,why=self:_stopOps(f)
  if not stopped then
    self:_notice("park-stop:"..rec.name,"PARKING_WAIT "..rec.name.." "..tostring(why))
    return false -- do not delete aircraft or release the flight on failed cleanup
  end
  local cfg=rec.settings
  rec.readyAt=now()+60*(cfg.turnaroundMinutes+(damaged and cfg.repairExtraMinutes or 0))
  rec.diverted=base:GetName()~=rec.home:GetName()
  rec.state="RESPAWNING"; rec.respawnDeadline=now()+self.Config.recovery.respawnGraceSec
  rec.expected={}; for _,u in ipairs(t.units) do rec.expected[u.name]=true end
  self:_release(f)
  rec.group:Respawn(t) -- supplied survivor-only template at verified actual parking
  log("PARKED "..rec.name.." survivors="..#t.units.." base="..base:GetName().." readyAt="..math.floor(rec.readyAt))
  return true
end

function R:_tanker(f)
  local closest,bestDistance=nil,math.huge
  local receiverType
  for _,u in ipairs(self:_units(f.rec)) do
    local wrapper=UNIT:FindByName(u:getName())
    local capable,kind=wrapper:IsRefuelable()
    if not capable or kind==nil or (receiverType and receiverType~=kind) then return nil,"aircraft cannot refuel" end
    receiverType=kind
  end
  if receiverType==nil then return nil,"no receivers" end
  local origin=f.rec.group:GetCoordinate()
  for name,item in pairs(self.tankerGroups) do
    local g=GROUP:FindByName(name)
    if alive(g) and g:GetCoalition()==coalition.side.RED then
      for _,u in pairs(g:GetUnits() or {}) do
        local tanker,kind=u:IsTanker()
        if tanker and kind==receiverType and u:IsAlive() and u:InAir()
          and (u:GetFuel() or 0)*100>=self.Config.refuelling.tankerMinFuelPercent then
          local d=dist(origin,u:GetCoordinate())
          if d<bestDistance then closest={name=name,group=g,unit=u,item=item}; bestDistance=d end
        end
      end
    end
  end
  if not closest or bestDistance>self.Config.refuelling.maxDistanceNm*1852 then return nil,"no airborne tanker in range" end
  if not closest.item.allowed or not closest.item.tasked then return nil,"nearest tanker is not operative AT_ tanker" end
  if not self.border:IsCoordinateInZone(closest.unit:GetCoordinate()) then return nil,"tanker outside ColdBorder" end
  local reservations=0
  for _,other in pairs(self.flights) do
    if other~=f and other.refuel and other.refuel.tanker==closest.name then reservations=reservations+1 end
  end
  if reservations>=self.Config.refuelling.maxFlightsPerTanker then return nil,"tanker reserved" end
  return closest
end
function R:_refuel(f)
  local limit=f.role=="CAP" and f.rec.settings.maxCAPRefuels or f.rec.settings.maxQRARefuels
  if f.refuels>=limit then return false,"refuelling disabled/limit reached" end
  local tanker,reason=self:_tanker(f)
  if not tanker then return false,reason end
  f.phase="REFUEL"; f.refuelTaskDone=false
  f.refuel={tanker=tanker.name,startedAt=now(),initial={}}
  for _,u in ipairs(self:_units(f.rec)) do f.refuel.initial[u:getName()]=u:getFuel()*100 end
  if f.slot then f.slot.gap=true end
  f.fg:CancelAllMissions(); f.mission=nil; f.fg:ClearTasks()
  f.fg:Refuel(tanker.unit:GetCoordinate())
  log("REFUEL_BEGIN "..f.rec.name.." tanker="..tanker.name.." cycle="..(f.refuels+1).."/"..limit)
  return true
end
function R:_manageRefuel(f,units,contacts)
  local complete=true
  for _,u in ipairs(units) do
    if u:getFuel()*100<self.Config.refuelling.completeFuelPercent then complete=false end
  end
  if complete then
    f.refuels=f.refuels+1; f.acceptRefueled=true
    f.fg:Refueled(); f.acceptRefueled=false; f.refuel=nil
    f.phase=f.role=="CAP" and "REJOIN" or "ACTIVE"
    log("REFUEL_OK "..f.rec.name.." completed="..f.refuels)
    if f.role=="CAP" then self:_capMission(f)
    else
      local contact=contacts[f.target]
      if self:_contact(contact,f.rec.settings.qraRadiusKm*1000,f.rec.home:GetCoordinate()) then self:_intercept(f,contact)
      else self:_rtb(f,"QRA contact lost during refuel") end
    end
    return
  end
  local t=self.tankerGroups[f.refuel.tanker]
  local g=t and GROUP:FindByName(f.refuel.tanker)
  local tanker,reason=self:_tanker(f)
  if not alive(g) or not tanker or tanker.name~=f.refuel.tanker then
    self:_rtb(f,reason or "assigned tanker unavailable/changed"); return
  end
  if f.refuelTaskDone or now()-f.refuel.startedAt>=self.Config.refuelling.maxDurationSec then
    self:_rtb(f,"refuel incomplete/timeout")
  end
end

function R:_manageFlight(f,contacts)
  if f.ended then return end
  local units=self:_units(f.rec)
  if #units==0 then self:_lostFlight(f); return end
  local anyAir,allAir,minFuel,minLife,totalAAM,anyEmpty=false,true,1000,100,0,false
  for _,u in ipairs(units) do
    local airborne=u:inAir()
    anyAir=anyAir or airborne; allAir=allAir and airborne
    if airborne then f.departed[u:getName()]=true end
    minFuel=math.min(minFuel,u:getFuel()*100); minLife=math.min(minLife,lifePercent(u))
    local n=aamCount(u); totalAAM=totalAAM+n; anyEmpty=anyEmpty or n==0
  end
  if f.role=="QRA" and f.deadline and not f.allAirborneAt and now()>f.deadline and not f.lateLogged then
    f.lateLogged=true; log("QRA_LATE "..f.rec.name.." deadline="..math.floor(f.deadline),true)
  end
  if f.phase=="ALERT" then return end
  if anyAir and not f.airborneAt then f.airborneAt=now() end
  if allAir and not f.allAirborneAt then
    f.allAirborneAt=now(); if f.phase=="STARTING" then f.phase="ACTIVE" end
    log("AIRBORNE "..f.rec.name.." elapsed="..math.floor(now()-f.alertAt).."s")
  end
  local txok,recovered=pcall(self._monitorTaxi,self,f,units,anyAir,allAir)
  if not txok then self:_notice("taxi-error:"..f.rec.name,"TAXI_MONITOR_ERROR "..f.rec.name.." "..tostring(recovered))
  elseif recovered then return end
  if f.airborneAt and not anyAir then
    if self:_park(f,units) then return end
    f.groundedAt=f.groundedAt or now()
    if now()-f.groundedAt>=self.Config.recovery.parkingTimeoutSec then
      self:_notice("parking:"..f.rec.name,"PARKING_BLOCKED "..f.rec.name.."; aircraft retained, no reuse")
    end
    return
  end
  if not f.airborneAt then
    if f.startedAt and now()-f.startedAt>=self.Config.recovery.launchTimeoutSec then
      f.phase="QUARANTINED"; f.rec.state="UNAVAILABLE"
      self:_notice("launch:"..f.rec.name,"LAUNCH_BLOCKED "..f.rec.name.."; retained, slot reserved")
    end
    return
  end
  if f.phase=="QUARANTINED" or f.returnWhenAirborne then self:_rtb(f,f.returnReason or "late takeoff from quarantined group"); return end
  if f.phase=="RTB" then
    if f.destination and f.destination:GetCoalition()~=coalition.side.RED then
      f.phase="ACTIVE"; f.fg.currbase=nil; self:_rtb(f,"destination captured")
    end
    return
  end
  local c=self.Config.recovery
  if minFuel<=c.criticalFuelPercent then self:_rtb(f,"critical fuel"); return end
  if minLife<c.returnBelowLifePercent then self:_rtb(f,"damage"); return end
  if totalAAM==0 or (c.returnOnAnyEmptyAAM and anyEmpty) then self:_rtb(f,"AAM depleted"); return end
  if now()-f.airborneAt>=c.maxSortieMinutes*60 then self:_rtb(f,"sortie time limit"); return end
  if not allAir then
    if now()-f.startedAt>=c.launchTimeoutSec then self:_rtb(f,"partial launch timeout") end
    return -- fuel/damage/weapon emergencies above still apply to mixed groups
  end
  if f.phase=="REFUEL" then self:_manageRefuel(f,units,contacts); return end
  local limit=f.role=="CAP" and f.rec.settings.maxCAPRefuels or f.rec.settings.maxQRARefuels
  if minFuel<=self.Config.refuelling.requestFuelPercent and f.refuels<limit then
    local sent,why=self:_refuel(f)
    if sent then return end
    self:_rtb(f,"AAR unavailable: "..why); return
  end
  if minFuel<=c.lowFuelPercent then self:_rtb(f,"low fuel/refuel limit"); return end
  if f.phase=="REJOIN" then
    if f.slot.zone:IsCoordinateInZone(f.rec.group:GetCoordinate()) then f.phase="ACTIVE"; f.slot.gap=false; log("CAP_REJOIN "..f.rec.name) end
    return
  end
  if f.slot and f.slot.zone:IsCoordinateInZone(f.rec.group:GetCoordinate()) then f.slot.gap=false end
  local origin=f.slot and f.slot.centre or f.rec.home:GetCoordinate()
  local limitKm=f.role=="CAP" and self.Config.CAP.pursuitLimitKm or self.Config.QRA.pursuitLimitKm
  if f.target then
    local contact=contacts[f.target]
    local valid=self:_contact(contact)
    local beyond=dist(f.rec.group:GetCoordinate(),origin)>limitKm*1000
    if not valid or beyond or (f.mission and f.mission:IsOver()) then
      if f.role=="CAP" then self:_capMission(f) else self:_rtb(f,"contact lost/border/pursuit/task complete") end
    end
  end
end

function R:_ground(rec)
  if rec.state=="RESPAWNING" then
    if now()<rec.respawnDeadline then return end
    -- No retry: a failed respawn must not recreate losses from a stale template.
    local units=self:_units(rec)
    self:_freeTaxiReservations(rec)
    if #units==0 then rec.state="LOST"; log("RESPAWN_FAILED "..rec.name,true); return end
    rec.group=GROUP:FindByName(rec.name)
    if rec.taxiVerification then
      for _,u in ipairs(units) do
        local p=rec.taxiVerification[u:getName()]
        if not p or u:inAir() or groundDistance(u:getPoint(),p)>60 then
          rec.state="UNAVAILABLE"; rec.taxiVerification=nil
          log("TAXI_VERIFY_FAILED "..rec.name.." unexpected position/airborne; no further spawn",true)
          return
        end
      end
      rec.taxiVerification=nil
      log("TAXI_RECOVERED "..rec.name.." survivors="..#units.."; visible on ramp")
    end
    rec.state=rec.diverted and "DIVERTED" or "TURNAROUND"
  end
  local units=self:_units(rec)
  if #units==0 then rec.state="LOST"; return end
  if rec.state=="TURNAROUND" and now()>=rec.readyAt then rec.state="READY"; log("READY_AGAIN "..rec.name.." survivors="..#units) end
end
function R:_readiness()
  for _,slot in pairs(self.slots) do if slot.active~=false and slot.gap then return self.Config.QRA.refuellingAirborneSec end end
  return self.Config.QRA.normalAirborneSec
end

function R:_tick()
  self:_syncSensors()
  local contacts={}
  for _,c in pairs(self.intel:GetContactTable() or {}) do contacts[c.groupname]=c end
  local current={}; for _,f in pairs(self.flights) do current[#current+1]=f end
  for _,f in ipairs(current) do self:_manageFlight(f,contacts) end
  for _,rec in pairs(self.records) do if not rec.flight then self:_ground(rec) end end
  if not self.running or now()<self.Config.operationsStartSec then return end
  local readiness=self:_readiness()
  if readiness~=self.readiness then self.readiness=readiness; log("QRA_READINESS "..readiness.."s alert-to-airborne") end
  for _,f in pairs(self.flights) do
    if f.role=="QRA" and f.deadline and not f.allAirborneAt then
      f.deadline=math.min(f.deadline,f.alertAt+readiness)
    end
  end

  local assigned={}
  for _,f in pairs(self.flights) do
    if f.target and f.phase~="RTB" and f.phase~="QUARANTINED" then assigned[f.target]=f end
  end
  -- Existing pending alerts keep their original clock and group reservation.
  for _,f in ipairs(current) do
    if not f.ended and f.phase=="ALERT" then
      local contact=contacts[f.target]
      f.deadline=math.min(f.deadline,f.alertAt+readiness)
      if not self:_contact(contact,f.rec.settings.qraRadiusKm*1000,f.rec.home:GetCoordinate()) then
        assigned[f.target]=nil; self:_release(f); f.rec.state="READY"; log("QRA_CANCEL "..f.rec.name.." contact invalid")
      elseif now()>=f.deadline-f.rec.settings.startupTaxiSec then self:_launch(f,contact) end
    end
  end
  local candidates={}
  for _,c in pairs(contacts) do if self:_contact(c) then candidates[#candidates+1]=c end end
  table.sort(candidates,function(a,b) return a.groupname<b.groupname end)
  -- Available airborne CAP gets first opportunity, including taking over an
  -- unlaunched QRA alert; the latter is released without starting engines.
  for _,c in ipairs(candidates) do
    local owner=assigned[c.groupname]
    if not owner or owner.phase=="ALERT" then
      local best,dmin=nil,math.huge
      for _,f in pairs(self.flights) do
        if f.role=="CAP" and f.phase=="ACTIVE" and f.allAirborneAt and not f.target
          and dist(c.position,f.slot.centre)<=self.Config.CAP.pursuitLimitKm*1000 then
          local d=dist(c.position,f.rec.group:GetCoordinate())
          if d<=self.Config.CAP.engageRangeKm*1000 and d<dmin then best=f; dmin=d end
        end
      end
      if best then
        if owner then self:_release(owner); owner.rec.state="READY" end
        self:_intercept(best,c); assigned[c.groupname]=best
      end
    end
  end
  local qra=0; for _,f in pairs(self.flights) do if f.role=="QRA" then qra=qra+1 end end
  if now()>=self.nextQra then
    for _,c in ipairs(candidates) do
      if qra>=self.Config.QRA.maxFlights then break end
      if not assigned[c.groupname] then
        local rec=self:_select("QRA",nil,c)
        if rec then
          local f=self:_reserve(rec,"QRA",nil,c); f.deadline=f.alertAt+readiness
          assigned[c.groupname]=f; qra=qra+1
          log("QRA_ALERT "..rec.name.." target="..c.groupname.." airborneBy="..math.floor(f.deadline))
          if now()>=f.deadline-rec.settings.startupTaxiSec then self:_launch(f,c) end
        else
          self:_notice("qra-unavailable","QRA_UNAVAILABLE no eligible group for "..c.groupname)
          self.nextQra=now()+self.Config.QRA.retrySec
        end
      end
    end
  end
  -- New QRA reservations take precedence over new CAP allocations.
  if not self.capPlan then
    self:_applyCAPPlan(self:_drawCAPPlan(self.Config.CAP.count.min,self.Config.CAP.count.max),"operations start")
  end
  for _,name in ipairs(self.capZones) do
    local slot=self.slots[name]
    if slot and slot.active and not slot.flight and now()>=slot.nextLaunch then
      local rec=self:_select("CAP",slot)
      slot.nextLaunch=now()+self.Config.CAP.replacementDelaySec
      if rec then
        local f=self:_reserve(rec,"CAP",slot); self:_launch(f)
        if not f.ended and f.phase=="STARTING" then log("CAP_ASSIGN "..rec.name.." zone="..slot.name) end
      else self:_notice("cap:"..slot.name,"CAP_UNAVAILABLE "..slot.name) end
    end
  end
end

function R:SetCAPCount(n)
  return self:SetCAPRange(n,n)
end
function R:SetCAPRange(minimum,maximum)
  if not integer(minimum) or not integer(maximum) or not number(minimum,0,5) or not number(maximum,minimum,5) then
    log("CAP_CHANGE_REFUSED range must be integer 0 <= min <= max <= 5",true); return false
  end
  if not self.initialized or not self.capPlan then
    self.Config.CAP.count={min=minimum,max=maximum}
    log("CAP_RANGE "..minimum..".."..maximum.."; draw pending operations start"); return true
  end
  local ok,plan=pcall(self._drawCAPPlan,self,minimum,maximum)
  if not ok then log("CAP_CHANGE_REFUSED "..tostring(plan),true); return false end
  self.Config.CAP.count={min=minimum,max=maximum}
  self:_applyCAPPlan(plan,"manual range change"); return true
end
function R:Inventory()
  local ids={}; for id in pairs(self.catalogue) do ids[#ids+1]=id end; table.sort(ids)
  for _,id in ipairs(ids) do
    local item=self.catalogue[id]
    for _,prefix in ipairs({"AA","AG"}) do
      local named=item.prefixes[prefix]
      if named then
        log("INVENTORY "..prefix.."_"..id.." groups="..#named.groups.." aircraft="..named.airframes.." static="..named.static)
      end
    end
  end
  return UTILS.DeepCopy(self.catalogue)
end
function R:Status()
  local result={version=self.version,running=self.running,initialized=self.initialized,
    CAPcount=#self.capZones,CAPrange=UTILS.DeepCopy(self.Config.CAP.count),CAPzones=UTILS.DeepCopy(self.capZones),
    CAPrequested=self.capPlan and self.capPlan.requested,CAPselectedAt=self.capPlan and self.capPlan.selectedAt,
    CAPselectionPending=self.capPlan==nil,QRAseconds=self:_readiness(),sensors=nkeys(self.sensorNames),groups={}}
  log("CAP_STATUS range="..result.CAPrange.min..".."..result.CAPrange.max.." requested="..tostring(result.CAPrequested)
    .." selected="..result.CAPcount.." zones="..table.concat(result.CAPzones,",").." pending="..tostring(result.CAPselectionPending))
  for name,rec in pairs(self.records) do
    local f=rec.flight
    local item={squadron=rec.id,prefix=rec.prefix,state=rec.state,lost=nkeys(rec.dead),remaining=rec.originalSize-nkeys(rec.dead),
      role=f and f.role,phase=f and f.phase,zone=f and f.slot and f.slot.name,
      target=f and f.target,refuels=f and f.refuels,readyAt=rec.readyAt,taxiRecoveries=rec.taxiRecoveries or 0,
      readyInSec=math.max(0,math.ceil((rec.readyAt or 0)-now())),opsAttached=_DATABASE:GetOpsGroup(name)~=nil}
    result.groups[name]=item
    log("STATUS "..name.." "..rec.state.." phase="..tostring(item.phase).." remaining="..item.remaining.." lost="..item.lost
      .." readyInSec="..item.readyInSec.." opsAttached="..tostring(item.opsAttached))
  end
  return result
end
function R:TaxiStatus()
  local result={}
  for name,rec in pairs(self.records) do
    local f=rec.flight; local tx=f and f.taxi
    local item={state=rec.state,recoveries=rec.taxiRecoveries or 0,phase=f and f.phase,
      protected=tx and tx.protected,stuckUnit=tx and tx.stuckUnit,stuckSeconds=tx and tx.stuckSeconds,units={}}
    for uname,track in pairs(tx and tx.units or {}) do
      local u=physical(uname)
      if u then
        local p=u:getPoint()
        item.units[uname]={x=p.x,z=p.z,airborne=u:inAir(),speed=speed(u),idle=now()-track.lastProgress,moved=track.moved}
        log("TAXI_STATUS "..name.." unit="..uname.." idle="..math.floor(now()-track.lastProgress)
          .."s x="..math.floor(p.x).." z="..math.floor(p.z).." protected="..tostring(item.protected))
      end
    end
    result[name]=item
  end
  return result
end
function R:ParkingReport(baseName)
  local base=AIRBASE:FindByName(baseName)
  if not base or not self.taxiAvailable then log("PARKING_REPORT unknown base/API unavailable: "..tostring(baseName)); return {} end
  local result={}
  for _,p in pairs(base:GetParkingSpotsTable(AIRBASE.TerminalType.FighterAircraft) or {}) do
    result[#result+1]={id=p.TerminalID,type=p.TerminalType,free=p.Free,allocated=p.TOAC,client=p.ClientSpot,
      x=p.Coordinate.x,z=p.Coordinate.z,reserved=self.taxiParking[self:_taxiParkingKey(base,p.TerminalID)]}
  end
  table.sort(result,function(a,b) return a.id<b.id end)
  for _,p in ipairs(result) do
    log("PARKING "..baseName.." terminal="..p.id.." type="..p.type.." free="..tostring(p.free)
      .." allocated="..tostring(p.allocated).." client="..tostring(p.client).." x="..math.floor(p.x).." z="..math.floor(p.z))
  end
  return result
end
function R:RecoverTaxi(groupName,ignoreHold)
  local rec=self.records[groupName]
  local ok,done,why=pcall(self._recoverTaxi,self,rec and rec.flight,true,ignoreHold==true)
  if not ok then why=done; done=false end
  log("TAXI_MANUAL "..tostring(groupName).." accepted="..tostring(done==true).." "..tostring(why),not done)
  return done==true,why
end
function R:_schedule()
  self.epoch=self.epoch+1; local epoch=self.epoch
  if self.timerId then timer.removeFunction(self.timerId) end
  self.timerId=timer.scheduleFunction(function(_,t)
    if epoch~=R.epoch then return nil end
    if not R.initialized then
      if not R.running then R.timerId=nil; return nil end
      local ready,why=R:_dependencies()
      if not ready then
        R.attempts=R.attempts+1; log("DEPENDENCY "..why.." attempt="..R.attempts,true)
        if R.attempts>=R.Config.dependencyAttempts then R.running=false; R.timerId=nil; return nil end
        return t+R.Config.dependencyRetrySec
      end
      local ok,err=pcall(function() R:_init() end)
      if not ok then
        R.running=false; R.fatal=true; R.timerId=nil
        if R.intel then R.intel:Stop() end
        log("START_FAILED "..tostring(err),true); return nil
      end
    end
    local ok,err=pcall(function() R:_tick() end)
    if not ok then
      R.errors=R.errors+1; R.running=false
      log("CONTROLLER_ERROR "..tostring(err),true)
      -- Disable new launches; recover existing flights where possible.
      for _,f in pairs(R.flights) do pcall(function() R:_rtb(f,"controller error") end) end
      if R.errors>=3 then R.fatal=true; R.timerId=nil; return nil end
    end
    -- Inventory keeps running when manually stopped so ground losses are real.
    return t+R.Config.tickSec
  end,nil,now()+1)
end
function R:Start()
  if self.running then log("ALREADY_RUNNING"); return false end
  if self.fatal then log("Restart mission after correcting logged error",true); return false end
  if self.sensorFault then log("Restart mission after restoring original Skynet sensor bridge",true); return false end
  local ok,err=pcall(function() self:_validate() end)
  if not ok then log("CONFIG_ERROR "..tostring(err),true); return false end
  self.running=true; self.attempts=0; self:_schedule(); return true
end
function R:Stop()
  self.running=false
  local list={}; for _,f in pairs(self.flights) do list[#list+1]=f end
  for _,f in ipairs(list) do self:_rtb(f,"manual stop") end
  if self.sensorSet then
    for name in pairs(self.sensorNames) do self.sensorSet:RemoveGroupsByName({name}) end
    self.sensorNames={}
  end
  log("STOPPED; inventory monitoring continues")
end

log("LOADED; physical AA/AG squadrons / AA_CAP1..5 / operative AT tankers")
if CONFIG.autoStart then R:Start() end
