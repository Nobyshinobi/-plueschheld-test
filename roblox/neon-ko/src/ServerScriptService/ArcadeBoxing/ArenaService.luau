-- Findet den vorhandenen Ring (Bodenplatte mit Tag), berechnet Kampfzone, Startpunkte und
-- legt die FIGHT-Interaktion an. Verändert den Boxstand nicht: alle Laufzeitobjekte liegen in
-- Workspace.ArcadeBoxingRuntime.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))

local ArenaService = {}

export type Arena = {
	id: string,
	index: number,
	floor: BasePart,
	cframe: CFrame, -- Mitte der Bodenoberfläche, Y = oben, X = lange Ringachse
	halfX: number,
	halfZ: number,
	fightHalfX: number,
	fightHalfZ: number,
	playerStart: CFrame,
	npcStart: CFrame,
	exitPoint: CFrame?,
	folder: Folder,
	promptPart: BasePart,
	prompt: ProximityPrompt,
	boardPart: BasePart,
}

local arenas: { Arena } = {}
local byFloor: { [BasePart]: Arena } = {}
local runtimeRoot: Folder? = nil
local onTriggered: ((Arena, Player) -> ())? = nil

local function log(...)
	if Config.Debug.Log then
		print("[NEON K.O.][Arena]", ...)
	end
end

local function getRuntimeRoot(): Folder
	if runtimeRoot and runtimeRoot.Parent then
		return runtimeRoot
	end
	local existing = Workspace:FindFirstChild(Keys.RuntimeFolder)
	if existing and existing:IsA("Folder") then
		runtimeRoot = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Keys.RuntimeFolder
	folder.Parent = Workspace
	runtimeRoot = folder
	return folder
end

local function invisiblePart(name: string, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- Bestimmt, welche lokale Achse der Bodenplatte nach oben zeigt, und baut daraus einen
-- waagerechten Arena-Rahmen (unabhängig davon, wie die Platte im Studio gedreht wurde).
function ArenaService.computeFrame(floor: BasePart): (CFrame, number, number)
	local cf = floor.CFrame
	local size = floor.Size
	local axes = {
		{ vec = cf.RightVector, len = size.X },
		{ vec = cf.UpVector, len = size.Y },
		{ vec = -cf.LookVector, len = size.Z },
	}
	local upIndex = 1
	for i = 2, 3 do
		if math.abs(axes[i].vec.Y) > math.abs(axes[upIndex].vec.Y) then
			upIndex = i
		end
	end
	local up = axes[upIndex]
	local upVec = if up.vec.Y >= 0 then up.vec else -up.vec
	local top = floor.Position + upVec * (up.len / 2)

	local horizontal = {}
	for i = 1, 3 do
		if i ~= upIndex then
			table.insert(horizontal, axes[i])
		end
	end
	table.sort(horizontal, function(a, b)
		return a.len > b.len
	end)
	local long = horizontal[1]
	local flatX = Vector3.new(long.vec.X, 0, long.vec.Z)
	if flatX.Magnitude < 1e-3 then
		flatX = Vector3.xAxis
	end
	flatX = flatX.Unit
	local frame = CFrame.fromMatrix(top, flatX, Vector3.yAxis)
	local halfX, halfZ = long.len / 2, horizontal[2].len / 2
	if floor:IsA("Part") and floor.Shape == Enum.PartType.Cylinder then
		-- Runder Ring: quadratische Kampfzone innerhalb des Kreises
		local r = math.min(halfX, halfZ) * 0.7071
		halfX, halfZ = r, r
	end
	return frame, halfX, halfZ
end

local function findAnchor(floor: BasePart, name: string): BasePart?
	local folders = {}
	local own = floor:FindFirstChild(Config.Arena.AnchorsFolderName)
	if own then
		table.insert(folders, own)
	end
	if floor.Parent then
		local sibling = floor.Parent:FindFirstChild(Config.Arena.AnchorsFolderName)
		if sibling then
			table.insert(folders, sibling)
		end
	end
	for _, folder in folders do
		local anchor = folder:FindFirstChild(name)
		if anchor and anchor:IsA("BasePart") then
			return anchor
		end
	end
	return nil
end

local function buildArena(floor: BasePart): Arena?
	if byFloor[floor] then
		return byFloor[floor]
	end
	local frame, halfX, halfZ = ArenaService.computeFrame(floor)
	local margin = Config.Arena.EdgeMargin
	local fightHalfX = halfX - margin
	local fightHalfZ = halfZ - margin
	if fightHalfX < 3 or fightHalfZ < 2 then
		warn(
			("[NEON K.O.] Ringboden %s ist zu klein für einen Kampf (%.1f × %.1f Studs). Arena wird übersprungen."):format(
				floor:GetFullName(),
				halfX * 2,
				halfZ * 2
			)
		)
		return nil
	end

	local index = #arenas + 1
	local id = "Arena_" .. index
	local folder = Instance.new("Folder")
	folder.Name = id
	folder:SetAttribute(Keys.Arena.Id, id)
	folder:SetAttribute(Keys.Arena.State, "Idle")
	folder.Parent = getRuntimeRoot()

	local spread = math.max(2.5, fightHalfX * Config.Arena.StartSpread)
	local standHeight = 3 -- HumanoidRootPart-Höhe über dem Boden (R15 Standard)
	local playerPos = frame:PointToWorldSpace(Vector3.new(-spread, standHeight, 0))
	local npcPos = frame:PointToWorldSpace(Vector3.new(spread, standHeight, 0))
	local playerStart = CFrame.lookAt(playerPos, Vector3.new(npcPos.X, playerPos.Y, npcPos.Z))
	local npcStart = CFrame.lookAt(npcPos, Vector3.new(playerPos.X, npcPos.Y, playerPos.Z))

	local anchorPlayer = findAnchor(floor, "PlayerStart")
	local anchorNpc = findAnchor(floor, "OpponentStart")
	if anchorPlayer then
		playerStart = anchorPlayer.CFrame
	end
	if anchorNpc then
		npcStart = anchorNpc.CFrame
	end
	local exitAnchor = findAnchor(floor, "ExitPoint")
	local promptAnchor = findAnchor(floor, "PromptPoint")

	local promptCf = if promptAnchor then promptAnchor.CFrame else frame * CFrame.new(0, 3.5, 0)
	local promptPart = invisiblePart(Keys.Instances.PromptPart, promptCf, folder)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Keys.Instances.Prompt
	prompt.ActionText = Config.Arena.PromptActionText
	prompt.ObjectText = Config.Arena.PromptObjectText
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	local reach = if promptAnchor then Config.Arena.PromptMinDistance else math.max(halfX, halfZ) + 6
	prompt.MaxActivationDistance = math.clamp(reach, Config.Arena.PromptMinDistance, Config.Arena.PromptMaxDistance)
	prompt.Parent = promptPart

	local boardPart = invisiblePart(Keys.Instances.BoardPart, frame * CFrame.new(0, Config.Arena.ZoneHeight, 0), folder)

	local arena: Arena = {
		id = id,
		index = index,
		floor = floor,
		cframe = frame,
		halfX = halfX,
		halfZ = halfZ,
		fightHalfX = fightHalfX,
		fightHalfZ = fightHalfZ,
		playerStart = playerStart,
		npcStart = npcStart,
		exitPoint = if exitAnchor then exitAnchor.CFrame else nil,
		folder = folder,
		promptPart = promptPart,
		prompt = prompt,
		boardPart = boardPart,
	}

	prompt.Triggered:Connect(function(player: Player)
		if onTriggered then
			onTriggered(arena, player)
		end
	end)

	table.insert(arenas, arena)
	byFloor[floor] = arena
	log(
		("%s an %s (%.1f × %.1f, Kampfzone %.1f × %.1f)"):format(
			id,
			floor:GetFullName(),
			halfX * 2,
			halfZ * 2,
			fightHalfX * 2,
			fightHalfZ * 2
		)
	)
	return arena
end

function ArenaService.init(triggered: (Arena, Player) -> ())
	onTriggered = triggered
	local tag = Config.Arena.FloorTag
	local function consider(instance: Instance)
		if instance:IsA("BasePart") then
			local ok, err = pcall(buildArena, instance)
			if not ok then
				warn("[NEON K.O.] Arena konnte nicht aufgebaut werden:", err)
			end
		else
			warn(
				("[NEON K.O.] Tag %q gehört an die Bodenplatte (BasePart) des Rings, nicht an %s (%s)."):format(
					tag,
					instance:GetFullName(),
					instance.ClassName
				)
			)
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		consider(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(consider)
	if #arenas == 0 then
		warn(
			("[NEON K.O.] Kein Ringboden mit Tag %q gefunden – das Minispiel bleibt inaktiv. Siehe studio-tools/03_Ring_markieren.luau."):format(
				tag
			)
		)
	end
end

function ArenaService.all(): { Arena }
	return arenas
end

function ArenaService.toLocal(arena: Arena, position: Vector3): Vector3
	return arena.cframe:PointToObjectSpace(position)
end

-- Liegt die Position in der Kampfzone (plus Toleranz)?
function ArenaService.isInFightZone(arena: Arena, position: Vector3, tolerance: number?): boolean
	local p = arena.cframe:PointToObjectSpace(position)
	local t = tolerance or 0
	return math.abs(p.X) <= arena.fightHalfX + t
		and math.abs(p.Z) <= arena.fightHalfZ + t
		and p.Y >= -3
		and p.Y <= Config.Arena.ZoneHeight
end

-- Liegt die Position innerhalb des gesamten Rings (für die Zuschauer-Sperre)?
function ArenaService.isInRing(arena: Arena, position: Vector3): boolean
	local p = arena.cframe:PointToObjectSpace(position)
	return math.abs(p.X) <= arena.halfX
		and math.abs(p.Z) <= arena.halfZ
		and p.Y >= -1.5
		and p.Y <= Config.Arena.ZoneHeight
end

function ArenaService.clampToFightZone(arena: Arena, position: Vector3): Vector3
	local p = arena.cframe:PointToObjectSpace(position)
	-- Y mindestens Standhöhe des HumanoidRootPart, damit niemand im Boden landet.
	local clamped = Vector3.new(
		math.clamp(p.X, -arena.fightHalfX, arena.fightHalfX),
		math.max(p.Y, 3),
		math.clamp(p.Z, -arena.fightHalfZ, arena.fightHalfZ)
	)
	return arena.cframe:PointToWorldSpace(clamped)
end

-- Position knapp außerhalb des Rings, auf der Seite, die der Position am nächsten liegt.
function ArenaService.nearestOutside(arena: Arena, position: Vector3): Vector3
	local p = arena.cframe:PointToObjectSpace(position)
	local dx = arena.halfX - math.abs(p.X)
	local dz = arena.halfZ - math.abs(p.Z)
	local out
	if dx < dz then
		local sign = if p.X >= 0 then 1 else -1
		out = Vector3.new(sign * (arena.halfX + 3), 3, p.Z)
	else
		local sign = if p.Z >= 0 then 1 else -1
		out = Vector3.new(p.X, 3, sign * (arena.halfZ + 3))
	end
	return arena.cframe:PointToWorldSpace(out)
end

function ArenaService.setBusy(arena: Arena, busy: boolean)
	if busy then
		arena.prompt.ActionText = Config.Arena.PromptBusyActionText
		arena.prompt.ObjectText = Config.Arena.PromptBusyObjectText
	else
		arena.prompt.ActionText = Config.Arena.PromptActionText
		arena.prompt.ObjectText = Config.Arena.PromptObjectText
	end
end

return ArenaService
