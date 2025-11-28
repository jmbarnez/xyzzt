local Concord = require "lib.concord.concord"

local FloatingTextSpawner = {}
 
local MERGE_RADIUS = 24

local function parseDamage(text)
	if not text then
		return nil
	end
	if string.sub(text, 1, 1) ~= "-" then
		return nil
	end
	local value = tonumber(string.sub(text, 2))
	return value
end

local function findNearbyDamageText(world, x, y, color)
	if not world or not world.getEntities then
		return nil
	end

	local entities = world:getEntities()
	if not entities or entities.size == 0 then
		return nil
	end

	local radiusSq = MERGE_RADIUS * MERGE_RADIUS

	for i = 1, entities.size do
		local e = entities[i]
		if e.floating_text then
			local ft = e.floating_text
			if parseDamage(ft.text) then
				local fx = ft.x or 0
				local fy = ft.y or 0
				local dx = fx - x
				local dy = fy - y
				if (dx * dx + dy * dy) <= radiusSq then
					local sameColor = true
					if color and ft.color then
						sameColor = (ft.color[1] == color[1] and ft.color[2] == color[2]
							and ft.color[3] == color[3])
					end
					if sameColor then
						return e
					end
				end
			end
		end
	end

	return nil
end

local function parsePlus(text)
	local amount, label = string.match(text or "", "^%+(%d+)%s+(.+)$")
	if amount then
		return tonumber(amount), label
	end
	return nil, nil
end

local function findNearbyPlusText(world, x, y, color, label)
	if not world or not world.getEntities then
		return nil
	end

	local entities = world:getEntities()
	if not entities or entities.size == 0 then
		return nil
	end

	local radiusSq = MERGE_RADIUS * MERGE_RADIUS

	for i = 1, entities.size do
		local e = entities[i]
		if e.floating_text then
			local ft = e.floating_text
			local existingAmount, existingLabel = parsePlus(ft.text)
			if existingAmount and existingLabel == label then
				local fx = ft.x or 0
				local fy = ft.y or 0
				local dx = fx - x
				local dy = fy - y
				if (dx * dx + dy * dy) <= radiusSq then
					local sameColor = true
					if color and ft.color then
						sameColor = (ft.color[1] == color[1] and ft.color[2] == color[2]
							and ft.color[3] == color[3])
					end
					if sameColor then
						return e
					end
				end
			end
		end
	end

	return nil
end

function FloatingTextSpawner.spawn(world, text, x, y, color)
	local damageAmount = parseDamage(text)

	if damageAmount and world then
		local existing = findNearbyDamageText(world, x, y, color)
		if existing and existing.floating_text then
			local ft = existing.floating_text
			local current = parseDamage(ft.text) or 0
			local total = current + damageAmount
			ft.text = "-" .. tostring(total)
			ft.elapsed = 0
			return existing
		end
	end

	local plusAmount, plusLabel = parsePlus(text)

	if plusAmount and plusLabel and world then
		local existingPlus = findNearbyPlusText(world, x, y, color, plusLabel)
		if existingPlus and existingPlus.floating_text then
			local ft = existingPlus.floating_text
			local currentAmount = select(1, parsePlus(ft.text)) or 0
			local total = currentAmount + plusAmount
			ft.text = "+" .. tostring(total) .. " " .. plusLabel
			ft.elapsed = 0
			return existingPlus
		end
	end

	local entity = Concord.entity(world)
	entity:give("floating_text", text, x, y, 1.0, color)
	-- Floating text is pure VFX; exclude it from serialization
	if entity.remove then
		entity:remove("serializable")
	end
	return entity
end

return FloatingTextSpawner
