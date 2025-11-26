-- Blackboard: Shared data storage for AI entities
-- Provides per-entity key-value storage for behavior tree nodes

local Blackboard = {}

-- Get a value from entity's blackboard
function Blackboard.get(entity, key)
    if not entity.ai or not entity.ai.blackboard then
        return nil
    end
    return entity.ai.blackboard[key]
end

-- Set a value in entity's blackboard
function Blackboard.set(entity, key, value)
    if not entity.ai then
        return
    end
    if not entity.ai.blackboard then
        entity.ai.blackboard = {}
    end
    entity.ai.blackboard[key] = value
end

-- Check if a key exists in entity's blackboard
function Blackboard.has(entity, key)
    if not entity.ai or not entity.ai.blackboard then
        return false
    end
    return entity.ai.blackboard[key] ~= nil
end

-- Remove a key from entity's blackboard
function Blackboard.clear(entity, key)
    if entity.ai and entity.ai.blackboard then
        entity.ai.blackboard[key] = nil
    end
end

-- Clear entire blackboard
function Blackboard.clearAll(entity)
    if entity.ai then
        entity.ai.blackboard = {}
    end
end

return Blackboard
