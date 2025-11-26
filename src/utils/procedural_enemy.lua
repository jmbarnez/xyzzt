-- Procedural Enemy Generator
-- Generates varied enemy types with different stats, behaviors, and appearances

local ProceduralShip = require "src.utils.procedural_ship"
local EnemyBehaviors = require "src.ai.behaviors.enemy_behaviors"

local ProceduralEnemy = {}

-- Enemy class definitions with stat modifiers
local ENEMY_CLASSES = {
    scout = {
        name = "Scout",
        -- Small, fast, low HP, medium detection range
        size_mult = 0.7,
        speed_mult = 1.5,
        hp_mult = 0.6,
        damage_mult = 0.7,
        detection_mult = 1.2,
        behavior = "aggressive_fighter",
        color_base = { 1, 0.3, 0.3 }, -- Red-ish
    },
    fighter = {
        name = "Fighter",
        -- Balanced stats
        size_mult = 1.0,
        speed_mult = 1.0,
        hp_mult = 1.0,
        damage_mult = 1.0,
        detection_mult = 1.0,
        behavior = "basic_drone",
        color_base = { 1, 0.4, 0.2 }, -- Orange-ish
    },
    interceptor = {
        name = "Interceptor",
        -- Fast, aggressive, medium HP
        size_mult = 0.9,
        speed_mult = 1.3,
        hp_mult = 0.8,
        damage_mult = 1.2,
        detection_mult = 1.3,
        behavior = "aggressive_fighter",
        color_base = { 1, 0.2, 0.5 }, -- Pink-ish
    },
    gunship = {
        name = "Gunship",
        -- Slow, tanky, high damage
        size_mult = 1.3,
        speed_mult = 0.7,
        hp_mult = 1.5,
        damage_mult = 1.4,
        detection_mult = 0.9,
        behavior = "basic_drone",
        color_base = { 0.9, 0.2, 0.2 }, -- Dark red
    },
    sniper = {
        name = "Sniper",
        -- Long range, fragile, high detection
        size_mult = 0.8,
        speed_mult = 0.9,
        hp_mult = 0.7,
        damage_mult = 1.3,
        detection_mult = 1.8,
        behavior = "sniper",
        color_base = { 0.7, 0.3, 0.9 }, -- Purple-ish
    },
    guardian = {
        name = "Guardian",
        -- Defensive, stays in area
        size_mult = 1.2,
        speed_mult = 0.8,
        hp_mult = 1.8,
        damage_mult = 0.9,
        detection_mult = 1.1,
        behavior = "defensive_sentry",
        color_base = { 0.8, 0.5, 0.2 }, -- Bronze-ish
    }
}

-- List of class keys for random selection
local CLASS_KEYS = {}
for key, _ in pairs(ENEMY_CLASSES) do
    table.insert(CLASS_KEYS, key)
end

-- Generate a procedural enemy configuration
-- @param seed: Random seed for generation
-- @param base_level: Base level for the enemy (from sector difficulty)
-- @return enemy_config: Configuration table for spawning
function ProceduralEnemy.generate(seed, base_level)
    base_level = base_level or 1
    local rng = love.math.newRandomGenerator(seed)

    -- Select random enemy class
    local class_index = rng:random(1, #CLASS_KEYS)
    local class_key = CLASS_KEYS[class_index]
    local class_def = ENEMY_CLASSES[class_key]

    -- Generate level with some variation
    local level = base_level + rng:random(-1, 2)
    if level < 1 then level = 1 end

    -- Calculate level multiplier
    local level_mult = 1 + (level - 1) * 0.15

    -- Generate procedural ship appearance
    local ship_seed = seed + 12345
    local ship_data = ProceduralShip.generate(ship_seed)

    -- Modify ship stats based on class
    local base_hp = ship_data.max_hull or 100
    local base_shield = ship_data.max_shield or 50
    local base_speed = ship_data.max_speed or 500
    local base_thrust = ship_data.thrust or 1000

    -- Apply class modifiers
    local hp = math.floor(base_hp * class_def.hp_mult * level_mult)
    local shield = math.floor(base_shield * class_def.hp_mult * level_mult)
    local max_speed = base_speed * class_def.speed_mult
    local thrust = base_thrust * class_def.speed_mult
    local detection_range = 600 * class_def.detection_mult * (1 + (level - 1) * 0.1)

    -- Modify ship radius based on class
    local radius = (ship_data.radius or 20) * class_def.size_mult

    -- Generate color variation
    local color = {
        class_def.color_base[1] + (rng:random() - 0.5) * 0.2,
        class_def.color_base[2] + (rng:random() - 0.5) * 0.2,
        class_def.color_base[3] + (rng:random() - 0.5) * 0.2
    }
    -- Clamp colors
    for i = 1, 3 do
        if color[i] < 0 then color[i] = 0 end
        if color[i] > 1 then color[i] = 1 end
    end

    -- Select behavior tree
    local behavior_tree
    if class_def.behavior == "basic_drone" then
        behavior_tree = EnemyBehaviors.createBasicDrone()
    elseif class_def.behavior == "aggressive_fighter" then
        behavior_tree = EnemyBehaviors.createAggressiveFighter()
    elseif class_def.behavior == "sniper" then
        behavior_tree = EnemyBehaviors.createSniper()
    elseif class_def.behavior == "defensive_sentry" then
        behavior_tree = EnemyBehaviors.createDefensiveSentry()
    else
        behavior_tree = EnemyBehaviors.createBasicDrone()
    end

    -- Create name
    local name = class_def.name .. " Lv." .. level

    return {
        -- Identity
        name = name,
        class = class_key,
        level = level,

        -- Ship appearance (from procedural generation)
        ship_data = ship_data,
        radius = radius,
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

        -- Loot/XP (for future expansion)
        xp_reward = 10 * level,
        credits_reward = 5 * level,
    }
end

-- Get a descriptive name for an enemy class
function ProceduralEnemy.getClassName(class_key)
    local class_def = ENEMY_CLASSES[class_key]
    return class_def and class_def.name or "Unknown"
end

-- Get all available enemy classes
function ProceduralEnemy.getClasses()
    return ENEMY_CLASSES
end

return ProceduralEnemy
