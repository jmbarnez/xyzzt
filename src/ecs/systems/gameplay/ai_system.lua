-- AI System
-- Processes behavior trees for AI-controlled entities

local Concord = require "lib.concord.concord"
local DefaultSector = require "src.data.default_sector"

local AISystem = Concord.system({
    pool = { "ai", "transform" }
})

function AISystem:update(dt)
    local world = self:getWorld()

    local Client = require "src.network.client"

    -- AI only runs on the authority (Host or Single Player)
    -- If we are connected as a client and NOT hosting, we are a pure client -> Skip AI
    if world and Client.connected and not world.hosting then
        return
    end

    local centers = world and world.player_centers or nil
    local has_centers = centers and #centers > 0
    local max_sector_diff = 0

    for _, entity in ipairs(self.pool) do
        local ai = entity.ai

        local relevant = true
        if has_centers and entity.sector then
            relevant = false
            local esx = entity.sector.x or 0
            local esy = entity.sector.y or 0

            for _, center in ipairs(centers) do
                local csx = center.sx or 0
                local csy = center.sy or 0
                local diff_sx = esx - csx
                local diff_sy = esy - csy

                if math.abs(diff_sx) <= max_sector_diff and math.abs(diff_sy) <= max_sector_diff then
                    relevant = true
                    break
                end
            end
        end

        if not relevant then
            goto continue_ai
        end

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

        ::continue_ai::
    end
end

return AISystem
