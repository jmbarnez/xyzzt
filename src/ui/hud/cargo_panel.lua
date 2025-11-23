local Theme = require "src.ui.theme"
local Window = require "src.ui.hud.window"

local CargoPanel = {}

-- Helper to draw a simple horizontal capacity bar
local function drawBar(x, y, width, height, current, max, colorFill, colorBg)
    local pct = 0
    if max and max > 0 then
        pct = math.max(0, math.min(1, (current or 0) / max))
    end

    love.graphics.setColor(colorBg)
    love.graphics.rectangle("fill", x, y, width, height, 0, 0)

    love.graphics.setColor(colorFill)
    love.graphics.rectangle("fill", x, y, width * pct, height, 0, 0)
end

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
    local bottomText = string.format("Cargo %d / %d", math.floor(used), math.floor(capacity))

    local wx, wy, ww, wh = CargoPanel.getWindowRect(world)

    local layout = Window.draw({
        x = wx,
        y = wy,
        width = ww,
        height = wh,
        title = "Cargo",
        bottomText = bottomText,
        showClose = true,
    })

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

    local slotSize = 32
    local slotGap = 4
    local cols = math.max(1, math.floor((cw + slotGap) / (slotSize + slotGap)))

    local textColor = { 0.9, 0.95, 1.0, 1.0 }
    local countColor = { 0.9, 0.9, 0.9, 1.0 }

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

        -- Invisible slot: only draw item representation in a notional cell
        love.graphics.setColor(textColor)
        love.graphics.print(it.name, sx, sy)

        -- Stack count in the bottom-right of the cell
        local countText = tostring(it.count or 0)
        local countW = fontText:getWidth(countText)
        local countH = fontText:getHeight()
        love.graphics.setColor(countColor)
        love.graphics.print(countText, sx + slotSize - countW - 1, sy + slotSize - countH)
    end
end

return CargoPanel
