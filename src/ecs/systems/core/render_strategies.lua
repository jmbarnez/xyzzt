local Ships = require "src.data.ships"

local RenderStrategies = {}

local asteroidShapes = {}
local asteroidShader = nil

local function hashString(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

local function getColorFromRender(r)
    local color = { 1, 1, 1, 1 }

    if type(r) == "table" then
        if type(r.color) == "table" then
            color = r.color
        elseif #r >= 3 then
            color = r
        end
    elseif type(r) == "number" then
        color = { r, r, r, 1 }
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    return cr, cg, cb, ca
end

local function getRadiusFromRender(r, defaultRadius)
    local radius = defaultRadius or 10
    if type(r) == "table" and r.radius then
        radius = r.radius
    end
    return radius
end

function RenderStrategies.asteroid(e)
    local r = e.render

    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)

    local key = tostring(e)
    local poly = nil

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    else
        poly = asteroidShapes[key]
        if not poly then
            poly = {}
            local seed = hashString(key)
            local rng = (love and love.math and love.math.newRandomGenerator) and
                love.math.newRandomGenerator(seed) or nil
            local function rnd()
                if rng and rng.random then
                    return rng:random()
                else
                    return math.random()
                end
            end

            local vertex_count = 8 + math.floor(rnd() * 5)
            if vertex_count < 5 then vertex_count = 5 end

            for i = 1, vertex_count do
                local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.4
                local rr = radius * (0.7 + rnd() * 0.4)
                table.insert(poly, math.cos(angle) * rr)
                table.insert(poly, math.sin(angle) * rr)
            end

            asteroidShapes[key] = poly
        end
    end

    -- Load shader on first use
    if not asteroidShader then
        local shader_path = "assets/shaders/asteroid.glsl"
        if love.filesystem.getInfo(shader_path) then
            asteroidShader = love.graphics.newShader(shader_path)
        end
    end

    -- Apply shader if available
    if asteroidShader then
        love.graphics.setShader(asteroidShader)
        -- Send unique seed for this asteroid to make texture stable
        local seed = hashString(key) / 2147483647 -- Normalize to 0-1
        asteroidShader:send("seed", seed)
    end

    -- Draw base asteroid shape with shader
    love.graphics.setColor(cr, cg, cb, ca)
    love.graphics.polygon("fill", poly)

    -- Reset shader
    if asteroidShader then
        love.graphics.setShader()
    end

    -- Black outline for crisp definition (very thin outline)
    local oldLineWidth = love.graphics.getLineWidth()
    local oldLineStyle = love.graphics.getLineStyle()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(0.5)
    love.graphics.setLineStyle("rough") -- Disable anti-aliasing for crisp lines
    love.graphics.polygon("line", poly)
    love.graphics.setLineWidth(oldLineWidth)
    love.graphics.setLineStyle(oldLineStyle)

    love.graphics.setColor(cr, cg, cb, ca)
end

function RenderStrategies.asteroid_chunk(e)
    local r = e.render

    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)

    local key = tostring(e)
    local poly = nil

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    else
        poly = asteroidShapes[key]
        if not poly then
            poly = {}
            local seed = hashString(key)
            local rng = (love and love.math and love.math.newRandomGenerator) and
                love.math.newRandomGenerator(seed) or nil
            local function rnd()
                if rng and rng.random then
                    return rng:random()
                else
                    return math.random()
                end
            end

            local vertex_count = 4 + math.floor(rnd() * 3)
            if vertex_count < 4 then vertex_count = 4 end

            for i = 1, vertex_count do
                local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.6
                local rr = radius * (0.6 + rnd() * 0.5)
                table.insert(poly, math.cos(angle) * rr)
                table.insert(poly, math.sin(angle) * rr)
            end

            asteroidShapes[key] = poly
        end
    end

    -- Load shader on first use
    if not asteroidShader then
        local shader_path = "assets/shaders/asteroid.glsl"
        if love.filesystem.getInfo(shader_path) then
            asteroidShader = love.graphics.newShader(shader_path)
        end
    end

    -- Apply shader if available
    if asteroidShader then
        love.graphics.setShader(asteroidShader)
        -- Send unique seed for this asteroid chunk to make texture stable
        local seed = hashString(key) / 2147483647 -- Normalize to 0-1
        asteroidShader:send("seed", seed)
    end

    -- Draw chunk shape with shader
    love.graphics.setColor(cr, cg, cb, ca)
    love.graphics.polygon("fill", poly)

    -- Reset shader
    if asteroidShader then
        love.graphics.setShader()
    end

    -- Black outline (very thin outline)
    local oldLineWidth = love.graphics.getLineWidth()
    local oldLineStyle = love.graphics.getLineStyle()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(0.5)
    love.graphics.setLineStyle("rough") -- Disable anti-aliasing for crisp lines
    love.graphics.polygon("line", poly)
    love.graphics.setLineWidth(oldLineWidth)
    love.graphics.setLineStyle(oldLineStyle)
end

function RenderStrategies.projectile_shard(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" and r.color then
        color = r.color
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    if e.lifetime then
        local fade = 1.0 - (e.lifetime.elapsed / e.lifetime.duration)
        ca = ca * math.max(0, fade)
    end

    love.graphics.setColor(cr, cg, cb, ca)

    if type(r) == "table" and r.vertices then
        love.graphics.polygon("fill", r.vertices)

        local outline_alpha = ca * 0.6
        love.graphics.setColor(cr * 0.7, cg * 0.7, cb * 0.7, outline_alpha)
        love.graphics.setLineWidth(0.5)
        love.graphics.polygon("line", r.vertices)
    else
        local radius = 2
        if type(r) == "table" and r.radius then
            radius = r.radius
        end
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.item(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" and r.color then
        color = r.color
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    love.graphics.setColor(cr, cg, cb, ca)

    if type(r) == "table" and r.shape then
        love.graphics.polygon("fill", r.shape)

        local orr = cr * 0.5
        local org = cg * 0.5
        local orb = cb * 0.5
        love.graphics.setColor(orr, org, orb, ca)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", r.shape)
    else
        local radius = 4
        if type(r) == "table" and r.radius then
            radius = r.radius
        end
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.projectile(e)
    local r = e.render

    local color = r.color or { 1, 1, 1, 1 }
    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1
    love.graphics.setColor(cr, cg, cb, ca)

    local shape = r.shape or "beam"
    if shape == "beam" then
        local radius = r.radius or 3
        local length = r.length or (radius * 4)
        local thickness = r.thickness or (radius * 0.7)
        love.graphics.rectangle("fill", -length * 0.5, -thickness * 0.5, length, thickness)
    elseif shape == "circle" then
        local radius = r.radius or 3
        love.graphics.circle("fill", 0, 0, radius)
    else
        local radius = r.radius or 3
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.ship(e)
    local r = e.render
    if not r then return end

    -- Color tint for player (green) or enemy (red)
    local tint = r.color or { 1, 1, 1, 1 }

    if r.shapes then
        -- Iterate through the data-driven shape list
        for _, shape in ipairs(r.shapes) do
            -- Blend shape color with tint by multiplication
            local shapeColor = shape.color or { 1, 1, 1, 1 }
            local blended = {
                shapeColor[1] * tint[1],
                shapeColor[2] * tint[2],
                shapeColor[3] * tint[3],
                (shapeColor[4] or 1) * (tint[4] or 1)
            }
            love.graphics.setColor(blended)

            if shape.type == "polygon" and shape.points then
                love.graphics.polygon("fill", shape.points)
                if shape.outline then
                    love.graphics.setColor(shape.outline)
                    love.graphics.setLineWidth(1)
                    love.graphics.polygon("line", shape.points)
                end
            elseif shape.type == "circle" then
                local cx = shape.x or 0
                local cy = shape.y or 0
                local rad = shape.radius or 2
                love.graphics.circle("fill", cx, cy, rad)
                if shape.outline then
                    love.graphics.setColor(shape.outline)
                    love.graphics.circle("line", cx, cy, rad)
                end
            end
        end
    else
        -- Fallback for ships without shape data (e.g., placeholder or procedural)
        love.graphics.setColor(tint)
        love.graphics.circle("fill", 0, 0, 10)
        -- Nose indicator
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.line(0, 0, 10, 0)
    end
end

function RenderStrategies.fallback(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" then
        if type(r.color) == "table" then
            color = r.color
        elseif #r >= 3 then
            color = r
        end
    elseif type(r) == "number" then
        color = { r, r, r, 1 }
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = 10
    if type(r) == "table" and r.radius then
        radius = r.radius
    end

    love.graphics.circle("fill", 0, 0, radius)
end

local DrawStrategies = {
    asteroid = RenderStrategies.asteroid,
    asteroid_chunk = RenderStrategies.asteroid_chunk,
    projectile_shard = RenderStrategies.projectile_shard,
    item = RenderStrategies.item,
    projectile = RenderStrategies.projectile,
    ship = RenderStrategies.ship,
}

local function resolve_type_key(e)
    local r = e.render

    if type(r) == "table" and r.type then
        if r.type == "asteroid" or r.type == "asteroid_chunk" or
            r.type == "projectile_shard" or r.type == "item" or
            r.type == "projectile" then
            return r.type
        else
            return "ship"
        end
    end

    return nil
end

local function draw(e)
    local r = e.render
    if not r then return end

    local key = resolve_type_key(e)
    local strategy = key and DrawStrategies[key] or nil

    if strategy then
        strategy(e)
    else
        RenderStrategies.fallback(e)
    end
end

return {
    draw = draw,
}
