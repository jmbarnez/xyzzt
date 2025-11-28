local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"

local CargoPanel = {}

-- Cache for item icon shapes to prevent regeneration each frame
local icon_shape_cache = {}

local function getOrderedItems(world, cargo)
    local items_map = {}
    for name, count in pairs(cargo.items or {}) do
        items_map[name] = count
    end

    local ordered_names = {}
    local ui = world and world.ui

    if ui then
        ui.cargo_item_order = ui.cargo_item_order or {}
        local existing_order = ui.cargo_item_order
        local present = {}

        for name, _ in pairs(items_map) do
            present[name] = true
        end

        for _, name in ipairs(existing_order) do
            if present[name] then
                table.insert(ordered_names, name)
                present[name] = nil
            end
        end

        local remaining = {}
        for name, _ in pairs(present) do
            table.insert(remaining, name)
        end
        table.sort(remaining)
        for _, name in ipairs(remaining) do
            table.insert(ordered_names, name)
        end

        ui.cargo_item_order = ordered_names
    else
        for name, _ in pairs(items_map) do
            table.insert(ordered_names, name)
        end
        table.sort(ordered_names)
    end

    local ordered_items = {}
    for _, name in ipairs(ordered_names) do
        local count = items_map[name]
        if count then
            table.insert(ordered_items, { name = name, count = count })
        end
    end

    return ordered_items
end

function CargoPanel.getWindowRect(world)
    local sw, sh = love.graphics.getDimensions()

    local spacing = Theme.spacing
    local defaultWidth = spacing.cargoWindowWidth or 720
    local defaultHeight = spacing.cargoWindowHeight or 420

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

    local spacing = Theme.spacing
    local shapes = Theme.shapes

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
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(infoText, bottomBar.x + 10, bottomBar.y + 4)

    -- Capacity bar on the right side of bottom bar
    local barWidth = spacing.cargoCapacityBarWidth or 150
    local barHeight = spacing.cargoCapacityBarHeight or 14
    local barX = bottomBar.x + bottomBar.w - barWidth - 10
    local barY = bottomBar.y + (bottomBar.h - barHeight) * 0.5

    local pct = 0
    if capacity > 0 then
        pct = math.max(0, math.min(1, used / capacity))
    end

    -- Bar background
    local cColors = Theme.colors.cargo
    love.graphics.setColor(cColors.barBackground)
    local slotCornerRadius = shapes.slotCornerRadius or 2
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, slotCornerRadius, slotCornerRadius)

    -- Bar fill
    if pct > 0 then
        local fillColor = cColors.barFill
        if pct > 0.9 then
            fillColor = cColors.barFillCritical
        elseif pct > 0.7 then
            fillColor = cColors.barFillWarning
        end
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", barX, barY, barWidth * pct, barHeight, slotCornerRadius, slotCornerRadius)
    end

    -- Bar outline
    love.graphics.setColor(cColors.barOutline)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight, slotCornerRadius, slotCornerRadius)

    -- Percentage text on bar
    local pctText = string.format("%d%%", math.floor(pct * 100))
    local pctTextW = fontLabel:getWidth(pctText)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.print(pctText, barX + (barWidth - pctTextW) * 0.5, barY + 1)

    local content = layout.content
    local cx, cy, cw, ch = content.x, content.y, content.w, content.h

    local fontText = Theme.getFont("chat")
    love.graphics.setFont(fontText)

    local ui = world and world.ui
    if ui then
        ui.cargo_slots = {}
    end

    -- Grid of item "slots" inside the content area (RuneScape-style, invisible slots)
    local items = getOrderedItems(world, cargo)

    if #items == 0 then
        love.graphics.setColor(Theme.colors.textMuted)
        love.graphics.print("Empty", cx, cy)
        return
    end

    local slotSize = spacing.cargoSlotSize or 64 -- Increased from 32 to fit icon + text
    local slotGap = spacing.cargoSlotGap or 8
    local cols = math.max(1, math.floor((cw + slotGap) / (slotSize + slotGap)))

    -- Load item definitions for rendering icons
    local ItemDefinitions = require "src.data.items"

    local drag = ui and ui.cargo_item_drag
    local drag_index = drag and drag.active and drag.index or nil
    local drag_item = nil

    local function drawItem(it, sx, sy)
        love.graphics.setColor(cColors.slotBackground)
        love.graphics.rectangle("fill", sx, sy, slotSize, slotSize, slotCornerRadius, slotCornerRadius)

        local item_def = ItemDefinitions[it.name:lower()]
        if item_def and item_def.render then
            love.graphics.push()
            love.graphics.translate(sx + slotSize * 0.5, sy + slotSize * 0.4)

            local cache_key = it.name:lower()
            local vertices = icon_shape_cache[cache_key]
            if not vertices then
                vertices = item_def:generate_shape()
                icon_shape_cache[cache_key] = vertices
            end

            local color = item_def.render.color or { 0.6, 0.6, 0.65, 1 }

            local scale = 3.0
            love.graphics.push()
            love.graphics.scale(scale, scale)

            love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
            if vertices and #vertices >= 6 then
                love.graphics.polygon("fill", vertices)
                love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, (color[4] or 1))
                love.graphics.setLineWidth(0.5)
                love.graphics.polygon("line", vertices)
            end

            love.graphics.pop()
            love.graphics.pop()
        end

        local countText = tostring(it.count or 0)
        local countW = fontText:getWidth(countText)
        local countH = fontText:getHeight()

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", sx + slotSize - countW - 4, sy + 2, countW + 4, countH + 2, 1, 1)

        love.graphics.setColor(cColors.textCount)
        love.graphics.print(countText, sx + slotSize - countW - 2, sy + 2)

        local nameText = it.name
        local nameW = fontText:getWidth(nameText)
        local nameX = sx + (slotSize - nameW) * 0.5
        local nameY = sy + slotSize - countH - 2

        love.graphics.setColor(cColors.textName)
        love.graphics.print(nameText, nameX, nameY)
    end

    for index, it in ipairs(items) do
        local idx = index - 1
        local col = idx % cols
        local row = math.floor(idx / cols)

        local sx = cx + col * (slotSize + slotGap)
        local sy = cy + row * (slotSize + slotGap)

        if sy + slotSize > cy + ch then
            break
        end

        if ui and ui.cargo_slots then
            ui.cargo_slots[index] = { x = sx, y = sy, w = slotSize, h = slotSize, item = it }
        end

        if drag_index == index then
            drag_item = it
        else
            drawItem(it, sx, sy)
        end
    end

    if drag and drag.active and drag_item and drag_index then
        local mx, my = love.mouse.getPosition()
        local sx = mx - (drag.offset_x or (slotSize * 0.5))
        local sy = my - (drag.offset_y or (slotSize * 0.5))
        drawItem(drag_item, sx, sy)
    end
end

function CargoPanel.update(dt, world)
    local ui = world and world.ui
    if ui and ui.cargo_drag and ui.cargo_drag.active and ui.cargo_open then
        local mx, my = love.mouse.getPosition()
        local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

        local drag = ui.cargo_drag
        local new_x = mx - drag.offset_x
        local new_y = my - drag.offset_y

        local sw, sh = love.graphics.getDimensions()
        new_x = math.max(0, math.min(new_x, sw - ww))
        new_y = math.max(0, math.min(new_y, sh - wh))

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.x = new_x
        ui.cargo_window.y = new_y
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
        return true
    end
    return false
end

function CargoPanel.mousepressed(x, y, button, world)
    if button ~= 1 then return false end
    if not (world and world.ui and world.ui.cargo_open) then return false end

    local wx, wy, ww, wh = CargoPanel.getWindowRect(world)
    local layout = Window.getLayout({ x = wx, y = wy, width = ww, height = wh })
    local r = layout.close

    -- Close button
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        world.ui.cargo_open = false
        if world.ui.cargo_drag then
            world.ui.cargo_drag.active = false
        end
        return true -- Consumed
    end

    -- Begin dragging when clicking the title bar (excluding close button)
    local tb = layout.titleBar
    if x >= tb.x and x <= tb.x + tb.w and y >= tb.y and y <= tb.y + tb.h then
        local ui = world.ui
        ui.cargo_drag = ui.cargo_drag or {}
        ui.cargo_drag.active = true
        ui.cargo_drag.offset_x = x - wx
        ui.cargo_drag.offset_y = y - wy

        ui.cargo_window = ui.cargo_window or {}
        ui.cargo_window.width = ww
        ui.cargo_window.height = wh
        return true -- Consumed
    end

    local ui = world.ui
    if ui and ui.cargo_slots then
        for index, slot in ipairs(ui.cargo_slots) do
            if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
                ui.cargo_item_drag = ui.cargo_item_drag or {}
                ui.cargo_item_drag.active = true
                ui.cargo_item_drag.index = index
                ui.cargo_item_drag.item_name = slot.item and slot.item.name or nil
                ui.cargo_item_drag.offset_x = x - slot.x
                ui.cargo_item_drag.offset_y = y - slot.y
                return true
            end
        end
    end

    return false
end

function CargoPanel.mousereleased(x, y, button, world)
    if button ~= 1 then return false end
    if not (world and world.ui) then return false end

    local ui = world.ui
    local consumed = false

    if ui.cargo_item_drag and ui.cargo_item_drag.active then
        local drag = ui.cargo_item_drag
        local slots = ui.cargo_slots or {}
        local order = ui.cargo_item_order or {}

        local target_index
        for index, slot in ipairs(slots) do
            if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
                target_index = index
                break
            end
        end

        local from_index = drag.index
        if target_index and from_index and from_index ~= target_index and order[from_index] then
            local name = table.remove(order, from_index)
            if name then
                if target_index > #order + 1 then
                    target_index = #order + 1
                end
                table.insert(order, target_index, name)
            end
        end

        drag.active = false
        drag.index = nil
        drag.item_name = nil
        consumed = true
    end

    if ui.cargo_drag and ui.cargo_drag.active then
        ui.cargo_drag.active = false
        consumed = true
    end

    if consumed then
        return true
    end

    return false
end

return CargoPanel
