local Concord = require "concord"
local Config = require "src.config"
local RenderStrategies = require "src.ecs.systems.core.render_strategies"

local nameFont
local trailShader

local RenderSystem = Concord.system({
    drawPool = { "transform", "render", "sector" },
    cameraPool = { "input", "controlling" }
})

function RenderSystem:draw()
    local world = self:getWorld()
    local screen_w, screen_h = love.graphics.getDimensions()
    local camera = world.camera

    -- 1. Find Camera Focus & Sector
    local cam_x, cam_y = 0, 0
    local cam_sector_x, cam_sector_y = 0, 0

    -- Find the target entity (Pilot or Ship)
    local target_entity = nil
    for _, e in ipairs(self.cameraPool) do
        if e.controlling and e.controlling.entity then
            target_entity = e.controlling.entity
            break
        elseif e.transform then
            target_entity = e
            break
        end
    end

    if target_entity and target_entity.transform and target_entity.sector then
        cam_x = target_entity.transform.x
        cam_y = target_entity.transform.y
        cam_sector_x = target_entity.sector.x or 0
        cam_sector_y = target_entity.sector.y or 0
    end

    -- Update HUMP Camera to the local coordinates
    if camera then
        camera:lookAt(cam_x, cam_y)
    end

    -- 2. Draw Background (Nebula + Stars)
    love.graphics.push()
    love.graphics.origin()
    if world.background then
        world.background:draw(cam_x, cam_y, cam_sector_x, cam_sector_y)
    end
    love.graphics.pop()

    -- 3. Draw World Content
    local function draw_world_content()
        -- Draw visual boundaries of the CURRENT sector (Debug Visual)
        love.graphics.setColor(0.1, 0.1, 0.1, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", -Config.SECTOR_SIZE / 2, -Config.SECTOR_SIZE / 2, Config.SECTOR_SIZE,
            Config.SECTOR_SIZE)

        -- Draw text at the sector boundary
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.print("SECTOR EDGE >", Config.SECTOR_SIZE / 2 - 100, 0)

        for _, e in ipairs(self.drawPool) do
            local t = e.transform
            local s = e.sector
            local r = e.render

            if not (t and s and r and t.x and t.y and s.x and s.y) then
                goto continue
            end


            -- Calculate Sector Difference
            local diff_x = s.x - (cam_sector_x or 0)
            local diff_y = s.y - (cam_sector_y or 0)

            -- Optimization: Only draw entities in neighbor sectors
            if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                -- Draw Trails (World Space)
                if e.trail and e.trail.trails then
                    -- We don't need the shader for particles (they use their own texture/colors)
                    -- But we do need to handle the coordinate system.
                    -- The particle systems are updated in World Space (emitters moved to world pos).
                    -- So we should draw them at (0,0) relative to the sector offset.

                    local sector_offset_x = diff_x * Config.SECTOR_SIZE
                    local sector_offset_y = diff_y * Config.SECTOR_SIZE

                    love.graphics.push()
                    love.graphics.translate(sector_offset_x, sector_offset_y)

                    -- Additive blending for glowing effect
                    love.graphics.setBlendMode("add")

                    for _, trail in ipairs(e.trail.trails) do
                        if trail.particle_system then
                            love.graphics.draw(trail.particle_system, 0, 0)
                        end
                    end

                    love.graphics.setBlendMode("alpha")
                    love.graphics.pop()
                end

                -- Calculate Relative Position to Camera's Sector
                local relative_x = t.x + (diff_x * Config.SECTOR_SIZE)
                local relative_y = t.y + (diff_y * Config.SECTOR_SIZE)

                love.graphics.push()
                love.graphics.translate(relative_x, relative_y)

                -- Health bar rendering for ALL entities with hp component (before rotation)
                if e.hp and e.hp.max and e.hp.current and e.hp.current < e.hp.max and e.hp.last_hit_time then
                    local now = (love and love.timer and love.timer.getTime) and love.timer.getTime() or nil
                    if now then
                        local elapsed = now - (e.hp.last_hit_time or 0)
                        local visible_duration = 2.0
                        if elapsed >= 0 and elapsed <= visible_duration then
                            local pct = 0
                            if e.hp.max > 0 then
                                pct = math.max(0, math.min(1, e.hp.current / e.hp.max))
                            end

                            -- Determine entity radius for bar sizing
                            local entity_radius = 10 -- default
                            if type(r) == "table" and r.radius then
                                entity_radius = r.radius
                            end

                            local bar_width = entity_radius * 2
                            local bar_height = 4
                            local y_offset = -entity_radius - 10

                            love.graphics.setColor(0, 0, 0, 0.7)
                            love.graphics.rectangle("fill", -bar_width * 0.5, y_offset, bar_width, bar_height, 2, 2)

                            love.graphics.setColor(1.0, 0.9, 0.25, 1.0)
                            love.graphics.rectangle("fill", -bar_width * 0.5, y_offset, bar_width * pct, bar_height, 2, 2)

                            love.graphics.setColor(0, 0, 0, 1.0)
                            love.graphics.rectangle("line", -bar_width * 0.5, y_offset, bar_width, bar_height, 2, 2)
                        end
                    end
                end

                love.graphics.rotate(t.r or 0)

                RenderStrategies.draw(e)

                if world and world.ui and world.ui.hover_target == e then
                    -- Bright Cyan Outline
                    love.graphics.setColor(0, 1, 1, 1)
                    love.graphics.setLineWidth(2) -- Slightly thicker for visibility

                    if type(r) == "table" then
                        if r.vertices then
                            love.graphics.polygon("line", r.vertices)
                        elseif r.shape then
                            love.graphics.polygon("line", r.shape)
                        elseif r.shapes then
                            for _, shape in ipairs(r.shapes) do
                                if shape.type == "polygon" and shape.points then
                                    love.graphics.polygon("line", shape.points)
                                elseif shape.type == "circle" then
                                    local cx = shape.x or 0
                                    local cy = shape.y or 0
                                    local rad = shape.radius or 2
                                    love.graphics.circle("line", cx, cy, rad)
                                end
                            end
                        end
                    end

                    love.graphics.setLineWidth(1)
                end

                -- Debug: Draw a small red dot at the center to ensure it's being drawn at all
                -- love.graphics.setColor(1, 0, 0, 1)
                -- love.graphics.circle("fill", 0, 0, 2)

                love.graphics.pop()
            end

            ::continue::
        end
    end

    -- 4. Execute World Draw
    if camera then
        camera:draw(draw_world_content)
    else
        draw_world_content()
    end
end

return RenderSystem
