do
--create an instance of the IADS
redIADS = SkynetIADS:create('THIRDCORPS')


--add all units with unit name beginning with 'EWR' to the IADS:
redIADS:addEarlyWarningRadarsByPrefix('THIRDSBORKA')

--add all groups begining with group name 'IADS' to the IADS:
redIADS:addSAMSitesByPrefix('THIRDAD')

--add a command center:
commandCenter = StaticObject.getByName('THIRDCORPSCOMMANDCENTER')
redIADS:addCommandCenter(commandCenter)


--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('THIRDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('THIRDSBORKA_SBORKA_1'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('THIRDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('THIRDSBORKA_SBORKA_2'):addConnectionNode(connectionNodeEW)

--add a power source and a connection node for this EW radar:
local connectionNodeEW = StaticObject.getByName('THIRDCORPSCOMMANDCENTER')
redIADS:getEarlyWarningRadarByUnitName('THIRDSBORKA_SBORKA_3'):addConnectionNode(connectionNodeEW)

--activate the IADS
redIADS:activate()

end
