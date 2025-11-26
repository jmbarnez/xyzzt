-- AI System
-- Processes behavior trees for AI-controlled entities

local Concord = require "lib.concord.concord"

local AISystem = Concord.system({
    pool = { "ai", "transform" }
})

function AISystem:update(dt)
    local world = self:getWorld()

    -- Skip on pure clients - AI only runs on host/server
    if world and not world.hosting then
        return
    end

    for _, entity in ipairs(self.pool) do
        local ai = entity.ai

        -- Update timer
        ai.time_since_update = (ai.time_since_update or 0) + dt

        -- Only update at specified interval
        if ai.time_since_update >= ai.update_interval then
            ai.time_since_update = 0

            -- Clear input each frame to prevent stuck inputs
            if entity.input then
                entity.input.fire = false
                entity.input.move_x = 0
                entity.input.move_y = 0
            end

            -- Tick behavior tree
            if ai.behavior_tree then
                local status = ai.behavior_tree:tick(entity, dt)
                -- Store status for debugging if needed
                ai.last_status = status
            end
        end
    end
end

return AISystem
