-- src/game.lua
-- This is now just the entry point that registers events and starts the Menu.

local Gamestate     = require "hump.gamestate"
local Config        = require "src.config"
local MenuState     = require "src.states.menu"
local Lurker        = require "lurker"
local WeaponRegistry = require "src.managers.weapon_registry"
local Screen        = require "src.screen"

function love.load()
    -- Initialize virtual resolution (internal 1920x1080)
    Screen.init(1920, 1080)

    WeaponRegistry.load_plugins()
    
    -- Start game in Menu
    Gamestate.switch(MenuState)
end

function love.update(dt)
    Lurker.update(dt)
    Gamestate.update(dt)
end

function love.draw()
    -- Render all game content to the virtual-resolution canvas,
    -- then scale/letterbox it into the actual window.
    Screen.beginDraw()
    Gamestate.draw()
    Screen.endDraw()
end

function love.keypressed(key, scancode, isrepeat)
    Gamestate.keypressed(key, scancode, isrepeat)
end

function love.textinput(t)
    Gamestate.textinput(t)
end

-- Forward other events to Gamestate
function love.keyreleased(key, scancode)
    Gamestate.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    Gamestate.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    Gamestate.mousereleased(x, y, button, istouch, presses)
end

function love.wheelmoved(x, y)
    Gamestate.wheelmoved(x, y)
end

function love.resize(w, h)
    -- Update virtual resolution scaling when the window size changes
    Screen.resize(w, h)
    Gamestate.resize(w, h)
end

function love.focus(f)
    Gamestate.focus(f)
end

function love.quit()
    return Gamestate.quit()
end