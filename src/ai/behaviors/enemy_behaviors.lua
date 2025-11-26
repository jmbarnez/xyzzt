-- Predefined Behavior Trees for Enemy AI
-- Contains factory functions for creating behavior trees for different enemy types

local BehaviorTree = require "src.ai.behavior_tree"
local Conditions = require "src.ai.nodes.conditions"
local Actions = require "src.ai.nodes.actions"

local EnemyBehaviors = {}

-- Basic Drone AI
-- Scans for targets, chases and attacks when found, patrols when idle
function EnemyBehaviors.createBasicDrone()
    return BehaviorTree.Selector:new({
        -- Combat: Has target and in range -> Attack
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            Conditions.TargetInRange(800),
            Actions.AttackTarget()
        }),

        -- Pursue: Has target but not in range -> Chase and opportunistic attack
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            Actions.ChaseTarget()
        }),

        -- Scan for targets
        Actions.ScanForTargets(),

        -- Fallback: Patrol
        Actions.Patrol(1000)
    })
end

-- Aggressive Fighter AI
-- More aggressive, longer detection range, will pursue targets more actively
function EnemyBehaviors.createAggressiveFighter()
    return BehaviorTree.Selector:new({
        -- Engage: Has target
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            BehaviorTree.Selector:new({
                -- Attack if in range
                BehaviorTree.Sequence:new({
                    Conditions.TargetInRange(1000),
                    Actions.AttackTarget()
                }),
                -- Otherwise chase
                Actions.ChaseTarget()
            })
        }),

        -- Scan for targets
        Actions.ScanForTargets(),

        -- Fallback: Patrol
        Actions.Patrol(1500)
    })
end

-- Defensive Sentry AI
-- Stays in patrol area, only engages if target comes close
function EnemyBehaviors.createDefensiveSentry()
    return BehaviorTree.Selector:new({
        -- Attack if target is very close
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            Conditions.TargetInRange(600),
            Actions.AttackTarget()
        }),

        -- Scan for nearby threats
        Actions.ScanForTargets(),

        -- Stay in patrol area
        Actions.Patrol(500)
    })
end

-- Sniper AI
-- Long range detection and attacks, tries to maintain distance
function EnemyBehaviors.createSniper()
    return BehaviorTree.Selector:new({
        -- Attack from distance
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            Conditions.TargetInRange(1200),
            Actions.AttackTarget()
        }),

        -- Chase if target is out of range
        BehaviorTree.Sequence:new({
            Conditions.HasTarget(),
            Actions.ChaseTarget()
        }),

        -- Scan for targets
        Actions.ScanForTargets(),

        -- Patrol wide area
        Actions.Patrol(2000)
    })
end

return EnemyBehaviors
