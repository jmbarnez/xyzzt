local socket = require "socket"

local Client = {
    host = "localhost",
    port = 12345,
    connected = false,
    socket = nil,
    receiveCallback = nil
}

function Client.connect()
    local client = socket.tcp()
    client:settimeout(5) -- Timeout for connection
    local success, err = client:connect(Client.host, Client.port)
    if not success then
        print("Failed to connect to server: " .. err)
        return false, err
    end

    print("Connected to server!")
    client:settimeout(0) -- Non-blocking for receive
    Client.socket = client
    Client.connected = true
    return true
end

function Client.update(dt)
    if not Client.connected then return end

    local line, err = Client.socket:receive()
    if not err then
        if line and Client.receiveCallback then
            Client.receiveCallback(line)
        end
    elseif err ~= "timeout" then
        print("Network error: " .. err)
        Client.disconnect()
    end
end

function Client.send(message)
    if not Client.connected then return end

    local success, err = Client.socket:send(message .. "\n")
    if not success then
        print("Failed to send message: " .. err)
        Client.disconnect()
    end
end

function Client.disconnect()
    if Client.socket then
        Client.socket:close()
    end
    Client.connected = false
    Client.socket = nil
    if Client.receiveCallback then
        Client.receiveCallback("System: Disconnected from server.")
    end
end

function Client.setReceiveCallback(fn)
    Client.receiveCallback = fn
end

return Client
