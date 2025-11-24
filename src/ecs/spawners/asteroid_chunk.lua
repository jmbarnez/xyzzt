local Concord = require "concord"
local ChunkTypes = require "src.data.chunks"
local ItemSpawners = require "src.ecs.spawners.item"

local AsteroidChunkSpawner = {}
local MIN_CHUNK_RADIUS = 6
local BASE_UNIT_RADIUS = MIN_CHUNK_RADIUS
local BASE_UNIT_AREA = math.pi * BASE_UNIT_RADIUS * BASE_UNIT_RADIUS

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

    local composition_map
    if parent_entity.asteroid_composition and parent_entity.asteroid_composition.map then
        composition_map = parent_entity.asteroid_composition.map
    end
    if not composition_map or next(composition_map) == nil then
        composition_map = { stone = 1.0 }
    end

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
    -- Inherit seed from parent if available to keep texture consistent
    local seed = 0
    if render.seed then
        seed = render.seed
    else
        local entity_key = tostring(parent_entity)
        for i = 1, #entity_key do
            seed = (seed * 31 + entity_key:byte(i)) % 2147483647
        end
    end
    local rng = love.math.newRandomGenerator(seed)

    local function choose_resource_type()
        local total = 0
        for _, weight in pairs(composition_map) do
            if weight and weight > 0 then
                total = total + weight
            end
        end

        if total <= 0 then
            return "stone"
        end

        local r = rng:random() * total
        local acc = 0
        for res, weight in pairs(composition_map) do
            if weight and weight > 0 then
                acc = acc + weight
                if r <= acc then
                    return res
                end
            end
        end

        return "stone"
    end

    for i = 1, num_chunks do
        local resource_type = choose_resource_type()

        -- Varied chunk sizes (40% to 120% of base)
        local size_variation = 0.4 + rng:random() * 0.8
        local raw_chunk_radius = base_chunk_radius * size_variation

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

        local chunk_def = ChunkTypes[resource_type] or ChunkTypes.stone

        -- If this chunk would be smaller than the minimum radius, drop items directly
        if raw_chunk_radius < MIN_CHUNK_RADIUS then
            local radius_for_volume = raw_chunk_radius
            if radius_for_volume <= 0 then
                radius_for_volume = MIN_CHUNK_RADIUS * 0.5
            end

            local area = math.pi * radius_for_volume * radius_for_volume
            local area_ratio = area / BASE_UNIT_AREA
            local yield_scale = chunk_def.yield_per_unit_area or 2.0
            local units = math.max(1, math.floor(math.sqrt(area_ratio) * yield_scale + 0.5))

            local chunk_volume = (math.pi * radius_for_volume * radius_for_volume) / 100.0
            local chunk_mass = chunk_volume * 2.0

            local item_volume = chunk_volume / units
            local item_mass = chunk_mass / units

            local item_id = chunk_def.item_id or "stone"

            for j = 1, units do
                ItemSpawners.spawn_item(world, item_id, spawn_x, spawn_y, sector.x, sector.y, item_volume, item_mass)
            end
        else
            local chunk_radius = raw_chunk_radius

            -- Generate random convex polygon for chunk (4-6 vertices)
            local vertex_count = math.random(4, 6)
            local vertices = {}
            for v = 1, vertex_count do
                local v_angle = (v / vertex_count) * math.pi * 2 + (rng:random() - 0.5) * 0.5
                local v_radius = chunk_radius * (0.8 + rng:random() * 0.4)
                table.insert(vertices, math.cos(v_angle) * v_radius)
                table.insert(vertices, math.sin(v_angle) * v_radius)
            end

            local chunk_color = chunk_def.color or parent_color

            local area = math.pi * chunk_radius * chunk_radius
            local area_ratio = area / BASE_UNIT_AREA
            local yield_scale = chunk_def.yield_per_unit_area or 2.0
            local units = math.max(1, math.floor(math.sqrt(area_ratio) * yield_scale + 0.5))

            -- Create chunk entity
            local chunk = Concord.entity(world)
            chunk:give("transform", spawn_x, spawn_y, rng:random() * math.pi * 2)
            chunk:give("sector", sector.x, sector.y)

            chunk:give("render", {
                render_type = "asteroid_chunk",
                color = chunk_color,
                radius = chunk_radius,
                vertices = vertices, -- Store vertices for rendering
                seed = seed          -- Pass parent seed for texture consistency
            })
            chunk:give("asteroid_chunk")
            chunk:give("chunk_resource", resource_type, units)

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
end

return AsteroidChunkSpawner
