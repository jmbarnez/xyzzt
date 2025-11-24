-- src/game.lua
-- This is now just the entry point that registers events and starts the Menu.

local Gamestate      = require "lib.hump.gamestate"
local Config         = require "src.config"
local MenuState      = require "src.states.menu"
local WeaponRegistry = require "src.managers.weapon_registry"

-- Only load lurker in development (not in .love builds)
local Lurker
if not love.filesystem.isFused() then
    local source = love.filesystem.getSource()
    -- Check if we're running from a .love file
    if not source:match("%.love$") then
        Lurker = require "lib.lurker"
    end
end

function love.load()
    -- Initialize game and load plugins
    WeaponRegistry.load_plugins()

    -- Start game in Menu
    Gamestate.switch(MenuState)
end

function love.update(dt)
    -- Only update lurker if it's loaded (development mode)
    if Lurker then
        Lurker.update(dt)
    end
    Gamestate.update(dt)
end

function love.draw()
    -- Render all game content directly to the window.
    Gamestate.draw()
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
    -- Forward resize events to the current Gamestate
    Gamestate.resize(w, h)
end

function love.focus(f)
    Gamestate.focus(f)
end

function love.quit()
    return Gamestate.quit()
end
