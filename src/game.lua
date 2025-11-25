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

-- Fixed timestep physics for deterministic multiplayer synchronization
local PHYSICS_TIMESTEP = 1 / 60 -- Physics always runs at 60 Hz, regardless of FPS
local physics_accumulator = 0
local MAX_PHYSICS_STEPS = 5   -- Prevent spiral of death if game lags

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

    -- Fixed timestep physics: accumulate time and run physics in fixed increments
    physics_accumulator = physics_accumulator + dt

    local steps = 0
    while physics_accumulator >= PHYSICS_TIMESTEP and steps < MAX_PHYSICS_STEPS do
        -- Run gamestate update with FIXED timestep for deterministic physics
        Gamestate.update(PHYSICS_TIMESTEP)
        physics_accumulator = physics_accumulator - PHYSICS_TIMESTEP
        steps = steps + 1
    end

    -- If we hit max steps, discard remaining time to prevent spiral of death
    if steps >= MAX_PHYSICS_STEPS then
        physics_accumulator = 0
    end
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
