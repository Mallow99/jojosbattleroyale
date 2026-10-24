--!nocheck
-- R6 forward kinematics and pose helpers for authoring/previewing KeyframeSequences in Lune.
-- Motor6D rule (as in Roblox): Part1 = Part0 * C0 * Transform * C1:Inverse().
local roblox = require("@lune/roblox")
local Builder = require("./Builder")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local R6 = {}

-- Prop joint added to the user's character during the cutscene.
R6.DISC_GRIP = { "DiscGrip", "Right Arm", "Disc", CFrame.new(0, -1, 0), CFrame.new() }

R6.JOINTS = table.clone(Builder.R6_JOINTS)
R6.JOINTS_WITH_DISC = table.clone(Builder.R6_JOINTS)
table.insert(R6.JOINTS_WITH_DISC, R6.DISC_GRIP)

local function rotationOf(cf)
	return cf - cf.Position
end

-- Converts a rotation/translation expressed in the parent part's axes at the joint pivot
-- into the Motor6D Transform (R6 joint frames are rotated relative to their parts).
function R6.transformFromParentSpace(joint, q)
	local r0 = rotationOf(joint[4])
	return r0:Inverse() * q * r0
end

function R6.jointByName(name, joints)
	for _, joint in joints or R6.JOINTS_WITH_DISC do
		if joint[1] == name then
			return joint
		end
	end
	error("unknown joint " .. name)
end

-- Parent-space degrees { rx, ry, rz, px?, py?, pz? } -> Transform per joint.
function R6.compile(spec)
	local pose = {}
	for jointName, v in spec do
		local q = CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0)
			* CFrame.Angles(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
		pose[jointName] = R6.transformFromParentSpace(R6.jointByName(jointName), q)
	end
	return pose
end

-- World CFrames of every part given the root CFrame and joint Transforms.
function R6.solve(rootCFrame, transforms, joints)
	local parts = { HumanoidRootPart = rootCFrame }
	for _, joint in joints or R6.JOINTS do
		local parent = parts[joint[2]]
		if parent then
			local transform = transforms[joint[1]] or CFrame.new()
			parts[joint[3]] = parent * joint[4] * transform * joint[5]:Inverse()
		end
	end
	return parts
end

-- Transform for joint `name` that puts its Part1 at `world`, given the solved parent.
function R6.transformFor(name, parentWorld, world)
	local joint = R6.jointByName(name)
	return (parentWorld * joint[4]):Inverse() * world * joint[5]
end

-- Parent-space rotation (shortest arc) turning the rest vector `from` (pivot to limb end,
-- in the parent part's axes) towards `direction`.
function R6.aim(from, direction)
	from = from.Unit
	local to = direction.Unit
	local axis = from:Cross(to)
	local angle = math.acos(math.clamp(from:Dot(to), -1, 1))
	if axis.Magnitude < 1e-6 then
		return CFrame.new()
	end
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

-- Samples a KeyframeSequence instance the way Roblox's Animator does with Linear poses:
-- per joint, interpolate between the keyframes that contain a Pose for that part.
function R6.sequenceSampler(sequence, joints)
	local tracks = {}
	local partToJoint = {}
	for _, joint in joints do
		partToJoint[joint[3]] = joint[1]
	end
	for _, keyframe in sequence:GetChildren() do
		if keyframe:IsA("Keyframe") then
			for _, pose in keyframe:GetDescendants() do
				if pose:IsA("Pose") and partToJoint[pose.Name] then
					local list = tracks[partToJoint[pose.Name]] or {}
					table.insert(list, { keyframe.Time, pose.CFrame })
					tracks[partToJoint[pose.Name]] = list
				end
			end
		end
	end
	for _, list in tracks do
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
	end
	return function(t)
		local transforms = {}
		for jointName, list in tracks do
			local value = list[#list][2]
			if t <= list[1][1] then
				value = list[1][2]
			else
				for i = 2, #list do
					if t <= list[i][1] then
						local a, b = list[i - 1], list[i]
						value = a[2]:Lerp(b[2], (t - a[1]) / (b[1] - a[1]))
						break
					end
				end
			end
			transforms[jointName] = value
		end
		return transforms
	end
end

return R6
