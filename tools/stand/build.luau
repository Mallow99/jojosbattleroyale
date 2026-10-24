--!nocheck
-- Generates the cutscene's Roblox instances as .rbxmx files under src/.
-- Run from the repository root: .tools/bin/lune run tools/stand/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local B = require("./Builder")
local Animations = require("./Animations")
local Shared = require("./Shared")

local Awakening = Shared.module("Awakening")
local rgb = B.rgb

local function write(path, instance)
	fs.writeFile(path, roblox.serializeModel({ instance }, true))
end

local function count(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

fs.writeDir("src/assets")
fs.writeDir("src/animations")
fs.writeDir("src/workspace")

-- Star Platinum: a plain R6 rig in Star Platinum's colours. The imported mesh morph supplies
-- the face, hair, armour and body art (see StandMorph).
local skin = rgb(116, 96, 192)
local function starPlatinum()
	local model =
		B.r6("StarPlatinum", { head = skin, torso = skin, arms = skin, legs = rgb(40, 36, 88) })
	model:SetAttribute("Stand", "StarPlatinum")
	return model
end

-- Fallback stand user (R6), also the Animation Editor rig for the user's animation.
local function standUser()
	local model = B.r6("StandUser", {
		head = rgb(234, 184, 146),
		torso = rgb(44, 48, 78),
		arms = rgb(44, 48, 78),
		legs = rgb(36, 38, 58),
	})
	local face = roblox.Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = roblox.Enum.NormalId.Front
	face.Parent = model.Head
	return model
end

local standModel = starPlatinum()
write("src/assets/StarPlatinum.rbxmx", standModel)
local userModel = standUser()
write("src/assets/StandUser.rbxmx", userModel)
write("src/workspace/DemoStage.rbxmx", require("./DemoStage")())

-- Animation Editor rigs in Workspace. Each rig's AnimSaves ObjectValue points at its saves
-- container in ServerStorage.RBX_ANIMSAVES (linked by Rojo through Rojo_Target/Rojo_Id).
local rigs = roblox.Instance.new("Folder")
rigs.Name = "AnimationRigs"
for _, entry in
	{
		{ starPlatinum(), roblox.CFrame.new(-24, 0, -18) },
		{ standUser(), roblox.CFrame.new(-30, 0, -18) },
	}
do
	local rig, place = entry[1], entry[2]
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = place * part.CFrame
		end
	end
	local link = roblox.Instance.new("ObjectValue")
	link.Name = "AnimSaves"
	link:SetAttribute("Rojo_Target_Value", "anim-saves-" .. string.lower(rig.Name))
	link.Parent = rig
	rig.Parent = rigs
end
write("src/workspace/AnimationRigs.rbxmx", rigs)

local function saves(rigName, sequence)
	local container = roblox.Instance.new("Model")
	container.Name = rigName
	container:SetAttribute("Rojo_Id", "anim-saves-" .. string.lower(rigName))
	sequence.Parent = container
	fs.writeFile(
		"src/animations/" .. rigName .. ".rbxm",
		roblox.serializeModel({ container }, false)
	)
end
local userSequence, userKeys =
	Animations.build("user", "UserDiscAwakening", Awakening.duration, table.clone(Awakening.marks))
saves("StandUser", userSequence)
local standSequence, standKeys =
	Animations.build("stand", "StarPlatinumAwakening", Awakening.duration)
saves("StarPlatinum", standSequence)

print(
	string.format(
		"StarPlatinum rig: %d parts; StandUser rig: %d parts",
		count(standModel),
		count(userModel)
	)
)
print(
	string.format(
		"UserDiscAwakening: %d keyframes; StarPlatinumAwakening: %d keyframes",
		userKeys,
		standKeys
	)
)
