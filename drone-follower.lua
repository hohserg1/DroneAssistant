local cx,cy,cz = -41+297, -58.62+57, 63+193
local port = 111

local navigation = component.proxy(component.list("navigation")())
local drone = component.proxy(component.list("drone")())

local function currentPos()
    local x,y,z = navigation.getPosition()
    return x+cx,y+cy,z+cz
end

local function equals(v1,v2)
    return v1[1]==v2[1] and v1[2]==v2[2] and v1[3]==v2[3] 
end

math.round = function(value)
    if value - math.floor(value) >= 0.5 then
        return math.ceil(value)
    else
        return math.floor(value)    
    end
end

local function round(value)
    return (math.round(value * 4) / 4)
end

local function prepare(v)
    return {round(v[1]),round(v[2]),round(v[3])}
end

local posList = {prepare({currentPos()})}

local   follow_player,
        stay_here
        = 0,1
    

local actionQueue = {}
local state = follow_player
local tick = 0

while true do
    local event_name, receiverAddress, senderAddress, receiverPort, distance, msg,x,y,z = computer.pullSignal(0)
    if event_name=="modem_message" and receiverAddress==modem.address and receiverPort==port and msg=="player-motion" then
    
        local last = posList[#posList]
        local current = prepare({x,y,z})
        
        if not equals(last, current) then
            table.insert(posList,current)
            --local dcx,dcy,dcz = currentPos()
            drone.move(round(x-last[1]),round(y-last[2]),round(z-last[3]))
        end
    end
    
    tick=tick+1
    if tick>=3 then
        tick=0
        modem.broadcast(111,"drone-motion",currentPos())
    end
    
    
    --[[if drone.getOffset() < 0.01 and drone.getVelocity()==0 then
        table.insert(posList,{currentPos()})
    end]]
    --[[
    if drone.getOffset() < 0.01 and drone.getVelocity()==0 then
        if #posQueue>0 then
            local nextTarget = table.remove(posQueue,1)
            local nx,ny,nz = nextTarget[1],nextTarget[2],nextTarget[3]
            local cx,cy,cz = currentTarget[1],currentTarget[2],currentTarget[3]
            drone.move(nx-cx,ny-cy,nz-cz)
            currentTarget = nextTarget
        end
    end]]
end