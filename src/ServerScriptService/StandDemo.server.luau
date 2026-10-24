--!strict
-- Demo place server: a stand disc on the pedestal; using it plays the Star Platinum
-- awakening cutscene for that player. The server owns the decision and the stand state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Awakening = require(ReplicatedStorage.StandCutscene.Awakening)
local StandDisc = require(ReplicatedStorage.StandCutscene.StandDisc)

-- Clients can only register animations they can see: copy the saved KeyframeSequences
-- (where the Animation Editor keeps them) into ReplicatedStorage.
local animations = Instance.new("Folder")
animations.Name = "StandAnimations"
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
for _, entry in
	{ { "StandUser", "UserDiscAwakening" }, { "StarPlatinum", "StarPlatinumAwakening" } }
do
	local container = saves and saves:FindFirstChild(entry[1])
	local sequence = container and container:FindFirstChild(entry[2])
	if sequence then
		sequence:Clone().Parent = animations
	else
		warn("[StandDemo] Missing ServerStorage.RBX_ANIMSAVES." .. entry[1] .. "." .. entry[2])
	end
end
animations.Parent = ReplicatedStorage

local remote = Instance.new("RemoteEvent")
remote.Name = "StandCutsceneEvent"
remote.Parent = ReplicatedStorage

local stage = workspace:WaitForChild("StandStage")
local spot = stage:WaitForChild("DiscSpot") :: BasePart
local mark = stage:WaitForChild("CutsceneMark") :: BasePart

local display = StandDisc.build()
display.Name = "DisplayDisc"
display.Anchored = true
display.CFrame = spot.CFrame
display.Parent = stage

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Use Stand Disc"
prompt.ObjectText = "Star Platinum"
prompt.HoldDuration = 0.4
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = display

local busy: { [Player]: boolean } = {}

prompt.Triggered:Connect(function(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if busy[player] or not (root and root:IsA("BasePart")) then
		return
	end
	busy[player] = true
	local look = mark.CFrame.LookVector
	local ground = mark.Position - Vector3.new(0, mark.Size.Y / 2, 0)
	local anchor = CFrame.lookAt(ground, ground + Vector3.new(look.X, 0, look.Z))
	root.CFrame = anchor * CFrame.new(0, 3, 0)
	root.Anchored = true
	player:SetAttribute("Stand", "StarPlatinum")
	remote:FireClient(player, anchor)
	task.delay(Awakening.duration + 0.25, function()
		if root.Parent then
			root.Anchored = false
		end
		busy[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
