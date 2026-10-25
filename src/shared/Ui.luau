--!strict
-- Small helpers for building plain code-driven UI.
local Ui = {}

Ui.colors = {
	panel = Color3.fromRGB(24, 20, 34),
	panelLight = Color3.fromRGB(44, 36, 62),
	accent = Color3.fromRGB(196, 120, 255),
	text = Color3.fromRGB(240, 236, 250),
	muted = Color3.fromRGB(170, 160, 190),
	good = Color3.fromRGB(110, 220, 140),
	bad = Color3.fromRGB(255, 100, 100),
}

function Ui.make(className: string, props: { [string]: any }, children: { any }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { any } do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Ui.corner(radius: number?): UICorner
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = Ui.colors.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextLabel", defaults)
end

function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = Ui.colors.accent,
		TextColor3 = Ui.colors.text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.make("TextButton", defaults, { Ui.corner(6) })
	button.Activated:Connect(onClick)
	return button
end

function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if
			not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UIGridLayout")
		then
			child:Destroy()
		end
	end
end

function Ui.rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function Ui.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	if days > 0 then
		return string.format("%dd %dh", days, (seconds % 86400) // 3600)
	end
	local hours = seconds // 3600
	if hours > 0 then
		return string.format("%dh %dm", hours, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Ui
