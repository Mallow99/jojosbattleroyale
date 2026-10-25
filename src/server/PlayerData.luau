--!strict
-- Persistent player profiles: currency, skins, gacha pity and stats.
--
-- Lobby servers own a player's profile while they are connected. Match servers never
-- overwrite it: they read equipped skins with `peek` and add rewards with `grant`, which
-- writes an idempotent pending entry that the lobby claims on the next load. This keeps
-- rewards safe without session locking; adopt ProfileStore if more servers need to write.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy)

local PlayerData = {}

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local CLAIMED_HISTORY = 50
local RETRIES = 3

export type Grant = { coins: number, matches: number, wins: number, eliminations: number }
export type Profile = {
	version: number,
	coins: number,
	shards: number,
	ownedSkins: { [string]: boolean },
	equippedSkins: { [string]: string },
	pity: { [string]: number },
	stats: { matches: number, wins: number, eliminations: number, pulls: number },
	pending: { [string]: Grant },
	claimed: { string },
	receipts: { string },
}

local function defaults(): Profile
	return {
		version = 1,
		coins = 0,
		shards = 0,
		ownedSkins = {},
		equippedSkins = {},
		pity = {},
		stats = { matches = 0, wins = 0, eliminations = 0, pulls = 0 },
		pending = {},
		claimed = {},
		receipts = {},
	}
end

-- Fill fields missing from older saves.
local function reconcile(data: any): Profile
	local profile = defaults()
	if type(data) ~= "table" then
		return profile
	end
	for key, value in data do
		if (profile :: any)[key] ~= nil and type(value) == type((profile :: any)[key]) then
			(profile :: any)[key] = value
		end
	end
	for key, value in defaults().stats do
		if type(profile.stats[key]) ~= "number" then
			(profile.stats :: any)[key] = value
		end
	end
	return profile
end

local store: DataStore? = nil
local storeWarning = false
local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	if not storeWarning then
		storeWarning = true
		warn(
			"[PlayerData] DataStore unavailable; profiles will not save this session: "
				.. tostring(result)
		)
	end
	return nil
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local lastError: any
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt)
	end
	warn(string.format("[PlayerData] %s failed: %s", label, tostring(lastError)))
	return false, nil
end

local function key(userId: number): string
	return "u_" .. userId
end

local profiles: { [Player]: Profile } = {}
local persistent: { [Player]: boolean } = {}
local changed = Instance.new("BindableEvent")

-- Fires with (player, profile) after every change, for UI refreshes.
PlayerData.Changed = changed.Event

local function claim(profile: Profile)
	for id, grant in profile.pending do
		profile.coins += grant.coins
		profile.stats.matches += grant.matches
		profile.stats.wins += grant.wins
		profile.stats.eliminations += grant.eliminations
		table.insert(profile.claimed, id)
	end
	profile.pending = {}
	while #profile.claimed > CLAIMED_HISTORY do
		table.remove(profile.claimed, 1)
	end
end

-- Lobby: load and own a profile for this server session.
function PlayerData.load(player: Player): Profile
	local dataStore = getStore()
	local profile: Profile
	local ok = false
	if dataStore then
		local stored: any
		ok, stored = retry("load " .. player.UserId, function()
			return dataStore:UpdateAsync(key(player.UserId), function(current)
				local loaded = reconcile(current)
				claim(loaded)
				return loaded
			end)
		end)
		profile = if ok then reconcile(stored) else defaults()
	else
		profile = defaults()
	end
	if player.Parent == nil then
		return profile
	end
	if not ok and RunService:IsStudio() then
		profile.coins = Economy.studioTestCoins
	end
	profiles[player] = profile
	persistent[player] = ok
	if not ok and dataStore then
		warn(
			"[PlayerData] "
				.. player.Name
				.. " is using a temporary profile; progress will not save"
		)
	end
	changed:Fire(player, profile)
	return profile
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

-- Mutate the cached profile. Call `save` for anything that must be durable now.
function PlayerData.update(player: Player, mutate: (Profile) -> ()): Profile?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	mutate(profile)
	changed:Fire(player, profile)
	return profile
end

-- Writes the cached profile. Grants added by match servers since our load are kept as
-- pending so they are claimed next time instead of being overwritten.
function PlayerData.save(player: Player): boolean
	local profile = profiles[player]
	local dataStore = getStore()
	if not profile or not dataStore or not persistent[player] then
		return false
	end
	local ok = retry("save " .. player.UserId, function()
		return dataStore:UpdateAsync(key(player.UserId), function(current)
			local stored = reconcile(current)
			for id, grant in stored.pending do
				if not table.find(profile.claimed, id) then
					profile.pending[id] = grant
				end
			end
			return profile
		end)
	end)
	return ok
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	profiles[player] = nil
	persistent[player] = nil
end

-- Match: read-only snapshot of a stored profile (equipped skins). Never saved back.
function PlayerData.peek(userId: number): Profile?
	local dataStore = getStore()
	if not dataStore then
		return nil
	end
	local ok, stored = retry("peek " .. userId, function()
		return (dataStore :: DataStore):GetAsync(key(userId))
	end)
	return if ok then reconcile(stored) else nil
end

-- Match: add a reward once. Repeating the same grantId is a no-op.
function PlayerData.grant(userId: number, grantId: string, grant: Grant): boolean
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	local ok = retry("grant " .. grantId, function()
		return dataStore:UpdateAsync(key(userId), function(current)
			local stored = reconcile(current)
			if stored.pending[grantId] or table.find(stored.claimed, grantId) then
				return nil -- already granted; cancel the write
			end
			stored.pending[grantId] = grant
			return stored
		end)
	end)
	return ok
end

function PlayerData.newGrantId(prefix: string): string
	return prefix .. ":" .. HttpService:GenerateGUID(false)
end

-- Lobby wiring: load on join, autosave, save on leave and shutdown.
function PlayerData.manage()
	Players.PlayerAdded:Connect(function(player)
		PlayerData.load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerData.load, player)
	end
	Players.PlayerRemoving:Connect(PlayerData.release)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1)
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerData.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
