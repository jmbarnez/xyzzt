-- Projectile shatter effect system
-- Creates realistic shard particles when projectiles impact
local Concord = require "lib.concord.concord"

local ProjectileShatter = {}

-- Creates a tight, realistic shatter effect when a projectile impacts
-- @param world: ECS world
-- @param x, y: Impact position
-- @param sector_x, sector_y: Sector coordinates
-- @param color: Projectile color {r, g, b, a}
-- @param projectile_radius: Size of the projectile (optional, defaults to 2)
-- @param impact_vel_x, impact_vel_y: Velocity at impact for directional scatter
function ProjectileShatter.spawn(world, x, y, sector_x, sector_y, color, projectile_radius, impact_vel_x, impact_vel_y)
    if not world then return end

    -- Default parameters
    color = color or { 1, 1, 1, 1 }
    projectile_radius = projectile_radius or 2

    -- Calculate number of shards based on projectile size (more realistic)
    -- Smaller projectiles = fewer shards
    local num_shards = math.floor(4 + projectile_radius * 2)
    num_shards = math.min(num_shards, 12) -- Cap at 12 for performance

    -- Shard size proportional to projectile size
    local base_shard_size = projectile_radius * 0.4

    -- Calculate impact direction
    local impact_angle = 0
    local impact_speed = 0
    local use_directional = false

    if impact_vel_x and impact_vel_y then
        impact_angle = math.atan2(impact_vel_y, impact_vel_x)
        impact_speed = math.sqrt(impact_vel_x * impact_vel_x + impact_vel_y * impact_vel_y)
        use_directional = true
    end

    -- Create seeded RNG for deterministic variation
    local seed = math.floor(x * 1000 + y * 1000) % 2147483647
    local rng = love.math.newRandomGenerator(seed)

    for i = 1, num_shards do
        local angle
        local speed_mult
        local spawn_distance

        if use_directional then
            -- Realistic physics: shards scatter in a cone opposite to impact direction
            -- Main scatter cone (most shards go backward)
            local is_backward = rng:random() < 0.7 -- 70% scatter backward

            if is_backward then
                -- Backward scatter (reflection-like)
                local spread = math.pi * 0.5          -- 90 degree cone
                angle = impact_angle + math.pi + (rng:random() - 0.5) * spread
                speed_mult = 0.6 + rng:random() * 0.5 -- Medium speed
            else
                -- Forward scatter (debris continues forward)
                local spread = math.pi * 0.4          -- 72 degree cone
                angle = impact_angle + (rng:random() - 0.5) * spread
                speed_mult = 0.3 + rng:random() * 0.4 -- Slower
            end

            -- Tighter spawn - shards originate very close to impact point
            spawn_distance = projectile_radius * 0.3 + rng:random() * projectile_radius * 0.4
        else
            -- Radial burst when no velocity info (even distribution)
            local base_angle_offset = (math.pi * 2 / num_shards) * i
            local jitter = (rng:random() - 0.5) * 0.3
            angle = base_angle_offset + jitter
            speed_mult = 0.7 + rng:random() * 0.5
            spawn_distance = projectile_radius * 0.2 + rng:random() * projectile_radius * 0.3
        end

        -- Calculate spawn position (very tight to impact point)
        local spawn_x = x + math.cos(angle) * spawn_distance
        local spawn_y = y + math.sin(angle) * spawn_distance

        -- Create shard entity
        local shard = Concord.entity(world)
        shard:give("transform", spawn_x, spawn_y, rng:random() * math.pi * 2)
        shard:give("sector", sector_x, sector_y)

        -- Shard size variation (realistic fragmentation)
        local size_var = 0.5 + rng:random() * 0.8
        local shard_size = base_shard_size * size_var

        -- Color variation with slight brightness change
        local brightness_var = 0.85 + rng:random() * 0.3
        local shard_color = {
            color[1] * brightness_var,
            color[2] * brightness_var,
            color[3] * brightness_var,
            color[4]
        }

        -- Create realistic shard shape (random polygon)
        -- Generate a random elongated shard shape
        local shard_type = rng:random(1, 3)
        local vertices = {}

        if shard_type == 1 then
            -- Elongated triangle shard
            local length = shard_size * (1.5 + rng:random() * 1.0)
            local width = shard_size * (0.3 + rng:random() * 0.4)
            vertices = {
                -length * 0.5, 0,
                length * 0.5, -width * 0.5,
                length * 0.5, width * 0.5
            }
        elseif shard_type == 2 then
            -- Jagged quadrilateral shard
            local length = shard_size * (1.2 + rng:random() * 0.8)
            local width = shard_size * (0.4 + rng:random() * 0.3)
            vertices = {
                -length * 0.4, -width * 0.3,
                length * 0.6, -width * 0.5,
                length * 0.5, width * 0.5,
                -length * 0.3, width * 0.4
            }
        else
            -- Thin splinter shard
            local length = shard_size * (1.8 + rng:random() * 0.7)
            local width = shard_size * (0.2 + rng:random() * 0.2)
            vertices = {
                -length * 0.5, -width * 0.5,
                length * 0.5, -width * 0.3,
                length * 0.4, width * 0.4,
                -length * 0.4, width * 0.5
            }
        end

        shard:give("render", {
            render_type = "projectile_shard",
            color = shard_color,
            radius = shard_size, -- Keep for reference
            vertices = vertices  -- Polygon shape for rendering
        })
        shard:give("projectile_shard")

        -- Shorter lifetime for snappier, more satisfying effect
        local lifetime = 0.12 + rng:random() * 0.18 -- 0.12-0.3 seconds
        shard:give("lifetime", lifetime)

        -- Physics setup with polygon shape
        local shard_body = love.physics.newBody(world.physics_world, spawn_x, spawn_y, "dynamic")
        shard_body:setLinearDamping(3.5) -- High damping for quick deceleration
        shard_body:setGravityScale(0)

        local shard_shape = love.physics.newPolygonShape(vertices)
        local shard_fixture = love.physics.newFixture(shard_body, shard_shape, 0.05)
        shard_fixture:setSensor(true) -- Don't collide with other objects
        shard_fixture:setUserData(shard)

        shard:give("physics", shard_body, shard_shape, shard_fixture)

        -- Velocity calculation (scaled to impact speed if available)
        local base_speed
        if use_directional and impact_speed > 0 then
            -- Scale shard speed based on impact speed (more realistic)
            base_speed = impact_speed * (0.4 + rng:random() * 0.5)
        else
            -- Default burst speed
            base_speed = 100 + rng:random() * 80
        end

        local final_speed = base_speed * speed_mult

        shard_body:setLinearVelocity(
            math.cos(angle) * final_speed,
            math.sin(angle) * final_speed
        )

        -- Angular velocity based on size (smaller shards spin faster)
        local angular_vel = (rng:random() - 0.5) * (25 / size_var)
        shard_body:setAngularVelocity(angular_vel)
    end
end

return ProjectileShatter
