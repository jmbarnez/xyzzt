local Ships = require "src.data.ships"

local RenderStrategies = {}

local asteroidShapes = {}

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

    love.graphics.polygon("fill", poly)

    local inner = {}
    for i = 1, #poly, 2 do
        table.insert(inner, poly[i] * 0.7)
        table.insert(inner, poly[i + 1] * 0.7)
    end

    local hr = math.min((cr or 1) * 1.1, 1)
    local hg = math.min((cg or 1) * 1.1, 1)
    local hb = math.min((cb or 1) * 1.1, 1)
    local ha = (ca or 1) * 0.9
    love.graphics.setColor(hr, hg, hb, ha)
    love.graphics.polygon("fill", inner)

    local orr = (cr or 1) * 0.5
    local org = (cg or 1) * 0.5
    local orb = (cb or 1) * 0.5
    local ora = ca or 1
    local oldLineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(orr, org, orb, ora)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", poly)
    love.graphics.setLineWidth(oldLineWidth)

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

    love.graphics.polygon("fill", poly)

    local orr = (cr or 1) * 0.5
    local org = (cg or 1) * 0.5
    local orb = (cb or 1) * 0.5
    local ora = ca or 1
    local oldLineWidth = love.graphics.getLineWidth()
    love.graphics.setColor(orr, org, orb, ora)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", poly)
    love.graphics.setLineWidth(oldLineWidth)
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
    local shipData

    if type(r.type) == "table" then
        shipData = r.type
    else
        shipData = Ships[r.type]
    end

    if shipData and shipData.draw then
        shipData.draw(r.color)
    else
        local color = r.color or { 1, 1, 1 }
        love.graphics.setColor(table.unpack(color))
        love.graphics.circle("fill", 0, 0, 10)
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
