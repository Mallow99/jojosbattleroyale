--!strict
-- Stand discs: the active/spare slots, swapping, dropping, the summoned Stand model and
-- the Stand's stat changes. Equipped skins come from the player's saved profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Stands = require(Shared.Config.Stands)
local MatchConfig = require(Shared.Config.Match)
local DiscSlots = require(Shared.Logic.DiscSlots)
local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local MatchState = require(script.Parent.MatchState)
local Channels = require(script.Parent.Channels)
local LootService = require(script.Parent.LootService)
local Announce = require(script.Parent.Announce)

local StandService = {}

local BASE_WALK_SPEED = 16
local BASE_MAX_HEALTH = 100
local STAND_OFFSET = CFrame.new(2.5, 1.2, 3)

local assets = ServerStorage:WaitForChild("Assets")
local slots: { [Player]: DiscSlots.Slots } = {}
local summoned: { [Player]: Model } = {}
local equippedSkins: { [number]: { [string]: string } } = {}
local discEvent = Net.event("Discs")

local standFolder = Instance.new("Folder")
standFolder.Name = "Stands"
standFolder.Parent = workspace

local function slotsOf(player: Player): DiscSlots.Slots
	local s = slots[player]
	if not s then
		s = DiscSlots.new()
		slots[player] = s
	end
	return s
end

local function publish(player: Player)
	local s = slotsOf(player)
	discEvent:FireClient(player, {
		active = if s.active then s.active.standId else nil,
		spare = if s.spare then s.spare.standId else nil,
	})
end

function StandService.activeStand(player: Player): Stands.Stand?
	local s = slots[player]
	return if s and s.active then Stands.byId[s.active.standId] else nil
end

function StandService.damageMultiplier(player: Player): number
	local stand = StandService.activeStand(player)
	return if stand then stand.damageMultiplier else 1
end

function StandService.walkSpeed(player: Player): number
	local stand = StandService.activeStand(player)
	return BASE_WALK_SPEED * (if stand then stand.speedMultiplier else 1)
end

local function applyStats(player: Player)
	local humanoid = MatchState.humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stand = StandService.activeStand(player)
	local maxHealth = BASE_MAX_HEALTH + (if stand then stand.maxHealthBonus else 0)
	local ratio = humanoid.Health / humanoid.MaxHealth
	humanoid.MaxHealth = maxHealth
	humanoid.Health = math.min(maxHealth, maxHealth * ratio)
	if humanoid:GetAttribute("Gliding") ~= true then
		humanoid.WalkSpeed = StandService.walkSpeed(player)
	end
end

local function unsummon(player: Player)
	local model = summoned[player]
	if model then
		model:Destroy()
		summoned[player] = nil
	end
end

local function standModel(player: Player, standId: string): (Model?, Instance?)
	local package = assets.Stands:FindFirstChild(standId)
	if not package then
		return nil, nil
	end
	local skinId = (equippedSkins[player.UserId] or {})[standId]
	local skin = skinId and assets.Skins:FindFirstChild(skinId)
	local source = if skin then skin else package:FindFirstChild("Morph")
	return if source then source:Clone() :: Model else nil, package
end

local function summon(player: Player)
	unsummon(player)
	local s = slotsOf(player)
	local root = MatchState.rootOf(player)
	if not s.active or not root then
		return
	end
	local model, package = standModel(player, s.active.standId)
	if not model or not package then
		return
	end
	model.Name = "Stand_" .. player.Name
	local standRoot = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not standRoot then
		model:Destroy()
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
			descendant:Destroy()
		end
	end
	model.PrimaryPart = standRoot
	local standHumanoid = model:FindFirstChildOfClass("Humanoid")
	if standHumanoid then
		standHumanoid.EvaluateStateMachine = false
		standHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local target = root:FindFirstChild("StandOffset") :: Attachment?
	if not target then
		local created = Instance.new("Attachment")
		created.Name = "StandOffset"
		created.CFrame = STAND_OFFSET
		created.Parent = root
		target = created
	end
	local own = Instance.new("Attachment")
	own.Name = "StandFollow"
	own.Parent = standRoot
	local align = Instance.new("AlignPosition")
	align.Attachment0 = own
	align.Attachment1 = target
	align.Responsiveness = 40
	align.MaxForce = math.huge
	align.Parent = standRoot
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = own
	orient.Attachment1 = target
	orient.Responsiveness = 40
	orient.MaxTorque = math.huge
	orient.Parent = standRoot

	local aura = package:FindFirstChild("Aura")
	local torso = model:FindFirstChild("UpperTorso") or standRoot
	local emitters: { Instance } = if aura then aura:GetChildren() else {}
	for _, emitter in emitters do
		emitter:Clone().Parent = torso
	end

	model:PivotTo(root.CFrame * STAND_OFFSET)
	model.Parent = standFolder
	pcall(function()
		standRoot:SetNetworkOwner(player)
	end)
	summoned[player] = model

	local idle = package:FindFirstChild("Idle")
	local animator = standHumanoid and standHumanoid:FindFirstChildOfClass("Animator")
	if idle and idle:IsA("Animation") and animator then
		animator:LoadAnimation(idle):Play()
	end
	local sound = package:FindFirstChild("Summon")
	if sound and sound:IsA("Sound") then
		local clone = sound:Clone()
		clone.Parent = root
		clone:Play()
		task.delay(5, clone.Destroy, clone)
	end
end

-- Re-summons after any change to the active disc and cancels channels that require
-- the Stand to stay the same (activation).
local function activeChanged(player: Player)
	if Channels.kind(player) == "Activation" then
		Channels.interrupt(player, "stand changed")
	end
	summon(player)
	applyStats(player)
	publish(player)
end

-- Adds a found disc; returns a replaced spare to drop.
function StandService.addDisc(player: Player, disc: DiscSlots.Disc): DiscSlots.Disc?
	local s = slotsOf(player)
	local slot, replaced = DiscSlots.add(s, disc)
	local stand = Stands.byId[disc.standId]
	Announce.to(
		player,
		string.format(
			"%s disc %s",
			if stand then stand.displayName else disc.standId,
			if slot == "active" then "equipped" else "stored as spare"
		)
	)
	if slot == "active" then
		activeChanged(player)
	else
		publish(player)
	end
	return replaced
end

local function swap(player: Player)
	if not MatchState.isAlive(player) or not DiscSlots.canSwap(slotsOf(player)) then
		return
	end
	Channels.start(player, "Swap", MatchConfig.discSwapDuration, MatchConfig.channelMoveTolerance, {
		onComplete = function()
			if MatchState.isAlive(player) and DiscSlots.swap(slotsOf(player)) then
				activeChanged(player)
			end
		end,
		onCancel = function(reason)
			Announce.to(player, "Swap cancelled: " .. reason, "bad")
		end,
	})
end

local function dropSpare(player: Player)
	local root = MatchState.rootOf(player)
	if not MatchState.isAlive(player) or not root then
		return
	end
	local disc = DiscSlots.dropSpare(slotsOf(player))
	if disc then
		LootService.spawn(
			"Disc",
			{ disc = disc },
			root.Position - Vector3.new(0, 2.5, 0) + root.CFrame.LookVector * 3
		)
		publish(player)
	end
end

-- Removes both discs (elimination) and returns them for dropping.
function StandService.takeAll(player: Player): { DiscSlots.Disc }
	unsummon(player)
	local dropped = DiscSlots.dropAll(slotsOf(player))
	publish(player)
	return dropped
end

function StandService.refreshStats(player: Player)
	applyStats(player)
end

function StandService.loadSkins(player: Player)
	local profile = PlayerData.peek(player.UserId)
	if profile then
		equippedSkins[player.UserId] = profile.equippedSkins
	end
end

function StandService.start()
	Net.event("SwapDisc").OnServerEvent:Connect(swap)
	Net.event("DropSpare").OnServerEvent:Connect(dropSpare)
	LootService.register("Disc", function(player, data)
		local replaced = StandService.addDisc(player, data.disc)
		return true, if replaced then { { kind = "Disc", data = { disc = replaced } } } else nil
	end)
	LootService.register("StandArrow", function(player)
		local data = LootService.newDiscData(LootService.randomStand(Random.new()))
		local replaced = StandService.addDisc(player, data.disc)
		return true, if replaced then { { kind = "Disc", data = { disc = replaced } } } else nil
	end)
end

-- Called by MatchService after a leaving player's discs were dropped.
function StandService.forget(player: Player)
	unsummon(player)
	slots[player] = nil
	equippedSkins[player.UserId] = nil
end

return StandService
