local Common = {}

function Common.hashString(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

function Common.getColorFromRender(r)
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

function Common.getRadiusFromRender(r, defaultRadius)
    local radius = defaultRadius or 10
    if type(r) == "table" and r.radius then
        radius = r.radius
    end
    return radius
end

return Common
