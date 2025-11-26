-- Procedural Enemy Generator
-- Generates basic enemy drones with AI

local ProceduralShip = require "src.utils.procedural_ship"
local EnemyBehaviors = require "src.ai.behaviors.enemy_behaviors"

local ProceduralEnemy = {}

-- Generate a basic enemy drone configuration
-- @param seed: Random seed for generation
-- @param base_level: Base level for the enemy (from sector difficulty)
-- @return enemy_config: Configuration table for spawning
function ProceduralEnemy.generate(seed, base_level)
    base_level = base_level or 1
    local rng = love.math.newRandomGenerator(seed)

    -- Generate level with some variation
    local level = base_level + rng:random(-1, 1)
    if level < 1 then level = 1 end

    -- Calculate level multiplier
    local level_mult = 1 + (level - 1) * 0.15

    -- Generate procedural ship appearance
    local ship_seed = seed + 12345
    local ship_data = ProceduralShip.generate(ship_seed)

    -- Base stats
    local base_hp = ship_data.max_hull or 100
    local base_shield = ship_data.max_shield or 50
    local base_speed = ship_data.max_speed or 500
    local base_thrust = ship_data.thrust or 1000

    -- Apply level scaling
    local hp = math.floor(base_hp * level_mult)
    local shield = math.floor(base_shield * level_mult)
    local max_speed = base_speed
    local thrust = base_thrust
    local detection_range = 800 -- Simple fixed detection range for now

    -- Red enemy color
    local color = { 1, 0.3, 0.3 }

    -- Always use basic drone behavior
    local behavior_tree = EnemyBehaviors.createBasicDrone()

    -- Create name
    local name = "Enemy Drone Lv." .. level

    return {
        -- Identity
        name = name,
        level = level,

        -- Ship appearance (from procedural generation)
        ship_data = ship_data,
        radius = ship_data.radius or 20,
        color = color,

        -- Stats
        max_hull = hp,
        max_shield = shield,
        shield_regen = 1 + level * 0.5,
        max_speed = max_speed,
        thrust = thrust,
        rotation_speed = ship_data.rotation_speed or 5,
        mass = ship_data.mass or 1,

        -- AI
        detection_range = detection_range,
        behavior_tree = behavior_tree,
    }
end

return ProceduralEnemy
