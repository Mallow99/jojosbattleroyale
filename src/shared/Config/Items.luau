--!strict
-- World loot. Weapon and heal ids match Tools in ServerStorage.Assets.Weapons/Heals.
export type Weapon = {
	id: string,
	displayName: string,
	damage: number,
	range: number,
	cooldown: number,
}
export type Heal = { id: string, displayName: string, amount: number, useTime: number }

local fists: Weapon =
	{ id = "Fists", displayName = "Fists", damage = 6, range = 5, cooldown = 0.35 }

local weapons: { [string]: Weapon } = {
	Katana = { id = "Katana", displayName = "Katana", damage = 14, range = 7, cooldown = 0.55 },
	Dagger = { id = "Dagger", displayName = "Dagger", damage = 10, range = 5.5, cooldown = 0.35 },
	Knife = { id = "Knife", displayName = "DIO's Knife", damage = 11, range = 5.5, cooldown = 0.4 },
	Shovel = { id = "Shovel", displayName = "Shovel", damage = 12, range = 6.5, cooldown = 0.6 },
}

local heals: { [string]: Heal } = {
	Tea = { id = "Tea", displayName = "Tea", amount = 35, useTime = 2 },
}

-- Relative weights for each loot point.
local lootWeights = {
	{ kind = "Disc", weight = 35 },
	{ kind = "Weapon", weight = 30 },
	{ kind = "Heal", weight = 25 },
	{ kind = "StandArrow", weight = 10 },
}

return table.freeze({
	fists = table.freeze(fists),
	weapons = table.freeze(weapons),
	heals = table.freeze(heals),
	lootWeights = table.freeze(lootWeights),
	-- Map markers are topped up with random ground points to this many loot points.
	lootPointTarget = 140,
	pickupRange = 12,
})
