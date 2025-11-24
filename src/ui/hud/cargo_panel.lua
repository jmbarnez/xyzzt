local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"

local CargoPanel = {}

-- Cache for item icon shapes to prevent regeneration each frame
local icon_shape_cache = {}

function CargoPanel.getWindowRect(world)
    local sw, sh = love.graphics.getDimensions()

    local defaultWidth = 1260
    local defaultHeight = 780

    local ui = world and world.ui
    if ui and ui.cargo_window then
        local w = ui.cargo_window
        local x = w.x or (sw - (w.width or defaultWidth)) * 0.5
        local y = w.y or (sh - (w.height or defaultHeight)) * 0.5
        local width = w.width or defaultWidth
        local height = w.height or defaultHeight
        return x, y, width, height
    end

    local width = defaultWidth
    local height = defaultHeight
    local x = (sw - width) * 0.5
    local y = (sh - height) * 0.5

    return x, y, width, height
end

function CargoPanel.draw(world, player)
    if not player then
        return
    end

    -- Find the ship (if any)
    local ship
    if player.controlling and player.controlling.entity then
        ship = player.controlling.entity
    end

    local cargo = ship and ship.cargo or player.cargo
    if not cargo then
        return
    end

    local used = cargo.current or 0
    local capacity = cargo.capacity or 0
    local mass = cargo.mass or 0

    local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Cargo",
        bottomText = "",
        showClose = true,
    })

    -- Draw custom bottom bar with volume/mass info and capacity bar
    local bottomBar = layout.bottomBar
    local fontLabel = Theme.getFont("chat")
    love.graphics.setFont(fontLabel)

    -- Volume and mass text with proper units
    local infoText = string.format("Volume: %.1f/%.1f m³  |  Mass: %.1f kg", used, capacity, mass)
    love.graphics.setColor(Theme.colors.textPrimary or { 0.9, 0.95, 1.0, 1.0 })
    love.graphics.print(infoText, bottomBar.x + 10, bottomBar.y + 4)

    -- Capacity bar on the right side of bottom bar
    local barWidth = 150
    local barHeight = 14
    local barX = bottomBar.x + bottomBar.w - barWidth - 10
    local barY = bottomBar.y + (bottomBar.h - barHeight) * 0.5

    local pct = 0
    if capacity > 0 then
        pct = math.max(0, math.min(1, used / capacity))
    end

    -- Bar background
    love.graphics.setColor(0.08, 0.05, 0.07, 0.9)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 2, 2)

    -- Bar fill
    if pct > 0 then
        local fillColor = { 0.3, 0.8, 0.95, 0.95 }
        if pct > 0.9 then
            fillColor = { 0.95, 0.25, 0.25, 0.95 }
        elseif pct > 0.7 then
            fillColor = { 0.95, 0.7, 0.25, 0.95 }
        end
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", barX, barY, barWidth * pct, barHeight, 2, 2)
    end

    -- Bar outline
    love.graphics.setColor(0.3, 0.3, 0.35, 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 2, 2)

    -- Percentage text on bar
    local pctText = string.format("%d%%", math.floor(pct * 100))
    local pctTextW = fontLabel:getWidth(pctText)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print(pctText, barX + (barWidth - pctTextW) * 0.5, barY + 1)

    local content = layout.content
    local cx, cy, cw, ch = content.x, content.y, content.w, content.h

    local fontText = Theme.getFont("chat")
    love.graphics.setFont(fontText)

    -- Grid of item "slots" inside the content area (RuneScape-style, invisible slots)
    local items = {}
    for name, count in pairs(cargo.items or {}) do
        table.insert(items, { name = name, count = count })
    end
    table.sort(items, function(a, b) return a.name < b.name end)

    if #items == 0 then
        love.graphics.setColor(0.6, 0.6, 0.75, 1)
        love.graphics.print("Empty", cx, cy)
        return
    end

    local slotSize = 64 -- Increased from 32 to fit icon + text
    local slotGap = 8
    local cols = math.max(1, math.floor((cw + slotGap) / (slotSize + slotGap)))

    local textColor = { 0.9, 0.95, 1.0, 1.0 }
    local countColor = { 1.0, 1.0, 0.8, 1.0 } -- Slightly yellow for visibility
    local nameColor = { 0.85, 0.85, 0.85, 1.0 }

    -- Load item definitions for rendering icons
    local ItemDefinitions = require "src.data.items"

    for index, it in ipairs(items) do
        local idx = index - 1
        local col = idx % cols
        local row = math.floor(idx / cols)

        local sx = cx + col * (slotSize + slotGap)
        local sy = cy + row * (slotSize + slotGap)

        -- Stop drawing if we run out of vertical space
        if sy + slotSize > cy + ch then
            break
        end

        -- Draw slot background (subtle)
        love.graphics.setColor(0.15, 0.15, 0.2, 0.5)
        love.graphics.rectangle("fill", sx, sy, slotSize, slotSize, 2, 2)
        love.graphics.setColor(0.3, 0.3, 0.35, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", sx, sy, slotSize, slotSize, 2, 2)

        -- Draw item icon (rendered shape) in center of slot
        local item_def = ItemDefinitions[it.name:lower()]
        if item_def and item_def.render then
            love.graphics.push()
            love.graphics.translate(sx + slotSize * 0.5, sy + slotSize * 0.4) -- Center upper portion

            -- Get or generate the item shape (cached to prevent spinning)
            local cache_key = it.name:lower()
            local vertices = icon_shape_cache[cache_key]
            if not vertices then
                -- Generate once and cache it
                vertices = item_def:generate_shape()
                icon_shape_cache[cache_key] = vertices
            end

            local color = item_def.render.color or { 0.6, 0.6, 0.65, 1 }

            -- Scale up the icon for visibility
            local scale = 3.0
            love.graphics.push()
            love.graphics.scale(scale, scale)

            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            if vertices and #vertices >= 6 then
                love.graphics.polygon("fill", vertices)
                -- Draw outline
                love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, (color[4] or 1))
                love.graphics.setLineWidth(0.5)
                love.graphics.polygon("line", vertices)
            end

            love.graphics.pop()
            love.graphics.pop()
        end

        -- Draw amount in top-right corner
        local countText = tostring(it.count or 0)
        local countW = fontText:getWidth(countText)
        local countH = fontText:getHeight()

        -- Background for count to improve readability
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", sx + slotSize - countW - 4, sy + 2, countW + 4, countH + 2, 1, 1)

        love.graphics.setColor(countColor)
        love.graphics.print(countText, sx + slotSize - countW - 2, sy + 2)

        -- Draw name at bottom-center of slot
        local nameText = it.name
        local nameW = fontText:getWidth(nameText)
        local nameX = sx + (slotSize - nameW) * 0.5
        local nameY = sy + slotSize - countH - 2

        love.graphics.setColor(nameColor)
        love.graphics.print(nameText, nameX, nameY)
    end
end

return CargoPanel
