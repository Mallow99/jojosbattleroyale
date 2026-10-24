--!nocheck
-- Simulates what Studio's 3D Importer produces from StarPlatinumMorph.fbx: one MeshPart per
-- mesh object, centred on its bounds, under an arbitrary import transform and scale. Used by
-- tests (installer robustness) and the preview. It is not the Roblox importer.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3

local ImportSim = {}

function ImportSim.report()
	return serde.decode("json", fs.readFile("art/star_platinum/morph_report.json"))
end

function ImportSim.import(importCFrame, scale)
	importCFrame = importCFrame or CFrame.new()
	scale = scale or 1
	local model = Instance.new("Model")
	model.Name = "StarPlatinumMorph"
	for _, piece in ImportSim.report().pieces do
		local lo = Vector3.new(piece.min[1], piece.min[2], piece.min[3])
		local hi = Vector3.new(piece.max[1], piece.max[2], piece.max[3])
		local center = (lo + hi) / 2
		local part = Instance.new("MeshPart")
		part.Name = piece.name
		part.Size = (hi - lo) * scale
		part.CFrame = importCFrame * CFrame.new(center * scale)
		part.Anchored = true
		-- Lune has no engine defaults, so set what Studio would.
		part.TextureID = if string.find(piece.name, "__tex")
				or string.find(piece.name, "__facetex")
			then "rbxassetid://0"
			else ""
		part.Color = roblox.Color3.fromRGB(163, 162, 165)
		part.Transparency = 0
		part:SetAttribute("SourceMesh", piece.name)
		part:SetAttribute("SourceCenter", center)
		part.Parent = model
	end
	return model
end

return ImportSim
