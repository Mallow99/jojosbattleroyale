--!strict
-- Map queries: ground height, loot points, district names and the final landmark.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.Match)

local MapService = {}

local RAY_TOP = 3000
local RAY_LENGTH = 4000

local map = workspace:WaitForChild("Map")
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { map }

-- Highest map surface at (x, z), or nil over empty space.
function MapService.ground(x: number, z: number): Vector3?
	local result =
		workspace:Raycast(Vector3.new(x, RAY_TOP, z), Vector3.new(0, -RAY_LENGTH, 0), rayParams)
	return if result then result.Position else nil
end

local function markers(): { Vector3 }
	local list = {}
	local folder = workspace:FindFirstChild("LootSpawns")
	for _, part in if folder then folder:GetChildren() else {} do
		if part:IsA("BasePart") then
			table.insert(list, part.Position)
		end
	end
	return list
end

-- Center of the playable town: the centroid of the loot markers.
function MapService.center(): Vector3
	local list = markers()
	local sum = Vector3.zero
	for _, position in list do
		sum += position
	end
	local center = if #list > 0 then sum / #list else Vector3.zero
	return MapService.ground(center.X, center.Z) or center
end

-- Map markers plus random ground points inside the starting circle.
function MapService.lootPoints(
	center: Vector3,
	radius: number,
	target: number,
	rng: Random
): { Vector3 }
	local points = {}
	for _, position in markers() do
		local ground = MapService.ground(position.X, position.Z)
		table.insert(
			points,
			if ground and math.abs(ground.Y - position.Y) < 6 then ground else position
		)
	end
	local attempts = 0
	while #points < target and attempts < target * 20 do
		attempts += 1
		local angle = rng:NextNumber() * math.pi * 2
		local distance = math.sqrt(rng:NextNumber()) * radius
		local ground = MapService.ground(
			center.X + math.cos(angle) * distance,
			center.Z + math.sin(angle) * distance
		)
		if ground then
			table.insert(points, ground)
		end
	end
	return points
end

-- Name of the district containing `position`, if any.
function MapService.districtAt(position: Vector3): string?
	local folder = workspace:FindFirstChild("Districts")
	for _, part in if folder then folder:GetChildren() else {} do
		if part:IsA("BasePart") then
			local localPos = part.CFrame:PointToObjectSpace(position)
			if
				math.abs(localPos.X) <= part.Size.X / 2
				and math.abs(localPos.Z) <= part.Size.Z / 2
			then
				return part.Name
			end
		end
	end
	return nil
end

-- Builds the activation beacon in the configured district.
function MapService.buildLandmark(): (Model, Vector3)
	local folder = workspace:FindFirstChild("Districts")
	local district = folder and folder:FindFirstChild(MatchConfig.finalLandmarkDistrict)
	local anchor = if district and district:IsA("BasePart")
		then district.Position
		else MapService.center()
	local position = MapService.ground(anchor.X, anchor.Z) or anchor

	local model = Instance.new("Model")
	model.Name = "FinalLandmark"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Anchored = true
	pad.CanCollide = false
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.4, MatchConfig.activationRadius * 2, MatchConfig.activationRadius * 2)
	pad.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(255, 210, 90)
	pad.Transparency = 0.6
	pad.Parent = model
	local pillar = Instance.new("Part")
	pillar.Name = "Beacon"
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Size = Vector3.new(2, 400, 2)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 200, 0))
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 210, 90)
	pillar.Transparency = 0.5
	pillar.Parent = model
	model.PrimaryPart = pad
	model.Parent = workspace
	return model, position
end

return MapService
