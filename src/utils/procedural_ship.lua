local Config = require "src.config"

local ProceduralShip = {}

-- Helper to generate a random color with specific hue tendencies
local function randomColor(rng, hue_bias)
    if hue_bias == "warm" then
        return {
            0.7 + rng:random() * 0.3, -- High R
            0.3 + rng:random() * 0.4, -- Med G
            0.1 + rng:random() * 0.2, -- Low B
            1
        }
    elseif hue_bias == "cool" then
        return {
            0.2 + rng:random() * 0.3, -- Low R
            0.4 + rng:random() * 0.4, -- Med G
            0.7 + rng:random() * 0.3, -- High B
            1
        }
    elseif hue_bias == "neutral" then
        local v = 0.5 + rng:random() * 0.4
        return { v, v, v, 1 }
    else
        return {
            0.5 + rng:random() * 0.5,
            0.5 + rng:random() * 0.5,
            0.5 + rng:random() * 0.5,
            1
        }
    end
end

-- Generate a sleek spaceship hull with front point, wings, and rear
local function generateSpaceshipHull(rng, length, width)
    -- Ship points forward (to the right, +X direction)
    local archetype = rng:random(1, 5)

    -- Archetype 1: baseline fighter (original shape with slight variation)
    if archetype == 1 then
        local points = {}

        local body_width = width * (0.7 + rng:random() * 0.5)
        local rear_width = body_width * (0.4 + rng:random() * 0.4)

        local nose_x = length * (0.5 + rng:random() * 0.2)
        local cockpit_x = length * (0.18 + rng:random() * 0.18)

        local asym_top = 1.0 + (rng:random() - 0.5) * 0.25
        local asym_bot = 1.0 + (rng:random() - 0.5) * 0.25

        local wing_span_top = (0.55 + rng:random() * 0.3) * asym_top
        local wing_span_bot = (0.55 + rng:random() * 0.3) * asym_bot

        local wing_front_x = length * (0.08 + rng:random() * 0.12)
        local wing_tip_x = -length * (0.18 + rng:random() * 0.18)
        local wing_back_x = -length * (0.32 + rng:random() * 0.16)
        local rear_x = -length * (0.5 + rng:random() * 0.1)

        table.insert(points, nose_x)
        table.insert(points, 0)

        local cockpit_y = -body_width * (0.25 + rng:random() * 0.2) * asym_top
        table.insert(points, cockpit_x)
        table.insert(points, cockpit_y)

        local wing_front_y = -body_width * (0.45 + rng:random() * 0.25) * wing_span_top
        table.insert(points, wing_front_x)
        table.insert(points, wing_front_y)

        local wing_tip_y = -body_width * wing_span_top
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y)

        local wing_back_y = -rear_width * (0.45 + rng:random() * 0.25) * asym_top
        table.insert(points, wing_back_x)
        table.insert(points, wing_back_y)

        local rear_top_y = -rear_width * (0.35 + rng:random() * 0.2) * asym_top
        table.insert(points, rear_x)
        table.insert(points, rear_top_y)

        table.insert(points, rear_x + length * 0.05)
        table.insert(points, -rear_width * 0.12 * asym_top)

        table.insert(points, rear_x)
        table.insert(points, 0)

        table.insert(points, rear_x + length * 0.05)
        table.insert(points, rear_width * 0.12 * asym_bot)

        local rear_bottom_y = rear_width * (0.35 + rng:random() * 0.2) * asym_bot
        table.insert(points, rear_x)
        table.insert(points, rear_bottom_y)

        local wing_back_x_bot = -length * (0.32 + rng:random() * 0.16)
        local wing_back_y_bot = rear_width * (0.45 + rng:random() * 0.25) * asym_bot
        table.insert(points, wing_back_x_bot)
        table.insert(points, wing_back_y_bot)

        local wing_tip_x_bot = -length * (0.18 + rng:random() * 0.18)
        local wing_tip_y_bot = body_width * wing_span_bot
        table.insert(points, wing_tip_x_bot)
        table.insert(points, wing_tip_y_bot)

        local wing_front_x_bot = length * (0.08 + rng:random() * 0.12)
        local wing_front_y_bot = body_width * (0.45 + rng:random() * 0.25) * wing_span_bot
        table.insert(points, wing_front_x_bot)
        table.insert(points, wing_front_y_bot)

        local cockpit_y_bot = body_width * (0.25 + rng:random() * 0.2) * asym_bot
        table.insert(points, cockpit_x)
        table.insert(points, cockpit_y_bot)

        return points
    end

    -- Archetype 2: broad gunship with heavy rear
    if archetype == 2 then
        local points = {}

        local body_width = width * (1.0 + rng:random() * 0.6)
        local rear_width = body_width * (0.75 + rng:random() * 0.3)
        local rear_x = -length * (0.38 + rng:random() * 0.14)
        local nose_x = length * (0.28 + rng:random() * 0.18)

        table.insert(points, nose_x)
        table.insert(points, 0)

        local mid_front_x = length * (0.12 + rng:random() * 0.12)
        local mid_front_y = -body_width * (0.35 + rng:random() * 0.25)
        table.insert(points, mid_front_x)
        table.insert(points, mid_front_y)

        local wing_tip_x = rear_x + length * (0.12 + rng:random() * 0.12)
        local wing_tip_y = -rear_width * (0.85 + rng:random() * 0.2)
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y)

        local rear_top_x = rear_x
        local rear_top_y = -rear_width * (0.65 + rng:random() * 0.2)
        table.insert(points, rear_top_x)
        table.insert(points, rear_top_y)

        local spine_x = rear_x - length * (0.08 + rng:random() * 0.08)
        table.insert(points, spine_x)
        table.insert(points, -rear_width * 0.15)

        table.insert(points, spine_x)
        table.insert(points, rear_width * 0.15)

        local rear_bottom_y = rear_width * (0.65 + rng:random() * 0.2)
        table.insert(points, rear_top_x)
        table.insert(points, rear_bottom_y)

        local wing_tip_y_bot = rear_width * (0.85 + rng:random() * 0.2)
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y_bot)

        local mid_front_y_bot = body_width * (0.35 + rng:random() * 0.25)
        table.insert(points, mid_front_x)
        table.insert(points, mid_front_y_bot)

        return points
    end

    -- Archetype 3: long interceptor / spearhead
    if archetype == 3 then
        local points = {}

        local body_width = width * (0.5 + rng:random() * 0.3)
        local tail_width = body_width * (0.25 + rng:random() * 0.3)
        local nose_x = length * (0.6 + rng:random() * 0.2)
        local mid_x = length * (0.12 + rng:random() * 0.12)
        local tail_x = -length * (0.65 + rng:random() * 0.15)

        table.insert(points, nose_x)
        table.insert(points, 0)

        table.insert(points, mid_x)
        table.insert(points, -body_width * (0.35 + rng:random() * 0.25))

        table.insert(points, tail_x)
        table.insert(points, -tail_width)

        table.insert(points, tail_x - length * (0.04 + rng:random() * 0.04))
        table.insert(points, 0)

        table.insert(points, tail_x)
        table.insert(points, tail_width)

        table.insert(points, mid_x)
        table.insert(points, body_width * (0.35 + rng:random() * 0.25))

        return points
    end

    -- Archetype 4: delta wing / bomber
    if archetype == 4 then
        local points = {}

        local body_width = width * (0.9 + rng:random() * 0.4)
        local rear_width = body_width * (0.6 + rng:random() * 0.2)
        local nose_x = length * (0.45 + rng:random() * 0.25)
        local rear_x = -length * (0.4 + rng:random() * 0.1)

        table.insert(points, nose_x)
        table.insert(points, 0)

        local wing_mid_x = length * (0.1 + rng:random() * 0.2)
        local wing_mid_y = -body_width * (0.4 + rng:random() * 0.2)
        table.insert(points, wing_mid_x)
        table.insert(points, wing_mid_y)

        local wing_rear_y = -rear_width * (0.8 + rng:random() * 0.2)
        table.insert(points, rear_x)
        table.insert(points, wing_rear_y)

        table.insert(points, rear_x)
        table.insert(points, rear_width * (0.8 + rng:random() * 0.2))

        local wing_mid_y_bot = body_width * (0.4 + rng:random() * 0.2)
        table.insert(points, wing_mid_x)
        table.insert(points, wing_mid_y_bot)

        return points
    end

    -- Archetype 5: forward-swept striker
    if archetype == 5 then
        local points = {}

        local body_width = width * (0.7 + rng:random() * 0.3)
        local rear_width = body_width * (0.5 + rng:random() * 0.3)
        local nose_x = length * (0.5 + rng:random() * 0.2)
        local root_x = length * (0.05 + rng:random() * 0.1)
        local rear_x = -length * (0.35 + rng:random() * 0.15)

        table.insert(points, nose_x)
        table.insert(points, 0)

        local root_y = -body_width * (0.28 + rng:random() * 0.2)
        table.insert(points, root_x)
        table.insert(points, root_y)

        local tip_x = -length * (0.05 + rng:random() * 0.12)
        local tip_y = -body_width * (0.65 + rng:random() * 0.2)
        table.insert(points, tip_x)
        table.insert(points, tip_y)

        local rear_top_y = -rear_width * (0.45 + rng:random() * 0.2)
        table.insert(points, rear_x)
        table.insert(points, rear_top_y)

        local rear_bottom_y = rear_width * (0.45 + rng:random() * 0.2)
        table.insert(points, rear_x)
        table.insert(points, rear_bottom_y)

        local tip_y_bot = body_width * (0.65 + rng:random() * 0.2)
        table.insert(points, tip_x)
        table.insert(points, tip_y_bot)

        local root_y_bot = body_width * (0.28 + rng:random() * 0.2)
        table.insert(points, root_x)
        table.insert(points, root_y_bot)

        return points
    end
end

-- Generate cockpit/detail overlay
local function generateCockpitDetail(rng, length, width)
    local style = rng:random(1, 3)
    local points = {}
    local cockpit_length = length * (0.25 + rng:random() * 0.25)
    local cockpit_width = width * (0.12 + rng:random() * 0.18)

    local front = length * (0.34 + rng:random() * 0.12)
    local back = front - cockpit_length

    if style == 1 then
        table.insert(points, front)
        table.insert(points, 0)

        table.insert(points, (front + back) * 0.5)
        table.insert(points, -cockpit_width * 0.5)

        table.insert(points, back)
        table.insert(points, 0)

        table.insert(points, (front + back) * 0.5)
        table.insert(points, cockpit_width * 0.5)
    elseif style == 2 then
        table.insert(points, front)
        table.insert(points, -cockpit_width * 0.4)

        table.insert(points, back)
        table.insert(points, -cockpit_width * 0.4)

        table.insert(points, back)
        table.insert(points, cockpit_width * 0.4)

        table.insert(points, front)
        table.insert(points, cockpit_width * 0.4)
    else
        local mid = (front + back) * 0.5
        table.insert(points, front)
        table.insert(points, 0)

        table.insert(points, mid)
        table.insert(points, -cockpit_width * 0.6)

        table.insert(points, back)
        table.insert(points, -cockpit_width * 0.2)

        table.insert(points, back)
        table.insert(points, cockpit_width * 0.2)

        table.insert(points, mid)
        table.insert(points, cockpit_width * 0.6)
    end

    return points
end

-- Generate engine glow positions
local function generateEngines(rng, hull_points, length, width)
    local engines = {}

    -- Ships have 2-4 engines at the rear
    local num_engines = rng:random(2, 4)
    local rear_x = -length * (0.45 + rng:random() * 0.12)
    local engine_width = width * (0.12 + rng:random() * 0.08)

    local layout = rng:random(1, 3)

    if layout == 1 then
        if num_engines == 2 then
            table.insert(engines, {
                x = rear_x,
                y = -width * (0.22 + rng:random() * 0.2),
                radius = engine_width,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = width * (0.22 + rng:random() * 0.2),
                radius = engine_width,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
        elseif num_engines == 3 then
            table.insert(engines, {
                x = rear_x,
                y = -width * (0.28 + rng:random() * 0.15),
                radius = engine_width * 0.85,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = 0,
                radius = engine_width * 1.1,
                color = { 0.3, 0.9, 1, 0.95 }
            })
            table.insert(engines, {
                x = rear_x,
                y = width * (0.28 + rng:random() * 0.15),
                radius = engine_width * 0.85,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
        else
            table.insert(engines, {
                x = rear_x,
                y = -width * (0.34 + rng:random() * 0.12),
                radius = engine_width * 0.75,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = -width * (0.16 + rng:random() * 0.12),
                radius = engine_width * 0.75,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = width * (0.16 + rng:random() * 0.12),
                radius = engine_width * 0.75,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = width * (0.34 + rng:random() * 0.12),
                radius = engine_width * 0.75,
                color = { 0.2, 0.8 + rng:random() * 0.2, 1, 0.9 }
            })
        end
    elseif layout == 2 then
        local offset = width * (0.18 + rng:random() * 0.15)
        if num_engines >= 2 then
            table.insert(engines, {
                x = rear_x + length * 0.04,
                y = -offset,
                radius = engine_width * 0.9,
                color = { 0.15, 0.85, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x + length * 0.04,
                y = offset,
                radius = engine_width * 0.9,
                color = { 0.15, 0.85, 1, 0.9 }
            })
        end
        if num_engines >= 3 then
            table.insert(engines, {
                x = rear_x - length * 0.04,
                y = 0,
                radius = engine_width * 1.1,
                color = { 0.25, 0.95, 1, 0.95 }
            })
        end
        if num_engines == 4 then
            table.insert(engines, {
                x = rear_x - length * 0.08,
                y = 0,
                radius = engine_width * 0.7,
                color = { 0.1, 0.8, 1, 0.8 }
            })
        end
    else
        local band = width * (0.12 + rng:random() * 0.2)
        if num_engines == 2 then
            table.insert(engines, {
                x = rear_x,
                y = -band * 0.5,
                radius = engine_width * 1.1,
                color = { 0.25, 0.9, 1, 0.95 }
            })
            table.insert(engines, {
                x = rear_x,
                y = band * 0.5,
                radius = engine_width * 1.1,
                color = { 0.25, 0.9, 1, 0.95 }
            })
        elseif num_engines == 3 then
            table.insert(engines, {
                x = rear_x,
                y = -band,
                radius = engine_width,
                color = { 0.2, 0.85, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = 0,
                radius = engine_width * 1.2,
                color = { 0.3, 0.95, 1, 0.95 }
            })
            table.insert(engines, {
                x = rear_x,
                y = band,
                radius = engine_width,
                color = { 0.2, 0.85, 1, 0.9 }
            })
        else
            table.insert(engines, {
                x = rear_x,
                y = -band * 1.5,
                radius = engine_width * 0.85,
                color = { 0.2, 0.85, 1, 0.9 }
            })
            table.insert(engines, {
                x = rear_x,
                y = -band * 0.5,
                radius = engine_width,
                color = { 0.3, 0.95, 1, 0.95 }
            })
            table.insert(engines, {
                x = rear_x,
                y = band * 0.5,
                radius = engine_width,
                color = { 0.3, 0.95, 1, 0.95 }
            })
            table.insert(engines, {
                x = rear_x,
                y = band * 1.5,
                radius = engine_width * 0.85,
                color = { 0.2, 0.85, 1, 0.9 }
            })
        end
    end

    return engines
end

-- Generate weapon hardpoints
local function generateWeaponHardpoints(rng, length, width)
    local hardpoints = {}
    local num_weapons = rng:random(2, 4)

    -- Weapons typically on wings or nose
    if num_weapons >= 2 then
        -- Wing-mounted
        local weapon_x = length * (0.08 + rng:random() * 0.25)
        table.insert(hardpoints, {
            x = weapon_x,
            y = -width * (0.38 + rng:random() * 0.18),
            type = "wing_cannon"
        })
        table.insert(hardpoints, {
            x = weapon_x,
            y = width * (0.38 + rng:random() * 0.18),
            type = "wing_cannon"
        })
    end

    if num_weapons >= 3 then
        table.insert(hardpoints, {
            x = length * (0.38 + rng:random() * 0.12),
            y = 0,
            type = "nose_cannon"
        })
    end

    if num_weapons >= 4 then
        table.insert(hardpoints, {
            x = length * 0.4,
            y = -width * 0.12,
            type = "nose_cannon"
        })
        table.insert(hardpoints, {
            x = length * 0.4,
            y = width * 0.12,
            type = "nose_cannon"
        })
    end

    return hardpoints
end

-- Generate panel lines / details
local function generatePanelLines(rng, length, width)
    local lines = {}
    local num_lines = rng:random(4, 8)

    for i = 1, num_lines do
        local line_type = rng:random(1, 3)

        if line_type == 1 then
            -- Longitudinal line (runs front to back)
            local y_pos = (rng:random() - 0.5) * width * 0.7
            table.insert(lines, {
                type = "line",
                x1 = length * (0.32 - rng:random() * 0.16),
                y1 = y_pos,
                x2 = -length * (0.25 + rng:random() * 0.18),
                y2 = y_pos
            })
        elseif line_type == 2 then
            -- Cross section line
            local x_pos = length * (rng:random() - 0.5) * 0.7
            local line_width = width * (0.28 + rng:random() * 0.5)
            table.insert(lines, {
                type = "line",
                x1 = x_pos,
                y1 = -line_width * 0.5,
                x2 = x_pos,
                y2 = line_width * 0.5
            })
        else
            -- Diagonal detail
            local start_x = length * (0.05 + rng:random() * 0.35)
            local start_y = (rng:random() - 0.5) * width * 0.55
            local end_x = start_x - length * (0.18 + rng:random() * 0.25)
            local end_y = start_y + (rng:random() - 0.5) * width * 0.35
            table.insert(lines, {
                type = "line",
                x1 = start_x,
                y1 = start_y,
                x2 = end_x,
                y2 = end_y
            })
        end
    end

    return lines
end

function ProceduralShip.generate(seed)
    local rng = love.math.newRandomGenerator(seed)

    -- Base ship dimensions
    local size_roll = rng:random()
    local length
    local width

    if size_roll < 0.33 then
        length = 22 + rng:random() * 16        -- small interceptor / scout
        width = 12 + rng:random() * 10
    elseif size_roll < 0.66 then
        length = 26 + rng:random() * 20        -- medium fighter
        width = 16 + rng:random() * 14
    else
        length = 32 + rng:random() * 22        -- heavy gunship
        width = 20 + rng:random() * 18
    end

    local radius = math.max(length, width) * 0.5 -- Bounding radius for physics

    -- Generate ship components
    local hull_points = generateSpaceshipHull(rng, length, width)
    local cockpit_points = generateCockpitDetail(rng, length, width)
    local engines = generateEngines(rng, hull_points, length, width)
    local weapon_hardpoints = generateWeaponHardpoints(rng, length, width)
    local panel_lines = generatePanelLines(rng, length, width)

    -- Color scheme
    local color_schemes = { "warm", "cool", "neutral", "vibrant" }
    local scheme = color_schemes[rng:random(1, #color_schemes)]

    local base_color = randomColor(rng, scheme)
    local detail_color = randomColor(rng, "neutral")
    local accent_color = randomColor(rng, scheme)

    -- Darken detail color a bit
    detail_color[1] = detail_color[1] * 0.7
    detail_color[2] = detail_color[2] * 0.7
    detail_color[3] = detail_color[3] * 0.7

    -- Stats based on size/randomness
    local class_mass_mult
    local class_hp_mult
    local class_shield_mult
    local class_speed_mult

    if length < 30 then
        class_mass_mult = 0.85
        class_hp_mult = 0.9
        class_shield_mult = 0.8
        class_speed_mult = 1.2
    elseif length < 40 then
        class_mass_mult = 1.0
        class_hp_mult = 1.0
        class_shield_mult = 1.0
        class_speed_mult = 1.0
    else
        class_mass_mult = 1.35
        class_hp_mult = 1.4
        class_shield_mult = 1.5
        class_speed_mult = 0.8
    end

    local mass = class_mass_mult * (1 + (radius / 15))
    local max_hull = math.floor((50 + rng:random(100)) * class_hp_mult)
    local max_shield = math.floor((20 + rng:random(80)) * class_shield_mult)
    local speed_mult = class_speed_mult * (1.5 - (radius / 40)) -- Smaller is faster

    -- Engine mounts for trail system (use actual engine positions)
    local engine_mounts = {}
    for _, eng in ipairs(engines) do
        table.insert(engine_mounts, {
            x = eng.x,
            y = eng.y,
            width = eng.radius * 2,
            length = 0.4 + rng:random() * 0.4,
            color = eng.color
        })
    end

    -- Weapon mounts for weapon component (strip type field)
    local weapon_mounts = {}
    for _, hp in ipairs(weapon_hardpoints) do
        table.insert(weapon_mounts, { x = hp.x, y = hp.y })
    end

    return {
        name = "Unknown Ship",
        type = "procedural",
        seed = seed,

        -- Physics
        mass = mass,
        linear_damping = Config.LINEAR_DAMPING,
        restitution = 0.2,
        radius = radius,

        -- Vehicle
        thrust = Config.THRUST * speed_mult,
        rotation_speed = Config.ROTATION_SPEED * speed_mult,
        max_speed = Config.MAX_SPEED * speed_mult,

        -- Stats
        max_hull = max_hull,
        max_shield = max_shield,
        shield_regen = 5,

        -- Loadout / capacity
        weapon_name = "pulse_laser",
        weapon_mounts = weapon_mounts,
        cargo_capacity = 50,
        magnet_radius = 100,
        magnet_force = 20,

        engine_mounts = engine_mounts,

        -- Render Data
        render_data = {
            hull = hull_points,
            cockpit = cockpit_points,
            engines = engines,
            weapon_hardpoints = weapon_hardpoints,
            panel_lines = panel_lines,
            base_color = base_color,
            detail_color = detail_color,
            accent_color = accent_color,
            radius = radius,
            length = length,
            width = width
        }
    }
end

return ProceduralShip
