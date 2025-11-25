-- src/network/protocol.lua
-- Network protocol definitions and packet serialization

local bitser = require "lib.bitser"

local Protocol = {}
local debugPrintedAsteroids = {}

-- Network Configuration
Protocol.TICK_RATE = 20 -- Server updates per second (20Hz = 50ms per tick)
Protocol.TICK_INTERVAL = 1.0 / Protocol.TICK_RATE

-- Packet Type Enumeration
Protocol.PacketType = {
    -- Client -> Server
    INPUT = 1,
    PING = 2,
    CHAT = 3, -- New: Chat message

    -- Server -> Client
    WORLD_STATE = 10,
    PLAYER_JOINED = 11,
    PLAYER_LEFT = 12,
    PONG = 13,
    WELCOME = 14,
    CHAT_BROADCAST = 15, -- New: Server broadcasting chat
}

-- Packet Constructors

--- Create a CHAT packet (Client -> Server)
--- @param message string The chat message
--- @return table packet
function Protocol.createChatPacket(message)
    return {
        type = Protocol.PacketType.CHAT,
        message = message
    }
end

--- Create a CHAT_BROADCAST packet (Server -> Client)
--- @param player_id number The ID of the sender
--- @param message string The message content
--- @return table packet
function Protocol.createChatBroadcastPacket(player_id, message)
    return {
        type = Protocol.PacketType.CHAT_BROADCAST,
        player_id = player_id,
        message = message
    }
end

--- Create a WELCOME packet (Server -> Client)
--- @param player_id number Network ID
--- @param entity_id number Entity ID in the world
--- @return table packet
function Protocol.createWelcomePacket(player_id, entity_id)
    return {
        type = Protocol.PacketType.WELCOME,
        player_id = player_id,
        entity_id = entity_id
    }
end

--- Create an INPUT packet (Client -> Server)
--- @param tick number Client tick number
--- @param move_x number Movement X (-1, 0, 1)
--- @param move_y number Movement Y (-1, 0, 1)
--- @param fire boolean Is firing
--- @param angle number Target angle for aiming
--- @param client_time number Client timestamp when input was created
--- @param pos_x number Client's ship X position (for shooting)
--- @param pos_y number Client's ship Y position (for shooting)
--- @param rotation number Client's ship rotation
--- @return table packet
function Protocol.createInputPacket(tick, move_x, move_y, fire, angle, client_time, pos_x, pos_y, rotation)
    return {
        type = Protocol.PacketType.INPUT,
        tick = tick,
        move_x = move_x or 0,
        move_y = move_y or 0,
        fire = fire or false,
        angle = angle or 0,
        client_time = client_time or 0,
        pos_x = pos_x,
        pos_y = pos_y,
        rotation = rotation
    }
end

--- Create a WORLD_STATE packet (Server -> Client)
--- @param tick number Server tick number
--- @param entities table Array of entity states
--- @param server_time number Server timestamp (optional, defaults to love.timer.getTime())
--- @return table packet
function Protocol.createWorldStatePacket(tick, entities, server_time)
    return {
        type = Protocol.PacketType.WORLD_STATE,
        tick = tick,
        entities = entities or {},
        server_time = server_time or (love.timer and love.timer.getTime() or 0)
    }
end

--- Create a PLAYER_JOINED packet (Server -> Client)
--- @param player_id number Network ID
--- @param entity_id number Entity ID in the world
--- @return table packet
function Protocol.createPlayerJoinedPacket(player_id, entity_id)
    return {
        type = Protocol.PacketType.PLAYER_JOINED,
        player_id = player_id,
        entity_id = entity_id
    }
end

--- Create a PLAYER_LEFT packet (Server -> Client)
--- @param player_id number Network ID
--- @return table packet
function Protocol.createPlayerLeftPacket(player_id)
    return {
        type = Protocol.PacketType.PLAYER_LEFT,
        player_id = player_id
    }
end

--- Serialize a packet to binary data
--- @param packet table Packet to serialize
--- @return string Binary data
function Protocol.serialize(packet)
    return bitser.dumps(packet)
end

--- Deserialize binary data to a packet
--- @param data string Binary data
--- @return table|nil Packet or nil on error
function Protocol.deserialize(data)
    local success, packet = pcall(bitser.loads, data)
    if success then
        return packet
    else
        print("Protocol: Failed to deserialize packet: " .. tostring(packet))
        return nil
    end
end

--- Create an entity state snapshot for network transmission
--- @param entity table ECS entity
--- @return table|nil Entity state or nil if not networkable
function Protocol.createEntityState(entity)
    -- Only sync entities with transform, sector, and a network ID
    if not (entity.transform and entity.sector and entity.network_id) then
        return nil
    end

    local state = {
        id = entity.network_id,
        x = entity.transform.x,
        y = entity.transform.y,
        r = entity.transform.r or 0,
        sx = entity.sector.x,
        sy = entity.sector.y,
    }

    -- Add velocity if physics component exists
    if entity.physics and entity.physics.body then
        local vx, vy = entity.physics.body:getLinearVelocity()
        state.vx = vx
        state.vy = vy

        -- Add angular velocity for rotating entities (asteroids)
        local angular_vel = entity.physics.body:getAngularVelocity()
        if angular_vel and angular_vel ~= 0 then
            state.angular_velocity = angular_vel
        end
    end

    -- Add entity type tag
    if entity.vehicle then
        state.type = "vehicle"
    elseif entity.asteroid then
        state.type = "asteroid"
    elseif entity.asteroid_chunk then
        state.type = "asteroid_chunk"
    elseif entity.projectile then
        state.type = "projectile"
    end

    -- Add HP if exists
    if entity.hp then
        state.hp_current = entity.hp.current
        state.hp_max = entity.hp.max
    end

    -- Add rendering properties for asteroids and projectiles
    if entity.render then
        if state.type == "asteroid" or state.type == "asteroid_chunk" then
            state.radius = entity.render.radius
            state.color = entity.render.color

            -- Add vertices for shape synchronization (clamped to Box2D 8-vertex limit)
            if entity.render.vertices then
                local verts = entity.render.vertices
                print("[SERVER] Asteroid " ..
                tostring(entity.network_id) .. " has vertices table with " .. tostring(#verts) .. " coords")
                if type(verts) == "table" and #verts >= 6 and (#verts % 2 == 0) then
                    local maxCoords = 8 * 2 -- Box2D maximum: 8 vertices => 16 coordinates
                    local count = #verts
                    if count > maxCoords then count = maxCoords end

                    -- Serialize to string to bypass any table serialization issues
                    local v_str = ""
                    for i = 1, count do
                        v_str = v_str .. string.format("%.2f", verts[i])
                        if i < count then
                            v_str = v_str .. ","
                        end
                    end
                    state.vertices_str = v_str
                    print("[SERVER] Serialized vertices_str: " .. v_str:sub(1, 50) .. "...")
                else
                    print("PROTOCOL WARNING: Asteroid " ..
                    tostring(entity.network_id) .. " has invalid vertices: " .. tostring(verts))
                end
            else
                print("[SERVER] Asteroid " .. tostring(entity.network_id) .. " MISSING render.vertices!")
            end

            -- Add generation seed if available (for deterministic generation)
            if state.type == "asteroid" then
                if entity.asteroid and entity.asteroid.seed then
                    state.seed = entity.asteroid.seed
                end
            elseif state.type == "asteroid_chunk" then
                if entity.render.seed then
                    state.seed = entity.render.seed
                end
            end
        elseif state.type == "projectile" then
            state.radius = entity.render.radius
            state.color = entity.render.color
            state.length = entity.render.length
            state.thickness = entity.render.thickness
            state.shape = entity.render.shape
        end
    end

    -- Add damage and owner for projectiles
    if state.type == "projectile" and entity.projectile then
        state.damage = entity.projectile.damage
        state.lifetime = entity.projectile.lifetime

        -- Track owner network ID if available so clients can avoid self-collision visuals
        if entity.projectile.owner and entity.projectile.owner.network_id then
            state.owner_id = entity.projectile.owner.network_id
        end
    end

    return state
end

return Protocol
