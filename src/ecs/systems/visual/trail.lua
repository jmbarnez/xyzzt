local Concord = require "concord"
local Config = require "src.config"

local TrailSystem = Concord.system({
    pool = { "trail", "transform", "vehicle" }
})

function TrailSystem:init()
    self.shader = love.graphics.newShader("assets/shaders/engine_trail.glsl")
end

function TrailSystem:update(dt)
    local time = love.timer.getTime()

    if self.shader then
        self.shader:send("time", time)
    end

    for _, e in ipairs(self.pool) do
        local trail = e.trail
        local transform = e.transform
        local vehicle = e.vehicle

        -- Only add points if moving (or maybe always to show idle engine?)
        -- For now, let's add points if thrusting or moving fast enough
        local is_moving = (e.input and e.input.thrust) or (vehicle and vehicle.speed and vehicle.speed > 10)

        -- Calculate rear of the ship based on rotation
        -- Assuming ship radius is roughly 10-15, engine is at the back
        local offset_dist = 15
        local angle = transform.r
        local rear_x = transform.x - math.cos(angle) * offset_dist
        local rear_y = transform.y - math.sin(angle) * offset_dist

        -- Add new point
        table.insert(trail.points, 1, {
            x = rear_x,
            y = rear_y,
            time = time,
            angle = angle
        })

        -- Remove old points
        for i = #trail.points, 1, -1 do
            local p = trail.points[i]
            if time - p.time > trail.length then
                table.remove(trail.points, i)
            end
        end

        -- Update Mesh
        if #trail.points >= 2 then
            local vertices = {}

            for i, p in ipairs(trail.points) do
                local age = time - p.time
                local life_pct = age / trail.length

                -- Texture coordinates: u = life_pct (0 at head, 1 at tail)
                local u = life_pct

                -- Width tapers slightly at the end?
                local w = trail.width * (1.0 - life_pct * 0.5)

                -- Perpendicular vector for width
                -- Use the point's angle (direction of ship when point was created)
                -- Or calculate normal from path? Path normal is smoother for curves.
                local perp_x, perp_y

                if i < #trail.points then
                    local next_p = trail.points[i + 1]
                    local dx = next_p.x - p.x
                    local dy = next_p.y - p.y
                    local len = math.sqrt(dx * dx + dy * dy)
                    if len > 0 then
                        perp_x = -dy / len
                        perp_y = dx / len
                    else
                        perp_x = -math.sin(p.angle)
                        perp_y = math.cos(p.angle)
                    end
                else
                    perp_x = -math.sin(p.angle)
                    perp_y = math.cos(p.angle)
                end

                -- Left vertex
                table.insert(vertices, {
                    p.x + perp_x * w * 0.5,
                    p.y + perp_y * w * 0.5,
                    u, 0,      -- u, v
                    1, 1, 1, 1 -- r, g, b, a
                })

                -- Right vertex
                table.insert(vertices, {
                    p.x - perp_x * w * 0.5,
                    p.y - perp_y * w * 0.5,
                    u, 1, -- u, v
                    1, 1, 1, 1
                })
            end

            -- Create or update mesh
            -- We need a strip of triangles
            -- Vertices are arranged: L1, R1, L2, R2, ...
            -- Love2D "strip" draw mode works with this order

            if not trail.mesh then
                trail.mesh = love.graphics.newMesh(vertices, "strip", "dynamic")
                trail.mesh:setTexture(love.graphics.newCanvas(1, 1)) -- Dummy texture
            else
                -- Check if we need to resize (recreate) the mesh
                if #vertices > trail.mesh:getVertexCount() then
                    trail.mesh = love.graphics.newMesh(vertices, "strip", "dynamic")
                    trail.mesh:setTexture(love.graphics.newCanvas(1, 1))
                else
                    trail.mesh:setVertices(vertices)
                    trail.mesh:setDrawRange(1, #vertices)
                end
            end
        end
    end
end

function TrailSystem:draw()
    -- Drawing is handled in RenderSystem via RenderStrategies usually,
    -- but since this is a visual system, maybe it can draw itself?
    -- The RenderSystem architecture seems to handle all drawing.
    -- We should probably expose the mesh to the RenderSystem.
    -- However, RenderStrategies.ship is where we want to attach this.
    -- Or we can have a separate RenderStrategies.trail?
    -- Let's stick to updating the mesh here, and drawing in RenderStrategies.
end

return TrailSystem
