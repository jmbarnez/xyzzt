local Config = require "src.config"

return {
    name = "Starter Station",

    -- Physics
    mass = 1000,
    linear_damping = 5,
    restitution = 0.1,
    radius = 50,
    is_static = true,

    -- Station Properties
    station_radius = 100, -- This will be used for the visible ring

    -- Render Data (Data-Driven)
    render_data = {
        shapes = {
            -- Central Hub
            {
                type = "circle",
                color = { 0.6, 0.6, 0.7, 1 },
                x = 0,
                y = 0,
                radius = 50,
                outline = { 0.4, 0.4, 0.5, 1 }
            },
            -- Docking Bay 1
            {
                type = "polygon",
                color = { 0.5, 0.5, 0.6, 1 },
                points = { 40, 30, 60, 50, 70, 40, 50, 20 },
                outline = { 0.3, 0.3, 0.4, 1 }
            },
            -- Docking Bay 2
            {
                type = "polygon",
                color = { 0.5, 0.5, 0.6, 1 },
                points = { 40, -30, 60, -50, 70, -40, 50, -20 },
                outline = { 0.3, 0.3, 0.4, 1 }
            },
            -- Docking Bay 3
            {
                type = "polygon",
                color = { 0.5, 0.5, 0.6, 1 },
                points = { -40, 30, -60, 50, -70, 40, -50, 20 },
                outline = { 0.3, 0.3, 0.4, 1 }
            },
            -- Docking Bay 4
            {
                type = "polygon",
                color = { 0.5, 0.5, 0.6, 1 },
                points = { -40, -30, -60, -50, -70, -40, -50, -20 },
                outline = { 0.3, 0.3, 0.4, 1 }
            }
        }
    }
}