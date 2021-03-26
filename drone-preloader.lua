local ok, err = xpcall(function()
    local port = 111

    drone = component.proxy(component.list("drone")())
    modem = component.proxy(component.list("modem")())
    modem.open(port)

    function send(...)
        modem.broadcast(port,...) --todo: make safe
    end

    function createPlainFilter(...)
        local pattern=table.pack(...)
        return function(...)
            local signal = table.pack(...)
                for i=1,pattern.n do
                    if pattern[i] and signal[i]~=pattern[i] then
                        return false
                    end
                end
            return true
        end
    end

    function pullEvent(filter, timeout)
        timeout = timeout or math.huge
        local startTime=computer.uptime()
        local signal
        repeat
            signal = table.pack(computer.pullSignal(timeout+startTime-computer.uptime()))
        until filter(table.unpack(signal, 1, signal.n)) or computer.uptime()-startTime>timeout

        if computer.uptime()-startTime>timeout and not filter(table.unpack(signal, 1, signal.n))then
            return nil
        end

        return table.unpack(signal, 1, signal.n)
    end

    send("drone_on")

    drone.setStatusText("")

    local program = "" do
        pullEvent(createPlainFilter("modem_message",modem.address,nil,port,nil,"program_start"))
        local _,_,_,_,_, msg, chunk = pullEvent(createPlainFilter("modem_message",modem.address,nil,port))
        drone.setStatusText(chunk and tostring(chunk) or "nil")
        while chunk do
            program = program..chunk
            local r = {pullEvent(createPlainFilter("modem_message",modem.address,nil,port))}
            msg = r[6]
            chunk = r[7]
        end
    end
    load(program)()
end,debug.traceback)
if not ok then
    send("drone_error", err)
    error(err)
end