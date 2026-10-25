--!strict
-- Silver Chariot Requiem guards the Requiem Arrow. It floats after the nearest player
-- inside its aggro range, strikes at melee range and returns home when nobody is near.
-- Defeating it drops the Requiem Arrow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local MatchConfig = require(Shared.Config.Match)
local MatchState = require(script.Parent.MatchState)
local MapService = require(script.Parent.MapService)
local Damage = require(script.Parent.Damage)
local Announce = require(script.Parent.Announce)

local BossService = {}

local HOVER = 3.5
local config = MatchConfig.boss

function BossService.spawn(home: Vector3, onDefeated: (position: Vector3) -> ())
	local package = ServerStorage.Assets.Boss:FindFirstChild(config.standId)
	local morph = package and package:FindFirstChild("Morph")
	if not package or not morph then
		warn("[Boss] Missing boss package; dropping the arrow unguarded")
		onDefeated(home)
		return
	end
	local model = morph:Clone() :: Model
	model.Name = config.displayName
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
		elseif descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") then
			descendant:Destroy()
		end
	end
	model.PrimaryPart = root
	humanoid.EvaluateStateMachine = false
	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.DisplayName = config.displayName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	model:PivotTo(CFrame.new(home + Vector3.new(0, HOVER, 0)))
	model.Parent = workspace

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local function track(name: string): AnimationTrack?
		local animation = package:FindFirstChild(name)
		return if animator
				and animation
				and animation:IsA("Animation")
			then animator:LoadAnimation(animation)
			else nil
	end
	local idle, move = track("Idle"), track("Move")
	if idle then
		idle:Play()
	end

	local lastStrike = 0
	local moving = false
	local defeated = false
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		if defeated then
			return
		end
		if humanoid.Health <= 0 or MatchState.ended then
			defeated = true
			connection:Disconnect()
			local position = root.Position
			if humanoid.Health <= 0 then
				local killer = Damage.killerOf(humanoid)
				Announce.all(
					config.displayName
						.. " was defeated"
						.. (if killer then " by " .. killer.Name else "")
						.. "! The Requiem Arrow dropped.",
					"relic"
				)
				onDefeated(MapService.ground(position.X, position.Z) or home)
			end
			task.delay(1, model.Destroy, model)
			return
		end

		local target: Player? = nil
		local best = config.aggroRadius
		for _, player in MatchState.alivePlayers() do
			local playerRoot = MatchState.rootOf(player)
			if playerRoot and (playerRoot.Position - home).Magnitude <= config.leashRadius then
				local distance = (playerRoot.Position - root.Position).Magnitude
				if distance < best then
					best = distance
					target = player
				end
			end
		end

		local goal = home
		local targetRoot = if target then MatchState.rootOf(target) else nil
		if targetRoot then
			goal = targetRoot.Position
		end
		local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		local distance = flat.Magnitude
		local stopAt = if targetRoot then config.attackRange * 0.6 else 1
		local position = root.Position
		local isMoving = distance > stopAt
		if isMoving then
			position += flat.Unit * math.min(distance - stopAt, config.moveSpeed * dt)
		end
		local ground = MapService.ground(position.X, position.Z)
		local y = if ground then ground.Y + HOVER else position.Y
		local facing = if distance > 0.1
			then Vector3.new(goal.X, y, goal.Z)
			else Vector3.new(position.X, y, position.Z) + root.CFrame.LookVector
		model:PivotTo(CFrame.lookAt(Vector3.new(position.X, y, position.Z), facing))

		if isMoving ~= moving then
			moving = isMoving
			if move then
				if moving then
					move:Play()
				else
					move:Stop()
				end
			end
		end

		local now = os.clock()
		if
			target
			and targetRoot
			and best <= config.attackRange
			and now - lastStrike >= config.attackCooldown
		then
			lastStrike = now
			local victim = MatchState.humanoidOf(target)
			if victim then
				Damage.apply(victim, config.damage, nil)
			end
		end
	end)
end

return BossService
