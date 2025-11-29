local Theme = require "src.ui.theme"
local HealthBar = require "src.ui.hud.health_bar"
local HealthModel = require "src.ui.hud.health_model"
local DefaultSector = require "src.data.default_sector"

local TargetPanel = {}

function TargetPanel.draw(world, player)
    if not (world and world.ui and world.ui.hover_target) then
        return
    end

    local target = world.ui.hover_target
    if not target.transform or not target.sector then
        return
    end

    local isStation = target.station ~= nil

    local sw, sh = love.graphics.getDimensions()
    local spacing = Theme.spacing
    local shapes = Theme.shapes
    local panelWidth = spacing.targetPanelWidth or 260
    local basePanelHeight = spacing.targetPanelHeight or 64 -- Base height for generic targets
    local extraHeight = 0
    if isStation then
        -- Give stations a bit more vertical space for description/docking info
        extraHeight = spacing.targetPanelStationExtraHeight or 32
    end
    local panelHeight = basePanelHeight + extraHeight
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

    if isStation then
        local infoY = cy + textHeight + 4

        if target.station and target.station.description and target.station.description ~= "" then
            love.graphics.setColor(Theme.colors.textMuted)
            love.graphics.print(target.station.description, cx, infoY)
            infoY = infoY + textHeight
        end

        local ship = world.local_ship
        if ship and ship.transform and ship.sector and target.sector then
            local ship_sx = ship.sector.x or 0
            local ship_sy = ship.sector.y or 0
            local target_sx = target.sector.x or 0
            local target_sy = target.sector.y or 0

            local ex = target.transform.x + (target_sx - ship_sx) * DefaultSector.SECTOR_SIZE
            local ey = target.transform.y + (target_sy - ship_sy) * DefaultSector.SECTOR_SIZE

            local dx = ex - ship.transform.x
            local dy = ey - ship.transform.y
            local dist = math.sqrt(dx * dx + dy * dy)

            local dock_radius = (target.station_area and target.station_area.radius) or 0
            local inRange = (dock_radius > 0 and dist <= dock_radius)

            love.graphics.setColor(Theme.colors.textPrimary)
            local distanceText = string.format("Distance: %.0f", dist)
            if inRange then
                distanceText = distanceText .. "   [F] Dock & Resupply"
            end
            love.graphics.print(distanceText, cx, infoY)
            infoY = infoY + textHeight
        end

        barY = infoY + 4
    end

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
