-- Kleine UI-Bausteine im NEON-K.O.-Stil (Schwarzlicht: Violett, Cyan, Giftgrün) und Toast-Hinweise.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))

local UI = {}

UI.Colors = Config.Effects.Colors
UI.TitleFont = Font.fromEnum(Enum.Font.LuckiestGuy)
UI.BodyFont = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
UI.TextFont = Font.fromEnum(Enum.Font.BuilderSansBold)

function UI.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.corner(radius: UDim?): UICorner
	return UI.new("UICorner", { CornerRadius = radius or UDim.new(0, 10) })
end

function UI.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(color: Color3, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UI.padding(px: number): UIPadding
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function UI.screen(name: string, displayOrder: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = playerGui,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = UI.Colors.White,
		FontFace = UI.BodyFont,
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

-- Neon-Button mit kurzem Drück-Feedback.
function UI.button(text: string, accent: Color3, props: { [string]: any }): TextButton
	local base = {
		Text = text,
		AutoButtonColor = false,
		BackgroundColor3 = UI.Colors.Night,
		BackgroundTransparency = 0.1,
		TextColor3 = UI.Colors.White,
		FontFace = UI.BodyFont,
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	local button = UI.new("TextButton", base, {
		UI.corner(UDim.new(0, 12)),
		UI.stroke(accent, 2.5, 0),
		UI.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 10 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	local scale = UI.new("UIScale", { Scale = 1, Parent = button })
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button
end

function UI.bar(parent: Instance, props: { [string]: any }, fillColor: Color3, rightToLeft: boolean)
	local frame = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 18, 52),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, { UI.corner(UDim.new(0, 6)), UI.stroke(UI.Colors.Violet, 1.5, 0.2) })
	for k, v in props do
		(frame :: any)[k] = v
	end
	local anchor = if rightToLeft then Vector2.new(1, 0) else Vector2.new(0, 0)
	local pos = if rightToLeft then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0)
	local ghost = UI.new("Frame", {
		Name = "Ghost",
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UI.Colors.White,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = frame,
	}, { UI.corner(UDim.new(0, 6)) })
	local fill = UI.new("Frame", {
		Name = "Fill",
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = frame,
	}, {
		UI.corner(UDim.new(0, 6)),
		UI.new("UIGradient", {
			Color = ColorSequence.new(fillColor, fillColor:Lerp(UI.Colors.White, 0.35)),
			Rotation = 90,
		}),
	})
	return { frame = frame, fill = fill, ghost = ghost, value = 1, ghostValue = 1 }
end

-- Glättet Balkenstände (Ghost-Balken läuft verzögert hinterher = gut lesbarer Schaden).
function UI.setBar(bar, value: number, dt: number)
	value = math.clamp(value, 0, 1)
	bar.value += (value - bar.value) * (1 - math.exp(-18 * dt))
	if bar.ghostValue < bar.value then
		bar.ghostValue = bar.value
	else
		bar.ghostValue += (bar.value - bar.ghostValue) * (1 - math.exp(-3 * dt))
	end
	bar.fill.Size = UDim2.fromScale(bar.value, 1)
	bar.ghost.Size = UDim2.fromScale(bar.ghostValue, 1)
end

-- Toasts ---------------------------------------------------------------------------
local toastGui: ScreenGui? = nil
local toastList: Frame? = nil
local queueChip: Frame? = nil

local function ensureToast()
	if toastGui and toastGui.Parent then
		return
	end
	toastGui = UI.screen("ArcadeBoxingToast", 70)
	toastList = UI.new("Frame", {
		Name = "List",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.9, 0, 0, 200),
		BackgroundTransparency = 1,
		Parent = toastGui,
	}, {
		UI.new("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 200) }),
	})
end

local KIND_COLORS = {
	info = UI.Colors.Cyan,
	warn = UI.Colors.Magenta,
	success = UI.Colors.Toxic,
}

function UI.toast(text: string, kind: string?, duration: number?)
	ensureToast()
	local accent = KIND_COLORS[kind or "info"] or UI.Colors.Cyan
	local item = UI.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = UI.Colors.Night,
		BackgroundTransparency = 0.12,
		Text = text,
		TextWrapped = true,
		TextScaled = true,
		FontFace = UI.TextFont,
		TextColor3 = UI.Colors.White,
		Parent = toastList,
	}, {
		UI.corner(UDim.new(0, 10)),
		UI.stroke(accent, 2, 0),
		UI.padding(8),
		UI.new("UITextSizeConstraint", { MaxTextSize = 20 }),
	})
	task.delay(duration or 3.5, function()
		if item.Parent then
			local tween =
				TweenService:Create(item, TweenInfo.new(0.3), { BackgroundTransparency = 1, TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			item:Destroy()
		end
	end)
end

-- Dauerhafter Hinweis "Warteschlange: Platz n" mit Verlassen-Button (position 0 = entfernen).
function UI.queueChip(position: number, onLeave: () -> ())
	ensureToast()
	if queueChip then
		queueChip:Destroy()
		queueChip = nil
	end
	if position <= 0 then
		return
	end
	local chip = UI.new("Frame", {
		Name = "Queue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.8, 0, 0, 48),
		BackgroundColor3 = UI.Colors.Night,
		BackgroundTransparency = 0.1,
		Parent = toastGui,
	}, {
		UI.corner(UDim.new(0, 12)),
		UI.stroke(UI.Colors.Violet, 2, 0),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(420, 48) }),
	})
	UI.label({
		Text = ("NEON K.O. · Warteschlange: Platz %d"):format(position),
		Size = UDim2.new(0.62, 0, 1, -12),
		Position = UDim2.new(0, 12, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UI.TextFont,
		Parent = chip,
	})
	local leave = UI.button("VERLASSEN", UI.Colors.Magenta, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.34, 0, 1, -12),
		Parent = chip,
	})
	leave.Activated:Connect(onLeave)
	queueChip = chip
end

return UI
