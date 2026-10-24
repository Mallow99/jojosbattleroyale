--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local config = require("./Config")

assert(config.targetPlayers == 32 and config.marker == "toolchain-fixture", "config must load")
for _, name in { "lobby", "match" } do
	local place = roblox.deserializePlace(fs.readFile("artifacts/code/" .. name .. ".rbxl"))
	assert(place.ReplicatedStorage.Shared.Config.ClassName == "ModuleScript", "shared module class")
	assert(
		place.ReplicatedStorage.Shared.Config.Source == fs.readFile("tests/tooling/Config.luau"),
		"shared source"
	)
	assert(place.ServerScriptService.Main.ClassName == "Script", "server script class")
	assert(
		place.ServerScriptService.Main.Source == fs.readFile("tests/tooling/Main.server.luau"),
		"server source"
	)
	assert(
		place.StarterPlayer.StarterPlayerScripts.Main.ClassName == "LocalScript",
		"client script class"
	)
	assert(
		place.StarterPlayer.StarterPlayerScripts.Main.Source
			== fs.readFile("tests/tooling/Main.client.luau"),
		"client source"
	)
	assert(place.Workspace.StreamingEnabled == true, "streaming enabled")
	assert(place.Workspace.Floor.Anchored == true, "floor anchored")
	assert(place.Workspace.Floor.Size.X == 128, "floor size")
end
print("PASS: 19 Luau and place serialization assertions (not Roblox engine tests)")
