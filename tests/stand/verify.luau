--!nocheck
-- Structural and motion checks for the Star Platinum cutscene place (Lune, not a Roblox playtest).
-- Expects artifacts/stand/StandAwakeningDemo.rbxl from `rojo build stand.project.json`.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local R6 = require("../../tools/stand/R6")
local Animations = require("../../tools/stand/Animations")
local ImportSim = require("../../tools/stand/ImportSim")
local Shared = require("../../tools/stand/Shared")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Awakening = Shared.module("Awakening")
local StandMorph = Shared.module("StandMorph")
local Track = Shared.module("Track")

local passed = 0
local function check(condition, message)
	if not condition then
		error("FAIL: " .. message, 2)
	end
	passed += 1
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-4)
end
local function cfNear(a, b, tolerance)
	local ac, bc = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if not near(ac[i], bc[i], tolerance or 1e-4) then
			return false
		end
	end
	return true
end

local place = roblox.deserializePlace(fs.readFile("artifacts/stand/StandAwakeningDemo.rbxl"))
local replicated = place:GetService("ReplicatedStorage")
local serverStorage = place:GetService("ServerStorage")

-- Scripts ----------------------------------------------------------------------------
for _, name in { "Awakening", "Config", "Cutscene", "Effects", "StandDisc", "StandMorph", "Track" } do
	local module = replicated.StandCutscene:FindFirstChild(name)
	check(module and module.ClassName == "ModuleScript", name .. " is a ModuleScript")
	check(
		module.Source == fs.readFile("src/ReplicatedStorage/StandCutscene/" .. name .. ".luau"),
		name .. " source matches"
	)
end
check(place:GetService("ServerScriptService").StandDemo.ClassName == "Script", "server script")
check(
	place:GetService("StarterPlayer").StarterPlayerScripts.StandCutsceneClient.ClassName
		== "LocalScript",
	"client script"
)
check(
	place:GetService("StarterPlayer").GameSettingsAvatar == roblox.Enum.GameAvatarType.R6,
	"demo place spawns R6 avatars"
)
check(replicated.StandMeshes.ClassName == "Folder", "StandMeshes folder for the imported morph")

-- R6 rigs ----------------------------------------------------------------------------
local R6_PARTS =
	{ "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local function checkRig(rig, label)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	check(
		humanoid and humanoid.RigType == roblox.Enum.HumanoidRigType.R6,
		label .. " Humanoid is R6"
	)
	check(humanoid:FindFirstChildOfClass("Animator"), label .. " has an Animator")
	check(rig.PrimaryPart == rig.HumanoidRootPart, label .. " PrimaryPart is the root")
	for _, name in R6_PARTS do
		check(rig:FindFirstChild(name) and rig[name]:IsA("BasePart"), label .. " has " .. name)
	end
	check(
		rig.Head:FindFirstChildOfClass("SpecialMesh").MeshType == roblox.Enum.MeshType.Head,
		label .. " classic head mesh"
	)
	local origin = rig.HumanoidRootPart.CFrame * CFrame.new(0, -3, 0)
	for _, joint in R6.JOINTS do
		local holder = if joint[1] == "RootJoint" then rig.HumanoidRootPart else rig.Torso
		local motor = holder:FindFirstChild(joint[1])
		check(
			motor and motor.ClassName == "Motor6D",
			label .. " " .. joint[1] .. " Motor6D in " .. holder.Name
		)
		check(
			motor.Part0 == rig[joint[2]] and motor.Part1 == rig[joint[3]],
			label .. " " .. joint[1] .. " parts"
		)
		check(
			cfNear(motor.C0, joint[4]) and cfNear(motor.C1, joint[5]),
			label .. " " .. joint[1] .. " standard C0/C1"
		)
		-- Rest pose consistency: Part1 = Part0 * C0 * C1^-1
		check(
			cfNear(rig[joint[3]].CFrame, rig[joint[2]].CFrame * motor.C0 * motor.C1:Inverse(), 1e-3),
			label .. " " .. joint[1] .. " rest pose"
		)
	end
	check(
		near((origin:Inverse() * rig["Left Leg"].CFrame).Position.Y, 1, 1e-3),
		label .. " stands on its origin"
	)
end
checkRig(replicated.StandAssets.StarPlatinum, "StarPlatinum")
checkRig(replicated.StandAssets.StandUser, "StandUser")
for _, name in { "StarPlatinum", "StandUser" } do
	local rig = place.Workspace.AnimationRigs[name]
	checkRig(rig, "Workspace " .. name)
	check(rig.HumanoidRootPart.Anchored, name .. " editor rig is anchored")
	check(
		rig.AnimSaves.ClassName == "ObjectValue"
			and rig.AnimSaves.Value == serverStorage.RBX_ANIMSAVES[name],
		name .. " AnimSaves links its saves"
	)
end

-- KeyframeSequences --------------------------------------------------------------------
local userSequence = serverStorage.RBX_ANIMSAVES.StandUser.UserDiscAwakening
local standSequence = serverStorage.RBX_ANIMSAVES.StarPlatinum.StarPlatinumAwakening
local function checkSequence(sequence, joints, label)
	check(
		sequence.ClassName == "KeyframeSequence" and sequence.Loop == false,
		label .. " is a non-looping KeyframeSequence"
	)
	check(sequence.Priority == roblox.Enum.AnimationPriority.Action4, label .. " plays at Action4")
	local parentOf = { HumanoidRootPart = "" }
	for _, joint in joints do
		parentOf[joint[3]] = joint[2]
	end
	local last, poseCount = 0, 0
	for _, keyframe in sequence:GetChildren() do
		check(keyframe.ClassName == "Keyframe", label .. " children are Keyframes")
		check(
			keyframe.Time >= 0 and keyframe.Time <= Awakening.duration + 1e-6,
			label .. " keyframe time in range"
		)
		last = math.max(last, keyframe.Time)
		for _, pose in keyframe:GetDescendants() do
			if pose.ClassName == "Pose" then
				poseCount += 1
				local expectedParent = parentOf[pose.Name]
				check(
					expectedParent ~= nil,
					label .. " pose " .. pose.Name .. " targets a rig part"
				)
				local parentName = if pose.Parent.ClassName == "Keyframe"
					then ""
					else pose.Parent.Name
				check(
					parentName == expectedParent,
					label .. " pose " .. pose.Name .. " is under " .. tostring(expectedParent)
				)
				check(
					pose.EasingStyle == roblox.Enum.PoseEasingStyle.Linear
						or pose.Name == "HumanoidRootPart",
					label .. " linear poses"
				)
			end
		end
	end
	check(near(last, Awakening.duration, 1 / 60 + 1e-6), label .. " lasts the full cutscene")
	check(poseCount > 100, label .. " has poses")
end
checkSequence(userSequence, R6.JOINTS_WITH_DISC, "UserDiscAwakening")
checkSequence(standSequence, R6.JOINTS, "StarPlatinumAwakening")
local markerNames = {}
for _, marker in userSequence:GetDescendants() do
	if marker.ClassName == "KeyframeMarker" then
		markerNames[marker.Name] = marker.Parent.Time
	end
end
for name, time in Awakening.marks do
	check(
		markerNames[name] and near(markerNames[name], time, 1e-6),
		"marker " .. name .. " at " .. time
	)
end

-- Motion: replay the saved sequences the way Animator interpolates Linear poses -----------
local userSampler = R6.sequenceSampler(userSequence, R6.JOINTS_WITH_DISC)
local standSampler = R6.sequenceSampler(standSequence, R6.JOINTS)
local anchor = CFrame.new()
local worstError, worstLegSink, closestStand, closestCamera = 0, 0, math.huge, math.huge
for i = 0, math.floor(Awakening.duration * 60) do
	local t = i / 60
	local saved = userSampler(t)
	local authored = Animations.sample(t)
	for jointName, value in authored do
		local rel = saved[jointName]:Inverse() * value
		local _, angle = rel:ToAxisAngle()
		worstError = math.max(worstError, math.deg(math.abs(angle)) + rel.Position.Magnitude * 40)
	end
	local user = R6.solve(anchor * CFrame.new(0, 3, 0), saved, R6.JOINTS_WITH_DISC)
	local stand = R6.solve(anchor * Awakening.standOffset, standSampler(t))
	for _, leg in { "Left Leg", "Right Leg" } do
		local lowest = math.huge
		for _, corner in
			{
				Vector3.new(0.5, -1, 0.5),
				Vector3.new(-0.5, -1, 0.5),
				Vector3.new(0.5, -1, -0.5),
				Vector3.new(-0.5, -1, -0.5),
			}
		do
			lowest = math.min(lowest, (user[leg] * corner).Y)
		end
		worstLegSink = math.max(worstLegSink, -lowest)
	end
	local standVisible = Track.number(Awakening.tracks.standVisibility, t) > 0.3
	if standVisible then
		closestStand =
			math.min(closestStand, (stand.Torso.Position - user.Torso.Position).Magnitude)
	end
	local camera = Track.cameraWorld(Awakening, t, anchor)
	for _, part in { user.Head, user.Torso } do
		closestCamera = math.min(closestCamera, (camera.Position - part.Position).Magnitude)
	end
	if standVisible then
		closestCamera = math.min(closestCamera, (camera.Position - stand.Head.Position).Magnitude)
	end
	-- Disc phases
	local disc = user.Disc
	local hand = user["Right Arm"] * Vector3.new(0, -1, 0)
	if t >= 0.8 and t <= 4.2 then
		check(
			(disc.Position - hand).Magnitude < 0.75,
			string.format("disc stays in the hand at %.2fs", t)
		)
	end
	local local_ = user.Torso:Inverse() * disc.Position
	if near(t, Awakening.marks.Dock, 1 / 120) then
		check(
			(local_ - Vector3.new(0, 1.05, -1.18)).Magnitude < 0.05,
			"disc docks in front of the throat"
		)
		check((hand - disc.Position).Magnitude < 0.9, "right hand is at the disc when it docks")
	end
	if t >= Awakening.marks.SlideEnd then
		check(
			math.abs(local_.X) < 0.3
				and math.abs(local_.Z) < 0.35
				and local_.Y > 0.8
				and local_.Y < 1.6,
			"disc ends inside the neck"
		)
	end
end
check(
	worstError < 0.6,
	string.format("saved keyframes reproduce the authored motion (worst %.2f°)", worstError)
)
check(
	worstLegSink < 0.35,
	string.format("feet stay on the ground (worst sink %.2f studs)", worstLegSink)
)
check(
	closestStand > 2.0,
	string.format("stand never overlaps the user (closest %.2f studs)", closestStand)
)
check(
	closestCamera > 1.3,
	string.format("camera never enters a character (closest %.2f studs)", closestCamera)
)

-- Morph installer --------------------------------------------------------------------
local report = ImportSim.report()
check(#report.pieces > 30, "morph has pieces")
for _, piece in report.pieces do
	check(piece.triangles <= 20000, piece.name .. " is under Roblox's 20k triangle limit")
	local parsed = StandMorph.parse(piece.name)
	check(
		parsed and (StandMorph.BONES[parsed.bone] or parsed.bone == "Marker"),
		piece.name .. " maps to an R6 part"
	)
	check(
		parsed.bone == "Marker" or StandMorph.PALETTE[parsed.colour],
		piece.name .. " has a known colour"
	)
end
check(StandMorph.parse("Head__Hair__hair.001").piece == "Hair", "parse tolerates importer suffixes")
local function installWith(importCFrame, scale)
	local rig = roblox.deserializeModel(fs.readFile("src/assets/StarPlatinum.rbxmx"))[1]
	local parts = StandMorph.install(rig, ImportSim.import(importCFrame, scale))
	local result = {}
	for _, part in parts do
		local bone = part.Parent.Parent
		result[bone.Name .. "/" .. part.Name] = { bone.CFrame:Inverse() * part.CFrame, part.Size }
	end
	return result, rig
end
local baseline, installedRig = installWith(CFrame.new(), 1)
local count = 0
for _ in baseline do
	count += 1
end
check(count == #report.pieces - 4, "every non-marker piece is installed")
check(
	installedRig.Torso.Transparency == 1 and installedRig.Head.Transparency == 1,
	"shelled R6 parts are hidden"
)
for _, variant in
	{
		{ CFrame.new(40, -3, 12) * CFrame.Angles(math.rad(-90), 0, 0), 0.28 },
		{ CFrame.new(-5, 0, 0) * CFrame.Angles(0, math.rad(180), 0), 1 },
		{ CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 1.1, -0.4), 3.571 },
	}
do
	local other = installWith(variant[1], variant[2])
	for key, value in baseline do
		check(
			other[key] and cfNear(other[key][1], value[1], 2e-3),
			"install is independent of import transform: " .. key
		)
		check((other[key][2] - value[2]).Magnitude < 2e-3, "install undoes import scale: " .. key)
	end
end
local mirrored = ImportSim.import(
	CFrame.fromMatrix(
		Vector3.new(),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(0, 0, 1)
	),
	1
)
check(
	not pcall(
		StandMorph.install,
		roblox.deserializeModel(fs.readFile("src/assets/StarPlatinum.rbxmx"))[1],
		mirrored
	),
	"mirrored import is rejected"
)

print(
	string.format(
		"PASS: %d stand cutscene assertions (Lune structural/motion checks, not a Roblox playtest)",
		passed
	)
)
