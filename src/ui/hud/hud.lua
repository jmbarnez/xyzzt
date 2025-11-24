local Theme = require "src.ui.theme"
local Config = require "src.config"
local StatusPanel = require "src.ui.hud.status_panel"
local CargoPanel = require "src.ui.hud.cargo_panel"
local TargetPanel = require "src.ui.hud.target_panel"

local HUD = {}

function HUD.draw(world, player)
    local sw, sh = love.graphics.getDimensions()

    -- Draw status panel (top-left)
    StatusPanel.draw(player)

    TargetPanel.draw(world, player)

    -- Draw cargo panel (bottom-right) when opened
    if world and world.ui and world.ui.cargo_open then
        CargoPanel.draw(world, player)
    end

    -- Draw coordinates under minimap (top-right)
    if player and player.controlling and player.controlling.entity then
        local ship = player.controlling.entity
        if ship.transform and ship.sector then
            -- Minimap config (from minimap.lua)
            local MAP_SIZE = 130
            local MAP_MARGIN = 20

            -- Position under minimap
            local coord_x = sw - MAP_SIZE - MAP_MARGIN
            local coord_y = MAP_MARGIN + MAP_SIZE + 10 -- 10px spacing below minimap

            love.graphics.setFont(Theme.getFont("default"))
            love.graphics.setColor(0.7, 0.9, 1.0, 0.9)

            -- Sector coordinates
            local sector_text = string.format("Sector: %d, %d", ship.sector.x, ship.sector.y)
            love.graphics.print(sector_text, coord_x, coord_y)

            -- Local position
            local pos_text = string.format("Pos: %.0f, %.0f", ship.transform.x, ship.transform.y)
            love.graphics.print(pos_text, coord_x, coord_y + 15)
        end
    end

    -- FPS Counter (Top Right)
    love.graphics.setColor(0.2, 1.0, 0.2, 1.0)
    love.graphics.setFont(Theme.getFont("default"))
    love.graphics.print("FPS: " .. love.timer.getFPS(), sw - 60, 10)
end

return HUD
