local Theme = require "src.ui.theme"
local HealthBar = require "src.ui.hud.health_bar"
local HealthModel = require "src.ui.hud.health_model"

local TargetPanel = {}

function TargetPanel.draw(world, player)
    if not (world and world.ui and world.ui.hover_target) then
        return
    end

    local target = world.ui.hover_target
    if not target.transform or not target.sector then
        return
    end

    local sw, sh = love.graphics.getDimensions()
    local spacing = Theme.spacing
    local shapes = Theme.shapes
    local panelWidth = spacing.targetPanelWidth or 260
    local panelHeight = spacing.targetPanelHeight or 64 -- Slightly taller to accommodate bar comfortably
    local panelX = (sw - panelWidth) / 2
    local panelY = spacing.targetPanelOffsetY or 16

    local bg = Theme.getBackgroundColor()
    local shadowOffsetX = shapes.shadowOffsetX or 3
    local shadowOffsetY = shapes.shadowOffsetY or 4
    local cornerRadius = shapes.targetPanelCornerRadius or 6
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", panelX + shadowOffsetX, panelY + shadowOffsetY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    love.graphics.setColor(bg[1], bg[2], bg[3], 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, cornerRadius, cornerRadius)

    local contentPadding = spacing.targetPanelContentPadding or 10
    local cx = panelX + contentPadding
    local cy = panelY + contentPadding
    local cw = panelWidth - contentPadding * 2

    local fontTitle = Theme.getFont("default")

    -- Name
    local nameText
    if target.name and target.name.value and target.name.value ~= "" then
        nameText = target.name.value
    elseif target.asteroid then
        nameText = "Asteroid"
    elseif target.asteroid_chunk then
        nameText = "Asteroid Chunk"
    else
        nameText = "Target"
    end

    love.graphics.setFont(fontTitle)
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(nameText, cx, cy)

    local bars = HealthModel.getBarsForEntity(target)

    local textHeight = fontTitle:getHeight()
    local barHeight = spacing.targetPanelBarHeight or 12
    local barGap = spacing.targetPanelBarGap or 4
    local barY = cy + textHeight + 6

    for _, bar in ipairs(bars) do
        HealthBar.draw(
            cx,
            barY,
            cw,
            barHeight,
            bar.current or 0,
            bar.max or 0,
            bar.fill or { 1, 1, 1, 1 },
            bar.bg or { 0, 0, 0, 0.8 },
            true
        )
        barY = barY + barHeight + barGap
    end

    if world.debug_asteroid_overlay then
        local debugY = panelY + panelHeight - 16
        love.graphics.setFont(fontTitle)
        love.graphics.setColor(Theme.colors.textPrimary)
        local id_text = "ID: " .. tostring(target.network_id or "nil")
        local rot = (target.transform and target.transform.r) or 0
        local rot_text = string.format("Rot: %.2f", rot)
        love.graphics.print(id_text .. "  " .. rot_text, cx, debugY)
    end

    love.graphics.setLineWidth(1)
end

return TargetPanel
