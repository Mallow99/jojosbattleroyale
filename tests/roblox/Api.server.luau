--!strict
-- Static API fixture only. Never executed in Roblox during cloud preparation.
local part: BasePart = Instance.new("Part")
part.Anchored = true
part.Size = Vector3.new(4, 1, 4)
part.Parent = workspace
game:GetService("CollectionService"):AddTag(part, "ToolchainFixture")
