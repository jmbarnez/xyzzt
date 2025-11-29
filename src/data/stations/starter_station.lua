local Config = require "src.config"

return {
    name = "Starter Station",

    -- Physics
    mass = 1000,
    linear_damping = 5,
    restitution = 0.1,
    radius = 80,
    is_static = true,

    -- Station Properties
    station_radius = 220, -- Radius for the visible docking/safe area ring

    -- Metadata for UI
    description = "Primary hub of the starter sector. Offers basic repairs and resupply.",
    services = {
        "Ship Repairs",
        "Shield Recharge",
        "Energy Refill",
    },

    -- Render Data (Data-Driven)
    render_data = {
        shapes = {
            -- Outer ring
            {
                type = "circle",
                color = { 0.10, 0.12, 0.18, 1 },
                x = 0,
                y = 0,
                radius = 120,
                outline = { 0.35, 0.65, 0.95, 1 },
            },
            -- Inner ring
            {
                type = "circle",
                color = { 0.14, 0.17, 0.24, 1 },
                x = 0,
                y = 0,
                radius = 90,
                outline = { 0.25, 0.5, 0.9, 1 },
            },
            -- Central core
            {
                type = "circle",
                color = { 0.65, 0.7, 0.85, 1 },
                x = 0,
                y = 0,
                radius = 45,
                outline = { 0.4, 0.45, 0.6, 1 },
            },
            -- East arm
            {
                type = "polygon",
                color = { 0.45, 0.5, 0.65, 1 },
                points = { 45, 16, 115, 24, 115, -24, 45, -16 },
                outline = { 0.25, 0.3, 0.5, 1 },
            },
            -- West arm
            {
                type = "polygon",
                color = { 0.45, 0.5, 0.65, 1 },
                points = { -45, 16, -115, 24, -115, -24, -45, -16 },
                outline = { 0.25, 0.3, 0.5, 1 },
            },
            -- North arm
            {
                type = "polygon",
                color = { 0.45, 0.5, 0.65, 1 },
                points = { -16, 45, 16, 45, 24, 115, -24, 115 },
                outline = { 0.25, 0.3, 0.5, 1 },
            },
            -- South arm
            {
                type = "polygon",
                color = { 0.45, 0.5, 0.65, 1 },
                points = { -16, -45, 16, -45, 24, -115, -24, -115 },
                outline = { 0.25, 0.3, 0.5, 1 },
            },
            -- NE pad
            {
                type = "polygon",
                color = { 0.55, 0.55, 0.7, 1 },
                points = { 30, 70, 60, 110, 90, 90, 55, 55 },
                outline = { 0.3, 0.3, 0.5, 1 },
            },
            -- NW pad
            {
                type = "polygon",
                color = { 0.55, 0.55, 0.7, 1 },
                points = { -30, 70, -55, 55, -90, 90, -60, 110 },
                outline = { 0.3, 0.3, 0.5, 1 },
            },
            -- SE pad
            {
                type = "polygon",
                color = { 0.55, 0.55, 0.7, 1 },
                points = { 30, -70, 55, -55, 90, -90, 60, -110 },
                outline = { 0.3, 0.3, 0.5, 1 },
            },
            -- SW pad
            {
                type = "polygon",
                color = { 0.55, 0.55, 0.7, 1 },
                points = { -30, -70, -60, -110, -90, -90, -55, -55 },
                outline = { 0.3, 0.3, 0.5, 1 },
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