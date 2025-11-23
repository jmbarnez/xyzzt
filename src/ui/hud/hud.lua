local Theme = require "src.ui.theme"
local Config = require "src.config"
local StatusPanel = require "src.ui.hud.status_panel"
local CargoPanel = require "src.ui.hud.cargo_panel"

local HUD = {}

function HUD.draw(world, player)
    local sw, sh = love.graphics.getDimensions()
    
    -- Draw status panel (top-left)
    StatusPanel.draw(player)

    -- Draw cargo panel (bottom-right) when opened
    if world and world.ui and world.ui.cargo_open then
        CargoPanel.draw(world, player)
    end

    -- FPS Counter (Top Right)
    love.graphics.setColor(0.2, 1.0, 0.2, 1.0)
    love.graphics.setFont(Theme.getFont("default"))
    love.graphics.print("FPS: " .. love.timer.getFPS(), sw - 60, 10)
end

return HUD
