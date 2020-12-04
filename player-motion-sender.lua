local cx,cy,cz = -41+297, -58.62+57, 63+193

local component = require("component")
local event = require("event")

local navigation = component.navigation
local modem = component.modem
modem.open(111)

while true do
    local x,y,z = navigation.getPosition()
    print(x+cx,y+cy,z+cz)
    modem.broadcast(111,"player-motion",x+cx,y+cy+0.3,z+cz)
    os.sleep()
end