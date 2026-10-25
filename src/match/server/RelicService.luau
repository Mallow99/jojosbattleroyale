--!strict
-- The Requiem Arrow: reveal (guarded by the boss when enabled), public carrier marker,
-- drops on death or disconnect, and the ten-second activation at the final landmark.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MatchConfig = require(Shared.Config.Match)
local Zone = require(Shared.Logic.Zone)
local MatchState = require(script.Parent.MatchState)
local MapService = require(script.Parent.MapService)
local ZoneService = require(script.Parent.ZoneService)
local LootService = require(script.Parent.LootService)
local BossService = require(script.Parent.BossService)
local Channels = require(script.Parent.Channels)
local Announce = require(script.Parent.Announce)

local RelicService = {}

local landmarkPosition = Vector3.zero
local carried: { model: Model, marker: BillboardGui, highlight: Highlight }? = nil
local onActivated: ((Player) -> ())? = nil
local activationEvent = Net.event("Activation")

local function clearCarrier()
	if carried then
		carried.model:Destroy()
		carried.marker:Destroy()
		carried.highlight:Destroy()
		carried = nil
	end
	MatchState.carrier = nil
end

local function pickUp(player: Player): boolean
	local character = player.Character
	local torso = character
		and (
			character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		) :: BasePart?
	if not character or not torso or MatchState.carrier then
		return false
	end
	MatchState.carrier = player

	local source = ServerStorage.Assets.Items:FindFirstChild("RequiemArrow")
	local model = if source then source:Clone() :: Model else Instance.new("Model")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	if model:FindFirstChildWhichIsA("BasePart", true) then
		model:PivotTo(torso.CFrame * CFrame.new(0, 0, 1.2) * CFrame.Angles(0, 0, math.rad(35)))
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = torso
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	model.Parent = character

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 200, 40)
	highlight.OutlineColor = Color3.fromRGB(255, 240, 160)
	highlight.FillTransparency = 0.7
	highlight.Parent = character

	local marker = Instance.new("BillboardGui")
	marker.Name = "RelicMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(200, 40)
	marker.StudsOffset = Vector3.new(0, 5, 0)
	marker.MaxDistance = math.huge
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 210, 60)
	text.TextStrokeTransparency = 0.3
	text.Text = "REQUIEM ARROW"
	text.Parent = marker
	marker.Adornee = torso
	marker.Parent = character

	carried = { model = model, marker = marker, highlight = highlight }
	Announce.all(player.Name .. " has the Requiem Arrow!", "relic")
	return true
end

-- A reachable spot for a dropped arrow: the ground below, inside the zone, or the landmark.
local function dropPosition(position: Vector3): Vector3
	local ground = MapService.ground(position.X, position.Z)
	if ground and ZoneService.inside(ground) then
		return ground
	end
	return landmarkPosition
end

-- Carrier eliminated or disconnected.
function RelicService.dropFrom(player: Player, position: Vector3)
	if MatchState.carrier ~= player then
		return
	end
	clearCarrier()
	LootService.spawn("Relic", {}, dropPosition(position))
	Announce.all(player.Name .. " dropped the Requiem Arrow!", "relic")
end

function RelicService.reveal()
	MatchState.relicRevealed = true
	local circle = ZoneService.target(MatchConfig.relicRevealAt)
	local candidates = {}
	for _, loot in workspace.Loot:GetChildren() do
		local pivot = (loot :: Model):GetPivot().Position
		if
			Zone.contains(
				{ x = circle.x, z = circle.z, radius = circle.radius * 0.7 },
				pivot.X,
				pivot.Z
			)
		then
			table.insert(candidates, pivot)
		end
	end
	local position = if #candidates > 0
		then candidates[math.random(1, #candidates)]
		else (MapService.ground(circle.x, circle.z) or landmarkPosition)
	position = MapService.ground(position.X, position.Z) or position
	local district = MapService.districtAt(position)
	local where = if district then " near " .. district else ""
	if MatchConfig.boss.enabled then
		Announce.all(
			"The Requiem Arrow has appeared"
				.. where
				.. ", guarded by "
				.. MatchConfig.boss.displayName
				.. "!",
			"relic"
		)
		BossService.spawn(position, function(dropAt)
			LootService.spawn("Relic", {}, dropAt)
		end)
	else
		Announce.all("The Requiem Arrow has appeared" .. where .. "!", "relic")
		LootService.spawn("Relic", {}, position)
	end
end

function RelicService.unlock()
	MatchState.activationOpen = true
	Announce.all("Activation unlocked! Bring the Requiem Arrow to the beacon.", "relic")
end

local function activate(player: Player)
	if
		MatchState.carrier ~= player
		or not MatchState.activationOpen
		or not MatchState.isAlive(player)
	then
		if MatchState.carrier == player and not MatchState.activationOpen then
			Announce.to(player, "The arrow can be activated after 15:00", "bad")
		end
		return
	end
	local root = MatchState.rootOf(player)
	if
		not root
		or (root.Position - landmarkPosition).Magnitude > MatchConfig.activationRadius + 4
	then
		return
	end
	local started = Channels.start(
		player,
		"Activation",
		MatchConfig.activationDuration,
		MatchConfig.activationMoveTolerance,
		{
			onComplete = function()
				activationEvent:FireAllClients({
					name = player.Name,
					done = true,
					status = "complete",
				})
				if onActivated and MatchState.carrier == player then
					onActivated(player)
				end
			end,
			onCancel = function(reason)
				activationEvent:FireAllClients({
					name = player.Name,
					done = true,
					status = "cancelled",
					reason = reason,
				})
				Announce.all(
					player.Name .. "'s activation was interrupted (" .. reason .. ")!",
					"relic"
				)
			end,
		}
	)
	if started then
		activationEvent:FireAllClients({
			name = player.Name,
			duration = MatchConfig.activationDuration,
		})
		Announce.all(player.Name .. " is activating the Requiem Arrow! Stop them!", "relic")
	end
end

function RelicService.start(landmark: Model, position: Vector3, activated: (Player) -> ())
	landmarkPosition = position
	onActivated = activated
	local pad = landmark.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Activate Requiem Arrow"
	prompt.ObjectText = "Final Landmark"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = MatchConfig.activationRadius + 4
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = pad
	prompt.Triggered:Connect(activate)
	LootService.register("Relic", function(player)
		return pickUp(player), nil
	end)
end

function RelicService.landmark(): Vector3
	return landmarkPosition
end

return RelicService
