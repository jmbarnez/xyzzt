local lume = require "lib.lume"

local Stations = {}

local stations_to_load = {
    "starter_station",
}

for _, station_name in ipairs(stations_to_load) do
    local station_data = require("src.data.stations." .. station_name)
    Stations[station_name] = station_data
end

return Stations
