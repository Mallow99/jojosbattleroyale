--!strict
-- Match server: one battle royale per reserved server.
local Players = game:GetService("Players")

Players.CharacterAutoLoads = false

local MatchService = require(script.MatchService)
MatchService.start()
