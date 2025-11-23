local EntityUtils = require "src.utils.entity_utils"
local ProjectileShatter = require "src.effects.projectile_shatter"

local CollisionHandlers = {}

-- Projectile vs Asteroid/Chunk/Enemy
function CollisionHandlers.handle_projectile_hit(projectile, target, world)
    if not (projectile and target and world) then return end

    -- Get damage
    local damage = 0
    if projectile.projectile and projectile.projectile.damage then
        damage = projectile.projectile.damage
    end

    -- Apply damage
    if target.hp then
        EntityUtils.apply_damage(target, damage)
    end

    -- Mark projectile as hit; ProjectileSystem will handle shatter + cleanup
    if projectile.projectile then
        projectile.projectile.hit_something = true
    end
end

-- Item vs Collector
function CollisionHandlers.handle_item_pickup(item, collector)
    if not (item and collector) then return end
    
    local itemComp = item.item

    if not itemComp then return end
    
    -- Logic for specific items
    if itemComp.name == "Stone" then
        if collector.cargo then
            local cargo = collector.cargo
            local item_vol = itemComp.volume or 1.0
            
            if (cargo.current + item_vol) <= cargo.capacity then
                cargo.current = cargo.current + item_vol
                cargo.items["Stone"] = (cargo.items["Stone"] or 0) + 1
            else
                -- Cargo full
                return 
            end
        end
    end
    
    -- Mark item as collected; ItemSystem will handle cleanup
    if item.item then
        item.item.collected = true
    end
end

return CollisionHandlers