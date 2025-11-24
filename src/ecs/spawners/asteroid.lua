local Concord   = require "concord"
local Config    = require "src.config"

local Asteroids = {}

local AsteroidTypes = {
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

local function spawn_single(world, sector_x, sector_y, x, y, radius, color)
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(Config.LINEAR_DAMPING * 2)
    body:setAngularDamping(Config.LINEAR_DAMPING * 2)

    local vertices = {}

    local function rnd()
        if love and love.math and love.math.random then
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

    local shape       = love.physics.newPolygonShape(vertices)
    local fixture     = love.physics.newFixture(body, shape, 1.0)
    fixture:setRestitution(0.1)

    local asteroid = Concord.entity(world)
    asteroid:give("transform", x, y, 0)
    asteroid:give("sector", sector_x or 0, sector_y or 0)
    asteroid:give("physics", body, shape, fixture)
    local c = color or { 0.6, 0.6, 0.6, 1 }
    asteroid:give("render", { render_type = "asteroid", color = c, radius = radius, vertices = vertices })
    local hp_max = math.floor((radius or 30) * 1.5)
    asteroid:give("hp", hp_max)
    asteroid:give("asteroid")

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

    local half_size = (Config.SECTOR_SIZE or 10000) * 0.5
    local inner_radius = half_size * 0.1
    local outer_radius = half_size * 0.8

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
        local color

        local function clamp01(v)
            if v < 0.1 then return 0.1 end
            if v > 0.9 then return 0.9 end
            return v
        end

        if type(rng) == "table" and rng.random then
            radius = 10 + rng:random() * 70

            local tone = 0.25 + rng:random() * 0.5 -- overall brightness
            local warm = rng:random()              -- 0 = gray, 1 = warm brown

            if warm > 0.4 then
                -- Warm brown rock
                local r_t = tone + 0.25
                local g_t = tone + 0.1 * rng:random()
                local b_t = tone * 0.4
                color = { clamp01(r_t), clamp01(g_t), clamp01(b_t), 1 }
            else
                -- Cooler / neutral gray
                local shift = (rng:random() - 0.5) * 0.2
                local g_tone = tone
                color = {
                    clamp01(g_tone + shift),
                    clamp01(g_tone + shift * 0.5),
                    clamp01(g_tone - shift),
                    1
                }
            end
        else
            radius = 10 + math.random() * 70

            local tone = 0.25 + math.random() * 0.5
            local warm = math.random()

            if warm > 0.4 then
                local r_t = tone + 0.25
                local g_t = tone + 0.1 * math.random()
                local b_t = tone * 0.4
                color = { clamp01(r_t), clamp01(g_t), clamp01(b_t), 1 }
            else
                local shift = (math.random() - 0.5) * 0.2
                local g_tone = tone
                color = {
                    clamp01(g_tone + shift),
                    clamp01(g_tone + shift * 0.5),
                    clamp01(g_tone - shift),
                    1
                }
            end
        end

        local asteroid = spawn_single(world, sector_x or 0, sector_y or 0, x, y, radius, color)
        if asteroid then
            local at
            if type(rng) == "table" and rng.random then
                at = AsteroidTypeList[rng:random(1, #AsteroidTypeList)]
            else
                at = AsteroidTypeList[math.random(1, #AsteroidTypeList)]
            end

            if at then
                asteroid:give("asteroid_composition", at.composition)
                if not asteroid.name then
                    asteroid:give("name", at.name)
                end
            end
        end
    end
end

return Asteroids
