local Concord = require "lib.concord.concord"
local Config = require "src.config"
local ItemDefinitions = require "src.data.items"

local ItemSpawners = {}

-- Generic item spawner that uses item definitions
function ItemSpawners.spawn_item(world, item_id, x, y, sector_x, sector_y, volume_override, mass_override)
    if not world then return end

    local item_def = ItemDefinitions[item_id]
    if not item_def then
        print("Warning: Unknown item ID: " .. tostring(item_id))
        return
    end

    local item = Concord.entity(world)
    item:give("transform", x, y, math.random() * math.pi * 2)
    item:give("sector", sector_x or 0, sector_y or 0)

    -- Generate shape using the item's definition
    local vertices = item_def:generate_shape()

    -- Render component from definition
    item:give("render", {
        render_type = "item",
        color = item_def.render.color,
        shape = vertices
    })

    -- Item component (use overrides if provided)
    local volume = volume_override or item_def.volume
    item:give("item", item_def.type, item_def.name, volume)

    -- Lifetime
    if item_def.lifetime then
        item:give("lifetime", item_def.lifetime)
    end

    -- Physics
    local phys = item_def.physics
    -- Changed to kinematic as requested
    local body = love.physics.newBody(world.physics_world, x, y, "kinematic")
    body:setLinearDamping(phys.linear_damping)
    body:setAngularDamping(phys.angular_damping)

    -- Set mass (use override if provided, otherwise use definition)
    local mass = mass_override or phys.mass
    if mass then
        body:setMass(mass)
    end

    -- No shape or fixture for items anymore
    item:give("physics", body, nil, nil)

    -- Assign network ID if hosting (same pattern as asteroids/chunks)
    local Server = nil
    local assign_network_ids = false
    if world.hosting then
        Server = require "src.network.server"
        assign_network_ids = true
    end

    if assign_network_ids and Server then
        item.network_id = Server.next_network_id
        Server.next_network_id = Server.next_network_id + 1
    end

    -- Apply random velocity
    local vel = phys.spawn_velocity
    local angle = math.random() * math.pi * 2
    local speed = vel.speed_min + math.random() * (vel.speed_max - vel.speed_min)
    body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)

    local angular_vel = vel.angular_min + math.random() * (vel.angular_max - vel.angular_min)
    body:setAngularVelocity(angular_vel)

    return item
end

-- Convenience function for spawning stone
function ItemSpawners.spawn_stone(world, x, y, sector_x, sector_y, volume, mass)
    return ItemSpawners.spawn_item(world, "stone", x, y, sector_x, sector_y, volume, mass)
end

return ItemSpawners
