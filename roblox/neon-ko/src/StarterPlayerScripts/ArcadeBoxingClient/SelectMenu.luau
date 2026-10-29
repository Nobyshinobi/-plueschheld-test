-- Gegnerauswahl: vier Karten (gesperrt / bereit / besiegt), Abbrechen, Zeitbalken.
-- Gamepad: Auswahl mit dem Steuerkreuz/Stick, Bestätigen mit A (Roblox-GUI-Navigation).

local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent:WaitForChild("UI"))

local SelectMenu = {}

local C = UI.Colors
local gui: ScreenGui? = nil
local previousSelection: GuiObject? = nil
local timerConnection: RBXScriptConnection? = nil

local function stars(n: number): string
	return string.rep("★", n) .. string.rep("☆", 4 - n)
end

-- payload: { opponents = {...}, deadline, timeout, invited }
function SelectMenu.open(payload, onChoose: (number) -> (), onCancel: () -> ())
	SelectMenu.close()
	gui = UI.screen("ArcadeBoxingSelect", 60)
	local root = gui :: ScreenGui
	local camera = Workspace.CurrentCamera
	local narrow = camera and camera.ViewportSize.X < 760

	UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.45,
		Parent = root,
	})
	local panel = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.05,
		Parent = root,
	}, {
		UI.corner(UDim.new(0, 18)),
		UI.stroke(C.Violet, 3, 0),
		UI.padding(14),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(980, 560) }),
	})
	local title = UI.label({
		Text = if payload.invited
			then "DU BIST DRAN – WÄHLE DEINEN GEGNER"
			else "NEON K.O. – WÄHLE DEINEN GEGNER",
		Size = UDim2.new(1, 0, 0.11, 0),
		FontFace = UI.TitleFont,
		TextColor3 = C.Cyan,
		Parent = panel,
	})
	UI.textStroke(C.Violet, 2).Parent = title

	local grid = UI.new("Frame", {
		Position = UDim2.fromScale(0, 0.13),
		Size = UDim2.fromScale(1, 0.72),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		UI.new("UIGridLayout", {
			CellSize = if narrow then UDim2.new(0.5, -6, 0.5, -6) else UDim2.new(0.25, -9, 1, 0),
			CellPadding = UDim2.fromOffset(12, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local firstButton: GuiObject? = nil
	local firstBeaten = false
	for _, o in payload.opponents do
		local accent = o.accent or C.Toxic
		local card = UI.new("Frame", {
			LayoutOrder = o.id,
			BackgroundColor3 = Color3.fromRGB(24, 14, 44),
			Parent = grid,
		}, {
			UI.corner(UDim.new(0, 14)),
			UI.stroke(if o.unlocked then accent else C.Violet, 2, if o.unlocked then 0 else 0.6),
		})
		UI.new("Frame", {
			Size = UDim2.new(1, 0, 0.2, 0),
			BackgroundColor3 = o.color or C.Violet,
			BackgroundTransparency = if o.unlocked then 0 else 0.6,
			Parent = card,
		}, {
			UI.corner(UDim.new(0, 14)),
			UI.new("UIGradient", { Color = ColorSequence.new(o.color or C.Violet, accent), Rotation = 0 }),
		})
		local body = UI.new("Frame", {
			Position = UDim2.fromScale(0, 0.2),
			Size = UDim2.fromScale(1, 0.8),
			BackgroundTransparency = 1,
			Parent = card,
		}, { UI.padding(8) })
		local function line(text: string, y: number, h: number, color: Color3?, font: Font?)
			return UI.label({
				Text = text,
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, h),
				TextColor3 = color or C.White,
				FontFace = font or UI.TextFont,
				TextTransparency = if o.unlocked then 0 else 0.45,
				Parent = body,
			})
		end
		line(o.name, 0, 0.18, accent, UI.TitleFont)
		line(o.title, 0.19, 0.11)
		line(o.style, 0.31, 0.15, C.White)
		line(("%s  ·  %d HP"):format(stars(o.difficulty), o.maxHp), 0.48, 0.1, C.Gold)
		line("Special: " .. o.special, 0.59, 0.09, C.Cyan)
		local status = if not o.unlocked then "🔒 GESPERRT" elseif o.beaten then "✓ BESIEGT" else "BEREIT"
		line(status, 0.69, 0.09, if o.beaten then C.Toxic else C.White)
		local fight = UI.button(if o.unlocked then "FIGHT" else "GESPERRT", if o.unlocked then C.Toxic else C.Violet, {
			Position = UDim2.fromScale(0.05, 0.81),
			Size = UDim2.fromScale(0.9, 0.17),
			Selectable = o.unlocked,
			Active = o.unlocked,
			TextTransparency = if o.unlocked then 0 else 0.5,
			Parent = body,
		})
		if o.unlocked then
			fight.Activated:Connect(function()
				onChoose(o.id)
			end)
			-- Vorauswahl: erster noch nicht besiegter Gegner, sonst der erste freigeschaltete.
			if not firstButton or (firstBeaten and not o.beaten) then
				firstButton = fight
				firstBeaten = o.beaten
			end
		end
	end

	local footer = UI.new("Frame", {
		Position = UDim2.fromScale(0, 0.88),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local cancel = UI.button("ABBRECHEN", C.Magenta, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, 180, 0.9, 0),
		Parent = footer,
	})
	cancel.Activated:Connect(onCancel)
	local timeBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -200, 0, 8),
		BackgroundColor3 = Color3.fromRGB(40, 24, 70),
		Parent = footer,
	}, { UI.corner(UDim.new(1, 0)) })
	local timeFill = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Cyan,
		Parent = timeBar,
	}, { UI.corner(UDim.new(1, 0)) })

	local deadline = payload.deadline or (Workspace:GetServerTimeNow() + (payload.timeout or 20))
	local total = math.max(1, payload.timeout or 20)
	timerConnection = game:GetService("RunService").RenderStepped:Connect(function()
		local left = math.max(0, deadline - Workspace:GetServerTimeNow())
		timeFill.Size = UDim2.fromScale(left / total, 1)
	end)

	previousSelection = GuiService.SelectedObject
	if firstButton then
		pcall(function()
			GuiService.SelectedObject = firstButton
		end)
	end
end

function SelectMenu.isOpen(): boolean
	return gui ~= nil
end

function SelectMenu.close()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
	if gui then
		gui:Destroy()
		gui = nil
		pcall(function()
			GuiService.SelectedObject = if previousSelection and previousSelection.Parent
				then previousSelection
				else nil
		end)
		previousSelection = nil
	end
end

return SelectMenu
