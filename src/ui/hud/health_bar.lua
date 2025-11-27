local HealthBar = {}

function HealthBar.draw(x, y, width, height, current, max, colorFill, colorBg, showBorder)
    local pct = 0
    if max and max > 0 then
        pct = math.max(0, math.min(1, (current or 0) / max))
    end

    love.graphics.setColor(colorBg)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)

    if pct > 0 then
        love.graphics.setColor(colorFill)
        love.graphics.rectangle("fill", x, y, width * pct, height, 3, 3)
    end

    if showBorder then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, width, height, 3, 3)
    end
end

return HealthBar
