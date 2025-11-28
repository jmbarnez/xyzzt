local Theme = require "src.ui.theme"

local HealthModel = {}

function HealthModel.getBarsForEntity(entity)
    if not entity then return {} end

    local bars = {}

    -- Ships: hull / shield
    local has_hull = (entity.hull and entity.hull.max and entity.hull.current)
    local has_shield = (entity.shield and entity.shield.max and entity.shield.current)

    if has_hull or has_shield then
        local healthColors = Theme.colors.health

        if has_shield then
            table.insert(bars, {
                id = "shield",
                label = "Shield",
                current = entity.shield.current,
                max = entity.shield.max,
                fill = healthColors and healthColors.shieldFill or { 0.2, 0.95, 1.0, 0.95 },
                bg = healthColors and healthColors.shieldBg or { 0.04, 0.08, 0.14, 0.9 },
                priority = 1,
            })
        end

        if has_hull then
            table.insert(bars, {
                id = "hull",
                label = "Hull",
                current = entity.hull.current,
                max = entity.hull.max,
                fill = healthColors and healthColors.hullFill or { 0.95, 0.25, 0.25, 0.95 },
                bg = healthColors and healthColors.hullBg or { 0.08, 0.05, 0.07, 0.9 },
                priority = 2,
            })
        end

    elseif entity.hp and entity.hp.max and entity.hp.current then
        -- Generic HP users (asteroids, chunks, etc.)
        local healthColors = Theme.colors.health
        table.insert(bars, {
            id = "hp",
            label = "HP",
            current = entity.hp.current,
            max = entity.hp.max,
            fill = healthColors and healthColors.hpFill or { 0.95, 0.25, 0.25, 0.95 },
            bg = healthColors and healthColors.hpBg or { 0.08, 0.05, 0.07, 0.9 },
            priority = 1,
        })
    end

    table.sort(bars, function(a, b)
        return (a.priority or 0) < (b.priority or 0)
    end)

    return bars
end

return HealthModel
