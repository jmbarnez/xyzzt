-- src/network/protocol.lua
-- Network protocol definitions and packet serialization

local bitser = require "lib.bitser"

local Protocol = {}

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
--- @return table packet
function Protocol.createInputPacket(tick, move_x, move_y, fire, angle)
    return {
        type = Protocol.PacketType.INPUT,
        tick = tick,
        move_x = move_x or 0,
        move_y = move_y or 0,
        fire = fire or false,
        angle = angle or 0
    }
end

--- Create a WORLD_STATE packet (Server -> Client)
--- @param tick number Server tick number
--- @param entities table Array of entity states
--- @return table packet
function Protocol.createWorldStatePacket(tick, entities)
    return {
        type = Protocol.PacketType.WORLD_STATE,
        tick = tick,
        entities = entities or {}
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

    return state
end

return Protocol
