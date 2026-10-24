--!nocheck
-- Loads the game's shared ModuleScripts in Lune with Roblox datatypes as globals and a
-- `script.Parent.X` require shim, so tests run the exact source shipped to Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Shared = {}
local cache = {}

local function fakeScript(directory, name)
	local folder = setmetatable({ __directory = directory }, {
		__index = function(self, child)
			return { __path = self.__directory .. "/" .. child .. ".luau", Name = child }
		end,
	})
	return { Parent = folder, Name = name }
end

local environmentBase = {
	CFrame = roblox.CFrame,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Instance = roblox.Instance,
	UDim = roblox.UDim,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
}

function Shared.load(path)
	if cache[path] then
		return cache[path]
	end
	local directory, name = string.match(path, "^(.*)/([^/]+)%.luau$")
	-- Lune copies only raw fields of the environment table, so copy the datatypes in.
	local environment = {}
	for key, value in environmentBase do
		environment[key] = value
	end
	environment.script = fakeScript(directory, name)
	environment.require = function(target)
		return Shared.load(target.__path)
	end
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = environment })
	local result = chunk()
	cache[path] = result
	return result
end

function Shared.module(name)
	return Shared.load("src/ReplicatedStorage/StandCutscene/" .. name .. ".luau")
end

return Shared
