-- src/network/server_world.lua
-- Server-side authoritative world simulation

local Concord = require "lib.concord.concord"
local Config = require "src.config"
local Protocol = require "src.network.protocol"

-- System Imports
local MovementSystem = require "src.ecs.systems.core.movement"
local PhysicsSystem = require "src.ecs.systems.core.physics"
local CollisionSystem = require "src.ecs.systems.core.collision"
local WeaponSystem = require "src.ecs.systems.gameplay.weapon"
local ProjectileSystem = require "src.ecs.systems.gameplay.projectile"
local DeathSystem = require "src.ecs.systems.gameplay.death"
local LootSystem = require "src.ecs.systems.gameplay.loot"
local AsteroidChunkSystem = require "src.ecs.systems.gameplay.asteroid_chunk"
local ItemPickupSystem = require "src.ecs.systems.gameplay.item_pickup"
local TrailSystem = require "src.ecs.systems.visual.trail"

-- Component registration
require "src.ecs.components"

local ServerWorld = {}

function ServerWorld.new()
    local self = {
        world = nil,
        players = {}, -- Map of player_id -> {entity, inputs}
        next_network_id = 1,
        accumulator = 0
    }

    -- Create ECS world
    self.world = Concord.world()

    -- Initialize physics (threads should have love.physics available)
    if not (love and love.physics and love.physics.newWorld) then
        error("ServerWorld: love.physics is not available! Threads need physics module enabled.")
    end

    self.world.physics_world = love.physics.newWorld(0, 0, true)

    -- Add server-side systems (no rendering systems!)
    self.world:addSystems(
        MovementSystem,
        PhysicsSystem,
        CollisionSystem,
        WeaponSystem,
        ProjectileSystem,
        DeathSystem,
        LootSystem,
        AsteroidChunkSystem,
        ItemPickupSystem,
        TrailSystem
    )

    print("ServerWorld: Created authoritative world simulation")

    return setmetatable(self, { __index = ServerWorld })
end

--- Spawn a player's ship
function ServerWorld:spawnPlayer(player_id)
    local ShipSystem = require "src.ecs.spawners.ship"

    -- Spawn all players at origin so they can see each other
    local spawn_x = 0
    local spawn_y = 0

    local ship = ShipSystem.spawn(self.world, "starter_drone", spawn_x, spawn_y, true)

    if ship then
        -- Assign network ID
        ship.network_id = self.next_network_id
        self.next_network_id = self.next_network_id + 1

        -- Track player
        self.players[player_id] = {
            entity = ship,
            inputs = { move_x = 0, move_y = 0, fire = false }
        }

        print("ServerWorld: Spawned ship for player " .. player_id .. " at (" .. spawn_x .. ", " .. spawn_y .. ")")

        return ship
    else
        print("ServerWorld: ERROR - Failed to spawn ship for player " .. player_id)
        return nil
    end
end

--- Remove a player's ship
function ServerWorld:removePlayer(player_id)
    local player = self.players[player_id]
    if player and player.entity then
        -- Destroy the entity
        player.entity:destroy()
        self.players[player_id] = nil
        print("ServerWorld: Removed player " .. player_id)
    end
end

--- Update player inputs
function ServerWorld:updatePlayerInput(player_id, move_x, move_y, fire, angle)
    local player = self.players[player_id]
    if not player then
        print("ServerWorld: WARNING - Received input for unknown player " .. player_id)
        return
    end

    -- Store inputs
    player.inputs.move_x = move_x
    player.inputs.move_y = move_y
    player.inputs.fire = fire
    player.inputs.angle = angle

    -- Apply inputs to entity's input component
    local entity = player.entity
    if entity and entity.input then
        entity.input.move_x = move_x
        entity.input.move_y = move_y
        entity.input.fire = fire
        entity.input.target_angle = angle
    end
end

--- Simulate one tick of the world
function ServerWorld:tick(dt)
    -- Accumulate time and step physics at fixed rate
    self.accumulator = self.accumulator + dt
    local fixed_dt = 1 / 60

    while self.accumulator >= fixed_dt do
        self.world:emit("update", fixed_dt)
        self.accumulator = self.accumulator - fixed_dt
    end
end

--- Get world state snapshot for network transmission
function ServerWorld:getWorldState()
    local entities = {}

    -- Gather all networkable entities
    for _, entity in ipairs(self.world:getEntities()) do
        local state = Protocol.createEntityState(entity)
        if state then
            table.insert(entities, state)
        end
    end

    return entities
end

--- Get player's entity ID
function ServerWorld:getPlayerEntityId(player_id)
    local player = self.players[player_id]
    if player and player.entity then
        return player.entity.network_id
    end
    return nil
end

return ServerWorld
