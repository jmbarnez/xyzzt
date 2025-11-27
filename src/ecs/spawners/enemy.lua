local ShipManager = require "src.ecs.spawners.ship"
local ProceduralEnemy = require "src.utils.procedural_enemy"
local Concord = require "lib.concord.concord"

local EnemySpawner = {}

-- Seeded random number generator for deterministic placement
local function createSeededRNG(seed)
    local rng = love.math.newRandomGenerator(seed)
    return rng
end

-- Generate a position that maintains minimum separation from existing positions
local function generateValidPosition(rng, existing_positions, min_distance, max_distance, min_separation)
    local max_attempts = 50

    for attempt = 1, max_attempts do
        -- Generate random angle and distance
        local angle = rng:random() * math.pi * 2
        local distance = min_distance + rng:random() * (max_distance - min_distance)

        local x = math.cos(angle) * distance
        local y = math.sin(angle) * distance

        -- Check separation from existing positions
        local valid = true
        for _, pos in ipairs(existing_positions) do
            local dx = x - pos.x
            local dy = y - pos.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < min_separation then
                valid = false
                break
            end
        end

        if valid then
            return x, y
        end
    end

    -- Fallback: return position even if separation isn't ideal
    local angle = rng:random() * math.pi * 2
    local distance = min_distance + rng:random() * (max_distance - min_distance)
    return math.cos(angle) * distance, math.sin(angle) * distance
end

-- Spawn a procedurally generated enemy
-- @param world: The Concord world
-- @param enemy_config: Configuration from ProceduralEnemy.generate()
-- @param x, y: Spawn position
-- @param sectorX, sectorY: Sector coordinates
-- @return entity: The spawned enemy entity
function EnemySpawner.spawnEnemy(world, enemy_config, x, y, sectorX, sectorY)
    if not (world and enemy_config) then
        return nil
    end

    local Server = nil
    local assign_network_ids = false
    if world.hosting then
        Server = require "src.network.server"
        assign_network_ids = true
    end

    -- Spawn ship using procedural ship data
    local enemy_ship = ShipManager.spawn(world, enemy_config.ship_data, x, y, false)

    if not enemy_ship then
        return nil
    end

    -- Set sector coordinates
    if enemy_ship.sector then
        enemy_ship.sector.x = sectorX or 0
        enemy_ship.sector.y = sectorY or 0
    end

    -- Override stats with enemy-specific values
    if enemy_ship.hull then
        enemy_ship.hull.max = enemy_config.max_hull
        enemy_ship.hull.current = enemy_config.max_hull
    end

    if enemy_ship.shield then
        enemy_ship.shield.max = enemy_config.max_shield
        enemy_ship.shield.current = enemy_config.max_shield
        enemy_ship.shield.regen = enemy_config.shield_regen
    end

    if enemy_ship.vehicle then
        enemy_ship.vehicle.max_speed = enemy_config.max_speed
        enemy_ship.vehicle.thrust = enemy_config.thrust
        enemy_ship.vehicle.turn_speed = enemy_config.rotation_speed
    end

    -- Set enemy color
    if enemy_ship.render then
        enemy_ship.render.color = enemy_config.color
    end

    -- Set enemy name
    enemy_ship:give("name", enemy_config.name)

    -- Add level scaling component
    enemy_ship:give("level_scaling", enemy_config.level)

    -- Add detection component
    enemy_ship:give("detection", enemy_config.detection_range)

    -- Add AI behavior tree
    enemy_ship:give("ai", enemy_config.behavior_tree)

    if assign_network_ids and Server then
        enemy_ship.network_id = Server.next_network_id
        Server.next_network_id = Server.next_network_id + 1
    end

    return enemy_ship
end

-- Spawn a field of enemy ships in a sector
-- @param world: The Concord world
-- @param sectorX: Sector X coordinate
-- @param sectorY: Sector Y coordinate
-- @param seed: Base universe seed
-- @param count: Number of enemy ships to spawn
-- @param config: Enemy ship configuration (optional, uses defaults if not provided)
function EnemySpawner.spawnField(world, sectorX, sectorY, seed, count, config)
    if not seed then
        seed = 12345 -- Fallback seed
    end

    -- Default configuration
    local cfg = config or {
        min_distance_from_origin = 1000,
        max_distance_from_origin = 4500,
        min_separation = 300,
    }

    -- Create a deterministic seed based on sector position and universe seed
    local sector_seed = seed + sectorX * 73856093 + sectorY * 19349663
    local rng = createSeededRNG(sector_seed)

    local positions = {}

    -- Calculate enemy level based on distance from origin (0,0)
    local sector_distance = math.sqrt(sectorX * sectorX + sectorY * sectorY)
    local base_level = 1 + math.floor(sector_distance / 2) -- Level increases every 2 sectors

    -- Spawn enemy ships
    for i = 1, count do
        local x, y = generateValidPosition(
            rng,
            positions,
            cfg.min_distance_from_origin,
            cfg.max_distance_from_origin,
            cfg.min_separation
        )

        -- Generate procedural enemy configuration
        local enemy_seed = sector_seed + i * 997
        local enemy_config = ProceduralEnemy.generate(enemy_seed, base_level)

        -- Spawn the enemy
        local enemy_ship = EnemySpawner.spawnEnemy(world, enemy_config, x, y, sectorX, sectorY)

        -- Track position for separation checks
        if enemy_ship then
            table.insert(positions, { x = x, y = y })
        end
    end
end

return EnemySpawner
