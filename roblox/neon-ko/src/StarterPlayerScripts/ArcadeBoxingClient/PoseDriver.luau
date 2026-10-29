-- Prozedurale Kampfanimationen für alle Kämpfer (eigener Charakter, NPC, andere Spieler im Ring).
-- Liest die vom Server replizierten Aktionsattribute und überschreibt Motor6D.Transform in
-- RunService.Stepped (nach dem Animator, vor dem Rendern). Motor6D.Transform repliziert nicht –
-- deshalb läuft dieser Treiber auf jedem Client und alle sehen dieselben, servergetakteten Posen.
-- Sind in Config.Animations eigene Animation-IDs eingetragen, werden diese stattdessen abgespielt.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local Poses = require(Shared:WaitForChild("Poses"))

local PoseDriver = {}

local FA = Keys.Fighter
local localPlayer = Players.LocalPlayer
local rigs = {}
local started = false
local onTelegraph: ((Model, string, number) -> ())? = nil

-- Aktion → Animationsschlüssel in Config.Animations
local ANIMATION_KEYS = {
	Light = "Light",
	Heavy = "Heavy",
	Special = "Special",
	Dodge = "Dodge",
	Hitstun = "Hit",
	GuardBreak = "Hit",
	KO = "KO",
	Victory = "Victory",
	Block = "Block",
	Idle = "Guard",
}

-- Wie stark der Unterkörper je Aktion überschrieben wird (0 = Laufanimation des Avatars bleibt).
local LEG_WEIGHT = {
	Idle = 0,
	Block = 0.6,
	Light = 0.35,
	Heavy = 0.65,
	Special = 1,
	Dodge = 1,
	Hitstun = 0.5,
	GuardBreak = 0.6,
	KO = 1,
	Victory = 0.5,
	Taunt = 0.3,
}

local function hasAnimation(key: string?): boolean
	local id = key and Config.Animations[key]
	return typeof(id) == "string" and id ~= ""
end

local function buildRig(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local map = if r15 then Poses.R15 else Poses.R6
	local motors = {}
	for role, spec in map do
		local part = model:FindFirstChild(spec[1])
		local motor = part and part:FindFirstChild(spec[2])
		if motor and motor:IsA("Motor6D") then
			motors[role] = motor
		end
	end
	if next(motors) == nil then
		return nil
	end
	local isNpc = model:GetAttribute(FA.Role) == "NPC"
	local owner = Players:GetPlayerFromCharacter(model)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		r15 = r15,
		motors = motors,
		isNpc = isNpc,
		isLocal = owner == localPlayer,
		isOtherPlayer = owner ~= nil and owner ~= localPlayer,
		scale = math.max(0.5, root.Size.Y / 2),
		keys = Poses.track("Idle", Config),
		loop = true,
		action = "Idle",
		start = 0,
		legWeight = 0,
		predictedSeq = {},
		prediction = nil,
		blockPredicted = nil,
		frozenUntil = 0,
		frozenAt = 0,
		frozenTotal = 0,
		walkPhase = 0,
		tracks = {},
		playingTrack = nil,
		connections = {},
	}
end

local function stopTrack(rig)
	if rig.playingTrack then
		rig.playingTrack:Stop(0.1)
		rig.playingTrack = nil
	end
end

-- Spielt eine konfigurierte Animation (falls vorhanden). Nicht für fremde Spielercharaktere:
-- deren Animationen repliziert der Besitzer-Client selbst.
local function playConfigured(rig, action: string, duration: number?): boolean
	local key = ANIMATION_KEYS[action]
	if not hasAnimation(key) or rig.isOtherPlayer then
		return false
	end
	local animator = rig.humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local track = rig.tracks[key]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.Animations[key]
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not loaded then
			return false
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		rig.tracks[key] = track
	end
	stopTrack(rig)
	track:Play(0.06)
	if duration and duration > 0 and track.Length > 0 then
		track:AdjustSpeed(track.Length / duration)
	end
	rig.playingTrack = track
	return true
end

local function setAction(rig, action: string, start: number, opts)
	local keys, loop = Poses.track(action, Config, opts)
	rig.action = action
	rig.keys = keys
	rig.loop = loop
	rig.start = start
	rig.frozenTotal = 0
	rig.legWeight = LEG_WEIGHT[action] or 0.5
	rig.usingTrack = playConfigured(rig, action, if loop then nil else Poses.duration(keys))
end

local function readServerAction(rig)
	local model = rig.model
	local action = model:GetAttribute(FA.Action) or "Idle"
	local start = model:GetAttribute(FA.ActionStart) or 0
	local seq = model:GetAttribute(FA.Seq) or 0
	local extra = model:GetAttribute(FA.ExtraWindup) or 0
	local side = model:GetAttribute(FA.DodgeSide) or 0
	local duration = model:GetAttribute(FA.ActionDuration) or -1

	-- Eigene, bereits vorhergesagte Aktion nicht doppelt starten
	if rig.isLocal and seq ~= 0 and rig.predictedSeq[seq] then
		rig.predictedSeq[seq] = nil
		return
	end
	rig.prediction = nil
	setAction(rig, action, start, {
		extraWindup = extra,
		dodgeSide = side,
		duration = if duration > 0 then duration else nil,
	})
	local telegraph = model:GetAttribute(FA.Telegraph)
	if onTelegraph and typeof(telegraph) == "string" and telegraph ~= "" then
		local def = Config.Attacks[telegraph]
		if def then
			onTelegraph(model, telegraph, def.Windup + extra)
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local rig = buildRig(model)
	if not rig then
		return
	end
	rigs[model] = rig
	table.insert(
		rig.connections,
		model:GetAttributeChangedSignal(FA.ActionId):Connect(function()
			readServerAction(rig)
		end)
	)
	if model:GetAttribute(FA.ActionId) then
		readServerAction(rig)
	end
end

local function untrack(model: Instance)
	local rig = rigs[model]
	if not rig then
		return
	end
	rigs[model] = nil
	for _, connection in rig.connections do
		connection:Disconnect()
	end
	stopTrack(rig)
	for _, t in rig.tracks do
		pcall(function()
			t:Destroy()
		end)
	end
end

-- Eigene Eingabe sofort darstellen (Server bestätigt später mit derselben Sequenznummer).
function PoseDriver.predict(model: Model, action: string, seq: number, opts)
	local rig = rigs[model]
	if not rig then
		return
	end
	rig.predictedSeq[seq] = true
	rig.prediction = seq
	setAction(rig, action, Workspace:GetServerTimeNow(), opts)
end

function PoseDriver.cancelPrediction(model: Model, seq: number)
	local rig = rigs[model]
	if rig and rig.prediction == seq then
		rig.prediction = nil
		rig.predictedSeq[seq] = nil
		setAction(rig, "Idle", Workspace:GetServerTimeNow(), nil)
	end
end

function PoseDriver.predictBlock(model: Model, on: boolean?)
	local rig = rigs[model]
	if rig then
		rig.blockPredicted = on
	end
end

-- Kurzer Hitstop: Posen der beteiligten Kämpfer frieren für duration Sekunden ein.
function PoseDriver.freeze(models: { Instance }, duration: number)
	if duration <= 0 then
		return
	end
	local t = Workspace:GetServerTimeNow()
	for _, model in models do
		local rig = rigs[model]
		if rig and t >= rig.frozenUntil then
			rig.frozenAt = t
			rig.frozenUntil = t + duration
			rig.frozenTotal += duration
		end
	end
end

local function withWalk(rig, pose, t: number, dt: number)
	-- Einfacher Boxer-Schritt für NPCs (sie haben kein Animate-Skript).
	local v = rig.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local amount = math.clamp(speed / 10, 0, 1)
	rig.walkPhase += dt * (4 + speed * 0.9)
	local s = math.sin(rig.walkPhase)
	local bounce = math.sin(t * 7) * 0.05
	local out = table.clone(pose)
	local function add(joint: string, drx: number, dpy: number?)
		local base = out[joint] or {}
		out[joint] = {
			rx = (base.rx or 0) + drx,
			ry = base.ry,
			rz = base.rz,
			px = base.px,
			py = (base.py or 0) + (dpy or 0),
			pz = base.pz,
		}
	end
	add("Root", 0, bounce + math.abs(s) * 0.08 * amount)
	add("RHip", s * 24 * amount)
	add("LHip", -s * 24 * amount)
	add("RKnee", -math.max(0, -s) * 32 * amount)
	add("LKnee", -math.max(0, s) * 32 * amount)
	return out
end

local function r6Adjust(pose)
	-- R6: Ellbogen in die Schulter falten, Taille in Root.
	local out = table.clone(pose)
	for _, side in { "R", "L" } do
		local shoulder = out[side .. "Shoulder"]
		local elbow = out[side .. "Elbow"]
		if shoulder and elbow and elbow.rx then
			out[side .. "Shoulder"] = {
				rx = (shoulder.rx or 0) + elbow.rx * Poses.R6ElbowFold,
				ry = shoulder.ry,
				rz = shoulder.rz,
			}
		end
	end
	local waist = out.Waist
	if waist then
		local root = out.Root or {}
		local f = Poses.R6WaistFold
		out.Root = {
			rx = (root.rx or 0) + (waist.rx or 0) * f,
			ry = (root.ry or 0) + (waist.ry or 0) * f,
			rz = (root.rz or 0) + (waist.rz or 0) * f,
			px = root.px,
			py = root.py,
			pz = root.pz,
		}
	end
	return out
end

local function stepRig(rig, t: number, dt: number)
	local model = rig.model
	if not model.Parent or not rig.root.Parent then
		return
	end
	local sampleT
	if t < rig.frozenUntil then
		sampleT = rig.frozenAt - rig.start - (rig.frozenTotal - (rig.frozenUntil - rig.frozenAt))
	else
		sampleT = t - rig.start - rig.frozenTotal
	end

	local keys = rig.keys
	local finished = not rig.loop and sampleT >= Poses.duration(keys)
	if finished and rig.action ~= "Idle" then
		rig.action = "Idle"
		rig.keys = Poses.track("Idle", Config)
		rig.loop = true
		rig.start = t
		rig.legWeight = 0
		rig.frozenTotal = 0
		stopTrack(rig)
		rig.usingTrack = false
		keys = rig.keys
		sampleT = 0
	end

	-- Deckung halten (Server-Attribut oder eigene Vorhersage)
	local blocking = model:GetAttribute(FA.Block) == true
	if rig.isLocal and rig.blockPredicted ~= nil then
		blocking = rig.blockPredicted
	end
	local pose
	local legWeight = rig.legWeight
	if rig.action == "Idle" and blocking then
		pose = Poses.Library.Block
		legWeight = LEG_WEIGHT.Block
	else
		pose = Poses.sample(keys, math.max(0, sampleT))
	end
	if rig.usingTrack then
		return -- konfigurierte Animation läuft über den Animator
	end

	if rig.isNpc then
		legWeight = 1
		if rig.action == "Idle" or rig.action == "Light" or rig.action == "Heavy" then
			pose = withWalk(rig, pose, t, dt)
		end
	elseif rig.action == "Idle" and not blocking then
		local out = table.clone(pose)
		local waist = out.Waist or {}
		out.Waist = { rx = (waist.rx or 0) + math.sin(t * 7) * 1.5, ry = waist.ry, rz = waist.rz }
		pose = out
	end
	if not rig.r15 then
		pose = r6Adjust(pose)
	end

	for role, motor in rig.motors do
		local jp = pose[role]
		local weight = if Poses.LegJoints[role] then legWeight else 1
		if weight > 0.001 then
			local desired = if jp then Poses.toCFrame(jp, rig.scale) else CFrame.identity
			local q = motor.C0.Rotation
			local target = q:Inverse() * desired * q
			if weight >= 0.999 then
				motor.Transform = target
			else
				motor.Transform = motor.Transform:Lerp(target, weight)
			end
		end
	end
end

function PoseDriver.start(telegraphCallback: ((Model, string, number) -> ())?)
	if started then
		return
	end
	started = true
	onTelegraph = telegraphCallback
	for _, model in CollectionService:GetTagged(Keys.FighterTag) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal(Keys.FighterTag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Keys.FighterTag):Connect(untrack)

	RunService.Stepped:Connect(function(_time: number, dt: number)
		if next(rigs) == nil then
			return
		end
		local t = Workspace:GetServerTimeNow()
		for model, rig in rigs do
			if not model.Parent then
				untrack(model)
			else
				local ok, err = pcall(stepRig, rig, t, dt)
				if not ok then
					warn("[NEON K.O.] Pose-Fehler, Animation für", model.Name, "deaktiviert:", err)
					untrack(model)
				end
			end
		end
	end)
end

function PoseDriver.isTracked(model: Instance): boolean
	return rigs[model] ~= nil
end

return PoseDriver
