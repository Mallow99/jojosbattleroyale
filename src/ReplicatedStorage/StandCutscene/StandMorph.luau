--!strict
-- Installs the Star Platinum morph meshes (imported from art/star_platinum/StarPlatinumMorph.fbx
-- with Studio's 3D Importer) onto a standard R6 rig.
--
-- Each imported MeshPart is named "<Bone>__<Piece>__<colour>". Four markers (Marker__O/X/Y/Z)
-- sit at the origin and 4 studs along each axis of the authoring space, so the installer can
-- recover the importer's placement, rotation and scale instead of assuming import settings.
--
-- Usage:
--   StandMorph.install(rig, importedModel)            -- welds clones of the meshes to `rig`
--   StandMorph.bake()  (Studio command bar)           -- installs into the stored rigs once

local StandMorph = {}

StandMorph.BONES = {
	Head = "Head",
	Torso = "Torso",
	LeftArm = "Left Arm",
	RightArm = "Right Arm",
	LeftLeg = "Left Leg",
	RightLeg = "Right Leg",
}

-- R6 rest CFrames in authoring space (ground at y = 0, facing -Z).
StandMorph.REST = {
	Head = CFrame.new(0, 4.5, 0),
	Torso = CFrame.new(0, 3, 0),
	LeftArm = CFrame.new(-1.5, 3, 0),
	RightArm = CFrame.new(1.5, 3, 0),
	LeftLeg = CFrame.new(-0.5, 1, 0),
	RightLeg = CFrame.new(0.5, 1, 0),
}

StandMorph.PALETTE = {
	hair = Color3.fromRGB(40, 32, 84),
	hairLight = Color3.fromRGB(62, 50, 120),
	gold = Color3.fromRGB(232, 182, 64),
	goldDark = Color3.fromRGB(168, 116, 36),
	scarf = Color3.fromRGB(204, 36, 50),
	scarfDark = Color3.fromRGB(150, 22, 38),
	cloth = Color3.fromRGB(40, 36, 88),
	gem = Color3.fromRGB(220, 30, 60),
	tex = Color3.new(1, 1, 1),
	facetex = Color3.new(1, 1, 1),
}

local MORPH_FOLDER = "StandMorph"

export type Piece = { bone: string, piece: string, colour: string }

-- Importers may append suffixes such as ".001"; only the first three fields matter.
function StandMorph.parse(name: string): Piece?
	local bone, piece, colour = string.match(name, "^([%w]+)__([%w]+)__([%w]+)")
	if not bone then
		return nil
	end
	return { bone = bone :: string, piece = piece :: string, colour = colour :: string }
end

local function findPieces(imported: Instance): ({ BasePart }, { [string]: BasePart })
	local pieces: { BasePart } = {}
	local markers: { [string]: BasePart } = {}
	local candidates = imported:GetDescendants()
	table.insert(candidates, imported)
	for _, descendant in candidates do
		if descendant:IsA("BasePart") then
			local parsed = StandMorph.parse(descendant.Name)
			if parsed and parsed.bone == "Marker" then
				markers[parsed.piece] = descendant
			elseif parsed and StandMorph.BONES[parsed.bone] then
				table.insert(pieces, descendant)
			end
		end
	end
	return pieces, markers
end

-- Authoring frame of the imported model and its scale (imported studs per authored stud).
function StandMorph.importFrame(imported: Instance): (CFrame, number)
	local _, markers = findPieces(imported)
	local o, x, y, z = markers.O, markers.X, markers.Y, markers.Z
	assert(o and x and y and z, "imported morph is missing Marker__O/X/Y/Z")
	local origin = o.CFrame.Position
	local xAxis = x.CFrame.Position - origin
	local yAxis = y.CFrame.Position - origin
	local zAxis = z.CFrame.Position - origin
	local scale = (xAxis.Magnitude + yAxis.Magnitude + zAxis.Magnitude) / 12
	assert(scale > 1e-3, "markers overlap; the import is degenerate")
	local right = xAxis.Unit
	local up = (yAxis - right * yAxis:Dot(right)).Unit
	local back = right:Cross(up)
	assert(
		back:Dot(zAxis.Unit) > 0.9,
		"imported morph is mirrored; re-import without flipping axes"
	)
	return CFrame.fromMatrix(origin, right, up, back), scale
end

-- Returns the installed parts. Existing morph parts on `rig` are replaced.
function StandMorph.install(rig: Model, imported: Instance): { BasePart }
	local pieces = findPieces(imported)
	local frame, scale = StandMorph.importFrame(imported)
	local frameInverse = frame:Inverse()
	local installed: { BasePart } = {}
	local covered: { [string]: boolean } = {}

	for _, bonePart in rig:GetChildren() do
		local old = bonePart:FindFirstChild(MORPH_FOLDER)
		if old then
			old:Destroy()
		end
	end

	for _, source in pieces do
		local parsed = StandMorph.parse(source.Name) :: Piece
		local bone = rig:FindFirstChild(StandMorph.BONES[parsed.bone])
		assert(
			bone and bone:IsA("BasePart"),
			"rig is missing R6 part " .. StandMorph.BONES[parsed.bone]
		)
		-- Piece pose in authoring space, with the importer's scale removed.
		local relative = frameInverse * source.CFrame
		local authored = CFrame.new(relative.Position / scale) * (relative - relative.Position)
		local offset = StandMorph.REST[parsed.bone]:Inverse() * authored

		local folder = bone:FindFirstChild(MORPH_FOLDER)
		if not folder then
			local created = Instance.new("Folder")
			created.Name = MORPH_FOLDER
			created.Parent = bone
			folder = created
		end
		local part = source:Clone()
		for _, child in part:GetChildren() do
			if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		part.Name = parsed.piece
		part.Size = source.Size / scale
		part.CFrame = bone.CFrame * offset
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = true
		local hasTexture = part:IsA("MeshPart") and part.TextureID ~= ""
		local colour = StandMorph.PALETTE[parsed.colour]
		if colour and not hasTexture then
			part.Color = colour
		elseif hasTexture then
			part.Color = Color3.new(1, 1, 1)
		end
		part.Material = if string.sub(parsed.colour, 1, 4) == "gold"
			then Enum.Material.Metal
			else Enum.Material.SmoothPlastic
		part:SetAttribute("MorphOffset", offset)
		part.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bone
		weld.Part1 = part
		weld.Parent = part
		table.insert(installed, part)
		if parsed.piece == "Body" or parsed.piece == "Face" then
			covered[bone.Name] = true
		end
	end

	-- Hide the plain R6 parts the shells replace.
	for boneName in covered do
		local bone = rig:FindFirstChild(boneName) :: BasePart
		bone.Transparency = 1
		for _, child in bone:GetChildren() do
			if child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
	rig:SetAttribute("MorphInstalled", #installed)
	return installed
end

-- Studio command bar helper: installs ReplicatedStorage.StandMeshes.StarPlatinumMorph onto the
-- stored Star Platinum rigs (the cutscene's template and the Animation Editor rig).
function StandMorph.bake(): number
	local replicated = game:GetService("ReplicatedStorage")
	local meshes = replicated:FindFirstChild("StandMeshes")
	local imported = meshes and meshes:FindFirstChild("StarPlatinumMorph")
	assert(
		imported,
		"Import StarPlatinumMorph.fbx and put the model in ReplicatedStorage.StandMeshes first"
	)
	local count = 0
	local targets = {}
	local assets = replicated:FindFirstChild("StandAssets")
	if assets and assets:FindFirstChild("StarPlatinum") then
		table.insert(targets, assets:FindFirstChild("StarPlatinum"))
	end
	local rigs = workspace:FindFirstChild("AnimationRigs")
	if rigs and rigs:FindFirstChild("StarPlatinum") then
		table.insert(targets, rigs:FindFirstChild("StarPlatinum"))
	end
	for _, rig in targets do
		count += #StandMorph.install(rig :: Model, imported)
	end
	return count
end

return StandMorph
