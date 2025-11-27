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
    local archetype = rng:random(1, 3)

    -- Archetype 1: baseline fighter (original shape with slight variation)
    if archetype == 1 then
        local points = {}

        -- Front tip (nose)
        local nose_x = length * (0.45 + rng:random() * 0.15)
        local nose_sharpness = 0.7 + rng:random() * 0.3 -- How pointy the nose is

        -- Main body width variation
        local body_width = width * (0.8 + rng:random() * 0.2)
        local rear_width = body_width * (0.4 + rng:random() * 0.3)

        -- Asymmetry factor (slightRandomVariation for organic feel)
        local asym_top = 1.0 + (rng:random() - 0.5) * 0.1
        local asym_bot = 1.0 + (rng:random() - 0.5) * 0.1

        -- Define ship profile (clockwise from nose, top side first)
        -- Nose tip
        table.insert(points, nose_x)
        table.insert(points, 0)

        -- Top side (going back from nose)
        -- Upper cockpit area
        local cockpit_x = length * (0.2 + rng:random() * 0.1)
        local cockpit_y = -body_width * 0.3 * asym_top
        table.insert(points, cockpit_x)
        table.insert(points, cockpit_y)

        -- Top wing leading edge
        local wing_front_x = length * (0.05 + rng:random() * 0.1)
        local wing_front_y = -body_width * (0.5 + rng:random() * 0.2) * asym_top
        table.insert(points, wing_front_x)
        table.insert(points, wing_front_y)

        -- Top wing tip (widest point)
        local wing_tip_x = -length * (0.15 + rng:random() * 0.1)
        local wing_tip_y = -body_width * (0.55 + rng:random() * 0.15) * asym_top
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y)

        -- Top wing trailing edge (back to body)
        local wing_back_x = -length * (0.3 + rng:random() * 0.1)
        local wing_back_y = -rear_width * 0.5 * asym_top
        table.insert(points, wing_back_x)
        table.insert(points, wing_back_y)

        -- Rear top (engine mount area)
        local rear_x = -length * 0.5
        local rear_top_y = -rear_width * (0.4 + rng:random() * 0.1) * asym_top
        table.insert(points, rear_x)
        table.insert(points, rear_top_y)

        -- Rear center top (engine cutout)
        table.insert(points, rear_x + length * 0.05)
        table.insert(points, -rear_width * 0.15 * asym_top)

        -- Center rear (between engines)
        table.insert(points, rear_x)
        table.insert(points, 0)

        -- Rear center bottom (engine cutout)
        table.insert(points, rear_x + length * 0.05)
        table.insert(points, rear_width * 0.15 * asym_bot)

        -- Rear bottom (engine mount area)
        table.insert(points, rear_x)
        table.insert(points, rear_width * (0.4 + rng:random() * 0.1) * asym_bot)

        -- Bottom wing trailing edge
        local wing_back_x_bot = -length * (0.3 + rng:random() * 0.1)
        local wing_back_y_bot = rear_width * 0.5 * asym_bot
        table.insert(points, wing_back_x_bot)
        table.insert(points, wing_back_y_bot)

        -- Bottom wing tip
        local wing_tip_x_bot = -length * (0.15 + rng:random() * 0.1)
        local wing_tip_y_bot = body_width * (0.55 + rng:random() * 0.15) * asym_bot
        table.insert(points, wing_tip_x_bot)
        table.insert(points, wing_tip_y_bot)

        -- Bottom wing leading edge
        local wing_front_x_bot = length * (0.05 + rng:random() * 0.1)
        local wing_front_y_bot = body_width * (0.5 + rng:random() * 0.2) * asym_bot
        table.insert(points, wing_front_x_bot)
        table.insert(points, wing_front_y_bot)

        -- Bottom cockpit area
        local cockpit_y_bot = body_width * 0.3 * asym_bot
        table.insert(points, cockpit_x)
        table.insert(points, cockpit_y_bot)

        -- Back to nose (loop complete)

        return points
    end

    -- Archetype 2: broad gunship with heavy rear
    if archetype == 2 then
        local points = {}

        local body_width = width * (1.1 + rng:random() * 0.3)
        local rear_width = body_width * (0.8 + rng:random() * 0.2)
        local rear_x = -length * (0.35 + rng:random() * 0.1)
        local nose_x = length * (0.25 + rng:random() * 0.15)

        table.insert(points, nose_x)
        table.insert(points, 0)

        local mid_front_x = length * (0.05 + rng:random() * 0.05)
        local mid_front_y = -body_width * (0.4 + rng:random() * 0.1)
        table.insert(points, mid_front_x)
        table.insert(points, mid_front_y)

        local wing_tip_x = rear_x + length * (0.05 + rng:random() * 0.05)
        local wing_tip_y = -rear_width * (0.8 + rng:random() * 0.1)
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y)

        local rear_top_x = rear_x
        local rear_top_y = -rear_width * (0.6 + rng:random() * 0.1)
        table.insert(points, rear_top_x)
        table.insert(points, rear_top_y)

        local rear_center_x = rear_x - length * (0.05 + rng:random() * 0.05)
        table.insert(points, rear_center_x)
        table.insert(points, 0)

        local rear_bottom_y = rear_width * (0.6 + rng:random() * 0.1)
        table.insert(points, rear_top_x)
        table.insert(points, rear_bottom_y)

        local wing_tip_y_bot = rear_width * (0.8 + rng:random() * 0.1)
        table.insert(points, wing_tip_x)
        table.insert(points, wing_tip_y_bot)

        local mid_front_y_bot = body_width * (0.4 + rng:random() * 0.1)
        table.insert(points, mid_front_x)
        table.insert(points, mid_front_y_bot)

        return points
    end

    -- Archetype 3: long interceptor / spearhead
    do
        local points = {}

        local body_width = width * (0.6 + rng:random() * 0.2)
        local tail_width = body_width * (0.3 + rng:random() * 0.2)
        local nose_x = length * (0.55 + rng:random() * 0.15)
        local mid_x = length * (0.1 + rng:random() * 0.05)
        local tail_x = -length * (0.6 + rng:random() * 0.1)

        table.insert(points, nose_x)
        table.insert(points, 0)

        table.insert(points, mid_x)
        table.insert(points, -body_width * (0.4 + rng:random() * 0.1))

        table.insert(points, tail_x)
        table.insert(points, -tail_width)

        table.insert(points, tail_x)
        table.insert(points, tail_width)

        table.insert(points, mid_x)
        table.insert(points, body_width * (0.4 + rng:random() * 0.1))

        return points
    end
end

-- Generate cockpit/detail overlay
local function generateCockpitDetail(rng, length, width)
    local points = {}
    local cockpit_length = length * (0.3 + rng:random() * 0.2)
    local cockpit_width = width * (0.15 + rng:random() * 0.15)

    -- Simple diamond shape for cockpit
    local front = length * (0.35 + rng:random() * 0.1)
    local back = length * (0.1 + rng:random() * 0.1)

    table.insert(points, front)
    table.insert(points, 0)

    table.insert(points, (front + back) * 0.5)
    table.insert(points, -cockpit_width * 0.5)

    table.insert(points, back)
    table.insert(points, 0)

    table.insert(points, (front + back) * 0.5)
    table.insert(points, cockpit_width * 0.5)

    return points
end

-- Generate engine glow positions
local function generateEngines(rng, hull_points, length, width)
    local engines = {}

    -- Ships have 2-4 engines at the rear
    local num_engines = rng:random(2, 4)
    local rear_x = -length * 0.5
    local engine_width = width * 0.15

    if num_engines == 2 then
        -- Two engines, top and bottom
        table.insert(engines, {
            x = rear_x,
            y = -width * (0.25 + rng:random() * 0.15),
            radius = engine_width,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = width * (0.25 + rng:random() * 0.15),
            radius = engine_width,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
    elseif num_engines == 3 then
        -- Three engines, top, center, bottom
        table.insert(engines, {
            x = rear_x,
            y = -width * 0.3,
            radius = engine_width * 0.8,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = 0,
            radius = engine_width,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = width * 0.3,
            radius = engine_width * 0.8,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
    else -- 4 engines
        table.insert(engines, {
            x = rear_x,
            y = -width * 0.35,
            radius = engine_width * 0.7,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = -width * 0.15,
            radius = engine_width * 0.7,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = width * 0.15,
            radius = engine_width * 0.7,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
        table.insert(engines, {
            x = rear_x,
            y = width * 0.35,
            radius = engine_width * 0.7,
            color = { 0.3, 0.7 + rng:random() * 0.3, 1, 0.9 }
        })
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
        local weapon_x = length * (0.1 + rng:random() * 0.2)
        table.insert(hardpoints, {
            x = weapon_x,
            y = -width * (0.4 + rng:random() * 0.1),
            type = "wing_cannon"
        })
        table.insert(hardpoints, {
            x = weapon_x,
            y = width * (0.4 + rng:random() * 0.1),
            type = "wing_cannon"
        })
    end

    if num_weapons >= 4 then
        -- Nose-mounted
        table.insert(hardpoints, {
            x = length * 0.4,
            y = -width * 0.1,
            type = "nose_cannon"
        })
        table.insert(hardpoints, {
            x = length * 0.4,
            y = width * 0.1,
            type = "nose_cannon"
        })
    end

    return hardpoints
end

-- Generate panel lines / details
local function generatePanelLines(rng, length, width)
    local lines = {}
    local num_lines = rng:random(3, 6)

    for i = 1, num_lines do
        local line_type = rng:random(1, 3)

        if line_type == 1 then
            -- Longitudinal line (runs front to back)
            local y_pos = (rng:random() - 0.5) * width * 0.6
            table.insert(lines, {
                type = "line",
                x1 = length * (0.3 - rng:random() * 0.1),
                y1 = y_pos,
                x2 = -length * (0.2 + rng:random() * 0.1),
                y2 = y_pos
            })
        elseif line_type == 2 then
            -- Cross section line
            local x_pos = length * (rng:random() - 0.5) * 0.6
            local line_width = width * (0.3 + rng:random() * 0.4)
            table.insert(lines, {
                type = "line",
                x1 = x_pos,
                y1 = -line_width * 0.5,
                x2 = x_pos,
                y2 = line_width * 0.5
            })
        else
            -- Diagonal detail
            local start_x = length * (rng:random() * 0.3)
            local start_y = (rng:random() - 0.5) * width * 0.5
            local end_x = start_x - length * (0.2 + rng:random() * 0.2)
            local end_y = start_y + (rng:random() - 0.5) * width * 0.3
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
    local length = 20 + rng:random() * 20        -- 20-40 units long
    local width = 15 + rng:random() * 15         -- 15-30 units wide
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
    local mass = 1 + (radius / 15)
    local max_hull = 50 + rng:random(100)
    local max_shield = 20 + rng:random(80)
    local speed_mult = 1.5 - (radius / 40) -- Smaller is faster

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
        },

        -- Enhanced draw function
        draw = function(color_override)
            local r_data = {
                hull = hull_points,
                cockpit = cockpit_points,
                engines = engines,
                weapon_hardpoints = weapon_hardpoints,
                panel_lines = panel_lines,
                base_color = base_color,
                detail_color = detail_color,
                accent_color = accent_color
            }

            -- Draw main hull
            if color_override then
                love.graphics.setColor(unpack(color_override))
            else
                love.graphics.setColor(unpack(r_data.base_color))
            end
            love.graphics.polygon("fill", r_data.hull)

            -- Draw hull outline
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", r_data.hull)

            -- Draw panel lines (surface details)
            if not color_override then
                love.graphics.setColor(r_data.detail_color[1], r_data.detail_color[2], r_data.detail_color[3], 0.4)
                love.graphics.setLineWidth(1)
                for _, line in ipairs(r_data.panel_lines) do
                    love.graphics.line(line.x1, line.y1, line.x2, line.y2)
                end
            end

            -- Draw cockpit detail
            if not color_override then
                love.graphics.setColor(r_data.accent_color[1], r_data.accent_color[2], r_data.accent_color[3], 0.6)
                if #r_data.cockpit >= 6 then
                    love.graphics.polygon("fill", r_data.cockpit)
                end

                -- Cockpit glass highlight
                love.graphics.setColor(0.6, 0.8, 1, 0.3)
                if #r_data.cockpit >= 6 then
                    love.graphics.polygon("fill", r_data.cockpit)
                end
            end

            -- Draw weapon hardpoints
            if not color_override then
                love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
                for _, wp in ipairs(r_data.weapon_hardpoints) do
                    love.graphics.circle("fill", wp.x, wp.y, 1.5)
                end
            end

            -- Draw engine glows
            if not color_override then
                for _, eng in ipairs(r_data.engines) do
                    -- Outer engine glow
                    love.graphics.setColor(eng.color[1], eng.color[2], eng.color[3], 0.3)
                    love.graphics.circle("fill", eng.x, eng.y, eng.radius * 1.5)

                    -- Inner engine core
                    love.graphics.setColor(eng.color[1], eng.color[2], eng.color[3], 0.8)
                    love.graphics.circle("fill", eng.x, eng.y, eng.radius * 0.8)

                    -- Bright center
                    love.graphics.setColor(1, 1, 1, 0.6)
                    love.graphics.circle("fill", eng.x, eng.y, eng.radius * 0.3)
                end
            end

            love.graphics.setLineWidth(1)
        end
    }
end

return ProceduralShip
