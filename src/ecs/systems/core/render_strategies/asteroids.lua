local Common = require "src.ecs.systems.core.render_strategies.common"

local asteroidShapes = {}
local asteroidShader = nil

local hashString = Common.hashString
local getColorFromRender = Common.getColorFromRender
local getRadiusFromRender = Common.getRadiusFromRender

local Asteroids = {}

-- Internal helper: load asteroid shader once
local function ensureAsteroidShader()
    if asteroidShader then
        return asteroidShader
    end

    local shader_path = "assets/shaders/asteroid.glsl"
    if love.filesystem.getInfo(shader_path) then
        asteroidShader = love.graphics.newShader(shader_path)
    end
    return asteroidShader
end

-- Internal helper: build convex-ish polygon
local function buildPolygon(key, radius, minVerts, maxVerts, angleJitter, radiusMinFactor, radiusRangeFactor)
    local poly = asteroidShapes[key]
    if poly then
        return poly
    end

    poly = {}
    local seed = hashString(key)
    local rng = (love and love.math and love.math.newRandomGenerator)
        and love.math.newRandomGenerator(seed)
        or nil

    local function rnd()
        if rng and rng.random then
            return rng:random()
        else
            return math.random()
        end
    end

    local vertex_count = minVerts + math.floor(rnd() * (maxVerts - minVerts + 1))
    if vertex_count < minVerts then
        vertex_count = minVerts
    end
    if maxVerts and vertex_count > maxVerts then
        vertex_count = maxVerts
    end

    for i = 1, vertex_count do
        local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * angleJitter
        local rr = radius * (radiusMinFactor + rnd() * radiusRangeFactor)
        table.insert(poly, math.cos(angle) * rr)
        table.insert(poly, math.sin(angle) * rr)
    end

    asteroidShapes[key] = poly
    return poly
end

-- Internal helper: polygon -> mesh (triangle fan)
local function buildMeshForPolygon(key, poly)
    local meshKey = key .. "_mesh"
    local mesh = asteroidShapes[meshKey]
    if mesh then
        return mesh
    end

    local cx, cy = 0, 0
    local vertCount = #poly / 2
    for i = 1, vertCount do
        cx = cx + poly[(i - 1) * 2 + 1]
        cy = cy + poly[(i - 1) * 2 + 2]
    end
    cx = cx / vertCount
    cy = cy / vertCount

    local minX, maxX = poly[1], poly[1]
    local minY, maxY = poly[2], poly[2]
    for i = 1, vertCount do
        local x = poly[(i - 1) * 2 + 1]
        local y = poly[(i - 1) * 2 + 2]
        minX = math.min(minX, x)
        maxX = math.max(maxX, x)
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    local width = maxX - minX
    local height = maxY - minY
    local scale = math.max(width, height)
    if scale == 0 then
        scale = 1
    end

    local vertices = {}
    for i = 1, vertCount do
        local x = poly[(i - 1) * 2 + 1]
        local y = poly[(i - 1) * 2 + 2]
        local u = (x - minX) / scale
        local v = (y - minY) / scale
        table.insert(vertices, { x, y, u, v, 1, 1, 1, 1 })
    end

    local triangles = {}
    for i = 1, vertCount do
        local nextIndex = (i % vertCount) + 1
        table.insert(triangles, {
            { cx, cy, 0.5, 0.5, 1, 1, 1, 1 },
            vertices[i],
            vertices[nextIndex],
        })
    end

    local flatVertices = {}
    for _, tri in ipairs(triangles) do
        for _, v in ipairs(tri) do
            table.insert(flatVertices, v)
        end
    end

    mesh = love.graphics.newMesh(flatVertices, "triangles", "static")
    asteroidShapes[meshKey] = mesh
    return mesh
end

-- Internal helper: set shader seed (normalized 0-1)
local function applyShaderSeed(e, r, key, inheritFromAsteroidComponent)
    if not asteroidShader then
        return
    end

    local seedVal

    if inheritFromAsteroidComponent and e.asteroid and e.asteroid.seed then
        seedVal = e.asteroid.seed
    elseif type(r) == "table" and r.seed then
        seedVal = r.seed
    else
        seedVal = hashString(key)
    end

    if type(r) == "table" and not r.seed then
        r.seed = seedVal
    end

    local seed = seedVal / 2147483647
    asteroidShader:send("seed", seed)
end

-- Internal helper: outline polygon with thin black line
local function drawOutline(poly)
    if not poly then
        return
    end
    local oldLineWidth = love.graphics.getLineWidth()
    local oldLineStyle = love.graphics.getLineStyle()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(0.5)
    love.graphics.setLineStyle("rough")
    love.graphics.polygon("line", poly)
    love.graphics.setLineWidth(oldLineWidth)
    love.graphics.setLineStyle(oldLineStyle)
end

function Asteroids.asteroid(e)
    local r = e.render
    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)
    local key = tostring(e)
    local poly
    local mesh

    local isNetworkedAsteroid = (e.asteroid ~= nil) and (e.network_id ~= nil)

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    elseif isNetworkedAsteroid then
        love.graphics.circle("fill", 0, 0, radius)
        return
    else
        poly = asteroidShapes[key]
        if not poly then
            poly = buildPolygon(key, radius, 5, 8, 0.4, 0.7, 0.4)
        end
        mesh = buildMeshForPolygon(key, poly)

        if type(r) == "table" then
            r.vertices = poly
        end
    end

    ensureAsteroidShader()
    if asteroidShader then
        love.graphics.setShader(asteroidShader)
        applyShaderSeed(e, r, key, true)
    end

    love.graphics.setColor(cr, cg, cb, ca)
    if mesh then
        love.graphics.draw(mesh)
    else
        love.graphics.polygon("fill", poly)
    end

    if asteroidShader then
        love.graphics.setShader()
    end

    drawOutline(poly)
    love.graphics.setColor(cr, cg, cb, ca)
end

function Asteroids.asteroid_chunk(e)
    local r = e.render
    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)
    local key = tostring(e)
    local poly
    local mesh

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    else
        poly = asteroidShapes[key]
        if not poly then
            poly = buildPolygon(key, radius, 4, 6, 0.6, 0.6, 0.5)
        end
        mesh = buildMeshForPolygon(key, poly)

        if type(r) == "table" then
            r.vertices = poly
        end
    end

    ensureAsteroidShader()
    if asteroidShader then
        love.graphics.setShader(asteroidShader)
        -- chunks do not look at e.asteroid; they just use r.seed or hash
        applyShaderSeed(e, r, key, false)
    end

    love.graphics.setColor(cr, cg, cb, ca)
    if mesh then
        love.graphics.draw(mesh)
    else
        love.graphics.polygon("fill", poly)
    end

    if asteroidShader then
        love.graphics.setShader()
    end

    drawOutline(poly)
end

return Asteroids
