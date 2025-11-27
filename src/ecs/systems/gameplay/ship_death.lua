local Concord = require "lib.concord.concord"
local EntityUtils = require "src.utils/entity_utils"
local Client = require "src.network.client"
local FloatingTextSpawner = require "src.utils.floating_text_spawner"

local ShipDeathSystem = Concord.system({
    pool = { "vehicle", "hull" }
})

function ShipDeathSystem:update(dt)
    local world = self:getWorld()
    if not world then return end

    local is_pure_client = (world and not world.hosting and Client.connected)

    for _, e in ipairs(self.pool) do
        local hull = e.hull
        if hull and hull.current and hull.current <= 0 then
            local is_local_ship = (world.local_ship == e)

            if is_local_ship then
                world.player_dead = true
                if love and love.timer and love.timer.getTime then
                    world.player_death_time = love.timer.getTime()
                else
                    world.player_death_time = 0
                end
            end

            if not is_pure_client then
                if e.experience_reward and hull.last_hit_by and hull.last_hit_by.level then
                    local killer = hull.last_hit_by
                    local reward = e.experience_reward.amount
                    killer.level.xp = killer.level.xp + reward
                    if killer.transform then
                        FloatingTextSpawner.spawn(world, "+" .. tostring(reward) .. " XP", killer.transform.x, killer.transform.y, {1, 1, 0, 1})
                    end
                end

                world:emit("entity_died", e)
                EntityUtils.cleanup_physics_entity(e)

                if is_local_ship then
                    world.local_ship = nil
                end
            end
        end
    end
end

return ShipDeathSystem
