-- Sichert vor dem Kampf alle Charakterwerte, die das Minispiel anfasst, und stellt sie danach
-- exakt wieder her. Der Avatar selbst wird nie verändert (Handschuhe sind temporäre Extra-Parts).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local Motion = require(Shared:WaitForChild("Motion"))
local Gear = require(script.Parent:WaitForChild("Gear"))

local PlayerGuard = {}

export type Handle = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	saved: {
		WalkSpeed: number,
		JumpPower: number,
		JumpHeight: number,
		UseJumpPower: boolean,
		AutoRotate: boolean,
	},
	startCFrame: CFrame,
	gear: Instance?,
	forceField: ForceField?,
	connections: { RBXScriptConnection },
	restored: boolean,
}

local FIGHTER_ATTRIBUTES = {}
for _, name in Keys.Fighter do
	table.insert(FIGHTER_ATTRIBUTES, name)
end

function PlayerGuard.capture(
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	arenaId: string
): Handle
	local handle: Handle = {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		saved = {
			WalkSpeed = humanoid.WalkSpeed,
			JumpPower = humanoid.JumpPower,
			JumpHeight = humanoid.JumpHeight,
			UseJumpPower = humanoid.UseJumpPower,
			AutoRotate = humanoid.AutoRotate,
		},
		startCFrame = root.CFrame,
		gear = nil,
		forceField = nil,
		connections = {},
		restored = false,
	}

	humanoid:UnequipTools()
	-- Werkzeuge bleiben während des Kampfs im Rucksack (Klicks sollen Schläge auslösen, keine Tools).
	table.insert(
		handle.connections,
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.defer(function()
					if not handle.restored and humanoid.Parent then
						humanoid:UnequipTools()
					end
				end)
			end
		end)
	)

	if Config.Fighter.ProtectWithForceField then
		local ff = Instance.new("ForceField")
		ff.Name = Keys.Instances.ForceField
		ff.Visible = false
		ff.Parent = character
		handle.forceField = ff
	end

	if Config.Fighter.GivePlayerGloves then
		local colors = Config.Effects.Colors
		local folder = Gear.folder(character, Keys.Instances.Gear)
		local ok, err = pcall(Gear.gloves, character, folder, colors.Cyan, colors.Violet)
		if not ok then
			warn("[NEON K.O.] Handschuhe konnten nicht angelegt werden:", err)
		end
		handle.gear = folder
	end

	character:SetAttribute(Keys.Fighter.Arena, arenaId)
	character:SetAttribute(Keys.Fighter.Role, "Player")
	character:AddTag(Keys.FighterTag)
	return handle
end

-- "Frozen" (Intro/Countdown/Ergebnis), "Fight", "Block"
function PlayerGuard.setMovement(handle: Handle, mode: string)
	if handle.restored or not handle.humanoid.Parent then
		return
	end
	local h = handle.humanoid
	h.AutoRotate = false
	h.UseJumpPower = true
	h.JumpPower = 0
	h.JumpHeight = 0
	if mode == "Frozen" then
		h.WalkSpeed = 0
	elseif mode == "Block" then
		h.WalkSpeed = Config.Fighter.BlockWalkSpeed
	else
		h.WalkSpeed = Config.Fighter.WalkSpeed
	end
end

function PlayerGuard.isSameCharacter(handle: Handle): boolean
	return handle.player.Parent == Players
		and handle.player.Character == handle.character
		and handle.character.Parent ~= nil
		and handle.humanoid.Parent ~= nil
		and handle.humanoid.Health > 0
end

-- teleportTo: Ziel-CFrame für den Rückweg in den Park (nil = Position bleibt).
function PlayerGuard.restore(handle: Handle, teleportTo: CFrame?)
	if handle.restored then
		return
	end
	handle.restored = true
	for _, connection in handle.connections do
		connection:Disconnect()
	end
	table.clear(handle.connections)

	if handle.forceField then
		handle.forceField:Destroy()
	end
	if handle.gear then
		handle.gear:Destroy()
	end

	local character = handle.character
	if character.Parent then
		character:RemoveTag(Keys.FighterTag)
		for _, name in FIGHTER_ATTRIBUTES do
			character:SetAttribute(name, nil)
		end
	end

	if not PlayerGuard.isSameCharacter(handle) then
		-- Charakter wurde ersetzt (Respawn/Verlassen): nichts am neuen Charakter verändern.
		return
	end

	local h = handle.humanoid
	local s = handle.saved
	h.WalkSpeed = s.WalkSpeed
	h.UseJumpPower = s.UseJumpPower
	h.JumpPower = s.JumpPower
	h.JumpHeight = s.JumpHeight
	h.AutoRotate = s.AutoRotate
	Motion.clear(handle.root)

	if teleportTo then
		character:PivotTo(teleportTo)
		handle.root.AssemblyLinearVelocity = Vector3.zero
	end
end

return PlayerGuard
