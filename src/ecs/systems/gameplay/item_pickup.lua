local Concord = require "lib.concord.concord"
local EntityUtils = require "src.utils.entity_utils"

local ItemPickupSystem = Concord.system({
    pool = { "item", "physics" }
})



-- Note: Actual collision detection is handled via callbacks in PhysicsSystem,
-- but we can process the results or handle logic here if we want to decouple.
-- However, for simple pickup, we can just listen to the "collision" event emitted by PhysicsSystem.
-- This system might not even need an update loop if it's purely event driven.

-- Helper function to process item collection
local function collect_item(item, collector)
    if not (item and collector) then return end

    local itemComp = item.item
    if not itemComp then return end

    if itemComp.type == "resource" then
        if collector.cargo then
            local cargo = collector.cargo
            local item_vol = itemComp.volume or 1.0

            if (cargo.current + item_vol) <= cargo.capacity then
                cargo.current = cargo.current + item_vol

                local item_mass = 0
                if item.physics and item.physics.body then
                    item_mass = item.physics.body:getMass()
                end
                cargo.mass = (cargo.mass or 0) + item_mass
                cargo.items[itemComp.name] = (cargo.items[itemComp.name] or 0) + 1

                if collector.physics and collector.physics.body then
                    local body = collector.physics.body
                    local current_mass = body:getMass()
                    body:setMass(current_mass + item_mass)
                end

                print("Cargo: " .. cargo.current .. "/" .. cargo.capacity .. " Vol | Mass: " .. cargo.mass)
            else
                print("Cargo full! (" .. cargo.current .. "/" .. cargo.capacity .. ")")
                return
            end
        end
    else
        print("Picked up " .. tostring(itemComp.name))
    end

    -- Mark item as collected; actual physics cleanup happens in update
    if item.item then
        item.item.collected = true
    end
end

-- Collision callback removed as items are now kinematic without fixtures


function ItemPickupSystem:update(dt)
    local world = self:getWorld()
    if not world then return end

    -- 1. Clean up any items that were marked as collected
    for _, entity in ipairs(self.pool) do
        if entity.item and entity.item.collected then
            EntityUtils.cleanup_physics_entity(entity)
        end
    end

    -- 2. Process Pickups and Magnets
    -- We need to check distance between items and collectors (ships with cargo/wallet)

    -- Get all collectors (entities with cargo or wallet)
    -- This is a bit expensive if there are many, but usually there's just the player
    local collectors = {}
    for _, entity in ipairs(world:getEntities()) do
        if (entity.cargo or entity.wallet) and entity.transform then
            table.insert(collectors, entity)
        end
    end

    for _, itemEntity in ipairs(self.pool) do
        if not itemEntity.item.collected and itemEntity.physics and itemEntity.physics.body then
            local itemBody = itemEntity.physics.body
            local ix, iy = itemBody:getPosition()

            -- Check against all collectors
            for _, collector in ipairs(collectors) do
                local cx, cy = collector.transform.x, collector.transform.y
                local dx = cx - ix
                local dy = cy - iy
                local dist2 = dx * dx + dy * dy

                -- Pickup radius (e.g. 30 units)
                local pickup_radius = 30
                if dist2 < (pickup_radius * pickup_radius) then
                    collect_item(itemEntity, collector)
                else
                    -- Magnet Logic
                    if collector.magnet then
                        local mag = collector.magnet
                        local mag_radius_sq = mag.radius * mag.radius

                        if dist2 < mag_radius_sq and dist2 > 1 then
                            local dist = math.sqrt(dist2)

                            -- Calculate attraction velocity
                            -- For kinematic bodies, we set velocity directly
                            -- We want them to fly towards the collector

                            local speed = 200                      -- Base magnet pull speed
                            local factor = 1 - (dist / mag.radius) -- Stronger when closer
                            local pull_speed = speed * factor

                            -- Normalize direction
                            local nx, ny = dx / dist, dy / dist

                            -- Get current velocity to blend or just override?
                            -- Let's add to it to simulate acceleration, but we must manually damp it if we do that.
                            -- Simpler for kinematic: just set velocity towards player.
                            -- But we want to preserve some of its original motion maybe?
                            -- Let's just lerp towards the target velocity

                            local vx, vy = itemBody:getLinearVelocity()
                            local target_vx = nx * pull_speed * 2 -- *2 to make it snappy
                            local target_vy = ny * pull_speed * 2

                            -- Lerp factor
                            local t = 5 * dt
                            itemBody:setLinearVelocity(
                                vx + (target_vx - vx) * t,
                                vy + (target_vy - vy) * t
                            )
                        end
                    end
                end
            end
        end
    end
end

return ItemPickupSystem
