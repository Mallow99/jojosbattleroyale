--!nocheck
-- Authors the cutscene's R6 KeyframeSequences. Poses are written in each parent part's axes
-- (see R6.compile), eased between keys, sampled at 60 fps and reduced to the keyframes needed
-- to reproduce the curves within 0.4 degrees using Roblox's Linear pose interpolation.
local roblox = require("@lune/roblox")
local R6 = require("./R6")
local Shared = require("./Shared")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Enum = roblox.Enum
local V = Vector3.new

local Track = Shared.module("Track")
local Awakening = Shared.module("Awakening")
local M = Awakening.marks

local Animations = {}
Animations.FPS = 60

-- Shoulder pivots (torso space) and a helper to point the right arm's hand end at a point
-- given in anchor space (user HumanoidRootPart at (0, 3, 0)).
-- R6 shoulders pivot at the torso edge; the hand end sits 0.5 further out and 1.5 down.
local RIGHT_SHOULDER = V(1, 3.5, 0)
local RIGHT_HAND_FROM_PIVOT = V(0.5, -1.5, 0)
local function aimRight(point)
	local d = point - RIGHT_SHOULDER
	local q = R6.aim(RIGHT_HAND_FROM_PIVOT, d)
	local rx, ry, rz = q:ToEulerAnglesXYZ()
	return { math.deg(rx), math.deg(ry), math.deg(rz) }
end

local DOCK = CFrame.new(0, 4.05, -1.18) -- disc centre in front of the throat, faces +X/-X
local SLIDE = 1.15
local SHOW_EYE = V(1.3, 5.0, -4.7) -- close-up camera; the disc turns its label towards it
local GRIP = CFrame.new(-0.56, -1.05, -0.15) -- disc centre relative to the Right Arm

Animations.userPoses = {
	idle = { ["Right Shoulder"] = { 0, 0, 4 }, ["Left Shoulder"] = { 0, 0, -4 } },
	present = {
		RootJoint = { 0, -6, 0 },
		Neck = { -14, -12, 0 },
		["Right Shoulder"] = { 104, 0, -18 },
		["Left Shoulder"] = { 8, 0, -6 },
		["Right Hip"] = { 0, 0, 3 },
		["Left Hip"] = { 0, 0, -3 },
	},
	admire = {
		RootJoint = { 3, -10, 0 },
		Neck = { -6, -16, 0 },
		["Right Shoulder"] = { 122, 0, -22 },
		["Left Shoulder"] = { 10, 0, -8 },
		["Right Hip"] = { 0, 0, 3 },
		["Left Hip"] = { 0, 0, -3 },
	},
	brace = {
		RootJoint = { 5, 0, 0 },
		Neck = { 16, 8, 4 },
		["Right Shoulder"] = aimRight(V(0.62, 4.12, -1.15)),
		["Left Shoulder"] = { 14, 0, -14 },
		["Right Hip"] = { 0, 0, 4 },
		["Left Hip"] = { 0, 0, -4 },
	},
	push = {
		RootJoint = { 7, 0, 0 },
		Neck = { 20, 8, 4 },
		["Right Shoulder"] = aimRight(V(0.6, 4.12, -0.75)),
		["Left Shoulder"] = { 18, 0, -18 },
		["Right Hip"] = { 0, 0, 4 },
		["Left Hip"] = { 0, 0, -4 },
	},
	jolt = {
		RootJoint = { 14, 0, 0 },
		Neck = { 34, 0, -10 },
		["Right Shoulder"] = { 22, 0, 52 },
		["Left Shoulder"] = { 22, 0, -52 },
		["Right Hip"] = { -6, 0, 6 },
		["Left Hip"] = { -6, 0, -6 },
	},
	power = {
		RootJoint = { -6, 0, 0, 0, -0.15, 0 },
		Neck = { -12, 0, 0 },
		["Right Shoulder"] = { 26, 0, 30 },
		["Left Shoulder"] = { 26, 0, -30 },
		["Right Hip"] = { 6, 0, 13 },
		["Left Hip"] = { 6, 0, -13 },
	},
	point = {
		RootJoint = { 0, 12, 0 },
		Neck = { -8, -16, 0 },
		["Right Shoulder"] = { 90, -8, -4 },
		["Left Shoulder"] = { 150, 0, 30 },
		["Right Hip"] = { 6, 0, 10 },
		["Left Hip"] = { -10, 0, -9 },
	},
}

Animations.standPoses = {
	emerge = {
		RootJoint = { -30, 0, 0, 0, -2.6, 0.4 },
		Neck = { -35, 0, 0 },
		["Right Shoulder"] = { 62, 0, -46 },
		["Left Shoulder"] = { 62, 0, 46 },
		["Right Hip"] = { 60, 0, 5 },
		["Left Hip"] = { 50, 0, -5 },
	},
	awaken = {
		RootJoint = { 10, 0, 0, 0, 0.9, 0 },
		Neck = { 18, 0, 0 },
		["Right Shoulder"] = { 35, 0, 80 },
		["Left Shoulder"] = { 35, 0, -80 },
		["Right Hip"] = { 8, 0, 14 },
		["Left Hip"] = { 8, 0, -14 },
	},
	guard = {
		RootJoint = { -8, 0, 0, 0, 0.9, 0 },
		Neck = { -8, 0, 0 },
		["Right Shoulder"] = { 62, 0, -16 },
		["Left Shoulder"] = { 62, 0, 16 },
		["Right Hip"] = { 20, 0, 8 },
		["Left Hip"] = { 5, 0, -8 },
	},
	point = {
		RootJoint = { -12, 16, 0, 0, 0.8, -0.4 },
		Neck = { -6, -20, 0 },
		["Right Shoulder"] = { 92, -12, -4 },
		["Left Shoulder"] = { 40, 0, -20 },
		["Right Hip"] = { 24, 0, 8 },
		["Left Hip"] = { -8, 0, -12 },
	},
}

local U, S = Animations.userPoses, Animations.standPoses
Animations.userKeys = {
	{ 0.0, U.idle },
	{ 0.4, U.idle },
	{ 1.4, U.present, "cubicInOut" },
	{ 2.3, U.present },
	{ 3.2, U.admire, "sineInOut" },
	{ M.Reach, U.admire },
	{ 4.5, U.brace, "cubicInOut" },
	{ M.SlideStart, U.brace },
	{ 5.25, U.push, "quadIn" },
	{ 5.5, U.jolt, "expoOut" },
	{ 6.3, U.jolt },
	{ 7.2, U.power, "cubicInOut" },
	{ 8.3, U.power },
	{ 9.0, U.point, "backOut" },
	{ M.Outro, U.point },
	{ 12.4, U.idle, "sineInOut" },
}
Animations.standKeys = {
	{ 0.0, S.emerge },
	{ M.StandStart, S.emerge },
	{ 6.9, S.awaken, "backOut" },
	{ 7.6, S.awaken },
	{ 8.3, S.guard, "cubicInOut" },
	{ 8.5, S.guard },
	{ 9.1, S.point, "backOut" },
	{ M.Outro, S.point },
	{ 12.4, S.guard, "sineInOut" },
}

local function compileKeys(keys)
	local compiled = {}
	for _, key in keys do
		table.insert(compiled, { key[1], R6.compile(key[2]), key[3] })
	end
	return compiled
end

local function poseAt(compiled, t)
	local a, b, alpha = Track.locate(compiled, t, 3)
	local pose = {}
	for joint in a[2] do
		pose[joint] = true
	end
	for joint in b[2] do
		pose[joint] = true
	end
	for joint in pose do
		local from = a[2][joint] or CFrame.new()
		local to = b[2][joint] or CFrame.new()
		pose[joint] = from:Lerp(to, alpha)
	end
	return pose
end

local function smoothstep(t, a, b)
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Disc world CFrame (anchor space) given the solved user parts.
function Animations.discWorld(t, parts)
	local arm = parts["Right Arm"]
	local position = (arm * GRIP).Position
	local carried = arm * GRIP
	local facing = CFrame.lookAt(position, SHOW_EYE) * CFrame.Angles(0, math.rad(90), 0)
	local show = smoothstep(t, 1.0, 2.0) * (1 - smoothstep(t, M.Reach, 4.3))
	local spin = CFrame.Angles(math.rad(170 * smoothstep(t, 2.0, M.Reach)), 0, 0)
	local held = carried:Lerp(facing, show) * spin
	local torso = parts.Torso
	local docked = torso * CFrame.new(0, -3, 0) * DOCK
	local slide = SLIDE
		* Track.EASES.quadIn(math.clamp((t - M.SlideStart) / (M.SlideEnd - M.SlideStart), 0, 1))
	docked = docked * CFrame.new(0, 0, slide)
	local dock = smoothstep(t, 4.25, M.Dock)
	return held:Lerp(docked, dock)
end

-- Joint transforms at time t for both actors (user includes the disc joint).
function Animations.sample(t)
	local userCompiled = Animations._user or compileKeys(Animations.userKeys)
	local standCompiled = Animations._stand or compileKeys(Animations.standKeys)
	Animations._user, Animations._stand = userCompiled, standCompiled
	local user = poseAt(userCompiled, t)
	local userParts = R6.solve(CFrame.new(0, 3, 0), user)
	user.DiscGrip =
		R6.transformFor("DiscGrip", userParts["Right Arm"], Animations.discWorld(t, userParts))
	local stand = poseAt(standCompiled, t)
	-- Hover: a slow bob layered on the stand's root translation.
	local bob = math.sin(t * math.pi * 2 * 0.6) * 0.12 * smoothstep(t, M.StandStart, M.StandFull)
	stand.RootJoint = R6.transformFromParentSpace(
		R6.jointByName("RootJoint"),
		CFrame.new(0, bob, 0)
	) * (stand.RootJoint or CFrame.new())
	return user, stand
end

local function angleBetween(a, b)
	local rel = a:Inverse() * b
	local axis, angle = rel:ToAxisAngle()
	local _ = axis
	return math.deg(math.abs(angle)) + rel.Position.Magnitude * 40
end

-- Keeps the samples needed so that linear interpolation stays within `tolerance`.
local function reduce(times, values, fixed, tolerance)
	local keep = {}
	for _, index in fixed do
		keep[index] = true
	end
	local function split(a, b)
		local worst, worstIndex = 0, nil
		for i = a + 1, b - 1 do
			local alpha = (times[i] - times[a]) / (times[b] - times[a])
			local err = angleBetween(values[a]:Lerp(values[b], alpha), values[i])
			if err > worst then
				worst, worstIndex = err, i
			end
		end
		if worstIndex and worst > tolerance then
			keep[worstIndex] = true
			split(a, worstIndex)
			split(worstIndex, b)
		end
	end
	local sorted = {}
	for index in keep do
		table.insert(sorted, index)
	end
	table.sort(sorted)
	for i = 1, #sorted - 1 do
		split(sorted[i], sorted[i + 1])
	end
	return keep
end

-- Builds a KeyframeSequence. `actor` is "user" or "stand".
function Animations.build(actor, name, duration, markers)
	local fps = Animations.FPS
	local count = math.floor(duration * fps + 0.5)
	local times, samples = {}, {}
	for i = 0, count do
		local t = i / fps
		local user, stand = Animations.sample(t)
		times[i + 1] = t
		samples[i + 1] = if actor == "user" then user else stand
	end
	local keyTimes = if actor == "user" then Animations.userKeys else Animations.standKeys
	local fixed = { 1, count + 1 }
	for _, key in keyTimes do
		table.insert(fixed, math.floor(key[1] * fps + 0.5) + 1)
	end
	local joints = if actor == "user" then R6.JOINTS_WITH_DISC else R6.JOINTS
	local union = {}
	for _, joint in joints do
		local series = {}
		for i, sample in samples do
			series[i] = sample[joint[1]] or CFrame.new()
		end
		for index in reduce(times, series, fixed, 0.4) do
			union[index] = true
		end
	end
	local indices = {}
	for index in union do
		table.insert(indices, index)
	end
	table.sort(indices)

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action4
	for _, index in indices do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = times[index]
		keyframe.Parent = sequence
		local poses = {}
		local root = Instance.new("Pose")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.new()
		root.Weight = 1
		root.Parent = keyframe
		poses.HumanoidRootPart = root
		for _, joint in joints do
			local pose = Instance.new("Pose")
			pose.Name = joint[3]
			pose.CFrame = samples[index][joint[1]] or CFrame.new()
			pose.Weight = 1
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.EasingDirection = Enum.PoseEasingDirection.In
			pose.Parent = poses[joint[2]]
			poses[joint[3]] = pose
		end
	end
	for markerName, time in markers or {} do
		local keyframe = Instance.new("Keyframe")
		keyframe.Name = markerName
		keyframe.Time = time
		local marker = Instance.new("KeyframeMarker")
		marker.Name = markerName
		marker.Value = ""
		marker.Parent = keyframe
		keyframe.Parent = sequence
	end
	return sequence, #indices
end

return Animations
