local Concord = require "lib.concord.concord"
local Theme   = require "src.ui.theme"

local FloatingTextSystem = Concord.system({
    pool = { "floating_text" }
})

function FloatingTextSystem:update(dt)
    for _, e in ipairs(self.pool) do
        local ft = e.floating_text
        ft.elapsed = ft.elapsed + dt
        if ft.elapsed >= ft.duration then
            if e.destroy then
                e:destroy()
            else
                local world = self:getWorld()
                if world and world.removeEntity then
                    world:removeEntity(e)
                end
            end
        else
            ft.y = ft.y - 20 * dt -- Move up
            local alpha = 1 - (ft.elapsed / ft.duration)
            ft.color[4] = alpha
        end
    end
end

function FloatingTextSystem:draw()
    local world = self:getWorld()
    if not world then
        return
    end

    local camera = world.camera
    local font = Theme.getFont("chat")
    love.graphics.setFont(font)

    if camera then
        for _, e in ipairs(self.pool) do
            local ft = e.floating_text
            local sx, sy = camera:cameraCoords(ft.x, ft.y)
            local alpha = ft.color[4] or 1
            -- Subtle shadow for readability
            love.graphics.setColor(0, 0, 0, alpha * 0.8)
            love.graphics.print(ft.text, sx + 1, sy + 1)
            -- Main text
            love.graphics.setColor(ft.color)
            love.graphics.print(ft.text, sx, sy)
        end
    else
        for _, e in ipairs(self.pool) do
            local ft = e.floating_text
            local alpha = ft.color[4] or 1
            love.graphics.setColor(0, 0, 0, alpha * 0.8)
            love.graphics.print(ft.text, ft.x + 1, ft.y + 1)
            love.graphics.setColor(ft.color)
            love.graphics.print(ft.text, ft.x, ft.y)
        end
    end
end

return FloatingTextSystem
