local Concord = require "concord"

local AsteroidChunkSpawner = {}

-- Spawn asteroid chunks when an asteroid is destroyed
-- @param world: ECS world
-- @param parent_entity: The asteroid entity being destroyed
-- @param num_chunks: Optional number of chunks to spawn
function AsteroidChunkSpawner.spawn(world, parent_entity, num_chunks)
    if not (world and parent_entity) then return end

    local transform = parent_entity.transform
    local sector = parent_entity.sector
    local render = parent_entity.render

    if not (transform and sector and render) then return end

    local parent_radius = render.radius or 10
    local parent_color = render.color or { 0.6, 0.6, 0.6, 1 }

    -- Always spawn 2-3 chunks
    if not num_chunks then
        num_chunks = 2 + math.random(0, 1) -- 2-3 chunks
    end

    -- Calculate max chunk radius to conserve mass
    -- In 2D: total area of chunks ≤ parent area
    -- Area = π*r², so for N equal chunks: N * π*rchunk² ≤ π*rparent²
    -- Therefore: rchunk ≤ rparent / sqrt(N)
    local base_chunk_radius = parent_radius / math.sqrt(num_chunks)

    -- Create seeded RNG for deterministic variation
    local entity_key = tostring(parent_entity)
    local seed = 0
    for i = 1, #entity_key do
        seed = (seed * 31 + entity_key:byte(i)) % 2147483647
    end
    local rng = love.math.newRandomGenerator(seed)

    for i = 1, num_chunks do
        -- Varied chunk sizes (40% to 120% of base)
        local size_variation = 0.4 + rng:random() * 0.8
        local chunk_radius = base_chunk_radius * size_variation

        -- Random angle for radial distribution with more jitter
        local base_angle = (math.pi * 2 / num_chunks) * i
        local angle_jitter = (rng:random() - 0.5) * 1.2 -- Increased jitter
        local angle = base_angle + angle_jitter

        -- Random radial distance (0.3 to 0.8 of parent radius)
        local radial_distance = parent_radius * (0.3 + rng:random() * 0.5)

        -- Perpendicular offset for more scatter
        local perp_offset = (rng:random() - 0.5) * parent_radius * 0.4

        -- Calculate spawn position
        local spawn_x = transform.x + math.cos(angle) * radial_distance + math.cos(angle + math.pi / 2) * perp_offset
        local spawn_y = transform.y + math.sin(angle) * radial_distance + math.sin(angle + math.pi / 2) * perp_offset

        -- Create chunk entity
        local chunk = Concord.entity(world)
        chunk:give("transform", spawn_x, spawn_y, rng:random() * math.pi * 2)
        chunk:give("sector", sector.x, sector.y)

        -- Generate random convex polygon for chunk (4-6 vertices)
        local vertex_count = math.random(4, 6)
        local vertices = {}
        for v = 1, vertex_count do
            local v_angle = (v / vertex_count) * math.pi * 2 + (rng:random() - 0.5) * 0.5
            local v_radius = chunk_radius * (0.8 + rng:random() * 0.4)
            table.insert(vertices, math.cos(v_angle) * v_radius)
            table.insert(vertices, math.sin(v_angle) * v_radius)
        end

        chunk:give("render", {
            render_type = "asteroid_chunk",
            color = parent_color,
            radius = chunk_radius,
            vertices = vertices -- Store vertices for rendering
        })
        chunk:give("asteroid_chunk")

        -- Give chunks HP so they can be destroyed
        local hp_max = math.floor(chunk_radius * 1.5)
        chunk:give("hp", hp_max)

        -- Create physics body for chunk
        local chunk_body = love.physics.newBody(world.physics_world, spawn_x, spawn_y, "dynamic")
        chunk_body:setLinearDamping(1.0)
        chunk_body:setAngularDamping(1.0)

        -- Use the same vertices for physics shape
        local chunk_shape = love.physics.newPolygonShape(vertices)
        local chunk_fixture = love.physics.newFixture(chunk_body, chunk_shape, 0.5)
        chunk_fixture:setRestitution(0.2)
        chunk_fixture:setUserData(chunk)

        chunk:give("physics", chunk_body, chunk_shape, chunk_fixture)

        -- Velocity varies by size (smaller chunks move faster)
        local base_speed = 80 + rng:random() * 120             -- 80-200 units/sec
        local size_speed_factor = 1.5 - (size_variation * 0.5) -- Smaller = faster
        local speed = base_speed * size_speed_factor

        -- Add tangential velocity component for spin effect
        local tangential_speed = speed * 0.3 * (rng:random() - 0.5)

        local vel_x = math.cos(angle) * speed + math.cos(angle + math.pi / 2) * tangential_speed
        local vel_y = math.sin(angle) * speed + math.sin(angle + math.pi / 2) * tangential_speed

        chunk_body:setLinearVelocity(vel_x, vel_y)

        -- Angular velocity proportional to linear speed
        local angular_vel = (rng:random() - 0.5) * (speed / 30)
        chunk_body:setAngularVelocity(angular_vel)
    end
end

return AsteroidChunkSpawner
