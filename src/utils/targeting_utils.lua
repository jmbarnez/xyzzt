-- Targeting and Prediction Utilities
-- Provides functions for predictive aiming and intercept calculations

local TargetingUtils = {}

-- Calculate the intercept point for hitting a moving target
-- @param shooter_x, shooter_y: Position of the shooter
-- @param projectile_speed: Speed of the projectile
-- @param target_x, target_y: Current position of target
-- @param target_vx, target_vy: Velocity of target
-- @return intercept_x, intercept_y, time_to_intercept (or nil if impossible)
function TargetingUtils.calculateIntercept(shooter_x, shooter_y, projectile_speed, target_x, target_y, target_vx,
                                           target_vy)
    -- Handle stationary target
    if not target_vx or not target_vy or (target_vx == 0 and target_vy == 0) then
        return target_x, target_y, 0
    end

    -- Calculate relative position
    local dx = target_x - shooter_x
    local dy = target_y - shooter_y

    -- Iterative solver for intercept point
    -- Start with initial estimate
    local time_estimate = math.sqrt(dx * dx + dy * dy) / projectile_speed

    -- Iterate to refine estimate (3-5 iterations usually sufficient)
    for i = 1, 5 do
        -- Predict target position at estimated time
        local pred_x = target_x + target_vx * time_estimate
        local pred_y = target_y + target_vy * time_estimate

        -- Calculate distance to predicted position
        local pred_dx = pred_x - shooter_x
        local pred_dy = pred_y - shooter_y
        local pred_dist = math.sqrt(pred_dx * pred_dx + pred_dy * pred_dy)

        -- Recalculate time estimate
        local new_time_estimate = pred_dist / projectile_speed

        -- Check for convergence
        if math.abs(new_time_estimate - time_estimate) < 0.01 then
            return pred_x, pred_y, new_time_estimate
        end

        time_estimate = new_time_estimate
    end

    -- Return final estimate even if not fully converged
    local final_x = target_x + target_vx * time_estimate
    local final_y = target_y + target_vy * time_estimate
    return final_x, final_y, time_estimate
end

-- Calculate angle to aim at a moving target with prediction
-- @param shooter_x, shooter_y: Position of the shooter
-- @param projectile_speed: Speed of the projectile
-- @param target_x, target_y: Current position of target
-- @param target_vx, target_vy: Velocity of target
-- @return angle in radians (or nil if impossible)
function TargetingUtils.calculateAimAngle(shooter_x, shooter_y, projectile_speed, target_x, target_y, target_vx,
                                          target_vy)
    local intercept_x, intercept_y, time = TargetingUtils.calculateIntercept(
        shooter_x, shooter_y, projectile_speed,
        target_x, target_y, target_vx, target_vy
    )

    if not intercept_x then
        return nil
    end

    -- Calculate angle to intercept point
    local dx = intercept_x - shooter_x
    local dy = intercept_y - shooter_y
    return math.atan2(dy, dx)
end

-- Check if a target is within field of view
-- @param shooter_angle: Current facing angle of shooter
-- @param shooter_x, shooter_y: Position of shooter
-- @param target_x, target_y: Position of target
-- @param fov: Field of view in radians
-- @return true if target is within FOV
function TargetingUtils.isInFieldOfView(shooter_angle, shooter_x, shooter_y, target_x, target_y, fov)
    local dx = target_x - shooter_x
    local dy = target_y - shooter_y
    local angle_to_target = math.atan2(dy, dx)

    -- Calculate angle difference
    local diff = angle_to_target - shooter_angle

    -- Normalize to [-pi, pi]
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end

    return math.abs(diff) <= fov / 2
end

return TargetingUtils
