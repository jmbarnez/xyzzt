local pulse_laser = require "src.plugins.weapons.pulse_laser"

local WeaponRegistry = {}

local plugins = {
	pulse_laser,
}

WeaponRegistry.weapons = {}

function WeaponRegistry.load_plugins()
	for _, weapon in ipairs(plugins) do
		WeaponRegistry.weapons[weapon.name] = weapon
	end
end

function WeaponRegistry.get_weapon(name)
	return WeaponRegistry.weapons[name]
end

return WeaponRegistry
