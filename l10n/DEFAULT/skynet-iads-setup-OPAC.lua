do
--create an instance of the IADS
redIADS = SkynetIADS:create('NOTIA')


---debug settings remove from here on if you do not wan't any output on what the IADS is doing by default
local iadsDebug = redIADS:getDebugSettings()
iadsDebug.IADSStatus = true
iadsDebug.radarWentDark = true
iadsDebug.contacts = true
iadsDebug.radarWentLive = true
iadsDebug.noWorkingCommmandCenter = true
iadsDebug.samNoConnection = true
iadsDebug.jammerProbability = true
iadsDebug.addedEWRadar = true
iadsDebug.harmDefence = true
---end remove debug ---


--add all units with unit name beginning with 'EWR' to the IADS:
redIADS:addEarlyWarningRadarsByPrefix('EWR')

--add all groups begining with group name 'IADS' to the IADS:
redIADS:addSAMSitesByPrefix('IADS')

--add a command center:
commandCenter = StaticObject.getByName('ADCC')
redIADS:addCommandCenter(commandCenter)


-- Warm up SAM sites in the IADS
redIADS:setupSAMSitesAndThenActivate()

-- EWR CONNECTION NODES

--EWR CONNECTION TO SECTOR COMMAND CENTER - NORTH
--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_1'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar :
local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_2'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_3'):addConnectionNode(connectionNodeEW)

local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_4'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar :
local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_5'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC NORTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_NORTH_6'):addConnectionNode(connectionNodeEW)


-- EWR CONNECTION TO SECTOR COMMAND CENTER - SOUTH
--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC SOUTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_SOUTH_1'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC SOUTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_SOUTH_2'):addConnectionNode(connectionNodeEW)

----add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SCC SOUTH')
redIADS:getEarlyWarningRadarByUnitName('EWR_SOUTH_3'):addConnectionNode(connectionNodeEW)




-- POINT DEFENCE
-- POINT DEFENCE SECTOR NORTH
-- SA-2 Rybachy peninsula
local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD1_SA15_1')
redIADS:getSAMSiteByGroupName('IADS_NORTH _8011_SA2_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD1_SA15_2')
redIADS:getSAMSiteByGroupName('IADS_NORTH _8011_SA2_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD1_SA15_3')
redIADS:getSAMSiteByGroupName('IADS_NORTH _8011_SA2_BN'):addPointDefence(sa15)

-- SA-5 
local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD2_SA15_1')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8001_SA5_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD2_SA15_2')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8001_SA5_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD2_SA15_3')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8001_SA5_BN'):addPointDefence(sa15)


-- SA-10 
redIADS:getSAMSiteByGroupName('IADS_NORTH_8291_SA10_BN'):setEngagementZone(SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE):setGoLiveRangeInPercent(170)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD3_SA15_1')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8291_SA10_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD3_SA15_2')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8291_SA10_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD3_SA15_3')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8291_SA10_BN'):addPointDefence(sa15)


-- SA-2 ivo MURMANSK
--set this SA-2 site to go live at maximunm search range (default is at maximung firing range):
redIADS:getSAMSiteByGroupName('IADS_NORTH_8111_SA2_BN'):setEngagementZone(SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE):setGoLiveRangeInPercent(170)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD4_SA15_1')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8111_SA2_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD4_SA15_2')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8111_SA2_BN'):addPointDefence(sa15)

local sa15 = redIADS:getSAMSiteByGroupName('IADS_NORTH_PD4_SA15_3')
redIADS:getSAMSiteByGroupName('IADS_NORTH_8111_SA2_BN'):addPointDefence(sa15)




--activate the IADS
redIADS:activate()

--Moose integration
DetectionSetGroup = SET_GROUP:New()
redIADS:addMooseSetGroup(DetectionSetGroup)


end
