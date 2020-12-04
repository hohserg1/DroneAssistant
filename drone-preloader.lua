local port = 111

drone = component.proxy(component.list("drone")())
modem = component.proxy(component.list("modem")())
modem.open(port)

function send(...)
    modem.broadcast(port,...) --todo: make safe
end

local function check(filter, r)
    if filter.n <= r.n then
        for i=1,filter.n do
            if filter[i] and filter[i]~=r[i] then
                --drone.setStatusText(tostring(filter[i]).."\n"..tostring(r[i]))
                return false
            end    
        end
    end
    return true
end

function eventPull(timeout, ...)
    local filter = table.pack(...)
    local endTime = computer.uptime()+timeout
    while computer.uptime()<endTime do
        local r = table.pack(computer.pullSignal(endTime-computer.uptime()))
        if check(filter,r) then
            return table.unpack(r)
        end     
    end
    return nil
end

drone.setStatusText("")
local program = "" do
    eventPull(math.huge,"modem_message",modem.address,_,port,_,"ping")
    send("pong")
    local _,_,_,_,_, msg, chunk = eventPull(math.huge,"modem_message",modem.address,nil,port)
    drone.setStatusText(chunk or "nil")
    while chunk do
        program = program..chunk
        drone.setStatusText("test1")
        local r = {eventPull(math.huge,"modem_message",modem.address,nil,port)}
        drone.setStatusText("test2")
        msg = r[6]
        chunk = r[7]
    end
end
load(program)()