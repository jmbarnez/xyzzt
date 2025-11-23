# Spatial Grid Integration Guide

## ✅ Setup Complete

The spatial grid system is now running alongside love.physics. Both systems coexist peacefully!

## How to Use It

### 1. **Add Collider Component to Entities**

```lua
-- When spawning an entity, give it a collider:
entity:give("collider", "projectile", 3)  -- layer, radius

-- Available layers (you can add more):
-- "projectile" - for bullets/missiles
-- "asteroid" - for asteroids and chunks
-- "ship" - for player/enemy ships  
-- "item" - for pickups
```

### 2. **Query for Collisions**

```lua
-- In your system's update method:
local spatial_grid = world:getSystem(SpatialGrid)

-- Find all entities in radius:
local hits = spatial_grid:queryRadius(
    x, y,           -- position
    50,             -- radius
    sector_x, sector_y,
    { asteroid = true, ship = true }  -- layer mask (optional)
)

-- Find first entity at point (for projectiles):
local hit = spatial_grid:queryPoint(
    proj_x, proj_y,
    sector_x, sector_y,
    { asteroid = true },  -- only hit asteroids
    projectile           -- ignore self
)
```

### 3. **Debug Visualization**

```lua
-- In your draw() function:
local spatial_grid = self.world:getSystem(SpatialGrid)
if debug_mode then
    spatial_grid:drawDebug(self.world.camera, sector_x, sector_y)
end
```

## Migration Strategy

### Start with Projectiles (Recommended First)

```lua
-- In weapon.lua, when spawning projectile:
projectile:give("collider", "projectile", proj_radius)

-- In projectile.lua update():
local spatial_grid = world:getSystem(SpatialGrid)
local hit = spatial_grid:queryPoint(
    e.transform.x,
    e.transform.y,
    e.sector.x,
    e.sector.y,
    { asteroid = true, ship = true },  -- what it can hit
    e.projectile.owner                 -- ignore owner
)

if hit then
    -- Apply damage to hit
    if hit.hp then
        hit.hp.current = hit.hp.current - e.projectile.damage
    end
    
    -- Destroy projectile
    self:destroyProjectile(e)
end
```

### Then Add to Other Entities

```lua
-- Asteroids
asteroid:give("collider", "asteroid", radius)

-- Ships
ship:give("collider", "ship", 20)

-- Items use spatial grid for pickup radius
item:give("collider", "item", 5)
```

## Current State

- ✅ Spatial grid system created
- ✅ Collider component added
- ✅ System added to world (runs every frame)
- ✅ love.physics still handles ship/asteroid collisions
- ⏳ Entities need collider components added
- ⏳ Systems need to use spatial queries

## Next Steps

1. **Test it works**: Add collider to one projectile and query it
2. **Migrate projectiles**: Use spatial grid for projectile hits
3. **Keep love.physics**: For ship/asteroid physical collisions
4. **Add collision layers**: As you need them (explosions, tractor beams, etc.)

## Benefits You Get

- 🚀 **Fast projectile collision** - O(1) for point queries
- 🎯 **Radius queries** - Perfect for explosions, magnets, detection
- 🔍 **Easy debugging** - Visualize the grid
- 🎮 **Layer filtering** - Projectiles only hit enemies, not items
- 🌐 **Multiplayer ready** - Deterministic, no physics quirks
