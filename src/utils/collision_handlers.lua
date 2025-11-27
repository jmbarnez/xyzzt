local EntityUtils = require "src.utils.entity_utils"
local ProjectileShatter = require "src.effects.projectile_shatter"
local Client = require "src.network.client"

local CollisionHandlers = {}

-- Projectile vs Asteroid/Chunk/Enemy
function CollisionHandlers.handle_projectile_hit(projectile, target, world)
    if not (projectile and target and world) then return end

    local proj_comp = projectile.projectile
    if not proj_comp then return end

    -- Get damage
    -- Mark projectile as hit; ProjectileSystem will handle shatter + cleanup
    proj_comp.hit_something = true

    local is_pure_client = (world and not world.hosting and Client.connected)
    local is_local_owner = (world and world.local_ship and proj_comp.owner == world.local_ship)

    if is_pure_client and not is_local_owner then
        return
    end

    local damage = proj_comp.damage or 0

    -- Apply damage
    if target.asteroid or target.asteroid_chunk then
        return
    end

    if target.vehicle and (target.hull or target.shield) then
        EntityUtils.apply_ship_damage(target, damage)
    elseif target.hp then
        EntityUtils.apply_damage(target, damage)
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