--!strict
-- Basic melee so eliminations work: fists, picked-up weapons, and the active Stand's
-- damage multiplier. Hit detection is server-side; the client only plays animations.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Items = require(Shared.Config.Items)
local MatchConfig = require(Shared.Config.Match)
local MatchState = require(script.Parent.MatchState)
local Damage = require(script.Parent.Damage)
local StandService = require(script.Parent.StandService)
local LootService = require(script.Parent.LootService)
local Channels = require(script.Parent.Channels)
local Announce = require(script.Parent.Announce)

local CombatService = {}

local MAX_HEALS = 3
local HITBOX_WIDTH = 5
local HITBOX_HEIGHT = 6

local assets = ServerStorage:WaitForChild("Assets")
local sounds = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("CombatSounds")
local lastAttack: { [Player]: number } = {}

local function equippedTool(player: Player): Tool?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Tool") else nil
end

local function weaponOf(player: Player): Items.Weapon
	local tool = equippedTool(player)
	local id = tool and tool:GetAttribute("WeaponId")
	return if type(id) == "string" and Items.weapons[id] then Items.weapons[id] else Items.fists
end

local function playHit(part: BasePart)
	local list = sounds:GetChildren()
	if #list == 0 then
		return
	end
	local sound = (list[math.random(1, #list)] :: Sound):Clone()
	sound.Parent = part
	sound:Play()
	task.delay(3, sound.Destroy, sound)
end

local function attack(player: Player)
	if not MatchState.isAlive(player) or MatchState.phase == "Waiting" then
		return
	end
	local tool = equippedTool(player)
	if tool and tool:GetAttribute("HealId") then
		return
	end
	local root, humanoid = MatchState.rootOf(player), MatchState.humanoidOf(player)
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	local weapon = weaponOf(player)
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < weapon.cooldown then
		return
	end
	lastAttack[player] = now

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances =
		{ player.Character :: Model, workspace:FindFirstChild("Loot") :: Instance }
	local center = root.CFrame * CFrame.new(0, 0, -weapon.range / 2)
	local hit: { [Humanoid]: BasePart } = {}
	for _, part in
		workspace:GetPartBoundsInBox(
			center,
			Vector3.new(HITBOX_WIDTH, HITBOX_HEIGHT, weapon.range),
			params
		)
	do
		local victim = Damage.humanoidOf(part)
		if victim and victim ~= humanoid and victim.Health > 0 and not hit[victim] then
			hit[victim] = part
		end
	end
	local damage = weapon.damage * StandService.damageMultiplier(player)
	for victim, part in hit do
		Damage.apply(victim, damage, player)
		playHit(part)
	end
end

local function heal(player: Player, tool: Tool)
	local healId = tool:GetAttribute("HealId")
	local def = if type(healId) == "string" then Items.heals[healId] else nil
	if not def or not MatchState.isAlive(player) or tool.Parent ~= player.Character then
		return
	end
	Channels.start(player, "Heal", def.useTime, MatchConfig.channelMoveTolerance, {
		onComplete = function()
			local humanoid = MatchState.humanoidOf(player)
			if humanoid and humanoid.Health > 0 and tool.Parent ~= nil then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.amount)
				tool:Destroy()
			end
		end,
		onCancel = function(reason)
			Announce.to(player, "Healing cancelled: " .. reason, "bad")
		end,
	})
end

local function toolsOf(player: Player): { Tool }
	local list: { Tool } = {}
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				table.insert(list, child)
			end
		end
	end
	return list
end

local function giveTool(player: Player, folder: Instance, id: string, attribute: string): Tool?
	local source = folder:FindFirstChild(id)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not source or not backpack then
		return nil
	end
	local tool = source:Clone() :: Tool
	tool:SetAttribute(attribute, id)
	tool.CanBeDropped = false
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	tool.Parent = backpack
	return tool
end

-- Everything droppable a player carries, for elimination.
function CombatService.takeTools(player: Player): { LootService.Drop }
	local drops: { LootService.Drop } = {}
	for _, tool in toolsOf(player) do
		local weaponId, healId = tool:GetAttribute("WeaponId"), tool:GetAttribute("HealId")
		if type(weaponId) == "string" then
			table.insert(drops, { kind = "Weapon", data = { weaponId = weaponId } })
		elseif type(healId) == "string" then
			table.insert(drops, { kind = "Heal", data = { healId = healId } })
		end
		tool:Destroy()
	end
	return drops
end

function CombatService.start()
	Net.event("Attack").OnServerEvent:Connect(attack)
	LootService.register("Weapon", function(player, data)
		if not assets.Weapons:FindFirstChild(data.weaponId) then
			return false, nil
		end
		local drops: { LootService.Drop } = {}
		for _, tool in toolsOf(player) do
			local current = tool:GetAttribute("WeaponId")
			if type(current) == "string" then
				table.insert(drops, { kind = "Weapon", data = { weaponId = current } })
				tool:Destroy()
			end
		end
		return giveTool(player, assets.Weapons, data.weaponId, "WeaponId") ~= nil, drops
	end)
	LootService.register("Heal", function(player, data)
		local count = 0
		for _, tool in toolsOf(player) do
			if tool:GetAttribute("HealId") then
				count += 1
			end
		end
		if count >= MAX_HEALS then
			Announce.to(player, "You can carry " .. MAX_HEALS .. " heals", "bad")
			return false, nil
		end
		local tool = giveTool(player, assets.Heals, data.healId, "HealId")
		if tool then
			tool.Activated:Connect(function()
				heal(player, tool)
			end)
		end
		return tool ~= nil, nil
	end)
end

function CombatService.forget(player: Player)
	lastAttack[player] = nil
end

return CombatService
