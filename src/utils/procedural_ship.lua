local Config = require "src.config"

local ProceduralShip = {}

-- Helper to generate a random color
local function randomColor(rng)
    return {
        rng:random() * 0.5 + 0.5, -- R (bright)
        rng:random() * 0.5 + 0.5, -- G (bright)
        rng:random() * 0.5 + 0.5, -- B (bright)
        1
    }
end

-- Helper to generate a random polygon for the ship hull
local function generateHull(rng, radius)
    local points = {}
    local num_points = rng:random(5, 12)
    for i = 1, num_points do
        local angle = (i / num_points) * math.pi * 2
        local r = radius * (0.5 + rng:random() * 0.5)
        table.insert(points, math.cos(angle) * r)
        table.insert(points, math.sin(angle) * r)
    end
    return points
end

function ProceduralShip.generate(seed)
    local rng = love.math.newRandomGenerator(seed)

    local radius = 10 + rng:random() * 10
    local hull_points = generateHull(rng, radius)
    local base_color = randomColor(rng)
    local detail_color = randomColor(rng)

    -- Stats based on size/randomness
    local mass = 1 + (radius / 10)
    local max_hull = 50 + rng:random(100)
    local max_shield = 20 + rng:random(80)
    local speed_mult = 1.5 - (radius / 30) -- Smaller is faster

    return {
        name = "Unknown Ship",
        type = "procedural", -- Marker for render system

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

        -- Render Data (stored for the generic draw function)
        render_data = {
            hull = hull_points,
            base_color = base_color,
            detail_color = detail_color,
            radius = radius
        },

        -- Custom draw function using the generated data
        draw = function(color_override)
            local r_data = hull_points -- Closure capture
            local b_col = base_color
            local d_col = detail_color

            if color_override then
                love.graphics.setColor(unpack(color_override))
            else
                love.graphics.setColor(unpack(b_col))
            end

            love.graphics.polygon("fill", hull_points)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.polygon("line", hull_points)
            love.graphics.setLineWidth(1)

            -- Simple detail: inner polygon
            love.graphics.setColor(unpack(d_col))
            love.graphics.push()
            love.graphics.scale(0.5)
            love.graphics.polygon("fill", hull_points)
            love.graphics.pop()
        end
    }
end

return ProceduralShip
