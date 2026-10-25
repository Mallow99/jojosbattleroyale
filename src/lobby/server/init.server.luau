--!strict
-- Lobby server: profiles, matchmaking queue and the skin gacha.
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.ServerShared.PlayerData)
local Purchases = require(ServerScriptService.ServerShared.Purchases)
local QueueService = require(script.QueueService)
local GachaService = require(script.GachaService)

PlayerData.manage()
Purchases.start()
GachaService.start()
QueueService.start()
