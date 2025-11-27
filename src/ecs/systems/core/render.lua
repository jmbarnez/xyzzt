local Concord = require "lib.concord.concord"
local Config = require "src.config"
local RenderStrategies = require "src.ecs.systems.core.render_strategies"
local DefaultSector = require "src.data.default_sector"

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
        love.graphics.rectangle("line", -DefaultSector.SECTOR_SIZE / 2, -DefaultSector.SECTOR_SIZE / 2,
            DefaultSector.SECTOR_SIZE,
            DefaultSector.SECTOR_SIZE)

        -- Draw text at the sector boundary
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.print("SECTOR EDGE >", DefaultSector.SECTOR_SIZE / 2 - 100, 0)

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

                    local sector_offset_x = diff_x * DefaultSector.SECTOR_SIZE
                    local sector_offset_y = diff_y * DefaultSector.SECTOR_SIZE

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
                local relative_x = t.x + (diff_x * DefaultSector.SECTOR_SIZE)
                local relative_y = t.y + (diff_y * DefaultSector.SECTOR_SIZE)

                love.graphics.push()
                love.graphics.translate(relative_x, relative_y)

                love.graphics.rotate(t.r or 0)

                RenderStrategies.draw(e)

                if world and world.ui and world.ui.hover_target == e then
                    if world.debug_asteroid_overlay and e.asteroid and type(r) == "table" and r.vertices then
                        world._debug_draw_asteroid_printed = world._debug_draw_asteroid_printed or {}
                        local printed = world._debug_draw_asteroid_printed
                        local nid = e.network_id or -1
                        if nid ~= -1 and not printed[nid] then
                            local label = world.hosting and "HOST" or "CLIENT"
                            print("DRAW ASTEROID " .. label .. " id=" .. tostring(nid) .. " verts=" ..
                                table.concat(r.vertices, ","))
                            printed[nid] = true
                        end
                    end
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

                if e.vehicle and not e.ai and e.name and e.name.value then
                    local local_ship = world and world.local_ship
                    if not local_ship or e ~= local_ship then
                        local name = e.name.value
                        local font = love.graphics.getFont()
                        local text_w = font:getWidth(name)
                        local text_h = font:getHeight()
                        local radius = (r and r.radius) or 16

                        love.graphics.rotate(-(t.r or 0))
                        love.graphics.setColor(1, 1, 1, 0.9)
                        love.graphics.print(name, -text_w / 2, -(radius + text_h + 4))
                        love.graphics.rotate(t.r or 0)
                    end
                end

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
