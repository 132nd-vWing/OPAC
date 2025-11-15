do
--create an instance of the IADS
redIADS = SkynetIADS:create('SECONDCORPS')


--add all units with unit name beginning with 'EWR' to the IADS:
redIADS:addEarlyWarningRadarsByPrefix('SECONDSBORKA')

--add all groups begining with group name 'IADS' to the IADS:
redIADS:addSAMSitesByPrefix('SECONDAD')

--add a command center:
commandCenter = StaticObject.getByName('SECONDCORPSCOMMANDCENTER')
redIADS:addCommandCenter(commandCenter)


--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SECONDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('SECONDSBORKA_SBORKA_1'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SECONDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('SECONDSBORKA_SBORKA_2'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('SECONDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('SECONDSBORKA_SBORKA_3'):addConnectionNode(connectionNodeEW)

--activate the IADS
redIADS:activate()

end
