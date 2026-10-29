-- Einfache, selbst gebaute Ausrüstung aus Parts (Handschuhe, Bänder, Helmteile ...).
-- Alles masselos, ohne Kollision/Abfrage und per WeldConstraint befestigt.

local Gear = {}

local function piece(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function attach(part: BasePart, body: BasePart, offset: CFrame)
	part.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
end

local function body(model: Model, name: string): BasePart?
	local part = model:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

function Gear.folder(model: Model, name: string): Folder
	local existing = model:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = model
	return folder
end

-- Boxhandschuhe für R15 (Hände) oder R6 (Armenden).
function Gear.gloves(model: Model, folder: Instance, color: Color3, accent: Color3)
	local sides = {
		{ hand = "RightHand", arm = "Right Arm", side = "R" },
		{ hand = "LeftHand", arm = "Left Arm", side = "L" },
	}
	for _, s in sides do
		local hand = body(model, s.hand)
		local r6 = false
		if not hand then
			hand = body(model, s.arm)
			r6 = true
		end
		if hand then
			local width = math.max(hand.Size.X, hand.Size.Z)
			local diameter = math.clamp(width * 1.3, 0.95, 1.6)
			local glove = piece("Glove" .. s.side, Vector3.one * diameter, color, Enum.Material.SmoothPlastic, folder)
			glove.Shape = Enum.PartType.Ball
			local drop = if r6 then -hand.Size.Y * 0.42 else -hand.Size.Y * 0.2
			attach(glove, hand, CFrame.new(0, drop, -diameter * 0.08))
			local cuff = piece(
				"Cuff" .. s.side,
				Vector3.new(0.22, diameter * 0.92, diameter * 0.92),
				accent,
				Enum.Material.Neon,
				folder
			)
			cuff.Shape = Enum.PartType.Cylinder
			attach(cuff, hand, CFrame.new(0, drop + diameter * 0.48, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

local builders = {}

function builders.Gloves(model: Model, folder: Instance, colors)
	Gear.gloves(model, folder, colors.Gloves, colors.Accent)
end

function builders.Waistband(model: Model, folder: Instance, colors)
	local lower = body(model, "LowerTorso")
	if lower then
		local band = piece(
			"Waistband",
			Vector3.new(lower.Size.X * 1.06, 0.28, lower.Size.Z * 1.1),
			colors.Accent,
			Enum.Material.Neon,
			folder
		)
		attach(band, lower, CFrame.new(0, lower.Size.Y * 0.3, 0))
	end
end

function builders.Headband(model: Model, folder: Instance, colors)
	local head = body(model, "Head")
	if head then
		local band = piece(
			"Headband",
			Vector3.new(head.Size.X * 1.04, 0.22, head.Size.Z * 1.04),
			colors.Accent,
			Enum.Material.Neon,
			folder
		)
		attach(band, head, CFrame.new(0, head.Size.Y * 0.2, 0))
	end
end

function builders.Mohawk(model: Model, folder: Instance, colors)
	local head = body(model, "Head")
	if head then
		for i = -1, 1 do
			local spike = piece(
				"Mohawk" .. (i + 2),
				Vector3.new(0.14, 0.42 - math.abs(i) * 0.08, 0.34),
				colors.Shirt,
				Enum.Material.Neon,
				folder
			)
			attach(
				spike,
				head,
				CFrame.new(0, head.Size.Y * 0.5 + 0.12, i * head.Size.Z * 0.28)
					* CFrame.Angles(math.rad(i * 14 + 10), 0, 0)
			)
		end
	end
end

function builders.Wristbands(model: Model, folder: Instance, colors)
	for _, name in { "RightLowerArm", "LeftLowerArm" } do
		local arm = body(model, name)
		if arm then
			local band = piece(
				"Wristband" .. name,
				Vector3.new(0.3, arm.Size.X * 1.12, arm.Size.Z * 1.12),
				colors.Accent,
				Enum.Material.Neon,
				folder
			)
			band.Shape = Enum.PartType.Cylinder
			attach(band, arm, CFrame.new(0, -arm.Size.Y * 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
end

function builders.ShoulderPads(model: Model, folder: Instance, colors)
	for _, s in { { "RightUpperArm", 1 }, { "LeftUpperArm", -1 } } do
		local arm = body(model, s[1])
		if arm then
			local pad = piece(
				"Pad" .. s[1],
				Vector3.new(arm.Size.X * 1.4, 0.38, arm.Size.Z * 1.4),
				colors.Shorts,
				Enum.Material.Metal,
				folder
			)
			attach(pad, arm, CFrame.new(s[2] * 0.06, arm.Size.Y * 0.42, 0) * CFrame.Angles(0, 0, math.rad(-s[2] * 12)))
			local rim = piece(
				"PadRim" .. s[1],
				Vector3.new(arm.Size.X * 1.42, 0.08, arm.Size.Z * 1.42),
				colors.Gloves,
				Enum.Material.Neon,
				folder
			)
			attach(
				rim,
				arm,
				CFrame.new(s[2] * 0.06, arm.Size.Y * 0.42 - 0.2, 0) * CFrame.Angles(0, 0, math.rad(-s[2] * 12))
			)
		end
	end
end

function builders.Visor(model: Model, folder: Instance, colors)
	local head = body(model, "Head")
	if head then
		local visor =
			piece("Visor", Vector3.new(head.Size.X * 1.02, 0.2, 0.1), colors.Gloves, Enum.Material.Neon, folder)
		visor.Transparency = 0.15
		attach(visor, head, CFrame.new(0, head.Size.Y * 0.08, -head.Size.Z * 0.5))
	end
end

function builders.Crown(model: Model, folder: Instance, colors)
	local head = body(model, "Head")
	if head then
		local ring = piece(
			"CrownRing",
			Vector3.new(0.2, head.Size.X * 0.95, head.Size.Z * 0.95),
			colors.Accent,
			Enum.Material.Neon,
			folder
		)
		ring.Shape = Enum.PartType.Cylinder
		attach(ring, head, CFrame.new(0, head.Size.Y * 0.5 + 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local radius = head.Size.X * 0.36
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			local spike =
				piece("CrownSpike" .. i, Vector3.new(0.16, 0.5, 0.16), colors.Accent, Enum.Material.Neon, folder)
			attach(
				spike,
				head,
				CFrame.new(math.cos(angle) * radius, head.Size.Y * 0.5 + 0.32, math.sin(angle) * radius)
					* CFrame.Angles(math.sin(angle) * 0.25, 0, -math.cos(angle) * 0.25)
			)
		end
	end
end

function builders.Cape(model: Model, folder: Instance, colors)
	local torso = body(model, "UpperTorso")
	if torso then
		local cape = piece(
			"Cape",
			Vector3.new(torso.Size.X * 0.95, 2.3, 0.08),
			colors.Shorts,
			Enum.Material.SmoothPlastic,
			folder
		)
		attach(cape, torso, CFrame.new(0, -0.55, torso.Size.Z * 0.56) * CFrame.Angles(math.rad(-8), 0, 0))
		local trim =
			piece("CapeTrim", Vector3.new(torso.Size.X * 0.96, 0.12, 0.1), colors.Accent, Enum.Material.Neon, folder)
		attach(trim, torso, CFrame.new(0, -1.66, torso.Size.Z * 0.56 + 0.16) * CFrame.Angles(math.rad(-8), 0, 0))
	end
end

function builders.ChestCore(model: Model, folder: Instance, colors)
	local torso = body(model, "UpperTorso")
	if torso then
		local core = piece("ChestCore", Vector3.one * 0.5, colors.Accent, Enum.Material.Neon, folder)
		core.Shape = Enum.PartType.Ball
		attach(core, torso, CFrame.new(0, torso.Size.Y * 0.12, -torso.Size.Z * 0.5))
	end
end

function Gear.build(model: Model, list: { string }, colors, folderName: string)
	local folder = Gear.folder(model, folderName)
	for _, key in list do
		local builder = builders[key]
		if builder then
			local ok, err = pcall(builder, model, folder, colors)
			if not ok then
				warn("[NEON K.O.] Ausrüstung", key, "fehlgeschlagen:", err)
			end
		end
	end
	return folder
end

return Gear
