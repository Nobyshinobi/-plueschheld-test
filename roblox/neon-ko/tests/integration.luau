-- Headless-Integrationstest des kompletten Server-Ablaufs mit einer kleinen Fake-Engine.
-- Lädt die ECHTEN Server-Module (ArenaService, MatchService, CombatService, NPCController,
-- NPCFactory, Gear, PlayerGuard, Main) und simuliert Instanzen, Signale, Zeit, Bewegung und
-- Clients. Prüft Abläufe, Aufräumen und Missbrauchsschutz – NICHT Roblox-Physik, Rendering,
-- Replikation oder den Client-Code. Aufruf:  cd roblox/neon-ko && lune run tests/integration.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

-- Fake-Zeit und Scheduler ------------------------------------------------------------------
local clock = 1000
local scheduled = {} -- { at, fn, args } | { at, thread }
local function schedule(at: number, item)
	item.at = at
	table.insert(scheduled, item)
end
local fakeTask = {}
function fakeTask.delay(seconds: number, fn, ...)
	schedule(clock + (seconds or 0), { fn = fn, args = table.pack(...) })
end
function fakeTask.defer(fn, ...)
	schedule(clock, { fn = fn, args = table.pack(...) })
end
function fakeTask.spawn(fn, ...)
	local thread = coroutine.create(fn)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(err)
	end
	return thread
end
function fakeTask.wait(seconds: number?)
	schedule(clock + (seconds or 0), { thread = coroutine.running() })
	return coroutine.yield()
end

local errors = {}
local warnings = {}
local function runScheduled()
	local i = 1
	while i <= #scheduled do
		local item = scheduled[i]
		if item.at <= clock then
			table.remove(scheduled, i)
			local ok, err
			if item.thread then
				ok, err = coroutine.resume(item.thread, clock - item.at)
			else
				ok, err = pcall(item.fn, table.unpack(item.args, 1, item.args.n))
			end
			if not ok then
				table.insert(errors, "Scheduler: " .. tostring(err))
			end
		else
			i += 1
		end
	end
end

-- Signale ----------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local entry = { fn = fn, connected = true }
	table.insert(self.handlers, entry)
	return {
		Connected = true,
		Disconnect = function(c)
			entry.connected = false
			c.Connected = false
		end,
	}
end
function Signal:Fire(...)
	for _, entry in table.clone(self.handlers) do
		if entry.connected then
			local ok, err = pcall(entry.fn, ...)
			if not ok then
				table.insert(errors, "Signal-Handler: " .. tostring(err))
			end
		end
	end
end

-- Fake-Instanzen ---------------------------------------------------------------------------
local SUPER = {
	BasePart = "PVInstance",
	Part = "BasePart",
	MeshPart = "BasePart",
	Model = "PVInstance",
	PVInstance = "Instance",
	Folder = "Instance",
	ProximityPrompt = "Instance",
	RemoteEvent = "Instance",
	Humanoid = "Instance",
	Animator = "Instance",
	Attachment = "Instance",
	AlignOrientation = "Constraint",
	LinearVelocity = "Constraint",
	Constraint = "Instance",
	WeldConstraint = "Instance",
	ForceField = "Instance",
	HumanoidDescription = "Instance",
	Script = "BaseScript",
	LocalScript = "BaseScript",
	BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	LuaSourceContainer = "Instance",
	Player = "Instance",
	Tool = "Instance",
	StringValue = "Instance",
	DataModel = "Instance",
	Service = "Instance",
}
local EVENTS = {
	Triggered = true,
	Died = true,
	CharacterRemoving = true,
	CharacterAdded = true,
	Destroying = true,
	ChildAdded = true,
	OnServerEvent = true,
	PlayerRemoving = true,
	PlayerAdded = true,
	Heartbeat = true,
}
local DEFAULTS = {
	BasePart = function()
		return {
			CFrame = CFrame.new(),
			Size = Vector3.new(4, 1, 2),
			Anchored = false,
			CanCollide = true,
			CanQuery = true,
			CanTouch = true,
			Transparency = 0,
			AssemblyLinearVelocity = Vector3.zero,
			AssemblyMass = 1,
			Shape = Enum.PartType.Block,
		}
	end,
	Humanoid = function()
		return {
			WalkSpeed = 16,
			JumpPower = 50,
			JumpHeight = 7.2,
			UseJumpPower = true,
			AutoRotate = true,
			Health = 100,
			MaxHealth = 100,
			RigType = Enum.HumanoidRigType.R15,
			MoveDirection = Vector3.zero,
		}
	end,
	ProximityPrompt = function()
		return { MaxActivationDistance = 10, Enabled = true, ActionText = "", ObjectText = "" }
	end,
	BaseScript = function()
		return { Enabled = true }
	end,
}

local all = setmetatable({}, { __mode = "k" })
local tagSignals = {}
local methods = {}

local function isA(className: string, target: string): boolean
	local c = className
	while c do
		if c == target then
			return true
		end
		c = SUPER[c]
	end
	return false
end

local Fake = {}
local function new(className: string, name: string?)
	local props = { Name = name or className, ClassName = className, Archivable = true }
	local c = className
	while c do
		if DEFAULTS[c] then
			for k, v in DEFAULTS[c]() do
				if props[k] == nil then
					props[k] = v
				end
			end
		end
		c = SUPER[c]
	end
	local self = setmetatable({ __props = props, __children = {}, __attrs = {}, __tags = {}, __signals = {} }, Fake)
	all[self] = true
	return self
end

Fake.__index = function(self, key)
	local m = methods[key]
	if m then
		return m
	end
	local props = rawget(self, "__props")
	if key == "Position" and props.CFrame then
		return props.CFrame.Position
	end
	local v = props[key]
	if v ~= nil then
		return v
	end
	if EVENTS[key] then
		local s = rawget(self, "__signals")
		s[key] = s[key] or Signal.new()
		return s[key]
	end
	for _, child in rawget(self, "__children") do
		if child.__props.Name == key then
			return child
		end
	end
	return nil
end

Fake.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if old == value then
			return
		end
		if old then
			local list = rawget(old, "__children")
			local i = table.find(list, self)
			if i then
				table.remove(list, i)
			end
		end
		props.Parent = value
		if value then
			table.insert(rawget(value, "__children"), self)
			value.ChildAdded:Fire(self)
		end
	elseif key == "Position" then
		props.CFrame = CFrame.new(value) * props.CFrame.Rotation
	else
		props[key] = value
	end
end

Fake.__tostring = function(self)
	return self.__props.Name
end

function methods:IsA(className: string): boolean
	return isA(self.__props.ClassName, className)
end
function methods:GetChildren()
	return table.clone(self.__children)
end
function methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, child in inst.__children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name: string)
	for _, child in self.__children do
		if child.__props.Name == name then
			return child
		end
	end
	return nil
end
function methods:WaitForChild(name: string)
	local child = self:FindFirstChild(name)
	if not child then
		error("WaitForChild: " .. name .. " fehlt in " .. self:GetFullName())
	end
	return child
end
function methods:FindFirstChildOfClass(className: string)
	for _, child in self.__children do
		if child.__props.ClassName == className then
			return child
		end
	end
	return nil
end
function methods:IsDescendantOf(other)
	local p = self.__props.Parent
	while p do
		if p == other then
			return true
		end
		p = p.__props.Parent
	end
	return false
end
function methods:GetFullName(): string
	local parts = {}
	local p = self
	while p and p.__props.ClassName ~= "DataModel" do
		table.insert(parts, 1, p.__props.Name)
		p = p.__props.Parent
	end
	return table.concat(parts, ".")
end
function methods:Destroy()
	if rawget(self, "__destroyed") then
		return
	end
	rawset(self, "__destroyed", true)
	self.Destroying:Fire()
	for _, child in table.clone(self.__children) do
		child:Destroy()
	end
	self.Parent = nil
end
function methods:SetAttribute(name: string, value)
	self.__attrs[name] = value
end
function methods:GetAttribute(name: string)
	return self.__attrs[name]
end
function methods:AddTag(tag: string)
	if not self.__tags[tag] then
		self.__tags[tag] = true
		if tagSignals[tag] then
			tagSignals[tag]:Fire(self)
		end
	end
end
function methods:RemoveTag(tag: string)
	self.__tags[tag] = nil
end
function methods:HasTag(tag: string): boolean
	return self.__tags[tag] == true
end
local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end
function methods:PivotTo(cf)
	if isA(self.__props.ClassName, "BasePart") then
		self.CFrame = cf
		return
	end
	local root = rootOf(self)
	if not root then
		return
	end
	local offset = cf * root.CFrame:Inverse()
	for _, d in self:GetDescendants() do
		if isA(d.__props.ClassName, "BasePart") then
			d.CFrame = offset * d.CFrame
		end
	end
end
function methods:GetPivot()
	local root = rootOf(self)
	return if root then root.CFrame else CFrame.new()
end
function methods:SetNetworkOwner() end
function methods:SetStateEnabled(state, enabled)
	self.__states = self.__states or {}
	rawset(self, "__statesTable", rawget(self, "__statesTable") or {})
	rawget(self, "__statesTable")[state] = enabled
end
function methods:Move(direction)
	self.__props.MoveDirection = direction
end
function methods:UnequipTools() end
function methods:FireClient(player, kind, payload)
	local inbox = rawget(player, "__inbox")
	table.insert(inbox, { kind = kind, payload = payload, at = clock })
end
function methods:GetPlayers()
	local list = {}
	for _, child in self.__children do
		if child.__props.ClassName == "Player" then
			table.insert(list, child)
		end
	end
	return list
end
function methods:GetPlayerFromCharacter(character)
	for _, p in self:GetPlayers() do
		if p.Character == character then
			return p
		end
	end
	return nil
end
function methods:GetServerTimeNow(): number
	return clock
end
function methods:IsServer(): boolean
	return true
end
function methods:IsStudio(): boolean
	return true
end
function methods:BindToClose(fn)
	rawset(self, "__close", fn)
end
function methods:AddItem() end
function methods:GetTagged(tag: string)
	local out = {}
	for inst in all do
		if inst.__tags[tag] and not rawget(inst, "__destroyed") then
			table.insert(out, inst)
		end
	end
	return out
end
function methods:GetInstanceAddedSignal(tag: string)
	tagSignals[tag] = tagSignals[tag] or Signal.new()
	return tagSignals[tag]
end

-- Physikersatz: Overlap-Abfrage über Teilmittelpunkte in Box-Koordinaten
function methods:GetPartBoundsInBox(cf, size, params)
	local out = {}
	for _, inst in params.FilterDescendantsInstances or {} do
		local candidates = inst:GetDescendants()
		table.insert(candidates, inst)
		for _, part in candidates do
			if isA(part.__props.ClassName, "BasePart") and part.CanQuery ~= false then
				local l = cf:PointToObjectSpace(part.Position)
				local s = part.Size
				if
					math.abs(l.X) <= size.X / 2 + s.X / 2
					and math.abs(l.Y) <= size.Y / 2 + s.Y / 2
					and math.abs(l.Z) <= size.Z / 2 + s.Z / 2
				then
					table.insert(out, part)
					if params.MaxParts and params.MaxParts > 0 and #out >= params.MaxParts then
						return out
					end
				end
			end
		end
	end
	return out
end
function methods:Raycast()
	return nil
end

-- Rig wie ein Standard-R15 (nur Teile und Humanoid; Motor6Ds braucht der Server nicht)
local R15_PARTS = {
	{ "HumanoidRootPart", Vector3.new(0, 0, 0), Vector3.new(2, 2, 1) },
	{ "LowerTorso", Vector3.new(0, -0.6, 0), Vector3.new(2, 0.4, 1) },
	{ "UpperTorso", Vector3.new(0, 0.4, 0), Vector3.new(2, 1.6, 1) },
	{ "Head", Vector3.new(0, 1.7, 0), Vector3.new(1.2, 1.2, 1.2) },
	{ "RightUpperArm", Vector3.new(1.5, 0.6, 0), Vector3.new(1, 1.2, 1) },
	{ "RightLowerArm", Vector3.new(1.5, -0.4, 0), Vector3.new(1, 1, 1) },
	{ "RightHand", Vector3.new(1.5, -1.1, 0), Vector3.new(1, 0.3, 1) },
	{ "LeftUpperArm", Vector3.new(-1.5, 0.6, 0), Vector3.new(1, 1.2, 1) },
	{ "LeftLowerArm", Vector3.new(-1.5, -0.4, 0), Vector3.new(1, 1, 1) },
	{ "LeftHand", Vector3.new(-1.5, -1.1, 0), Vector3.new(1, 0.3, 1) },
	{ "RightUpperLeg", Vector3.new(0.5, -1.4, 0), Vector3.new(1, 1.2, 1) },
	{ "RightLowerLeg", Vector3.new(0.5, -2.3, 0), Vector3.new(1, 1, 1) },
	{ "RightFoot", Vector3.new(0.5, -2.9, 0), Vector3.new(1, 0.3, 1) },
	{ "LeftUpperLeg", Vector3.new(-0.5, -1.4, 0), Vector3.new(1, 1.2, 1) },
	{ "LeftLowerLeg", Vector3.new(-0.5, -2.3, 0), Vector3.new(1, 1, 1) },
	{ "LeftFoot", Vector3.new(-0.5, -2.9, 0), Vector3.new(1, 0.3, 1) },
}
local function buildRig(name: string, at: CFrame)
	local model = new("Model", name)
	for _, spec in R15_PARTS do
		local part = new("Part", spec[1])
		part.Size = spec[3]
		part.CFrame = at * CFrame.new(spec[2])
		part.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	local humanoid = new("Humanoid")
	humanoid.Parent = model
	new("Animator").Parent = humanoid
	return model
end

-- Welt aufbauen -------------------------------------------------------------------------
local game = new("DataModel", "Game")
local services = {}
for _, name in
	{
		"Players",
		"RunService",
		"Workspace",
		"ReplicatedStorage",
		"ServerScriptService",
		"ServerStorage",
		"CollectionService",
		"Debris",
	}
do
	local s = new("Service", name)
	s.Parent = game
	services[name] = s
end
function methods:GetService(name: string)
	local s = services[name]
	if not s then
		error("Fake-Dienst fehlt: " .. name)
	end
	return s
end
local Workspace = services.Workspace
local Players = services.Players

-- Vorhandener "Boxstand": Gebäude-Modell mit Ringboden (Tag wie nach Werkzeug 03)
local stand = new("Model", "Boxstand")
stand.Parent = Workspace
local floor = new("Part", "RingBoden")
floor.Size = Vector3.new(24, 1, 20)
floor.CFrame = CFrame.new(100, 2.5, 50)
floor.Anchored = true
floor.Parent = stand
floor:AddTag("ArcadeBoxingFloor")
local standSnapshot = {}
for _, d in stand:GetDescendants() do
	standSnapshot[d] = { size = d.Size, cf = d.CFrame, parent = d.Parent }
end

function methods:CreateHumanoidModelFromDescriptionAsync(desc)
	local model = buildRig("Rig", CFrame.new())
	for _, part in model:GetDescendants() do
		if isA(part.__props.ClassName, "BasePart") then
			part.Color = desc.TorsoColor
		end
	end
	return model
end

-- Module laden ----------------------------------------------------------------------------
local OverlapParams = {
	new = function()
		return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, MaxParts = 0 }
	end,
}
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	return setmetatable({ state = math.floor(math.abs(seed or 1)) % 2147483646 + 1 }, RandomShim)
end
function RandomShim:NextNumber(min: number?, max: number?): number
	self.state = (self.state * 48271) % 2147483647
	local a, b = min or 0, max or 1
	return a + (b - a) * (self.state / 2147483647)
end
function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(self:NextNumber(min, max + 1))
end

local realTypeof = typeof
local function fakeTypeof(v): string
	if getmetatable(v) == Fake then
		return "Instance"
	end
	return realTypeof(v)
end

local moduleCache = {}
local requireFake
local function envFor(scriptInstance)
	return {
		game = game,
		workspace = Workspace,
		script = scriptInstance,
		require = requireFake,
		Instance = { new = new },
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		UDim2 = roblox.UDim2,
		Enum = Enum,
		OverlapParams = OverlapParams,
		Random = RandomShim,
		task = fakeTask,
		os = {
			clock = function()
				return clock
			end,
			date = os.date,
			time = os.time,
		},
		math = math,
		table = table,
		string = string,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		type = type,
		typeof = fakeTypeof,
		tostring = tostring,
		tonumber = tonumber,
		error = error,
		assert = assert,
		pcall = pcall,
		select = select,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		print = function() end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring(select(i, ...)))
			end
			table.insert(warnings, table.concat(parts, " "))
		end,
	}
end
function requireFake(moduleScript)
	if moduleCache[moduleScript] then
		return moduleCache[moduleScript]
	end
	local path = rawget(moduleScript, "__path")
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = envFor(moduleScript) })
	local result = fn()
	moduleCache[moduleScript] = result
	return result
end

local function mount(dir: string, parent, folderName: string)
	local folder = new("Folder", folderName)
	folder.Parent = parent
	for _, file in fs.readDir(dir) do
		local name = string.match(file, "^(.-)%.server%.luau$")
		if name then
			local s = new("Script", name)
			rawset(s, "__path", dir .. "/" .. file)
			s.Parent = folder
		else
			name = string.match(file, "^(.-)%.luau$")
			if name then
				local m = new("ModuleScript", name)
				rawset(m, "__path", dir .. "/" .. file)
				m.Parent = folder
			end
		end
	end
	return folder
end
mount("src/ReplicatedStorage/ArcadeBoxing", services.ReplicatedStorage, "ArcadeBoxing")
local serverFolder = mount("src/ServerScriptService/ArcadeBoxing", services.ServerScriptService, "ArcadeBoxing")

local Config = requireFake(services.ReplicatedStorage.ArcadeBoxing.Config)
Config.Debug.Log = false
Config.Debug.ShowHitboxes = false

-- Server starten (wie Studio: Main.server.luau ausführen)
do
	local main = serverFolder.Main
	local fn = luau.load(fs.readFile(rawget(main, "__path")), { debugName = "Main", environment = envFor(main) })
	fn()
end

local remotes = services.ReplicatedStorage.ArcadeBoxing.Remotes
local Request = remotes.Request
local runtime = Workspace.ArcadeBoxingRuntime
local arenaFolder = runtime.Arena_1
local prompt = arenaFolder.ABX_PromptAnchor.ArcadeBoxingPrompt

-- Spieler & Simulation ----------------------------------------------------------------------
local nextUserId = 1
local function addPlayer(name: string, position: Vector3)
	local player = new("Player", name)
	player.UserId = nextUserId
	nextUserId += 1
	player.DisplayName = name
	rawset(player, "__inbox", {})
	local character = buildRig(name, CFrame.new(position))
	character.Parent = Workspace
	player.Character = character
	player.Parent = Players
	Players.PlayerAdded:Fire(player)
	return player
end

local function inbox(player, kind: string)
	local list = {}
	for _, e in rawget(player, "__inbox") do
		if e.kind == kind then
			table.insert(list, e)
		end
	end
	return list
end

local function clearInbox(player)
	table.clear(rawget(player, "__inbox"))
end

-- Bewegt Humanoiden (Server-NPC über Move), wendet AlignOrientation und LinearVelocity an.
local function physics(dt: number)
	for _, d in Workspace:GetDescendants() do
		if d.ClassName == "Humanoid" then
			local model = d.Parent
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if root and model.Parent then
				local dir = d.MoveDirection
				local velocity = Vector3.new(dir.X, 0, dir.Z) * d.WalkSpeed
				local push = root:FindFirstChild("ABX_Push")
				if push and push:FindFirstChildOfClass("LinearVelocity") then
					velocity += push:FindFirstChildOfClass("LinearVelocity").VectorVelocity
				end
				if velocity.Magnitude > 0 then
					model:PivotTo(CFrame.new(root.Position + velocity * dt) * root.CFrame.Rotation)
				end
				local align = root:FindFirstChildOfClass("AlignOrientation")
				if align then
					model:PivotTo(CFrame.new(root.Position) * align.CFrame.Rotation)
				end
			end
		end
	end
end

local function tick(seconds: number, perTick: ((number) -> ())?)
	local dt = 1 / 30
	local steps = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, steps do
		clock += dt
		if perTick then
			perTick(dt)
		end
		physics(dt)
		services.RunService.Heartbeat:Fire(dt)
		runScheduled()
	end
end

local function state(): string
	return arenaFolder:GetAttribute("State")
end

local function npcModel()
	for _, child in arenaFolder:GetChildren() do
		if child.ClassName == "Model" then
			return child
		end
	end
	return nil
end

-- Simulierter Kampf-Client: läuft zum Gegner, blickt ihn an, schlägt im Takt.
local function fightingClient(player, opts)
	local seq = 0
	local nextAttack = 0
	opts = opts or {}
	return function(dt: number)
		if state() ~= "Fighting" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local npc = npcModel()
		local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
		if not root or not npcRoot then
			return
		end
		local delta = npcRoot.Position - root.Position
		local flat = Vector3.new(delta.X, 0, delta.Z)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local pos = root.Position
		if flat.Magnitude > 3.6 then
			pos += flat.Unit * math.min(flat.Magnitude - 3.4, humanoid.WalkSpeed * dt)
		end
		character:PivotTo(CFrame.lookAt(pos, Vector3.new(npcRoot.Position.X, pos.Y, npcRoot.Position.Z)))
		if clock >= nextAttack and flat.Magnitude <= 4.6 then
			nextAttack = clock + (opts.interval or 0.32)
			seq += 1
			local action = if seq % 4 == 0 then "Heavy" else "Light"
			Request.OnServerEvent:Fire(player, "Action", action, seq, 0)
		end
	end
end

-- Testrahmen ----------------------------------------------------------------------------------
local passed, failed = 0, 0
local function check(cond, message: string)
	if not cond then
		error(message, 2)
	end
end
local function scenario(name: string, fn: () -> (), allowedWarning: string?)
	table.clear(errors)
	table.clear(warnings)
	local ok, err = pcall(fn)
	if ok and #errors > 0 then
		ok, err = false, "Laufzeitfehler: " .. table.concat(errors, " | ")
	end
	local unexpected = {}
	for _, w in warnings do
		if not (allowedWarning and string.find(w, allowedWarning, 1, true)) then
			table.insert(unexpected, w)
		end
	end
	if ok and #unexpected > 0 then
		ok, err = false, "Unerwartete Warnungen: " .. table.concat(unexpected, " | ")
	end
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
	-- Zustand für das nächste Szenario aufräumen
	for _, p in Players:GetPlayers() do
		Request.OnServerEvent:Fire(p, "Leave")
	end
	tick(2)
end

local function startFight(player, opponentId: number)
	clearInbox(player)
	prompt.Triggered:Fire(player)
	check(#inbox(player, "OpenSelect") == 1, "OpenSelect fehlt")
	check(state() == "Queued", "Arena nicht reserviert: " .. tostring(state()))
	Request.OnServerEvent:Fire(player, "SelectOpponent", opponentId)
	check(#inbox(player, "MatchSetup") == 1, "MatchSetup fehlt")
	check(state() == "Intro", "kein Intro: " .. tostring(state()))
end

local function assertRestored(player, label: string)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	check(humanoid.WalkSpeed == 16, label .. ": WalkSpeed nicht wiederhergestellt (" .. humanoid.WalkSpeed .. ")")
	check(humanoid.JumpPower == 50 and humanoid.UseJumpPower == true, label .. ": Sprung nicht wiederhergestellt")
	check(humanoid.AutoRotate == true, label .. ": AutoRotate nicht wiederhergestellt")
	check(character:FindFirstChild("ABX_ForceField") == nil, label .. ": ForceField nicht entfernt")
	check(character:FindFirstChild("ABX_Gear") == nil, label .. ": Handschuhe nicht entfernt")
	check(not character:HasTag("ABX_Fighter"), label .. ": Kämpfer-Tag nicht entfernt")
	check(character:GetAttribute("ABX_Action") == nil, label .. ": Kampfattribute nicht entfernt")
end

local function assertIdle(label: string)
	check(state() == "Idle", label .. ": Arena nicht Idle (" .. tostring(state()) .. ")")
	check(npcModel() == nil, label .. ": NPC nicht entfernt")
	check(prompt.ActionText == Config.Arena.PromptActionText, label .. ": Prompt-Text nicht zurückgesetzt")
end

print("Integration (Fake-Engine, echte Server-Module)")

local alice = addPlayer("Alice", Vector3.new(100, 6, 38))
local bob = addPlayer("Bob", Vector3.new(112, 6, 38))

scenario("Arena wird aus dem markierten Ringboden aufgebaut, Prompt FIGHT vorhanden", function()
	check(arenaFolder ~= nil, "Arena-Ordner fehlt")
	check(prompt.ActionText == "FIGHT", "Prompt-Text falsch")
	check(state() == "Idle", "Startzustand nicht Idle")
	check(prompt.MaxActivationDistance >= Config.Arena.PromptMinDistance, "Prompt-Reichweite zu klein")
end)

scenario("Kompletter Kampf gegen Gegner 1: Intro → Countdown → Kampf → Ergebnis → Cleanup", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + 0.1)
	check(state() == "Countdown", "kein Countdown nach Intro: " .. tostring(state()))
	local humanoid = alice.Character:FindFirstChildOfClass("Humanoid")
	check(humanoid.WalkSpeed == 0, "Spieler im Countdown nicht eingefroren")
	tick(Config.Match.CountdownStep * 3 + 0.1)
	check(state() == "Fighting", "kein Kampf nach Countdown: " .. tostring(state()))
	check(humanoid.WalkSpeed == Config.Fighter.WalkSpeed, "Kampf-Laufgeschwindigkeit fehlt")
	check(humanoid.Health == 100, "Spielerschaden an echtem Humanoid!")
	local client = fightingClient(alice)
	local elapsed = 0
	while state() == "Fighting" and elapsed < 65 do
		tick(0.5, client)
		elapsed += 0.5
	end
	check(state() == "Finished", "Kampf endete nicht: " .. tostring(state()))
	local results = inbox(alice, "Result")
	check(#results == 1, "Ergebnis fehlt")
	local r = results[1].payload
	check(
		r.result == "Victory" or r.result == "Defeat" or r.result == "Draw",
		"unerwartetes Ergebnis " .. tostring(r.result)
	)
	check(#inbox(alice, "Hit") > 5, "kaum Treffer-Rückmeldungen (" .. #inbox(alice, "Hit") .. ")")
	local npcAttacks = 0
	for _, e in inbox(alice, "Hit") do
		if e.payload.attackerSide == "npc" then
			npcAttacks += 1
		end
	end
	check(npcAttacks > 0, "NPC hat nie angegriffen")
	check(humanoid.Health == 100, "echter Humanoid wurde beschädigt")
	tick(Config.Match.ResultDuration + 0.2)
	check(#inbox(alice, "Cleanup") == 1, "Cleanup-Ereignis fehlt")
	assertIdle("nach Kampf")
	assertRestored(alice, "nach Kampf")
	if r.result == "Victory" then
		clearInbox(alice)
		prompt.Triggered:Fire(alice)
		local open = inbox(alice, "OpenSelect")[1]
		check(open and open.payload.opponents[2].unlocked == true, "Gegner 2 nach Sieg nicht freigeschaltet")
		Request.OnServerEvent:Fire(alice, "CancelSelect")
	end
	print(
		("       Ergebnis: %s · Treffer %d · Max-Combo %d · Dauer %.1f s"):format(
			r.result,
			r.hits,
			r.maxCombo,
			elapsed
		)
	)
end)

scenario("Passiver Spieler: Kampf endet spätestens nach 60 s (K. o. oder Zeit) mit Ergebnis", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	local elapsed = 0
	while state() == "Fighting" and elapsed < 62 do
		tick(1)
		elapsed += 1
	end
	check(state() == "Finished", "kein Kampfende nach 60 s: " .. tostring(state()))
	check(elapsed <= Config.Match.FightDuration + 1, "Kampf dauerte länger als 60 s")
	local r = inbox(alice, "Result")[1].payload
	check(r.reason == "KO" or r.reason == "Timeout", "unerwarteter Grund " .. tostring(r.reason))
	print(("       Passiv: %s durch %s nach %d s"):format(r.result, r.reason, elapsed))
	tick(Config.Match.ResultDuration + 0.2)
	assertIdle("Passiv")
	assertRestored(alice, "Passiv")
end)

scenario("Zeitablauf: Entscheidung nach HP-Prozent (Rundenzeit für den Test verkürzt)", function()
	local original = Config.Match.FightDuration
	Config.Match.FightDuration = 6
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	tick(6.5, fightingClient(alice, { interval = 0.9 }))
	Config.Match.FightDuration = original
	check(state() == "Finished", "kein Ende nach Zeitablauf: " .. tostring(state()))
	local r = inbox(alice, "Result")[1].payload
	check(r.reason == "Timeout", "Grund nicht Timeout: " .. tostring(r.reason))
	local p = arenaFolder:GetAttribute("PlayerHP") / arenaFolder:GetAttribute("PlayerMaxHP")
	local n = arenaFolder:GetAttribute("NpcHP") / arenaFolder:GetAttribute("NpcMaxHP")
	local expected = if math.abs(p - n) <= Config.Match.DrawTolerance
		then "Draw"
		elseif p > n then "Victory"
		else "Defeat"
	check(r.result == expected, ("Ergebnis %s, erwartet %s (%.2f vs %.2f)"):format(r.result, expected, p, n))
	print(("       Zeitentscheidung: %s (Spieler %.0f %% · Gegner %.0f %%)"):format(r.result, p * 100, n * 100))
	tick(Config.Match.ResultDuration + 0.2)
	assertIdle("Zeitablauf")
end)

scenario("Gesperrter Gegner wird serverseitig abgelehnt", function()
	clearInbox(bob)
	prompt.Triggered:Fire(bob)
	Request.OnServerEvent:Fire(bob, "SelectOpponent", 4)
	check(#inbox(bob, "MatchSetup") == 0, "gesperrter Gegner gestartet")
	check(state() == "Queued", "Reservierung verloren")
	Request.OnServerEvent:Fire(bob, "CancelSelect")
	check(state() == "Idle", "Abbrechen gibt Arena nicht frei")
end)

scenario("Manipulierte Anfragen: falsche Typen, NaN, unbekannte Aktionen, fremde Spieler", function()
	local junk = { {}, 1, true, "DoesNotExist", "Action" }
	for _, kind in junk do
		Request.OnServerEvent:Fire(bob, kind, { evil = true }, 0 / 0, math.huge)
	end
	Request.OnServerEvent:Fire(bob, "SelectOpponent", "1")
	Request.OnServerEvent:Fire(bob, "SelectOpponent", 0 / 0)
	Request.OnServerEvent:Fire(bob, "SkipIntro")
	startFight(alice, 1)
	-- Bob versucht, in Alices Kampf einzugreifen
	Request.OnServerEvent:Fire(bob, "SkipIntro")
	Request.OnServerEvent:Fire(bob, "Leave")
	check(state() == "Intro", "fremder Spieler konnte Kampf beeinflussen: " .. tostring(state()))
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	check(state() == "Fighting", "Kampf startet nicht")
	local npc = npcModel()
	local hpBefore = arenaFolder:GetAttribute("NpcHP")
	for _ = 1, 20 do
		Request.OnServerEvent:Fire(bob, "Action", "Special", 1, 1)
	end
	Request.OnServerEvent:Fire(alice, "Action", "Special", 1, 1) -- keine Energie
	Request.OnServerEvent:Fire(alice, "Action", "Teleport", 2, 0)
	tick(0.5)
	check(arenaFolder:GetAttribute("NpcHP") == hpBefore, "Schaden ohne gültigen Treffer")
	check(npc.Parent ~= nil, "NPC verschwunden")
	-- ungültige Sequenz/Seite werden bereinigt (gültige Aktion bleibt gültig, kein Absturz)
	Request.OnServerEvent:Fire(alice, "Action", "Light", -5, 99)
	Request.OnServerEvent:Fire(alice, "Action", "Dodge", 1.5, 0 / 0)
	tick(0.5)
end)

scenario("Spam: 600 Anfragen in einem Tick werden gedrosselt, kein Absturz", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	for i = 1, 600 do
		Request.OnServerEvent:Fire(alice, "Action", "Light", i, 0)
	end
	check(#inbox(alice, "Reject") < 40, "Drosselung greift nicht (" .. #inbox(alice, "Reject") .. " Ablehnungen)")
	tick(1)
	check(state() == "Fighting", "Spam beendet Kampf")
end, "ungewöhnlich viele Anfragen")

scenario("Abbruch im Intro: Ergebnis ABGEBROCHEN, danach sauberer Rückbau", function()
	startFight(alice, 1)
	tick(0.5)
	Request.OnServerEvent:Fire(alice, "Leave")
	check(inbox(alice, "Result")[1].payload.result == "Aborted", "kein Abbruch-Ergebnis")
	tick(Config.Match.AbortResultDuration + 0.2)
	assertIdle("Abbruch Intro")
	assertRestored(alice, "Abbruch Intro")
end)

scenario("Intro überspringen verkürzt das Intro", function()
	startFight(alice, 1)
	tick(0.3)
	Request.OnServerEvent:Fire(alice, "SkipIntro")
	tick(0.1)
	check(state() == "Countdown", "Überspringen wirkt nicht: " .. tostring(state()))
end)

scenario("Abbruch mitten im Kampf über VERLASSEN", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3, nil)
	tick(3, fightingClient(alice))
	Request.OnServerEvent:Fire(alice, "Leave")
	tick(Config.Match.AbortResultDuration + 0.2)
	assertIdle("Abbruch Kampf")
	assertRestored(alice, "Abbruch Kampf")
	local restoredPos = alice.Character.HumanoidRootPart.Position
	check((restoredPos - Vector3.new(100, 6, 38)).Magnitude < 1, "Spieler nicht an den Ausgangspunkt zurückgebracht")
end)

scenario("Tod während des Kampfs: sofortiges Aufräumen, keine Arena-Blockade", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	local humanoid = alice.Character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 0
	humanoid.Died:Fire()
	tick(0.2)
	assertIdle("Tod")
	-- Respawn: neuer Charakter darf nicht angefasst werden
	local old = alice.Character
	alice.CharacterRemoving:Fire(old)
	old:Destroy()
	alice.Character = buildRig("Alice", CFrame.new(100, 6, 38))
	alice.Character.Parent = Workspace
	tick(0.2)
	assertRestored(alice, "nach Respawn")
end)

scenario("Respawn (CharacterRemoving) im Countdown", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + 0.2)
	local old = alice.Character
	alice.CharacterRemoving:Fire(old)
	old:Destroy()
	alice.Character = buildRig("Alice", CFrame.new(100, 6, 38))
	alice.Character.Parent = Workspace
	tick(0.3)
	assertIdle("Respawn")
	check(#inbox(alice, "Cleanup") == 1, "Client erhält kein Cleanup")
end)

scenario("Arena besetzt: Warteschlange, Zuschauer-Sperre, Einladung nach Kampfende", function()
	startFight(alice, 1)
	clearInbox(bob)
	prompt.Triggered:Fire(bob)
	local notices = inbox(bob, "Notice")
	check(#notices == 1 and string.find(notices[1].payload.text, "Arena besetzt") ~= nil, "keine Besetzt-Meldung")
	check(inbox(bob, "Queue")[1].payload.position == 1, "Warteschlangenplatz fehlt")
	check(prompt.ActionText == Config.Arena.PromptBusyActionText, "Prompt zeigt nicht 'Anstellen'")
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	-- Bob läuft in den Ring → wird hinausgesetzt
	bob.Character:PivotTo(CFrame.new(101, 6, 50))
	tick(0.6)
	local bobPos = bob.Character.HumanoidRootPart.Position
	local localPos = CFrame.new(100, 3, 50):PointToObjectSpace(bobPos)
	check(math.abs(localPos.X) > 12 or math.abs(localPos.Z) > 10, "Zuschauer nicht aus dem Ring gesetzt")
	-- Kampf beenden → Bob wird eingeladen
	clearInbox(bob)
	Request.OnServerEvent:Fire(alice, "Leave")
	tick(Config.Match.AbortResultDuration + 0.3)
	local invite = inbox(bob, "OpenSelect")[1]
	check(invite and invite.payload.invited == true, "Bob nicht eingeladen")
	check(state() == "Queued", "Arena nicht für Bob reserviert")
	Request.OnServerEvent:Fire(bob, "CancelSelect")
	check(state() == "Idle", "Arena nach Absage nicht frei")
end)

scenario("Disconnect des Kämpfers (PlayerRemoving) gibt Arena sofort frei", function()
	local carol = addPlayer("Carol", Vector3.new(96, 6, 38))
	startFight(carol, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	Players.PlayerRemoving:Fire(carol)
	carol.Parent = nil
	tick(0.2)
	assertIdle("Disconnect")
end)

scenario("Auswahl-Zeitlimit gibt die Arena wieder frei", function()
	clearInbox(alice)
	prompt.Triggered:Fire(alice)
	tick(Config.Match.SelectTimeout + 0.5)
	check(#inbox(alice, "CloseSelect") >= 1, "Auswahl nicht geschlossen")
	check(state() == "Idle", "Arena hängt nach Zeitlimit")
end)

scenario("Kämpfer verlässt per Exploit die Kampfzone → wird zurückgesetzt, Treffer gesperrt", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
	alice.Character:PivotTo(CFrame.new(160, 6, 50))
	tick(0.1)
	local pos = alice.Character.HumanoidRootPart.Position
	local localPos = CFrame.new(100, 3, 50):PointToObjectSpace(pos)
	check(math.abs(localPos.X) <= 12 and math.abs(localPos.Z) <= 10, "Spieler nicht in die Kampfzone zurückgesetzt")
end)

scenario("Prompt aus zu großer Entfernung wird ignoriert", function()
	clearInbox(bob)
	bob.Character:PivotTo(CFrame.new(200, 6, 200))
	prompt.Triggered:Fire(bob)
	check(#inbox(bob, "OpenSelect") == 0, "Reichweitenprüfung fehlt")
	bob.Character:PivotTo(CFrame.new(112, 6, 38))
end)

scenario("Alle vier Gegner lassen sich bauen und kämpfen (Freischaltung in Studio-Debug)", function()
	Config.Debug.UnlockAllInStudio = true
	for id = 1, 4 do
		startFight(alice, id)
		tick(Config.Match.IntroDuration + Config.Match.CountdownStep * 3 + 0.3)
		local npc = npcModel()
		check(npc and npc:FindFirstChild("ABX_Gear") ~= nil, "Gegner " .. id .. " ohne Ausrüstung")
		tick(8, fightingClient(alice, { interval = 0.4 }))
		check(
			state() == "Fighting" or state() == "Finished",
			"Gegner " .. id .. ": unerwarteter Zustand " .. tostring(state())
		)
		Request.OnServerEvent:Fire(alice, "Leave")
		tick(Config.Match.AbortResultDuration + 0.3)
		assertIdle("Gegner " .. id)
	end
	Config.Debug.UnlockAllInStudio = false
end)

scenario("Boxstand selbst wurde nie verändert", function()
	for d, snap in standSnapshot do
		check(d.Parent == snap.parent, "Teil umgehängt: " .. d.Name)
		check(d.Size == snap.size and d.CFrame == snap.cf, "Teil verändert: " .. d.Name)
	end
	for _, d in stand:GetDescendants() do
		check(standSnapshot[d] ~= nil, "neues Objekt im Boxstand: " .. d:GetFullName())
	end
end)

scenario("BindToClose räumt laufende Kämpfe auf", function()
	startFight(alice, 1)
	tick(Config.Match.IntroDuration + 0.2)
	local close = rawget(game, "__close")
	check(close ~= nil, "BindToClose nicht registriert")
	close()
	tick(0.1)
	assertIdle("Shutdown")
	assertRestored(alice, "Shutdown")
end)

print(("\n%d bestanden, %d fehlgeschlagen"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
