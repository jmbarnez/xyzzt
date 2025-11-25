-- src/network/interpolation.lua
local Interpolation = {}

-- Maximum number of historical states to keep per entity
local BUFFER_SIZE = 32

-- How far behind real time (in seconds) the render interpolation should be
local INTERPOLATION_DELAY = 0.15

-- Create a new interpolation buffer
function Interpolation.createBuffer()
    return {
        states = {},
        last_update = love.timer.getTime(),
    }
end

-- Add a new state to the buffer
function Interpolation.addState(buffer, server_time, x, y, r, vx, vy, angular_velocity)
    local state = {
        time = server_time,
        x = x,
        y = y,
        r = r,
        vx = vx or 0,
        vy = vy or 0,
        angular_velocity = angular_velocity or 0
    }

    -- Insert in chronological order
    table.insert(buffer.states, state)

    -- Sort by time (in case packets arrive out of order)
    table.sort(buffer.states, function(a, b) return a.time < b.time end)

    -- Keep only last BUFFER_SIZE states
    while #buffer.states > BUFFER_SIZE do
        table.remove(buffer.states, 1)
    end

    buffer.last_update = love.timer.getTime()
end

-- Get interpolated state at current render time
function Interpolation.getInterpolatedState(buffer)
    if #buffer.states == 0 then
        return nil
    end

    -- Render time is slightly behind current time for smooth interpolation
    local current_time = love.timer.getTime()
    local render_time = current_time - INTERPOLATION_DELAY

    -- If we only have one state, use it directly
    if #buffer.states == 1 then
        return buffer.states[1]
    end

    -- Find two states that bracket the render time
    local state_before = nil
    local state_after = nil

    for i = 1, #buffer.states - 1 do
        if buffer.states[i].time <= render_time and buffer.states[i + 1].time >= render_time then
            state_before = buffer.states[i]
            state_after = buffer.states[i + 1]
            break
        end
    end

    -- If no bracketing states found, use extrapolation or latest state
    if not state_before or not state_after then
        -- Use the latest state we have
        local latest = buffer.states[#buffer.states]

        -- Extrapolate if render time is ahead (within reason)
        if render_time > latest.time and (render_time - latest.time) < 0.05 then
            local dt = render_time - latest.time
            return {
                x = latest.x + latest.vx * dt,
                y = latest.y + latest.vy * dt,
                r = latest.r + latest.angular_velocity * dt,
                vx = latest.vx,
                vy = latest.vy,
                angular_velocity = latest.angular_velocity
            }
        end

        return latest
    end

    -- Interpolate between the two states
    local time_diff = state_after.time - state_before.time
    if time_diff == 0 then
        return state_before
    end

    local alpha = (render_time - state_before.time) / time_diff
    alpha = math.max(0, math.min(1, alpha)) -- Clamp to [0, 1]

    return {
        x = state_before.x + (state_after.x - state_before.x) * alpha,
        y = state_before.y + (state_after.y - state_before.y) * alpha,
        r = state_before.r + (state_after.r - state_before.r) * alpha,
        vx = state_before.vx + (state_after.vx - state_before.vx) * alpha,
        vy = state_before.vy + (state_after.vy - state_before.vy) * alpha,
        angular_velocity = state_before.angular_velocity +
        (state_after.angular_velocity - state_before.angular_velocity) * alpha
    }
end

-- Check if buffer is stale (no updates for too long)
function Interpolation.isStale(buffer, timeout)
    timeout = timeout or 1.0 -- Default 1 second timeout
    local current_time = love.timer.getTime()
    return (current_time - buffer.last_update) > timeout
end

return Interpolation
