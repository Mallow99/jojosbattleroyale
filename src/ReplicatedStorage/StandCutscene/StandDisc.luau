--!strict
-- Builds the Star Platinum stand disc prop: a thin cylinder with an iridescent label on both
-- faces. Built at runtime from engine primitives and GUI objects, so it needs no uploads.

local StandDisc = {}

StandDisc.RADIUS = 0.5

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 240)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(190, 220, 255)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200, 255, 230)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 250, 200)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(230, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 210, 240)),
})
local LABEL = ColorSequence.new(Color3.fromRGB(150, 110, 255), Color3.fromRGB(70, 40, 160))

local function circle(parent: Instance, name: string, size: number, color: Color3, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

local function label(
	parent: Instance,
	name: string,
	text: string,
	y: number,
	width: number,
	font: Enum.Font,
	color: Color3
)
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Position = UDim2.fromScale(0.5, y)
	textLabel.Size = UDim2.fromScale(width, 0.11)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = font
	textLabel.TextColor3 = color
	textLabel.ZIndex = 4
	textLabel.Parent = parent
end

local function decorate(disc: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(512, 512)
	gui.LightInfluence = 1
	gui.Parent = disc
	local shine = circle(gui, "Shine", 1, Color3.new(1, 1, 1), 1)
	local gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW
	gradient.Rotation = 35
	gradient.Parent = shine
	local groove = circle(gui, "Groove", 0.86, Color3.new(1, 1, 1), 2)
	groove.BackgroundTransparency = 0.75
	local labelFrame = circle(gui, "Label", 0.66, Color3.new(1, 1, 1), 3)
	local labelGradient = Instance.new("UIGradient")
	labelGradient.Color = LABEL
	labelGradient.Rotation = 90
	labelGradient.Parent = labelFrame
	label(gui, "Star", "★", 0.27, 0.2, Enum.Font.GothamBlack, Color3.fromRGB(255, 216, 74))
	label(gui, "Name", "STAR", 0.38, 0.36, Enum.Font.Bangers, Color3.new(1, 1, 1))
	label(gui, "Name2", "PLATINUM", 0.66, 0.5, Enum.Font.Bangers, Color3.new(1, 1, 1))
	circle(gui, "HoleRing", 0.2, Color3.fromRGB(220, 224, 236), 5)
	circle(gui, "Hole", 0.11, Color3.fromRGB(30, 26, 44), 6)
end

-- Returns the disc part (named "Disc", the Pose name used by the user animation).
function StandDisc.build(): BasePart
	local disc = Instance.new("Part")
	disc.Name = "Disc"
	disc.Shape = Enum.PartType.Cylinder -- axis is X, so the faces are Left and Right
	disc.Size = Vector3.new(0.05, StandDisc.RADIUS * 2, StandDisc.RADIUS * 2)
	disc.Color = Color3.fromRGB(232, 236, 248)
	disc.Material = Enum.Material.SmoothPlastic
	disc.Reflectance = 0.2
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Massless = true
	disc.CastShadow = false
	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.04, StandDisc.RADIUS * 2 + 0.03, StandDisc.RADIUS * 2 + 0.03)
	rim.Color = Color3.fromRGB(190, 196, 214)
	rim.Material = Enum.Material.SmoothPlastic
	rim.Reflectance = 0.3
	rim.CanCollide = false
	rim.CanQuery = false
	rim.CanTouch = false
	rim.Massless = true
	rim.CastShadow = false
	rim.CFrame = disc.CFrame
	rim.Parent = disc
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = disc
	weld.Part1 = rim
	weld.Parent = rim
	decorate(disc, Enum.NormalId.Right)
	decorate(disc, Enum.NormalId.Left)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 150, 255)
	light.Brightness = 1.2
	light.Range = 6
	light.Parent = disc
	return disc
end

-- Fades every part and label of the disc (1 = visible). GUI objects ignore part transparency.
function StandDisc.setVisibility(disc: BasePart, visibility: number)
	local hidden = 1 - visibility
	for _, item in disc:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = hidden
		elseif item:IsA("SurfaceGui") or item:IsA("PointLight") then
			(item :: any).Enabled = visibility > 0.02
		elseif item:IsA("Frame") then
			local base = item:GetAttribute("BaseTransparency")
			if base == nil then
				base = item.BackgroundTransparency
				item:SetAttribute("BaseTransparency", base)
			end
			item.BackgroundTransparency = 1 - (1 - base :: number) * visibility
		elseif item:IsA("TextLabel") then
			item.TextTransparency = hidden
		end
	end
	disc.LocalTransparencyModifier = hidden
end

return StandDisc
