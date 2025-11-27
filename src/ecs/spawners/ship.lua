local Concord = require "lib.concord.concord"
local Ships = require "src.data.ships"
local Config = require "src.config"

local ShipManager = {}

function ShipManager.spawn(world, ship_def, x, y, is_host_player)
    local data = (type(ship_def) == "table") and ship_def or Ships[ship_def]
    if not data then error("Unknown ship: " .. tostring(ship_def)) end

    -- Physics
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(data.linear_damping)
    body:setAngularDamping(0)
    body:setFixedRotation(true)

    local shape = love.physics.newCircleShape(data.radius)
    local fixture = love.physics.newFixture(body, shape, data.mass)
    fixture:setRestitution(data.restitution)

    -- Entity
    local ship = Concord.entity(world)
    ship:give("transform", x, y, 0)
    ship:give("sector", 0, 0)
    ship:give("physics", body, shape, fixture)
    ship:give("vehicle", data.thrust, data.rotation_speed, data.max_speed)
    ship:give("hull", data.max_hull)
    ship:give("shield", data.max_shield, data.shield_regen)
    fixture:setUserData(ship)

    -- Render: Host green, others red. Attach shapes data.
    local color = is_host_player and { 0.2, 1, 0.2 } or { 1, 0.2, 0.2 }

    -- Check if this is a procedural ship
    if data.type == "procedural" and data.render_data then
        ship:give("render", {
            type = "procedural",
            color = color,
            radius = data.radius,
            render_data = data.render_data, -- Store full render data
            seed = data.seed,
        })
    else
        ship:give("render", {
            type = "ship",
            color = color,
            radius = data.radius,
            shapes = data.render_data and data.render_data.shapes -- Pass the shapes
        })
    end

    if is_host_player then
        ship:give("name", Config.PLAYER_NAME or "Player")
        ship:give("pilot")
    end

    -- Add trail component
    -- Define engine mounts based on ship type or procedural data
    local engine_mounts = {}

    if data.engine_mounts then
        engine_mounts = data.engine_mounts
    else
        -- Default single engine at rear
        table.insert(engine_mounts, {
            x = -15, -- Offset behind center
            y = 0,
            width = 10,
            length = 0.5,
            color = { 0, 1, 1, 1 } -- Cyan
        })
    end

    ship:give("trail", engine_mounts)

    ship:give("input")

    -- Weapon configuration from ship definition (with safe defaults)
    local weapon_name = data.weapon_name or "pulse_laser"
    local weapon_mounts = data.weapon_mounts or { { x = data.radius, y = 0 } }
    ship:give("weapon", weapon_name, weapon_mounts)

    ship:give("level")

    -- Cargo and tractor/magnet stats from ship definition (with defaults)
    local cargo_capacity = data.cargo_capacity or 50
    ship:give("cargo", cargo_capacity)

    local magnet_radius = data.magnet_radius or 100
    local magnet_force = data.magnet_force or 20
    ship:give("magnet", magnet_radius, magnet_force)

    return ship
end

return ShipManager
