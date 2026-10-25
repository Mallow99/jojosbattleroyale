--!strict
-- Stand discs found in a match. `id` matches the package in ServerStorage.Assets.Stands.
-- Abilities are not implemented yet; each Stand currently changes basic attack damage,
-- walk speed and max health while its disc is active.
export type Stand = {
	id: string,
	displayName: string,
	-- Relative chance of this Stand on a found disc or a Stand Arrow.
	weight: number,
	damageMultiplier: number,
	speedMultiplier: number,
	maxHealthBonus: number,
}

local list: { Stand } = {
	{
		id = "StarPlatinum",
		displayName = "Star Platinum",
		weight = 10,
		damageMultiplier = 1.5,
		speedMultiplier = 1.0,
		maxHealthBonus = 20,
	},
	{
		id = "TheWorld",
		displayName = "The World",
		weight = 10,
		damageMultiplier = 1.5,
		speedMultiplier = 1.0,
		maxHealthBonus = 20,
	},
	{
		id = "CrazyDiamond",
		displayName = "Crazy Diamond",
		weight = 12,
		damageMultiplier = 1.4,
		speedMultiplier = 1.0,
		maxHealthBonus = 30,
	},
	{
		id = "KingCrimson",
		displayName = "King Crimson",
		weight = 10,
		damageMultiplier = 1.45,
		speedMultiplier = 1.05,
		maxHealthBonus = 15,
	},
	{
		id = "GoldExperience",
		displayName = "Gold Experience",
		weight = 12,
		damageMultiplier = 1.3,
		speedMultiplier = 1.0,
		maxHealthBonus = 35,
	},
	{
		id = "Whitesnake",
		displayName = "Whitesnake",
		weight = 12,
		damageMultiplier = 1.35,
		speedMultiplier = 1.0,
		maxHealthBonus = 25,
	},
	{
		id = "SilverChariot",
		displayName = "Silver Chariot",
		weight = 14,
		damageMultiplier = 1.3,
		speedMultiplier = 1.12,
		maxHealthBonus = 10,
	},
	{
		id = "TheHand",
		displayName = "The Hand",
		weight = 14,
		damageMultiplier = 1.4,
		speedMultiplier = 1.0,
		maxHealthBonus = 20,
	},
}

local byId: { [string]: Stand } = {}
for _, stand in list do
	table.freeze(stand)
	byId[stand.id] = stand
end

return table.freeze({
	list = table.freeze(list),
	byId = table.freeze(byId),
})
