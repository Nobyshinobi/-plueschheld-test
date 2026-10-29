--[[
NEON K.O. · Werkzeug 04 · R15-Animationen für den Animation Editor vorbereiten

Das Minispiel läuft OHNE veröffentlichte Animationen (prozedurale Posen aus Poses.luau).
Wer echte AnimationTracks möchte, erzeugt mit diesem Werkzeug aus denselben Posen und
Zeitachsen KeyframeSequences, verfeinert sie im Animation Editor und veröffentlicht sie SELBST.

Voraussetzung: ReplicatedStorage.ArcadeBoxing ist installiert.
Anwendung:
  1. Avatar › Rig Builder › R15 Block-Rig einfügen und im Explorer markieren (optional, aber
     empfohlen: dann stimmen die Gelenkachsen exakt).
  2. Datei in die Befehlsleiste einfügen, Enter.
  3. Ergebnis: ServerStorage.RBX_ANIMSAVES.<RigName>.NEONKO_* (das ist der Speicherort,
     den der Animation Editor unter "Load" anzeigt).
  4. Im Animation Editor: Rig wählen › ⋯ › Load › NEONKO_Light usw. › anpassen ›
     ⋯ › Publish to Roblox. Die erhaltene ID in Config.Animations eintragen, z. B.
     Light = "rbxassetid://1234567890". Keine fremden oder erfundenen IDs verwenden.
Es werden keine Assets hochgeladen und keine Kosten verursacht.
]]

local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Shared = game:GetService("ReplicatedStorage"):FindFirstChild("ArcadeBoxing")
if not Shared then
	warn("[NEON K.O.] ReplicatedStorage.ArcadeBoxing fehlt – bitte zuerst installieren.")
	return
end
local Poses = require(Shared:WaitForChild("Poses"))
local Config = require(Shared:WaitForChild("Config"))

local ANIMATIONS = {
	{ key = "Guard", action = "Idle", loop = true },
	{ key = "Light", action = "Light", loop = false },
	{ key = "Heavy", action = "Heavy", loop = false },
	{ key = "Special", action = "Special", loop = false },
	{ key = "Dodge", action = "Dodge", loop = false, opts = { dodgeSide = -1 } },
	{ key = "Hit", action = "Hitstun", loop = false },
	{ key = "Block", action = "Block", loop = true },
	{ key = "KO", action = "KO", loop = true },
	{ key = "Victory", action = "Victory", loop = true },
}

-- Pose-Hierarchie eines R15-Rigs (Teilname → Kinder)
local HIERARCHY = {
	LowerTorso = {
		UpperTorso = {
			Head = {},
			RightUpperArm = { RightLowerArm = { RightHand = {} } },
			LeftUpperArm = { LeftLowerArm = { LeftHand = {} } },
		},
		RightUpperLeg = { RightLowerLeg = { RightFoot = {} } },
		LeftUpperLeg = { LeftLowerLeg = { LeftFoot = {} } },
	},
}

local ROLE_BY_PART = {}
for role, spec in Poses.R15 do
	ROLE_BY_PART[spec[1]] = { role = role, motor = spec[2] }
end

local EASE = {
	linear = { Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In },
	smooth = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.InOut },
	out = { Enum.PoseEasingStyle.Cubic, Enum.PoseEasingDirection.Out },
}

local rig = Selection:Get()[1]
local rotations = {}
if rig and rig:IsA("Model") and rig:FindFirstChildOfClass("Humanoid") then
	for partName, info in ROLE_BY_PART do
		local part = rig:FindFirstChild(partName)
		local motor = part and part:FindFirstChild(info.motor)
		if motor and motor:IsA("Motor6D") then
			rotations[partName] = motor.C0.Rotation
		end
	end
	print("[NEON K.O.] Gelenkachsen aus Rig übernommen:", rig:GetFullName())
else
	rig = nil
	print("[NEON K.O.] Kein Rig ausgewählt – Standard-R15-Gelenkachsen werden angenommen.")
end

local function jointCFrame(partName: string, pose): CFrame
	local info = ROLE_BY_PART[partName]
	local jp = info and pose[info.role]
	local desired = if jp then Poses.toCFrame(jp, 1) else CFrame.identity
	local q = rotations[partName] or CFrame.identity
	return q:Inverse() * desired * q
end

local function buildPose(name: string, children, pose, ease): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.Weight = 1
	p.CFrame = if name == "HumanoidRootPart" then CFrame.identity else jointCFrame(name, pose)
	p.EasingStyle = ease[1]
	p.EasingDirection = ease[2]
	for childName, grandChildren in children do
		p:AddSubPose(buildPose(childName, grandChildren, pose, ease))
	end
	return p
end

local function buildSequence(entry): KeyframeSequence
	local keys = Poses.track(entry.action, Config, entry.opts)
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = "NEONKO_" .. entry.key
	kfs.Loop = entry.loop
	kfs.Priority = Enum.AnimationPriority.Action
	local times = {}
	for i, k in keys do
		-- Easing gilt vom aktuellen Keyframe zum nächsten
		local nextKey = keys[i + 1]
		table.insert(times, { t = k.t, ease = EASE[nextKey and nextKey.ease or "linear"] or EASE.linear })
	end
	if #times == 1 then
		table.insert(times, { t = 1, ease = EASE.linear })
	end
	for _, entryTime in times do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = entryTime.t
		local pose = Poses.sample(keys, entryTime.t)
		keyframe:AddPose(buildPose("HumanoidRootPart", HIERARCHY, pose, entryTime.ease))
		keyframe.Parent = kfs
	end
	return kfs
end

local recording = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("NEON K.O. Animationen", "NEON K.O. Animationen")
end)
local ok, err = pcall(function()
	local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	if not saves then
		saves = Instance.new("Model")
		saves.Name = "RBX_ANIMSAVES"
		saves.Parent = ServerStorage
	end
	local rigName = if rig then rig.Name else "NEONKO_Rig"
	local target = saves:FindFirstChild(rigName)
	if not target then
		target = Instance.new("ObjectValue")
		target.Name = rigName
		target.Parent = saves
	end
	if rig and target:IsA("ObjectValue") then
		target.Value = rig
	end
	for _, entry in ANIMATIONS do
		local existing = target:FindFirstChild("NEONKO_" .. entry.key)
		if existing then
			existing.Parent = nil -- per Strg+Z wiederherstellbar
		end
		local kfs = buildSequence(entry)
		kfs.Parent = target
		print(
			("   %s · %.2f s%s"):format(
				kfs.Name,
				kfs:GetKeyframes()[#kfs:GetKeyframes()].Time,
				if entry.loop then " · Loop" else ""
			)
		)
	end
	print("[NEON K.O.] KeyframeSequences gespeichert unter", target:GetFullName())
	print(
		"[NEON K.O.] Nächster Schritt: Animation Editor › Load › NEONKO_* › Publish to Roblox › ID in Config.Animations eintragen."
	)
end)
if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if not ok then
	warn("[NEON K.O.] Fehler:", err)
end
