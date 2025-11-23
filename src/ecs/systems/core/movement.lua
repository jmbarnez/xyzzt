local Concord = require "concord"
local MathUtils = require "src.utils.math_utils"

local MovementSystem = Concord.system({
    pool = { "input", "physics", "vehicle", "transform" }
})

function MovementSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local input = e.input
        local body = e.physics.body
        local stats = e.vehicle
        local trans = e.transform

        local current_angle = body:getAngle()

        -- 1. Handle Rotation (Target Angle vs Direct Turn)
        if input.target_angle then
            local desired = input.target_angle
            local diff = MathUtils.angle_difference(current_angle, desired)

            -- Cap rotation speed
            local max_step = stats.turn_speed * dt
            diff = MathUtils.clamp(diff, -max_step, max_step)

            current_angle = current_angle + diff
            body:setAngle(current_angle)
        elseif input.turn and input.turn ~= 0 then
            current_angle = current_angle + input.turn * stats.turn_speed * dt
            body:setAngle(current_angle)
        end

        -- 2. Handle Movement (absolute screen directions, rotation-independent)
        local fx, fy = 0, 0
        if input.move_x and input.move_y and (input.move_x ~= 0 or input.move_y ~= 0) then
            -- Absolute movement (WASD moves up/left/down/right regardless of ship rotation)
            local len = math.sqrt(input.move_x * input.move_x + input.move_y * input.move_y)
            if len > 0 then
                local nx = input.move_x / len
                local ny = input.move_y / len

                fx = nx * stats.thrust
                fy = ny * stats.thrust
            end
        end

        -- Apply Force
        if fx ~= 0 or fy ~= 0 then
            body:applyForce(fx, fy)
        end

        -- 3. Cap Max Speed
        local vx, vy = body:getLinearVelocity()
        local speed_sq = vx * vx + vy * vy
        if speed_sq > (stats.max_speed * stats.max_speed) then
            local speed = math.sqrt(speed_sq)
            local scale = stats.max_speed / speed
            body:setLinearVelocity(vx * scale, vy * scale)
        end

        -- 4. Sync Transform
        trans.r = body:getAngle()
    end
end

return MovementSystem
