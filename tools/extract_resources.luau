--!nocheck
-- Extracts the assets the game foundation uses from `Main game resources.rbxl`.
-- Usage: lune run tools/extract_resources.luau "<path to Main game resources.rbxl>"
-- Reads the place as data only. Every script is stripped; game logic lives in src/.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local placePath = process.args[1] or "Main game resources.rbxl"
local outRoot = process.args[2] or "assets/rbx"
local game = roblox.deserializePlace(fs.readFile(placePath))
local Instance = roblox.Instance

local STRIP = {
	"Script",
	"LocalScript",
	"ModuleScript",
	"RemoteEvent",
	"RemoteFunction",
	"BindableEvent",
	"BindableFunction",
}

local function get(path: { string })
	local inst = game
	for _, name in path do
		inst = inst:FindFirstChild(name)
		if not inst then
			error("missing source instance: " .. table.concat(path, "/"))
		end
	end
	return inst
end

local function strip(inst)
	for _, d in inst:GetDescendants() do
		if table.find(STRIP, d.ClassName) and d.Parent then
			d.Parent = nil
		end
	end
	return inst
end

local written = 0
local function write(rel: string, inst)
	local path = outRoot .. "/" .. rel
	local dir = string.match(path, "^(.*)/[^/]+$")
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	strip(inst)
	fs.writeFile(path, roblox.serializeModel({ inst }))
	written += 1
end

local function copy(path: { string }, name: string?)
	local clone = get(path):Clone()
	if name then
		clone.Name = name
	end
	return clone
end

-- Stand id -> source name in the place. Morphs come from ServerStorage, presentation
-- (idle/move animations, aura, summon sound) from ReplicatedStorage.
local STANDS = {
	StarPlatinum = "Star Platinum",
	TheWorld = "The World",
	CrazyDiamond = "Crazy Diamond",
	KingCrimson = "King Crimson",
	GoldExperience = "Gold Experience",
	Whitesnake = "Whitesnake",
	SilverChariot = "Silver Chariot",
	TheHand = "The Hand",
	ChariotRequiem = "Chariot Requiem",
}

local function standPackage(id: string, source: string)
	local folder = Instance.new("Folder")
	folder.Name = id
	local morph = copy({ "ServerStorage", "Stands", source, "StandMorph" }, "Morph")
	morph.Parent = folder
	local presentation = get({ "ReplicatedStorage", "Stands", source })
	for _, animName in { "Idle", "Move", "PlayerIdle" } do
		local anim = presentation:FindFirstChild(animName)
		if anim then
			anim:Clone().Parent = folder
		end
	end
	local aura = Instance.new("Folder")
	aura.Name = "Aura"
	aura.Parent = folder
	for _, c in presentation:GetChildren() do
		if c.ClassName == "ParticleEmitter" then
			c:Clone().Parent = aura
		end
	end
	local sounds = presentation:FindFirstChild("SummonSounds")
	local summon = sounds and sounds:FindFirstChildWhichIsA("Sound")
	if summon then
		local s = summon:Clone()
		s.Name = "Summon"
		s.Parent = folder
	end
	return folder
end

for id, source in STANDS do
	local dest = if id == "ChariotRequiem" then "boss/" else "stands/"
	write(dest .. id .. ".rbxm", standPackage(id, source))
end

-- Skins for the stands above, from the place's own ObtainableSkins table.
local SKINS = {
	StarPlatinum = { "Manga Platinum", "Female Platinum", "Stone Platinum" },
	TheWorld = { "Retro The World", "The World Greatest High", "Sumo The World", "The Waifu V2" },
	CrazyDiamond = {
		"Crazy Ruby",
		"Jade Peace",
		"Crazy Overseer",
		"Crazy Idol",
		"Sakara",
		"Tsunate",
	},
	KingCrimson = { "Mono Crimson", "Queen Crimson", "Vinegar Crimson", "Sukuna" },
	GoldExperience = { "Volcanic Experience", "Lord Boros" },
	Whitesnake = { "Deimos Snake", "Invert-Snake", "Alabaster Serpent" },
	SilverChariot = { "French Chariot", "Asuna", "Uber Spy" },
	TheHand = { "Chrome Hand" },
}
local function slug(name: string): string
	return (string.gsub(name, "[^%w]", ""))
end
for _, skins in SKINS do
	for _, skinName in skins do
		write(
			"skins/" .. slug(skinName) .. ".rbxm",
			copy({ "ServerStorage", "Skins", skinName, "StandMorph" }, slug(skinName))
		)
	end
end

-- Pickups. World models come from Tool_Replicas; weapons and heals stay Tools.
write(
	"items/RequiemArrow.rbxm",
	copy({ "ServerStorage", "Tool_Replicas", "Requiem Arrow" }, "RequiemArrow")
)
write(
	"items/StandArrow.rbxm",
	copy({ "ServerStorage", "Tool_Replicas", "Mysterious Arrow" }, "StandArrow")
)
do
	local disc = Instance.new("Model")
	disc.Name = "Disc"
	for _, c in get({ "ServerStorage", "Tools", "Jotaro's DISC" }):GetChildren() do
		c:Clone().Parent = disc
	end
	disc.PrimaryPart = disc:FindFirstChild("Handle")
	write("items/Disc.rbxm", disc)
end
for id, source in { Katana = "Katana", Dagger = "Dagger", Knife = "DIO's Knife", Shovel = "Shovel" } do
	local tool = copy({ "ServerStorage", "Tools", source }, id)
	for _, c in tool:GetChildren() do
		if
			c.ClassName ~= "Part"
			and c.ClassName ~= "MeshPart"
			and c.ClassName ~= "UnionOperation"
		then
			c.Parent = nil
		end
	end
	write("weapons/" .. id .. ".rbxm", tool)
end
write("heals/Tea.rbxm", copy({ "ServerStorage", "Tools", "Tea" }, "Tea"))

-- Shared presentation: punch combo animations, hit/swing sounds, Magician's Red VFX.
write(
	"shared/CombatAnims.rbxm",
	copy({ "ReplicatedStorage", "Assets", "Anims", "DefaultCombat" }, "CombatAnims")
)
do
	local sounds = Instance.new("Folder")
	sounds.Name = "CombatSounds"
	for _, name in
		{
			"Fist_Hit1",
			"Fist_Hit2",
			"Fist_Hit3",
			"Heavy_Hit",
			"Swoosh_2",
			"Swoosh_3",
			"Sword Cut 1",
		}
	do
		local s = copy({ "ReplicatedStorage", "Assets", "Sounds", name }, slug(name))
		s.Parent = sounds
	end
	write("shared/CombatSounds.rbxm", sounds)
end
write(
	"effects/MagiciansRed.rbxm",
	copy({ "ReplicatedStorage", "Assets", "Objects", "Magicians_Red_Assets" }, "MagiciansRed")
)

-- Match map: the town, its item spawn markers and its named districts.
write("map/Town.rbxm", copy({ "Workspace", "Map", "Map" }, "Town"))
do
	local spawns = Instance.new("Folder")
	spawns.Name = "LootSpawns"
	for _, c in get({ "Workspace", "Item_Spawns" }):GetChildren() do
		if c.ClassName == "Part" then
			c:Clone().Parent = spawns
		end
	end
	write("map/LootSpawns.rbxm", spawns)
end
do
	-- Persistent so every client can name the district it stands in.
	local districts = Instance.new("Model")
	districts.Name = "Districts"
	districts.ModelStreamingMode = roblox.Enum.ModelStreamingMode.Persistent
	for _, c in get({ "Workspace", "Locations" }):GetChildren() do
		if c.ClassName == "Part" then
			local p = c:Clone()
			p:ClearAllChildren()
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Transparency = 1
			p.Parent = districts
		end
	end
	write("map/Districts.rbxm", districts)
end
for _, name in { "Atmosphere", "Sky", "Bloom", "SunRays", "ColorCorrection" } do
	write("lighting/" .. name .. ".rbxm", copy({ "Lighting", name }))
end

print(string.format("Wrote %d model files to %s", written, outRoot))
