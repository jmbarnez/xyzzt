local Theme = require "src.ui.theme"

local Window = {}

local function computeLayout(x, y, width, height)
    local titleBarHeight = 24
    local bottomBarHeight = 22
    local padding = 8

    local titleBar = {
        x = x,
        y = y,
        w = width,
        h = titleBarHeight,
    }

    local bottomBar = {
        x = x,
        y = y + height - bottomBarHeight,
        w = width,
        h = bottomBarHeight,
    }

    local content = {
        x = x + padding,
        y = y + titleBarHeight + padding,
        w = width - padding * 2,
        h = height - titleBarHeight - bottomBarHeight - padding * 2,
    }

    local closeSize = titleBarHeight - 8
    local closeX = x + width - closeSize - 6
    local closeY = y + (titleBarHeight - closeSize) * 0.5
    local close = {
        x = closeX,
        y = closeY,
        w = closeSize,
        h = closeSize,
    }

    return {
        titleBar = titleBar,
        bottomBar = bottomBar,
        content = content,
        close = close,
    }
end

function Window.getLayout(opts)
    return computeLayout(opts.x, opts.y, opts.width, opts.height)
end

function Window.draw(opts)
    local x = opts.x or 0
    local y = opts.y or 0
    local width = opts.width or 300
    local height = opts.height or 200
    local title = opts.title or ""
    local bottomText = opts.bottomText
    local showClose = opts.showClose ~= false

    local layout = computeLayout(x, y, width, height)

    local bg = Theme.getBackgroundColor()
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.94)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)

    local _, outlineColor = Theme.getButtonColors("default")
    love.graphics.setColor(outlineColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, width, height, 4, 4)

    love.graphics.setColor(0.06, 0.08, 0.16, 1.0)
    local inset = 1
    love.graphics.rectangle(
        "fill",
        layout.titleBar.x + inset,
        layout.titleBar.y,
        layout.titleBar.w - inset * 2,
        layout.titleBar.h,
        4,
        4
    )

    love.graphics.setFont(Theme.getFont("header"))
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.print(title, layout.titleBar.x + 10, layout.titleBar.y + 4)

    love.graphics.setColor(0.06, 0.08, 0.16, 1.0)
    love.graphics.rectangle(
        "fill",
        layout.bottomBar.x + inset,
        layout.bottomBar.y,
        layout.bottomBar.w - inset * 2,
        layout.bottomBar.h,
        4,
        4
    )

    if bottomText then
        local font = Theme.getFont("chat")
        love.graphics.setFont(font)
        love.graphics.setColor(Theme.colors.textMuted)
        local textY = layout.bottomBar.y + (layout.bottomBar.h - font:getHeight()) * 0.5
        love.graphics.print(bottomText, layout.bottomBar.x + 8, textY)
    end

    if showClose then
        local r = layout.close
        love.graphics.setColor(0.16, 0.18, 0.24, 1.0)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)

        love.graphics.setColor(outlineColor)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3, 3)

        love.graphics.setColor(1.0, 0.35, 0.35, 1.0)
        love.graphics.setLineWidth(1.4)
        love.graphics.line(r.x + 3, r.y + 3, r.x + r.w - 3, r.y + r.h - 3)
        love.graphics.line(r.x + 3, r.y + r.h - 3, r.x + r.w - 3, r.y + 3)
        love.graphics.setLineWidth(1)
    end

    return layout
end

return Window
