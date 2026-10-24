--!nocheck
-- Lune helpers that author native Roblox instances for the stand cutscene assets.
-- Every model is built from Parts, WedgeParts and SurfaceGuis so it loads in Studio
-- without uploading meshes, images or animations.
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Color3 = roblox.Color3
local Enum = roblox.Enum
local UDim = roblox.UDim
local UDim2 = roblox.UDim2

local Builder = {}

function Builder.rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function smooth(part)
	for _, surface in
		{
			"TopSurface",
			"BottomSurface",
			"LeftSurface",
			"RightSurface",
			"FrontSurface",
			"BackSurface",
		}
	do
		part[surface] = Enum.SurfaceType.Smooth
	end
end

-- Creates a part. `kind` is Block, Wedge, Cylinder or Ball. `cf` is relative to `relativeTo`.
function Builder.part(parent, kind, name, size, cf, color, options)
	options = options or {}
	local part
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		elseif kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		else
			part.Shape = Enum.PartType.Block
		end
	end
	part.Name = name
	part.Size = size
	local origin = options.relativeTo or (parent:IsA("BasePart") and parent.CFrame) or CFrame.new()
	part.CFrame = origin * cf
	part.Color = color
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Reflectance = options.reflectance or 0
	part.Transparency = options.transparency or 0
	part.Anchored = options.anchored or false
	part.CanCollide = options.canCollide or false
	part.CanTouch = false
	part.CanQuery = options.canQuery or false
	part.CastShadow = options.castShadow ~= false
	part.Massless = true
	smooth(part)
	part.Parent = parent
	if parent:IsA("BasePart") and options.weld ~= false then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = parent
		weld.Part1 = part
		weld.Parent = part
	end
	return part
end

local function rightWedge(parent, name, p0, p1, p2, thickness, color, options)
	-- Right angle at p0; p1 lies along the wedge's -Z leg, p2 along its +Y leg.
	local legZ = p1 - p0
	local legY = p2 - p0
	local zAxis = (-legZ).Unit
	local yAxis = legY.Unit
	local xAxis = yAxis:Cross(zAxis)
	local center = p0 + legZ / 2 + legY / 2
	local cf = CFrame.fromMatrix(center, xAxis, yAxis, zAxis)
	return Builder.part(
		parent,
		"Wedge",
		name,
		Vector3.new(thickness, legY.Magnitude, legZ.Magnitude),
		cf,
		color,
		options
	)
end

-- Solid triangle between three points (relative to `parent`) using two WedgeParts.
function Builder.triangle(parent, name, a, b, c, thickness, color, options)
	local edges = { { a, b, c }, { b, c, a }, { c, a, b } }
	table.sort(edges, function(left, right)
		return (left[2] - left[1]).Magnitude > (right[2] - right[1]).Magnitude
	end)
	local s, e, apex = edges[1][1], edges[1][2], edges[1][3]
	local base = e - s
	local t = (apex - s):Dot(base) / base:Dot(base)
	local foot = s + base * t
	local made = {}
	if (foot - s).Magnitude > 0.01 then
		table.insert(made, rightWedge(parent, name, foot, s, apex, thickness, color, options))
	end
	if (e - foot).Magnitude > 0.01 then
		table.insert(made, rightWedge(parent, name, foot, e, apex, thickness, color, options))
	end
	return made
end

-- Mirrors a bone-relative CFrame across the X axis (left/right symmetry).
function Builder.mirror(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

function Builder.angles(x, y, z)
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

-- Standard Roblox R6 joint data (the values Studio's Rig Builder and R6 avatars use).
Builder.R6_JOINTS = {
	{
		"RootJoint",
		"HumanoidRootPart",
		"Torso",
		cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	{
		"Neck",
		"Torso",
		"Head",
		cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		cf(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	{
		"Right Shoulder",
		"Torso",
		"Right Arm",
		cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		"Left Shoulder",
		"Torso",
		"Left Arm",
		cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	{
		"Right Hip",
		"Torso",
		"Right Leg",
		cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		"Left Hip",
		"Torso",
		"Left Leg",
		cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}

-- Standard R6 character attachments, used by accessories and effects.
local R6_ATTACHMENTS = {
	Head = {
		FaceCenterAttachment = Vector3.new(0, 0, 0),
		FaceFrontAttachment = Vector3.new(0, 0, -0.6),
		HairAttachment = Vector3.new(0, 0.6, 0),
		HatAttachment = Vector3.new(0, 0.6, 0),
	},
	Torso = {
		NeckAttachment = Vector3.new(0, 1, 0),
		BodyFrontAttachment = Vector3.new(0, 0, -0.5),
		BodyBackAttachment = Vector3.new(0, 0, 0.5),
		LeftCollarAttachment = Vector3.new(-1, 1, 0),
		RightCollarAttachment = Vector3.new(1, 1, 0),
		WaistFrontAttachment = Vector3.new(0, -1, -0.5),
		WaistCenterAttachment = Vector3.new(0, -1, 0),
		WaistBackAttachment = Vector3.new(0, -1, 0.5),
	},
	["Left Arm"] = {
		LeftShoulderAttachment = Vector3.new(0, 1, 0),
		LeftGripAttachment = Vector3.new(0, -1, 0),
	},
	["Right Arm"] = {
		RightShoulderAttachment = Vector3.new(0, 1, 0),
		RightGripAttachment = Vector3.new(0, -1, 0),
	},
	["Left Leg"] = { LeftFootAttachment = Vector3.new(0, -1, 0) },
	["Right Leg"] = { RightFootAttachment = Vector3.new(0, -1, 0) },
	HumanoidRootPart = { RootAttachment = Vector3.new(0, 0, 0) },
}

-- Builds a standard R6 character rig standing on y = 0, facing -Z.
-- `colors` holds head/torso/arm/leg Color3s; they are also written to BodyColors.
function Builder.r6(name, colors)
	local model = Instance.new("Model")
	model.Name = name
	local layout = {
		HumanoidRootPart = { Vector3.new(2, 2, 1), Vector3.new(0, 3, 0) },
		Torso = { Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), colors.torso },
		Head = { Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), colors.head },
		["Left Arm"] = {
			Vector3.new(1, 2, 1),
			Vector3.new(-1.5, 3, 0),
			colors.leftArm or colors.arms,
		},
		["Right Arm"] = {
			Vector3.new(1, 2, 1),
			Vector3.new(1.5, 3, 0),
			colors.rightArm or colors.arms,
		},
		["Left Leg"] = {
			Vector3.new(1, 2, 1),
			Vector3.new(-0.5, 1, 0),
			colors.leftLeg or colors.legs,
		},
		["Right Leg"] = {
			Vector3.new(1, 2, 1),
			Vector3.new(0.5, 1, 0),
			colors.rightLeg or colors.legs,
		},
	}
	local bones = {}
	for _, partName in
		{ "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
	do
		local spec = layout[partName]
		local isRoot = partName == "HumanoidRootPart"
		local part = Builder.part(
			model,
			"Block",
			partName,
			spec[1],
			CFrame.new(spec[2]),
			spec[3] or Color3.fromRGB(163, 162, 165),
			{
				transparency = if isRoot then 1 else 0,
				anchored = isRoot,
				canCollide = partName == "Torso" or partName == "Head" or isRoot,
				castShadow = not isRoot,
				material = Enum.Material.Plastic,
				weld = false,
			}
		)
		part.Massless = false
		bones[partName] = part
		for attachmentName, position in R6_ATTACHMENTS[partName] or {} do
			local attachment = Instance.new("Attachment")
			attachment.Name = attachmentName
			attachment.CFrame = CFrame.new(position)
			attachment.Parent = part
		end
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = bones.Head
	model.PrimaryPart = bones.HumanoidRootPart

	for _, joint in Builder.R6_JOINTS do
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = bones[joint[2]]
		motor.Part1 = bones[joint[3]]
		motor.C0 = joint[4]
		motor.C1 = joint[5]
		motor.MaxVelocity = 0.1
		-- Roblox keeps R6 joints in the Torso, except RootJoint which lives in the root part.
		motor.Parent = if joint[1] == "RootJoint" then bones.HumanoidRootPart else bones.Torso
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	local bodyColors = Instance.new("BodyColors")
	bodyColors.HeadColor3 = layout.Head[3]
	bodyColors.TorsoColor3 = layout.Torso[3]
	bodyColors.LeftArmColor3 = layout["Left Arm"][3]
	bodyColors.RightArmColor3 = layout["Right Arm"][3]
	bodyColors.LeftLegColor3 = layout["Left Leg"][3]
	bodyColors.RightLegColor3 = layout["Right Leg"][3]
	bodyColors.Parent = model
	return model, bones
end

-- SurfaceGui drawing helpers. Coordinates are 0..1 of the face, origin top-left as seen
-- from outside the face.
function Builder.surface(part, face, name)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name or (face .. "Art")
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = roblox.Vector2.new(400, 400)
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	gui.Parent = part
	return gui
end

-- Rectangle centred at (cx, cy) with size (w, h), rotation in degrees.
function Builder.rect(gui, name, cx, cy, w, h, color, options)
	options = options or {}
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = roblox.Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(cx, cy)
	frame.Size = UDim2.fromScale(w, h)
	frame.Rotation = options.rotation or 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = options.transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = options.z or 1
	frame.Parent = gui
	if options.round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(options.round, 0)
		corner.Parent = frame
	end
	if options.gradient then
		local gradient = Instance.new("UIGradient")
		gradient.Color = options.gradient
		gradient.Rotation = options.gradientRotation or 0
		if options.gradientTransparency then
			gradient.Transparency = options.gradientTransparency
		end
		gradient.Parent = frame
	end
	return frame
end

function Builder.text(gui, name, text, cx, cy, w, h, color, options)
	options = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = roblox.Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(cx, cy)
	label.Size = UDim2.fromScale(w, h)
	label.Rotation = options.rotation or 0
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = options.font or Enum.Font.GothamBlack
	label.TextStrokeColor3 = options.strokeColor or Color3.new(0, 0, 0)
	label.TextStrokeTransparency = options.strokeTransparency or 1
	label.ZIndex = options.z or 2
	label.Parent = gui
	return label
end

return Builder
