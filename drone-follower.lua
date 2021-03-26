local cx,cy,cz = -41+297, -58.62+57, 63+193
local port = 111

local navigation = component.proxy(component.list("navigation")())
local drone = component.proxy(component.list("drone")())
local inventory_controller = component.proxy(component.list("inventory_controller")())

drone.select(drone.inventorySize())

local sides={up=1}

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

local posList = {}
local current=prepare({currentPos()})

local   follow_player,
        stay_here
        = 0,1
    

local actionQueue = {}
local state = follow_player

local shulkersCount = 0
local arity = 1
local inv = {}

local shulkerSize = 9*3

local function getSlotLocationFunction(shulkerCount)
    local lowArityCapcity = math.pow(shulkerSize,arity-1)
    local topArityShulkerCount = (shulkerCount-1)%27
    local topArityMaxIndex = topArityShulkerCount*27
    local getForArity = function(virtualSlot, arity)
        local r = {}
        local i = virtualSlot-1
        local curArity = arity
        while curArity>=0 do
            local curGCubeSize = math.pow(27,curArity)
            table.insert(r,i//curGCubeSize + 1)
            curArity = curArity-1
            i = i%curGCubeSize    
        end
        return r
    end
    
    return function(virtualSlot)
        if virtualSlot<topArityMaxIndex then
            return getForArity(virtualSlot, arity)
        else
            return getForArity(virtualSlot, arity-1)
        end
    end
end

local function isShulkerLike(stack)
    return stack.name:find("shulker_box") -- or stack.name:find("some_backpack")

end

local function setupInvScan()
    drone.select(8)
    for i=1,8 do
        local stack = inventory_controller.getStackInInternalSlot(i)
        if stack then
            if isShulkerLike(stack) then
                discoverShulker(i)
            end
        end
    end
end

local function dropAllToUp()
    for i=1,drone.inventorySize() do
        drone.select(i)
        drone.drop(sides.up)
    end
end

local function scanShulkers(side)
    local r = {}
    for i=1, inv.getInventorySize(side) do
        if isShulkerLike(inv.getStackInSlot(side)) then
            table.insert(r,i)
        end        
    end
    return r
end

local function suckShulkers7(shulkerLocation,side)
    drone.select(1)
    local shulkerFreeSlotsCount = (drone.getInventorySize() - #shulkerLocation)
    inv = {n = shulkerFreeSlotsCount + 9*3*#shulkerLocation}
    for k,i in ipairs(shulkerLocation) do
        inv.suckFromSlot(side,i)
    end
end

local function prepareShulkerInv(side)
    local shulkerLocation = scanShulkers(side)
    if #isShulkerLike==0 then
        invArity=0
    elseif #shulkerLocation<=7 then
        suckShulkers7(shulkerLocation,side)
        invArity=1
    elseif #shulkerLocation<=168 then
        suckShulkers6(shulkerLocation,side)
        invArity=2
    elseif #shulkerLocation<=3785 then
        suckShulkers5(shulkerLocation,side)
        invArity=3
    else
        error("unsupported shulker count")
    end
    
    suckOtherItems(side)
end


local function pullPlayerPathAndCommands(_, _, _, _, _, msg,x,y,z)
    if msg=="player-motion" then
        local last = posList[#posList]
        local next = prepare({x,y,z})
        
        if not last or not equals(last, next) then
            table.insert(posList,next)
        end
        
    elseif msg=="stay_here" then
        state = stay_here
        
    elseif msg=="come_on" then
        state = follow_player
        
    elseif msg=="prepare_shulker_inv" then
        dropAllToUp()
        prepareShulkerInv()
    
    elseif msg=="get_item" then
        extractItem(x)
    end
end

local function pullInventoryChange(_, slot)
    --updateInvSlot(slot)
end


local standardFilter = createPlainFilter(nil,modem.address,nil,port)

local function pullEvents()
    local r = table.pack(pullEvent(standardFilter,1))
    if r[1]=="modem_message" then
        pullPlayerPathAndCommands(table.unpack(r))
    --elseif r[1]=="inventory_changed" then
    --    pullInventoryChange(table.unpack(r))
    end
end

local moveSleepTime = 0
local moveSleepStart = 0
local accelerated = false

local function moveByPath()
    if computer.uptime()>=moveSleepStart+moveSleepTime then
        if state==follow_player and #posList>0 then --continue motion
            local next = table.remove(posList,1)
            local dcx,dcy,dcz = table.unpack(current)
            current=next
            local dx,dy,dz = round(next[1]-dcx),round(next[2]-dcy),round(next[3]-dcz)
            
            --[[
                accelerationS = v0*t+a*t*t/2
                v0 = 0
                accelerationS = a*t*t/2
                a = 2 //max acceleration
                V = 8 //max velocity
                accelerationTime = V/a = 4
                accelerationS = a*accelerationTime*accelerationTime/2
                accelerationS = 2*4*4/2 = 16
                
                uniformS = fullS - accelerationS
                uniformS = V*uniformT
                uniformT = uniformS/V
            ]]
            local s = math.sqrt(dx*dx+dy*dy+dz*dz)
            if s > 0.01 then
                moveSleepTime=s/8 --simple time calc, considered that drone speed is 8
                moveSleepStart=computer.uptime()
            end
            
            drone.move(dx,dy,dz)
            accelerated=true
            
        else --stop
            accelerated=false
        end
    end
end


local function sub(v1,v2)
    return {v1[1]-v2[1],v1[2]-v2[2],v1[3]-v2[3]}
end
local function cosVecAngle(v1,v2)
    local scalar = v1[1]*v2[1]+v1[2]*v2[2]+v1[3]*v2[3]
    local v1Len = math.sqrt(v1[1]*v1[1]+v1[2]*v1[2]+v1[3]*v1[3])
    local v2Len = math.sqrt(v2[1]*v2[1]+v2[2]*v2[2]+v2[3]*v2[3])
    return scalar/(v1Len*v2Len)
end
local function optimizePath()
    if #posList>3 then
        local c1,c2,c3, v1,v2
        for i = #posList, 3, -1 do
            c1 = posList[i]
            c2 = posList[i-1]
            c3 = posList[i-2]
            v1 = sub(c1,c2)
            v2 = sub(c3,c2)
            if cosVecAngle(v1,v2) < -0.994 then
                table.remove(posList, i-1)
            end
        end
    end
end


local tick = 0
local function trackPathAndCorrentPos()
    tick=tick+1
    if tick>=3 then
        tick=0
        local dcx,dcy,dcz = currentPos()
        modem.broadcast(111,"drone-motion",dcx,dcy,dcz)
        
        if #posList==0 and current and drone.getVelocity()==0 then
            local x,y,z = table.unpack(current)
            drone.move((x-dcx),(y-dcy),(z-dcz))
        end
    end
end

send("drone_ready")


while true do
    
    pullEvents()
    
    moveByPath()
    
    optimizePath()
    
    trackPathAndCorrentPos()
    
end 