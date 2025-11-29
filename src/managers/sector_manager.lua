local DefaultSector = require "src.data.default_sector"
local Config = require "src.config"
local Asteroids = require "src.ecs.spawners.asteroid"
local EnemySpawner = require "src.ecs.spawners.enemy"

local SectorManager = {}

local function sector_key(sx, sy)
    return tostring(sx or 0) .. "," .. tostring(sy or 0)
end

local function ensure_loaded_table(world)
    world.loaded_sectors = world.loaded_sectors or {}
    return world.loaded_sectors
end

function SectorManager.ensure_sector_loaded(world, sx, sy)
    if not world or not world.physics_world then
        return
    end

    local loaded = ensure_loaded_table(world)
    local key = sector_key(sx, sy)
    if loaded[key] then
        return
    end

    local universe_seed = Config.UNIVERSE_SEED or 12345

    if DefaultSector.asteroids and DefaultSector.asteroids.enabled then
        Asteroids.spawnField(world, sx, sy, universe_seed, DefaultSector.asteroids.count)
    end

    if DefaultSector.enemy_ships and DefaultSector.enemy_ships.enabled then
        EnemySpawner.spawnField(world, sx, sy, universe_seed, DefaultSector.enemy_ships.count, DefaultSector.enemy_ships)
    end

    loaded[key] = {
        sx = sx,
        sy = sy,
        loaded = true,
        last_touched = 0,
    }
end

function SectorManager.unload_sector(world, sx, sy)
    if not world then return end

    local loaded = ensure_loaded_table(world)
    local key = sector_key(sx, sy)
    if not loaded[key] then
        return
    end

    if world.getEntities then
        for _, e in ipairs(world:getEntities()) do
            local s = e.sector
            if s and s.x == sx and s.y == sy then
                if e.pilot or (e.vehicle and not e.ai) or e.station then
                else
                    e:destroy()
                end
            end
        end
    end

    loaded[key] = nil
end

function SectorManager.update_streaming(world, dt)
    if not world then return end

    local Client = require "src.network.client"
    if Client.connected and not world.hosting then
        return
    end

    local centers = world.player_centers
    if not (centers and #centers > 0) then
        return
    end

    for _, center in ipairs(centers) do
        local csx = center.sx or 0
        local csy = center.sy or 0
        SectorManager.ensure_sector_loaded(world, csx, csy)
    end
end

return SectorManager
