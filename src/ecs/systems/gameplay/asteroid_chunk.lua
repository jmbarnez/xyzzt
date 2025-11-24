local Concord = require "lib.concord.concord"
local EntityUtils = require "src.utils.entity_utils"

-- Asteroid chunks are gameplay entities (not just visual effects)
-- They have HP, physics, and drop items when destroyed
-- They persist until destroyed (no auto-expiry unless given a lifetime component)
local AsteroidChunkSystem = Concord.system({
    pool = { "asteroid_chunk", "physics", "transform" }
})



function AsteroidChunkSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local lifetime = e.lifetime

        -- Only process lifetime if the chunk has one (optional)
        if lifetime then
            lifetime.elapsed = lifetime.elapsed + dt

            -- Remove chunk when lifetime expires
            if lifetime.elapsed >= lifetime.duration then
                EntityUtils.cleanup_physics_entity(e)
            end
        end
    end
end

return AsteroidChunkSystem
