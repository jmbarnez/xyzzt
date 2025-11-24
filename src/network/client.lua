local socket = require "socket"

local Client = {
    host = "localhost",
    port = 12345,
    connected = false,
    socket = nil,
    receiveCallback = nil
}

function Client.connect()
    -- Start async connection attempt
    local client = socket.tcp()
    client:settimeout(0) -- Non-blocking from the start

    -- Attempt to connect (will return "timeout" if in progress)
    local success, err = client:connect(Client.host, Client.port)

    if success then
        -- Immediate connection (unlikely but possible on localhost)
        print("Connected to chat server!")
        Client.socket = client
        Client.connected = true
        return true
    elseif err == "timeout" then
        -- Connection in progress
        print("Connecting to chat server in background...")
        Client.socket = client
        Client.connected = false
        Client.connecting = true
        return true
    else
        -- Connection failed immediately
        print("Failed to connect to chat server: " .. tostring(err))
        client:close()
        return false, err
    end
end

function Client.update(dt)
    -- Handle async connection completion
    if Client.connecting and Client.socket then
        local success, err = Client.socket:connect(Client.host, Client.port)

        if success then
            print("Connected to chat server!")
            Client.connected = true
            Client.connecting = false
        elseif err ~= "timeout" and err ~= "already connected" then
            print("Chat server connection failed: " .. tostring(err))
            Client.socket:close()
            Client.socket = nil
            Client.connecting = false
        end
        -- If err == "timeout", keep trying
    end

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
    Client.connecting = false
    Client.socket = nil
    if Client.receiveCallback then
        Client.receiveCallback("System: Disconnected from server.")
    end
end

function Client.setReceiveCallback(fn)
    Client.receiveCallback = fn
end

return Client
