local username = "hohserg"
local port = 111
local cx,cy,cz = -41+297, -58.62+57, 63+193

local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local computer = require("computer")

local glasses = component.glasses
glasses.removeAll()
glasses.startLinking(username)
local navigation = component.navigation
local modem = component.modem
modem.open(port)

local function send(...)
    --print("test1")
    modem.broadcast(port,...) --todo: make safe
    --print("test2")
end


local baseInventory = {__index={
    setItem = function(self, index, stack)
        self.inv[index]=stack
        self.glInv[index].setItem(stack.name, stack.damage)
    end,
    slotIterator = function(self) local index = 0 return function() index=index+1; if index<=self.inv.n then return index, self.inv[index] else return nil end end end
}}

local function getPositionOfSlot(slotIndex,w,h) return (slotIndex - 1) % w + 1, (slotIndex - 1) // w + 1 end

local function inventory(sx,sy, w, h, size)
    size = size or w*h
    local glInv = {}
    for i=1, size do
        local x,y = getPositionOfSlot(i,w,h)
        local glBox = glasses.addBox2D()
        glBox.addTranslation(sx+ x*18 +1,sy+ y*18 +1, 0)
        glBox.setSize(16,16)
        glBox.addColor(1,1,1, 0.5)
        glBox.addColor(1,1,1, 0.5)
        local glItem = glasses.addItem2D()
        --glItem.setItem("minecraft:apple")
        glItem.addScale(16,16,16)
        glItem.addTranslation((sx+x*18+1)/16,(sy+y*18+1)/16,0)
        glInv[i]=glItem
    end
    return setmetatable({w=w, h=h, size = size, inv = {}, glInv = glInv},baseInventory)
end

local droneInventory = inventory(10,10, 4,2)


local eh1=event.listen("modem_message",function(_,receiverAddress, senderAddress, receiverPort, distance, msg,...)
    if receiverAddress==modem.address and receiverPort==port then
        if msg=="drone_on" then
            print("drone_on")
            local h,err = filesystem.open("/home/drone-follower.lua","r")
            if not h then print(err) end
            local r=""
            send("program_start")
            while r do
                r=h:read(tonumber(computer.getDeviceInfo()[modem.address].capacity)-4)
                if r then
                    send("program_chunk",r)
                end
            end
            send("program_end")
        elseif msg=="drone_error" then
            print(...)
        elseif msg=="drone_ready" then
            print("drone ready")
        elseif msg=="drone_inv_update" then
            local index = select(1,...)
            local name = select(2,...)
            local damage = select(3,...)
            droneInventory:setItem(index,{name=name, damage=damage})
        end
    end
end)

local eh2=event.listen("chat_message",function(_,_,playerName,msg)
    if playerName==username then
        if msg:find("stay here") then
            send("stay_here")
            
        elseif msg:find("come on") then
            send("come_on")
            
        elseif msg:find("get")==1 then
            send("get_item",msg:sub(("get "):len()+1))
        end
    end
end)

local running=true

eh3 = event.listen("key_down",function(_,_,c) 
    if string.char(c)=="r" or string.char(c)=="к" then
        event.cancel(eh1)
        event.cancel(eh2)
        event.cancel(eh3)
        running=false
    end
end)

while running do
    local x,y,z = navigation.getPosition()
    --print(x+cx,y+cy,z+cz)
    send("player-motion",x+cx,y+cy+0.3,z+cz)
    os.sleep()
end