local Screen = {}

Screen.internalWidth = 1920
Screen.internalHeight = 1080
Screen.windowWidth = 0
Screen.windowHeight = 0
Screen.scale = 1
Screen.offsetX = 0
Screen.offsetY = 0
Screen.canvas = nil

function Screen.init(internalW, internalH)
    Screen.internalWidth = internalW or Screen.internalWidth
    Screen.internalHeight = internalH or Screen.internalHeight

    if love.graphics and love.graphics.getDimensions then
        local w, h = love.graphics.getDimensions()
        Screen.windowWidth = w
        Screen.windowHeight = h
    else
        Screen.windowWidth = Screen.internalWidth
        Screen.windowHeight = Screen.internalHeight
    end

    Screen.canvas = love.graphics.newCanvas(Screen.internalWidth, Screen.internalHeight)
    Screen.resize(Screen.windowWidth, Screen.windowHeight)
end

function Screen.resize(windowW, windowH)
    if not windowW or not windowH then
        if love.graphics and love.graphics.getDimensions then
            windowW, windowH = love.graphics.getDimensions()
        else
            windowW, windowH = Screen.internalWidth, Screen.internalHeight
        end
    end

    Screen.windowWidth = windowW
    Screen.windowHeight = windowH

    local scaleX = windowW / Screen.internalWidth
    local scaleY = windowH / Screen.internalHeight
    Screen.scale = math.min(scaleX, scaleY)

    local scaledW = Screen.internalWidth * Screen.scale
    local scaledH = Screen.internalHeight * Screen.scale

    Screen.offsetX = math.floor((windowW - scaledW) / 2)
    Screen.offsetY = math.floor((windowH - scaledH) / 2)
end

function Screen.beginDraw()
    if not Screen.canvas then
        Screen.canvas = love.graphics.newCanvas(Screen.internalWidth, Screen.internalHeight)
    end

    love.graphics.push("all")
    love.graphics.setCanvas(Screen.canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()
end

function Screen.endDraw()
    love.graphics.setCanvas()
    love.graphics.pop()

    local r, g, b, a = love.graphics.getBackgroundColor()
    love.graphics.clear(r, g, b, a)

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Screen.canvas, Screen.offsetX, Screen.offsetY, 0, Screen.scale, Screen.scale)
    love.graphics.pop()
end

function Screen.windowToVirtual(x, y)
    local vx = (x - Screen.offsetX) / Screen.scale
    local vy = (y - Screen.offsetY) / Screen.scale
    return vx, vy
end

function Screen.getInternalDimensions()
    return Screen.internalWidth, Screen.internalHeight
end

return Screen
