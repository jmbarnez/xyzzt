local Concord = require "concord"
local EntityUtils = require "src.utils.entity_utils"

local DeathSystem = Concord.system({
    pool = { "hp" }
})

function DeathSystem:update(dt)
    local world = self:getWorld()
    
    for _, e in ipairs(self.pool) do
        if e.hp.current <= 0 then
            -- 1. Emit death event so other systems (Loot, FX) can react
            -- We pass the entity itself before it is destroyed
            world:emit("entity_died", e)
            
            -- 2. Cleanup and destroy
            EntityUtils.cleanup_physics_entity(e)
        end
    end
end

return DeathSystem