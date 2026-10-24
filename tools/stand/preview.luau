--!nocheck
-- Builds a preview scene from the generated Roblox files: the R6 rigs, the morph installed by
-- the shipped StandMorph module onto a simulated import, both KeyframeSequences sampled the
-- way Roblox interpolates them, and the shipped camera/effect tracks.
-- Usage: lune run tools/stand/preview.luau <cutscene|turnaround> <out.json> [fps]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Export = require("./Export")
local ImportSim = require("./ImportSim")
local R6 = require("./R6")
local Shared = require("./Shared")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Track = Shared.module("Track")
local Awakening = Shared.module("Awakening")
local StandMorph = Shared.module("StandMorph")

local mode = process.args[1] or "cutscene"
local outPath = process.args[2] or "artifacts/preview/cutscene.json"
local fps = tonumber(process.args[3]) or 30

local function load(path)
	return roblox.deserializeModel(fs.readFile(path))[1]
end

local REST = {
	HumanoidRootPart = CFrame.new(0, 3, 0),
	Torso = CFrame.new(0, 3, 0),
	Head = CFrame.new(0, 4.5, 0),
	["Left Arm"] = CFrame.new(-1.5, 3, 0),
	["Right Arm"] = CFrame.new(1.5, 3, 0),
	["Left Leg"] = CFrame.new(-0.5, 1, 0),
	["Right Leg"] = CFrame.new(0.5, 1, 0),
}

local stand = load("src/assets/StarPlatinum.rbxmx")
StandMorph.install(stand, ImportSim.import())
local user = load("src/assets/StandUser.rbxmx")
local disc = roblox.Instance.new("Model")
Shared.module("StandDisc").build().Parent = disc
local stage = load("src/workspace/DemoStage.rbxmx")

local parts = {}
local function add(list)
	for _, p in list do
		table.insert(parts, p)
	end
end
add(Export.modelParts("stand", stand, REST))
add(Export.modelParts("user", user, REST))
add(Export.modelParts("user", disc, { Disc = CFrame.new() }))

local frames = {}
local scene =
	{ parts = parts, frames = frames, glb = "StarPlatinumMorph.glb", menacing = Awakening.menacing }

if mode == "turnaround" then
	local floor = roblox.Instance.new("Model")
	local ground = roblox.Instance.new("Part")
	ground.Size = Vector3.new(80, 1, 80)
	ground.CFrame = CFrame.new(0, -0.5, 0)
	ground.Color = roblox.Color3.fromRGB(198, 182, 152)
	ground.Material = roblox.Enum.Material.Slate
	ground.Transparency = 0
	ground.Reflectance = 0
	ground.Parent = floor
	add(Export.staticParts("stage", floor))
	local standRest = R6.solve(CFrame.new(0, 3, 0), {})
	local views =
		{ { "front", 0 }, { "three-quarter", 35 }, { "side", 90 }, { "back", 180 }, { "face", 25 } }
	for _, view in views do
		local yaw = math.rad(view[2])
		local face = view[1] == "face"
		local distance = if face then 3.6 else 9.5
		local target = Vector3.new(0, if face then 4.6 else 3.1, 0)
		local eye = target
			+ Vector3.new(
				-math.sin(yaw) * distance,
				if face then 0.2 else 0.6,
				-math.cos(yaw) * distance
			)
		table.insert(frames, {
			t = 0,
			caption = "Star Platinum on the R6 rig — " .. view[1],
			actors = {
				stand = { bones = Export.bones(standRest), visibility = 1 },
				user = { bones = Export.bones(R6.solve(CFrame.new(0, -50, 0), {})), visibility = 0 },
			},
			camera = Export.cf(CFrame.lookAt(eye, target)),
			fov = 40,
			focus = { 0, 3, 0 },
		})
	end
else
	-- The demo stage places the user at the CutsceneMark, facing +Z.
	local mark = stage:FindFirstChild("CutsceneMark", true)
	local anchor = CFrame.new(mark.CFrame.Position.X, 0, mark.CFrame.Position.Z)
		* (mark.CFrame - mark.CFrame.Position)
	add(Export.staticParts("stage", stage))
	local userSampler = R6.sequenceSampler(
		load("src/animations/StandUser.rbxm").UserDiscAwakening,
		R6.JOINTS_WITH_DISC
	)
	local standSampler = R6.sequenceSampler(
		load("src/animations/StarPlatinum.rbxm").StarPlatinumAwakening,
		R6.JOINTS
	)
	local function rand(seed)
		local x = math.sin(seed * 12.9898) * 43758.5453
		return x - math.floor(x)
	end
	local function particles(t, window, origin, rate, color, spread, rise)
		local points = {}
		if t < window.start then
			return points
		end
		local first = math.max(0, math.floor((t - 1.1 - window.start) * rate))
		local last = math.floor((math.min(t, window.stop) - window.start) * rate)
		for i = first, last do
			local born = window.start + i / rate
			local age = t - born
			if age >= 0 and age <= 1.1 then
				local angle = rand(i * 3.1 + rate) * math.pi * 2
				local r = spread * (0.4 + rand(i * 7.7) * 0.8)
				local p = origin
					+ Vector3.new(
						math.cos(angle) * r * (1 + age),
						-1.2 + rand(i * 1.3) * 2 + rise * age,
						math.sin(angle) * r * (1 + age)
					)
				local fade = 1 - age / 1.1
				table.insert(
					points,
					{ p.X, p.Y, p.Z, color[1] * fade, color[2] * fade, color[3] * fade }
				)
			end
		end
		return points
	end
	local count = math.floor(Awakening.duration * fps)
	for i = 0, count do
		local t = i / fps
		local userParts =
			R6.solve(anchor * CFrame.new(0, 3, 0), userSampler(t), R6.JOINTS_WITH_DISC)
		local standRoot = anchor * Awakening.standOffset
		local standParts = R6.solve(standRoot, standSampler(t))
		local camera, fov = Track.cameraWorld(Awakening, t, anchor)
		local rings = {}
		for _, ring in Awakening.rings do
			local age = (t - ring.start) / ring.life
			if age >= 0 and age <= 1 then
				local at = if ring.at == "neck"
					then CFrame.new((userParts.Torso * CFrame.new(0, 1, 0)).Position)
					else CFrame.new(
						standRoot.Position.X,
						anchor.Position.Y + 0.15,
						standRoot.Position.Z
					)
				table.insert(rings, {
					cframe = Export.cf(at),
					radius = ring.from + (ring.to - ring.from) * Track.EASES.cubicOut(age),
					alpha = 1 - age * age,
					color = { ring.color.R, ring.color.G, ring.color.B },
				})
			end
		end
		local tracks = Awakening.tracks
		local discBones = { Disc = userParts.Disc }
		local actorsUser = Export.bones(userParts)
		actorsUser.Disc = nil
		table.insert(frames, {
			t = t,
			actors = {
				user = { bones = actorsUser, visibility = 1 },
				disc = {
					bones = Export.bones(discBones),
					visibility = Track.number(tracks.discVisibility, t),
				},
				stand = {
					bones = Export.bones(standParts),
					visibility = Track.number(tracks.standVisibility, t),
					glow = Track.number(tracks.standGlow, t),
				},
			},
			camera = Export.cf(camera),
			fov = fov,
			focus = { anchor.Position.X, 3, anchor.Position.Z },
			gui = {
				letterbox = Track.number(tracks.letterbox, t),
				flash = Track.number(tracks.flash, t),
				tint = Track.number(tracks.tint, t),
				menacing = Track.number(tracks.menacing, t),
				title = Track.number(tracks.title, t),
			},
			fx = {
				rings = rings,
				particles = {
					{
						points = particles(
							t,
							Awakening.aura,
							userParts.Torso.Position,
							45,
							{ 0.75, 0.5, 1 },
							1.0,
							2.5
						),
					},
					{
						points = particles(
							t,
							Awakening.standAura,
							standParts.Torso.Position,
							35,
							{ 0.55, 0.45, 1 },
							1.3,
							2.0
						),
					},
				},
			},
		})
	end
	-- Disc parts belong to the "disc" actor in cutscene mode.
	for _, p in parts do
		if p.bone == "Disc" then
			p.actor = "disc"
		end
	end
end

fs.writeDir(string.match(outPath, "^(.*)/") or ".")
fs.writeFile(outPath, serde.encode("json", scene))
print(string.format("Wrote %s (%d parts, %d frames)", outPath, #parts, #frames))
