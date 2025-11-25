-- src/network/embedded_server.lua
-- Manages an embedded server running in a separate thread

local EmbeddedServer = {
    thread = nil,
    channel_in = nil,
    channel_out = nil,
    running = false
}

-- Thread code runs the server in a separate Lua state
local server_thread_code = [[
-- Set up paths for the thread (threads have separate Lua states)
local function extend_paths()
    local folder = love.filesystem.getSource()
    local additions = {
        "src/?.lua",
        "src/?/init.lua",
        "lib/?.lua",
        "lib/?/init.lua",
        "lib/?/?.lua"
    }

    local final_path = package.path
    for _, add in ipairs(additions) do
        final_path = final_path .. ";" .. folder .. "/" .. add
    end
    package.path = final_path
end

extend_paths()

-- Now require modules
local enet = require "enet"
local Protocol = require "src.network.protocol"

-- IMPORTANT: Register all components before loading ServerWorld
-- (Concord components must be registered in each Lua state)
require "src.ecs.components"

-- local ServerWorld = require "src.network.server_world"

local channel_in = love.thread.getChannel("server_in")
local channel_out = love.thread.getChannel("server_out")

local Server = {
    host = nil,
    port = 12345,
    running = false,
    tick = 0,
    accumulator = 0,
    clients = {},
    next_player_id = 1,
    world = nil
}

-- Copy server logic here (simplified for thread)
function Server.start(port)
    Server.port = port or 12345
    local host = enet.host_create("*:" .. Server.port, 32, 2)

    if not host then
        channel_out:push({type = "error", message = "Failed to bind port " .. Server.port})
        return
    end

    Server.host = host
    Server.running = true
    -- Server.world = ServerWorld.new() -- TODO: Re-implement server world logic

    channel_out:push({type = "started", port = Server.port})

    local last_time = love.timer.getTime()

    while Server.running do
        -- Check for stop command
        local cmd = channel_in:pop()
        if cmd == "stop" then
            Server.running = false
            break
        end

        local current_time = love.timer.getTime()
        local dt = current_time - last_time
        last_time = current_time

        Server.accumulator = Server.accumulator + dt

        while Server.accumulator >= Protocol.TICK_INTERVAL do
            Server.tick = Server.tick + 1
            -- Simulate and broadcast
            Server.world:tick(Protocol.TICK_INTERVAL)
            local entities = Server.world:getWorldState()
            local packet = Protocol.createWorldStatePacket(Server.tick, entities)

            local data = Protocol.serialize(packet)
            for peer_id, client in pairs(Server.clients) do
                client.peer:send(data, 0, "reliable")
            end

            Server.accumulator = Server.accumulator - Protocol.TICK_INTERVAL
        end

        -- Process network events
        local event = Server.host:service(0)
        while event do
            if event.type == "connect" then
                local peer_id = event.peer:index()
                local player_id = Server.next_player_id
                Server.next_player_id = Server.next_player_id + 1

                local ship = Server.world:spawnPlayer(player_id)
                Server.clients[peer_id] = {peer = event.peer, player_id = player_id}

                local packet = Protocol.createPlayerJoinedPacket(player_id, ship and ship.network_id or nil)
                local data = Protocol.serialize(packet)
                for _, client in pairs(Server.clients) do
                    client.peer:send(data, 0, "reliable")
                end

                channel_out:push({type = "player_joined", player_id = player_id})
            elseif event.type == "receive" then
                local packet = Protocol.deserialize(event.data)
                if packet and packet.type == Protocol.PacketType.INPUT then
                    local peer_id = event.peer:index()
                    local client = Server.clients[peer_id]
                    if client then
                        Server.world:updatePlayerInput(client.player_id, packet.move_x or 0, packet.move_y or 0, packet.fire or false)
                    end
                end
            elseif event.type == "disconnect" then
                local peer_id = event.peer:index()
                local client = Server.clients[peer_id]
                if client then
                    Server.world:removePlayer(client.player_id)
                    Server.clients[peer_id] = nil
                    channel_out:push({type = "player_left", player_id = client.player_id})
                end
            end
            event = Server.host:service(0)
        end

        love.timer.sleep(0.001)
    end

    if Server.host then
        Server.host:flush()
    end

    channel_out:push({type = "stopped"})
end

-- Start server
Server.start()
]]

function EmbeddedServer.start(port)
    if EmbeddedServer.running then
        print("EmbeddedServer: Already running")
        return false
    end

    port = port or 12345

    -- Create communication channels
    EmbeddedServer.channel_in = love.thread.getChannel("server_in")
    EmbeddedServer.channel_out = love.thread.getChannel("server_out")

    -- Clear channels
    EmbeddedServer.channel_in:clear()
    EmbeddedServer.channel_out:clear()

    -- Create and start thread
    EmbeddedServer.thread = love.thread.newThread(server_thread_code)
    EmbeddedServer.thread:start()
    EmbeddedServer.running = true

    print("EmbeddedServer: Starting on port " .. port)

    return true
end

function EmbeddedServer.stop()
    if not EmbeddedServer.running then
        return
    end

    print("EmbeddedServer: Stopping...")

    if EmbeddedServer.channel_in then
        EmbeddedServer.channel_in:push("stop")
    end

    if EmbeddedServer.thread then
        EmbeddedServer.thread:wait()
    end

    EmbeddedServer.running = false
    EmbeddedServer.thread = nil

    print("EmbeddedServer: Stopped")
end

function EmbeddedServer.update()
    if not EmbeddedServer.running then
        return
    end

    -- Check for messages from server thread
    if EmbeddedServer.channel_out then
        local msg = EmbeddedServer.channel_out:pop()
        while msg do
            if msg.type == "started" then
                print("EmbeddedServer: Started on port " .. msg.port)
            elseif msg.type == "error" then
                print("EmbeddedServer ERROR: " .. msg.message)
                EmbeddedServer.running = false
            elseif msg.type == "player_joined" then
                print("EmbeddedServer: Player " .. msg.player_id .. " joined")
            elseif msg.type == "player_left" then
                print("EmbeddedServer: Player " .. msg.player_id .. " left")
            elseif msg.type == "stopped" then
                print("EmbeddedServer: Thread stopped")
                EmbeddedServer.running = false
            end
            msg = EmbeddedServer.channel_out:pop()
        end
    end
end

return EmbeddedServer
