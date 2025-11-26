-- Core Behavior Tree Implementation
-- Provides base classes for building AI behavior trees

local BehaviorTree = {}

-- Node execution results
BehaviorTree.Status = {
    SUCCESS = "success",
    FAILURE = "failure",
    RUNNING = "running"
}

-- Base Node class
local Node = {}
Node.__index = Node

function Node:new()
    local instance = setmetatable({}, self)
    return instance
end

function Node:tick(entity, dt)
    error("Node:tick must be implemented by subclass")
end

-- Composite Node: Selector (OR logic - returns success on first success)
local Selector = setmetatable({}, { __index = Node })
Selector.__index = Selector

function Selector:new(children)
    local instance = Node.new(self)
    instance.children = children or {}
    return instance
end

function Selector:tick(entity, dt)
    for _, child in ipairs(self.children) do
        local status = child:tick(entity, dt)
        if status == BehaviorTree.Status.SUCCESS then
            return BehaviorTree.Status.SUCCESS
        elseif status == BehaviorTree.Status.RUNNING then
            return BehaviorTree.Status.RUNNING
        end
        -- Continue to next child on FAILURE
    end
    return BehaviorTree.Status.FAILURE
end

-- Composite Node: Sequence (AND logic - returns success only if all succeed)
local Sequence = setmetatable({}, { __index = Node })
Sequence.__index = Sequence

function Sequence:new(children)
    local instance = Node.new(self)
    instance.children = children or {}
    return instance
end

function Sequence:tick(entity, dt)
    for _, child in ipairs(self.children) do
        local status = child:tick(entity, dt)
        if status == BehaviorTree.Status.FAILURE then
            return BehaviorTree.Status.FAILURE
        elseif status == BehaviorTree.Status.RUNNING then
            return BehaviorTree.Status.RUNNING
        end
        -- Continue to next child on SUCCESS
    end
    return BehaviorTree.Status.SUCCESS
end

-- Decorator Node: Inverter (NOT logic - inverts child result)
local Inverter = setmetatable({}, { __index = Node })
Inverter.__index = Inverter

function Inverter:new(child)
    local instance = Node.new(self)
    instance.child = child
    return instance
end

function Inverter:tick(entity, dt)
    local status = self.child:tick(entity, dt)
    if status == BehaviorTree.Status.SUCCESS then
        return BehaviorTree.Status.FAILURE
    elseif status == BehaviorTree.Status.FAILURE then
        return BehaviorTree.Status.SUCCESS
    end
    return status -- RUNNING stays RUNNING
end

-- Decorator Node: Succeeder (always returns success)
local Succeeder = setmetatable({}, { __index = Node })
Succeeder.__index = Succeeder

function Succeeder:new(child)
    local instance = Node.new(self)
    instance.child = child
    return instance
end

function Succeeder:tick(entity, dt)
    self.child:tick(entity, dt)
    return BehaviorTree.Status.SUCCESS
end

-- Leaf Node: Action (executes a function)
local Action = setmetatable({}, { __index = Node })
Action.__index = Action

function Action:new(action_func)
    local instance = Node.new(self)
    instance.action_func = action_func
    return instance
end

function Action:tick(entity, dt)
    return self.action_func(entity, dt)
end

-- Leaf Node: Condition (evaluates a condition)
local Condition = setmetatable({}, { __index = Node })
Condition.__index = Condition

function Condition:new(condition_func)
    local instance = Node.new(self)
    instance.condition_func = condition_func
    return instance
end

function Condition:tick(entity, dt)
    if self.condition_func(entity) then
        return BehaviorTree.Status.SUCCESS
    else
        return BehaviorTree.Status.FAILURE
    end
end

-- Export classes
BehaviorTree.Node = Node
BehaviorTree.Selector = Selector
BehaviorTree.Sequence = Sequence
BehaviorTree.Inverter = Inverter
BehaviorTree.Succeeder = Succeeder
BehaviorTree.Action = Action
BehaviorTree.Condition = Condition

return BehaviorTree
