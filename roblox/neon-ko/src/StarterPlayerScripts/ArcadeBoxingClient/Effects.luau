-- Neon-Trefferfeedback ohne Assets: wenige Partikel (eingebaute rbxasset-Texturen), kurze Highlights,
-- Comic-Wörter, Lichtimpulse, Schockwellen und Sounds. Alles lokal, alles räumt sich selbst auf.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))

local Effects = {}

local C = Config.Effects.Colors
local rng = Random.new()
local folder: Folder? = nil

local ATTACK_COLORS = { Light = C.Cyan, Heavy = C.Magenta, Special = C.Toxic }

local function fxFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "ABX_ClientFX"
	f.Parent = Workspace
	folder = f
	return f
end

local function anchorAt(position: Vector3, life: number): Part
	local part = Instance.new("Part")
	part.Name = "ABX_Fx"
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = position
	part.Parent = fxFolder()
	Debris:AddItem(part, life)
	return part
end

function Effects.sound(id: string?, parent: Instance?, volume: number?)
	if not Config.Sounds.Enabled or not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = (volume or 1) * Config.Sounds.Volume
	sound.RollOffMaxDistance = 90
	sound.Parent = parent or fxFolder()
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function sparks(part: Part, color: Color3, count: number, speed: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, C.White)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.12, 0.3)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Drag = 6
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(math.min(count, Config.Effects.MaxParticlesPerHit))
end

local function pulseLight(part: Part, color: Color3, brightness: number)
	if not Config.Effects.HitLight then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = 10
	light.Shadows = false
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(0.18), { Brightness = 0 }):Play()
end

function Effects.word(position: Vector3, text: string, color: Color3, scale: number?)
	local part = anchorAt(position, 0.9)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(170 * (scale or 1), 64 * (scale or 1))
	board.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-0.6, 0.6), 1.2, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 120
	board.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextColor3 = color
	label.Rotation = rng:NextNumber(-10, 10)
	label.Parent = board
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Night
	stroke.Thickness = 3
	stroke.Parent = label
	TweenService:Create(board, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
		StudsOffsetWorldSpace = board.StudsOffsetWorldSpace + Vector3.new(0, 1.6, 0),
	}):Play()
	TweenService
		:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
		:Play()
	TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
end

local function shockwave(position: Vector3, color: Color3, size: number)
	local ring = Instance.new("Part")
	ring.Name = "ABX_Shockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Size = Vector3.new(0.15, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder()
	TweenService:Create(ring, TweenInfo.new(0.32, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.15, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)
end

local function flash(model: Instance?, color: Color3)
	if not model or not model.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ABX_HitFlash"
	highlight.Adornee = model
	highlight.FillColor = color
	highlight.OutlineColor = C.White
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = fxFolder()
	TweenService:Create(highlight, TweenInfo.new(0.16), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.2)
end

-- Ausholen des Gegners sichtbar machen (Fairness): violetter Puls + "!".
function Effects.telegraph(model: Model, attack: string, duration: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local color = if attack == "Special" then C.Toxic else C.Magenta
	local highlight = Instance.new("Highlight")
	highlight.Name = "ABX_Telegraph"
	highlight.Adornee = model
	highlight.FillColor = color
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = fxFolder()
	TweenService:Create(highlight, TweenInfo.new(math.max(0.1, duration)), { FillTransparency = 0.35 }):Play()
	Debris:AddItem(highlight, duration + 0.05)

	local board = Instance.new("BillboardGui")
	board.Name = "ABX_TelegraphMark"
	board.Adornee = head
	board.Size = UDim2.fromOffset(46, 46)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Parent = fxFolder()
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "!"
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextColor3 = color
	label.Parent = board
	Debris:AddItem(board, duration + 0.05)
end

-- Comic-Sterne über dem Kopf nach einem K. o. (kein Blut, keine Verletzungen).
function Effects.dizzy(model: Instance?)
	local head = model and model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "ABX_Dizzy"
	board.Adornee = head
	board.Size = UDim2.fromOffset(120, 50)
	board.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	board.LightInfluence = 0
	board.Parent = fxFolder()
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "✦  ✦  ✦"
	label.TextScaled = true
	label.TextColor3 = C.Gold
	label.Parent = board
	TweenService
		:Create(label, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
		:Play()
	Debris:AddItem(board, 4)
end

local function pick(list: { string }?): string
	if not list or #list == 0 then
		return "POW!"
	end
	return list[rng:NextInteger(1, #list)]
end

-- payload aus dem "Hit"-Event des Servers.
function Effects.onHit(payload)
	local position: Vector3 = payload.position
	if typeof(position) ~= "Vector3" then
		return
	end
	local attack = payload.attack
	local color = ATTACK_COLORS[attack] or C.Cyan
	local outcome = payload.outcome
	local part = anchorAt(position, 1)

	if outcome == "Hit" or outcome == "Burst" then
		sparks(part, color, if attack == "Light" then 8 else 14, if attack == "Light" then 18 else 28)
		pulseLight(part, color, if attack == "Light" then 3 else 6)
		flash(payload.target, color)
		Effects.word(position, pick(Config.Effects.ComicWords[attack]), color, if attack == "Light" then 0.85 else 1.15)
		if attack ~= "Light" then
			shockwave(position, color, if attack == "Special" then 12 else 7)
		end
		Effects.sound(
			if attack == "Light" then Config.Sounds.HitLight else Config.Sounds.HitHeavy,
			part,
			if attack == "Light" then 0.7 else 1
		)
		if attack == "Special" then
			Effects.sound(Config.Sounds.Special, part, 0.8)
		end
		if outcome == "Burst" then
			Effects.word(position + Vector3.new(0, 1, 0), "COMBO BREAK", C.Gold, 0.9)
		end
	elseif outcome == "Blocked" then
		sparks(part, C.Violet, 5, 12)
		Effects.word(position, "BLOCK", C.Violet, 0.75)
		Effects.sound(Config.Sounds.Block, part, 0.8)
	elseif outcome == "GuardBreak" then
		sparks(part, C.Gold, 12, 24)
		shockwave(position, C.Gold, 8)
		Effects.word(position, "GUARD BREAK!", C.Gold, 1.1)
		Effects.sound(Config.Sounds.HitHeavy, part, 1)
	elseif outcome == "PerfectDodge" then
		sparks(part, C.Toxic, 6, 10)
		Effects.word(position, "PERFECT!", C.Toxic, 0.9)
	elseif outcome == "Dodged" then
		Effects.word(position, "MISS", C.White, 0.7)
		Effects.sound(Config.Sounds.Swing, part, 0.5)
	end

	if payload.ko then
		Effects.dizzy(payload.target)
		Effects.sound(Config.Sounds.KO, part, 0.9)
	end
end

function Effects.clear()
	if folder then
		folder:Destroy()
		folder = nil
	end
end

return Effects
