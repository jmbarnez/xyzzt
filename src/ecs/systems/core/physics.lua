local Concord = require "concord"
local Config = require "src.config"

local PhysicsSystem = Concord.system({
    pool = { "physics", "transform", "sector" }
})

function PhysicsSystem:init()
    self.callbacks_registered = false
    self.accumulator = 0
    self.fixed_dt = 1 / 60
end

-- Standard Box2D Callbacks
function PhysicsSystem:handleBeginContact(fixtureA, fixtureB, contact)
    local world = self:getWorld()
    if not world then return end

    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil

    if not entityA or not entityB then return end

    -- Ignore collisions between projectile and owner
    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA) then
        return
    end

    -- Emit generic collision event for CollisionSystem
    world:emit("collision", entityA, entityB, contact)
end

function PhysicsSystem:handlePreSolve(fixtureA, fixtureB, contact)
    local entityA = fixtureA and fixtureA:getUserData() or nil
    local entityB = fixtureB and fixtureB:getUserData() or nil

    if not entityA or not entityB then return end

    -- Disable physical response between projectile and owner
    if (entityA.projectile and entityA.projectile.owner == entityB)
        or (entityB.projectile and entityB.projectile.owner == entityA) then
        contact:setEnabled(false)
    end
end

function PhysicsSystem:update(dt)
    local world = self:getWorld()
    if not world.physics_world then return end

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

    -- 1. Step Simulation
    self.accumulator = self.accumulator + dt
    while self.accumulator >= self.fixed_dt do
        world.physics_world:update(self.fixed_dt)
        self.accumulator = self.accumulator - self.fixed_dt
    end

    -- 2. Handle Sector Wrapping (Infinite Universe)
    local half_size = Config.SECTOR_SIZE / 2

    for _, e in ipairs(self.pool) do
        local body = e.physics.body
        local t = e.transform
        local s = e.sector

        if body then
            local x, y = body:getPosition()
            local r = body:getAngle()
            local sector_changed = false

            if x > half_size then
                x = x - Config.SECTOR_SIZE
                s.x = s.x + 1
                sector_changed = true
            elseif x < -half_size then
                x = x + Config.SECTOR_SIZE
                s.x = s.x - 1
                sector_changed = true
            end

            if y > half_size then
                y = y - Config.SECTOR_SIZE
                s.y = s.y + 1
                sector_changed = true
            elseif y < -half_size then
                y = y + Config.SECTOR_SIZE
                s.y = s.y - 1
                sector_changed = true
            end

            if sector_changed then
                body:setPosition(x, y)
            end

            -- Sync visual transform
            t.x, t.y = x, y
            t.r = r
        end
    end
end

return PhysicsSystem