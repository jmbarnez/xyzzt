---@diagnostic disable: undefined-global

local Gamestate    = require "lib.hump.gamestate"
local Utils        = require "src.utils.utils"
local Theme        = require "src.ui.theme"
local Config       = require "src.config"
local Background   = require "src.rendering.background"
local NewGameState = require "src.states.newgame"
local SaveManager  = require "src.managers.save_manager"

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local nameAdjectives = {
    "Swift",
    "Crimson",
    "Silent",
    "Luminous",
    "Iron",
    "Void",
    "Solar",
    "Nebula",
}

local nameNouns = {
    "Ranger",
    "Voyager",
    "Drifter",
    "Phoenix",
    "Comet",
    "Warden",
    "Nomad",
    "Specter",
}

local function randomFrom(list)
    return list[math.random(1, #list)]
end

local function generateRandomDisplayName()
    return randomFrom(nameAdjectives) .. " " .. randomFrom(nameNouns)
end

local function getJoinDialogLayout()
    local sw, sh = love.graphics.getDimensions()
    local boxWidth = 420
    local boxHeight = 250
    local boxX = (sw - boxWidth) / 2
    local boxY = (sh - boxHeight) / 2

    local labelFont = Theme.getFont("button")
    local labelH = labelFont:getHeight()

    local titleY = boxY + 20
    local ipLabelY = titleY + labelH + 10
    local ipY = ipLabelY + labelH + 6
    local nameLabelY = ipY + labelH + 16
    local nameY = nameLabelY + labelH + 6

    local ipRect = {
        x = boxX + 20,
        y = ipY,
        w = boxWidth - 40,
        h = 40,
    }

    local nameRect = {
        x = boxX + 20,
        y = nameY,
        w = boxWidth - 180,
        h = 40,
    }

    local randomBtnWidth = 140
    local randomBtnHeight = 40
    local randomRect = {
        x = boxX + boxWidth - randomBtnWidth - 20,
        y = nameY,
        w = randomBtnWidth,
        h = randomBtnHeight,
    }

    return {
        boxX = boxX,
        boxY = boxY,
        boxWidth = boxWidth,
        boxHeight = boxHeight,
        titleY = titleY,
        ipLabelY = ipLabelY,
        nameLabelY = nameLabelY,
        instructionsY = boxY + boxHeight - 40,
        ipRect = ipRect,
        nameRect = nameRect,
        randomRect = randomRect,
    }
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
            label = "JOIN GAME",
            action = function()
                self.ip_input_mode = true
                self.ip_input = "localhost"
                self.cursor_blink_time = 0
                self.cursor_visible = true
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

    -- Display name field on main menu
    self.display_name_input = Config.PLAYER_NAME or generateRandomDisplayName()
    self.editing_display_name = false

    -- IP Input state (join dialog)
    self.ip_input_mode = false
    self.ip_input = "localhost"
    self.cursor_blink_time = 0
    self.cursor_visible = true
end

function MenuState:update(dt)
    if self.background then
        self.background:update(dt)
    end

    if self.titleShader then
        self.shaderTime = self.shaderTime + dt
        self.titleShader:send("time", self.shaderTime)
    end

    -- Update cursor blink
    self.cursor_blink_time = self.cursor_blink_time + dt
    if self.cursor_blink_time >= 0.5 then
        self.cursor_visible = not self.cursor_visible
        self.cursor_blink_time = 0
    end

    self:updateButtonLayout()

    local mouseX, mouseY = love.mouse.getPosition()

    -- Don't process button hovers/clicks when IP input dialog is open
    if not self.ip_input_mode then
        self.hoveredButton = nil
        for index, rect in ipairs(self.buttonRects) do
            if pointInRect(mouseX, mouseY, rect) then
                self.hoveredButton = index
                break
            end
        end
    else
        self.hoveredButton = nil
    end

    local isDown = love.mouse.isDown(1)

    if self.ip_input_mode then
        local layout = getJoinDialogLayout()
        if isDown and not self.mouseWasDown then
            if pointInRect(mouseX, mouseY, layout.ipRect) then
                -- Focus IP field only
            end
        end
    else
        -- Handle clicks on main-menu display name field
        if isDown and not self.mouseWasDown then
            local sw, sh = love.graphics.getDimensions()
            local fieldWidth, fieldHeight = 260, 40
            local randomWidth = 140
            local totalWidth = fieldWidth + 12 + randomWidth
            local startX = (sw - totalWidth) * 0.5
            local labelFont = Theme.getFont("button")
            local labelH = labelFont:getHeight()
            local labelY = sh * 0.8
            local fieldY = labelY + labelH + 6

            local nameRect = { x = startX, y = fieldY, w = fieldWidth, h = fieldHeight }
            local randomRect = { x = startX + fieldWidth + 12, y = fieldY, w = randomWidth, h = fieldHeight }

            if pointInRect(mouseX, mouseY, nameRect) then
                self.editing_display_name = true
            elseif pointInRect(mouseX, mouseY, randomRect) then
                self.display_name_input = generateRandomDisplayName()
                Config.PLAYER_NAME = self.display_name_input
                self.editing_display_name = true
            else
                self.editing_display_name = false
            end
        end
    end

    -- Only process button clicks when dialog is NOT open
    if not self.ip_input_mode then
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

    -- Draw IP input dialog if active
    if self.ip_input_mode then
        -- Draw overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, sw, sh)

        local layout = getJoinDialogLayout()
        local boxX = layout.boxX
        local boxY = layout.boxY
        local boxWidth = layout.boxWidth
        local boxHeight = layout.boxHeight
        local rounding = Theme.shapes.buttonRounding or 0
        local outlineWidth = Theme.shapes.outlineWidth or 1.5

        local bgColor = Theme.getBackgroundColor()
        local buttonColors = Theme.colors.button
        local textPrimary = Theme.colors.textPrimary
        local textMuted = Theme.colors.textMuted

        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight, rounding, rounding)
        love.graphics.setLineWidth(outlineWidth)
        love.graphics.setColor(buttonColors.outline)
        love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight, rounding, rounding)

        -- Draw title
        love.graphics.setColor(textPrimary)
        love.graphics.setFont(self.fontButton)
        love.graphics.printf("Join Game", boxX, layout.titleY, boxWidth, "center")

        -- Draw IP label and field
        love.graphics.setColor(textMuted)
        love.graphics.printf("Server IP", boxX + 20, layout.ipLabelY, boxWidth - 40, "left")
        love.graphics.setColor(buttonColors.fill)
        love.graphics.rectangle("fill", layout.ipRect.x, layout.ipRect.y, layout.ipRect.w, layout.ipRect.h, rounding,
            rounding)
        if self.active_join_input == "ip" then
            love.graphics.setColor(buttonColors.outlineActive)
        else
            love.graphics.setColor(buttonColors.outline)
        end
        love.graphics.rectangle("line", layout.ipRect.x, layout.ipRect.y, layout.ipRect.w, layout.ipRect.h, rounding,
            rounding)

        -- Draw IP text
        love.graphics.setColor(textPrimary)
        love.graphics.printf(self.ip_input, layout.ipRect.x + 10, layout.ipRect.y + 12, layout.ipRect.w - 20, "left")
        
        -- Draw blinking cursor in IP field
        if self.cursor_visible then
            love.graphics.setColor(buttonColors.outlineActive)
            local textWidth = self.fontButton:getWidth(self.ip_input)
            love.graphics.rectangle("fill", layout.ipRect.x + 10 + textWidth + 2, layout.ipRect.y + 10, 2, 20)
        end

        -- Draw instructions
        love.graphics.setColor(textMuted)
        local smallFont = Theme.getFont("chat")
        love.graphics.setFont(smallFont)
        love.graphics.printf("Press ENTER to connect | ESC to cancel", boxX,
            layout.instructionsY, boxWidth, "center")
    end

    -- Persistent display name field at bottom center
    local sw2, sh2 = love.graphics.getDimensions()
    local fieldWidth, fieldHeight = 260, 40
    local randomWidth = 140
    local totalWidth = fieldWidth + 12 + randomWidth
    local startX = (sw2 - totalWidth) * 0.5
    local labelFont = self.fontButton
    local labelH = labelFont:getHeight()
    local labelY = sh2 * 0.8
    local fieldY = labelY + labelH + 6

    local bgColor = Theme.getBackgroundColor()
    local buttonColors = Theme.colors.button
    local textPrimary = Theme.colors.textPrimary
    local textMuted = Theme.colors.textMuted

    -- Label
    love.graphics.setFont(labelFont)
    love.graphics.setColor(textMuted)
    love.graphics.printf("Display Name", startX, labelY, totalWidth, "center")

    -- Name field
    local nameX = startX
    love.graphics.setColor(buttonColors.fill)
    love.graphics.rectangle("fill", nameX, fieldY, fieldWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)
    love.graphics.setColor(self.editing_display_name and buttonColors.outlineActive or buttonColors.outline)
    love.graphics.rectangle("line", nameX, fieldY, fieldWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)

    love.graphics.setColor(textPrimary)
    local nameText = self.display_name_input or ""
    love.graphics.printf(nameText, nameX + 10, fieldY + 12, fieldWidth - 20, "left")

    -- Randomize button
    local randomX = startX + fieldWidth + 12
    local randomFill, randomOutline = Theme.getButtonColors("default")
    love.graphics.setColor(randomFill)
    love.graphics.rectangle("fill", randomX, fieldY, randomWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)
    love.graphics.setColor(randomOutline)
    love.graphics.rectangle("line", randomX, fieldY, randomWidth, fieldHeight, Theme.shapes.buttonRounding,
        Theme.shapes.buttonRounding)
    love.graphics.setColor(textPrimary)
    love.graphics.printf("Randomize", randomX, fieldY + 12, randomWidth, "center")

    -- Caret in display name field
    if self.editing_display_name and self.cursor_visible then
        love.graphics.setColor(buttonColors.outlineActive)
        local textWidth = self.fontButton:getWidth(nameText)
        love.graphics.rectangle("fill", nameX + 10 + textWidth + 2, fieldY + 10, 2, 20)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuState:keypressed(key)
    if self.ip_input_mode then
        if key == "return" or key == "kpenter" then
            Gamestate.switch(require("src.states.play"), { mode = "join", host = self.ip_input })
        elseif key == "escape" then
            self.ip_input_mode = false
            self.ip_input = "localhost"
        elseif key == "backspace" then
            self.ip_input = string.sub(self.ip_input, 1, -2)
        end
        return
    end

    if key == 'escape' then
        love.event.quit()
        return
    end
end

function MenuState:textinput(t)
    if self.ip_input_mode then
        self.ip_input = self.ip_input .. t
        return
    end

    if self.editing_display_name then
        self.display_name_input = (self.display_name_input or "") .. t
        Config.PLAYER_NAME = self.display_name_input
    end
end

return MenuState
