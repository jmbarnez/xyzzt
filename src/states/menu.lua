---@diagnostic disable: undefined-global

local Gamestate    = require "hump.gamestate"
local Utils        = require "src.utils.utils"
local Theme        = require "src.ui.theme"
local Config       = require "src.config"
local Background   = require "src.rendering.background"
local NewGameState = require "src.states.newgame"
local SaveManager  = require "src.managers.save_manager"

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local MenuState = {}

function MenuState:enter()
    -- Initialize menu state (no animated background here)

    -- Fonts
    self.fontTitle = Theme.getFont("title")
    self.fontButton = Theme.getFont("button")

    if not self.background then
        self.background = Background.new()
    end

    if not self.titleShader then
        self.titleShader = love.graphics.newShader("assets/shaders/title_aurora.glsl")
        self.shaderTime = 0
    end

    self.buttons = {
        {
            label = "NEW GAME",
            action = function()
                Gamestate.switch(NewGameState)
            end,
        },
        {
            label = "LOAD GAME",
            action = function()
                if SaveManager.has_save(1) then
                    Gamestate.switch(require("src.states.play"), { mode = "load", slot = 1 })
                end
            end,
        },
    }

    self.buttonRects = {}
    self.hoveredButton = nil
    self.activeButton = nil
    self.mouseWasDown = false
end

function MenuState:update(dt)
    if self.background then
        self.background:update(dt)
    end

    if self.titleShader then
        self.shaderTime = self.shaderTime + dt
        self.titleShader:send("time", self.shaderTime)
    end

    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()

    self.hoveredButton = nil
    for index, rect in ipairs(self.buttonRects) do
        if pointInRect(mouseX, mouseY, rect) then
            self.hoveredButton = index
            break
        end
    end

    local isDown = love.mouse.isDown(1)

    if isDown and not self.mouseWasDown then
        self.activeButton = self.hoveredButton
    elseif not isDown and self.mouseWasDown then
        if self.activeButton ~= nil and self.hoveredButton == self.activeButton then
            local button = self.buttons[self.activeButton]
            if button and button.action then
                button.action()
            end
        end

        self.activeButton = nil
    end

    if not isDown then
        self.activeButton = nil
    end

    self.mouseWasDown = isDown
end

function MenuState:updateButtonLayout()
    if not self.buttons then
        return
    end

    self.buttonRects = self.buttonRects or {}
    for index = 1, #self.buttonRects do
        self.buttonRects[index] = nil
    end

    local sw, sh = love.graphics.getDimensions()

    local spacing = Theme.spacing
    local totalHeight = #self.buttons * spacing.buttonHeight + (#self.buttons - 1) * spacing.buttonSpacing
    local startX = (sw - spacing.buttonWidth) * 0.5
    local centerY = sh * 0.5 + spacing.menuVerticalOffset
    local startY = centerY - totalHeight * 0.5

    for index = 1, #self.buttons do
        local y = startY + (index - 1) * (spacing.buttonHeight + spacing.buttonSpacing)
        self.buttonRects[index] = {
            x = startX,
            y = y,
            w = spacing.buttonWidth,
            h = spacing.buttonHeight,
        }
    end
end

function MenuState:draw()
    local sw, sh = love.graphics.getDimensions()

    -- 1. Clear to a simple background color (pitch black)
    love.graphics.clear(0, 0, 0, 1)

    if self.background then
        love.graphics.push()
        love.graphics.origin()
        self.background:draw(0, 0, 0, 0)
        love.graphics.pop()
    end

    -- 2. Draw Title "NOVUS"
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.fontTitle)
    if self.titleShader then
        love.graphics.setShader(self.titleShader)
    end
    love.graphics.printf("NOVUS", 0, sh * 0.08, sw, "center")
    love.graphics.setShader()

    self:updateButtonLayout()

    love.graphics.setFont(self.fontButton)
    local textHeight = self.fontButton:getHeight()

    for index, button in ipairs(self.buttons) do
        local rect = self.buttonRects[index]
        if rect then
            local hovered = self.hoveredButton == index

            local active = love.mouse.isDown(1) and self.activeButton == index

            local stateButton = "default"
            if active then
                stateButton = "active"
            elseif hovered then
                stateButton = "hover"
            end

            local btnFill, btnOutline = Theme.getButtonColors(stateButton)
            local btnTextColor = Theme.getButtonTextColor(stateButton)

            love.graphics.setColor(btnFill)
            love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, Theme.shapes.buttonRounding,
                Theme.shapes.buttonRounding)

            love.graphics.setColor(btnOutline)
            love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, Theme.shapes.buttonRounding,
                Theme.shapes.buttonRounding)

            love.graphics.setColor(btnTextColor)
            love.graphics.printf(
                button.label,
                rect.x,
                rect.y + (rect.h - textHeight) * 0.5,
                rect.w,
                "center"
            )
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
    if key == 'escape' then
        love.event.quit()
        return
    end
end

function MenuState:textinput(t)
end

return MenuState
