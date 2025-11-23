local Concord = require "concord"
local Ships = require "src.data.ships"
local Config = require "src.config"

local ShipManager = {}

function ShipManager.spawn(world, ship_def, x, y, is_host_player)
    local data
    local ship_type_id

    if type(ship_def) == "table" then
        data = ship_def
        ship_type_id = ship_def -- Store the table itself as the type for render system
    else
        data = Ships[ship_def]
        ship_type_id = ship_def
    end

    if not data then
        error("Unknown ship: " .. tostring(ship_def))
    end

    -- Physics Body
    local body = love.physics.newBody(world.physics_world, x, y, "dynamic")
    body:setLinearDamping(data.linear_damping)
    body:setAngularDamping(data.linear_damping)
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

    -- Render component stores the ship name and color
    -- Host is green-ish, enemies are red-ish
    local color = is_host_player and { 0.2, 1, 0.2 } or { 1, 0.2, 0.2 }
    ship:give("render", { type = ship_type_id, color = color })

    if is_host_player then
        ship:give("name", Config.PLAYER_NAME or "Player")
    end

    -- Input component
    ship:give("input")
    ship:give("weapon", "pulse_laser", data.weapon_mounts or { { x = data.radius, y = 0 } })
    ship:give("level")
    ship:give("cargo", 50)       -- Default capacity 50 (volume)
    ship:give("magnet", 100, 20) -- Radius 100, Force 20 (weaker magnet)

    return ship
end

return ShipManager
