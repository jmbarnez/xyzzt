local Concord = require "concord"

local PlayerControlSystem = Concord.system({
    pool = { "input", "pilot" } -- Only entities marked as controlled by the local pilot
})

function PlayerControlSystem:update(dt)
    local world = self:getWorld()
    
    -- 1. Check if Controls are active/exists
    if not world.controls or world.controlsEnabled == false then return end
    world.controls:update(dt)

    -- 2. Map Hardware -> Intent
    for _, e in ipairs(self.pool) do
        local input = e.input
        local transform = e.transform

        -- Digital movement (WASD / Arrows)
        local move_left  = world.controls:down("move_left") and 1 or 0
        local move_right = world.controls:down("move_right") and 1 or 0
        local move_up    = world.controls:down("move_up") and 1 or 0
        local move_down  = world.controls:down("move_down") and 1 or 0

        input.move_x = move_right - move_left
        input.move_y = move_down - move_up
        input.thrust = (move_up == 1)
        
        -- Actions
        input.fire = world.controls:down("fire")
        
        -- Mouse Aiming
        if transform then
            local mx, my = love.mouse.getPosition()
            local wx, wy = mx, my
            
            -- Convert screen to world coordinates if camera exists
            if world.camera and world.camera.worldCoords then
                local screen_w, screen_h = love.graphics.getDimensions()
                wx, wy = world.camera:worldCoords(mx, my, 0, 0, screen_w, screen_h)
            end

            -- Calculate target angle
            local dx = wx - transform.x
            local dy = wy - transform.y
            input.target_angle = math.atan2(dy, dx)
        end
    end
end

return PlayerControlSystem