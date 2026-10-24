--!nocheck
-- Serialises rigs and frame states for the browser preview renderer.
local roblox = require("@lune/roblox")

local Export = {}

local function cf(value)
	local components = { value:GetComponents() }
	for index, number in components do
		components[index] = math.floor(number * 10000 + 0.5) / 10000
	end
	return components
end
Export.cf = cf

-- Lune reports unset properties without defaults as errors; fall back explicitly.
local function get(instance, property, default)
	local ok, value = pcall(function()
		return instance[property]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

local function color(value)
	return { value.R, value.G, value.B }
end

local function shapeOf(part)
	if part:IsA("WedgePart") then
		return "Wedge"
	end
	return get(part, "Shape", roblox.Enum.PartType.Block).Name
end

local function sequence(value)
	local keys = {}
	for _, key in value.Keypoints do
		table.insert(
			keys,
			{ key.Time, if typeof(key.Value) == "Color3" then color(key.Value) else key.Value }
		)
	end
	return keys
end

local function gui(surface)
	local elements = {}
	for _, child in surface:GetChildren() do
		if child:IsA("GuiObject") then
			assert(
				#child:GetChildren() == 0
					or child:FindFirstChildWhichIsA("UICorner")
					or child:FindFirstChildWhichIsA("UIGradient"),
				"nested GUI objects are not previewed"
			)
			local element = {
				kind = child.ClassName,
				x = child.Position.X.Scale,
				y = child.Position.Y.Scale,
				w = child.Size.X.Scale,
				h = child.Size.Y.Scale,
				ax = child.AnchorPoint.X,
				ay = child.AnchorPoint.Y,
				rotation = get(child, "Rotation", 0),
				z = get(child, "ZIndex", 1),
				color = color(get(child, "BackgroundColor3", roblox.Color3.new(1, 1, 1))),
				transparency = get(child, "BackgroundTransparency", 0),
			}
			local corner = child:FindFirstChildWhichIsA("UICorner")
			if corner then
				element.round = get(corner, "CornerRadius", roblox.UDim.new(0, 8)).Scale
			end
			local gradient = child:FindFirstChildWhichIsA("UIGradient")
			if gradient then
				element.gradient = {
					color = sequence(gradient.Color),
					transparency = sequence(
						get(gradient, "Transparency", roblox.NumberSequence.new(0))
					),
					rotation = get(gradient, "Rotation", 0),
				}
			end
			if child:IsA("TextLabel") then
				element.text = get(child, "Text", "")
				element.textColor = color(get(child, "TextColor3", roblox.Color3.new(1, 1, 1)))
				element.textStroke = 1 - get(child, "TextStrokeTransparency", 1)
				local font = get(child, "Font", nil)
				element.font = if font then font.Name else "Bangers"
			end
			table.insert(elements, element)
		end
	end
	return { face = surface.Face.Name, elements = elements }
end

local function partEntry(part, actorName, boneName, offset)
	local guis = {}
	local decals = {}
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			table.insert(guis, gui(child))
		elseif child:IsA("Decal") and get(child, "Transparency", 0) < 1 then
			table.insert(decals, {
				face = get(child, "Face", roblox.Enum.NormalId.Front).Name,
				texture = get(child, "Texture", ""),
			})
		end
	end
	local shape = shapeOf(part)
	local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
	if mesh and get(mesh, "MeshType", roblox.Enum.MeshType.Brick) == roblox.Enum.MeshType.Head then
		shape = "Head"
	end
	local entry = {
		name = part.Name,
		actor = actorName,
		bone = boneName,
		offset = cf(offset),
		shape = shape,
		size = { part.Size.X, part.Size.Y, part.Size.Z },
		color = color(get(part, "Color", roblox.Color3.fromRGB(163, 162, 165))),
		material = get(part, "Material", roblox.Enum.Material.Plastic).Name,
		transparency = get(part, "Transparency", 0),
		reflectance = get(part, "Reflectance", 0),
		guis = guis,
		decals = decals,
	}
	if part:IsA("MeshPart") then
		entry.shape = "Mesh"
		entry.mesh = part:GetAttribute("SourceMesh")
		entry.meshCenter = part:GetAttribute("SourceCenter")
			and {
				part:GetAttribute("SourceCenter").X,
				part:GetAttribute("SourceCenter").Y,
				part:GetAttribute("SourceCenter").Z,
			}
		entry.meshScale = part:GetAttribute("SourceScale") or 1
		entry.textured = get(part, "TextureID", "") ~= ""
	end
	return entry
end

-- Every BasePart of `model`, attached to the nearest ancestor (or self) named in `bones`.
-- `rest` maps bone name -> rest CFrame used to compute offsets.
function Export.modelParts(actorName, model, rest)
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local bone = part
			while bone and not rest[bone.Name] do
				bone = bone.Parent
			end
			assert(bone, actorName .. ": no bone for " .. part:GetFullName())
			table.insert(
				parts,
				partEntry(part, actorName, bone.Name, rest[bone.Name]:Inverse() * part.CFrame)
			)
		end
	end
	return parts
end

function Export.staticParts(actorName, root)
	local parts = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, partEntry(part, actorName, "World", part.CFrame))
		end
	end
	return parts
end

function Export.bones(boneCFrames)
	local out = {}
	for name, value in boneCFrames do
		out[name] = cf(value)
	end
	return out
end

return Export
