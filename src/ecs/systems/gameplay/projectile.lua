local Concord = require "lib.concord.concord"
local EntityUtils = require "src.utils.entity_utils"
local ProjectileShatter = require "src.effects.projectile_shatter"

local ProjectileSystem = Concord.system({
    pool = { "projectile", "transform", "sector" }
})

function ProjectileSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local projectile = e.projectile
        projectile.lifetime = (projectile.lifetime or 0) - dt

        if projectile.hit_something or projectile.lifetime <= 0 then
            self:destroyProjectile(e)
        end
    end
end

function ProjectileSystem:destroyProjectile(e)
    local world = self:getWorld()
    if not e or not e:getWorld() then return end -- Already destroyed

    -- Spawn shards at projectile location before destroying
    if e.transform and e.render and e.sector and e.projectile.hit_something then
        local color = e.render.color or { 1, 1, 1, 1 }

        -- Get projectile velocity for directional shatter
        local vx, vy = 0, 0
        if e.physics and e.physics.body then
            vx, vy = e.physics.body:getLinearVelocity()
        end

        ProjectileShatter.spawn(
            world,
            e.transform.x,
            e.transform.y,
            e.sector.x,
            e.sector.y,
            color,
            e.projectile.radius or 2,
            vx, vy
        )
    end

    EntityUtils.cleanup_physics_entity(e)
end

return ProjectileSystem
