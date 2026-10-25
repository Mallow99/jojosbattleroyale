--!strict
-- World pickups. Each kind registers a handler; the handler decides whether the player
-- can take it and may return items to drop in its place (a replaced disc or weapon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Stands = require(Shared.Config.Stands)
local Weighted = require(Shared.Logic.Weighted)
local MatchState = require(script.Parent.MatchState)

local LootService = {}

export type Drop = { kind: string, data: any }
export type Handler = (player: Player, data: any) -> (boolean, { Drop }?)

local assets = ServerStorage:WaitForChild("Assets")
local handlers: { [string]: Handler } = {}
local container = Instance.new("Folder")
container.Name = "Loot"
container.Parent = workspace

local COLORS = {
	Disc = Color3.fromRGB(200, 120, 255),
	Weapon = Color3.fromRGB(255, 170, 80),
	Heal = Color3.fromRGB(110, 230, 140),
	StandArrow = Color3.fromRGB(255, 220, 120),
	Relic = Color3.fromRGB(255, 200, 40),
}

function LootService.register(kind: string, handler: Handler)
	handlers[kind] = handler
end

local function labelFor(kind: string, data: any): string
	if kind == "Disc" then
		local stand = Stands.byId[data.disc.standId]
		return (if stand then stand.displayName else data.disc.standId) .. " Disc"
	elseif kind == "Weapon" then
		return Items.weapons[data.weaponId].displayName
	elseif kind == "Heal" then
		return Items.heals[data.healId].displayName
	elseif kind == "StandArrow" then
		return "Stand Arrow"
	elseif kind == "Relic" then
		return "Requiem Arrow"
	end
	return kind
end

local function visualFor(kind: string, data: any): Model
	local source: Instance?
	if kind == "Disc" then
		source = assets.Items:FindFirstChild("Disc")
	elseif kind == "StandArrow" then
		source = assets.Items:FindFirstChild("StandArrow")
	elseif kind == "Relic" then
		source = assets.Items:FindFirstChild("RequiemArrow")
	elseif kind == "Weapon" then
		source = assets.Weapons:FindFirstChild(data.weaponId)
	elseif kind == "Heal" then
		source = assets.Heals:FindFirstChild(data.healId)
	end
	local model = Instance.new("Model")
	if source then
		for _, child in source:GetChildren() do
			child:Clone().Parent = model
		end
	end
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		local placeholder = Instance.new("Part")
		placeholder.Size = Vector3.new(1.5, 1.5, 1.5)
		placeholder.Color = COLORS[kind] or Color3.new(1, 1, 1)
		placeholder.Material = Enum.Material.Neon
		placeholder.Parent = model
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	return model
end

-- Places a pickup on the ground at `position`.
function LootService.spawn(kind: string, data: any, position: Vector3): Model
	local model = visualFor(kind, data)
	model.Name = kind
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(position + Vector3.new(0, size.Y / 2 + 0.5, 0)))
	local anchorPart = model:FindFirstChildWhichIsA("BasePart", true) :: BasePart

	local light = Instance.new("PointLight")
	light.Color = COLORS[kind] or Color3.new(1, 1, 1)
	light.Range = 10
	light.Brightness = 2
	light.Parent = anchorPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = labelFor(kind, data)
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchorPart

	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken or not MatchState.isAlive(player) then
			return
		end
		local root = MatchState.rootOf(player)
		if not root or (root.Position - anchorPart.Position).Magnitude > Items.pickupRange then
			return
		end
		local handler = handlers[kind]
		if not handler then
			return
		end
		-- Claim before any yield so two simultaneous triggers cannot both take it.
		taken = true
		local accepted, drops = handler(player, data)
		if not accepted then
			taken = false
			return
		end
		model:Destroy()
		for i, drop in (drops or {}) :: { Drop } do
			LootService.spawn(drop.kind, drop.data, position + Vector3.new(i * 2, 0, 0))
		end
	end)

	model.Parent = container
	return model
end

-- Drops several items in a small ring, e.g. everything an eliminated player carried.
function LootService.scatter(drops: { Drop }, position: Vector3)
	for i, drop in drops do
		local angle = (i / math.max(#drops, 1)) * math.pi * 2
		LootService.spawn(
			drop.kind,
			drop.data,
			position + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
		)
	end
end

local function randomStand(rng: Random): string
	return Weighted.pick(Stands.list, function(stand)
		return stand.weight
	end, rng:NextNumber()).id
end
LootService.randomStand = randomStand

local uid = 0
function LootService.newDiscData(standId: string): any
	uid += 1
	return { disc = { uid = "d" .. uid, standId = standId, cooldowns = {} } }
end

function LootService.spawnAll(points: { Vector3 }, rng: Random)
	local weaponIds, healIds = {}, {}
	for id in Items.weapons do
		table.insert(weaponIds, id)
	end
	for id in Items.heals do
		table.insert(healIds, id)
	end
	table.sort(weaponIds)
	table.sort(healIds)
	for _, point in points do
		local kind = Weighted.pick(Items.lootWeights, function(entry)
			return entry.weight
		end, rng:NextNumber()).kind
		local data: any = {}
		if kind == "Disc" then
			data = LootService.newDiscData(randomStand(rng))
		elseif kind == "Weapon" then
			data = { weaponId = weaponIds[rng:NextInteger(1, #weaponIds)] }
		elseif kind == "Heal" then
			data = { healId = healIds[rng:NextInteger(1, #healIds)] }
		end
		LootService.spawn(kind, data, point)
	end
end

function LootService.clear()
	container:ClearAllChildren()
end

return LootService
