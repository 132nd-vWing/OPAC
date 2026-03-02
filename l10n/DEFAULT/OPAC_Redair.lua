
-- CAP active from Airbases --
local Redair_Debugging = false --change to false to silence the messages

-- at missions start there is a 50% chance that one or two CAP will be launched, per the table below.
-- You can comment out any entry in the table below if you dont want to launch CAP from it.


airfield_Cap_table = {
--"Andoya",
--"Banak",
--"Bardufoss",
--"Bodo",
--"Ivalo",
--"Jokkmokk",
--"Kalixfors",
--"Kallax",
--"Kemi_Tornio",
--"Kirkenes",
--"Kiruna",
--"Kittila",
--"Kuusamo",
--"Rovaniemi",
--"Vidsel",
--"Vuojarvi",

"Severomorsk-1",
"Severomorsk-3",
"Monchegorsk",
--"Murmansk_International",
"Olenya",

--"Alakourtti",
}
-- these are the airfields that will launch QRF fighters upon detection by Skynet. you can comment out as many as you want..
airfield_GCI_table = {
--"Andoya",
--"Banak",
--"Bardufoss",
--"Bodo",
--"Ivalo",
--"Jokkmokk",
--"Kalixfors",
--"Kallax",
--"Kemi_Tornio",
--"Kirkenes",
--"Kiruna",
--"Kittila",
--"Kuusamo",
--"Rovaniemi",
--"Vidsel",
--"Vuojarvi",

--"Severomorsk-1",
--"Severomorsk-3",
"Monchegorsk",
--"Murmansk_International",
"Olenya",

--"Alakourtti",

}

local function pickNumber() -- picks a random number of 1-4 with a weighting of 2 about 2/3rds of the time
  local choose = math.random(1,100)
  if choose < 1 then env.info("someone is a singleton") return 1
  elseif choose >=1 and choose < 98 then env.info("someone is a 2ship") return 2
  elseif choose >= 98 and choose < 99 then env.info("someone is a 3 ship") return 3
  elseif choose >= 99 then env.info("someone is a fourship") return 4
  end
end


-----------------------------------------------------------------------
-- CAP CONFIGURATION (Fixed Racetrack Parameters)
-----------------------------------------------------------------------

local CAP_ALTITUDE_FT = 25000
local CAP_SPEED_KTS   = 440      -- Mach 0.75 approx at 25,000 ft
local CAP_LEG_NM      = 20
local CAP_HDG_OUT     = 270
local CAP_HDG_IN      = 90

--- CAP



local number_of_CAP_Airfield = math.random(1,#airfield_Cap_table)
for i,_cap_airfield in ipairs(airfield_Cap_table) do
  if i == number_of_CAP_Airfield then
    CAP_Airfield1 = _cap_airfield
    table.remove(airfield_Cap_table,i)
  end
end
if CAP_Airfield1 then
  env.info(CAP_Airfield1.." has CAP enabled")
end

-- DETECTION SET (EWR)
DetectionSetGroup = SET_GROUP:New()
  :FilterCoalitions("red")
  :FilterCategories("ground")
  :FilterPrefixes("EWR")
  :FilterStart()
  
Detection = DETECTION_AREAS:New( DetectionSetGroup, 30000 ) --range in meters for targets to be grouped
A2ADispatcher = AI_A2A_DISPATCHER:New( Detection )
A2ADispatcher:SetEngageRadius() -- 100000 is the default value. Set 100km as the radius to engage any target by airborne friendlies.
A2ADispatcher:SetGciRadius() -- 200000 is the default value. Set 200km as the radius to ground control intercept.

CCCPBorderZone = ZONE_POLYGON:New( "ColdBorder", GROUP:FindByName( "ColdBorder" ) )
A2ADispatcher:SetBorderZone( CCCPBorderZone )
A2ADispatcher:SetDisengageRadius( 185000 )--important to stop caps drifting 460km is 250nm, and covers coast from Shiraz to a bit east of Abbas
A2ADispatcher:SetEngageRadius(120000) --everything inside 200km from the aircraft is handled by the CAP
A2ADispatcher:SetTacticalDisplay( Redair_Debugging )
A2ADispatcher:SetDefaultCapTimeInterval( 900, 1200 ) --between 15mins and 20mins  NECK: DAY 900, 1200  NIGHT: 1700,1900
A2ADispatcher:SetDefaultFuelThreshold( 0.3 ) -- % including tanks before heading to refuel. Note refuel is on INTERNAL max only for AI.



if CAP_Airfield1 then
  A2ADispatcher:SetSquadron(CAP_Airfield1,CAP_Airfield1,("Cap_"..CAP_Airfield1))
  A2ADispatcher:SetSquadronGrouping(CAP_Airfield1,pickNumber())
  --A2ADispatcher:SetSquadronOverhead( CAP_Airfield1, 1 )
  A2ADispatcher:SetSquadronTakeoffFromParkingHot(CAP_Airfield1)
  A2ADispatcher:SetSquadronLandingAtRunway(CAP_Airfield1)
  A2ADispatcher:SetSquadronCap(
	CAP_Airfield1,
	ZONE:New("Cap_"..CAP_Airfield1),
	CAP_ALTITUDE_FT, CAP_ALTITUDE_FT,   -- Fixed altitude
	CAP_SPEED_KTS, CAP_SPEED_KTS,       -- Fixed patrol speed
	400, 1000,
	"BARO"
)	
  A2ADispatcher:SetSquadronCapInterval( CAP_Airfield1, 1, 15*60, 20*60 ) -- only one CAP ever, between 15mins and 20mins
  A2ADispatcher:SetSquadronCapRacetrack(
	CAP_Airfield1,
	UTILS.NMToMeters(CAP_LEG_NM),
	UTILS.NMToMeters(CAP_LEG_NM),
	CAP_HDG_OUT,
	CAP_HDG_IN,
	nil,
	nil,
	ZONE:New("Cap_"..CAP_Airfield1):GetCoordinate()
)
  A2ADispatcher:SchedulerCAP(CAP_Airfield1)
end

local number_of_CAPs = math.random(1,2) --randomly have 1 or 2 airfields launching CAP
if number_of_CAPs == 2 then
  local number_of_CAP_Airfield = math.random(1,#airfield_Cap_table)
  for i,_cap_airfield in ipairs(airfield_Cap_table) do
    if i == number_of_CAP_Airfield then
      CAP_Airfield2 = _cap_airfield
      env.info(CAP_Airfield2.." has second CAP enabled")
      A2ADispatcher:SetSquadron(CAP_Airfield2,CAP_Airfield2,("Cap_"..CAP_Airfield2))
      A2ADispatcher:SetSquadronGrouping(CAP_Airfield2,pickNumber())
      --A2ADispatcher:SetSquadronOverhead( CAP_Airfield2, 1 )
      A2ADispatcher:SetSquadronTakeoffFromParkingHot(CAP_Airfield2)
      A2ADispatcher:SetSquadronLandingAtRunway(CAP_Airfield2)
  A2ADispatcher:SetSquadronCap(
	CAP_Airfield2,
	ZONE:New("Cap_"..CAP_Airfield2),
	CAP_ALTITUDE_FT, CAP_ALTITUDE_FT,   -- Fixed altitude
	CAP_SPEED_KTS, CAP_SPEED_KTS,       -- Fixed patrol speed
	400, 1000,
	"BARO"
)
      A2ADispatcher:SetSquadronCapInterval( CAP_Airfield2, 1, 15*60, 20*60 ) -- only one CAP ever, between 15mins and 20mins
	A2ADispatcher:SetSquadronCapRacetrack(
		CAP_Airfield2,
		UTILS.NMToMeters(CAP_LEG_NM),
		UTILS.NMToMeters(CAP_LEG_NM),
		CAP_HDG_OUT,
		CAP_HDG_IN,
		nil,
		nil,
		ZONE:New("Cap_"..CAP_Airfield2):GetCoordinate()
)
      A2ADispatcher:SchedulerCAP(CAP_Airfield2)
    end
  end
end

-----------------------------------------------------------------------
-- CAP RACETRACK RETURN WATCHDOG
--
-- Purpose:
-- Ensures CAP flights return to their defined racetrack pattern
-- when they are no longer actively engaging enemy aircraft.
--
-- Behavior:
-- - If hostile aircraft are detected within a defined radius,
--   the dispatcher is allowed to control the CAP normally.
-- - If no hostiles are nearby, the racetrack pattern is re-applied.
--
-- This allows:
--   ✔ Dynamic interception when tracks exist (Skynet + Dispatcher)
--   ✔ Proper racetrack orbit when idle
-----------------------------------------------------------------------

-- Distance (in meters) within which enemy aircraft count as "active engagement"
local WATCHDOG_HOSTILE_CHECK_RADIUS = 80000  -- 80 km

-- How often (seconds) the watchdog checks CAP groups
local WATCHDOG_INTERVAL = 60


-- Function: Re-apply racetrack if CAP group is idle
local function PushRacetrackIfIdle(squadronName)

  -- Get squadron object from dispatcher
  local squad = A2ADispatcher:GetSquadron(squadronName)
  if not squad then return end

  -- Get active CAP groups belonging to this squadron
  local capSet = squad.CAPSet
  if not capSet then return end

  capSet:ForEachGroupAlive(function(grp)

    -- Only process airborne aircraft
    if not grp:InAir() then return end

    local coord = grp:GetCoordinate()
    if not coord then return end

    -------------------------------------------------------------------
    -- Check for nearby hostile aircraft
    -------------------------------------------------------------------

    local hostileNearby = false

    -- Adjust coalition filter if needed (blue/red depending on your mission)
    local hostileSet = SET_GROUP:New()
      :FilterCoalitions("blue")   -- Change if your CAP is blue
      :FilterCategoryAirplane()
      :FilterStart()

    hostileSet:ForEachGroupAlive(function(enemyGrp)
      if hostileNearby then return end

      local enemyCoord = enemyGrp:GetCoordinate()
      if enemyCoord then
        local distance = coord:Get2DDistance(enemyCoord)
        if distance < WATCHDOG_HOSTILE_CHECK_RADIUS then
          hostileNearby = true
        end
      end
    end)

    -- If hostiles are nearby, do nothing (dispatcher controls intercept)
    if hostileNearby then
      return
    end

    -------------------------------------------------------------------
    -- No nearby hostiles → re-apply racetrack pattern
    -------------------------------------------------------------------

    A2ADispatcher:SetSquadronCapRacetrack(
  squadronName,
  UTILS.NMToMeters(CAP_LEG_NM),
  UTILS.NMToMeters(CAP_LEG_NM),
  CAP_HDG_OUT,
  CAP_HDG_IN,
  nil,
  nil,
  ZONE:New("Cap_" .. squadronName):GetCoordinate()
)

  end)
end


-----------------------------------------------------------------------
-- Scheduler: Runs watchdog every WATCHDOG_INTERVAL seconds
-----------------------------------------------------------------------

SCHEDULER:New(nil,
  function()

    if CAP_Airfield1 then
      PushRacetrackIfIdle(CAP_Airfield1)
    end

    if CAP_Airfield2 then
      PushRacetrackIfIdle(CAP_Airfield2)
    end

  end,
{},
WATCHDOG_INTERVAL,
WATCHDOG_INTERVAL
)



--- CAP


--- QRA
for i,_gci_airfield in ipairs(airfield_GCI_table) do
  A2ADispatcher:SetSquadron( _gci_airfield,_gci_airfield,("Cap_".._gci_airfield),2)
  A2ADispatcher:SetSquadronGrouping(_gci_airfield,pickNumber())
  A2ADispatcher:SetSquadronTakeoffFromParkingHot( _gci_airfield )
  A2ADispatcher:SetSquadronLandingAtEngineShutdown( _gci_airfield )
  A2ADispatcher:SetSquadronGci(_gci_airfield,600,1200) -- NECK: Day 600, 1200  Night 2100, 2700
  env.info(_gci_airfield.." has QRF enabled")
end

