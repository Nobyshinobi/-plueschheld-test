-- Kampf-HUD (nur für den aktiven Kämpfer): HP/Energie beider Seiten, Timer, Combo-Zähler,
-- Countdown/Ansagen, Intro-Karte, Ergebnis, Verlassen/FX-Buttons und Touch-Steuerung.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("UI"))

local HUD = {}

local C = UI.Colors
local gui: ScreenGui? = nil
local refs = nil
local connections: { RBXScriptConnection } = {}

local RESULT_TEXT = {
	Victory = { "VICTORY", C.Toxic },
	Defeat = { "DEFEAT", C.Magenta },
	Draw = { "DRAW", C.Cyan },
	Aborted = { "ABGEBROCHEN", C.Violet },
}

local function fighterPanel(parent: Instance, name: string, accent: Color3, right: boolean)
	local panel = UI.new("Frame", {
		Size = UDim2.fromScale(0.42, 1),
		Position = if right then UDim2.fromScale(0.58, 0) else UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local align = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	UI.label({
		Text = name,
		Size = UDim2.new(1, 0, 0.3, 0),
		TextXAlignment = align,
		FontFace = UI.TitleFont,
		TextColor3 = accent,
		Parent = panel,
	}, nil)
	local hp = UI.bar(panel, { Size = UDim2.new(1, 0, 0.36, 0), Position = UDim2.fromScale(0, 0.33) }, accent, right)
	local energy = UI.bar(
		panel,
		{ Size = UDim2.new(0.8, 0, 0.16, 0), Position = UDim2.fromScale(if right then 0.2 else 0, 0.75) },
		C.Violet,
		right
	)
	local ready = UI.label({
		Text = "SPECIAL!",
		Visible = false,
		Size = UDim2.new(0.18, 0, 0.2, 0),
		Position = UDim2.fromScale(if right then 0 else 0.82, 0.72),
		TextColor3 = C.Toxic,
		Parent = panel,
	})
	return { hp = hp, energy = energy, ready = ready }
end

local function touchButton(
	parent: Instance,
	text: string,
	accent: Color3,
	center: Vector2,
	size: number,
	onDown: () -> (),
	onUp: (() -> ())?,
	connections: { RBXScriptConnection }
)
	local button = UI.new("TextButton", {
		Name = text,
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(center.X, center.Y),
		Size = UDim2.fromScale(size, size),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		AutoButtonColor = false,
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.2,
		TextColor3 = C.White,
		FontFace = UI.BodyFont,
		TextScaled = true,
		Parent = parent,
	}, {
		UI.corner(UDim.new(1, 0)),
		UI.stroke(accent, 3, 0),
		UI.new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 9 }),
		UI.new("UIPadding", { PaddingLeft = UDim.new(0.12, 0), PaddingRight = UDim.new(0.12, 0) }),
	})
	local scale = UI.new("UIScale", { Parent = button })
	local held: InputObject? = nil
	local function release()
		if held then
			held = nil
			scale.Scale = 1
			button.BackgroundColor3 = C.Night
			if onUp then
				onUp()
			end
		end
	end
	button.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) and not held then
			held = input
			scale.Scale = 0.9
			button.BackgroundColor3 = accent:Lerp(C.Night, 0.5)
			onDown()
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input == held then
			release()
		end
	end)
	-- Finger vom Button gerutscht: Ende trotzdem erkennen (wichtig für gehaltenen BLOCK).
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if input == held then
				release()
			end
		end)
	)
	return button
end

-- opts: { playerName, opponent (Opponents-Eintrag), effectLabel, inputMode,
--         onLeave(), onSkip(), onEffects(), onAction(name, down) }
function HUD.open(opts)
	HUD.close()
	gui = UI.screen("ArcadeBoxingHUD", 50)
	local root = gui :: ScreenGui
	local opponent = opts.opponent

	-- Kopfzeile
	local top = UI.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.96, 0, 0, 84),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.25,
		Parent = root,
	}, {
		UI.corner(UDim.new(0, 14)),
		UI.stroke(C.Violet, 2, 0.1),
		UI.padding(8),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(980, 84) }),
	})
	local player = fighterPanel(top, opts.playerName, C.Cyan, false)
	local npc = fighterPanel(top, opponent.Name, opponent.Colors.Accent:Lerp(C.Magenta, 0.35), true)
	local timer = UI.label({
		Text = tostring(Config.Match.FightDuration),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, -0.04),
		Size = UDim2.fromScale(0.13, 0.78),
		FontFace = UI.TitleFont,
		TextColor3 = C.White,
		Parent = top,
	}, nil)
	UI.textStroke(C.Violet, 2).Parent = timer
	UI.label({
		Text = "NEON K.O.",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1.02),
		Size = UDim2.fromScale(0.13, 0.22),
		TextColor3 = C.Toxic,
		Parent = top,
	})

	-- Buttons rechts unter der Kopfzeile
	local tools = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 98),
		Size = UDim2.new(0, 280, 0, 40),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 8),
		}),
	})
	local effects = UI.button(opts.effectLabel, C.Cyan, { Size = UDim2.new(0, 120, 1, 0), Parent = tools })
	local leave = UI.button("VERLASSEN", C.Magenta, { Size = UDim2.new(0, 130, 1, 0), Parent = tools })
	effects.Activated:Connect(opts.onEffects)
	leave.Activated:Connect(opts.onLeave)

	-- Combo-Anzeige
	local combo = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.03, 0.38),
		Size = UDim2.fromScale(0.3, 0.09),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UI.TitleFont,
		TextColor3 = C.Toxic,
		Parent = root,
	})
	UI.textStroke(C.Night, 3).Parent = combo
	local comboScale = UI.new("UIScale", { Parent = combo })
	local comboName = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.03, 0.45),
		Size = UDim2.fromScale(0.3, 0.05),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Cyan,
		Parent = root,
	})

	-- Zentrale Ansage (Countdown, K.O., Ergebnis)
	local announce = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.9, 0.2),
		FontFace = UI.TitleFont,
		Parent = root,
	}, nil)
	UI.new("UITextSizeConstraint", { MaxTextSize = 120, Parent = announce })
	local announceStroke = UI.textStroke(C.Violet, 4)
	announceStroke.Parent = announce
	local announceScale = UI.new("UIScale", { Parent = announce })
	local sub = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.8, 0.06),
		FontFace = UI.TextFont,
		Parent = root,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 30, Parent = sub })
	local popup = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromScale(0.5, 0.07),
		FontFace = UI.TitleFont,
		Parent = root,
	})
	UI.textStroke(C.Night, 3).Parent = popup

	-- Intro-Karte + Überspringen
	local intro = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -90),
		Size = UDim2.new(0.5, 0, 0, 110),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.2,
		Parent = root,
	}, {
		UI.corner(UDim.new(0, 14)),
		UI.stroke(opponent.Colors.Accent, 2, 0),
		UI.padding(10),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, 110) }),
	})
	UI.label({
		Text = "VS  " .. opponent.Name,
		Size = UDim2.fromScale(1, 0.45),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UI.TitleFont,
		TextColor3 = opponent.Colors.Accent,
		Parent = intro,
	})
	UI.label({
		Text = ("%s · %s"):format(opponent.Title, opponent.Style),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 0.25),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UI.TextFont,
		Parent = intro,
	})
	UI.label({
		Text = ("Special: %s · %s"):format(
			opponent.SpecialName,
			string.rep("★", opponent.Difficulty) .. string.rep("☆", 4 - opponent.Difficulty)
		),
		Position = UDim2.fromScale(0, 0.76),
		Size = UDim2.fromScale(1, 0.22),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = UI.TextFont,
		TextColor3 = C.Cyan,
		Parent = intro,
	})
	local skip = UI.button("ÜBERSPRINGEN ▸", C.Toxic, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0, 220, 0, 46),
		Parent = root,
	})
	skip.Activated:Connect(opts.onSkip)

	-- Tastenhinweis
	local hint = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(0.9, 0, 0, 20),
		FontFace = UI.TextFont,
		TextColor3 = C.White,
		TextTransparency = 0.15,
		Parent = root,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 17, Parent = hint })

	-- Touch-Steuerung (rechts unten; linker Bereich bleibt für den Bewegungsstick frei)
	local pad = UI.new("Frame", {
		Name = "TouchPad",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromScale(0.44, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	}, {
		UI.new("UIAspectRatioConstraint", { AspectRatio = 1.15 }),
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(380, 330), MinSize = Vector2.new(250, 217) }),
	})
	local function act(name: string)
		return function()
			opts.onAction(name, true)
		end, function()
			opts.onAction(name, false)
		end
	end
	local lightDown, lightUp = act("Light")
	local heavyDown, heavyUp = act("Heavy")
	local blockDown, blockUp = act("Block")
	local dodgeDown, dodgeUp = act("Dodge")
	local specialDown, specialUp = act("Special")
	touchButton(pad, "LIGHT", C.Cyan, Vector2.new(0.7, 0.64), 0.32, lightDown, lightUp, connections)
	touchButton(pad, "HEAVY", C.Magenta, Vector2.new(0.4, 0.8), 0.23, heavyDown, heavyUp, connections)
	touchButton(pad, "BLOCK", C.Violet, Vector2.new(0.36, 0.46), 0.23, blockDown, blockUp, connections)
	touchButton(pad, "DODGE", C.White, Vector2.new(0.63, 0.27), 0.21, dodgeDown, dodgeUp, connections)
	local special =
		touchButton(pad, "SPECIAL", C.Toxic, Vector2.new(0.9, 0.25), 0.21, specialDown, specialUp, connections)

	-- Ergebnis-Button
	local continue = UI.button("WEITER", C.Toxic, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(0, 220, 0, 50),
		Visible = false,
		Parent = root,
	})
	continue.Activated:Connect(opts.onLeave)

	refs = {
		player = player,
		npc = npc,
		timer = timer,
		combo = combo,
		comboScale = comboScale,
		comboName = comboName,
		comboUntil = 0,
		announce = announce,
		announceStroke = announceStroke,
		announceScale = announceScale,
		announceUntil = 0,
		sub = sub,
		popup = popup,
		popupUntil = 0,
		intro = intro,
		skip = skip,
		hint = hint,
		pad = pad,
		special = special,
		effects = effects,
		leave = leave,
		continue = continue,
		lastCount = nil,
		fightShown = false,
		finished = false,
		clock = 0,
	}
	HUD.setInputMode(opts.inputMode)
end

function HUD.setInputMode(mode: string)
	if not refs then
		return
	end
	refs.pad.Visible = mode == "Touch"
	refs.hint.Text = Config.Input.Hints[mode] or ""
	refs.hint.Visible = mode ~= "Touch"
end

function HUD.setEffectLabel(text: string)
	if refs then
		refs.effects.Text = text
	end
end

function HUD.announce(text: string, color: Color3?, duration: number?, subText: string?)
	if not refs then
		return
	end
	local r = refs
	r.announce.Text = text
	r.announce.TextColor3 = color or C.White
	r.announceStroke.Color = (color or C.Violet):Lerp(C.Night, 0.55)
	r.announce.TextTransparency = 0
	r.announceUntil = if duration then os.clock() + duration else math.huge
	r.sub.Text = subText or ""
	r.announceScale.Scale = 1.5
	TweenService
		:Create(r.announceScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function HUD.popup(text: string, color: Color3?)
	if not refs then
		return
	end
	refs.popup.Text = text
	refs.popup.TextColor3 = color or C.Cyan
	refs.popupUntil = os.clock() + 0.7
end

function HUD.combo(count: number, name: string?)
	if not refs then
		return
	end
	if count >= 2 then
		refs.combo.Text = ("%d HITS!"):format(count)
		refs.comboUntil = os.clock() + 1.4
		refs.comboScale.Scale = 1.35
		TweenService:Create(refs.comboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if name then
		refs.comboName.Text = name
	end
end

local function countdownText(state: string, t: number, countdownEndsAt: number): string?
	if state ~= "Countdown" or countdownEndsAt <= 0 then
		return nil
	end
	local remaining = countdownEndsAt - t
	local n = math.clamp(math.ceil(remaining / Config.Match.CountdownStep), 1, 3)
	return tostring(n)
end

-- snapshot: { state, t, pHP, pMax, nHP, nMax, pEnergy, nEnergy, fightEndsAt, countdownEndsAt }
-- Rückgabe: Countdown-Zahl, wenn sie gerade gewechselt hat (für Sound).
function HUD.update(s, dt: number): string?
	if not refs then
		return nil
	end
	local r = refs
	local now = os.clock()
	UI.setBar(r.player.hp, if s.pMax > 0 then s.pHP / s.pMax else 1, dt)
	UI.setBar(r.npc.hp, if s.nMax > 0 then s.nHP / s.nMax else 1, dt)
	UI.setBar(r.player.energy, s.pEnergy / Config.Fighter.EnergyMax, dt)
	UI.setBar(r.npc.energy, s.nEnergy / Config.Fighter.EnergyMax, dt)
	local ready = s.pEnergy >= Config.Attacks.Special.EnergyCost
	r.player.ready.Visible = ready
	r.npc.ready.Visible = s.nEnergy >= Config.Attacks.Special.EnergyCost
	local stroke = r.special:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = if ready then 4 + math.sin(now * 10) * 1.5 else 2
		stroke.Transparency = if ready then 0 else 0.55
	end
	r.special.TextTransparency = if ready then 0 else 0.5

	local timeLeft = Config.Match.FightDuration
	if s.state == "Fighting" and s.fightEndsAt > 0 then
		timeLeft = math.max(0, s.fightEndsAt - s.t)
	elseif s.state == "Finished" then
		timeLeft = math.max(0, s.fightEndsAt - s.t)
		if s.fightEndsAt <= 0 then
			timeLeft = Config.Match.FightDuration
		end
	end
	r.timer.Text = tostring(math.ceil(timeLeft))
	r.timer.TextColor3 = if timeLeft <= 10 and s.state == "Fighting"
		then C.Magenta:Lerp(C.White, (math.sin(now * 8) + 1) * 0.25)
		else C.White

	local introVisible = s.state == "Intro"
	r.intro.Visible = introVisible
	r.skip.Visible = introVisible

	local changed = nil
	local count = countdownText(s.state, s.t, s.countdownEndsAt)
	if count and count ~= r.lastCount then
		r.lastCount = count
		changed = count
		HUD.announce(count, C.Cyan, Config.Match.CountdownStep)
	end
	if s.state == "Fighting" and not r.fightShown then
		r.fightShown = true
		HUD.announce("FIGHT!", C.Toxic, 0.8)
		changed = "FIGHT"
	end

	if now > r.announceUntil and r.announce.Text ~= "" then
		r.announce.Text = ""
		r.sub.Text = ""
	end
	if now > r.comboUntil then
		r.combo.Text = ""
		r.comboName.Text = ""
	end
	if now > r.popupUntil then
		r.popup.Text = ""
	end
	return changed
end

function HUD.showResult(payload)
	if not refs then
		return
	end
	refs.finished = true
	local info = RESULT_TEXT[payload.result] or RESULT_TEXT.Aborted
	local sub = ""
	if payload.result ~= "Aborted" then
		sub = ("Treffer %d · Max-Combo %d · Schaden %d"):format(
			payload.hits or 0,
			payload.maxCombo or 0,
			payload.damage or 0
		)
		if payload.unlocked then
			sub ..= ("\nNEU FREIGESCHALTET: %s"):format(payload.unlocked)
		end
	end
	local function show()
		if refs then
			HUD.announce(info[1], info[2], nil, sub)
			refs.continue.Visible = payload.result ~= "Aborted"
			refs.pad.Visible = false
		end
	end
	if payload.byKO then
		HUD.announce("K.O.!", C.Gold, 1.1)
		task.delay(1.1, show)
	elseif payload.reason == "Timeout" then
		HUD.announce("TIME!", C.Cyan, 0.9)
		task.delay(0.9, show)
	else
		show()
	end
end

function HUD.close()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if gui then
		gui:Destroy()
	end
	gui = nil
	refs = nil
end

return HUD
