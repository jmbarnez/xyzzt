local Concord = require "lib.concord.concord"
local WeaponRegistry = require "src.managers.weapon_registry"
local MathUtils = require "src.utils.math_utils"

local WeaponSystem = Concord.system({
    pool = { "weapon", "input", "transform", "sector" }
})



function WeaponSystem:update(dt)
    local world = self:getWorld()

    for _, e in ipairs(self.pool) do
        local weapon = e.weapon
        local input = e.input
        local transform = e.transform
        local sector = e.sector

        weapon.cooldown = (weapon.cooldown or 0) - dt
        if weapon.cooldown < 0 then
            weapon.cooldown = 0
        end

        if not input.fire or weapon.cooldown > 0 then
            goto continue_weapon
        end

        local weapon_def = WeaponRegistry.get_weapon(weapon.weapon_name)
        if not weapon_def then
            goto continue_weapon
        end

        local mounts = weapon.mounts or { { x = 0, y = 0 } }
        local base_angle = transform.r or 0
        local desired_angle = input.target_angle or base_angle
        local max_offset = weapon_def.max_angle_offset
        if not max_offset then
            if weapon_def.cone_deg then
                max_offset = math.rad(weapon_def.cone_deg)
            else
                max_offset = math.pi
            end
        end
        -- Use MathUtils for angle difference calculation
        local diff = MathUtils.angle_difference(base_angle, desired_angle)
        diff = MathUtils.clamp(diff, -max_offset, max_offset)

        local angle = base_angle + diff
        local cos_a = math.cos(angle)
        local sin_a = math.sin(angle)

        for i = 1, #mounts do
            local mount = mounts[i]
            local mx = mount.x or 0
            local my = mount.y or 0

            local px = transform.x + mx * cos_a - my * sin_a
            local py = transform.y + mx * sin_a + my * cos_a


            local projectile = Concord.entity(world)
            projectile:give("transform", px, py, angle)
            projectile:give("sector", sector.x, sector.y)
            projectile:give("projectile", weapon_def.damage, weapon_def.lifetime or 1.5, e)

            local proj_cfg = weapon_def.projectile or {}
            local render_type = proj_cfg.type or proj_cfg.render_type or "projectile"
            local proj_color = proj_cfg.color or weapon_def.color
            local proj_radius = proj_cfg.radius or weapon_def.radius or 3
            local proj_length = proj_cfg.length
            local proj_thickness = proj_cfg.thickness
            local proj_shape = proj_cfg.shape

            projectile:give("render", {
                type = render_type,
                color = proj_color,
                radius = proj_radius,
                length = proj_length,
                thickness = proj_thickness,
                shape = proj_shape
            })
            if world.physics_world then
                local body = love.physics.newBody(world.physics_world, px, py, "dynamic")
                body:setBullet(true)
                body:setAngle(angle)

                -- Create polygon collision shape based on projectile visual type
                local shape
                if proj_shape == "beam" or not proj_shape then
                    -- Beam projectile: use rectangular polygon
                    local radius = proj_cfg.radius or weapon_def.radius or 3
                    local length = proj_length or (radius * 4)
                    local thickness = proj_thickness or (radius * 0.7)

                    -- Create rectangle vertices (centered at origin)
                    local half_length = length * 0.5
                    local half_thickness = thickness * 0.5
                    shape = love.physics.newPolygonShape(
                        -half_length, -half_thickness, -- bottom-left
                        half_length, -half_thickness,  -- bottom-right
                        half_length, half_thickness,   -- top-right
                        -half_length, half_thickness   -- top-left
                    )
                elseif proj_shape == "circle" then
                    -- Circle projectile: use octagon for better precision
                    local radius = proj_cfg.radius or weapon_def.radius or 3
                    local vertices = {}
                    for i = 0, 7 do
                        local angle_offset = (i / 8) * math.pi * 2
                        table.insert(vertices, math.cos(angle_offset) * radius)
                        table.insert(vertices, math.sin(angle_offset) * radius)
                    end
                    shape = love.physics.newPolygonShape(unpack(vertices))
                else
                    -- Fallback: small rectangle for unknown shapes
                    local radius = proj_cfg.radius or weapon_def.radius or 3
                    local half = radius * 0.7
                    shape = love.physics.newPolygonShape(
                        -half, -half,
                        half, -half,
                        half, half,
                        -half, half
                    )
                end

                -- Get mass from projectile config or weapon config, default to 0.1
                local mass = proj_cfg.mass or weapon_def.mass or 0.1
                local fixture = love.physics.newFixture(body, shape, mass)
                fixture:setRestitution(0)
                fixture:setSensor(true) -- Make sensor so it doesn't physically collide
                projectile:give("physics", body, shape, fixture)
                fixture:setUserData(projectile)

                local speed = weapon_def.projectile_speed or 800
                local vx = math.cos(angle) * speed
                local vy = math.sin(angle) * speed
                body:setLinearVelocity(vx, vy)
            end
        end

        weapon.cooldown = weapon_def.cooldown or 0.25

        ::continue_weapon::
    end
end

return WeaponSystem
