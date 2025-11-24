local Concord   = require "concord"
local Config    = require "src.config"
local ChunkTypes = require "src.data.chunks"

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

        local asteroid = spawn_single(world, sector_x or 0, sector_y or 0, x, y, radius, color)
        if asteroid and at then
            asteroid:give("asteroid_composition", at.composition)
            if not asteroid.name then
                asteroid:give("name", at.name)
            end
        end
    end
end

return Asteroids
