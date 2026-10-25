--!strict
-- Cross-server matchmaking. Every lobby server writes its queued players into a shared
-- MemoryStore sorted map. One server at a time holds a short lease and forms matches
-- with Matchmaking.decide, reserving a match server and writing an assignment for each
-- player. Each lobby teleports its own assigned players with the reserved access code.
--
-- Without Places.matchPlaceId, or in Studio (where teleports do not work), the queue
-- runs locally and tells players to open the match place to test a match.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Places = require(Shared.Config.Places)
local MatchConfig = require(Shared.Config.Match)
local Matchmaking = require(Shared.Logic.Matchmaking)

local QueueService = {}

local QUEUE_TTL = 60
local LEASE_TTL = 10
local ASSIGNMENT_TTL = 120
local TICK = 3

local queued: { [Player]: number } = {}
local teleporting: { [Player]: boolean } = {}
local statusEvent = Net.event("QueueStatus")

local function online(): boolean
	return Places.matchPlaceId ~= nil and not RunService:IsStudio()
end

local function send(player: Player, state: string, message: string)
	local count = 0
	for _ in queued do
		count += 1
	end
	statusEvent:FireClient(player, { state = state, message = message, queuedHere = count })
end

local queueMap = MemoryStoreService:GetSortedMap("MatchQueue")
local leaseMap = MemoryStoreService:GetSortedMap("MatchQueueLease")
local assignmentMap = MemoryStoreService:GetSortedMap("MatchAssignments")

local function writeEntry(player: Player, joinedAt: number)
	pcall(function()
		queueMap:SetAsync(
			tostring(player.UserId),
			{ joinedAt = joinedAt, jobId = game.JobId },
			QUEUE_TTL
		)
	end)
end

local function removeEntry(userId: number)
	pcall(function()
		queueMap:RemoveAsync(tostring(userId))
	end)
end

local function leave(player: Player)
	if queued[player] == nil then
		return
	end
	queued[player] = nil
	if online() then
		task.spawn(removeEntry, player.UserId)
	end
end

local function join(player: Player)
	if queued[player] or teleporting[player] then
		return
	end
	local now = os.time()
	queued[player] = now
	if online() then
		task.spawn(writeEntry, player, now)
		send(player, "queued", "Searching for a match...")
	else
		send(
			player,
			"queued",
			"Queued locally. Match place not configured or running in Studio: open the match place to test a match."
		)
	end
end

-- Lease holder only: form matches from the shared queue.
local function tryLease(): boolean
	local ok, held = pcall(function()
		return leaseMap:UpdateAsync("leader", function(current)
			if current == nil or current == game.JobId then
				return game.JobId
			end
			return nil
		end, LEASE_TTL)
	end)
	return ok and held == game.JobId
end

local function formMatches()
	local ok, items = pcall(function()
		return queueMap:GetRangeAsync(Enum.SortDirection.Ascending, 200)
	end)
	if not ok or not items then
		return
	end
	local entries = {}
	for _, item in items do
		table.insert(
			entries,
			{ userId = tonumber(item.key) :: number, joinedAt = item.value.joinedAt }
		)
	end
	while true do
		local decision = Matchmaking.decide(entries, os.time(), MatchConfig)
		if not decision.start then
			return
		end
		local reserved, code = pcall(function()
			return TeleportService:ReserveServer(Places.matchPlaceId :: number)
		end)
		if not reserved then
			warn("[Queue] ReserveServer failed: " .. tostring(code))
			return
		end
		local matchId = HttpService:GenerateGUID(false)
		local assignment = {
			code = code,
			matchId = matchId,
			expected = #decision.userIds,
			areaScale = decision.areaScale,
		}
		for _, userId in decision.userIds do
			pcall(function()
				assignmentMap:SetAsync(tostring(userId), assignment, ASSIGNMENT_TTL)
			end)
			removeEntry(userId)
		end
		local remaining = {}
		for _, entry in entries do
			if not table.find(decision.userIds, entry.userId) then
				table.insert(remaining, entry)
			end
		end
		entries = remaining
	end
end

local function teleport(players: { Player }, assignment: any)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = assignment.code
	options:SetTeleportData({
		matchId = assignment.matchId,
		expected = assignment.expected,
		areaScale = assignment.areaScale,
	})
	for _, player in players do
		teleporting[player] = true
		queued[player] = nil
		send(player, "teleporting", "Match found! Teleporting...")
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Places.matchPlaceId :: number, players, options)
	end)
	if not ok then
		warn("[Queue] Teleport failed: " .. tostring(err))
		for _, player in players do
			teleporting[player] = nil
			if player.Parent then
				join(player)
			end
		end
	end
end

-- Teleport any of our queued players that the lease holder assigned to a match.
local function deliverAssignments()
	local byCode: { [string]: { players: { Player }, assignment: any } } = {}
	for player in queued do
		local ok, assignment = pcall(function()
			return assignmentMap:GetAsync(tostring(player.UserId))
		end)
		if ok and assignment then
			pcall(function()
				assignmentMap:RemoveAsync(tostring(player.UserId))
			end)
			local group = byCode[assignment.code] or { players = {}, assignment = assignment }
			table.insert(group.players, player)
			byCode[assignment.code] = group
		end
	end
	for _, group in byCode do
		task.spawn(teleport, group.players, group.assignment)
	end
end

function QueueService.start()
	Net.event("QueueJoin").OnServerEvent:Connect(join)
	Net.event("QueueLeave").OnServerEvent:Connect(function(player)
		leave(player)
		send(player, "idle", "")
	end)
	Players.PlayerRemoving:Connect(function(player)
		leave(player)
		teleporting[player] = nil
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, result, message: string)
		teleporting[player] = nil
		if player.Parent then
			send(
				player,
				"idle",
				"Teleport failed (" .. tostring(result) .. "): " .. message .. ". Queue again."
			)
		end
	end)

	if not online() then
		return
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, joinedAt in queued do
				task.spawn(writeEntry, player, joinedAt)
			end
			if tryLease() then
				formMatches()
			end
			deliverAssignments()
		end
	end)
end

return QueueService
