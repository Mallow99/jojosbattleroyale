--!strict
-- Match HUD and input: timers, zone, discs, channels, Requiem Arrow, results, spectating.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)
local Stands = require(Shared.Config.Stands)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local colors = Ui.colors

local gui = Ui.make("ScreenGui", {
	Name = "MatchHud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	Parent = player:WaitForChild("PlayerGui"),
})

local function hudLabel(props: { [string]: any }): TextLabel
	props.Parent = gui
	props.TextStrokeTransparency = 0.4
	return Ui.label(props)
end

local phaseLabel = hudLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(600, 30),
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local zoneLabel = hudLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(600, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local relicLabel = hudLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 68),
	Size = UDim2.fromOffset(600, 24),
	TextColor3 = Color3.fromRGB(255, 210, 60),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local aliveLabel = hudLabel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 14),
	Size = UDim2.fromOffset(200, 30),
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local districtLabel = hudLabel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 44),
	Size = UDim2.fromOffset(300, 24),
	TextColor3 = colors.muted,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local discLabel = hudLabel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90),
	Size = UDim2.fromOffset(700, 26),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "No Stand: find a disc or a Stand Arrow",
})
hudLabel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.fromOffset(700, 22),
	TextSize = 14,
	TextColor3 = colors.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Click: attack   X: swap disc   G: drop spare   F: activate at the beacon",
})
local deployLabel = hudLabel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.7),
	Size = UDim2.fromOffset(600, 40),
	TextSize = 26,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Press SPACE to drop",
	Visible = false,
})

local feed = Ui.make("Frame", {
	Parent = gui,
	Position = UDim2.fromOffset(20, 110),
	Size = UDim2.fromOffset(460, 220),
	BackgroundTransparency = 1,
}, {
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}),
})
local feedOrder = 0
local TONES = {
	info = colors.text,
	bad = colors.bad,
	relic = Color3.fromRGB(255, 210, 60),
	good = colors.good,
}
local function notify(text: string, tone: string?)
	feedOrder += 1
	local label = Ui.label({
		Parent = feed,
		LayoutOrder = feedOrder,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		Text = text,
		TextColor3 = TONES[tone or "info"] or colors.text,
	})
	local children = feed:GetChildren()
	if #children > 9 then
		for _, child in children do
			if child:IsA("TextLabel") and child.LayoutOrder <= feedOrder - 8 then
				child:Destroy()
			end
		end
	end
	task.delay(10, function()
		if label.Parent then
			label:Destroy()
		end
	end)
end

-- Channel bar (own swap/heal/activation) and the public activation bar.
local function bar(y: number, color: Color3): (Frame, Frame, TextLabel)
	local frame = Ui.make("Frame", {
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(360, 26),
		BackgroundColor3 = colors.panel,
		Visible = false,
	}, { Ui.corner(6) })
	local fill = Ui.make(
		"Frame",
		{ Parent = frame, Size = UDim2.fromScale(0, 1), BackgroundColor3 = color },
		{ Ui.corner(6) }
	)
	local text = Ui.label({
		Parent = frame,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		ZIndex = 2,
	})
	return frame, fill, text
end
local channelFrame, channelFill, channelText = bar(0, colors.accent)
channelFrame.Position = UDim2.fromScale(0.5, 0.62)
local activationFrame, activationFill, activationText = bar(110, Color3.fromRGB(255, 200, 40))

local channel: { kind: string, duration: number, started: number }? = nil
local activation: { name: string, duration: number, started: number }? = nil

-- End and elimination screen.
local endFrame = Ui.make("Frame", {
	Parent = gui,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(460, 230),
	BackgroundColor3 = colors.panel,
	Visible = false,
}, { Ui.corner(12) })
local endTitle = Ui.label({
	Parent = endFrame,
	Position = UDim2.fromOffset(20, 16),
	Size = UDim2.new(1, -40, 0, 40),
	TextSize = 30,
	Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local endBody = Ui.label({
	Parent = endFrame,
	Position = UDim2.fromOffset(20, 64),
	Size = UDim2.new(1, -40, 0, 80),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = colors.muted,
})
Ui.button({
	Parent = endFrame,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -110, 1, -16),
	Size = UDim2.fromOffset(200, 44),
	Text = "Return to lobby",
}, function()
	Net.event("ReturnToLobby"):FireServer()
end)
local spectateTargets: { Player } = {}
local spectateIndex = 0
local function spectateNext()
	spectateTargets = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if other ~= player and humanoid and humanoid.Health > 0 then
			table.insert(spectateTargets, other)
		end
	end
	if #spectateTargets == 0 then
		return
	end
	spectateIndex = spectateIndex % #spectateTargets + 1
	local target = spectateTargets[spectateIndex]
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		notify("Spectating " .. target.Name)
	end
end
Ui.button({
	Parent = endFrame,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 110, 1, -16),
	Size = UDim2.fromOffset(200, 44),
	Text = "Spectate next",
	BackgroundColor3 = colors.panelLight,
}, spectateNext)

local function showEnd(title: string, body: string)
	endTitle.Text = title
	endBody.Text = body
	endFrame.Visible = true
end

-- Server events ----------------------------------------------------------------------
local PHASE_NAMES = {
	Waiting = "Waiting for players",
	Deploying = "Deploying",
	Looting = "Loot up",
	RelicRevealed = "Requiem Arrow revealed",
	ActivationOpen = "Activation open",
	Ended = "Match over",
}

local zone: any = nil
Net.event("MatchState").OnClientEvent:Connect(function(state)
	local phaseName = PHASE_NAMES[state.phase] or state.phase
	if state.phase == "Waiting" then
		phaseLabel.Text = string.format(
			"%s (%d%s)",
			phaseName,
			state.waiting or 0,
			if state.expected then "/" .. state.expected else ""
		)
		return
	end
	phaseLabel.Text = if state.nextEvent
		then string.format(
			"%s  |  %s in %s",
			phaseName,
			state.nextEvent,
			Ui.duration(state.nextEventIn)
		)
		else phaseName
	aliveLabel.Text = string.format("%d alive", state.alive)
	zone = state.zone
	relicLabel.Text = if state.carrier then "Requiem Arrow: " .. state.carrier else ""
end)

Net.event("Notify").OnClientEvent:Connect(function(message)
	notify(message.text, message.tone)
end)

Net.event("Discs").OnClientEvent:Connect(function(discs)
	local function name(id: string?): string
		local stand = id and Stands.byId[id]
		return if stand then stand.displayName elseif id then id else "empty"
	end
	if not discs.active then
		discLabel.Text = "No Stand: find a disc or a Stand Arrow"
	else
		discLabel.Text =
			string.format("Stand: %s   |   Spare: %s", name(discs.active), name(discs.spare))
	end
end)

Net.event("Channel").OnClientEvent:Connect(function(message)
	if message.done then
		channel = nil
		channelFrame.Visible = false
	else
		channel = { kind = message.kind, duration = message.duration, started = os.clock() }
		channelFrame.Visible = true
	end
end)

Net.event("Activation").OnClientEvent:Connect(function(message)
	if message.done then
		activation = nil
		activationFrame.Visible = false
	else
		activation = { name = message.name, duration = message.duration, started = os.clock() }
		activationFrame.Visible = true
	end
end)

local aboard = false
Net.event("Deploy").OnClientEvent:Connect(function(message)
	aboard = message.aboard
	deployLabel.Visible = aboard
end)

Net.event("Eliminated").OnClientEvent:Connect(function(message)
	showEnd(
		string.format("#%d", message.placement),
		if message.killer then "Eliminated by " .. message.killer else "Eliminated"
	)
end)

Net.event("Results").OnClientEvent:Connect(function(results)
	local title = if results.won then "REQUIEM!" else "Match over"
	local winner = if results.winner
		then results.winner .. " activated the Requiem Arrow."
		else "No winner."
	showEnd(title, string.format("%s\n+%d %s", winner, results.coins, results.currencyName))
end)

-- Input ------------------------------------------------------------------------------
local animations = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("CombatAnims")
local combo = 0
local lastSwing = 0
local function playSwing()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	combo = combo % 5 + 1
	local animation = animations:FindFirstChild("Combo" .. combo)
	if animation and animation:IsA("Animation") then
		animator:LoadAnimation(animation):Play()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		if tool and tool:GetAttribute("HealId") then
			return
		end
		if os.clock() - lastSwing > 0.3 then
			lastSwing = os.clock()
			playSwing()
		end
		Net.event("Attack"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.X then
		Net.event("SwapDisc"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		Net.event("DropSpare"):FireServer()
	elseif input.KeyCode == Enum.KeyCode.Space and aboard then
		Net.event("DeployDrop"):FireServer()
	end
end)

-- Per-frame HUD ----------------------------------------------------------------------
local districtsFolder = workspace:WaitForChild("Districts", 10)
local lastDistrictCheck = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if channel then
		local t = math.clamp((now - channel.started) / channel.duration, 0, 1)
		channelFill.Size = UDim2.fromScale(t, 1)
		channelText.Text = channel.kind
	end
	if activation then
		local t = math.clamp((now - activation.started) / activation.duration, 0, 1)
		activationFill.Size = UDim2.fromScale(t, 1)
		activationText.Text = activation.name .. " is activating the Requiem Arrow"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if zone and root then
		local dx, dz = root.Position.X - zone.x, root.Position.Z - zone.z
		local inside = dx * dx + dz * dz <= zone.radius * zone.radius
		zoneLabel.Text = if inside
			then (if zone.shrinking then "Zone is shrinking" else "Inside the zone")
			else string.format("OUTSIDE THE ZONE (-%d/s)", zone.damage)
		zoneLabel.TextColor3 = if inside then colors.text else colors.bad
	end
	if root and districtsFolder and now - lastDistrictCheck > 1 then
		lastDistrictCheck = now
		local found = ""
		for _, part in districtsFolder:GetChildren() do
			if part:IsA("BasePart") then
				local p = part.CFrame:PointToObjectSpace(root.Position)
				if math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2 then
					found = part.Name
				end
			end
		end
		districtLabel.Text = found
	end
end)
