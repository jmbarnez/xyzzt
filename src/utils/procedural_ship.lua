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

    -- Find rear-most points for engine mounts
    -- Simple heuristic: find vertices with lowest X (assuming ship points right, but hull generation is radial)
    -- Actually, hull generation is radial around 0,0.
    -- Let's assume engines are at the "back" relative to some direction?
    -- Or just pick 1-2 random points on the perimeter?
    -- Better: Pick points that are roughly opposite to the "front".
    -- Let's assume "front" is +X (0 angle). "Back" is -X (pi angle).

    local engine_mounts = {}
    local num_engines = rng:random(1, 2)

    -- Find vertices closest to angle PI
    local candidate_indices = {}
    for i = 1, #hull_points, 2 do
        local x = hull_points[i]
        local y = hull_points[i + 1]
        local angle = math.atan2(y, x)
        -- Normalize angle to 0..2PI
        if angle < 0 then angle = angle + math.pi * 2 end

        -- Back is PI (3.14159)
        local dist_to_back = math.abs(angle - math.pi)
        table.insert(candidate_indices, { index = i, dist = dist_to_back, x = x, y = y })
    end

    table.sort(candidate_indices, function(a, b) return a.dist < b.dist end)

    -- Pick top N candidates
    for i = 1, math.min(num_engines, #candidate_indices) do
        local cand = candidate_indices[i]
        table.insert(engine_mounts, {
            x = cand.x,
            y = cand.y,
            width = radius * 0.4,
            length = 0.4 + rng:random() * 0.4,
            color = { 0.2, 0.8 + rng:random() * 0.2, 1, 1 } -- Cyan/Blueish
        })
    end

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

        engine_mounts = engine_mounts,

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
