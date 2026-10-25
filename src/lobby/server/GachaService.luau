--!strict
-- Skin gacha: banner state, pulls, crafting and equipping. All validation happens here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GachaConfig = require(Shared.Config.Gacha)
local Economy = require(Shared.Config.Economy)
local Gacha = require(Shared.Logic.Gacha)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Purchases = require(ServerScriptService.ServerShared.Purchases)

local GachaService = {}

local PULL_DEBOUNCE = 0.75
local lastPull: { [Player]: number } = {}
local rng = Random.new()

local function snapshot(player: Player): any
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local banners = {}
	for _, entry in Gacha.activeBanners(GachaConfig, os.time()) do
		table.insert(banners, {
			id = entry.banner.id,
			displayName = entry.banner.displayName,
			endsAt = entry.endsAt,
			featured = entry.banner.featured or {},
			pity = profile.pity[entry.banner.pityGroup] or 0,
			odds = Gacha.odds(GachaConfig, entry.banner),
		})
	end
	return {
		currencyName = Economy.currencyName,
		coins = profile.coins,
		shards = profile.shards,
		owned = profile.ownedSkins,
		equipped = profile.equippedSkins,
		pullCost = GachaConfig.pullCost,
		multiPullCount = GachaConfig.multiPullCount,
		hardPity = GachaConfig.hardPity,
		craftCost = GachaConfig.craftCost,
		banners = banners,
		stats = profile.stats,
		canBuyCoins = Purchases.canBuy(player),
		serverTime = os.time(),
	}
end

local function pull(player: Player, bannerId: unknown, count: unknown): any
	if type(bannerId) ~= "string" or (count ~= 1 and count ~= GachaConfig.multiPullCount) then
		return { ok = false, message = "Invalid request" }
	end
	local now = os.clock()
	if lastPull[player] and now - lastPull[player] < PULL_DEBOUNCE then
		return { ok = false, message = "Slow down" }
	end
	lastPull[player] = now
	local banner = Gacha.findActive(GachaConfig, os.time(), bannerId)
	if not banner then
		return { ok = false, message = "That banner is not active" }
	end
	local profile = PlayerData.get(player)
	local pulls = count :: number
	local cost = GachaConfig.pullCost * pulls
	if not profile or profile.coins < cost then
		return { ok = false, message = "Not enough " .. Economy.currencyName }
	end
	local results = {}
	PlayerData.update(player, function(p)
		p.coins -= cost
		local state: Gacha.State = { pity = p.pity, owned = p.ownedSkins, shards = p.shards }
		for _ = 1, pulls do
			table.insert(results, Gacha.pull(GachaConfig, banner, state, rng))
		end
		p.shards = state.shards
		p.stats.pulls += pulls
	end)
	-- Pulls spend currency; persist right away.
	task.spawn(PlayerData.save, player)
	return { ok = true, results = results, state = snapshot(player) }
end

local function craft(player: Player, skinId: unknown): any
	if type(skinId) ~= "string" then
		return { ok = false, message = "Invalid request" }
	end
	local ok, reason = false, nil
	PlayerData.update(player, function(p)
		local state: Gacha.State = { pity = p.pity, owned = p.ownedSkins, shards = p.shards }
		ok, reason = Gacha.craft(GachaConfig, state, skinId)
		p.shards = state.shards
	end)
	if ok then
		task.spawn(PlayerData.save, player)
	end
	return { ok = ok, message = reason, state = snapshot(player) }
end

local function equip(player: Player, standId: unknown, skinId: unknown): any
	if type(standId) ~= "string" or (skinId ~= nil and type(skinId) ~= "string") then
		return { ok = false, message = "Invalid request" }
	end
	local profile = PlayerData.get(player)
	if not profile then
		return { ok = false, message = "Profile not loaded" }
	end
	if skinId ~= nil then
		local skin = GachaConfig.skinsById[skinId :: string]
		if not skin or skin.standId ~= standId or not profile.ownedSkins[skinId :: string] then
			return { ok = false, message = "You don't own that skin" }
		end
	end
	PlayerData.update(player, function(p)
		(p.equippedSkins :: any)[standId] = skinId
	end)
	-- Match servers read equipped skins on arrival; save before the player queues.
	task.spawn(PlayerData.save, player)
	return { ok = true, state = snapshot(player) }
end

function GachaService.start()
	Net.func("GachaState").OnServerInvoke = snapshot
	Net.func("GachaPull").OnServerInvoke = pull
	Net.func("GachaCraft").OnServerInvoke = craft
	Net.func("EquipSkin").OnServerInvoke = equip
	Net.func("BuyCoins").OnServerInvoke = function(player, index)
		if type(index) ~= "number" then
			return { ok = false, message = "Invalid request" }
		end
		local ok, message = Purchases.prompt(player, index)
		return { ok = ok, message = message }
	end
	local profileChanged = Net.event("ProfileChanged")
	PlayerData.Changed:Connect(function(player: Player)
		profileChanged:FireClient(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPull[player] = nil
	end)
end

return GachaService
