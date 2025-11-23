-- Stone resource item definition
return {
    id = "stone",
    name = "Stone",
    type = "resource",

    -- Item properties
    volume = 1.0,
    lifetime = 60, -- seconds before despawn

    -- Visual properties
    render = {
        type = "polygon",
        size = 4,                     -- Much smaller than before (was 8)
        color = { 0.6, 0.6, 0.65, 1 }, -- Slightly bluish grey
        num_points = { 5, 7 },        -- Random between 5-7 points
        radius_variation = { 0.7, 1.3 } -- Random radius multiplier range
    },

    -- Physics properties
    physics = {
        mass = 0.5,
        linear_damping = 1.0,
        angular_damping = 1.0,
        sensor = true, -- Items don't collide, just trigger pickup
        spawn_velocity = {
            speed_min = 10,
            speed_max = 30,
            angular_min = -2,
            angular_max = 2
        }
    },

    -- Generate polygon vertices for this item
    generate_shape = function(self)
        local vertices = {}
        local radius = self.render.size
        local num_points = math.random(self.render.num_points[1], self.render.num_points[2])

        for i = 1, num_points do
            local angle = (i - 1) * (2 * math.pi / num_points)
            local r = radius * (self.render.radius_variation[1] +
                math.random() * (self.render.radius_variation[2] - self.render.radius_variation[1]))
            table.insert(vertices, r * math.cos(angle))
            table.insert(vertices, r * math.sin(angle))
        end

        return vertices
    end
}
