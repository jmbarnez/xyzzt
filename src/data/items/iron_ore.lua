return {
    id = "iron_ore",
    name = "Iron Ore",
    type = "resource",

    volume = 1.0,
    lifetime = 60,

    render = {
        type = "polygon",
        size = 4,
        color = { 0.8, 0.6, 0.4, 1 },
        num_points = { 5, 7 },
        radius_variation = { 0.7, 1.3 },
    },

    physics = {
        mass = 0.6,
        linear_damping = 1.0,
        angular_damping = 1.0,
        spawn_velocity = {
            speed_min = 10,
            speed_max = 30,
            angular_min = -2,
            angular_max = 2,
        },
    },

    generate_shape = function(self)
        local vertices = {}
        local radius = self.render.size
        local num_points = math.random(self.render.num_points[1], self.render.num_points[2])

        for i = 1, num_points do
            local angle = (i - 1) * (2 * math.pi / num_points)
            local r = radius * (self.render.radius_variation[1]
                + math.random() * (self.render.radius_variation[2] - self.render.radius_variation[1]))
            table.insert(vertices, r * math.cos(angle))
            table.insert(vertices, r * math.sin(angle))
        end

        return vertices
    end,
}
