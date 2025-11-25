-- src/network/client.lua
-- ENet-based game client

local enet = require "enet"
local Protocol = require "src.network.protocol"

local Client = {
    host = nil,
    peer = nil,
    server_address = "localhost",
    server_port = 25565,
    connected = false,
    connecting = false,
    tick = 0,
    player_id = nil,
    entity_id = nil,

    -- Callbacks
    onWorldState = nil,
    onPlayerJoined = nil,
    onPlayerLeft = nil,
    onWelcome = nil,
    onChatBroadcast = nil,
}

function Client.connect()
    print("Connecting to server " .. Client.server_address .. ":" .. Client.server_port)

    -- Create ENet host (client only needs 1 peer)
    local host = enet.host_create()

    if not host then
        print("ERROR: Failed to create ENet client host")
        return false
    end

    Client.host = host

    -- Initiate connection to server
    local peer = host:connect(Client.server_address .. ":" .. Client.server_port)

    if not peer then
        print("ERROR: Failed to initiate connection to server")
        Client.host = nil
        return false
    end

    Client.peer = peer
    Client.connecting = true
    Client.connected = false

    print("Connection initiated...")

    return true
end

function Client.update(dt)
    if not Client.host then return end

    Client.tick = Client.tick + 1

    -- Process network events (guard against ENet service errors)
    local ok, event = pcall(function()
        return Client.host:service(0) -- Non-blocking
    end)

    if not ok then
        print("Client: ENet service error: " .. tostring(event))
        return
    end

    while event do
        if event.type == "connect" then
            Client.onConnect(event.peer)
        elseif event.type == "receive" then
            Client.onReceive(event.peer, event.data)
        elseif event.type == "disconnect" then
            Client.onDisconnect(event.peer)
        end

        ok, event = pcall(function()
            return Client.host:service(0)
        end)

        if not ok then
            print("Client: ENet service error: " .. tostring(event))
            break
        end
    end
end

function Client.onConnect(peer)
    print("Connected to server!")
    Client.connected = true
    Client.connecting = false
end

function Client.onReceive(peer, data)
    local packet = Protocol.deserialize(data)

    if not packet then
        print("Client: Received invalid packet")
        return
    end

    -- Handle packet based on type
    if packet.type == Protocol.PacketType.WORLD_STATE then
        if Client.onWorldState then
            Client.onWorldState(packet)
        end
    elseif packet.type == Protocol.PacketType.PLAYER_JOINED then
        print("Player joined: player_id=" .. packet.player_id)
        if Client.onPlayerJoined then
            Client.onPlayerJoined(packet.player_id, packet.entity_id)
        end
    elseif packet.type == Protocol.PacketType.PLAYER_LEFT then
        print("Player left: player_id=" .. packet.player_id)
        if Client.onPlayerLeft then
            Client.onPlayerLeft(packet.player_id)
        end
    elseif packet.type == Protocol.PacketType.WELCOME then
        print("Received WELCOME: player_id=" .. packet.player_id .. ", entity_id=" .. tostring(packet.entity_id))
        Client.player_id = packet.player_id
        Client.entity_id = packet.entity_id
        if Client.onWelcome then
            Client.onWelcome(packet.player_id, packet.entity_id)
        end
    elseif packet.type == Protocol.PacketType.CHAT_BROADCAST then
        if Client.onChatBroadcast then
            Client.onChatBroadcast(packet.player_id, packet.message)
        end
    elseif packet.type == Protocol.PacketType.PONG then
        -- Handle ping response
    end
end

function Client.onDisconnect(peer)
    print("Disconnected from server")
    Client.connected = false
    Client.connecting = false
    Client.peer = nil
end

function Client.sendInput(move_x, move_y, fire, angle, pos_x, pos_y, rotation)
    if not Client.connected or not Client.peer then
        return
    end

    -- Include client timestamp for lag compensation
    local client_time = love.timer.getTime()
    local packet = Protocol.createInputPacket(Client.tick, move_x, move_y, fire, angle, client_time, pos_x, pos_y,
        rotation)
    local data = Protocol.serialize(packet)

    Client.peer:send(data, 0, "reliable") -- Channel 0, reliable delivery
end

function Client.sendChatMessage(message)
    if not Client.connected or not Client.peer then
        return
    end

    local packet = Protocol.createChatPacket(message)
    local data = Protocol.serialize(packet)

    Client.peer:send(data, 0, "reliable") -- Channel 0, reliable delivery
end

function Client.disconnect()
    if Client.peer then
        Client.peer:disconnect()
        -- Give time for disconnect to be sent
        if Client.host then
            Client.host:flush()
        end
    end

    Client.connected = false
    Client.connecting = false
    Client.peer = nil
    Client.host = nil
    Client.player_id = nil

    print("Client disconnected")
end

-- Callback setters
function Client.setWorldStateCallback(fn)
    Client.onWorldState = fn
end

function Client.setPlayerJoinedCallback(fn)
    Client.onPlayerJoined = fn
end

function Client.setPlayerLeftCallback(fn)
    Client.onPlayerLeft = fn
end

function Client.setWelcomeCallback(fn)
    Client.onWelcome = fn
end

function Client.setChatCallback(fn)
    Client.onChatBroadcast = fn
end

return Client
