local port = 111
local cx,cy,cz = -41+297, -58.62+57, 63+193

local component = require("component")
local event = require("event")
local filesystem = require("filesystem")

local navigation = component.navigation
local modem = component.modem
modem.open(port)

local function send(...)
    modem.broadcast(port,...) --todo: make safe
end

while true do
    send("ping")
    local _, _, senderAddress = event.pull("modem_message",modem.address,_,port,_,"pong") --todo: make safe
    if senderAddress then
        local h = filesystem.open("/home/drone-follower.lua","r")
        local r=""
        while r do
            r=h:read(modem.maxPacketSize()-4)
            if r then
                print("program_chunk")
                send("program_chunk",r)
            end
        end
        print("program_end")
        send("program_end")
        break
    end
end

while true do
    local x,y,z = navigation.getPosition()
    print(x+cx,y+cy,z+cz)
    send("player-motion",x+cx,y+cy+0.3,z+cz)
    os.sleep()
end