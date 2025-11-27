local Items = {}

function Items.item(e)
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

return Items
