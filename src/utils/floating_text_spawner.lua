local Concord = require "lib.concord.concord"

local FloatingTextSpawner = {}

function FloatingTextSpawner.spawn(world, text, x, y, color)
	local entity = Concord.entity(world)
	entity:give("floating_text", text, x, y, 1.0, color)
	-- Floating text is pure VFX; exclude it from serialization
	if entity.remove then
		entity:remove("serializable")
	end
	return entity
end

return FloatingTextSpawner
