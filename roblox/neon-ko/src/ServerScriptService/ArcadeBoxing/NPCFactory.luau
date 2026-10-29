-- Baut einen NPC-Gegner aus einem frischen Studio-R15-Rig (HumanoidDescription) + eigener Ausrüstung.
-- Keine Free Models, keine Asset-IDs. Fallback: eigenes Rig unter ServerStorage.ArcadeBoxing.NPCRig
-- (z. B. mit Studio › Avatar › Rig Builder erstellt).

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Keys = require(Shared:WaitForChild("Keys"))
local Gear = require(script.Parent:WaitForChild("Gear"))

local NPCFactory = {}

export type NPC = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	align: AlignOrientation,
}

local function makeDescription(def): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local c = def.Colors
	desc.HeadColor = c.Skin
	desc.LeftArmColor = c.Skin
	desc.RightArmColor = c.Skin
	desc.TorsoColor = c.Shirt
	desc.LeftLegColor = c.Shorts
	desc.RightLegColor = c.Shorts
	desc.HeightScale = def.Body.Height
	desc.WidthScale = def.Body.Width
	desc.DepthScale = def.Body.Depth
	desc.HeadScale = def.Body.Head
	desc.BodyTypeScale = 0
	desc.ProportionScale = 0
	return desc
end

local function fromTemplate(): Model?
	local folder = ServerStorage:FindFirstChild("ArcadeBoxing")
	local template = folder and folder:FindFirstChild("NPCRig")
	if template and template:IsA("Model") and template:FindFirstChildOfClass("Humanoid") then
		return template:Clone()
	end
	return nil
end

local function paintTemplate(model: Model, def)
	local c = def.Colors
	local map = {
		Head = c.Skin,
		UpperTorso = c.Shirt,
		LowerTorso = c.Shorts,
		LeftUpperArm = c.Skin,
		LeftLowerArm = c.Skin,
		LeftHand = c.Skin,
		RightUpperArm = c.Skin,
		RightLowerArm = c.Skin,
		RightHand = c.Skin,
		LeftUpperLeg = c.Shorts,
		LeftLowerLeg = c.Shorts,
		LeftFoot = c.Shorts,
		RightUpperLeg = c.Shorts,
		RightLowerLeg = c.Shorts,
		RightFoot = c.Shorts,
	}
	for name, color in map do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

-- Kann blockieren (lädt das Rig). Gibt nil + Fehlermeldung zurück, wenn kein Rig gebaut werden konnte.
function NPCFactory.build(def, cframe: CFrame, parent: Instance, arenaId: string): (NPC?, string?)
	local model: Model? = nil
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(makeDescription(def), Enum.HumanoidRigType.R15)
	end)
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		model = result
	else
		model = fromTemplate()
		if model then
			paintTemplate(model, def)
		else
			return nil, "R15-Rig konnte nicht erstellt werden: " .. tostring(result)
		end
	end
	assert(model, "NPC-Modell fehlt")

	model.Name = "NEON_KO_" .. def.Key
	-- Fremde Skripte im Rig (z. B. Animate) entfernen: der NPC wird ausschließlich vom Server gesteuert.
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil, "Rig ohne Humanoid/HumanoidRootPart"
	end
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = def.MoveSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- NPC-Körperteile kollidieren normal mit dem Ring, sind aber für Raycasts anderer Systeme
	-- nicht nötig; CanTouch aus, damit Park-Trigger nicht auf den NPC reagieren.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end

	Gear.build(model, def.Gear, def.Colors, Keys.Instances.Gear)

	local ff = Instance.new("ForceField")
	ff.Name = Keys.Instances.ForceField
	ff.Visible = false
	ff.Parent = model

	local attachment = Instance.new("Attachment")
	attachment.Name = Keys.Instances.AlignAttachment
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = Keys.Instances.Align
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.RigidityEnabled = false
	align.Responsiveness = 40
	align.MaxTorque = 1e7
	align.CFrame = cframe.Rotation
	align.Parent = root

	model:SetAttribute(Keys.Fighter.Arena, arenaId)
	model:SetAttribute(Keys.Fighter.Role, "NPC")
	model:SetAttribute(Keys.Fighter.OpponentKey, def.Key)
	model:AddTag(Keys.FighterTag)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	model:PivotTo(cframe)
	model.Parent = parent
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	return { model = model, humanoid = humanoid, root = root, align = align }, nil
end

return NPCFactory
