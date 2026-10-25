--!strict
-- Overhead deployment: players ride a flight line across the zone and choose when to
-- drop. Everyone still aboard drops when the flight ends. Falling is slowed until landing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MatchConfig = require(Shared.Config.Match)
local MatchState = require(script.Parent.MatchState)
local StandService = require(script.Parent.StandService)

local DeployService = {}

local GLIDE_WALK_SPEED = 40
local LANDING_HEIGHT = 6
local aboard: { [Player]: Vector3 } = {}
local deployEvent = Net.event("Deploy")

local function land(player: Player, humanoid: Humanoid, velocity: LinearVelocity)
	velocity:Destroy()
	humanoid:SetAttribute("Gliding", nil)
	StandService.refreshStats(player)
end

local function release(player: Player)
	if not aboard[player] then
		return
	end
	aboard[player] = nil
	deployEvent:FireClient(player, { aboard = false })
	local root, humanoid = MatchState.rootOf(player), MatchState.humanoidOf(player)
	if not root or not humanoid then
		return
	end
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if not attachment then
		local created = Instance.new("Attachment")
		created.Name = "RootAttachment"
		created.Parent = root
		attachment = created
	end
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	velocity.LineDirection = Vector3.yAxis
	velocity.LineVelocity = -MatchConfig.glideFallSpeed
	velocity.MaxForce = math.huge
	velocity.Parent = root
	humanoid:SetAttribute("Gliding", true)
	humanoid.WalkSpeed = GLIDE_WALK_SPEED
	root.Anchored = false

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.RespectCanCollide = true
	local started = os.clock()
	task.spawn(function()
		-- Landed once there is solid ground just below the character.
		while velocity.Parent and os.clock() - started < MatchConfig.glideMaxTime do
			if
				humanoid.Health <= 0
				or workspace:Raycast(root.Position, Vector3.new(0, -LANDING_HEIGHT, 0), params)
			then
				break
			end
			task.wait(0.1)
		end
		if velocity.Parent then
			land(player, humanoid, velocity)
		end
	end)
end

-- Runs the flight; returns when every player has dropped.
function DeployService.run(players: { Player }, center: Vector3, radius: number, rng: Random)
	local angle = rng:NextNumber() * math.pi * 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local altitude = center.Y + MatchConfig.deployAltitude
	local from = Vector3.new(center.X, altitude, center.Z) - direction * radius * 0.9
	local to = Vector3.new(center.X, altitude, center.Z) + direction * radius * 0.9
	local side = direction:Cross(Vector3.yAxis)

	for i, player in players do
		local root = MatchState.rootOf(player)
		if root then
			root.Anchored = true
			aboard[player] = side * ((i - #players / 2) * 4)
			deployEvent:FireClient(player, { aboard = true })
		end
	end

	local started = os.clock()
	local connection = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - started) / MatchConfig.deployDuration, 0, 1)
		local point = from:Lerp(to, t)
		for player, offset in aboard do
			local root = MatchState.rootOf(player)
			if root then
				root.CFrame = CFrame.lookAt(point + offset, point + offset + direction)
			end
		end
	end)
	while next(aboard) and os.clock() - started < MatchConfig.deployDuration do
		task.wait(0.2)
	end
	connection:Disconnect()
	for player in aboard do
		release(player)
	end
end

function DeployService.start()
	Net.event("DeployDrop").OnServerEvent:Connect(release)
end

function DeployService.forget(player: Player)
	aboard[player] = nil
end

return DeployService
