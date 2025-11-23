local Concord = require "concord"
local AsteroidChunkSpawner = require "src.ecs.spawners.asteroid_chunk"
local ItemSpawners = require "src.ecs.spawners.item"

local LootSystem = Concord.system({})

function LootSystem:entity_died(entity)
    local world = self:getWorld()
    if not world then return end
    
    local t = entity.transform
    local s = entity.sector
    
    -- Safety check
    if not (t and s) then return end

    if entity.asteroid then
        -- Asteroids split into chunks
        if entity.render then
            AsteroidChunkSpawner.spawn(world, entity)
        end
    elseif entity.asteroid_chunk then
        -- Chunks drop resources
        ItemSpawners.spawn_stone(world, t.x, t.y, s.x, s.y)
    elseif entity.vehicle then
        -- Ships could drop scrap or cargo here
        -- (Future implementation)
    end
end

return LootSystem