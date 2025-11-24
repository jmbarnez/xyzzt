local Concord = require "lib.concord.concord"
local CollisionHandlers = require "src.utils.collision_handlers"

local CollisionSystem = Concord.system({})

function CollisionSystem:collision(entityA, entityB, contact)
    local world = self:getWorld()

    -- 1. Projectile Collisions
    if entityA.projectile and not entityB.projectile then
        if entityA.projectile.owner ~= entityB then
            CollisionHandlers.handle_projectile_hit(entityA, entityB, world)
        end
    elseif entityB.projectile and not entityA.projectile then
        if entityB.projectile.owner ~= entityA then
            CollisionHandlers.handle_projectile_hit(entityB, entityA, world)
        end
    
    -- 2. Item Pickup Collisions
    elseif entityA.item and entityB.cargo then
        CollisionHandlers.handle_item_pickup(entityA, entityB)
    elseif entityB.item and entityA.cargo then
        CollisionHandlers.handle_item_pickup(entityB, entityA)
    end
end

return CollisionSystem