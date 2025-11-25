-- src/network/server.lua
-- ENet-based authoritative game server (non-blocking version)

local enet = require "enet"
local Protocol = require "src.network.protocol"
local ServerWorld = require "src.network.server_world"

local Server = {
    host = nil,
    port = 25565,
    running = false,
    tick = 0,
    accumulator = 0,
    clients = {},
    next_player_id = 1,
    next_network_id = 1,
    world = nil, -- Host's world (passed in)
    players = {} -- Map of player_id -> {entity, inputs}
}

function Server.start(port, host_world)
    if Server.running then
        print("Server: Already running")
        return false
    end

    if not host_world then
        print("ERROR: Server.start() requires a host_world parameter")
        return false
    end

    port = port or 12345

    print("Starting server on port " .. port)

    -- Create ENet host
    local host = enet.host_create("*:" .. port, 32, 2)

    if not host then
        print("ERROR: Failed to create ENet host on port " .. port)
        return false
    end

    Server.host = host
    Server.running = true
    Server.port = port
    Server.world = host_world -- Use the host's existing world!

    print("Server started successfully on port " .. port)
    print("Tick rate: " .. Protocol.TICK_RATE .. " Hz")
    print("Using host's world directly (shared world mode)")

    return true
end

function Server.stop()
    if not Server.running then
        return
    end

    print("Stopping server...")

    if Server.host then
        Server.host:flush()
        Server.host = nil
    end

    Server.running = false
    Server.world = nil
    Server.clients = {}
    Server.players = {}
    Server.tick = 0
    Server.accumulator = 0

    print("Server stopped")
end

function Server.update(dt)
    if not Server.running then
        return
    end

    -- Fixed timestep simulation
    -- Clamp dt to prevent spiral of death
    if dt > 0.1 then dt = 0.1 end
    Server.accumulator = Server.accumulator + dt

    while Server.accumulator >= Protocol.TICK_INTERVAL do
        Server.tick = Server.tick + 1

        -- NOTE: We don't call world:tick() here!
        -- The host's game loop (PlayState:update) already updates the world.
        -- We just broadcast the current state to clients.

        -- Broadcast world state
        local entities = Server.getWorldState()
        local server_time = love.timer.getTime()
        local packet = Protocol.createWorldStatePacket(Server.tick, entities, server_time)
        Server.broadcast(packet)

        Server.accumulator = Server.accumulator - Protocol.TICK_INTERVAL
    end

    -- Process network events
    Server.processEvents()
end

function Server.processEvents()
    if not Server.host then return end

    -- Service the ENet host (non-blocking)
    local ok, event = pcall(function()
        return Server.host:service(0)
    end)

    if not ok then
        print("Server: ENet service error: " .. tostring(event))
        return
    end

    while event do
        if event.type == "connect" then
            Server.onClientConnect(event.peer)
        elseif event.type == "receive" then
            Server.onClientReceive(event.peer, event.data)
        elseif event.type == "disconnect" then
            Server.onClientDisconnect(event.peer)
        end

        event = Server.host:service(0)
    end
end

function Server.onClientConnect(peer)
    local peer_id = peer:index()
    local player_id = Server.next_player_id
    Server.next_player_id = Server.next_player_id + 1

    print("Client connected: peer_id=" .. peer_id .. ", player_id=" .. player_id)

    -- Spawn player ship directly in the host's world
    local ShipSystem = require "src.ecs.spawners.ship"
    local spawn_x = 0
    local spawn_y = 0
    local ship = ShipSystem.spawn(Server.world, "starter_drone", spawn_x, spawn_y, false) -- false = not local player

    if ship then
        -- Assign network ID
        ship.network_id = Server.next_network_id
        Server.next_network_id = Server.next_network_id + 1

        -- Track player
        Server.players[player_id] = {
            entity = ship,
            inputs = { move_x = 0, move_y = 0, fire = false }
        }

        -- Mark as remote player (different color)
        if ship.render then
            ship.render.color = { 1, 0.5, 0.2 } -- Orange for remote players
        end

        print("Server: Spawned ship for player " .. player_id .. " at (" .. spawn_x .. ", " .. spawn_y .. ")")
    end

    -- Store client info
    Server.clients[peer_id] = {
        peer = peer,
        player_id = player_id
    }

    -- Send WELCOME packet to the new client
    local entity_id = (ship and ship.network_id) or 0
    local welcome_packet = Protocol.createWelcomePacket(player_id, entity_id)
    local welcome_data = Protocol.serialize(welcome_packet)
    peer:send(welcome_data, 0, "reliable")

    -- Broadcast PLAYER_JOINED to all clients (including the new one, for consistency)
    local packet = Protocol.createPlayerJoinedPacket(player_id, ship and ship.network_id or 0)
    Server.broadcast(packet)
end

function Server.onClientReceive(peer, data)
    local packet = Protocol.deserialize(data)
    if not packet then
        return
    end

    local peer_id = peer:index()
    local client = Server.clients[peer_id]

    if not client then
        return
    end

    -- Handle packet based on type
    if packet.type == Protocol.PacketType.INPUT then
        -- Process player input
        local player = Server.players[client.player_id]
        if player and player.entity and player.entity.input then
            -- Apply inputs to entity's input component
            player.entity.input.move_x = packet.move_x or 0
            player.entity.input.move_y = packet.move_y or 0
            player.entity.input.fire = packet.fire or false
            player.entity.input.target_angle = packet.angle or 0

            -- Store client position for accurate projectile spawning
            if packet.fire and packet.pos_x then
                player.entity.input.client_pos_x = packet.pos_x
                player.entity.input.client_pos_y = packet.pos_y
                player.entity.input.client_rotation = packet.rotation
            end
        end
    elseif packet.type == Protocol.PacketType.CHAT then
        -- Broadcast chat message to all clients
        print("Server: Chat from player " .. client.player_id .. ": " .. packet.message)
        local broadcast = Protocol.createChatBroadcastPacket(client.player_id, packet.message)
        Server.broadcast(broadcast)

        -- Notify Host (if callback set)
        if Server.onChatReceived then
            Server.onChatReceived(client.player_id, packet.message)
        end
    end
end

function Server.setChatCallback(fn)
    Server.onChatReceived = fn
end

function Server.onClientDisconnect(peer)
    local peer_id = peer:index()
    local client = Server.clients[peer_id]

    if client then
        print("Client disconnected: player_id=" .. client.player_id)

        -- Remove player entity from world
        local player = Server.players[client.player_id]
        if player and player.entity then
            player.entity:destroy()
        end
        Server.players[client.player_id] = nil

        -- Broadcast PLAYER_LEFT
        local packet = Protocol.createPlayerLeftPacket(client.player_id)
        Server.broadcast(packet)

        -- Remove from clients table
        Server.clients[peer_id] = nil
    end
end

-- Get world state snapshot for network transmission
-- Get world state snapshot for network transmission
function Server.getWorldState()
    local entities = {}

    -- Network culling: only send entities within range of players
    local NETWORK_RANGE = 2000 -- Only sync entities within 2000 units

    -- Get all player positions for culling
    local player_positions = {}
    for _, player_data in pairs(Server.players) do
        if player_data.entity and player_data.entity.transform then
            table.insert(player_positions, {
                x = player_data.entity.transform.x,
                y = player_data.entity.transform.y
            })
        end
    end

    -- Helper function to check if entity is near any player
    local function isNearAnyPlayer(entity)
        if not entity.transform then
            return false
        end

        for _, player_pos in ipairs(player_positions) do
            local dx = entity.transform.x - player_pos.x
            local dy = entity.transform.y - player_pos.y
            local dist_sq = dx * dx + dy * dy

            if dist_sq <= NETWORK_RANGE * NETWORK_RANGE then
                return true
            end
        end

        return false
    end

    -- Gather all networkable entities in the host's world
    for _, entity in ipairs(Server.world:getEntities()) do
        -- Always include player ships, cull other entities by distance
        local should_include = false

        if entity.vehicle then
            -- Always include player ships
            should_include = true
        elseif entity.projectile then
            -- Always include projectiles (they're fast-moving and important)
            should_include = true
        else
            -- For asteroids and other entities, use distance culling
            should_include = isNearAnyPlayer(entity)
        end

        if should_include and entity.network_id then
            local state = Protocol.createEntityState(entity)
            if state then
                table.insert(entities, state)
            end
        end
    end

    return entities
end

function Server.broadcast(packet)
    if not Server.host then return end

    local data = Protocol.serialize(packet)

    for peer_id, client in pairs(Server.clients) do
        client.peer:send(data, 0, "reliable")
    end
end

return Server
