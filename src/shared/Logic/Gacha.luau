--!strict
-- Pure gacha rules: banner rotation, odds, pulls with pity, duplicates and crafting.
-- No Roblox APIs; the caller supplies the config, the time and a random source.
local Gacha = {}

-- Roblox `Random` or any object with a `NextNumber()` method returning [0, 1).
export type Rng = any
export type State = {
	pity: { [string]: number },
	owned: { [string]: boolean },
	shards: number,
}
export type PullResult = {
	skinId: string,
	rarity: string,
	duplicate: boolean,
	shards: number,
	pity: boolean,
}

local function find(list: { string }?, value: string): boolean
	return list ~= nil and table.find(list, value) ~= nil
end

-- The standard banner plus the limited banner live at `now`.
-- Each entry is `{ banner, endsAt }`; the standard banner never ends.
function Gacha.activeBanners(config: any, now: number): { { banner: any, endsAt: number? } }
	local banners: { { banner: any, endsAt: number? } } =
		{ { banner = config.standardBanner, endsAt = nil } }
	local rotation = config.limitedRotation
	if rotation and #rotation.banners > 0 and now >= rotation.epoch then
		local period = math.floor((now - rotation.epoch) / rotation.periodSeconds)
		local banner = rotation.banners[(period % #rotation.banners) + 1]
		table.insert(
			banners,
			{ banner = banner, endsAt = rotation.epoch + (period + 1) * rotation.periodSeconds }
		)
	end
	return banners
end

function Gacha.findActive(config: any, now: number, bannerId: string): any?
	for _, entry in Gacha.activeBanners(config, now) do
		if entry.banner.id == bannerId then
			return entry.banner
		end
	end
	return nil
end

-- Skin ids in the banner grouped by rarity.
function Gacha.pool(config: any, banner: any): { [string]: { string } }
	local grouped: { [string]: { string } } = {}
	for _, rarity in config.rarityOrder do
		grouped[rarity] = {}
	end
	for _, skin in config.skins do
		if banner.pool == nil or find(banner.pool, skin.id) then
			table.insert(grouped[skin.rarity], skin.id)
		end
	end
	return grouped
end

-- Probability of each rarity actually present in the pool, renormalized.
local function rarityRates(config: any, grouped: { [string]: { string } }): { [string]: number }
	local total = 0
	for _, rarity in config.rarityOrder do
		if #grouped[rarity] > 0 then
			total += config.rates[rarity]
		end
	end
	local rates = {}
	for _, rarity in config.rarityOrder do
		rates[rarity] = if #grouped[rarity] > 0 then config.rates[rarity] / total else 0
	end
	return rates
end

-- Per-skin chance on a normal (non-pity) pull, for the odds display.
function Gacha.odds(
	config: any,
	banner: any
): { { skinId: string, rarity: string, chance: number } }
	local grouped = Gacha.pool(config, banner)
	local rates = rarityRates(config, grouped)
	local result: { { skinId: string, rarity: string, chance: number } } = {}
	for _, rarity: string in config.rarityOrder do
		local ids = grouped[rarity]
		local featured: { string }, regular: { string } = {}, {}
		for _, id in ids do
			table.insert(if find(banner.featured, id) then featured else regular, id)
		end
		local featuredPart = if #featured == 0
			then 0
			elseif #regular == 0 then 1
			else config.featuredShare
		for _, id in featured do
			table.insert(
				result,
				{ skinId = id, rarity = rarity, chance = rates[rarity] * featuredPart / #featured }
			)
		end
		for _, id in regular do
			table.insert(result, {
				skinId = id,
				rarity = rarity,
				chance = rates[rarity] * (1 - featuredPart) / #regular,
			})
		end
	end
	return result
end

local function topRarity(config: any): string
	return config.rarityOrder[#config.rarityOrder]
end

function Gacha.newState(): State
	return { pity = {}, owned = {}, shards = 0 }
end

-- One pull. Mutates `state` (pity, owned, shards) and returns what dropped.
function Gacha.pull(config: any, banner: any, state: State, rng: Rng): PullResult
	local grouped = Gacha.pool(config, banner)
	local rates = rarityRates(config, grouped)
	local top = topRarity(config)
	local counter = (state.pity[banner.pityGroup] or 0) + 1

	local rarity: string
	local pity = false
	if counter >= config.hardPity and #grouped[top] > 0 then
		rarity = top
		pity = true
	else
		local roll = rng:NextNumber()
		rarity = config.rarityOrder[1]
		local cumulative = 0
		for _, candidate in config.rarityOrder do
			if rates[candidate] > 0 then
				cumulative += rates[candidate]
				rarity = candidate
				if roll < cumulative then
					break
				end
			end
		end
	end

	local ids = grouped[rarity]
	local featured: { string }, regular: { string } = {}, {}
	for _, id in ids do
		table.insert(if find(banner.featured, id) then featured else regular, id)
	end
	local candidates = regular
	if #featured > 0 and (#regular == 0 or rng:NextNumber() < config.featuredShare) then
		candidates = featured
	end
	local skinId =
		candidates[math.clamp(math.floor(rng:NextNumber() * #candidates) + 1, 1, #candidates)]

	state.pity[banner.pityGroup] = if rarity == top then 0 else counter
	local duplicate = state.owned[skinId] == true
	local shards = 0
	if duplicate then
		shards = config.duplicateShards[rarity] or 0
		state.shards += shards
	else
		state.owned[skinId] = true
	end
	return { skinId = skinId, rarity = rarity, duplicate = duplicate, shards = shards, pity = pity }
end

-- Spend shards on a specific skin. Returns false with a reason if not allowed.
function Gacha.craft(config: any, state: State, skinId: string): (boolean, string?)
	local skin = config.skinsById[skinId]
	if not skin then
		return false, "Unknown skin"
	end
	if state.owned[skinId] then
		return false, "Already owned"
	end
	local cost = config.craftCost[skin.rarity]
	if state.shards < cost then
		return false, "Not enough shards"
	end
	state.shards -= cost
	state.owned[skinId] = true
	return true, nil
end

return Gacha
