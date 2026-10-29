-- Lokale Kampfkamera: kurzes Intro (≤ 3 s, überspringbar), 3D-Schulterperspektive im Kampf,
-- Ergebnis-Orbit. Speichert CameraType/Subject/FOV vorher und stellt sie danach exakt wieder her.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))

local CameraController = {}

local BIND_NAME = "ABX_Camera"
local cfg = Config.Camera

local active = nil

local function damp(current: CFrame, target: CFrame, rate: number, dt: number): CFrame
	local alpha = 1 - math.exp(-rate * dt)
	return current:Lerp(target, alpha)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Kamera nicht durch Wände des Boxstands schieben.
local function popper(focus: Vector3, desired: Vector3, exclude: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local dir = desired - focus
	local hit = Workspace:Raycast(focus, dir, params)
	if hit and hit.Instance.Transparency < 0.6 and hit.Instance.CanCollide then
		return hit.Position - dir.Unit * 0.6
	end
	return desired
end

-- session: { root: BasePart, npc: Model, character: Model, exclude: {Instance} }
function CameraController.start(session, introEndsAt: number)
	CameraController.stop()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	active = {
		session = session,
		saved = {
			cameraType = camera.CameraType,
			subject = camera.CameraSubject,
			fov = camera.FieldOfView,
			cframe = camera.CFrame,
		},
		mode = "Intro",
		introStart = Workspace:GetServerTimeNow(),
		introEndsAt = introEndsAt,
		shake = 0,
		shakeTime = 0,
		effectScale = 1,
		resultTarget = nil,
		resultStart = 0,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = cfg.FieldOfView
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local ok, err = pcall(CameraController.update, dt)
		if not ok then
			warn("[NEON K.O.] Kamera-Fehler, Standardkamera wird wiederhergestellt:", err)
			CameraController.stop()
		end
	end)
end

local function fightCFrame(session): (CFrame?, Vector3?)
	local root = session.root
	local npcRoot = session.npc and session.npc:FindFirstChild("HumanoidRootPart")
	if not root or not root.Parent or not npcRoot or not npcRoot:IsA("BasePart") then
		return nil, nil
	end
	local p, n = root.Position, npcRoot.Position
	local toNpc = flat(n - p)
	local dist = toNpc.Magnitude
	local forward = if dist > 0.05 then toNpc.Unit else flat(root.CFrame.LookVector).Unit
	local right = forward:Cross(Vector3.yAxis)
	local focus = p:Lerp(n, 0.45) + Vector3.new(0, 1.6, 0)
	local back = cfg.Distance + math.max(0, dist - 5) * cfg.ExtraDistancePerStud
	local pos = p - forward * back + right * cfg.SideOffset + Vector3.new(0, cfg.Height, 0)
	pos = popper(focus, pos, session.exclude)
	return CFrame.lookAt(pos, focus), focus
end

function CameraController.update(dt: number)
	if not active then
		return
	end
	local camera = Workspace.CurrentCamera
	local session = active.session
	local t = Workspace:GetServerTimeNow()
	local target

	if active.mode == "Intro" then
		local npcRoot = session.npc and session.npc:FindFirstChild("HumanoidRootPart")
		local root = session.root
		if npcRoot and npcRoot:IsA("BasePart") and root.Parent then
			local span = math.max(0.5, active.introEndsAt - active.introStart)
			local a = math.clamp((t - active.introStart) / span, 0, 1)
			if a < 0.5 then
				-- Shot 1: langsamer Schwenk um den Gegner
				local k = a / 0.5
				local face = npcRoot.CFrame
				local angle = math.rad(-35 + 70 * k)
				local offset = CFrame.Angles(0, angle, 0) * Vector3.new(0, 0.6, -6.5)
				local pos = face:PointToWorldSpace(offset)
				target = CFrame.lookAt(pos, npcRoot.Position + Vector3.new(0, 1.3, 0))
			else
				-- Shot 2: Spieler vorstellen, dann in die Kampfposition
				local k = (a - 0.5) / 0.5
				local face = root.CFrame
				local pos = face:PointToWorldSpace(Vector3.new(2.5, 1.2, -6))
				local intro = CFrame.lookAt(pos, root.Position + Vector3.new(0, 1.2, 0))
				local fight = fightCFrame(session)
				target = if fight then intro:Lerp(fight, k * k) else intro
			end
			camera.CFrame = if t - active.introStart < 0.05 then target else damp(camera.CFrame, target, 12, dt)
		end
		if t >= active.introEndsAt then
			active.mode = "Fight"
		end
		return
	elseif active.mode == "Result" and active.resultTarget then
		local model = active.resultTarget
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local k = t - active.resultStart
			local angle = k * 0.35
			local pos = root.Position + Vector3.new(math.sin(angle) * 8, 3.2, math.cos(angle) * 8)
			target = CFrame.lookAt(pos, root.Position + Vector3.new(0, 1.2, 0))
		end
	else
		target = fightCFrame(session)
	end

	if target then
		local cf = damp(camera.CFrame, target, cfg.Damping, dt)
		if active.shake > 0.001 then
			active.shakeTime += dt
			local s = active.shake * active.effectScale
			local f = cfg.ShakeFrequency
			local rx = math.noise(active.shakeTime * f, 0.3) * s * 0.03
			local ry = math.noise(0.7, active.shakeTime * f) * s * 0.03
			cf = cf * CFrame.Angles(rx, ry, 0)
			active.shake = math.max(0, active.shake - dt * 4)
		end
		camera.CFrame = cf
	end
end

function CameraController.skipIntro()
	if active and active.mode == "Intro" then
		active.introEndsAt = Workspace:GetServerTimeNow()
	end
end

function CameraController.fight()
	if active then
		active.mode = "Fight"
	end
end

function CameraController.shake(amount: number, effectScale: number)
	if active and effectScale > 0 then
		active.effectScale = effectScale
		active.shake = math.min(1.2, active.shake + amount)
	end
end

function CameraController.showResult(model: Model?)
	if active and model then
		active.mode = "Result"
		active.resultTarget = model
		active.resultStart = Workspace:GetServerTimeNow()
	end
end

function CameraController.stop()
	pcall(function()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end)
	if not active then
		return
	end
	local saved = active.saved
	active = nil
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.FieldOfView = saved.fov
	local subject = saved.subject
	if not subject or not subject.Parent then
		local player = game:GetService("Players").LocalPlayer
		local character = player.Character
		subject = character and character:FindFirstChildOfClass("Humanoid")
	end
	if subject then
		camera.CameraSubject = subject
	end
	camera.CameraType = saved.cameraType
	if saved.cameraType == Enum.CameraType.Scriptable then
		-- Ein anderes System hatte die Kamera vorher selbst gesteuert: auch die Lage zurücksetzen.
		camera.CFrame = saved.cframe
	end
end

return CameraController
