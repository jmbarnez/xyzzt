local Ships = require "src.data.ships"

local RenderStrategies = {}

local asteroidShapes = {}
local asteroidShader = nil

local function hashString(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end

local function getColorFromRender(r)
    local color = { 1, 1, 1, 1 }

    if type(r) == "table" then
        if type(r.color) == "table" then
            color = r.color
        elseif #r >= 3 then
            color = r
        end
    elseif type(r) == "number" then
        color = { r, r, r, 1 }
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    return cr, cg, cb, ca
end

local function getRadiusFromRender(r, defaultRadius)
    local radius = defaultRadius or 10
    if type(r) == "table" and r.radius then
        radius = r.radius
    end
    return radius
end

function RenderStrategies.asteroid(e)
    local r = e.render

    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)

    local key = tostring(e)
    local poly = nil
    local mesh = nil

    local isNetworkedAsteroid = (e.asteroid ~= nil) and (e.network_id ~= nil)

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    elseif isNetworkedAsteroid then
        -- For network-synced asteroids, never generate a new random shape.
        -- If vertices are missing for some reason, fall back to a simple circle
        -- so the host and all clients see the same basic geometry instead of
        -- diverging random polygons.
        love.graphics.circle("fill", 0, 0, radius)
        return
    else
        -- Check if we have a cached mesh
        local meshKey = key .. "_mesh"
        mesh = asteroidShapes[meshKey]

        if not mesh then
            -- Generate polygon if not cached
            poly = asteroidShapes[key]
            if not poly then
                poly = {}
                local seed = hashString(key)
                local rng = (love and love.math and love.math.newRandomGenerator) and
                    love.math.newRandomGenerator(seed) or nil
                local function rnd()
                    if rng and rng.random then
                        return rng:random()
                    else
                        return math.random()
                    end
                end

                -- Match physics generator: 5–8 vertices max to satisfy Box2D limits
                local vertex_count = 5 + math.floor(rnd() * 4) -- 5–8 vertices
                if vertex_count < 5 then vertex_count = 5 end
                if vertex_count > 8 then vertex_count = 8 end

                for i = 1, vertex_count do
                    local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.4
                    local rr = radius * (0.7 + rnd() * 0.4)
                    table.insert(poly, math.cos(angle) * rr)
                    table.insert(poly, math.sin(angle) * rr)
                end

                asteroidShapes[key] = poly
            end

            -- Create mesh from polygon using triangulation
            -- Calculate centroid for fan triangulation
            local cx, cy = 0, 0
            local vertCount = #poly / 2
            for i = 1, vertCount do
                cx = cx + poly[(i - 1) * 2 + 1]
                cy = cy + poly[(i - 1) * 2 + 2]
            end
            cx = cx / vertCount
            cy = cy / vertCount

            -- Find bounding box for UV normalization
            local minX, maxX = poly[1], poly[1]
            local minY, maxY = poly[2], poly[2]
            for i = 1, vertCount do
                local x = poly[(i - 1) * 2 + 1]
                local y = poly[(i - 1) * 2 + 2]
                minX = math.min(minX, x)
                maxX = math.max(maxX, x)
                minY = math.min(minY, y)
                maxY = math.max(maxY, y)
            end
            local width = maxX - minX
            local height = maxY - minY
            local scale = math.max(width, height)

            -- Build vertex list for mesh (triangle fan from center)
            local vertices = {}
            for i = 1, vertCount do
                local x = poly[(i - 1) * 2 + 1]
                local y = poly[(i - 1) * 2 + 2]
                local u = (x - minX) / scale
                local v = (y - minY) / scale
                table.insert(vertices, { x, y, u, v, 1, 1, 1, 1 })
            end

            -- Create mesh with triangle fan
            local triangles = {}
            for i = 1, vertCount do
                local next = (i % vertCount) + 1
                table.insert(triangles, {
                    { cx, cy, 0.5, 0.5, 1, 1, 1, 1 },
                    vertices[i],
                    vertices[next]
                })
            end

            -- Flatten triangles into single vertex list
            local flatVertices = {}
            for _, tri in ipairs(triangles) do
                for _, v in ipairs(tri) do
                    table.insert(flatVertices, v)
                end
            end

            mesh = love.graphics.newMesh(flatVertices, "triangles", "static")
            asteroidShapes[meshKey] = mesh
        end

        poly = asteroidShapes[key]
        -- Store generated vertices in component for outline rendering
        if poly and type(r) == "table" then
            r.vertices = poly
        end
    end

    -- Load shader on first use
    if not asteroidShader then
        local shader_path = "assets/shaders/asteroid.glsl"
        if love.filesystem.getInfo(shader_path) then
            asteroidShader = love.graphics.newShader(shader_path)
        end
    end

    -- Apply shader if available
    if asteroidShader then
        love.graphics.setShader(asteroidShader)

        -- Use a deterministic, network-synced seed for the asteroid texture
        -- Prefer render.seed (may be propagated to chunks), then asteroid.seed,
        -- and finally fall back to a hash of the entity key.
        local seedVal
        if type(r) == "table" and r.seed then
            seedVal = r.seed
        elseif e.asteroid and e.asteroid.seed then
            seedVal = e.asteroid.seed
        else
            seedVal = hashString(key)
        end

        -- Store seed in render component so chunks or other systems can inherit it
        if type(r) == "table" and not r.seed then
            r.seed = seedVal
        end

        local seed = seedVal / 2147483647 -- Normalize to 0-1
        asteroidShader:send("seed", seed)
    end

    -- Draw base asteroid shape with shader
    love.graphics.setColor(cr, cg, cb, ca)
    if mesh then
        love.graphics.draw(mesh)
    else
        love.graphics.polygon("fill", poly)
    end

    -- Reset shader
    if asteroidShader then
        love.graphics.setShader()
    end

    -- Black outline for crisp definition (very thin outline)
    if poly then
        local oldLineWidth = love.graphics.getLineWidth()
        local oldLineStyle = love.graphics.getLineStyle()
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(0.5)
        love.graphics.setLineStyle("rough") -- Disable anti-aliasing for crisp lines
        love.graphics.polygon("line", poly)
        love.graphics.setLineWidth(oldLineWidth)
        love.graphics.setLineStyle(oldLineStyle)
    end

    love.graphics.setColor(cr, cg, cb, ca)
end

function RenderStrategies.asteroid_chunk(e)
    local r = e.render

    local cr, cg, cb, ca = getColorFromRender(r)
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = getRadiusFromRender(r, 10)

    local key = tostring(e)
    local poly = nil
    local mesh = nil

    if type(r) == "table" and r.vertices then
        poly = r.vertices
    else
        -- Check if we have a cached mesh
        local meshKey = key .. "_mesh"
        mesh = asteroidShapes[meshKey]

        if not mesh then
            -- Generate polygon if not cached
            poly = asteroidShapes[key]
            if not poly then
                poly = {}
                local seed = hashString(key)
                local rng = (love and love.math and love.math.newRandomGenerator) and
                    love.math.newRandomGenerator(seed) or nil
                local function rnd()
                    if rng and rng.random then
                        return rng:random()
                    else
                        return math.random()
                    end
                end

                local vertex_count = 4 + math.floor(rnd() * 3)
                if vertex_count < 4 then vertex_count = 4 end

                for i = 1, vertex_count do
                    local angle = (i / vertex_count) * math.pi * 2 + (rnd() - 0.5) * 0.6
                    local rr = radius * (0.6 + rnd() * 0.5)
                    table.insert(poly, math.cos(angle) * rr)
                    table.insert(poly, math.sin(angle) * rr)
                end

                asteroidShapes[key] = poly
            end

            -- Create mesh from polygon using triangulation
            -- Calculate centroid for fan triangulation
            local cx, cy = 0, 0
            local vertCount = #poly / 2
            for i = 1, vertCount do
                cx = cx + poly[(i - 1) * 2 + 1]
                cy = cy + poly[(i - 1) * 2 + 2]
            end
            cx = cx / vertCount
            cy = cy / vertCount

            -- Find bounding box for UV normalization
            local minX, maxX = poly[1], poly[1]
            local minY, maxY = poly[2], poly[2]
            for i = 1, vertCount do
                local x = poly[(i - 1) * 2 + 1]
                local y = poly[(i - 1) * 2 + 2]
                minX = math.min(minX, x)
                maxX = math.max(maxX, x)
                minY = math.min(minY, y)
                maxY = math.max(maxY, y)
            end
            local width = maxX - minX
            local height = maxY - minY
            local scale = math.max(width, height)

            -- Build vertex list for mesh (triangle fan from center)
            local vertices = {}
            for i = 1, vertCount do
                local x = poly[(i - 1) * 2 + 1]
                local y = poly[(i - 1) * 2 + 2]
                local u = (x - minX) / scale
                local v = (y - minY) / scale
                table.insert(vertices, { x, y, u, v, 1, 1, 1, 1 })
            end

            -- Create mesh with triangle fan
            local triangles = {}
            for i = 1, vertCount do
                local next = (i % vertCount) + 1
                table.insert(triangles, {
                    { cx, cy, 0.5, 0.5, 1, 1, 1, 1 },
                    vertices[i],
                    vertices[next]
                })
            end

            -- Flatten triangles into single vertex list
            local flatVertices = {}
            for _, tri in ipairs(triangles) do
                for _, v in ipairs(tri) do
                    table.insert(flatVertices, v)
                end
            end

            mesh = love.graphics.newMesh(flatVertices, "triangles", "static")
            asteroidShapes[meshKey] = mesh
        end

        poly = asteroidShapes[key]
        -- Store generated vertices in component for outline rendering
        if poly and type(r) == "table" then
            r.vertices = poly
        end
    end

    -- Load shader on first use
    if not asteroidShader then
        local shader_path = "assets/shaders/asteroid.glsl"
        if love.filesystem.getInfo(shader_path) then
            asteroidShader = love.graphics.newShader(shader_path)
        end
    end

    -- Apply shader if available
    if asteroidShader then
        love.graphics.setShader(asteroidShader)
        -- Send unique seed for this asteroid chunk to make texture stable
        -- Use inherited seed if available, otherwise generate one
        local seed = 0
        if type(r) == "table" and r.seed then
            seed = r.seed
        else
            seed = hashString(key)
        end

        -- Normalize to 0-1 range for shader
        -- If seed is already large (from hash), normalize it. If it's small (passed from parent), use as is?
        -- Actually, the parent seed was likely generated via hashString too, so it's a large integer.
        -- We should normalize it consistently.
        seed = seed / 2147483647

        asteroidShader:send("seed", seed)
    end

    -- Draw chunk shape with shader
    love.graphics.setColor(cr, cg, cb, ca)
    if mesh then
        love.graphics.draw(mesh)
    else
        love.graphics.polygon("fill", poly)
    end

    -- Reset shader
    if asteroidShader then
        love.graphics.setShader()
    end

    -- Black outline (very thin outline)
    if poly then
        local oldLineWidth = love.graphics.getLineWidth()
        local oldLineStyle = love.graphics.getLineStyle()
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(0.5)
        love.graphics.setLineStyle("rough") -- Disable anti-aliasing for crisp lines
        love.graphics.polygon("line", poly)
        love.graphics.setLineWidth(oldLineWidth)
        love.graphics.setLineStyle(oldLineStyle)
    end
end

function RenderStrategies.projectile_shard(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" and r.color then
        color = r.color
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    if e.lifetime then
        local fade = 1.0 - (e.lifetime.elapsed / e.lifetime.duration)
        ca = ca * math.max(0, fade)
    end

    love.graphics.setColor(cr, cg, cb, ca)

    if type(r) == "table" and r.vertices then
        love.graphics.polygon("fill", r.vertices)

        local outline_alpha = ca * 0.6
        love.graphics.setColor(cr * 0.7, cg * 0.7, cb * 0.7, outline_alpha)
        love.graphics.setLineWidth(0.5)
        love.graphics.polygon("line", r.vertices)
    else
        local radius = 2
        if type(r) == "table" and r.radius then
            radius = r.radius
        end
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.item(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" and r.color then
        color = r.color
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1

    love.graphics.setColor(cr, cg, cb, ca)

    if type(r) == "table" and r.shape then
        love.graphics.polygon("fill", r.shape)

        local orr = cr * 0.5
        local org = cg * 0.5
        local orb = cb * 0.5
        love.graphics.setColor(orr, org, orb, ca)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line", r.shape)
    else
        local radius = 4
        if type(r) == "table" and r.radius then
            radius = r.radius
        end
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.projectile(e)
    local r = e.render

    local color = r.color or { 1, 1, 1, 1 }
    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1
    love.graphics.setColor(cr, cg, cb, ca)

    local shape = r.shape or "beam"
    if shape == "beam" then
        local radius = r.radius or 3
        local length = r.length or (radius * 4)
        local thickness = r.thickness or (radius * 0.7)
        love.graphics.rectangle("fill", -length * 0.5, -thickness * 0.5, length, thickness)
    elseif shape == "circle" then
        local radius = r.radius or 3
        love.graphics.circle("fill", 0, 0, radius)
    else
        local radius = r.radius or 3
        love.graphics.circle("fill", 0, 0, radius)
    end
end

function RenderStrategies.ship(e)
    local r = e.render
    if not r then return end

    -- Color tint for player (green) or enemy (red)
    local tint = r.color or { 1, 1, 1, 1 }

    if r.shapes then
        -- Iterate through the data-driven shape list
        for _, shape in ipairs(r.shapes) do
            -- Blend shape color with tint by multiplication
            local shapeColor = shape.color or { 1, 1, 1, 1 }
            local blended = {
                shapeColor[1] * tint[1],
                shapeColor[2] * tint[2],
                shapeColor[3] * tint[3],
                (shapeColor[4] or 1) * (tint[4] or 1)
            }
            love.graphics.setColor(blended)

            if shape.type == "polygon" and shape.points then
                love.graphics.polygon("fill", shape.points)
                if shape.outline then
                    love.graphics.setColor(shape.outline)
                    love.graphics.setLineWidth(1)
                    love.graphics.polygon("line", shape.points)
                end
            elseif shape.type == "circle" then
                local cx = shape.x or 0
                local cy = shape.y or 0
                local rad = shape.radius or 2
                love.graphics.circle("fill", cx, cy, rad)
                if shape.outline then
                    love.graphics.setColor(shape.outline)
                    love.graphics.circle("line", cx, cy, rad)
                end
            end
        end
    else
        -- Fallback for ships without shape data (e.g., placeholder or procedural)
        love.graphics.setColor(tint)
        love.graphics.circle("fill", 0, 0, 10)
        -- Nose indicator
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.line(0, 0, 10, 0)
    end
end

function RenderStrategies.procedural(e)
    local r = e.render
    if not r or not r.render_data then return end

    local data = r.render_data

    -- Color tint (e.g. red for enemies, green for allies)
    local tint = r.color or { 1, 1, 1, 1 }

    -- 1. Draw Main Hull
    -- Use base color from data, tinted by entity color
    local base_color = data.base_color or { 0.5, 0.5, 0.5, 1 }
    love.graphics.setColor(
        base_color[1] * tint[1],
        base_color[2] * tint[2],
        base_color[3] * tint[3],
        base_color[4] or 1
    )

    if data.hull then
        love.graphics.polygon("fill", data.hull)

        -- Hull Outline
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", data.hull)
    end

    -- 2. Draw Panel Lines (Surface Details)
    if data.panel_lines then
        local detail_color = data.detail_color or { 0.3, 0.3, 0.3, 1 }
        love.graphics.setColor(
            detail_color[1] * tint[1],
            detail_color[2] * tint[2],
            detail_color[3] * tint[3],
            0.4
        )
        love.graphics.setLineWidth(1)
        for _, line in ipairs(data.panel_lines) do
            if line.x1 and line.y1 and line.x2 and line.y2 then
                love.graphics.line(line.x1, line.y1, line.x2, line.y2)
            end
        end
    end

    -- 3. Draw Cockpit
    if data.cockpit and #data.cockpit >= 6 then
        local accent_color = data.accent_color or { 0, 0.8, 1, 1 }

        -- Cockpit Base
        love.graphics.setColor(
            accent_color[1],
            accent_color[2],
            accent_color[3],
            0.6
        )
        love.graphics.polygon("fill", data.cockpit)

        -- Cockpit Glass Highlight
        love.graphics.setColor(0.6, 0.8, 1, 0.3)
        love.graphics.polygon("fill", data.cockpit)
    end

    -- 4. Draw Weapon Hardpoints
    if data.weapon_hardpoints then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        for _, wp in ipairs(data.weapon_hardpoints) do
            love.graphics.circle("fill", wp.x, wp.y, 1.5)
        end
    end

    -- 5. Draw Engines
    if data.engines then
        for _, eng in ipairs(data.engines) do
            local eng_color = eng.color or { 0, 1, 1, 1 }

            -- Outer Glow
            love.graphics.setColor(eng_color[1], eng_color[2], eng_color[3], 0.3)
            love.graphics.circle("fill", eng.x, eng.y, eng.radius * 1.5)

            -- Inner Core
            love.graphics.setColor(eng_color[1], eng_color[2], eng_color[3], 0.8)
            love.graphics.circle("fill", eng.x, eng.y, eng.radius * 0.8)

            -- Bright Center
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.circle("fill", eng.x, eng.y, eng.radius * 0.3)
        end
    end

    love.graphics.setLineWidth(1)
end

function RenderStrategies.fallback(e)
    local r = e.render

    local color = { 1, 1, 1, 1 }
    if type(r) == "table" then
        if type(r.color) == "table" then
            color = r.color
        elseif #r >= 3 then
            color = r
        end
    elseif type(r) == "number" then
        color = { r, r, r, 1 }
    end

    local cr = color[1] or 1
    local cg = color[2] or 1
    local cb = color[3] or 1
    local ca = color[4] or 1
    love.graphics.setColor(cr, cg, cb, ca)

    local radius = 10
    if type(r) == "table" and r.radius then
        radius = r.radius
    end

    love.graphics.circle("fill", 0, 0, radius)
end

local DrawStrategies = {
    asteroid = RenderStrategies.asteroid,
    asteroid_chunk = RenderStrategies.asteroid_chunk,
    projectile_shard = RenderStrategies.projectile_shard,
    item = RenderStrategies.item,
    projectile = RenderStrategies.projectile,
    ship = RenderStrategies.ship,
    procedural = RenderStrategies.procedural,
}

local function resolve_type_key(e)
    local r = e.render

    if type(r) == "table" and r.type then
        if r.type == "asteroid" or r.type == "asteroid_chunk" or
            r.type == "projectile_shard" or r.type == "item" or
            r.type == "projectile" or r.type == "procedural" then
            return r.type
        else
            return "ship"
        end
    end

    return nil
end

local function draw(e)
    local r = e.render
    if not r then return end

    local key = resolve_type_key(e)
    local strategy = key and DrawStrategies[key] or nil

    if strategy then
        strategy(e)
    else
        RenderStrategies.fallback(e)
    end
end

return {
    draw = draw,
}
