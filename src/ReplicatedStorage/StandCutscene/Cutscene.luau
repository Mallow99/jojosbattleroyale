--!strict
-- Plays the Star Platinum awakening cutscene for the local player (client only).
--
-- Body motion comes from two standard R6 animations played through Animator:
--   user  : UserDiscAwakening (includes the "Disc" prop joint on the right arm)
--   stand : StarPlatinumAwakening (on a clone of ReplicatedStorage.StandAssets.StarPlatinum)
-- Camera, visibility and screen effects come from the Awakening shot data.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Awakening = require(script.Parent.Awakening)
local Config = require(script.Parent.Config)
local Effects = require(script.Parent.Effects)
local StandDisc = require(script.Parent.StandDisc)
local StandMorph = require(script.Parent.StandMorph)
local Track = require(script.Parent.Track)

local Cutscene = {}

local RENDER_STEP = "StandCutscene"
local playing = false

local function animationFor(configuredId: string, sequenceName: string): Animation?
	local animation = Instance.new("Animation")
	if configuredId ~= "" then
		animation.AnimationId = configuredId
		return animation
	end
	local folder = ReplicatedStorage:FindFirstChild("StandAnimations")
	local sequence = folder and folder:FindFirstChild(sequenceName)
	if sequence and sequence:IsA("KeyframeSequence") and RunService:IsStudio() then
		-- Temporary ID; works in Studio playtests only.
		animation.AnimationId = KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		return animation
	end
	warn(
		"[StandCutscene] No animation for "
			.. sequenceName
			.. ". Publish it and set its ID in StandCutscene.Config (live games cannot use unpublished animations)."
	)
	return nil
end

local function animatorOf(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local controller = humanoid or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end
	local existing = controller:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	local animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

local function isR6(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and humanoid.RigType == Enum.HumanoidRigType.R6
		and character:FindFirstChild("Right Arm") ~= nil
		and character:FindFirstChild("Torso") ~= nil
end

local function setModelHidden(model: Model, hidden: boolean)
	local value = if hidden then 1 else 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			(item :: any).LocalTransparencyModifier = value
		end
	end
end

-- Plays the cutscene and yields until it ends. Returns false if it could not start.
-- `startAnchor` (ground point, facing forward) defaults to where the character stands.
function Cutscene.play(startAnchor: CFrame?): boolean
	if playing then
		return false
	end
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and root and root:IsA("BasePart") and humanoid) then
		return false
	end
	local assets = ReplicatedStorage:WaitForChild("StandAssets")
	playing = true

	local cleanup: { () -> () } = {}
	local function onCleanup(fn: () -> ())
		table.insert(cleanup, fn)
	end

	-- Anchor point: the user's ground position and facing at the start.
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local ground = root.Position - Vector3.new(0, 3, 0)
	local anchor = startAnchor or CFrame.lookAt(ground, ground + flat.Unit)

	-- The actor: the player's own R6 character, or the fallback R6 rig in its place.
	local actor: Model = character
	if not isR6(character) then
		local fallback = (assets:WaitForChild("StandUser") :: Model):Clone()
		fallback:PivotTo(anchor * CFrame.new(0, 3, 0))
		fallback.Parent = workspace
		setModelHidden(character, true)
		actor = fallback
		onCleanup(function()
			fallback:Destroy()
			setModelHidden(character, false)
		end)
	end
	local actorRoot = actor:FindFirstChild("HumanoidRootPart") :: BasePart
	local wasAnchored = actorRoot.Anchored
	actorRoot.Anchored = true
	actorRoot.CFrame = anchor * CFrame.new(0, 3, 0)
	onCleanup(function()
		if actorRoot.Parent then
			actorRoot.Anchored = wasAnchored
		end
	end)

	-- Freeze controls and hide the default UI.
	local controls: any = nil
	pcall(function()
		local playerModule =
			require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any) :: any
		controls = playerModule:GetControls()
		controls:Disable()
	end)
	onCleanup(function()
		if controls then
			controls:Enable()
		end
	end)
	local coreTypes = {
		Enum.CoreGuiType.PlayerList,
		Enum.CoreGuiType.Chat,
		Enum.CoreGuiType.Backpack,
		Enum.CoreGuiType.Health,
	}
	local coreState = {}
	for _, coreType in coreTypes do
		coreState[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end
	onCleanup(function()
		for coreType, enabled in coreState do
			StarterGui:SetCoreGuiEnabled(coreType, enabled)
		end
	end)

	-- Disc prop on the right arm, driven by the animation's "Disc" pose.
	local rightArm = actor:FindFirstChild("Right Arm") :: BasePart
	local disc = StandDisc.build()
	disc.CFrame = rightArm.CFrame * CFrame.new(0, -1, 0)
	disc.Parent = actor
	local grip = Instance.new("Motor6D")
	grip.Name = "DiscGrip"
	grip.Part0 = rightArm
	grip.Part1 = disc
	grip.C0 = CFrame.new(0, -1, 0)
	grip.Parent = rightArm
	StandDisc.setVisibility(disc, 0)
	onCleanup(function()
		grip:Destroy()
		disc:Destroy()
	end)

	-- The stand: clone the R6 template, add the imported morph if it is not baked in yet.
	local stand = (assets:WaitForChild("StarPlatinum") :: Model):Clone()
	local meshes = ReplicatedStorage:FindFirstChild("StandMeshes")
	local morph = meshes and meshes:FindFirstChild("StarPlatinumMorph")
	if morph and not stand:GetAttribute("MorphInstalled") then
		local ok, err = pcall(StandMorph.install, stand, morph)
		if not ok then
			warn("[StandCutscene] Morph install failed: " .. tostring(err))
		end
	end
	stand:PivotTo(anchor * Awakening.standOffset)
	local standHumanoid = stand:FindFirstChildOfClass("Humanoid")
	if standHumanoid then
		standHumanoid.EvaluateStateMachine = false
	end
	setModelHidden(stand, true)
	stand.Parent = workspace
	onCleanup(function()
		stand:Destroy()
	end)

	local effects = Effects.new(player:WaitForChild("PlayerGui") :: PlayerGui, Awakening)
	effects:addAura(
		"user",
		actor:FindFirstChild("Torso") :: BasePart,
		Color3.fromRGB(190, 130, 255),
		45,
		0.6
	)
	effects:addAura(
		"stand",
		stand:FindFirstChild("Torso") :: BasePart,
		Color3.fromRGB(140, 115, 255),
		35,
		0.8
	)
	effects:addGlow(stand)
	onCleanup(function()
		effects:destroy()
	end)

	-- Animations
	local tracks: { AnimationTrack } = {}
	local userAnimation = animationFor(Config.UserAnimationId, "UserDiscAwakening")
	local standAnimation = animationFor(Config.StandAnimationId, "StarPlatinumAwakening")
	local actorAnimator = animatorOf(actor)
	local standAnimator = animatorOf(stand)
	if actorAnimator then
		for _, other in actorAnimator:GetPlayingAnimationTracks() do
			other:Stop(0.2)
		end
	end
	if userAnimation and actorAnimator then
		table.insert(tracks, actorAnimator:LoadAnimation(userAnimation))
	end
	if standAnimation and standAnimator then
		table.insert(tracks, standAnimator:LoadAnimation(standAnimation))
	end
	for _, track in tracks do
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		track:Play(0.15, 1, 1)
	end
	onCleanup(function()
		for _, track in tracks do
			track:Stop(0.3)
		end
	end)

	-- Camera
	local camera = workspace.CurrentCamera
	local returnCamera = camera.CFrame
	local returnFov = camera.FieldOfView
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	onCleanup(function()
		camera.FieldOfView = returnFov
		camera.CameraType = previousType
		local subject = character:FindFirstChildOfClass("Humanoid")
		if subject then
			camera.CameraSubject = subject
		end
	end)

	local tracksData = Awakening.tracks
	local start = os.clock()
	local finished = Instance.new("BindableEvent")
	local function step()
		local t = os.clock() - start
		if t >= Awakening.duration or not character.Parent then
			finished:Fire()
			return
		end
		local cameraCFrame, fov = Track.cameraWorld(Awakening, t, anchor, returnCamera, returnFov)
		camera.CFrame = cameraCFrame
		camera.FieldOfView = fov

		local standVisibility = Track.number(tracksData.standVisibility, t)
		for _, item in stand:GetDescendants() do
			if (item:IsA("BasePart") or item:IsA("Decal")) and item.Name ~= "HumanoidRootPart" then
				(item :: any).LocalTransparencyModifier = 1 - standVisibility
			end
		end
		StandDisc.setVisibility(disc, Track.number(tracksData.discVisibility, t))
		effects:setAura("user", t >= Awakening.aura.start and t <= Awakening.aura.stop)
		effects:setAura(
			"stand",
			t >= Awakening.standAura.start
				and t <= Awakening.standAura.stop
				and standVisibility > 0.2
		)
		for index, ring in Awakening.rings do
			local age = (t - ring.start) / ring.life
			if age >= 0 and age <= 1 then
				local center
				if ring.at == "neck" then
					local torso = actor:FindFirstChild("Torso") :: BasePart
					center = CFrame.new((torso.CFrame * CFrame.new(0, 1, 0)).Position)
						* anchor.Rotation
				else
					local standRoot = (anchor * Awakening.standOffset).Position
					center = CFrame.new(standRoot.X, anchor.Position.Y + 0.15, standRoot.Z)
						* anchor.Rotation
				end
				local radius = ring.from + (ring.to - ring.from) * Track.EASES.cubicOut(age)
				effects:setRing(index, center, radius, 1 - age * age)
			else
				effects:setRing(index, nil, 0, 0)
			end
		end
		effects:update({
			t = t,
			letterbox = Track.number(tracksData.letterbox, t),
			flash = Track.number(tracksData.flash, t),
			tint = Track.number(tracksData.tint, t),
			menacing = Track.number(tracksData.menacing, t),
			title = Track.number(tracksData.title, t),
			glow = Track.number(tracksData.standGlow, t),
			visibility = standVisibility,
		})
	end
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, step)
	onCleanup(function()
		RunService:UnbindFromRenderStep(RENDER_STEP)
	end)

	finished.Event:Wait()
	finished:Destroy()
	for index = #cleanup, 1, -1 do
		local ok, err = pcall(cleanup[index] :: any)
		if not ok then
			warn("[StandCutscene] cleanup step failed: " .. tostring(err))
		end
	end
	playing = false
	return true
end

function Cutscene.isPlaying(): boolean
	return playing
end

return Cutscene
