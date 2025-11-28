local Concord = require "lib.concord.concord"
local Config = require "src.config"

local TrailSystem = Concord.system({
    pool = { "trail", "transform", "vehicle" }
})

function TrailSystem:init()
    -- Create a shared texture for the particles (a soft glow)
    local size = 32
    local canvas = love.graphics.newCanvas(size, size)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    -- Draw a soft circle
    local radius = size / 2
    for r = radius, 0, -1 do
        local alpha = math.pow(1.0 - (r / radius), 2) -- Quadratic falloff
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", radius, radius, r)
    end

    love.graphics.setCanvas()
    self.particle_texture = love.graphics.newImage(canvas:newImageData())
end

function TrailSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local trail_comp = e.trail
        local transform = e.transform
        local vehicle = e.vehicle

        -- Emit if any movement key is pressed or if moving fast enough
        local is_moving = (e.input and (
            e.input.thrust or
            (e.input.move_x and e.input.move_x ~= 0) or
            (e.input.move_y and e.input.move_y ~= 0)
        )) or
        (vehicle and vehicle.speed and vehicle.speed > 10)

        if trail_comp.trails then
            for _, trail in ipairs(trail_comp.trails) do
                -- Initialize ParticleSystem if needed
                if not trail.particle_system then
                    local ps = love.graphics.newParticleSystem(self.particle_texture, 500)
                    ps:setParticleLifetime(trail.length * 0.5, trail.length) -- Lifetime based on trail length
                    ps:setEmissionRate(60)                                   -- Particles per second
                    ps:setSizeVariation(0.5)
                    ps:setLinearAcceleration(0, 0, 0, 0)                     -- No gravity
                    ps:setColors(
                        trail.color[1], trail.color[2], trail.color[3], 1,   -- Start color
                        trail.color[1], trail.color[2], trail.color[3], 0    -- End color (fade out)
                    )

                    -- Size over life: Start at width, shrink to 0
                    -- Particle size is a multiplier of the texture size (32)
                    local start_size = trail.width / 32
                    ps:setSizes(start_size, start_size * 0.5, 0)

                    trail.particle_system = ps
                end

                local ps = trail.particle_system

                local color = trail.color or { 0, 1, 1, 1 }
                local r = color[1] or 1
                local g = color[2] or 1
                local b = color[3] or 1
                if e.input and e.input.boost then
                    r, g, b = 0.8, 0.2, 1.0
                end
                ps:setColors(
                    r, g, b, 1,
                    r, g, b, 0
                )

                -- Calculate world position of this engine mount
                local angle = transform.r
                local cos_a = math.cos(angle)
                local sin_a = math.sin(angle)

                local world_x = transform.x + (trail.offset_x * cos_a - trail.offset_y * sin_a)
                local world_y = transform.y + (trail.offset_x * sin_a + trail.offset_y * cos_a)

                -- Update Particle System
                ps:update(dt)

                -- Move emitter to current position
                -- Note: We don't use setPosition because that moves the whole system coordinate space if we draw at (0,0).
                -- Wait, if we draw at (0,0) world space, and setPosition(world_x, world_y), then particles spawn at world_x, world_y.
                -- Existing particles stay relative to the system origin?
                -- Actually, standard behavior:
                -- If we draw(ps, 0, 0), and ps:setPosition(x, y), particles spawn at (x,y).
                -- If we move the emitter, old particles stay where they were spawned relative to the system origin (0,0).
                -- So this is exactly what we want for world-space trails.

                ps:setPosition(world_x, world_y)

                -- Emit particles if moving
                if is_moving then
                    if not ps:isActive() then
                        ps:start()
                    end
                else
                    ps:stop()
                end
            end
        end
    end
end

function TrailSystem:draw()
    -- Drawing is handled in RenderSystem
end

return TrailSystem
