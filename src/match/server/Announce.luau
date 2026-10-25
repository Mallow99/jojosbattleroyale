--!strict
-- Feed messages shown on every client's HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Announce = {}

local event = Net.event("Notify")

function Announce.all(text: string, tone: string?)
	event:FireAllClients({ text = text, tone = tone or "info" })
end

function Announce.to(player: Player, text: string, tone: string?)
	event:FireClient(player, { text = text, tone = tone or "info" })
end

return Announce
