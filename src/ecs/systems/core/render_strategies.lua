local Ships = require "src.data.ships"
local Asteroids = require "src.ecs.systems.core.render_strategies.asteroids"
local Projectiles = require "src.ecs.systems.core.render_strategies.projectiles"
local Items = require "src.ecs.systems.core.render_strategies.items"
local ShipsRender = require "src.ecs.systems.core.render_strategies.ships"

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
    Asteroids.asteroid(e)
end

function RenderStrategies.asteroid_chunk(e)
    Asteroids.asteroid_chunk(e)
end

function RenderStrategies.projectile_shard(e)
    Projectiles.projectile_shard(e)
end

function RenderStrategies.item(e)
    Items.item(e)
end

function RenderStrategies.projectile(e)
    Projectiles.projectile(e)
end

function RenderStrategies.ship(e)
    ShipsRender.ship(e)
end

function RenderStrategies.procedural(e)
    ShipsRender.procedural(e)
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
    procedural = RenderStrategies.procedural,
}

local function resolve_type_key(e)
    local r = e.render

    if type(r) == "table" and r.type then
        if r.type == "asteroid" or r.type == "asteroid_chunk" or
            r.type == "projectile_shard" or r.type == "item" or
            r.type == "projectile" or r.type == "procedural" then
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
