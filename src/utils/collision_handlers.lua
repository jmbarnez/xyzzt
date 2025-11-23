local EntityUtils = require "src.utils.entity_utils"
local ProjectileShatter = require "src.effects.projectile_shatter"

local CollisionHandlers = {}

--- Handle collision between projectile and asteroid/asteroid_chunk
--- Applies damage to the target and destroys the projectile with shatter effect
--- @param projectile Entity The projectile entity
--- @param target Entity The asteroid or asteroid_chunk entity
--- @param world World The Concord world
function CollisionHandlers.handle_projectile_asteroid(projectile, target, world)
    if not projectile or not target or not world then
        return
    end

    -- Get damage from projectile
    local damage = 0
    if projectile.projectile and projectile.projectile.damage then
        damage = projectile.projectile.damage
    end

    -- Apply damage to target if it has HP
    -- The physics system will handle destruction when HP <= 0
    if target.hp and damage > 0 then
        target.hp.current = target.hp.current - damage
        target.hp.last_hit_time = love.timer.getTime()
    end

    -- Destroy the projectile and spawn shatter effect
    if projectile and projectile:getWorld() then
        -- Spawn shards at projectile location before destroying
        if projectile.transform and projectile.render and projectile.sector then
            local color = projectile.render.color or { 1, 1, 1, 1 }

            -- Get projectile velocity for directional shatter
            local vx, vy = 0, 0
            if projectile.physics and projectile.physics.body then
                vx, vy = projectile.physics.body:getLinearVelocity()
            end

            ProjectileShatter.spawn(
                world,
                projectile.transform.x,
                projectile.transform.y,
                projectile.sector.x,
                projectile.sector.y,
                color,
                projectile.projectile.radius or 2,
                vx, vy
            )
        end

        -- Clean up the projectile entity
        EntityUtils.cleanup_physics_entity(projectile)
    end
end

return CollisionHandlers
