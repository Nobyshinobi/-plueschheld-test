-- NEON K.O. – Client. Verbindet Server-Ereignisse mit Auswahlmenü, HUD, Kamera, Eingaben,
-- Animationen und Effekten. Alles, was während eines Kampfs am Client verändert wird, wird in
-- session.saved gesichert und beim Ende (oder bei jedem Fehler) wiederhergestellt.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("ArcadeBoxing", 30)
if not Shared then
	warn("[NEON K.O.] ReplicatedStorage.ArcadeBoxing fehlt – Client bleibt inaktiv.")
	return
end
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local Net = require(Shared:WaitForChild("Net"))
local Opponents = require(Shared:WaitForChild("Opponents"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local Motion = require(Shared:WaitForChild("Motion"))

local PoseDriver = require(script:WaitForChild("PoseDriver"))
local InputController = require(script:WaitForChild("InputController"))
local CameraController = require(script:WaitForChild("CameraController"))
local HUD = require(script:WaitForChild("HUD"))
local SelectMenu = require(script:WaitForChild("SelectMenu"))
local Effects = require(script:WaitForChild("Effects"))
local Spectator = require(script:WaitForChild("Spectator"))
local UI = require(script:WaitForChild("UI"))

local request, event = Net.clientGet(30)
if not request or not event then
	warn("[NEON K.O.] Server-Teil (ServerScriptService.ArcadeBoxing) nicht gefunden – Client bleibt inaktiv.")
	return
end

local AK = Keys.Arena
local RENDER_NAME = "ABX_Fight"

local session = nil
local seq = 0
local effectIndex = math.clamp(Config.Camera.DefaultEffectLevel, 1, #Config.Camera.EffectLevels)

local function effectLevel()
	return Config.Camera.EffectLevels[effectIndex]
end

local function fire(kind: string, a: any?, b: any?, c: any?)
	request:FireServer(kind, a, b, c)
end

PoseDriver.start(function(model: Model, attack: string, duration: number)
	Effects.telegraph(model, attack, duration)
end)
Spectator.start()
InputController.init(script)

local function eachPrompt(callback: (ProximityPrompt) -> ())
	local runtime = Workspace:FindFirstChild(Keys.RuntimeFolder)
	if not runtime then
		return
	end
	for _, d in runtime:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == Keys.Instances.Prompt then
			callback(d)
		end
	end
end

-- Sitzungsende -----------------------------------------------------------------------
local function stopSession(reason: string)
	local s = session
	if not s then
		return
	end
	session = nil
	local function try(label: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn(("[NEON K.O.] Wiederherstellung '%s' fehlgeschlagen: %s"):format(label, tostring(err)))
		end
	end
	try("render", function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
	end)
	try("input", InputController.disable)
	try("camera", CameraController.stop)
	try("hud", HUD.close)
	for _, connection in s.connections do
		connection:Disconnect()
	end
	try("align", function()
		if s.align then
			s.align:Destroy()
		end
		if s.alignAttachment then
			s.alignAttachment:Destroy()
		end
	end)
	try("humanoid", function()
		if s.humanoid.Parent and s.humanoid.Health > 0 then
			s.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, s.saved.jumpEnabled)
		end
		if s.root.Parent then
			Motion.clear(s.root)
		end
	end)
	try("backpack", function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, s.saved.backpack)
	end)
	try("mouselock", function()
		player.DevEnableMouseLock = s.saved.mouseLock
	end)
	try("prompts", function()
		for prompt, enabled in s.saved.prompts do
			if prompt.Parent then
				prompt.Enabled = enabled
			end
		end
		if s.saved.promptService ~= nil then
			ProximityPromptService.Enabled = s.saved.promptService
		end
	end)
	try("block", function()
		PoseDriver.predictBlock(s.character, nil)
	end)
	if Config.Debug.Log then
		print("[NEON K.O.] Client-Sitzung beendet:", reason)
	end
end

-- Eingaben ---------------------------------------------------------------------------
local function arenaState(s): string
	return s.folder:GetAttribute(AK.State) or "Idle"
end

local function dodgeSide(s): number
	local npcRoot = s.npc and s.npc:FindFirstChild("HumanoidRootPart")
	if npcRoot and npcRoot:IsA("BasePart") then
		local toNpc = npcRoot.Position - s.root.Position
		local flatTo = Vector3.new(toNpc.X, 0, toNpc.Z)
		if flatTo.Magnitude > 0.05 then
			local right = flatTo.Unit:Cross(Vector3.yAxis)
			local d = s.humanoid.MoveDirection:Dot(right)
			if d > 0.3 then
				return 1
			elseif d < -0.3 then
				return -1
			end
		end
	end
	s.lastDodgeSide = -(s.lastDodgeSide or 1)
	return s.lastDodgeSide
end

local function dodgeVector(s, side: number): Vector3
	local npcRoot = s.npc and s.npc:FindFirstChild("HumanoidRootPart")
	local forward = s.root.CFrame.LookVector
	if npcRoot and npcRoot:IsA("BasePart") then
		local d = npcRoot.Position - s.root.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude > 0.05 then
			forward = Vector3.new(d.X, 0, d.Z).Unit
		end
	end
	local right = forward:Cross(Vector3.yAxis)
	return right * side
end

local function performAction(s, name: string)
	local t = Workspace:GetServerTimeNow()
	local f = s.predicted
	CombatRules.settle(f, t)
	-- Energie kennt nur der Server; für die Vorhersage den replizierten Wert übernehmen.
	f.energy = s.folder:GetAttribute(AK.PlayerEnergy) or 0
	local ok = CombatRules.canStart(f, name, t, Config)
	seq += 1
	local side = if name == "Dodge" then dodgeSide(s) else 0
	fire("Action", name, seq, side)
	if ok then
		CombatRules.begin(f, name, t, Config, 0)
		s.lastPredictedSeq = seq
		PoseDriver.predict(s.character, name, seq, { dodgeSide = side })
		if name == "Dodge" then
			local speed = Config.Dodge.Distance / (Config.Dodge.Duration * 0.6)
			Motion.push(s.root, dodgeVector(s, side) * speed, Config.Dodge.Duration * 0.6)
		elseif CombatRules.isAttack(name) then
			Effects.sound(Config.Sounds.Swing, s.root, 0.35)
		end
	end
end

local function onInput(name: string, down: boolean)
	local s = session
	if not s then
		return
	end
	local state = arenaState(s)
	if name == "Leave" then
		if down then
			local token = {}
			s.leaveToken = token
			task.delay(Config.Input.LeaveHoldTime, function()
				if session == s and s.leaveToken == token then
					fire("Leave")
				end
			end)
		else
			s.leaveToken = nil
		end
		return
	end
	if state == "Intro" then
		if down and (name == "Skip" or name == "Light") then
			fire("SkipIntro")
			CameraController.skipIntro()
		end
		return
	end
	if state == "Finished" then
		if down and (name == "Skip" or name == "Light") and s.resultShown then
			fire("Leave")
		end
		return
	end
	if state ~= "Fighting" then
		return
	end
	if name == "Block" then
		if down ~= s.blockHeld then
			s.blockHeld = down
			s.blockRetryAt = Workspace:GetServerTimeNow() + 0.25
			fire("Action", if down then "BlockStart" else "BlockEnd")
			PoseDriver.predictBlock(s.character, down)
		end
		return
	end
	if not down or name == "Skip" then
		return
	end
	performAction(s, name)
end

local function cycleEffects()
	effectIndex = effectIndex % #Config.Camera.EffectLevels + 1
	HUD.setEffectLabel(effectLevel().Label)
end

-- Laufendes Update ---------------------------------------------------------------------
local function update(dt: number)
	local s = session
	if not s then
		return
	end
	local t = Workspace:GetServerTimeNow()
	local folder = s.folder
	local state = arenaState(s)

	-- Wachhund: Server-Match weg oder gewechselt → lokal sauber beenden.
	local matchId = folder:GetAttribute(AK.MatchId) or 0
	if matchId ~= s.matchId or state == "Idle" or not folder.Parent then
		s.lostFor += dt
		if s.lostFor > 1.5 then
			stopSession("watchdog")
			return
		end
	else
		s.lostFor = 0
	end
	if not s.root.Parent or not s.humanoid.Parent or s.humanoid.Health <= 0 then
		stopSession("character")
		return
	end

	-- Zum Gegner drehen + weich in der Kampfzone halten
	local npcRoot = s.npc and s.npc:FindFirstChild("HumanoidRootPart")
	if npcRoot and npcRoot:IsA("BasePart") then
		local from = s.root.Position
		local to = Vector3.new(npcRoot.Position.X, from.Y, npcRoot.Position.Z)
		if (to - from).Magnitude > 0.05 then
			s.align.CFrame = CFrame.lookAt(from, to).Rotation
		end
	end
	if state == "Fighting" then
		local localPos = s.arenaCFrame:PointToObjectSpace(s.root.Position)
		local cx = math.clamp(localPos.X, -s.fightHalfX, s.fightHalfX)
		local cz = math.clamp(localPos.Z, -s.fightHalfZ, s.fightHalfZ)
		if math.abs(cx - localPos.X) > 0.05 or math.abs(cz - localPos.Z) > 0.05 then
			local clamped = s.arenaCFrame:PointToWorldSpace(Vector3.new(cx, localPos.Y, cz))
			s.root.CFrame = CFrame.new(clamped) * s.root.CFrame.Rotation
		end
	end

	-- Deckung gehalten, aber vom Server (z. B. wegen Hitstun) nicht angenommen: erneut anfragen.
	if state == "Fighting" and s.blockHeld and s.character:GetAttribute(Keys.Fighter.Block) ~= true then
		if t >= (s.blockRetryAt or 0) then
			s.blockRetryAt = t + 0.2
			fire("Action", "BlockStart")
		end
	end

	if state ~= "Intro" and s.lastState == "Intro" then
		CameraController.fight()
	end
	s.lastState = state

	local beep = HUD.update({
		state = state,
		t = t,
		pHP = folder:GetAttribute(AK.PlayerHP) or 0,
		pMax = folder:GetAttribute(AK.PlayerMaxHP) or 0,
		nHP = folder:GetAttribute(AK.NpcHP) or 0,
		nMax = folder:GetAttribute(AK.NpcMaxHP) or 0,
		pEnergy = folder:GetAttribute(AK.PlayerEnergy) or 0,
		nEnergy = folder:GetAttribute(AK.NpcEnergy) or 0,
		fightEndsAt = folder:GetAttribute(AK.FightEndsAt) or 0,
		countdownEndsAt = folder:GetAttribute(AK.CountdownEndsAt) or 0,
	}, dt)
	if beep then
		Effects.sound(Config.Sounds.Countdown, nil, if beep == "FIGHT" then 1 else 0.6)
	end
end

-- Sitzungsstart ----------------------------------------------------------------------
local function startSession(payload)
	stopSession("restart")
	SelectMenu.close()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = payload.folder
	local def = Opponents.Get(payload.opponentId)
	if not character or not humanoid or not root or not root:IsA("BasePart") or not folder or not def then
		fire("Leave")
		return
	end
	local npc = payload.npc
	if not npc then
		npc = folder:WaitForChild(payload.npcName, 5)
	end

	local s = {
		matchId = payload.matchId,
		folder = folder,
		npc = npc,
		character = character,
		humanoid = humanoid,
		root = root,
		arenaCFrame = payload.arenaCFrame,
		fightHalfX = payload.fightHalfX,
		fightHalfZ = payload.fightHalfZ,
		connections = {},
		saved = { prompts = {} },
		predicted = CombatRules.newFighter(Config.Fighter.PlayerMaxHP, Config, 1),
		lostFor = 0,
		lastState = "Intro",
		blockHeld = false,
		resultShown = false,
	}
	session = s

	-- Lokale Zustände sichern und für den Kampf anpassen
	s.saved.backpack = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	s.saved.jumpEnabled = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	s.saved.mouseLock = player.DevEnableMouseLock
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	eachPrompt(function(prompt)
		s.saved.prompts[prompt] = prompt.Enabled
		prompt.Enabled = false
	end)
	s.saved.promptService = ProximityPromptService.Enabled
	if Config.Input.HidePromptsDuringFight then
		ProximityPromptService.Enabled = false
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "ABX_FaceAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "ABX_Face"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.Responsiveness = 45
	align.MaxTorque = 1e7
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	s.align = align
	s.alignAttachment = attachment

	HUD.open({
		playerName = player.DisplayName,
		opponent = def,
		effectLabel = effectLevel().Label,
		inputMode = InputController.preferred(),
		onLeave = function()
			fire("Leave")
		end,
		onSkip = function()
			fire("SkipIntro")
			CameraController.skipIntro()
		end,
		onEffects = cycleEffects,
		onAction = onInput,
	})
	table.insert(s.connections, InputController.onPreferredChanged(HUD.setInputMode))

	local exclude = { character, folder }
	local fx = Workspace:FindFirstChild("ABX_ClientFX")
	if fx then
		table.insert(exclude, fx)
	end
	CameraController.start({ root = root, npc = npc, character = character, exclude = exclude }, payload.introEndsAt)
	InputController.enable(onInput)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Character.Value + 1, function(dt: number)
		local ok, err = pcall(update, dt)
		if not ok then
			warn("[NEON K.O.] Client-Fehler im Kampf – Kampf wird verlassen:", err)
			fire("Leave")
			stopSession("error")
		end
	end)
	table.insert(
		s.connections,
		player.CharacterAdded:Connect(function()
			stopSession("respawn")
		end)
	)
	table.insert(
		s.connections,
		humanoid.Died:Connect(function()
			stopSession("died")
		end)
	)
end

-- Server-Ereignisse ------------------------------------------------------------------
local handlers = {}

function handlers.OpenSelect(payload)
	SelectMenu.open(payload, function(id: number)
		fire("SelectOpponent", id)
	end, function()
		fire("CancelSelect")
		SelectMenu.close()
	end)
end

function handlers.CloseSelect()
	SelectMenu.close()
end

function handlers.Notice(payload)
	UI.toast(tostring(payload.text), payload.kind)
end

function handlers.Queue(payload)
	UI.queueChip(payload.position or 0, function()
		fire("LeaveQueue")
		UI.queueChip(0, function() end)
	end)
end

function handlers.MatchSetup(payload)
	UI.queueChip(0, function() end)
	startSession(payload)
end

function handlers.Hit(payload)
	Effects.onHit(payload)
	local s = session
	if not s or payload.matchId ~= s.matchId then
		return
	end
	local t = Workspace:GetServerTimeNow()
	local def = Config.Attacks[payload.attack]
	local level = effectLevel()
	local landed = payload.outcome == "Hit" or payload.outcome == "Burst" or payload.outcome == "GuardBreak"
	if landed or payload.outcome == "Blocked" then
		if def then
			local scale = if payload.outcome == "Blocked" then 0.4 else 1
			CameraController.shake(def.Shake * scale, level.Shake)
			if level.Hitstop > 0 and payload.outcome ~= "Blocked" then
				PoseDriver.freeze({ payload.attacker, payload.target }, def.Hitstop * level.Hitstop)
			end
		end
	end

	local f = s.predicted
	if payload.attackerSide == "player" then
		if payload.outcome == "Hit" or payload.outcome == "Burst" then
			f.cancelUntil = t + Config.Fighter.HitCancelWindow
			HUD.combo(payload.combo or 0, payload.comboName)
		elseif payload.outcome == "PerfectDodge" then
			HUD.popup("AUSGEWICHEN!", UI.Colors.White)
		elseif payload.outcome == "Blocked" then
			HUD.popup("GEBLOCKT", UI.Colors.Violet)
		end
	else
		if payload.outcome == "PerfectDodge" then
			HUD.popup("PERFECT DODGE! +ENERGIE", UI.Colors.Toxic)
		elseif payload.outcome == "GuardBreak" then
			HUD.popup("DECKUNG GEBROCHEN!", UI.Colors.Gold)
		end
		if landed and (payload.stun or 0) > 0 then
			f.actionId += 1
			f.action = "Hitstun"
			f.actionStartedAt = t
			f.actionEndsAt = t + payload.stun
			f.stunUntil = t + payload.stun
			f.blocking = false
		end
		if typeof(payload.knockback) == "Vector3" and payload.knockback.Magnitude > 0.1 then
			Motion.push(s.root, payload.knockback, 0.14)
		end
	end
end

function handlers.Reject(payload)
	local s = session
	-- Nur die zuletzt vorhergesagte Aktion zurücknehmen; abgelehnte Zusatz-Eingaben (Spam)
	-- dürfen eine laufende, gültige Vorhersage nicht abbrechen.
	if s and typeof(payload.seq) == "number" and payload.seq == s.lastPredictedSeq then
		PoseDriver.cancelPrediction(s.character, payload.seq)
		s.lastPredictedSeq = nil
		local f = s.predicted
		f.action = "Idle"
		f.actionEndsAt = 0
		table.clear(f.cooldowns)
	end
end

function handlers.Result(payload)
	local s = session
	if not s or payload.matchId ~= s.matchId then
		return
	end
	s.resultShown = true
	HUD.showResult(payload)
	local winner = nil
	if payload.result == "Victory" then
		winner = s.character
	elseif payload.result == "Defeat" then
		winner = s.npc
	end
	if winner then
		task.delay(if payload.byKO then 0.6 else 0.3, function()
			if session == s then
				CameraController.showResult(winner)
			end
		end)
	end
end

function handlers.Cleanup(payload)
	local s = session
	if s and (payload.matchId == nil or payload.matchId == s.matchId) then
		stopSession("server")
	end
	SelectMenu.close()
end

event.OnClientEvent:Connect(function(kind: any, payload: any)
	local handler = typeof(kind) == "string" and handlers[kind]
	if handler then
		local ok, err = pcall(handler, if typeof(payload) == "table" then payload else {})
		if not ok then
			warn("[NEON K.O.] Fehler bei Ereignis", kind, err)
		end
	end
end)
