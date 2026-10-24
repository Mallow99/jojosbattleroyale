--!strict
-- Timing, camera shots and effects for the Star Platinum awakening cutscene.
-- Body motion lives in the two KeyframeSequences (UserDiscAwakening, StarPlatinumAwakening);
-- this module only holds what an animation cannot: camera, screen effects and visibility.
--
-- "Anchor space": the user's ground point when the cutscene starts, facing -Z, +X to the
-- user's right. The user's HumanoidRootPart is 3 studs above the anchor (standard R6).

local Awakening = {}

Awakening.duration = 12.6
Awakening.standName = "STAR PLATINUM"

-- Event times (seconds). The user animation carries KeyframeMarkers with the same names.
Awakening.marks = {
	DiscOut = 0.45,
	CloseUp = 2.0,
	Reach = 3.9,
	Dock = 4.55,
	SlideStart = 4.7,
	SlideEnd = 5.3,
	Impact = 5.4,
	StandStart = 5.9,
	StandFull = 7.0,
	Pose = 8.2,
	Outro = 11.6,
}
local M = Awakening.marks

-- Where the stand's HumanoidRootPart stands relative to the anchor. The stand's animation
-- raises its torso off this point (RootJoint translation), so it hovers.
Awakening.standOffset = CFrame.new(2.3, 3.6, 2.6)

-- { time, value, ease? } tracks; ease names are listed in Track.EASES.
type Keys = { { any } }
local tracks: { [string]: Keys } = {
	discVisibility = {
		{ 0.0, 0 },
		{ M.DiscOut, 0 },
		{ 0.75, 1, "quadOut" },
		{ 5.15, 1 },
		{ M.SlideEnd, 0, "linear" },
	},
	standVisibility = {
		{ 0.0, 0 },
		{ M.StandStart, 0 },
		{ M.StandFull, 1, "quadOut" },
		{ M.Outro, 1 },
		{ 12.3, 0, "quadIn" },
	},
	standGlow = {
		{ 0.0, 1 },
		{ M.StandFull, 1 },
		{ 7.6, 0, "quadOut" },
		{ M.Outro, 0 },
		{ 12.3, 0.8, "quadIn" },
	},
	letterbox = { { 0.0, 0 }, { 0.6, 1, "cubicOut" }, { 11.8, 1 }, { 12.5, 0, "sineInOut" } },
	flash = {
		{ 0.0, 0 },
		{ 5.38, 0 },
		{ 5.42, 1, "linear" },
		{ 5.8, 0, "quadOut" },
		{ 6.9, 0 },
		{ 6.95, 0.55, "linear" },
		{ 7.4, 0, "quadOut" },
	},
	tint = { { 0.0, 0 }, { M.Impact, 0 }, { 5.6, 1, "quadOut" }, { M.Outro, 1 }, { 12.4, 0 } },
	menacing = { { 0.0, 0 }, { 6.4, 0 }, { 7.0, 1, "quadOut" }, { 11.5, 1 }, { 12.1, 0 } },
	title = { { 0.0, 0 }, { 8.9, 0 }, { 9.35, 1, "cubicOut" }, { 11.4, 1 }, { 11.9, 0, "quadIn" } },
	shake = {
		{ 0.0, 0 },
		{ M.Impact, 0 },
		{ 5.45, 0.35, "linear" },
		{ 6.0, 0, "quadOut" },
		{ 6.85, 0, "linear" },
		{ 6.95, 0.22, "linear" },
		{ 7.6, 0, "quadOut" },
	},
}
Awakening.tracks = tracks

-- Camera keys in anchor space: { time, eye, target, fov, ease }. "step" makes a cut.
local V = Vector3.new
local camera: Keys = {
	{ 0.0, V(-3.6, 4.4, -7.4), V(0.2, 3.6, 0), 50 },
	{ 1.95, V(-2.6, 4.2, -5.5), V(0.3, 3.9, 0), 46, "sineOut" },
	{ 2.0, V(1.4, 5.0, -5.0), V(0.3, 4.3, -1.2), 38, "step" },
	{ 3.85, V(1.1, 4.9, -4.3), V(0.3, 4.3, -1.2), 35, "sineInOut" },
	{ 3.9, V(-3.6, 4.5, -2.6), V(0.0, 4.0, -0.9), 44, "step" },
	{ 5.35, V(-2.8, 4.3, -2.0), V(0.0, 4.0, -0.7), 40, "sineInOut" },
	{ 5.6, V(-3.6, 4.3, -3.3), V(0.0, 4.0, -0.5), 52, "expoOut" },
	{ 5.9, V(5.6, 1.6, -8.6), V(0.8, 4.8, 1.4), 55, "step" },
	{ 8.15, V(6.9, 2.0, -10.6), V(0.9, 5.2, 1.6), 55, "sineOut" },
	{ 8.2, V(3.6, 1.5, -7.8), V(1.0, 5.0, 1.2), 55, "step" },
	{ 11.6, V(2.9, 2.0, -6.6), V(1.0, 5.2, 1.2), 51, "sineInOut" },
}
Awakening.camera = camera
-- After Outro the camera eases back to the player's own camera.
Awakening.cameraReturn = { from = M.Outro, to = 12.6 }

-- Screen positions (scale) for the menacing "ゴ" glyphs: x, y, size, rotation.
Awakening.menacing = {
	{ 0.78, 0.17, 1.2, -12 },
	{ 0.87, 0.32, 0.9, 8 },
	{ 0.73, 0.44, 0.75, -6 },
	{ 0.12, 0.21, 0.85, 10 },
	{ 0.19, 0.39, 0.65, -10 },
}

Awakening.rings = {
	{
		start = M.Impact,
		life = 0.6,
		at = "neck",
		from = 0.4,
		to = 5,
		color = Color3.fromRGB(205, 165, 255),
	},
	{
		start = 6.9,
		life = 0.8,
		at = "stand",
		from = 1.5,
		to = 11,
		color = Color3.fromRGB(150, 110, 255),
	},
}

Awakening.aura = { start = M.Impact, stop = M.Outro + 0.4 }
Awakening.standAura = { start = M.StandStart, stop = M.Outro + 0.4 }

return Awakening
