local Theme = require "src.ui.theme"
local HealthBar = require "src.ui.hud.health_bar"
local HealthModel = require "src.ui.hud.health_model"

local StatusPanel = {}

-- Draw the status panel in the top-left, with level on the left and bars on the right
function StatusPanel.draw(player)
    if not player then
        return
    end

    -- Find the ship (if any)
    local ship = nil
    if player.controlling and player.controlling.entity then
        ship = player.controlling.entity
    end

    -- Panel positioning (top-left)
    local sw, _ = love.graphics.getDimensions()
    local margin = 16
    local panelWidth = 300
    local panelHeight = 60
    local panelX = margin
    local panelY = margin

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", panelX + 3, panelY + 4, panelWidth, panelHeight, 6, 6)

    -- Panel Background (single solid color)
    local bg = Theme.getBackgroundColor()
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)

    -- Panel Outline
    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)

    -- Layout inside panel
    local contentPadding = 10
    local cx = panelX + contentPadding
    local cy = panelY + contentPadding
    local cw = panelWidth - contentPadding * 2
    local ch = panelHeight - contentPadding * 2

    -- Fonts
    local fontLevel = Theme.getFont("default")
    local fontLabel = Theme.getFont("chat")

    -- === LEFT: Level + XP Ring ===
    local levelRadius = 18
    local levelCenterX = cx + levelRadius + 4
    local levelCenterY = panelY + panelHeight * 0.5

    local levelComponent = (ship and ship.level) or player.level
    local xp = levelComponent and levelComponent.xp or 0
    local nextXp = levelComponent and levelComponent.next_level_xp or 1000
    local xpRatio = 0
    if nextXp > 0 then
        xpRatio = math.max(0, math.min(1, xp / nextXp))
    end

    local startAngle = -math.pi / 2
    local endAngle = startAngle + (2 * math.pi * xpRatio)

    -- XP Ring (background track)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(0.04, 0.06, 0.14, 0.9)
    love.graphics.circle("fill", levelCenterX, levelCenterY, levelRadius + 1)

    love.graphics.setColor(0.12, 0.16, 0.28, 1.0)
    love.graphics.arc("line", levelCenterX, levelCenterY, levelRadius, 0, 2 * math.pi)

    -- XP arc
    love.graphics.setColor(0.25, 0.95, 0.55, 1.0)
    love.graphics.arc("line", levelCenterX, levelCenterY, levelRadius, startAngle, endAngle)
    love.graphics.setLineWidth(1)

    -- Level text in the center
    love.graphics.setFont(fontLevel)
    love.graphics.setColor(Theme.colors.textPrimary)
    local levelValue = (levelComponent and levelComponent.current) or 1
    local levelText = tostring(levelValue)
    local textW = fontLevel:getWidth(levelText)
    local textH = fontLevel:getHeight()
    love.graphics.print(levelText, levelCenterX - textW / 2, levelCenterY - textH / 2)

    -- Divider line between level and bars
    local dividerX = levelCenterX + levelRadius + 8
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(dividerX, cy, dividerX, cy + ch)

    -- === RIGHT: Bars ===
    local rightX = dividerX + 6
    local rightWidth = panelX + panelWidth - contentPadding - rightX
    local barWidth = rightWidth
    local barHeight = 12
    local barGap = 7

    local bars = HealthModel.getBarsForEntity(ship or player)

    local barY = cy + 2
    for i, bar in ipairs(bars) do
        if i > 2 then break end
        HealthBar.draw(
            rightX,
            barY,
            barWidth,
            barHeight,
            bar.current or 0,
            bar.max or 0,
            bar.fill or { 1, 1, 1, 1 },
            bar.bg or { 0, 0, 0, 0.8 },
            true
        )
        barY = barY + barHeight + barGap
    end

    local numDivisions = 8
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.setLineWidth(1)
    for i = 1, numDivisions - 1 do
        local t = i / numDivisions
        local tickX = rightX + barWidth * t
        local firstBarY = cy + 2
        love.graphics.line(tickX, firstBarY + 2, tickX, firstBarY + barHeight - 2)
        local secondBarY = firstBarY + barHeight + barGap
        love.graphics.line(tickX, secondBarY + 2, tickX, secondBarY + barHeight - 2)
    end

    love.graphics.setLineWidth(1)
end

return StatusPanel
