--!strict
-- Lobby UI: queue, currency, gacha banners and skin collection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)
local Stands = require(Shared.Config.Stands)
local GachaConfig = require(Shared.Config.Gacha)

local player = Players.LocalPlayer
local colors = Ui.colors

local state: any = nil
local queued = false
local selectedBanner: string? = nil

local gui = Ui.make("ScreenGui", {
	Name = "Lobby",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Top bar ----------------------------------------------------------------------------
local currency = Ui.label({
	Parent = gui,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.fromOffset(420, 30),
	TextSize = 20,
	Font = Enum.Font.GothamBold,
	Text = "Loading profile...",
})

-- Queue ------------------------------------------------------------------------------
local queueStatus = Ui.label({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -100),
	Size = UDim2.fromOffset(560, 44),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = colors.muted,
	Text = "",
})
local queueButton: TextButton
queueButton = Ui.button({
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.fromOffset(260, 60),
	TextSize = 26,
	Text = "PLAY",
}, function()
	if queued then
		Net.event("QueueLeave"):FireServer()
	else
		Net.event("QueueJoin"):FireServer()
	end
end)

Net.event("QueueStatus").OnClientEvent:Connect(function(status)
	queued = status.state == "queued" or status.state == "teleporting"
	queueButton.Text = if queued then "CANCEL" else "PLAY"
	queueButton.BackgroundColor3 = if queued then colors.panelLight else colors.accent
	queueStatus.Text = status.message
end)

-- Panels -----------------------------------------------------------------------------
local function panel(name: string): Frame
	return Ui.make("Frame", {
		Name = name,
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(860, 520),
		BackgroundColor3 = colors.panel,
		Visible = false,
	}, { Ui.corner(12) })
end

local bannerPanel = panel("Banners")
local collectionPanel = panel("Collection")

local function toggle(target: Frame)
	local show = not target.Visible
	bannerPanel.Visible = false
	collectionPanel.Visible = false
	target.Visible = show
end

Ui.button({
	Parent = gui,
	Position = UDim2.fromOffset(20, 56),
	Size = UDim2.fromOffset(150, 40),
	Text = "Banners",
}, function()
	toggle(bannerPanel)
end)
Ui.button({
	Parent = gui,
	Position = UDim2.fromOffset(180, 56),
	Size = UDim2.fromOffset(150, 40),
	Text = "Collection",
}, function()
	toggle(collectionPanel)
end)

local function list(
	parent: Instance,
	position: UDim2,
	size: UDim2,
	padding: number?
): ScrollingFrame
	return Ui.make("ScrollingFrame", {
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundColor3 = colors.panelLight,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, {
		Ui.corner(8),
		Ui.make(
			"UIListLayout",
			{ Padding = UDim.new(0, padding or 4), SortOrder = Enum.SortOrder.LayoutOrder }
		),
		Ui.make("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
end

-- Banner panel layout
local bannerTabs = list(bannerPanel, UDim2.fromOffset(16, 16), UDim2.fromOffset(220, 488), 8)
local bannerTitle = Ui.label({
	Parent = bannerPanel,
	Position = UDim2.fromOffset(252, 16),
	Size = UDim2.fromOffset(590, 32),
	TextSize = 24,
	Font = Enum.Font.GothamBold,
})
local bannerInfo = Ui.label({
	Parent = bannerPanel,
	Position = UDim2.fromOffset(252, 50),
	Size = UDim2.fromOffset(590, 44),
	TextColor3 = colors.muted,
})
local oddsList = list(bannerPanel, UDim2.fromOffset(252, 100), UDim2.fromOffset(300, 340))
local resultList = list(bannerPanel, UDim2.fromOffset(564, 100), UDim2.fromOffset(278, 340))
local pullOne = Ui.button({
	Parent = bannerPanel,
	Position = UDim2.fromOffset(252, 456),
	Size = UDim2.fromOffset(290, 48),
}, function() end)
local pullMany = Ui.button({
	Parent = bannerPanel,
	Position = UDim2.fromOffset(552, 456),
	Size = UDim2.fromOffset(290, 48),
}, function() end)

-- Collection panel layout
local collectionList =
	list(collectionPanel, UDim2.fromOffset(16, 16), UDim2.fromOffset(828, 488), 6)

local function skinName(id: string): string
	local skin = GachaConfig.skinsById[id]
	return if skin then skin.displayName else id
end

local function rarityColor(rarity: string): Color3
	return Ui.rgb(GachaConfig.rarityColors[rarity] or { 255, 255, 255 })
end

local render: () -> ()

local function apply(response: any)
	if response and response.state then
		state = response.state
	end
	render()
end

local function doPull(count: number)
	if not selectedBanner then
		return
	end
	local response = Net.func("GachaPull"):InvokeServer(selectedBanner, count)
	Ui.clear(resultList)
	if not response.ok then
		Ui.label({
			Parent = resultList,
			Size = UDim2.new(1, 0, 0, 40),
			Text = response.message,
			TextColor3 = colors.bad,
		})
		return
	end
	for i, result in response.results do
		local suffix = if result.duplicate
			then string.format("  (duplicate +%d shard)", result.shards)
			else "  NEW"
		Ui.label({
			Parent = resultList,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 24),
			Text = skinName(result.skinId) .. suffix,
			TextColor3 = rarityColor(result.rarity),
		})
	end
	apply(response)
end
pullOne.Activated:Connect(function()
	doPull(1)
end)
pullMany.Activated:Connect(function()
	doPull(GachaConfig.multiPullCount)
end)

local function renderBanners()
	Ui.clear(bannerTabs)
	Ui.clear(oddsList)
	local active = state.banners[1]
	for _, banner in state.banners do
		if banner.id == selectedBanner then
			active = banner
		end
	end
	selectedBanner = active.id
	for i, banner in state.banners do
		local ends = if banner.endsAt
			then "\nEnds in " .. Ui.duration(banner.endsAt - state.serverTime)
			else "\nPermanent"
		Ui.button({
			Parent = bannerTabs,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = if banner.id == active.id then colors.accent else colors.panel,
			Text = banner.displayName .. ends,
			TextSize = 14,
		}, function()
			selectedBanner = banner.id
			render()
		end)
	end
	bannerTitle.Text = active.displayName
	local featured = {}
	for _, id in active.featured do
		table.insert(featured, skinName(id))
	end
	local untilPity = state.hardPity - active.pity
	bannerInfo.Text = (
		if #featured > 0 then "Featured: " .. table.concat(featured, ", ") .. "\n" else ""
	) .. string.format("Legendary guaranteed within %d pulls", untilPity)
	for i, entry in active.odds do
		local owned = if state.owned[entry.skinId] then "  (owned)" else ""
		Ui.label({
			Parent = oddsList,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 14,
			Text = string.format(
				"%5.2f%%  %s%s",
				entry.chance * 100,
				skinName(entry.skinId),
				owned
			),
			TextColor3 = rarityColor(entry.rarity),
		})
	end
	pullOne.Text = string.format("Pull x1 (%d %s)", state.pullCost, state.currencyName)
	pullMany.Text = string.format(
		"Pull x%d (%d %s)",
		state.multiPullCount,
		state.pullCost * state.multiPullCount,
		state.currencyName
	)
end

local function renderCollection()
	Ui.clear(collectionList)
	local order = 0
	for _, stand in Stands.list do
		order += 1
		Ui.label({
			Parent = collectionList,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			Text = stand.displayName,
			TextSize = 20,
			Font = Enum.Font.GothamBold,
		})
		for _, skin in GachaConfig.skins do
			if skin.standId ~= stand.id then
				continue
			end
			order += 1
			local owned = state.owned[skin.id] == true
			local equipped = state.equipped[stand.id] == skin.id
			local row = Ui.make("Frame", {
				Parent = collectionList,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			})
			Ui.label({
				Parent = row,
				Size = UDim2.new(1, -220, 1, 0),
				Text = string.format(
					"%s  [%s]%s",
					skin.displayName,
					skin.rarity,
					if equipped then "  EQUIPPED" else ""
				),
				TextColor3 = if owned then rarityColor(skin.rarity) else colors.muted,
			})
			local action, label
			if owned then
				label = if equipped then "Unequip" else "Equip"
				action = function()
					apply(
						Net.func("EquipSkin")
							:InvokeServer(stand.id, if equipped then nil else skin.id)
					)
				end
			else
				label = string.format("Craft (%d shards)", state.craftCost[skin.rarity])
				action = function()
					apply(Net.func("GachaCraft"):InvokeServer(skin.id))
				end
			end
			Ui.button({
				Parent = row,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 200, 1, 0),
				Text = label,
				TextSize = 14,
			}, action)
		end
	end
end

render = function()
	if not state then
		return
	end
	currency.Text = string.format(
		"%d %s   |   %d Shards   |   %d wins",
		state.coins,
		state.currencyName,
		state.shards,
		state.stats.wins
	)
	renderBanners()
	renderCollection()
end

local function refresh()
	local snapshot = Net.func("GachaState"):InvokeServer()
	if snapshot then
		state = snapshot
		render()
	end
end

Net.event("ProfileChanged").OnClientEvent:Connect(refresh)
task.spawn(function()
	while not state do
		refresh()
		task.wait(1)
	end
	-- Keep banner countdowns current.
	while true do
		task.wait(30)
		refresh()
	end
end)
