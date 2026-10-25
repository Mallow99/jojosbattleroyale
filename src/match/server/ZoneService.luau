--!strict
-- Safe zone visual and out-of-zone damage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local MatchConfig = require(Shared.Config.Match)
local Zone = require(Shared.Logic.Zone)
local MatchState = require(script.Parent.MatchState)
local Damage = require(script.Parent.Damage)

local ZoneService = {}

local WALL_HEIGHT = 2000
local DAMAGE_INTERVAL = 1

local origin: Zone.Circle = { x = 0, z = 0, radius = 1 }
local landmark: Zone.Circle = { x = 0, z = 0, radius = 0 }
local baseY = 0
local current: Zone.ZoneState? = nil
local lastDamage = 0
local wall: Part? = nil

function ZoneService.init(center: Vector3, radius: number, landmarkPosition: Vector3)
	origin = { x = center.X, z = center.Z, radius = radius }
	landmark = { x = landmarkPosition.X, z = landmarkPosition.Z, radius = 0 }
	baseY = center.Y - 400
	local model = Instance.new("Model")
	model.Name = "Zone"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local part = Instance.new("Part")
	part.Name = "Wall"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(170, 90, 255)
	part.Transparency = 0.2
	part.Parent = model
	model.Parent = workspace
	wall = part
end

function ZoneService.state(): Zone.ZoneState?
	return current
end

function ZoneService.target(elapsed: number): Zone.Circle
	return Zone.target(elapsed, MatchConfig.zone, origin, landmark)
end

function ZoneService.inside(position: Vector3): boolean
	return current == nil or Zone.contains(current, position.X, position.Z)
end

function ZoneService.update(elapsed: number)
	local zone = Zone.at(elapsed, MatchConfig.zone, origin, landmark)
	current = zone
	if wall then
		wall.Size = Vector3.new(WALL_HEIGHT, zone.radius * 2, zone.radius * 2)
		wall.CFrame = CFrame.new(zone.x, baseY + WALL_HEIGHT / 2, zone.z)
			* CFrame.Angles(0, 0, math.rad(90))
	end
	local now = os.clock()
	if now - lastDamage < DAMAGE_INTERVAL then
		return
	end
	lastDamage = now
	for _, player in MatchState.alivePlayers() do
		local root, humanoid = MatchState.rootOf(player), MatchState.humanoidOf(player)
		if
			root
			and humanoid
			and not root.Anchored
			and not Zone.contains(zone, root.Position.X, root.Position.Z)
		then
			Damage.apply(humanoid, zone.damage, nil)
		end
	end
end

return ZoneService
