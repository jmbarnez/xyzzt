local Theme = require "src.ui.theme"

local PauseMenu = {}

local buttons = {
    { label = "RESUME", action = "resume" },
    { label = "MAIN MENU", action = "menu" },
}

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function getLayout()
    local sw, sh = love.graphics.getDimensions()
    local spacing = Theme.spacing
    local buttonWidth = spacing.buttonWidth
    local buttonHeight = spacing.buttonHeight
    local buttonSpacing = spacing.buttonSpacing

    local totalHeight = #buttons * buttonHeight + (#buttons - 1) * buttonSpacing
    local boxWidth = buttonWidth + 80
    local boxHeight = totalHeight + 120

    local boxX = (sw - boxWidth) * 0.5
    local boxY = (sh - boxHeight) * 0.5

    local startX = boxX + (boxWidth - buttonWidth) * 0.5
    local startY = boxY + 80

    local rects = {}
    for i = 1, #buttons do
        local y = startY + (i - 1) * (buttonHeight + buttonSpacing)
        rects[i] = {
            x = startX,
            y = y,
            w = buttonWidth,
            h = buttonHeight,
        }
    end

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        buttonRects = rects,
    }
end

function PauseMenu.draw()
    local sw, sh = love.graphics.getDimensions()
    local dim = Theme.colors.overlay.screenDim
    love.graphics.setColor(dim[1], dim[2], dim[3], dim[4] or 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local layout = getLayout()
    local boxX = layout.boxX
    local boxY = layout.boxY
    local boxWidth = layout.boxWidth
    local boxHeight = layout.boxHeight
    local buttonRects = layout.buttonRects

    local bgColor = Theme.getBackgroundColor()
    local buttonColors = Theme.colors.button
    local textPrimary = Theme.colors.textPrimary

    local rounding = Theme.shapes.buttonRounding or 0
    local outlineWidth = Theme.shapes.outlineWidth or 1.5

    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, rounding, rounding)
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.setColor(buttonColors.outline)
    love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, rounding, rounding)

    local titleFont = Theme.getFont("button")
    love.graphics.setFont(titleFont)
    local titleText = "PAUSED"
    love.graphics.setColor(textPrimary)
    love.graphics.printf(titleText, boxX, boxY + 26, boxWidth, "center")

    local mx, my = love.mouse.getPosition()
    local buttonFont = Theme.getFont("button")
    love.graphics.setFont(buttonFont)
    local textHeight = buttonFont:getHeight()

    for i, button in ipairs(buttons) do
        local rect = buttonRects[i]
        local hovered = pointInRect(mx, my, rect)

        local state = hovered and "hover" or "default"
        local fill, outline = Theme.getButtonColors(state)
        local textColor = Theme.getButtonTextColor(state)

        love.graphics.setColor(fill)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, rounding, rounding)

        love.graphics.setColor(outline)
        love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, rounding, rounding)

        love.graphics.setColor(textColor)
        love.graphics.printf(button.label, rect.x, rect.y + (rect.h - textHeight) * 0.5, rect.w, "center")
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu.mousepressed(x, y, button)
    if button ~= 1 then
        return nil
    end

    local layout = getLayout()
    local buttonRects = layout.buttonRects

    for i, rect in ipairs(buttonRects) do
        if pointInRect(x, y, rect) then
            local data = buttons[i]
            return data and data.action or nil
        end
    end

    return nil
end

return PauseMenu
