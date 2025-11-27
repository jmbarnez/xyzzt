local Concord = require "lib.concord.concord"

-- The standard local transform (Float relative to sector center)
Concord.component("transform", function(c, x, y, r)
    c.x = x or 0
    c.y = y or 0
    c.r = r or 0
end)

-- The Sector Coordinate (Integer Grid ID)
Concord.component("sector", function(c, x, y)
    c.x = x or 0
    c.y = y or 0
end)

Concord.component("physics", function(c, body, shape, fixture)
    c.body = body
    c.shape = shape
    c.fixture = fixture
end)

-- [UPDATED] Input now stores the *state* of controls, not just the tag
Concord.component("input", function(c)
    c.thrust = false
    c.turn = 0 -- -1 (left), 0 (none), 1 (right)
    c.fire = false
    c.move_x = 0
    c.move_y = 0
    c.target_angle = nil
    c.boost = false
end)

Concord.component("render", function(c, arg)
    if type(arg) == "table" then
        if arg.type or arg.render_type then
            c.type = arg.type or arg.render_type
            c.color = arg.color or { 1, 1, 1 }
            if arg.radius then
                c.radius = arg.radius
            end
            if arg.length then
                c.length = arg.length
            end
            if arg.thickness then
                c.thickness = arg.thickness
            end
            if arg.shape then
                c.shape = arg.shape
            end
            if arg.shapes then
                c.shapes = arg.shapes
            end
            if arg.vertices then
                c.vertices = arg.vertices
            end
            if arg.seed then
                c.seed = arg.seed
            end
            if arg.render_data then
                c.render_data = arg.render_data
            end
        else
            c.color = arg
        end
    elseif type(arg) == "string" then
        c.type = arg
        c.color = { 1, 1, 1 }
    else
        c.color = arg or { 1, 1, 1 }
    end
end)

Concord.component("name", function(c, value)
    c.value = value or ""
end)

Concord.component("hull", function(c, max, current)
    c.max = max or 100
    c.current = current or c.max
end)

Concord.component("shield", function(c, max, regen)
    c.max = max or 100
    c.current = max or 100
    c.regen = regen or 0
end)

Concord.component("wallet", function(c, credits)
    c.credits = credits or 0
end)

Concord.component("skills", function(c)
    c.list = {}
end)

-- Pilot/Ship Separation
Concord.component("pilot")

Concord.component("controlling", function(c, entity)
    c.entity = entity
end)

Concord.component("vehicle", function(c, thrust, turn_speed, max_speed)
    c.thrust = thrust or 1000
    c.turn_speed = turn_speed or 5
    c.max_speed = max_speed or 500
end)

Concord.component("weapon", function(c, weapon_name, mounts)
    c.weapon_name = weapon_name or "pulse_laser"
    c.cooldown = 0
    c.mounts = mounts or { { x = 0, y = 0 } }
end)

Concord.component("projectile", function(c, damage, lifetime, owner)
    c.damage = damage or 0
    c.lifetime = lifetime or 0
    c.owner = owner
end)

Concord.component("level", function(c, current, xp, next_level_xp)
    c.current = current or 1
    c.xp = xp or 0
    c.next_level_xp = next_level_xp or 1000
end)

Concord.component("hp", function(c, max, current)
    c.max = max or 100
    c.current = current or c.max
    c.last_hit_time = nil
end)

Concord.component("asteroid", function(c, seed)
    c.seed = seed -- Store generation seed for network sync
end)

Concord.component("asteroid_composition", function(c, composition)
    c.map = composition or {}
end)

Concord.component("asteroid_chunk")

Concord.component("chunk_resource", function(c, resource_type, amount)
    c.resource_type = resource_type or "stone"
    c.amount = amount or 1
end)

Concord.component("projectile_shard")

Concord.component("lifetime", function(c, duration)
    c.duration = duration or 3.0
    c.elapsed = 0
end)

Concord.component("item", function(c, type, name, volume)
    c.type = type or "resource"
    c.name = name or "Unknown Item"
    c.volume = volume or 1.0
end)



Concord.component("cargo", function(c, capacity)
    c.capacity = capacity or 100 -- Now represents volume
    c.current = 0
    c.mass = 0                   -- Total mass of items in cargo
    c.items = {}                 -- table of {name="Stone", count=1}
end)

Concord.component("magnet", function(c, radius, force)
    c.radius = radius or 100
    c.force = force or 500
end)

-- Collision layers for spatial grid

Concord.component("trail", function(c, config_list)
    -- config_list is a list of { x, y, width, length, color }
    c.trails = {}

    if config_list then
        for _, cfg in ipairs(config_list) do
            table.insert(c.trails, {
                offset_x = cfg.x or 0,
                offset_y = cfg.y or 0,
                width = cfg.width or 10,
                length = cfg.length or 0.5,
                color = cfg.color or { 0, 1, 1, 1 },
                particle_system = nil -- Love2D ParticleSystem
            })
        end
    end
end)

-- AI behavior tree controller
Concord.component("ai", function(c, behavior_tree)
    c.behavior_tree = behavior_tree
    c.blackboard = {}
    c.update_interval = 0.1 -- AI ticks every 100ms
    c.time_since_update = 0
end)

-- Detection and sensing
Concord.component("detection", function(c, range, fov)
    c.range = range or 500 -- Detection radius
    c.fov = fov            -- Field of view in radians (nil = 360 degrees)
    c.can_detect_cloaked = false
end)

-- Current target tracking
Concord.component("target", function(c, entity)
    c.entity = entity -- Target entity reference
    c.last_seen_time = 0
    c.last_known_x = 0
    c.last_known_y = 0
    c.pursuit_duration = 0
end)

-- Level-based stat scaling
Concord.component("level_scaling", function(c, level)
    c.level = level or 1
    c.stat_multiplier = 1 + (level - 1) * 0.15 -- 15% per level
end)

Concord.component("station")

Concord.component("station_area", function(c, radius)
    c.radius = radius or 200
end)

Concord.component("experience_reward", function(c, amount)
    c.amount = amount or 0
end)

Concord.component("floating_text", function(c, text, x, y, duration, color)
    c.text = text or ""
    c.x = x or 0
    c.y = y or 0
    c.duration = duration or 1.0
    c.elapsed = 0
    c.color = color or { 1, 1, 1, 1 }
end)


