local Concord = require "lib.concord.concord"
local AsteroidChunkSpawner = require "src.ecs.spawners.asteroid_chunk"
local ItemSpawners = require "src.ecs.spawners.item"
local FloatingTextSpawner = require "src.utils.floating_text_spawner"
local Client = require "src.network.client"

local LootSystem = Concord.system({})

function LootSystem:entity_died(entity)
    local world = self:getWorld()
    if not world then return end

    -- Pure network clients (joined games) should not spawn loot/chunks; the host/server is authoritative.
    local is_pure_client = (world and not world.hosting and Client.connected)
    if is_pure_client then
        return
    end

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
        local cr = entity.chunk_resource
        if not cr then
            ItemSpawners.spawn_stone(world, t.x, t.y, s.x, s.y)
            return
        end

        local resource_type = cr.resource_type or "stone"
        local amount = cr.amount or 1

        -- Calculate volume and mass from chunk
        -- Volume is based on chunk area (using radius from render component)
        local chunk_volume = 1.0 -- Default if no render
        local chunk_mass = 0.5   -- Default if no render

        if entity.render and entity.render.radius then
            local radius = entity.render.radius
            -- Volume proportional to area (2D game, so area = pi * r^2)
            -- Scale to reasonable units: radius 10 = 1 m^3
            chunk_volume = (math.pi * radius * radius) / 100.0
            -- Mass: assume density of ~2 kg/m^3 for stone
            chunk_mass = chunk_volume * 2.0
        end

        -- Divide by amount to get per-stone volume and mass
        local stone_volume = chunk_volume / amount
        local stone_mass = chunk_mass / amount

        -- For now we only have stone items; treat any unknown type as stone
        if resource_type ~= "stone" then
            resource_type = "stone"
        end

        for i = 1, amount do
            ItemSpawners.spawn_stone(world, t.x, t.y, s.x, s.y, stone_volume, stone_mass)
        end

        local hp = entity.hp
        local killer = hp and hp.last_hit_by
        if killer and killer.level then
            local XP_PER_UNIT = 5
            local reward = math.max(1, math.floor((amount or 1) * XP_PER_UNIT))
            killer.level.xp = (killer.level.xp or 0) + reward
            if killer.transform then
                FloatingTextSpawner.spawn(world, "+" .. tostring(reward) .. " XP", killer.transform.x, killer.transform.y,
                    { 1, 1, 0, 1 })
            end
        end
    elseif entity.vehicle then
        -- Ships could drop scrap or cargo here
        --  (Future implementation)
    end
end

return LootSystem
