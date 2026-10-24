--!strict
-- Client-side presentation for the cutscene: letterbox/flash/title GUI, menacing glyphs,
-- shock rings, aura particles, colour grading and the stand's summon glow.
-- Everything uses engine primitives and built-in textures; nothing needs uploading.

local Lighting = game:GetService("Lighting")

local Effects = {}
Effects.__index = Effects

local RING_SEGMENTS = 24

export type Effects = typeof(setmetatable(
	{} :: {
		gui: ScreenGui,
		bars: { Frame },
		flash: Frame,
		title: Frame,
		titleLabels: { TextLabel },
		glyphs: { TextLabel },
		glyphSizes: { Vector2 },
		grading: ColorCorrectionEffect,
		folder: Folder,
		rings: { { BasePart } },
		emitters: { [string]: ParticleEmitter },
		highlight: Highlight?,
	},
	Effects
))

local function frame(parent: Instance, name: string, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function text(
	parent: Instance,
	name: string,
	value: string,
	color: Color3,
	strokeThickness: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextScaled = true
	label.Font = Enum.Font.Bangers
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(42, 16, 80)
	stroke.Thickness = strokeThickness
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function emitter(
	parent: Attachment,
	color: ColorSequence,
	rate: number,
	size: number
): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	-- Default texture (built-in sparkles), tinted.
	particles.Color = color
	particles.LightEmission = 1
	particles.LightInfluence = 0
	particles.Rate = rate
	particles.Lifetime = NumberRange.new(0.7, 1.2)
	particles.Speed = NumberRange.new(2, 4.5)
	particles.SpreadAngle = Vector2.new(40, 40)
	particles.Acceleration = Vector3.new(0, 2, 0)
	particles.EmissionDirection = Enum.NormalId.Top
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Enabled = false
	particles.Parent = parent
	return particles
end

function Effects.new(playerGui: PlayerGui, shots: any): Effects
	local gui = Instance.new("ScreenGui")
	gui.Name = "StandCutsceneGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bars = {}
	for index, anchor in { 0, 1 } do
		local bar = frame(gui, if index == 1 then "TopBar" else "BottomBar", Color3.new(0, 0, 0))
		bar.AnchorPoint = Vector2.new(0, anchor)
		bar.Position = UDim2.fromScale(0, anchor)
		bar.Size = UDim2.fromScale(1, 0)
		bar.ZIndex = 5
		table.insert(bars, bar)
	end
	local flash = frame(gui, "Flash", Color3.new(1, 1, 1))
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 6

	local title = Instance.new("Frame")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.fromScale(0.05, 0.84)
	title.Size = UDim2.fromScale(0.5, 0.2)
	title.ZIndex = 7
	title.Parent = gui
	local caption = text(title, "Caption", "STAND NAME", Color3.fromRGB(255, 216, 74), 2)
	caption.Size = UDim2.fromScale(0.5, 0.25)
	local shadow = text(title, "Shadow", shots.standName, Color3.fromRGB(122, 60, 255), 0)
	shadow.Position = UDim2.fromScale(0.012, 0.3)
	shadow.Size = UDim2.fromScale(1, 0.72)
	local name = text(title, "Name", shots.standName, Color3.new(1, 1, 1), 3)
	name.Position = UDim2.fromScale(0, 0.25)
	name.Size = UDim2.fromScale(1, 0.72)

	local glyphs = {}
	local glyphSizes = {}
	for _, slot in shots.menacing do
		local glyph = Instance.new("TextLabel")
		glyph.Name = "Menacing"
		glyph.BackgroundTransparency = 1
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(slot[1], slot[2])
		glyph.Size = UDim2.fromScale(0.09 * slot[3], 0.16 * slot[3])
		table.insert(glyphSizes, Vector2.new(0.09 * slot[3], 0.16 * slot[3]))
		glyph.Rotation = slot[4]
		glyph.Text = "ゴ"
		glyph.TextScaled = true
		glyph.Font = Enum.Font.GothamBlack
		glyph.TextColor3 = Color3.fromRGB(182, 77, 255)
		glyph.TextTransparency = 1
		glyph.ZIndex = 6
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
		stroke.Transparency = 1
		stroke.Parent = glyph
		glyph.Parent = gui
		table.insert(glyphs, glyph)
	end
	gui.Parent = playerGui

	local grading = Instance.new("ColorCorrectionEffect")
	grading.Name = "StandCutsceneGrading"
	grading.Parent = Lighting

	local folder = Instance.new("Folder")
	folder.Name = "StandCutsceneEffects"
	folder.Parent = workspace

	local rings: { { BasePart } } = {}
	for _, spec in shots.rings do
		local segments: { BasePart } = {}
		for _ = 1, RING_SEGMENTS do
			local segment = Instance.new("Part")
			segment.Anchored = true
			segment.CanCollide = false
			segment.CanQuery = false
			segment.CanTouch = false
			segment.CastShadow = false
			segment.Material = Enum.Material.Neon
			segment.Color = spec.color
			segment.Transparency = 1
			segment.Size = Vector3.new(0.5, 0.12, 0.12)
			segment.Parent = folder
			table.insert(segments, segment)
		end
		table.insert(rings, segments)
	end

	return setmetatable({
		gui = gui,
		bars = bars,
		flash = flash,
		title = title,
		titleLabels = { caption, shadow, name },
		glyphs = glyphs,
		glyphSizes = glyphSizes,
		grading = grading,
		folder = folder,
		rings = rings,
		emitters = {},
		highlight = nil,
	}, Effects)
end

-- Attaches an aura emitter to `part` under `key`.
function Effects.addAura(
	self: Effects,
	key: string,
	part: BasePart,
	color: Color3,
	rate: number,
	size: number
)
	local attachment = Instance.new("Attachment")
	attachment.Name = "StandCutsceneAura"
	attachment.Parent = part
	self.emitters[key] = emitter(attachment, ColorSequence.new(color), rate, size)
end

function Effects.addGlow(self: Effects, model: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "SummonGlow"
	highlight.FillColor = Color3.fromRGB(170, 120, 255)
	highlight.OutlineColor = Color3.fromRGB(235, 210, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	self.highlight = highlight
end

export type EffectState = {
	letterbox: number,
	flash: number,
	tint: number,
	menacing: number,
	title: number,
	glow: number,
	visibility: number,
	t: number,
}

function Effects.update(self: Effects, state: EffectState)
	local barHeight = 0.11 * state.letterbox
	for _, bar in self.bars do
		bar.Size = UDim2.fromScale(1, barHeight)
	end
	self.flash.BackgroundTransparency = 1 - state.flash
	for index, glyph in self.glyphs do
		local pulse = 1 + 0.08 * math.sin(state.t * 6 + index * 1.3)
		glyph.TextTransparency = 1 - state.menacing
		local stroke = glyph:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1 - state.menacing
		end
		local base = self.glyphSizes[index]
		glyph.Size = UDim2.fromScale(base.X * pulse, base.Y * pulse)
	end
	local titleAlpha = state.title
	self.title.Position = UDim2.fromScale(0.05 - (1 - titleAlpha) * 0.04, 0.84)
	for _, label in self.titleLabels do
		label.TextTransparency = 1 - titleAlpha
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1 - titleAlpha
		end
	end
	local tint = state.tint
	self.grading.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(225, 205, 255), tint)
	self.grading.Saturation = 0.25 * tint
	self.grading.Contrast = 0.15 * tint
	local highlight = self.highlight
	if highlight then
		highlight.Enabled = state.visibility > 0.01 and state.glow > 0.01
		highlight.FillTransparency = 1 - 0.75 * state.glow * state.visibility
		highlight.OutlineTransparency = 1 - state.glow * state.visibility
	end
end

function Effects.setAura(self: Effects, key: string, enabled: boolean)
	local particles = self.emitters[key]
	if particles then
		particles.Enabled = enabled
	end
end

-- Positions ring `index` (centre CFrame, radius, 0..1 alpha).
function Effects.setRing(
	self: Effects,
	index: number,
	center: CFrame?,
	radius: number,
	alpha: number
)
	local segments = self.rings[index]
	for i, segment in segments do
		if not center or alpha <= 0.01 then
			segment.Transparency = 1
		else
			local angle = (i / RING_SEGMENTS) * math.pi * 2
			segment.Size = Vector3.new(radius * math.pi * 2 / RING_SEGMENTS * 1.08, 0.14, 0.14)
			segment.CFrame = center * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
			segment.Transparency = 1 - alpha
		end
	end
end

function Effects.destroy(self: Effects)
	self.gui:Destroy()
	self.grading:Destroy()
	self.folder:Destroy()
	for _, particles in self.emitters do
		local attachment = particles.Parent
		if attachment then
			attachment:Destroy()
		end
	end
	if self.highlight then
		self.highlight:Destroy()
	end
end

return Effects
