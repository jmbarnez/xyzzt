local Theme = require "src.ui.theme"

local TargetPanel = {}

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

function TargetPanel.draw(world, player)
    if not (world and world.ui and world.ui.hover_target) then
        return
    end

    local target = world.ui.hover_target
    if not target.transform or not target.sector then
        return
    end

    local sw, sh = love.graphics.getDimensions()
    local panelWidth = 260
    local panelHeight = 64 -- Slightly taller to accommodate bar comfortably
    local panelX = (sw - panelWidth) / 2
    local panelY = 16

    local bg = Theme.getBackgroundColor()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", panelX + 3, panelY + 4, panelWidth, panelHeight, 6, 6)

    love.graphics.setColor(bg[1], bg[2], bg[3], 0.96)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight, 6, 6)

    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor[1], outlineColor[2], outlineColor[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight, 6, 6)

    local contentPadding = 10
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

    -- HP Bar
    if target.hp and target.hp.max and target.hp.current then
        local barY = cy + fontTitle:getHeight() + 6
        local barHeight = 12

        -- Using Hull colors from StatusPanel for consistency
        local hpFill = { 0.95, 0.25, 0.25, 0.95 }
        local hpBg = { 0.08, 0.05, 0.07, 0.9 }

        drawBar(cx, barY, cw, barHeight, target.hp.current, target.hp.max, hpFill, hpBg, true)

        -- Optional: Draw text overlay on bar? Or just keep it clean as requested "just ... hp bar"
        -- User said "hp bar for all entities for now", implying visual.
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
