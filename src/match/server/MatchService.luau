--!strict
-- Runs one match: wait for players, deploy, loot, zone, Requiem Arrow, results, return.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MatchConfig = require(Shared.Config.Match)
local Items = require(Shared.Config.Items)
local Places = require(Shared.Config.Places)
local Economy = require(Shared.Config.Economy)
local MatchClock = require(Shared.Logic.MatchClock)
local Rewards = require(Shared.Logic.Rewards)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)

local MatchState = require(script.Parent.MatchState)
local MapService = require(script.Parent.MapService)
local ZoneService = require(script.Parent.ZoneService)
local LootService = require(script.Parent.LootService)
local StandService = require(script.Parent.StandService)
local CombatService = require(script.Parent.CombatService)
local DeployService = require(script.Parent.DeployService)
local RelicService = require(script.Parent.RelicService)
local Channels = require(script.Parent.Channels)
local Damage = require(script.Parent.Damage)
local Announce = require(script.Parent.Announce)

local MatchService = {}

local rng = Random.new()
local stateEvent = Net.event("MatchState")
local eliminatedEvent = Net.event("Eliminated")
local resultsEvent = Net.event("Results")
local studio = RunService:IsStudio()
local lastPosition: { [Player]: Vector3 } = {}
local grantsInFlight = 0

local function sendToLobby(players: { Player })
	if not Places.lobbyPlaceId or studio then
		for _, player in players do
			Announce.to(player, "Lobby place not configured; stay here or leave the game.", "bad")
		end
		return
	end
	pcall(function()
		TeleportService:TeleportAsync(Places.lobbyPlaceId :: number, players)
	end)
end

local function readJoinData(player: Player)
	if MatchState.matchId ~= "" then
		return
	end
	local data: any = player:GetJoinData().TeleportData
	if type(data) == "table" and type(data.matchId) == "string" then
		MatchState.matchId = data.matchId
		MatchState.expected = tonumber(data.expected)
		MatchState.areaScale = tonumber(data.areaScale) or 1
	elseif studio or not Places.lobbyPlaceId then
		MatchState.matchId = "dev-" .. HttpService:GenerateGUID(false)
	end
end

-- Elimination or disconnect: drop everything the player carried, record placement.
local function eliminate(player: Player, leftEarly: boolean)
	local participant = MatchState.participants[player.UserId]
	if not participant or not participant.alive then
		return
	end
	participant.alive = false
	participant.leftEarly = leftEarly
	participant.placement = MatchState.aliveCount() + 1
	Channels.interrupt(player, "died")

	local humanoid = MatchState.humanoidOf(player)
	local root = MatchState.rootOf(player)
	local position = if root then root.Position else lastPosition[player] or RelicService.landmark()
	position = MapService.ground(position.X, position.Z) or position

	local killer = if humanoid then Damage.killerOf(humanoid) else nil
	if killer and MatchState.participants[killer.UserId] then
		MatchState.participants[killer.UserId].eliminations += 1
	end

	RelicService.dropFrom(player, position)
	local drops: { LootService.Drop } = {}
	for _, disc in StandService.takeAll(player) do
		table.insert(drops, { kind = "Disc", data = { disc = disc } })
	end
	for _, drop in CombatService.takeTools(player) do
		table.insert(drops, drop)
	end
	LootService.scatter(drops, position)

	local how = if leftEarly
		then " left the match"
		elseif killer then " was eliminated by " .. killer.Name
		else " was eliminated"
	Announce.all(string.format("%s%s (%d left)", player.Name, how, MatchState.aliveCount()), "bad")
	if player.Parent then
		eliminatedEvent:FireClient(
			player,
			{ placement = participant.placement, killer = if killer then killer.Name else nil }
		)
	end
end

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		if MatchState.started and not MatchState.ended then
			eliminate(player, false)
		end
	end)
end

local function onPlayerAdded(player: Player)
	readJoinData(player)
	if MatchState.matchId == "" then
		-- Joined the match place directly in production: back to the lobby.
		sendToLobby({ player })
		return
	end
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	task.spawn(StandService.loadSkins, player)
	if not MatchState.started then
		player:LoadCharacterAsync()
	else
		Announce.to(player, "Match already in progress; spectating.", "info")
	end
end

local function broadcast()
	local elapsed = MatchState.elapsed()
	local nextName, nextIn = MatchClock.nextEvent(elapsed, MatchConfig)
	local zone = ZoneService.state()
	local landmark = RelicService.landmark()
	stateEvent:FireAllClients({
		phase = MatchState.phase,
		elapsed = elapsed,
		nextEvent = nextName,
		nextEventIn = if nextIn then nextIn / MatchState.timeScale else nil,
		alive = MatchState.aliveCount(),
		zone = if zone
			then {
				x = zone.x,
				z = zone.z,
				radius = zone.radius,
				shrinking = zone.shrinking,
				damage = zone.damage,
			}
			else nil,
		carrier = if MatchState.carrier then MatchState.carrier.Name else nil,
		landmark = { landmark.X, landmark.Y, landmark.Z },
	})
end

local function finish(outcome: MatchClock.Outcome)
	if MatchState.ended then
		return
	end
	MatchState.ended = true
	MatchState.phase = "Ended"
	MatchState.winner = outcome.winner
	local winner = if outcome.winner then Players:GetPlayerByUserId(outcome.winner) else nil
	if winner then
		local participant = MatchState.participants[winner.UserId]
		participant.placement = 1
		Announce.all(winner.Name .. " activated the Requiem Arrow and wins!", "relic")
	elseif outcome.reason == "timeout" then
		Announce.all("Time is up. Nobody activated the Requiem Arrow; no winner.", "bad")
	else
		Announce.all("No survivors. No winner.", "bad")
	end
	broadcast()

	for userId, participant in MatchState.participants do
		local result = {
			qualified = not participant.leftEarly,
			won = userId == outcome.winner,
			eliminations = participant.eliminations,
		}
		local coins = Rewards.coins(result, Economy)
		if result.qualified then
			grantsInFlight += 1
			task.spawn(function()
				PlayerData.grant(userId, "match:" .. MatchState.matchId, {
					coins = coins,
					matches = 1,
					wins = if result.won then 1 else 0,
					eliminations = participant.eliminations,
				})
				grantsInFlight -= 1
			end)
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			resultsEvent:FireClient(player, {
				won = result.won,
				placement = participant.placement,
				coins = coins,
				currencyName = Economy.currencyName,
				winner = if winner then winner.Name else nil,
				reason = outcome.reason,
			})
		end
	end

	task.wait(MatchConfig.endScreenDuration)
	sendToLobby(Players:GetPlayers())
end

local function waitForPlayers()
	MatchState.phase = "Waiting"
	local started = os.clock()
	while true do
		local count = #Players:GetPlayers()
		local waited = os.clock() - started
		if studio then
			if count > 0 and waited >= MatchConfig.studioStartDelay then
				return
			end
		elseif MatchState.expected then
			if
				count >= MatchState.expected or (count > 0 and waited >= MatchConfig.arrivalTimeout)
			then
				return
			end
		elseif count > 0 and waited >= MatchConfig.arrivalTimeout then
			return
		end
		stateEvent:FireAllClients({
			phase = "Waiting",
			waiting = count,
			expected = MatchState.expected,
		})
		task.wait(1)
	end
end

local function begin()
	if studio then
		local scale = workspace:GetAttribute("DevTimeScale")
		MatchState.timeScale = if type(scale) == "number" and scale > 0 then scale else 1
	end
	local center = MapService.center()
	local radius = MatchConfig.zone.startRadius * MatchState.areaScale
	local landmark, landmarkPosition = MapService.buildLandmark()
	ZoneService.init(center, radius, landmarkPosition)
	RelicService.start(landmark, landmarkPosition, function(player)
		finish(
			MatchClock.outcome(
				MatchState.elapsed(),
				MatchState.aliveCount(),
				player.UserId,
				MatchConfig
			)
		)
	end)
	LootService.spawnAll(MapService.lootPoints(center, radius, Items.lootPointTarget, rng), rng)

	local players = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(players, player)
			MatchState.participants[player.UserId] = {
				userId = player.UserId,
				name = player.Name,
				alive = true,
				leftEarly = false,
				placement = nil,
				eliminations = 0,
			}
			local humanoid = MatchState.humanoidOf(player)
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end
	MatchState.started = true
	MatchState.startedAt = os.clock()
	MatchState.phase = "Deploying"
	Announce.all(
		string.format("Match started with %d players. Find a Stand disc!", #players),
		"info"
	)
	ZoneService.update(0)
	broadcast()
	task.spawn(DeployService.run, players, center, radius, rng)
end

local function loop()
	local lastBroadcast = 0
	while not MatchState.ended do
		Channels.step()
		local elapsed = MatchState.elapsed()
		local phase = MatchClock.phase(elapsed, MatchConfig)
		if phase ~= "Ended" then
			MatchState.phase = phase
		end
		if not MatchState.relicRevealed and elapsed >= MatchConfig.relicRevealAt then
			RelicService.reveal()
		end
		if not MatchState.activationOpen and elapsed >= MatchConfig.activationUnlockAt then
			RelicService.unlock()
		end
		ZoneService.update(elapsed)
		for _, player in MatchState.alivePlayers() do
			local root = MatchState.rootOf(player)
			if root then
				lastPosition[player] = root.Position
			end
		end
		local outcome = MatchClock.outcome(elapsed, MatchState.aliveCount(), nil, MatchConfig)
		if outcome.ended then
			task.spawn(finish, outcome)
			break
		end
		if os.clock() - lastBroadcast >= MatchConfig.stateBroadcastInterval then
			lastBroadcast = os.clock()
			broadcast()
		end
		task.wait(0.1)
	end
end

function MatchService.start()
	StandService.start()
	CombatService.start()
	DeployService.start()
	Net.event("ReturnToLobby").OnServerEvent:Connect(function(player)
		if MatchState.ended or not MatchState.isAlive(player) then
			sendToLobby({ player })
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if MatchState.started and not MatchState.ended then
			eliminate(player, true)
		end
		Channels.clear(player)
		DeployService.forget(player)
		CombatService.forget(player)
		StandService.forget(player)
		lastPosition[player] = nil
	end)

	game:BindToClose(function()
		-- Let reward writes finish before the server shuts down.
		local deadline = os.clock() + 25
		while grantsInFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	waitForPlayers()
	begin()
	loop()
end

return MatchService
