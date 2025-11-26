-- AI Condition Nodes
-- Condition nodes for behavior tree decision making

local BehaviorTree = require "src.ai.behavior_tree"
local Blackboard = require "src.ai.blackboard"

local Conditions = {}

-- Check if entity has a valid target in blackboard
function Conditions.HasTarget()
    return BehaviorTree.Condition:new(function(entity)
        local target = Blackboard.get(entity, "target")
        if not target then
            return false
        end

        -- Check if target is still valid (not destroyed)
        if not target:getWorld() then
            Blackboard.clear(entity, "target")
            return false
        end

        return true
    end)
end

-- Check if target is within specified range
function Conditions.TargetInRange(range)
    return BehaviorTree.Condition:new(function(entity)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform then
            return false
        end

        -- Calculate distance (ignoring sectors for now - assume same sector)
        local dx = target.transform.x - entity.transform.x
        local dy = target.transform.y - entity.transform.y
        local dist_sq = dx * dx + dy * dy

        return dist_sq <= (range * range)
    end)
end

-- Check if target is within detection range (uses detection component)
function Conditions.TargetInDetectionRange()
    return BehaviorTree.Condition:new(function(entity)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform or not entity.detection then
            return false
        end

        local dx = target.transform.x - entity.transform.x
        local dy = target.transform.y - entity.transform.y
        local dist_sq = dx * dx + dy * dy
        local range = entity.detection.range or 500

        return dist_sq <= (range * range)
    end)
end

-- Check if weapon is ready to fire
function Conditions.CanFire()
    return BehaviorTree.Condition:new(function(entity)
        if not entity.weapon then
            return false
        end

        return (entity.weapon.cooldown or 0) <= 0
    end)
end

-- Check if target is visible (basic FOV check)
function Conditions.IsTargetVisible()
    return BehaviorTree.Condition:new(function(entity)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform or not entity.detection then
            return false
        end

        local TargetingUtils = require "src.utils.targeting_utils"
        local shooter_angle = entity.transform.r or 0
        local fov = entity.detection.fov or (math.pi * 2) -- Default 360 degrees

        return TargetingUtils.isInFieldOfView(
            shooter_angle,
            entity.transform.x, entity.transform.y,
            target.transform.x, target.transform.y,
            fov
        )
    end)
end

-- Check if entity has a patrol point
function Conditions.HasPatrolPoint()
    return BehaviorTree.Condition:new(function(entity)
        return Blackboard.has(entity, "patrol_x") and Blackboard.has(entity, "patrol_y")
    end)
end

return Conditions
