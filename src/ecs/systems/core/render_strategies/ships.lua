local ShipsRender = {}

function ShipsRender.ship(e)
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

function ShipsRender.procedural(e)
    local r = e.render
    if not r or not r.render_data then return end

    local data = r.render_data

    -- Color tint (e.g. red for enemies, green for allies)
    local tint = r.color or { 1, 1, 1, 1 }

    -- 1. Draw Main Hull
    -- Use base color from data, tinted by entity color
    local base_color = data.base_color or { 0.5, 0.5, 0.5, 1 }
    love.graphics.setColor(
        base_color[1] * tint[1],
        base_color[2] * tint[2],
        base_color[3] * tint[3],
        base_color[4] or 1
    )

    if data.hull then
        love.graphics.polygon("fill", data.hull)

        -- Hull Outline
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", data.hull)
    end

    -- 2. Draw Panel Lines (Surface Details)
    if data.panel_lines then
        local detail_color = data.detail_color or { 0.3, 0.3, 0.3, 1 }
        love.graphics.setColor(
            detail_color[1] * tint[1],
            detail_color[2] * tint[2],
            detail_color[3] * tint[3],
            0.4
        )
        love.graphics.setLineWidth(1)
        for _, line in ipairs(data.panel_lines) do
            if line.x1 and line.y1 and line.x2 and line.y2 then
                love.graphics.line(line.x1, line.y1, line.x2, line.y2)
            end
        end
    end

    -- 3. Draw Cockpit
    if data.cockpit and #data.cockpit >= 6 then
        local accent_color = data.accent_color or { 0, 0.8, 1, 1 }

        -- Cockpit Base
        love.graphics.setColor(
            accent_color[1],
            accent_color[2],
            accent_color[3],
            0.6
        )
        love.graphics.polygon("fill", data.cockpit)

        -- Cockpit Glass Highlight
        love.graphics.setColor(0.6, 0.8, 1, 0.3)
        love.graphics.polygon("fill", data.cockpit)
    end

    -- 4. Draw Weapon Hardpoints
    if data.weapon_hardpoints then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        for _, wp in ipairs(data.weapon_hardpoints) do
            love.graphics.circle("fill", wp.x, wp.y, 1.5)
        end
    end

    love.graphics.setLineWidth(1)
end

return ShipsRender
