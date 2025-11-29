local Concord = require "lib.concord.concord"
local Config = require "src.config"
local RenderStrategies = require "src.ecs.systems.core.render_strategies"
local DefaultSector = require "src.data.default_sector"

local nameFont
local trailShader

local function ensureTrailShader()
    if trailShader then
        return trailShader
    end

    local shader_path = "assets/shaders/engine_trail.glsl"
    if love.filesystem.getInfo(shader_path) then
        trailShader = love.graphics.newShader(shader_path)
    end

    return trailShader
end

local RenderSystem = Concord.system({
    drawPool = { "transform", "render", "sector" },
    cameraPool = { "input", "controlling" }
})

function RenderSystem:draw()
    local world = self:getWorld()
    local screen_w, screen_h = love.graphics.getDimensions()
    local camera = world.camera
    local shader = ensureTrailShader()
    local shaderTime = love.timer.getTime()

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

    local half_view_w, half_view_h

    -- Update HUMP Camera to the local coordinates
    if camera then
        local zoom = camera.scale or 1
        local half_size = DefaultSector.SECTOR_SIZE / 2
        half_view_w = (screen_w / 2) / zoom
        half_view_h = (screen_h / 2) / zoom

        local min_x = -half_size + half_view_w
        local max_x = half_size - half_view_w
        local min_y = -half_size + half_view_h
        local max_y = half_size - half_view_h

        if min_x > max_x then
            min_x = 0
            max_x = 0
        end

        if min_y > max_y then
            min_y = 0
            max_y = 0
        end

        if cam_x < min_x then
            cam_x = min_x
        elseif cam_x > max_x then
            cam_x = max_x
        end

        if cam_y < min_y then
            cam_y = min_y
        elseif cam_y > max_y then
            cam_y = max_y
        end

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

        if shader then
            shader:send("time", shaderTime)
            love.graphics.setBlendMode("add")
            love.graphics.setShader(shader)

            for _, e in ipairs(self.drawPool) do
                local t = e.transform
                local s = e.sector

                if not (t and s and t.x and t.y and s.x and s.y and e.trail and e.trail.trails) then
                    goto trail_continue
                end

                local diff_x = s.x - (cam_sector_x or 0)
                local diff_y = s.y - (cam_sector_y or 0)

                if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                    local sector_offset_x = diff_x * DefaultSector.SECTOR_SIZE
                    local sector_offset_y = diff_y * DefaultSector.SECTOR_SIZE

                    love.graphics.push()
                    love.graphics.translate(sector_offset_x, sector_offset_y)

                    for _, trail in ipairs(e.trail.trails) do
                        if trail.particle_system then
                            local c = trail.color or { 0, 1, 1, 1 }
                            local tr = c[1] or 1
                            local tg = c[2] or 1
                            local tb = c[3] or 1
                            if e.input and e.input.boost then
                                tr, tg, tb = 0.8, 0.2, 1.0
                            end
                            shader:send("glow_tint", { tr, tg, tb })
                            love.graphics.draw(trail.particle_system, 0, 0)
                        end
                    end

                    love.graphics.pop()
                end

                ::trail_continue::
            end

            love.graphics.setShader()
            love.graphics.setBlendMode("alpha")
        else
            love.graphics.setBlendMode("add")

            for _, e in ipairs(self.drawPool) do
                local t = e.transform
                local s = e.sector

                if not (t and s and t.x and t.y and s.x and s.y and e.trail and e.trail.trails) then
                    goto trail_continue_no_shader
                end

                local diff_x = s.x - (cam_sector_x or 0)
                local diff_y = s.y - (cam_sector_y or 0)

                if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                    local sector_offset_x = diff_x * DefaultSector.SECTOR_SIZE
                    local sector_offset_y = diff_y * DefaultSector.SECTOR_SIZE

                    love.graphics.push()
                    love.graphics.translate(sector_offset_x, sector_offset_y)

                    for _, trail in ipairs(e.trail.trails) do
                        if trail.particle_system then
                            love.graphics.draw(trail.particle_system, 0, 0)
                        end
                    end

                    love.graphics.pop()
                end

                ::trail_continue_no_shader::
            end

            love.graphics.setBlendMode("alpha")
        end

        for _, e in ipairs(self.drawPool) do
            local t = e.transform
            local s = e.sector
            local r = e.render

            if not (t and s and r and t.x and t.y and s.x and s.y) then
                goto continue
            end

            local diff_x = s.x - (cam_sector_x or 0)
            local diff_y = s.y - (cam_sector_y or 0)

            -- Optimization: Only draw entities in neighbor sectors
            if math.abs(diff_x) <= 1 and math.abs(diff_y) <= 1 then
                local relative_x = t.x + (diff_x * DefaultSector.SECTOR_SIZE)
                local relative_y = t.y + (diff_y * DefaultSector.SECTOR_SIZE)

                if camera then
                    local dx = relative_x - cam_x
                    local dy = relative_y - cam_y
                    local padding = 64
                    if math.abs(dx) > (half_view_w + padding) or math.abs(dy) > (half_view_h + padding) then
                        goto continue
                    end
                end

                love.graphics.push()
                love.graphics.translate(relative_x, relative_y)

                love.graphics.rotate(t.r or 0)

                RenderStrategies.draw(e)

                -- Draw station area
                if e.station_area then
                    love.graphics.push()
                    love.graphics.setColor(0, 0.5, 1, 0.5)
                    love.graphics.circle("line", 0, 0, e.station_area.radius, 128)
                    love.graphics.pop()
                end

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
