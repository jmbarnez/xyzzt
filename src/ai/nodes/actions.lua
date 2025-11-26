-- AI Action Nodes
-- Action nodes for behavior tree behaviors

local BehaviorTree = require "src.ai.behavior_tree"
local Blackboard = require "src.ai.blackboard"
local TargetingUtils = require "src.utils.targeting_utils"

local Actions = {}

-- Scan for nearby player targets and select the closest one
function Actions.ScanForTargets()
    return BehaviorTree.Action:new(function(entity, dt)
        if not entity.transform or not entity.detection then
            return BehaviorTree.Status.FAILURE
        end

        local world = entity:getWorld()
        if not world then
            return BehaviorTree.Status.FAILURE
        end

        local detection_range = entity.detection.range or 500
        local best_target = nil
        local best_dist_sq = detection_range * detection_range

        -- Find all entities with pilot component (player ships)
        for _, potential_target in ipairs(world:getEntities()) do
            if potential_target.pilot and potential_target.transform and potential_target ~= entity then
                -- Calculate distance
                local dx = potential_target.transform.x - entity.transform.x
                local dy = potential_target.transform.y - entity.transform.y
                local dist_sq = dx * dx + dy * dy

                -- Check if within range and closer than current best
                if dist_sq <= best_dist_sq then
                    -- Optional: Check FOV if specified
                    if entity.detection.fov then
                        local in_fov = TargetingUtils.isInFieldOfView(
                            entity.transform.r or 0,
                            entity.transform.x, entity.transform.y,
                            potential_target.transform.x, potential_target.transform.y,
                            entity.detection.fov
                        )
                        if in_fov then
                            best_target = potential_target
                            best_dist_sq = dist_sq
                        end
                    else
                        best_target = potential_target
                        best_dist_sq = dist_sq
                    end
                end
            end
        end

        if best_target then
            Blackboard.set(entity, "target", best_target)
            Blackboard.set(entity, "last_detection_time", love.timer.getTime())
            print("[AI] Enemy detected player at distance: " .. math.sqrt(best_dist_sq))
            return BehaviorTree.Status.SUCCESS
        end

        return BehaviorTree.Status.FAILURE
    end)
end

-- Patrol: Generate random waypoints and navigate to them
function Actions.Patrol(patrol_radius)
    patrol_radius = patrol_radius or 1000

    return BehaviorTree.Action:new(function(entity, dt)
        if not entity.transform or not entity.input then
            return BehaviorTree.Status.FAILURE
        end

        -- Check if we have a patrol point
        local patrol_x = Blackboard.get(entity, "patrol_x")
        local patrol_y = Blackboard.get(entity, "patrol_y")

        -- Generate new patrol point if none exists
        if not patrol_x or not patrol_y then
            local angle = math.random() * math.pi * 2
            local dist = math.random() * patrol_radius
            patrol_x = entity.transform.x + math.cos(angle) * dist
            patrol_y = entity.transform.y + math.sin(angle) * dist
            Blackboard.set(entity, "patrol_x", patrol_x)
            Blackboard.set(entity, "patrol_y", patrol_y)
        end

        -- Calculate distance to patrol point
        local dx = patrol_x - entity.transform.x
        local dy = patrol_y - entity.transform.y
        local dist_sq = dx * dx + dy * dy

        -- Reached patrol point - generate new one
        if dist_sq < 100 * 100 then
            Blackboard.clear(entity, "patrol_x")
            Blackboard.clear(entity, "patrol_y")
            return BehaviorTree.Status.SUCCESS
        end

        -- Navigate to patrol point
        local angle_to_patrol = math.atan2(dy, dx)
        entity.input.target_angle = angle_to_patrol
        entity.input.move_x = math.cos(angle_to_patrol)
        entity.input.move_y = math.sin(angle_to_patrol)

        return BehaviorTree.Status.RUNNING
    end)
end

-- Chase: Pursue the target entity
function Actions.ChaseTarget()
    return BehaviorTree.Action:new(function(entity, dt)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform or not entity.input then
            return BehaviorTree.Status.FAILURE
        end

        -- Calculate direction to target
        local dx = target.transform.x - entity.transform.x
        local dy = target.transform.y - entity.transform.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 1 then
            return BehaviorTree.Status.SUCCESS
        end

        -- Set input to move towards target
        local angle_to_target = math.atan2(dy, dx)
        entity.input.target_angle = angle_to_target
        entity.input.move_x = dx / dist
        entity.input.move_y = dy / dist

        return BehaviorTree.Status.RUNNING
    end)
end

-- Attack: Fire weapon at target with predictive aiming
function Actions.AttackTarget()
    return BehaviorTree.Action:new(function(entity, dt)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform or not entity.weapon or not entity.input then
            return BehaviorTree.Status.FAILURE
        end

        -- Get weapon data to determine projectile speed
        local WeaponRegistry = require "src.managers.weapon_registry"
        local weapon_def = WeaponRegistry.get_weapon(entity.weapon.weapon_name)

        if not weapon_def then
            return BehaviorTree.Status.FAILURE
        end

        local projectile_speed = weapon_def.projectile_speed or 500

        -- Get target velocity
        local target_vx, target_vy = 0, 0
        if target.physics and target.physics.body then
            target_vx, target_vy = target.physics.body:getLinearVelocity()
        end

        -- Calculate predictive aim angle
        local aim_angle = TargetingUtils.calculateAimAngle(
            entity.transform.x, entity.transform.y,
            projectile_speed,
            target.transform.x, target.transform.y,
            target_vx, target_vy
        )

        if not aim_angle then
            -- Can't hit target, just aim directly at it
            local dx = target.transform.x - entity.transform.x
            local dy = target.transform.y - entity.transform.y
            aim_angle = math.atan2(dy, dx)
        end

        -- Set input to aim and fire
        entity.input.target_angle = aim_angle
        entity.input.fire = true

        return BehaviorTree.Status.SUCCESS
    end)
end

-- Clear target from blackboard
function Actions.ClearTarget()
    return BehaviorTree.Action:new(function(entity, dt)
        Blackboard.clear(entity, "target")
        return BehaviorTree.Status.SUCCESS
    end)
end

-- Evade: Move perpendicular to target threat vector
function Actions.Evade()
    return BehaviorTree.Action:new(function(entity, dt)
        local target = Blackboard.get(entity, "target")
        if not target or not target.transform or not entity.transform or not entity.input then
            return BehaviorTree.Status.FAILURE
        end

        -- Calculate perpendicular direction
        local dx = target.transform.x - entity.transform.x
        local dy = target.transform.y - entity.transform.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < 1 then
            return BehaviorTree.Status.FAILURE
        end

        -- Normalize and rotate 90 degrees
        local nx = -dy / dist
        local ny = dx / dist

        -- Randomly choose left or right evade
        local evade_dir = Blackboard.get(entity, "evade_direction")
        if not evade_dir then
            evade_dir = (math.random() > 0.5) and 1 or -1
            Blackboard.set(entity, "evade_direction", evade_dir)
        end

        entity.input.move_x = nx * evade_dir
        entity.input.move_y = ny * evade_dir

        return BehaviorTree.Status.RUNNING
    end)
end

return Actions
