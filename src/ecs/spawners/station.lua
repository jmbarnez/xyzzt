local Concord = require "lib.concord.concord"
local Stations = require "src.data.stations"

local StationManager = {}

function StationManager.spawn(world, station_def, x, y)
    local data = (type(station_def) == "table") and station_def or Stations[station_def]
    if not data then error("Unknown station: " .. tostring(station_def)) end

    -- Physics
    local body_type = data.is_static and "static" or "dynamic"
    local body = love.physics.newBody(world.physics_world, x, y, body_type)
    if body_type == "dynamic" then
        body:setLinearDamping(data.linear_damping)
        body:setAngularDamping(0)
    end
    body:setFixedRotation(true)

    local shape = love.physics.newCircleShape(data.radius)
    local fixture = love.physics.newFixture(body, shape, data.mass or 1)
    if data.restitution then
        fixture:setRestitution(data.restitution)
    end

    -- Entity
    local station = Concord.entity(world)
    station:give("transform", x, y, 0)
    station:give("sector", 0, 0)
    station:give("physics", body, shape, fixture)
    fixture:setUserData(station)

    station:give("render", {
        type = "station",
        radius = data.radius,
        shapes = data.render_data and data.render_data.shapes
    })

    station:give("name", data.name or "Station")
    station:give("station", data.description, data.services)
    station:give("station_area", data.station_radius or data.radius * 2)

    return station
end

return StationManager
