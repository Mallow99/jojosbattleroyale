--!nocheck
-- Demo stage for viewing the cutscene in Studio: plaza, ruined pillars, disc pedestal and spawn.
local roblox = require("@lune/roblox")
local B = require("./Builder")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local Enum = roblox.Enum
local V = Vector3.new
local rgb = B.rgb

local SOLID = { anchored = true, canCollide = true, canQuery = true }

local function solid(extra)
	local options = table.clone(SOLID)
	for key, value in extra or {} do
		options[key] = value
	end
	return options
end

return function()
	local model = roblox.Instance.new("Model")
	model.Name = "StandStage"
	B.part(
		model,
		"Block",
		"Ground",
		V(220, 2, 220),
		CFrame.new(0, -1, 0),
		rgb(186, 160, 122),
		solid({ material = Enum.Material.Sand })
	)
	-- plaza tiles
	for ix = -4, 3 do
		for iz = -4, 3 do
			local shade = if (ix + iz) % 2 == 0 then rgb(214, 198, 168) else rgb(198, 180, 150)
			B.part(
				model,
				"Block",
				"Tile",
				V(5.9, 0.2, 5.9),
				CFrame.new(ix * 6 + 3, 0.1, iz * 6 + 3),
				shade,
				solid({ material = Enum.Material.Slate })
			)
		end
	end
	-- dais and pedestal
	B.part(
		model,
		"Cylinder",
		"Dais",
		V(0.5, 9, 9),
		CFrame.new(0, 0.3, -6) * B.angles(0, 0, 90),
		rgb(120, 104, 140),
		solid({ material = Enum.Material.Slate })
	)
	B.part(
		model,
		"Block",
		"Pedestal",
		V(1.8, 3, 1.8),
		CFrame.new(0, 2, -6),
		rgb(70, 58, 96),
		solid({ material = Enum.Material.Slate })
	)
	B.part(
		model,
		"Block",
		"PedestalCap",
		V(2.3, 0.3, 2.3),
		CFrame.new(0, 3.6, -6),
		rgb(222, 178, 70),
		solid({ reflectance = 0.1 })
	)
	B.part(model, "Block", "DiscSpot", V(1, 1, 1), CFrame.new(0, 5.1, -6), rgb(255, 255, 255), {
		anchored = true,
		transparency = 1,
		castShadow = false,
	})
	-- ring of ruined pillars
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2 + math.pi / 8
		local position = V(math.sin(angle) * 30, 0, math.cos(angle) * 30)
		local height = ({ 16, 11, 16, 7, 16, 13, 9, 16 })[index + 1]
		local base = CFrame.new(position) * CFrame.Angles(0, angle, 0)
		B.part(
			model,
			"Block",
			"PillarBase",
			V(3.6, 1, 3.6),
			base * CFrame.new(0, 0.5, 0),
			rgb(176, 156, 126),
			solid({ material = Enum.Material.Sandstone })
		)
		B.part(
			model,
			"Block",
			"Pillar",
			V(2.6, height, 2.6),
			base * CFrame.new(0, height / 2 + 1, 0),
			rgb(206, 188, 154),
			solid({ material = Enum.Material.Sandstone })
		)
		if height == 16 then
			B.part(
				model,
				"Block",
				"PillarCap",
				V(3.8, 1.2, 3.8),
				base * CFrame.new(0, 17.6, 0),
				rgb(176, 156, 126),
				solid({ material = Enum.Material.Sandstone })
			)
		else
			B.part(
				model,
				"Block",
				"Rubble",
				V(2.2, 1.4, 1.8),
				base * CFrame.new(2.4, 0.7, 1.2) * B.angles(0, 25, 12),
				rgb(196, 176, 142),
				solid({ material = Enum.Material.Sandstone })
			)
		end
	end
	local spawn = roblox.Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = V(6, 0.4, 6)
	spawn.CFrame = CFrame.new(0, 0.2, 18)
	spawn.Anchored = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = model
	-- Where the server places the player for the demo: in front of the pedestal, facing the plaza.
	local mark = B.part(
		model,
		"Block",
		"CutsceneMark",
		V(1, 0.2, 1),
		CFrame.new(0, 0.1, 2) * B.angles(0, 180, 0),
		rgb(255, 255, 255),
		{
			anchored = true,
			transparency = 1,
			castShadow = false,
		}
	)
	mark:SetAttribute(
		"Note",
		"Player stands here during the demo cutscene, facing the mark's LookVector"
	)
	return model
end
