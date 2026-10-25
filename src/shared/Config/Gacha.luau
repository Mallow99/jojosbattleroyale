--!strict
-- Skin gacha. Skin ids match models in ServerStorage.Assets.Skins.
-- Rarity assignments are first-pass placeholders for tuning.
export type Rarity = "Common" | "Rare" | "Legendary"
export type Skin = { id: string, displayName: string, standId: string, rarity: Rarity }
export type Banner = {
	id: string,
	displayName: string,
	-- Pity counters are shared by banners in the same group.
	pityGroup: string,
	-- Skin ids that can drop. nil means every skin in the catalog.
	pool: { string }?,
	-- Skin ids with a rate-up inside their rarity.
	featured: { string }?,
}

local skins: { Skin } = {
	{
		id = "MangaPlatinum",
		displayName = "Manga Platinum",
		standId = "StarPlatinum",
		rarity = "Common",
	},
	{
		id = "FemalePlatinum",
		displayName = "Female Platinum",
		standId = "StarPlatinum",
		rarity = "Rare",
	},
	{
		id = "StonePlatinum",
		displayName = "Stone Platinum",
		standId = "StarPlatinum",
		rarity = "Legendary",
	},
	{
		id = "RetroTheWorld",
		displayName = "Retro The World",
		standId = "TheWorld",
		rarity = "Common",
	},
	{ id = "SumoTheWorld", displayName = "Sumo The World", standId = "TheWorld", rarity = "Rare" },
	{ id = "TheWaifuV2", displayName = "The Waifu V2", standId = "TheWorld", rarity = "Rare" },
	{
		id = "TheWorldGreatestHigh",
		displayName = "The World Greatest High",
		standId = "TheWorld",
		rarity = "Legendary",
	},
	{ id = "CrazyRuby", displayName = "Crazy Ruby", standId = "CrazyDiamond", rarity = "Common" },
	{ id = "JadePeace", displayName = "Jade Peace", standId = "CrazyDiamond", rarity = "Common" },
	{ id = "Tsunate", displayName = "Tsunate", standId = "CrazyDiamond", rarity = "Common" },
	{
		id = "CrazyOverseer",
		displayName = "Crazy Overseer",
		standId = "CrazyDiamond",
		rarity = "Rare",
	},
	{ id = "CrazyIdol", displayName = "Crazy Idol", standId = "CrazyDiamond", rarity = "Rare" },
	{ id = "Sakara", displayName = "Sakara", standId = "CrazyDiamond", rarity = "Legendary" },
	{
		id = "MonoCrimson",
		displayName = "Mono Crimson",
		standId = "KingCrimson",
		rarity = "Common",
	},
	{
		id = "VinegarCrimson",
		displayName = "Vinegar Crimson",
		standId = "KingCrimson",
		rarity = "Common",
	},
	{
		id = "QueenCrimson",
		displayName = "Queen Crimson",
		standId = "KingCrimson",
		rarity = "Rare",
	},
	{ id = "Sukuna", displayName = "Sukuna", standId = "KingCrimson", rarity = "Legendary" },
	{
		id = "VolcanicExperience",
		displayName = "Volcanic Experience",
		standId = "GoldExperience",
		rarity = "Rare",
	},
	{
		id = "LordBoros",
		displayName = "Lord Boros",
		standId = "GoldExperience",
		rarity = "Legendary",
	},
	{ id = "InvertSnake", displayName = "Invert-Snake", standId = "Whitesnake", rarity = "Common" },
	{
		id = "AlabasterSerpent",
		displayName = "Alabaster Serpent",
		standId = "Whitesnake",
		rarity = "Common",
	},
	{ id = "DeimosSnake", displayName = "Deimos Snake", standId = "Whitesnake", rarity = "Rare" },
	{
		id = "FrenchChariot",
		displayName = "French Chariot",
		standId = "SilverChariot",
		rarity = "Common",
	},
	{ id = "Asuna", displayName = "Asuna", standId = "SilverChariot", rarity = "Rare" },
	{ id = "UberSpy", displayName = "Uber Spy", standId = "SilverChariot", rarity = "Rare" },
	{ id = "ChromeHand", displayName = "Chrome Hand", standId = "TheHand", rarity = "Common" },
}

local standard: Banner = {
	id = "Standard",
	displayName = "Standard Banner",
	pityGroup = "Standard",
	pool = nil,
	featured = nil,
}

-- Limited banners rotate automatically: one is live per period, in this order.
local limited: { Banner } = {
	{
		id = "StardustCrusaders",
		displayName = "Stardust Crusaders",
		pityGroup = "Limited",
		pool = {
			"MangaPlatinum",
			"FemalePlatinum",
			"StonePlatinum",
			"RetroTheWorld",
			"SumoTheWorld",
			"TheWaifuV2",
			"TheWorldGreatestHigh",
			"FrenchChariot",
			"Asuna",
			"UberSpy",
		},
		featured = { "StonePlatinum", "TheWorldGreatestHigh" },
	},
	{
		id = "DiamondIsUnbreakable",
		displayName = "Diamond is Unbreakable",
		pityGroup = "Limited",
		pool = {
			"CrazyRuby",
			"JadePeace",
			"Tsunate",
			"CrazyOverseer",
			"CrazyIdol",
			"Sakara",
			"ChromeHand",
			"VolcanicExperience",
			"LordBoros",
		},
		featured = { "Sakara" },
	},
	{
		id = "GoldenWind",
		displayName = "Golden Wind",
		pityGroup = "Limited",
		pool = {
			"MonoCrimson",
			"VinegarCrimson",
			"QueenCrimson",
			"Sukuna",
			"VolcanicExperience",
			"LordBoros",
			"InvertSnake",
			"AlabasterSerpent",
			"DeimosSnake",
		},
		featured = { "Sukuna", "LordBoros" },
	},
}

local byId: { [string]: Skin } = {}
for _, skin in skins do
	byId[skin.id] = skin
end

return table.freeze({
	skins = skins,
	skinsById = byId,
	rarityOrder = { "Common", "Rare", "Legendary" } :: { Rarity },
	-- Chance of each rarity per pull. Must sum to 1.
	rates = { Common = 0.6, Rare = 0.35, Legendary = 0.05 },
	-- A Legendary is guaranteed on this pull if none dropped in the previous ones.
	hardPity = 20,
	-- Share of a rarity's drops that go to that rarity's featured skins.
	featuredShare = 0.5,
	pullCost = 100,
	multiPullCount = 10,
	duplicateShards = { Common = 1, Rare = 1, Legendary = 1 },
	craftCost = { Common = 3, Rare = 6, Legendary = 12 },
	rarityColors = {
		Common = { 190, 190, 190 },
		Rare = { 80, 160, 255 },
		Legendary = { 255, 200, 60 },
	},
	standardBanner = standard,
	limitedRotation = {
		-- 2026-11-01 00:00 UTC. Rotation index = floor((now - epoch) / period) % #banners.
		epoch = 1793491200,
		periodSeconds = 14 * 24 * 60 * 60,
		banners = limited,
	},
})
