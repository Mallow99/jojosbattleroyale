--!strict
-- Demo place client: plays the cutscene when the server says so and spins the display disc.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

ReplicatedStorage:WaitForChild("StandCutscene"):WaitForChild("Cutscene")
local Cutscene = require(ReplicatedStorage.StandCutscene.Cutscene)
local remote = ReplicatedStorage:WaitForChild("StandCutsceneEvent") :: RemoteEvent

remote.OnClientEvent:Connect(function(anchor: CFrame)
	Cutscene.play(anchor)
end)

local stage = workspace:WaitForChild("StandStage")
local spot = stage:WaitForChild("DiscSpot") :: BasePart
RunService.RenderStepped:Connect(function()
	local display = stage:FindFirstChild("DisplayDisc")
	if display and display:IsA("BasePart") then
		local t = os.clock()
		display.CFrame = spot.CFrame
			* CFrame.new(0, math.sin(t * 2) * 0.15, 0)
			* CFrame.Angles(0, t * 1.5, 0)
	end
end)
