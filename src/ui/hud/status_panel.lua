local Theme = require "src.ui.theme"

local StatusPanel = {}

-- Compact horizontal bar (with optional border)
local function drawBar(x, y, width, height, current, max, colorFill, colorBg, showBorder)
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

    local topBarY = cy + 2
    local bottomBarY = topBarY + barHeight + barGap

    local shieldCurrent = (ship and ship.shield and ship.shield.current) or 0
    local shieldMax = (ship and ship.shield and ship.shield.max) or 0
    local hullCurrent = (ship and ship.hull and ship.hull.current) or 0
    local hullMax = (ship and ship.hull and ship.hull.max) or 0

    -- SHIELD BAR (top)
    local shieldFill = { 0.2, 0.95, 1.0, 0.95 }
    local shieldBg = { 0.04, 0.08, 0.14, 0.9 }
    drawBar(
        rightX,
        topBarY,
        barWidth,
        barHeight,
        shieldCurrent,
        shieldMax,
        shieldFill,
        shieldBg,
        true
    )

    -- Slight neon inner line for shield if any
    if shieldMax > 0 and shieldCurrent > 0 then
        local pct = math.max(0, math.min(1, shieldCurrent / shieldMax))
        love.graphics.setColor(0.5, 1.0, 1.0, 0.9)
        love.graphics.setLineWidth(1)
        local innerX = rightX + 2
        local innerY = topBarY + barHeight - 3
        local innerW = (barWidth - 4) * pct
        love.graphics.line(innerX, innerY, innerX + innerW, innerY)
    end

    -- HULL BAR (bottom)
    local hullFill = { 0.95, 0.25, 0.25, 0.95 }
    local hullBg = { 0.08, 0.05, 0.07, 0.9 }
    drawBar(
        rightX,
        bottomBarY,
        barWidth,
        barHeight,
        hullCurrent,
        hullMax,
        hullFill,
        hullBg,
        true
    )

    -- Divider ticks on bars
    local numDivisions = 8
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.setLineWidth(1)
    for i = 1, numDivisions - 1 do
        local t = i / numDivisions
        local tickX = rightX + barWidth * t
        love.graphics.line(tickX, topBarY + 2, tickX, topBarY + barHeight - 2)
        love.graphics.line(tickX, bottomBarY + 2, tickX, bottomBarY + barHeight - 2)
    end

    love.graphics.setLineWidth(1)
end

return StatusPanel
