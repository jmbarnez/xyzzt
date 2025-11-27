local Concord       = require "lib.concord.concord"
local Config        = require "src.config"
local DefaultSector = require "src.data.default_sector"

local PhysicsSystem = Concord.system({
    pool = { "physics", "transform", "sector" }
})

function PhysicsSystem:init()
    self.callbacks_registered = false
    self.accumulator         = 0
    self.fixed_dt            = 1 / 60
end

-- Box2D: begin contact
function PhysicsSystem:handleBeginContact(fixtureA, fixtureB, contact)
    local world = self:getWorld()
    if not world then return end

    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil
    if not entityA or not entityB then return end

    -- Ignore projectile–projectile
    if entityA.projectile and entityB.projectile then
        return
    end

    -- Ignore projectile–item
    if (entityA.projectile and entityB.item)
        or (entityB.projectile and entityA.item)
    then
        return
    end

    -- Ignore collisions between projectile and its owner
    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA)
    then
        return
    end

    world:emit("collision", entityA, entityB, contact)
end

-- Box2D: pre-solve (modify/disable physical response)
function PhysicsSystem:handlePreSolve(fixtureA, fixtureB, contact)
    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil
    if not entityA or not entityB then return end

    -- Disable projectile–projectile
    if entityA.projectile and entityB.projectile then
        contact:setEnabled(false)
        return
    end

    -- Disable projectile–item
    if (entityA.projectile and entityB.item)
        or (entityB.projectile and entityA.item)
    then
        contact:setEnabled(false)
        return
    end

    -- Disable physical response between projectile and its owner
    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA)
    then
        contact:setEnabled(false)
    end
end

-- World bounds handling:
--  * Projectiles: kill when leaving bounds
--  * Items: clamp inside bounds, stop movement
--  * Other bodies: bounce off edges with some energy loss
function PhysicsSystem:applyWorldBounds(e, body, half_size, is_player)
    if not (e and body and half_size) then
        return body:getPosition()
    end

    local x, y = body:getPosition()
    local vx, vy = body:getLinearVelocity()
    local r = body:getAngle()

    -- Projectiles: mark as expired when out of bounds
    if e.projectile then
        if x > half_size or x < -half_size
            or y > half_size or y < -half_size
        then
            e.projectile.lifetime = 0
        end
        return x, y, r
    end

    -- Items: hard clamp, zero velocity
    if e.item then
        local clamped_x, clamped_y = x, y
        local hit_edge = false

        if clamped_x > half_size then
            clamped_x = half_size
            hit_edge  = true
        elseif clamped_x < -half_size then
            clamped_x = -half_size
            hit_edge  = true
        end

        if clamped_y > half_size then
            clamped_y = half_size
            hit_edge  = true
        elseif clamped_y < -half_size then
            clamped_y = -half_size
            hit_edge  = true
        end

        if hit_edge then
            body:setPosition(clamped_x, clamped_y)
            body:setLinearVelocity(0, 0)
            x, y = clamped_x, clamped_y
        end

        return x, y, r
    end

    -- Ships / asteroids / other dynamic bodies: bounce
    local bounce_factor = 0.5
    local bounced       = false

    if x > half_size then
        x  = half_size
        vx = -math.abs(vx) * bounce_factor
        bounced = true
    elseif x < -half_size then
        x  = -half_size
        vx =  math.abs(vx) * bounce_factor
        bounced = true
    end

    if y > half_size then
        y  = half_size
        vy = -math.abs(vy) * bounce_factor
        bounced = true
    elseif y < -half_size then
        y  = -half_size
        vy =  math.abs(vy) * bounce_factor
        bounced = true
    end

    if bounced then
        body:setPosition(x, y)
        body:setLinearVelocity(vx, vy)
    end

    return x, y, r
end

function PhysicsSystem:update(dt)
    local world = self:getWorld()
    if not (world and world.physics_world) then return end

    -- Register callbacks once
    if not self.callbacks_registered then
        world.physics_world:setCallbacks(
            function(a, b, c) self:handleBeginContact(a, b, c) end,
            nil,
            function(a, b, c) self:handlePreSolve(a, b, c) end,
            nil
        )
        self.callbacks_registered = true
    end

    -- Fixed-step physics update
    self.accumulator = self.accumulator + dt
    while self.accumulator >= self.fixed_dt do
        world.physics_world:update(self.fixed_dt)
        self.accumulator = self.accumulator - self.fixed_dt
    end

    -- Bounds management
    local half_size = DefaultSector.SECTOR_SIZE / 2

    for _, e in ipairs(self.pool) do
        local body = e.physics and e.physics.body
        local t    = e.transform
        if body and t then
            local x, y, r = self:applyWorldBounds(
                e,
                body,
                half_size,
                e.pilot ~= nil -- currently unused flag, reserved for behavior tweaks
            )

            t.x, t.y = x, y
            t.r      = r
        end
    end
end

return PhysicsSystem
