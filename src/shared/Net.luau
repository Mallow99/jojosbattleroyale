--!strict
-- Remote lookup. The server creates remotes on first use; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string, className: string): Instance
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	if RunService:IsServer() then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return get(name, "RemoteEvent") :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return get(name, "RemoteFunction") :: RemoteFunction
end

return Net
