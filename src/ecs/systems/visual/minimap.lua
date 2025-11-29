-- src/systems/minimap.lua
local Concord       = require "lib.concord.concord"
local Config        = require "src.config"
local DefaultSector = require "src.data.default_sector"

local MinimapSystem = Concord.system({
    -- Entities to draw on the minimap
    drawPool = { "transform", "render" },
    -- Entities to track for the camera center (usually the player)
    cameraPool = { "input", "controlling" }
})

-- Minimap Configuration
local MAP_SIZE      = 130 -- Size of the minimap in pixels (square)
local MAP_MARGIN    = 20  -- Margin from the top-right corner
local ZOOM_LEVEL    = 0.1 -- Scale factor (how much world area is shown)
local CORNER_RADIUS = 12  -- Radius for rounded corners
local BORDER_COLOR  = { 1, 1, 1, 0.65 }
local BG_COLOR      = { 0.01, 0.015, 0.035, 1.0 }

function MinimapSystem:init()
    self._canvas = nil
    self._accumulator = 0
    self._dirty = true
end

function MinimapSystem:update(dt)
    self._accumulator = (self._accumulator or 0) + dt
    if self._accumulator >= 0.1 then
        self._accumulator = 0
        self._dirty = true
    end
end

function MinimapSystem:draw()
    local screen_w, screen_h = love.graphics.getDimensions()

    -- 1. Define Minimap Position
    local map_x = screen_w - MAP_SIZE - MAP_MARGIN
    local map_y = MAP_MARGIN

    -- 2. Find Camera Center (Player Position)
    local cam_x, cam_y = 0, 0
    local cam_sector_x, cam_sector_y = 0, 0

    local target_entity = nil
    for _, e in ipairs(self.cameraPool) do
        if e.controlling and e.controlling.entity then
            target_entity = e.controlling.entity
            break
        elseif e.transform then -- Fallback
            target_entity = e
            break
        end
    end
    if target_entity and target_entity.transform then
        cam_x = target_entity.transform.x
        cam_y = target_entity.transform.y
        if target_entity.sector then
            cam_sector_x = target_entity.sector.x
            cam_sector_y = target_entity.sector.y
        end
    end

    if not self._canvas then
        self._canvas = love.graphics.newCanvas(MAP_SIZE, MAP_SIZE)
        self._dirty = true
    end

    if self._dirty then
        local previousCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(self._canvas)
        love.graphics.clear(0, 0, 0, 0)

        love.graphics.push()
        love.graphics.origin()

        love.graphics.setColor(BG_COLOR)
        love.graphics.rectangle("fill", 0, 0, MAP_SIZE, MAP_SIZE, CORNER_RADIUS, CORNER_RADIUS)

        love.graphics.setColor(BORDER_COLOR)
        love.graphics.setLineWidth(1.5)
        love.graphics.rectangle("line", 0, 0, MAP_SIZE, MAP_SIZE, CORNER_RADIUS, CORNER_RADIUS)

        local center_x = MAP_SIZE / 2
        local center_y = MAP_SIZE / 2

        for _, e in ipairs(self.drawPool) do
            if not e.projectile then
                local is_asteroid = e.asteroid or e.asteroid_chunk
                local is_ship = e.vehicle

                if is_asteroid or is_ship then
                    local t = e.transform
                    local s = e.sector or { x = 0, y = 0 }

                    local diff_sector_x = s.x - cam_sector_x
                    local diff_sector_y = s.y - cam_sector_y

                    local world_diff_x = (t.x - cam_x) + (diff_sector_x * DefaultSector.SECTOR_SIZE)
                    local world_diff_y = (t.y - cam_y) + (diff_sector_y * DefaultSector.SECTOR_SIZE)

                    local draw_x = center_x + (world_diff_x * ZOOM_LEVEL)
                    local draw_y = center_y + (world_diff_y * ZOOM_LEVEL)

                    if draw_x > 0 and draw_x < MAP_SIZE and
                        draw_y > 0 and draw_y < MAP_SIZE then
                        if e.asteroid or e.asteroid_chunk then
                            love.graphics.setColor(0.6, 0.6, 0.6, 1)
                            love.graphics.circle("fill", draw_x, draw_y, 3)
                        elseif e.vehicle then
                            if e == target_entity then
                                love.graphics.setColor(0, 1, 0, 1)
                            else
                                love.graphics.setColor(1, 0, 0, 1)
                            end
                            love.graphics.circle("fill", draw_x, draw_y, 4)
                        end
                    end
                end
            end
        end

        love.graphics.pop()
        love.graphics.setCanvas(previousCanvas)

        self._dirty = false
    end

    love.graphics.setColor(1, 1, 1, 1)
    if self._canvas then
        love.graphics.draw(self._canvas, map_x, map_y)
    end
end

return MinimapSystem
