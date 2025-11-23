local Config = require "src.config"

return {
    name = "Starter Drone",

    -- Physics
    mass = 1,
    linear_damping = Config.LINEAR_DAMPING,
    restitution = 0.2,
    radius = 10,

    weapon_mounts = {
        { x = 12, y = 0 },
    },

    -- Vehicle Stats
    thrust = Config.THRUST,
    rotation_speed = Config.ROTATION_SPEED,
    max_speed = Config.MAX_SPEED,
    max_hull = 100,
    max_shield = 100,
    shield_regen = 5,

    -- Render Data (Data-Driven)
    render_data = {
        shapes = {
            -- Main Hull (Forward Section)
            {
                type = "polygon",
                color = { 0.2, 0.4, 0.8, 1 },
                points = { 12, 0, 8, 2, 2, 3, -4, 3, -4, -3, 2, -3, 8, -2 },
                outline = { 0, 0, 0, 1 }
            },

            -- Central Body
            {
                type = "polygon",
                color = { 0.18, 0.36, 0.72, 1 },
                points = { 2, 4, -4, 4, -8, 3, -8, -3, -4, -4, 2, -4 },
                outline = { 0, 0, 0, 1 }
            },

            -- Cockpit Canopy
            {
                type = "polygon",
                color = { 0.1, 0.3, 0.6, 1 },
                points = { 8, 0, 6, 1.5, 3, 2, 0, 2, 0, -2, 3, -2, 6, -1.5 },
                outline = { 0.05, 0.15, 0.4, 1 }
            },

            -- Cockpit Detail
            {
                type = "circle",
                color = { 0.3, 0.5, 1, 0.8 },
                x = 5,
                y = 0,
                radius = 1,
                outline = { 0.1, 0.2, 0.5, 1 }
            },

            -- Left Wing
            {
                type = "polygon",
                color = { 0.2, 0.4, 0.8, 1 },
                points = { 0, 4, -6, 7, -10, 9, -10, 4, -6, 3 },
                outline = { 0, 0, 0, 1 }
            },

            -- Right Wing
            {
                type = "polygon",
                color = { 0.2, 0.4, 0.8, 1 },
                points = { 0, -4, -6, -7, -10, -9, -10, -4, -6, -3 },
                outline = { 0, 0, 0, 1 }
            },

            -- Left Wing Strut
            {
                type = "polygon",
                color = { 0.15, 0.3, 0.6, 1 },
                points = { -3, 3.5, -8, 5, -8, 4, -3, 3 },
                outline = { 0, 0, 0, 1 }
            },

            -- Right Wing Strut
            {
                type = "polygon",
                color = { 0.15, 0.3, 0.6, 1 },
                points = { -3, -3.5, -8, -5, -8, -4, -3, -3 },
                outline = { 0, 0, 0, 1 }
            },

            -- Left Engine Nacelle
            {
                type = "polygon",
                color = { 0.15, 0.3, 0.6, 1 },
                points = { -6, 7, -11, 7.5, -12, 8.5, -12, 9.5, -10, 9.5, -8, 8 },
                outline = { 0, 0, 0, 1 }
            },

            -- Right Engine Nacelle
            {
                type = "polygon",
                color = { 0.15, 0.3, 0.6, 1 },
                points = { -6, -7, -11, -7.5, -12, -8.5, -12, -9.5, -10, -9.5, -8, -8 },
                outline = { 0, 0, 0, 1 }
            },

            -- Left Engine Glow
            {
                type = "circle",
                color = { 0.4, 0.6, 1, 0.6 },
                x = -12,
                y = 9,
                radius = 0.8,
                outline = { 0.2, 0.4, 0.8, 1 }
            },

            -- Right Engine Glow
            {
                type = "circle",
                color = { 0.4, 0.6, 1, 0.6 },
                x = -12,
                y = -9,
                radius = 0.8,
                outline = { 0.2, 0.4, 0.8, 1 }
            },

            -- Left Weapon Pod
            {
                type = "polygon",
                color = { 0.12, 0.25, 0.5, 1 },
                points = { -9, 5, -11, 5.5, -11, 6.5, -9, 6.5 },
                outline = { 0, 0, 0, 1 }
            },

            -- Right Weapon Pod
            {
                type = "polygon",
                color = { 0.12, 0.25, 0.5, 1 },
                points = { -9, -5, -11, -5.5, -11, -6.5, -9, -6.5 },
                outline = { 0, 0, 0, 1 }
            },

            -- Nose Sensor
            {
                type = "circle",
                color = { 0.3, 0.5, 1, 1 },
                x = 12,
                y = 0,
                radius = 1.2,
                outline = { 0, 0, 0, 1 }
            },

            -- Nose Sensor Detail
            {
                type = "circle",
                color = { 0.5, 0.7, 1, 1 },
                x = 12,
                y = 0,
                radius = 0.6,
                outline = { 0.1, 0.2, 0.5, 1 }
            },

            -- Left Hull Accent
            {
                type = "polygon",
                color = { 0.25, 0.45, 0.85, 1 },
                points = { 4, 2, 0, 2.5, -2, 2.5, -2, 1.5, 0, 1.5, 4, 1 },
                outline = { 0, 0, 0, 0 }
            },

            -- Right Hull Accent
            {
                type = "polygon",
                color = { 0.25, 0.45, 0.85, 1 },
                points = { 4, -2, 0, -2.5, -2, -2.5, -2, -1.5, 0, -1.5, 4, -1 },
                outline = { 0, 0, 0, 0 }
            }
        }
    }
}
