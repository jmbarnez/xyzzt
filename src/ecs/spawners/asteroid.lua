local Concord          = require "lib.concord.concord"
local Config           = require "src.config"
local ChunkTypes       = require "src.data.chunks"
local DefaultSector    = require "src.data.default_sector"

local Asteroids        = {}

local AsteroidTypes    = {
    rocky = {
        name = "Rocky Asteroid",
        composition = { stone = 1.0 },
    },
    metallic = {
        name = "Metallic Asteroid",
        composition = { stone = 0.5, iron = 0.5 },
    },
}

local AsteroidTypeList = {
    AsteroidTypes.rocky,
    AsteroidTypes.metallic,
}

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function mix_resource_colors(composition)
    if not composition then
        return { 0.6, 0.6, 0.6, 1 }
    end

    local r, g, b, a, total = 0, 0, 0, 0, 0
    for res, weight in pairs(composition) do
        if weight and weight > 0 then
            local def = ChunkTypes[res]
            if def and def.color then
                local c = def.color
                r = r + (c[1] or 1) * weight
                g = g + (c[2] or 1) * weight
                b = b + (c[3] or 1) * weight
                a = a + (c[4] or 1) * weight
                total = total + weight
            end
        end
    end

    if total > 0 then
        return {
            clamp01(r / total),
            clamp01(g / total),
            clamp01(b / total),
            clamp01(a / total),
        }
    end

    return { 0.6, 0.6, 0.6, 1 }
end

local function jitter_color(base, rng)
    local j = 0.08

    local br = base[1] or 1
    local bg = base[2] or 1
    local bb = base[3] or 1
    local ba = base[4] or 1

    local function rand01()
        if rng and type(rng) == "table" and rng.random then
            return rng:random()
        else
            return math.random()
        end
    end

    local function jitter_channel(c)
        local shift = (rand01() - 0.5) * 2 * j
        return clamp01(c + shift)
    end

    return {
        jitter_channel(br),
        jitter_channel(bg),
        jitter_channel(bb),
        ba,
    }
end

local function spawn_single(world, sector_x, sector_y, x, y, radius, color, network_id, seed)
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(Config.LINEAR_DAMPING * 2)
    body:setAngularDamping(Config.LINEAR_DAMPING * 2)

    local vertices = {}

    -- Use seed-based RNG if provided, otherwise use global random
    local rng
    if seed then
        rng = love.math.newRandomGenerator(seed)
    end

    local function rnd()
        if rng then
            return rng:random()
        elseif love and love.math and love.math.random then
            return love.math.random()
        else
            return math.random()
        end
    end

    local vertex_count = 5 + math.floor(rnd() * 4) -- 5–8 vertices to satisfy Box2D limits

    for i = 1, vertex_count do
        local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.4
        local rr = radius * (0.7 + rnd() * 0.4)
        table.insert(vertices, math.cos(angle) * rr)
        table.insert(vertices, math.sin(angle) * rr)
    end

    local shape   = love.physics.newPolygonShape(vertices)
    local fixture = love.physics.newFixture(body, shape, 1.0)
    fixture:setRestitution(0.1)

    -- Deterministic initial rotation (no spin)
    local initial_rotation = 0
    if rng then
        initial_rotation = rng:random() * math.pi * 2 -- Random angle 0-2π
    end

    body:setAngle(initial_rotation)

    local asteroid = Concord.entity(world)
    if network_id then
        asteroid.network_id = network_id
    end

    asteroid:give("transform", x, y, initial_rotation)
    asteroid:give("sector", sector_x or 0, sector_y or 0)
    asteroid:give("physics", body, shape, fixture)
    asteroid:give("render", {
        type = "asteroid",
        color = color or { 0.6, 0.6, 0.6, 1 },
        radius = radius,
        vertices = vertices,
    })
    asteroid:give("asteroid", seed)

    local hp_max = math.floor((radius or 30) * 2)
    asteroid:give("hp", hp_max)

    fixture:setUserData(asteroid)

    return asteroid
end

function Asteroids.spawnField(world, sector_x, sector_y, seed, count)
    if not world or not world.physics_world then
        return
    end

    count = count or 40

    local use_seed = seed
    if type(use_seed) ~= "number" then
        use_seed = os.time()
    end

    local rng
    if love and love.math and love.math.newRandomGenerator then
        rng = love.math.newRandomGenerator(use_seed)
    else
        rng = math.random
    end

    local half_size = (DefaultSector.SECTOR_SIZE or 10000) * 0.5
    local inner_radius = half_size * 0.1
    local outer_radius = half_size * 0.8

    -- Check if we need to assign network IDs (server/host mode)
    local Server = nil
    local assign_network_ids = false
    if world.hosting then
        Server = require "src.network.server"
        assign_network_ids = true
    end

    for i = 1, count do
        local a
        local r
        if type(rng) == "table" and rng.random then
            a = rng:random() * math.pi * 2
            local t = rng:random()
            r = inner_radius + (t * t) * (outer_radius - inner_radius)
        else
            a = math.random() * math.pi * 2
            local t = math.random()
            r = inner_radius + (t * t) * (outer_radius - inner_radius)
        end

        local x = math.cos(a) * r
        local y = math.sin(a) * r

        local radius
        if type(rng) == "table" and rng.random then
            radius = 10 + rng:random() * 70
        else
            radius = 10 + math.random() * 70
        end

        local at
        if type(rng) == "table" and rng.random then
            at = AsteroidTypeList[rng:random(1, #AsteroidTypeList)]
        else
            at = AsteroidTypeList[math.random(1, #AsteroidTypeList)]
        end

        local base_color = mix_resource_colors(at and at.composition)
        local color = jitter_color(base_color, rng)

        -- Generate deterministic seed for this specific asteroid
        -- Combines sector coords, asteroid index, and universe seed for uniqueness
        local asteroid_seed = use_seed + (sector_x or 0) * 1000000 + (sector_y or 0) * 10000 + i

        -- Assign network_id if we're on the server/host
        local network_id = nil
        if assign_network_ids and Server then
            network_id = Server.next_network_id
            Server.next_network_id = Server.next_network_id + 1
        end

        local asteroid = spawn_single(world, sector_x or 0, sector_y or 0, x, y, radius, color, network_id, asteroid_seed)
        if asteroid and at then
            asteroid:give("asteroid_composition", at.composition)
            if not asteroid.name then
                asteroid:give("name", at.name)
            end
        end
    end
end

-- Export spawn_single for client-side network spawning
Asteroids.spawn_single = spawn_single

return Asteroids
