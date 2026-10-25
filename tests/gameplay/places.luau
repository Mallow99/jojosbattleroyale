--!strict
-- Checks the built lobby and match places against the game config: every configured
-- Stand, skin, weapon, heal and map reference exists, and extracted assets carry no
-- scripts. Run after `rojo build` (tools/check.py does both). Not a Roblox engine test.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Stands = require("../../src/shared/Config/Stands")
local GachaConfig = require("../../src/shared/Config/Gacha")
local Items = require("../../src/shared/Config/Items")
local MatchConfig = require("../../src/shared/Config/Match")

local checks = 0
local function check(condition: any, message: string)
	checks += 1
	assert(condition, message)
end

local function load(name: string)
	return roblox.deserializePlace(fs.readFile("artifacts/game/" .. name .. ".rbxl"))
end

local function noScripts(root: any, label: string)
	for _, d in root:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), label .. " contains script " .. d:GetFullName())
	end
	check(true, label .. " has no scripts")
end

local lobby = load("lobby")
check(lobby.ServerScriptService.Lobby.ClassName == "Script", "lobby server script")
check(lobby.ServerScriptService.Lobby:FindFirstChild("QueueService"), "queue service")
check(lobby.ServerScriptService.Lobby:FindFirstChild("GachaService"), "gacha service")
check(
	lobby.StarterPlayer.StarterPlayerScripts.Lobby.ClassName == "LocalScript",
	"lobby client script"
)
check(
	lobby.ServerScriptService.ServerShared.PlayerData.ClassName == "ModuleScript",
	"player data module"
)
check(lobby.ReplicatedStorage.Shared.Logic.Gacha.ClassName == "ModuleScript", "shared gacha logic")
check(lobby.Workspace:FindFirstChildOfClass("SpawnLocation"), "lobby spawn")

local match = load("match")
check(match.ServerScriptService.Match.ClassName == "Script", "match server script")
check(
	match.StarterPlayer.StarterPlayerScripts.Match.ClassName == "LocalScript",
	"match client script"
)
check(match.Players.CharacterAutoLoads == false, "characters load only when the match spawns them")
check(match.Workspace.StreamingEnabled == true, "streaming enabled")

local assets = match.ServerStorage.Assets
for _, stand in Stands.list do
	local package = assets.Stands:FindFirstChild(stand.id)
	check(package, "missing Stand package " .. stand.id)
	local morph = package:FindFirstChild("Morph")
	check(
		morph and morph:FindFirstChild("HumanoidRootPart"),
		stand.id .. " morph needs a HumanoidRootPart"
	)
	check(
		morph:FindFirstChildOfClass("Humanoid"),
		stand.id .. " morph needs a Humanoid for animation"
	)
	check(package:FindFirstChild("Idle"), stand.id .. " idle animation")
end
for _, skin in GachaConfig.skins do
	local model = assets.Skins:FindFirstChild(skin.id)
	check(model and model:FindFirstChild("HumanoidRootPart"), "missing skin model " .. skin.id)
end
local boss = assets.Boss:FindFirstChild(MatchConfig.boss.standId)
check(boss and boss:FindFirstChild("Morph"), "boss package " .. MatchConfig.boss.standId)
for id in Items.weapons do
	local tool = assets.Weapons:FindFirstChild(id)
	check(
		tool and tool.ClassName == "Tool" and tool:FindFirstChild("Handle"),
		"weapon tool with handle " .. id
	)
end
for id in Items.heals do
	local tool = assets.Heals:FindFirstChild(id)
	check(
		tool and tool.ClassName == "Tool" and tool:FindFirstChild("Handle"),
		"heal tool with handle " .. id
	)
end
for _, name in { "Disc", "StandArrow", "RequiemArrow" } do
	check(assets.Items:FindFirstChild(name), "item model " .. name)
end
noScripts(assets, "ServerStorage.Assets")

local workspace = match.Workspace
check(workspace:FindFirstChild("Map") and #workspace.Map:GetChildren() > 100, "town map")
noScripts(workspace.Map, "Map")
check(#workspace.LootSpawns:GetChildren() > 20, "loot spawn markers")
check(
	workspace.Districts:FindFirstChild(MatchConfig.finalLandmarkDistrict),
	"final landmark district"
)
check(workspace.WaitingRoom:FindFirstChildOfClass("SpawnLocation"), "waiting room spawn")

local anims = match.ReplicatedStorage.Assets.CombatAnims
for i = 1, 5 do
	check(anims:FindFirstChild("Combo" .. i), "combo animation " .. i)
end
check(#match.ReplicatedStorage.Assets.CombatSounds:GetChildren() > 0, "combat sounds")

print(string.format("PASS: %d place/config consistency checks (not Roblox engine tests)", checks))
