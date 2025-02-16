do
--create an instance of the IADS
redIADS = SkynetIADS:create('FIRSTCORPS')


--add all units with unit name beginning with 'EWR' to the IADS:
redIADS:addEarlyWarningRadarsByPrefix('FIRSTSBORKA')

--add all groups begining with group name 'IADS' to the IADS:
redIADS:addSAMSitesByPrefix('FIRSTAD')

--add a command center:
commandCenter = StaticObject.getByName('FIRSTCORPSCOMMANDCENTER')
redIADS:addCommandCenter(commandCenter)


--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('FIRSTCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('FIRSTSBORKA_SBORKA_1'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('FIRSTCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('FIRSTSBORKA_SBORKA_2'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('FIRSTCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('FIRSTSBORKA_SBORKA_3'):addConnectionNode(connectionNodeEW)

--activate the IADS
redIADS:activate()

end
