local ShipManager = require "src.ecs.spawners.ship"
local ProceduralShip = require "src.utils.procedural_ship"

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
        ship_name = "starter_drone"
    }

    -- Create a deterministic seed based on sector position and universe seed
    local sector_seed = seed + sectorX * 73856093 + sectorY * 19349663
    local rng = createSeededRNG(sector_seed)

    local positions = {}

    -- Spawn enemy ships
    for i = 1, count do
        local x, y = generateValidPosition(
            rng,
            positions,
            cfg.min_distance_from_origin,
            cfg.max_distance_from_origin,
            cfg.min_separation
        )

        -- Spawn ship as non-player (will be colored red-ish as enemy)
        -- Generate a unique procedural ship for this enemy
        -- Use a unique seed for each ship based on its position/index
        local ship_seed = sector_seed + i * 997
        local ship_data = ProceduralShip.generate(ship_seed)

        local enemy_ship = ShipManager.spawn(world, ship_data, x, y, false)

        -- Set sector coordinates
        if enemy_ship and enemy_ship.sector then
            enemy_ship.sector.x = sectorX
            enemy_ship.sector.y = sectorY
        end

        -- Track position for separation checks
        table.insert(positions, { x = x, y = y })
    end
end

return EnemySpawner
