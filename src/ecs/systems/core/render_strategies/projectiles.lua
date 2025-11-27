local Projectiles = {}

function Projectiles.projectile_shard(e)
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

function Projectiles.projectile(e)
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

return Projectiles
