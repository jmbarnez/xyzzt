local Theme = require "src.ui.theme"
local HealthBar = require "src.ui.hud.health_bar"
local HealthModel = require "src.ui.hud.health_model"

local StatusPanel = {
    _lastLevel = nil,
    _flashUntil = 0,
}

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
    local spacing = Theme.spacing
    local shapes = Theme.shapes
    local margin = spacing.hudMargin or 16
    local panelWidth = spacing.statusPanelWidth or 300
    local panelHeight = spacing.statusPanelHeight or 80
    local panelX = margin
    local panelY = margin

    local shadowOffsetX = shapes.shadowOffsetX or 3
    local shadowOffsetY = shapes.shadowOffsetY or 4
    local cornerRadius = shapes.panelCornerRadius or 4

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", panelX + shadowOffsetX, panelY + shadowOffsetY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    -- Panel Background (single solid color)
    local bg = Theme.getBackgroundColor()
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.94)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    -- Panel Outline
    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    -- Layout inside panel
    local contentPadding = spacing.panelContentPadding or 10
    local cx = panelX + contentPadding
    local cy = panelY + contentPadding
    local cw = panelWidth - contentPadding * 2
    local ch = panelHeight - contentPadding * 2

    -- Fonts
    local fontLevel = Theme.getFont("header")
    local fontLabel = Theme.getFont("chat")

    -- === LEFT: Level + XP Ring ===
    local levelRadius = spacing.hudLevelRadius or 18
    local levelCenterX = cx + levelRadius + 4
    local levelCenterY = panelY + panelHeight * 0.5

    local levelComponent = (ship and ship.level) or player.level
    local xp = levelComponent and levelComponent.xp or 0
    local nextXp = levelComponent and levelComponent.next_level_xp or 1000
    local xpRatio = 0
    if nextXp > 0 then
        xpRatio = math.max(0, math.min(1, xp / nextXp))
    end

    -- Visual mapping: keep true xpRatio for logic, but ensure even small amounts of XP
    -- produce a clearly visible fill in the ring.
    local visualRatio = xpRatio
    local minVisible = 0.08
    if xp > 0 and visualRatio < minVisible then
        visualRatio = minVisible
    end

    local currentLevel = (levelComponent and levelComponent.current) or 1
    local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0

    if StatusPanel._lastLevel and currentLevel > StatusPanel._lastLevel then
        StatusPanel._flashUntil = now + 0.4
    end
    StatusPanel._lastLevel = currentLevel

    local flashAlpha = 0
    if StatusPanel._flashUntil and now < StatusPanel._flashUntil then
        local duration = 0.4
        flashAlpha = (StatusPanel._flashUntil - now) / duration
        if flashAlpha < 0 then flashAlpha = 0 end
        if flashAlpha > 1 then flashAlpha = 1 end
    end

    -- XP Ring (background disk + vertically filling interior)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(Theme.colors.health.ringBg)
    love.graphics.circle("fill", levelCenterX, levelCenterY, levelRadius + 2)

    -- XP fill: a vertical "tank" filling inside the circle
    local xpColor = Theme.colors.health.xpFill
    local r, g, b, a = xpColor[1], xpColor[2], xpColor[3], xpColor[4] or 1.0
    local brightness = 1 + 0.6 * flashAlpha
    r = math.min(1, r * brightness)
    g = math.min(1, g * brightness)
    b = math.min(1, b * brightness)

    love.graphics.stencil(function()
        love.graphics.circle("fill", levelCenterX, levelCenterY, levelRadius)
    end, "replace", 1)
    love.graphics.setStencilTest("equal", 1)

    local diameter = levelRadius * 2
    local fillHeight = diameter * visualRatio
    local fillY = (levelCenterY + levelRadius) - fillHeight
    local fillX = levelCenterX - levelRadius
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", fillX, fillY, diameter, fillHeight)

    if fillHeight > 0 then
        local highlightHeight = math.min(fillHeight * 0.35, diameter * 0.4)
        love.graphics.setColor(1, 1, 1, 0.18 + 0.2 * flashAlpha)
        love.graphics.rectangle("fill", fillX, fillY, diameter, highlightHeight)
    end

    love.graphics.setStencilTest()

    -- Ring outline on top
    local outlineAlpha = 0.7 + 0.3 * flashAlpha
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineAlpha)
    love.graphics.circle("line", levelCenterX, levelCenterY, levelRadius)
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
    local barHeight = spacing.hudBarHeight or 12
    local barGap = spacing.hudBarGap or 7

    local bars = HealthModel.getBarsForEntity(ship or player)
    local barCount = math.min(#bars, 2)

    local barY = cy + 2
    love.graphics.setFont(fontLabel)
    for i, bar in ipairs(bars) do
        if i > barCount then break end

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

    -- Energy bar (yellow), always rendered as a third row
    local energyMax = 100
    local energyCurrent = energyMax
    if ship and ship.energy and ship.energy.max and ship.energy.current then
        energyMax = ship.energy.max
        energyCurrent = ship.energy.current
    elseif player and player.energy and player.energy.max and player.energy.current then
        energyMax = player.energy.max
        energyCurrent = player.energy.current
    end

    local energyBarY = barY
    local energyFill = Theme.colors.health.energyFill
    local energyBg = Theme.colors.health.energyBg

    HealthBar.draw(
        rightX,
        energyBarY,
        barWidth,
        barHeight,
        energyCurrent or 0,
        energyMax or 0,
        energyFill,
        energyBg,
        true
    )

    love.graphics.setLineWidth(1)
end

return StatusPanel
