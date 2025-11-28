local Theme = require "src.ui.theme"

local HealthBar = {}

function HealthBar.draw(x, y, width, height, current, max, colorFill, colorBg, showBorder)
    local pct = 0
    if max and max > 0 then
        pct = math.max(0, math.min(1, (current or 0) / max))
    end

    local shapes = Theme.shapes
    local barRadius = shapes.healthBarCornerRadius or 3

    love.graphics.setColor(colorBg)
    love.graphics.rectangle("fill", x, y, width, height, barRadius, barRadius)

    if pct > 0 then
        love.graphics.setColor(colorFill)
        love.graphics.rectangle("fill", x, y, width * pct, height, barRadius, barRadius)
    end

    if showBorder then
        love.graphics.setColor(Theme.colors.health.border)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, width, height, barRadius, barRadius)
    end
end

return HealthBar
