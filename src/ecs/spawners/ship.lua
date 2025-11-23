local Concord = require "concord"
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

    ship:give("render", {
        type = "ship",
        color = color,
        shapes = data.render_data and data.render_data.shapes -- Pass the shapes
    })

    if is_host_player then
        ship:give("name", Config.PLAYER_NAME or "Player")
        ship:give("pilot")
        -- Add engine trail
        ship:give("trail", 0.6, 12, { 0, 1, 1, 1 })
    end

    ship:give("input")
    ship:give("weapon", "pulse_laser", data.weapon_mounts or { { x = data.radius, y = 0 } })
    ship:give("level")
    ship:give("cargo", 50)
    ship:give("magnet", 100, 20)

    return ship
end

return ShipManager
