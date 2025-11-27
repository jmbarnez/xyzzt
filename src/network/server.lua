-- src/network/server.lua
-- ENet-based authoritative game server (non-blocking version)

local enet = require "enet"
local Protocol = require "src.network.protocol"

local MAX_INPUTS_PER_SECOND = 120
local CHAT_WINDOW_SECONDS = 2.0
local MAX_CHAT_PER_WINDOW = 6

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
    players = {}, -- Map of player_id -> {entity, inputs, display_name}
    last_sent_states = {}
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
    Server.last_sent_states = {}

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
        local entities, removed_ids = Server.getWorldState()
        local server_time = love.timer.getTime()
        local packet = Protocol.createWorldStatePacket(Server.tick, entities, server_time, removed_ids)
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

        if not Server.host then
            return
        end

        ok, event = pcall(function()
            return Server.host:service(0)
        end)

        if not ok then
            print("Server: ENet service error: " .. tostring(event))
            return
        end
    end
end

function Server.onClientConnect(peer)
    local peer_id = peer:index()
    local player_id = Server.next_player_id
    Server.next_player_id = Server.next_player_id + 1

    -- Client connected: peer_id and player_id assigned

    -- Spawn player ship directly in the host's world
    local ShipSystem = require "src.ecs.spawners.ship"
    local spawn_x = 0
    local spawn_y = 0
    local ship = ShipSystem.spawn(Server.world, "starter_drone", spawn_x, spawn_y, false) -- false = not local player

    if ship then
        -- Assign network ID
        ship.network_id = Server.next_network_id
        Server.next_network_id = Server.next_network_id + 1

        -- Track player (display_name filled in once we receive PLAYER_INFO)
        Server.players[player_id] = {
            entity = ship,
            entity_id = ship.network_id,
            inputs = { move_x = 0, move_y = 0, fire = false },
            display_name = nil,
        }

        -- Mark as remote player (different color)
        if ship.render then
            ship.render.color = { 1, 0.5, 0.2 } -- Orange for remote players
        end

        -- Ship spawned for player
    end

    -- Store client info
    Server.clients[peer_id] = {
        peer = peer,
        player_id = player_id,
        input_window_start = 0,
        input_count = 0,
        chat_window_start = 0,
        chat_count = 0
    }

    -- Send WELCOME packet to the new client
    local entity_id = (ship and ship.network_id) or 0
    local welcome_packet = Protocol.createWelcomePacket(player_id, entity_id)
    local welcome_data = Protocol.serialize(welcome_packet)
    peer:send(welcome_data, 0, "reliable")

    -- Send a full world snapshot to the new client so they see all entities
    if Server.world then
        local entities = Server.getFullWorldState()
        local server_time = love.timer.getTime()
        local world_packet = Protocol.createWorldStatePacket(Server.tick, entities, server_time)
        local world_data = Protocol.serialize(world_packet)
        peer:send(world_data, 0, "reliable")
    end

    -- Broadcast PLAYER_JOINED to all clients (including the new one, for consistency)
    local player_count = 0
    for _ in pairs(Server.clients) do
        player_count = player_count + 1
    end
    if Server.world then
        player_count = player_count + 1 -- Count the host
    end
    local packet = Protocol.createPlayerJoinedPacket(player_id, ship and ship.network_id or 0, player_count)
    Server.broadcast(packet)

    if Server.onPlayerJoined then
        Server.onPlayerJoined(player_id, player_count)
    end
end

function Server.respawnPlayer(player_id)
    if not Server.world then return end

    local player = Server.players[player_id]
    if not player then return end

    -- Don't respawn if they already have a ship that isn't destroyed
    if player.entity and player.entity:isValid() then
        return
    end

    local ShipSystem = require "src.ecs.spawners.ship"
    local ship = ShipSystem.spawn(Server.world, "starter_drone", 0, 0, false)

    if ship then
        ship.network_id = Server.next_network_id
        Server.next_network_id = Server.next_network_id + 1

        player.entity = ship
        player.entity_id = ship.network_id

        if ship.render then
            ship.render.color = { 1, 0.5, 0.2 }
        end

        if player.display_name then
            if ship.name then
                ship.name.value = player.display_name
            else
                ship:give("name", player.display_name)
            end
        end

        local client = nil
        for _, c in pairs(Server.clients) do
            if c.player_id == player_id then
                client = c
                break
            end
        end

        if client then
            local respawn_packet = Protocol.createPlayerRespawnedPacket(ship.network_id)
            local data = Protocol.serialize(respawn_packet)
            client.peer:send(data, 0, "reliable")
        end
    end
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
        local now = love.timer.getTime()
        local window_start = client.input_window_start or 0
        if (now - window_start) > 1.0 then
            client.input_window_start = now
            client.input_count = 0
        end
        client.input_count = (client.input_count or 0) + 1
        if client.input_count > MAX_INPUTS_PER_SECOND then
            return
        end

        local move_x = packet.move_x or 0
        if move_x < -1 then move_x = -1 elseif move_x > 1 then move_x = 1 end
        local move_y = packet.move_y or 0
        if move_y < -1 then move_y = -1 elseif move_y > 1 then move_y = 1 end

        local player = Server.players[client.player_id]
        if player and player.entity and player.entity.input then
            player.entity.input.move_x = move_x
            player.entity.input.move_y = move_y
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
        local now = love.timer.getTime()
        local window_start = client.chat_window_start or 0
        if (now - window_start) > CHAT_WINDOW_SECONDS then
            client.chat_window_start = now
            client.chat_count = 0
        end
        client.chat_count = (client.chat_count or 0) + 1
        if client.chat_count > MAX_CHAT_PER_WINDOW then
            return
        end

        local broadcast = Protocol.createChatBroadcastPacket(client.player_id, packet.message)
        Server.broadcast(broadcast)

        -- Notify Host (if callback set)
        if Server.onChatReceived then
            Server.onChatReceived(client.player_id, packet.message)
        end
    elseif packet.type == Protocol.PacketType.PLAYER_INFO then
        local name = packet.name
        if type(name) ~= "string" or name == "" then
            name = "Player " .. tostring(client.player_id)
        end

        client.display_name = name

        local player = Server.players[client.player_id]
        if player then
            player.display_name = name
            local ship = player.entity
            if ship and ship.vehicle then
                if ship.name then
                    ship.name.value = name
                else
                    ship:give("name", name)
                end
            end
        end

        -- Broadcast this player info to all connected clients
        local info_packet = Protocol.createPlayerInfoPacket(client.player_id, name)
        local info_data = Protocol.serialize(info_packet)
        for _, c in pairs(Server.clients) do
            c.peer:send(info_data, 0, "reliable")
        end
    elseif packet.type == Protocol.PacketType.PING then
        local client_time = packet.client_time or 0
        local pong = Protocol.createPongPacket(client_time, love.timer.getTime())
        local data = Protocol.serialize(pong)
        peer:send(data, 0, "unreliable")
    elseif packet.type == Protocol.PacketType.REQUEST_RESPAWN then
        Server.respawnPlayer(client.player_id)
    end
end

function Server.setChatCallback(fn)
    Server.onChatReceived = fn
end

function Server.setPlayerJoinedCallback(fn)
    Server.onPlayerJoined = fn
end

function Server.setPlayerLeftCallback(fn)
    Server.onPlayerLeft = fn
end

function Server.onClientDisconnect(peer)
    local peer_id = peer:index()
    local client = Server.clients[peer_id]

    if client then
        -- Client disconnected

        -- Remove player entity from world
        local player = Server.players[client.player_id]
        if player and player.entity then
            player.entity:destroy()
        end
        Server.players[client.player_id] = nil

        -- Remove from clients table before counting
        Server.clients[peer_id] = nil

        -- Compute current player count (all connected clients + host, if present)
        local player_count = 0
        for _ in pairs(Server.clients) do
            player_count = player_count + 1
        end
        if Server.world then
            player_count = player_count + 1 -- Count the host
        end

        -- Broadcast PLAYER_LEFT
        local packet = Protocol.createPlayerLeftPacket(client.player_id, player_count)
        Server.broadcast(packet)

        if Server.onPlayerLeft then
            Server.onPlayerLeft(client.player_id, player_count)
        end
    end
end

local function hasEntityStateChanged(prev, cur)
    if not prev then return true end

    local function diff(a, b, eps)
        if a == nil or b == nil then
            return a ~= b
        end
        return math.abs(a - b) > (eps or 0)
    end

    if diff(prev.x, cur.x, 0.5) or diff(prev.y, cur.y, 0.5) or diff(prev.r, cur.r, 0.01) then
        return true
    end

    if diff(prev.vx, cur.vx, 0.5) or diff(prev.vy, cur.vy, 0.5) then
        return true
    end

    if prev.sx ~= cur.sx or prev.sy ~= cur.sy then
        return true
    end

    if prev.hp_current ~= cur.hp_current or prev.hp_max ~= cur.hp_max then
        return true
    end

    if prev.type ~= cur.type then
        return true
    end

    return false
end

-- Full world state snapshot (used for new clients)
function Server.getFullWorldState()
    local entities = {}
    local NETWORK_RANGE = 2000

    local player_positions = {}
    for _, player_data in pairs(Server.players) do
        if player_data.entity and player_data.entity.transform then
            table.insert(player_positions, {
                x = player_data.entity.transform.x,
                y = player_data.entity.transform.y
            })
        end
    end

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

    for _, entity in ipairs(Server.world:getEntities()) do
        local should_include = false

        if entity.vehicle then
            should_include = true
        elseif entity.projectile then
            should_include = true
        else
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

-- Get world state snapshot for network transmission
function Server.getWorldState()
    local entities = {}
    local new_states = {}
    local removed_ids = {}

    local NETWORK_RANGE = 2000

    local player_positions = {}
    for _, player_data in pairs(Server.players) do
        if player_data.entity and player_data.entity.transform then
            table.insert(player_positions, {
                x = player_data.entity.transform.x,
                y = player_data.entity.transform.y
            })
        end
    end

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

    for _, entity in ipairs(Server.world:getEntities()) do
        local should_include = false

        if entity.vehicle then
            should_include = true
        elseif entity.projectile then
            should_include = true
        else
            should_include = isNearAnyPlayer(entity)
        end

        if should_include and entity.network_id then
            local state = Protocol.createEntityState(entity)
            if state then
                new_states[state.id] = state
                local prev = Server.last_sent_states[state.id]
                if hasEntityStateChanged(prev, state) then
                    table.insert(entities, state)
                end
            end
        end
    end

    -- Anything we previously sent but is no longer in range / no longer exists
    for id, _ in pairs(Server.last_sent_states) do
        if not new_states[id] then
            table.insert(removed_ids, id)
        end
    end

    Server.last_sent_states = new_states
    return entities, removed_ids
end

function Server.broadcast(packet)
    if not Server.host then return end

    local data = Protocol.serialize(packet)

    local flag = "reliable"
    if packet.type == Protocol.PacketType.WORLD_STATE then
        flag = "unreliable"
    end

    for peer_id, client in pairs(Server.clients) do
        client.peer:send(data, 0, flag)
    end
end

return Server
