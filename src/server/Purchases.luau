--!strict
-- Coin developer products. Disabled unless Places.purchasesEnabled is true and product
-- ids are configured. Coins buy gacha pulls, so players for whom paid random items are
-- restricted cannot buy them. Receipts are recorded in the profile and only reported as
-- granted after the save succeeds, so Roblox retries until the grant is durable.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Shared.Config.Places)
local PlayerData = require(script.Parent.PlayerData)

local Purchases = {}

local RECEIPT_HISTORY = 100

function Purchases.enabled(): boolean
	if not Places.purchasesEnabled then
		return false
	end
	for _, product in Places.coinProducts do
		if product.productId == nil then
			return false
		end
	end
	return true
end

function Purchases.canBuy(player: Player): boolean
	if not Purchases.enabled() then
		return false
	end
	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	return ok and policy and not policy.ArePaidRandomItemsRestricted
end

local function coinsFor(productId: number): number?
	for _, product in Places.coinProducts do
		if product.productId == productId then
			return product.coins
		end
	end
	return nil
end

local function processReceipt(receipt): Enum.ProductPurchaseDecision
	local player = game:GetService("Players"):GetPlayerByUserId(receipt.PlayerId)
	local coins = coinsFor(receipt.ProductId)
	if not player or not coins or not PlayerData.get(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.update(player, function(profile)
		if table.find(profile.receipts, receipt.PurchaseId) then
			return
		end
		profile.coins += coins
		table.insert(profile.receipts, receipt.PurchaseId)
		while #profile.receipts > RECEIPT_HISTORY do
			table.remove(profile.receipts, 1)
		end
	end)
	if not PlayerData.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Purchases.start()
	if not Purchases.enabled() then
		return
	end
	MarketplaceService.ProcessReceipt = processReceipt
end

function Purchases.prompt(player: Player, index: number): (boolean, string?)
	if not Purchases.enabled() then
		return false, "Purchases are disabled"
	end
	if not Purchases.canBuy(player) then
		return false, "Coin purchases are unavailable for your account"
	end
	local product = Places.coinProducts[index]
	if not product or not product.productId then
		return false, "Unknown product"
	end
	MarketplaceService:PromptProductPurchase(player, product.productId)
	return true, nil
end

return Purchases
