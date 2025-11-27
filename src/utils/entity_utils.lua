-- Entity management utility functions

local EntityUtils = {}

-- Safely cleanup an entity with physics components
-- Handles fixture userdata, body destruction, and entity destruction
function EntityUtils.cleanup_physics_entity(entity)
    if not entity then return end

    local physics = entity.physics
    if physics then
        -- Check if fixture exists and isn't already destroyed
        if physics.fixture and not physics.fixture:isDestroyed() then
            physics.fixture:setUserData(nil)
        end
        -- Check if body exists and isn't already destroyed
        if physics.body and not physics.body:isDestroyed() then
            physics.body:destroy()
        end
    end

    entity:destroy()
end

-- Apply damage to an entity and update last hit time
function EntityUtils.apply_damage(entity, damage)
    if not entity or not entity.hp then return end

    local hp = entity.hp
    local current = hp.current or hp.max or 0

    current = current - damage
    if current < 0 then
        current = 0
    end

    hp.current = current

    -- Update last hit time
    if love and love.timer and love.timer.getTime then
        hp.last_hit_time = love.timer.getTime()
    end
end

function EntityUtils.apply_ship_damage(entity, damage)
    if not entity or not damage or damage <= 0 then return end

    local remaining = damage

    if entity.shield then
        local shield = entity.shield
        local current = shield.current or shield.max or 0
        if current > 0 then
            local new_current = current - remaining
            if new_current < 0 then
                remaining = -new_current
                new_current = 0
            else
                remaining = 0
            end
            shield.current = new_current
        end
    end

    if remaining > 0 and entity.hull then
        local hull = entity.hull
        local current = hull.current or hull.max or 0
        local new_current = current - remaining
        if new_current < 0 then
            new_current = 0
        end
        hull.current = new_current
    end
end

return EntityUtils
