-- Default sector configuration
-- This defines what gets spawned in a standard sector

return {
    -- World / Sector Configuration
    SECTOR_SIZE = 7500, -- The width/height of one "Sector" before coordinates wrap

    -- Asteroid field configuration
    asteroids = {
        enabled = true,
        count = 20, -- Number of asteroids per sector
        -- Distribution uses the sector seed for deterministic generation
    },

    -- Enemy ship configuration
    enemy_ships = {
        enabled = true,
        count = 15,                       -- Number of enemy ships per sector
        ship_name = "starter_drone",     -- All enemies use this ship
        -- Spatial distribution parameters
        min_distance_from_origin = 2000,  -- Don't spawn too close to player start
        max_distance_from_origin = 7500, -- Stay within sector bounds
        min_separation = 50,             -- Minimum distance between enemy ships
    },

    -- Future: could add station spawning, resource nodes, etc.
}
