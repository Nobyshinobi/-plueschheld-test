-- Unit-Tests und Balancing-Simulation für die reinen Logikmodule (CombatRules, NPCBrain, Poses,
-- Config, Opponents). Läuft außerhalb von Roblox Studio mit Lune:
--   cd roblox/neon-ko && lune run tests/run.luau
-- Getestet wird nur Logik ohne Engine. Physik, Netzwerk, UI und Animationen brauchen Studio-Playtests.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Deterministischer Ersatz für Roblox' Random (gleiche Schnittstelle: NextNumber/NextInteger).
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	return setmetatable({ state = math.floor(seed or 1) % 2147483647 }, RandomShim)
end
function RandomShim:_next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function RandomShim:NextNumber(min: number?, max: number?): number
	local a, b = min or 0, max or 1
	return a + (b - a) * self:_next()
end
function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(min + (max - min + 1) * self:_next())
end

local ENV_GLOBALS = {
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Random = RandomShim,
	math = math,
	table = table,
	string = string,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	type = type,
	typeof = typeof,
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
	print = print,
	warn = print,
}

local cache = {}
local function load(path: string)
	if cache[path] then
		return cache[path]
	end
	local env = table.clone(ENV_GLOBALS)
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

local Config = load("src/ReplicatedStorage/ArcadeBoxing/Config.luau")
local Opponents = load("src/ReplicatedStorage/ArcadeBoxing/Opponents.luau")
local CombatRules = load("src/ReplicatedStorage/ArcadeBoxing/CombatRules.luau")
local Poses = load("src/ReplicatedStorage/ArcadeBoxing/Poses.luau")
local NPCBrain = load("src/ServerScriptService/ArcadeBoxing/NPCBrain.luau")

-- Mini-Testrahmen ------------------------------------------------------------------------
local passed, failed = 0, 0
local current = ""

local function test(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ok   " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. "\n       " .. tostring(err))
	end
end

local function eq(actual, expected, label: string?)
	if actual ~= expected then
		error(("%s: erwartet %s, erhalten %s"):format(label or current, tostring(expected), tostring(actual)), 2)
	end
end

local function near(actual: number, expected: number, eps: number, label: string?)
	if math.abs(actual - expected) > eps then
		error(("%s: erwartet ≈%s, erhalten %s"):format(label or current, tostring(expected), tostring(actual)), 2)
	end
end

local function truthy(v, label: string?)
	if not v then
		error((label or current) .. ": Bedingung nicht erfüllt", 2)
	end
end

local function fighter(hp: number?)
	return CombatRules.newFighter(hp or 100, Config, 1)
end

-- Startet einen Angriff und liefert den Treffermoment.
local function attack(f, name: string, t: number): number
	local ok, reason = CombatRules.canStart(f, name, t, Config)
	assert(ok, ("Angriff %s nicht erlaubt: %s"):format(name, reason))
	CombatRules.begin(f, name, t, Config, 0)
	local windupEnd = CombatRules.attackTimings(Config.Attacks[name], 0)
	return t + windupEnd
end

print("CombatRules")

test("neuer Kämpfer startet mit voller HP/Deckung, ohne Energie", function()
	local f = fighter(90)
	eq(f.hp, 90)
	eq(f.guard, Config.Fighter.GuardMax)
	eq(f.energy, 0)
	eq(f.action, "Idle")
end)

test("Light: frei → Busy während Aktion → wieder frei nach Ende + Cooldown", function()
	local f = fighter()
	local ok = CombatRules.canStart(f, "Light", 0, Config)
	truthy(ok)
	CombatRules.begin(f, "Light", 0, Config, 0)
	local ok2, reason = CombatRules.canStart(f, "Light", 0.05, Config)
	eq(ok2, false)
	eq(reason, "Busy")
	local def = Config.Attacks.Light
	local total = def.Windup + def.Active + def.Recovery
	local ok3, reason3 = CombatRules.canStart(f, "Light", total + 0.01, Config)
	eq(ok3, false)
	eq(reason3, "Cooldown")
	local ok4 = CombatRules.canStart(f, "Light", total + def.Cooldown + 0.01, Config)
	truthy(ok4)
end)

test("Special braucht volle Energie und verbraucht sie", function()
	local f = fighter()
	local ok, reason = CombatRules.canStart(f, "Special", 0, Config)
	eq(ok, false)
	eq(reason, "NoEnergy")
	f.energy = Config.Fighter.EnergyMax
	truthy(CombatRules.canStart(f, "Special", 0, Config))
	CombatRules.begin(f, "Special", 0, Config, 0)
	eq(f.energy, 0)
end)

test("Light-Treffer: Schaden, Hitstun, Combo, Energie", function()
	local a, b = fighter(), fighter()
	local hitAt = attack(a, "Light", 0)
	local r = CombatRules.applyHit(a, b, "Light", hitAt, Config, true)
	eq(r.outcome, "Hit")
	eq(r.damage, Config.Attacks.Light.Damage)
	eq(b.hp, 100 - Config.Attacks.Light.Damage)
	eq(b.action, "Hitstun")
	near(b.stunUntil, hitAt + Config.Attacks.Light.Hitstun, 1e-9)
	eq(a.comboCount, 1)
	eq(a.energy, Config.Attacks.Light.EnergyOnHit)
	eq(b.energy, Config.Fighter.EnergyOnTakeHit)
	truthy(a.cancelUntil > hitAt)
end)

test("Hit-Cancel: Light → Heavy erlaubt, Heavy → Light nicht", function()
	local a, b = fighter(), fighter()
	local t = attack(a, "Light", 0)
	CombatRules.applyHit(a, b, "Light", t, Config, true)
	local ok, reason = CombatRules.canStart(a, "Heavy", t + 0.05, Config)
	truthy(ok)
	eq(reason, "Cancel")
	CombatRules.begin(a, "Heavy", t + 0.05, Config, 0)
	local t2 = t + 0.05 + Config.Attacks.Heavy.Windup
	CombatRules.applyHit(a, b, "Heavy", t2, Config, true)
	local ok2, reason2 = CombatRules.canStart(a, "Light", t2 + 0.05, Config)
	eq(ok2, false)
	eq(reason2, "Busy")
end)

test("Light → Light per Hit-Cancel trotz Cooldown möglich", function()
	local a, b = fighter(), fighter()
	local t = attack(a, "Light", 0)
	CombatRules.applyHit(a, b, "Light", t, Config, true)
	local ok, reason = CombatRules.canStart(a, "Light", t + 0.03, Config)
	truthy(ok)
	eq(reason, "Cancel")
end)

test("Cancel-Kombos sind echte Kombos (Ziel kann dazwischen nicht handeln)", function()
	for _, pair in { { "Light", "Light" }, { "Light", "Heavy" }, { "Heavy", "Special" } } do
		local first, second = Config.Attacks[pair[1]], Config.Attacks[pair[2]]
		-- Abbruch direkt nach Treffer: nächster Treffer nach Windup des zweiten Angriffs
		truthy(second.Windup < first.Hitstun, pair[1] .. "→" .. pair[2] .. " ist keine echte Kombo")
		truthy(second.Windup < Config.Fighter.HitCancelWindow + first.Hitstun)
	end
end)

test("NEON RUSH (L, L, H) erkennt Kombo und verrechnet Bonus + Skalierung", function()
	local a, b = fighter(), fighter()
	local t = attack(a, "Light", 0)
	CombatRules.applyHit(a, b, "Light", t, Config, true)
	CombatRules.begin(a, "Light", t + 0.02, Config, 0)
	t += 0.02 + Config.Attacks.Light.Windup
	CombatRules.applyHit(a, b, "Light", t, Config, true)
	CombatRules.begin(a, "Heavy", t + 0.02, Config, 0)
	t += 0.02 + Config.Attacks.Heavy.Windup
	local r = CombatRules.applyHit(a, b, "Heavy", t, Config, true)
	eq(r.comboName, "NEON RUSH")
	eq(r.comboCount, 3)
	local expected = math.floor(Config.Attacks.Heavy.Damage * CombatRules.comboScale(3, Config) * 1.35 + 0.5)
	eq(r.damage, expected)
end)

test("Deckung: nur nach vorne, reduziert Schaden, kostet Guard", function()
	local a, b = fighter(), fighter()
	b.blocking = true
	local t = attack(a, "Heavy", 0)
	local r = CombatRules.applyHit(a, b, "Heavy", t, Config, true)
	eq(r.outcome, "Blocked")
	eq(
		r.damage,
		math.max(1, math.floor(Config.Attacks.Heavy.Damage * Config.Attacks.Heavy.BlockDamageMultiplier + 0.5))
	)
	eq(b.guard, Config.Fighter.GuardMax - Config.Attacks.Heavy.GuardDamage)
	-- von hinten wirkt die Deckung nicht
	local c, d = fighter(), fighter()
	d.blocking = true
	local t2 = attack(c, "Light", 0)
	eq(CombatRules.applyHit(c, d, "Light", t2, Config, false).outcome, "Hit")
end)

test("Guard Break nach mehreren geblockten Heavys", function()
	local a, b = fighter(), fighter()
	local t = 0
	local outcome
	for _ = 1, 4 do
		b.blocking = true
		a.action = "Idle"
		a.cooldowns = {}
		local hitAt = attack(a, "Heavy", t)
		outcome = CombatRules.applyHit(a, b, "Heavy", hitAt, Config, true).outcome
		t = hitAt + 1
		if outcome == "GuardBreak" then
			break
		end
	end
	eq(outcome, "GuardBreak")
	eq(b.blocking, false)
	truthy(b.stunUntil > t - 1)
end)

test("Ausweichen: perfekt / normal / zu spät", function()
	local function scenario(delay: number): string
		local a, b = fighter(), fighter()
		CombatRules.begin(b, "Dodge", 0, Config, 0)
		return CombatRules.applyHit(a, b, "Light", delay, Config, true).outcome
	end
	eq(scenario(0.1), "PerfectDodge")
	eq(scenario(0.27), "Dodged")
	eq(scenario(Config.Dodge.Invulnerable + 0.05), "Hit")
	local a, b = fighter(), fighter()
	CombatRules.begin(b, "Dodge", 0, Config, 0)
	CombatRules.applyHit(a, b, "Light", 0.05, Config, true)
	eq(b.energy, Config.Fighter.EnergyOnPerfectDodge)
end)

test("Combo-Burst nach ComboMaxHits verhindert Dauer-Stunlock", function()
	local a, b = fighter(200), fighter(200)
	local t = 0
	local last
	for i = 1, Config.Fighter.ComboMaxHits do
		a.action = "Idle"
		a.cooldowns = {}
		local hitAt = attack(a, "Light", t)
		last = CombatRules.applyHit(a, b, "Light", hitAt, Config, true)
		t = hitAt + 0.05
		if i < Config.Fighter.ComboMaxHits then
			eq(last.outcome, "Hit")
		end
	end
	eq(last.outcome, "Burst")
	truthy(b.invulnUntil > t)
	eq(a.comboCount, 0)
end)

test("K. o. setzt KO-Zustand; Ergebnis Sieg durch K. o.", function()
	local a, b = fighter(), fighter(5)
	local t = attack(a, "Light", 0)
	local r = CombatRules.applyHit(a, b, "Light", t, Config, true)
	eq(r.ko, true)
	eq(b.ko, true)
	eq(b.hp, 0)
	local res = CombatRules.decideResult("KO", a, b, Config.Match.DrawTolerance)
	eq(res.result, "Victory")
	eq(res.byKO, true)
	local ok, reason = CombatRules.canStart(b, "Light", t + 5, Config)
	eq(ok, false)
	eq(reason, "KO")
end)

test("Zeitentscheidung nach HP-Prozent, Gleichstand = Draw, Abbruch", function()
	local p, n = fighter(100), CombatRules.newFighter(90, Config, 1)
	p.hp, n.hp = 50, 45
	eq(CombatRules.decideResult("Timeout", p, n, Config.Match.DrawTolerance).result, "Draw")
	p.hp, n.hp = 60, 40
	eq(CombatRules.decideResult("Timeout", p, n, Config.Match.DrawTolerance).result, "Victory")
	p.hp, n.hp = 20, 80
	eq(CombatRules.decideResult("Timeout", p, n, Config.Match.DrawTolerance).result, "Defeat")
	eq(CombatRules.decideResult("Abort", p, n, Config.Match.DrawTolerance).result, "Aborted")
end)

test("Guard-Regeneration und Settle", function()
	local f = fighter()
	f.guard = 10
	f.guardRegenAt = 1
	CombatRules.regenGuard(f, 0.5, 0.5, Config)
	eq(f.guard, 10)
	CombatRules.regenGuard(f, 1.5, 0.5, Config)
	near(f.guard, 10 + Config.Fighter.GuardRegenPerSecond * 0.5, 1e-9)
	CombatRules.begin(f, "Light", 2, Config, 0)
	CombatRules.settle(f, 2.1)
	eq(f.action, "Light")
	CombatRules.settle(f, 3)
	eq(f.action, "Idle")
end)

print("Config & Opponents")

test("vier Gegner mit aufsteigender Schwierigkeit und gültigen Werten", function()
	eq(Opponents.Count(), 4)
	local lastDifficulty = 0
	for index, def in Opponents.List do
		eq(def.Id, index, "Id")
		truthy(def.Difficulty > lastDifficulty, def.Name .. " Schwierigkeit")
		lastDifficulty = def.Difficulty
		truthy(def.MaxHP > 0 and def.MoveSpeed > 0)
		for _, key in { "Skin", "Shirt", "Shorts", "Gloves", "Accent" } do
			truthy(def.Colors[key] ~= nil, def.Name .. " Farbe " .. key)
		end
		local ai = def.AI
		truthy(ai.Think[1] <= ai.Think[2], def.Name .. " Think")
		for _, p in ai.Patterns do
			truthy(p.Weight > 0)
			for _, step in p.Sequence do
				truthy(Config.Attacks[step] ~= nil, def.Name .. " Pattern-Angriff " .. step)
			end
		end
		eq(Opponents.Get(def.Id), def)
	end
	truthy(Opponents.Get(99) == nil)
end)

test("Telegraph macht NPC-Heavys für jeden Gegner reagierbar (≥ 0,4 s Ausholen)", function()
	for _, def in Opponents.List do
		local windup = Config.Attacks.Heavy.Windup + def.AI.Telegraph
		truthy(windup >= 0.4, def.Name .. " Heavy-Ausholzeit " .. windup)
	end
end)

test("Kampfzeit 60 s, Intro ≤ 3 s, Animations-IDs nicht erfunden (leer)", function()
	eq(Config.Match.FightDuration, 60)
	truthy(Config.Match.IntroDuration <= 3)
	for key, id in Config.Animations do
		truthy(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil, "Animation " .. key)
	end
end)

print("NPCBrain")

local function ctx(now: number, distance: number, overrides)
	local c = {
		now = now,
		distance = distance,
		free = true,
		canCancel = false,
		energyFull = false,
		hpPct = 1,
		stunned = false,
		opponentAttacking = false,
		opponentStunned = false,
		opponentBlocking = false,
		reachLight = Config.Attacks.Light.Reach,
		reachSpecial = Config.Attacks.Special.Reach,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

test("deterministisch: gleicher Seed + gleiche Eingaben = gleiche Befehle", function()
	local function run(seed: number): string
		local ai = Opponents.Get(2).AI
		local rng = RandomShim.new(seed)
		local brain = NPCBrain.new(0)
		local out = {}
		for i = 1, 300 do
			local t = i / 30
			local c = ctx(t, 3 + (i % 40) / 10, { free = i % 3 ~= 0, opponentStunned = i % 17 == 0 })
			if i % 23 == 0 then
				NPCBrain.onOpponentAttack(brain, ai, rng, t, t + 0.35)
			end
			local cmd = NPCBrain.think(brain, ai, rng, c)
			if cmd.action then
				NPCBrain.confirm(brain, ai, rng, cmd, true, "Started", t, 1)
			end
			table.insert(
				out,
				("%s|%s|%.2f|%.2f"):format(tostring(cmd.action), tostring(cmd.block), cmd.forward, cmd.strafe)
			)
		end
		return table.concat(out, ";")
	end
	eq(run(42), run(42))
	truthy(run(42) ~= run(7), "unterschiedliche Seeds sollten sich unterscheiden")
end)

test("nähert sich aus der Distanz an, steht im Stun still", function()
	local ai = Opponents.Get(1).AI
	local brain = NPCBrain.new(0)
	local cmd = NPCBrain.think(brain, ai, RandomShim.new(1), ctx(0.1, 12))
	eq(cmd.forward, 1)
	local stunned = NPCBrain.think(brain, ai, RandomShim.new(1), ctx(0.2, 3, { stunned = true }))
	eq(stunned.action, nil)
	eq(stunned.forward, 0)
end)

test("Angriffsfolge rückt erst nach Bestätigung vor und endet sauber", function()
	local ai = table.clone(Opponents.Get(2).AI)
	ai.Aggression = 1
	ai.Hesitation = 0
	ai.GuardStance = 0
	ai.Patterns = { { Weight = 1, Sequence = { "Light", "Light", "Heavy" } } }
	local brain = NPCBrain.new(0)
	local rng = RandomShim.new(3)
	local seen = {}
	local t = 1
	for _ = 1, 40 do
		local cmd = NPCBrain.think(brain, ai, rng, ctx(t, 3))
		if cmd.action and cmd.fromPattern then
			table.insert(seen, cmd.action)
			NPCBrain.confirm(brain, ai, rng, cmd, true, "Started", t, 1)
		end
		if #seen == 3 then
			break
		end
		t += 0.05
	end
	eq(table.concat(seen, ","), "Light,Light,Heavy")
	eq(brain.pattern, nil)
	-- abgelehnt (Busy) → derselbe Schritt wird wiederholt
	brain.pattern = { "Light", "Heavy" }
	brain.patternIndex = 0
	local cmd = NPCBrain.think(brain, ai, rng, ctx(t + 0.1, 3))
	NPCBrain.confirm(brain, ai, rng, cmd, false, "Busy", t + 0.1, 1)
	eq(brain.patternIndex, 0)
	local cmd2 = NPCBrain.think(brain, ai, rng, ctx(t + 0.2, 3))
	eq(cmd2.action, "Light")
	NPCBrain.confirm(brain, ai, rng, cmd2, false, "NoEnergy", t + 0.2, 1)
	eq(brain.pattern, nil)
end)

test("Reaktion nur, wenn sie vor dem Treffer möglich ist (faire Reaktionszeit)", function()
	local ai = table.clone(Opponents.Get(1).AI)
	ai.BlockChance = 1
	local brain = NPCBrain.new(0)
	-- Rookie (0,5 s) kann auf einen Light (0,1 s Ausholen) nicht reagieren
	NPCBrain.onOpponentAttack(brain, ai, RandomShim.new(5), 1, 1 + Config.Attacks.Light.Windup)
	eq(brain.reaction, nil)
	-- …aber auf ein Special mit langer Ausholzeit
	NPCBrain.onOpponentAttack(brain, ai, RandomShim.new(5), 1, 1 + 0.9)
	truthy(brain.reaction ~= nil)
	eq(brain.reaction.kind, "Block")
	local cmd = NPCBrain.think(brain, ai, RandomShim.new(5), ctx(brain.reaction.at + 0.01, 3))
	eq(cmd.block, true)
end)

print("Poses")

test("alle Zeitachsen verweisen auf vorhandene Posen", function()
	for _, action in
		{ "Light", "Heavy", "Special", "Dodge", "Hitstun", "GuardBreak", "Block", "KO", "Victory", "Taunt", "Idle" }
	do
		for _, side in { -1, 1 } do
			local keys = Poses.track(action, Config, { dodgeSide = side })
			for _, k in keys do
				truthy(Poses.Library[k.pose] ~= nil, action .. " → " .. k.pose)
			end
		end
	end
end)

test("Faust ist exakt im Treffermoment ausgestreckt (Light/Heavy)", function()
	for _, pair in { { "Light", "Jab" }, { "Heavy", "HeavyStrike" } } do
		local def = Config.Attacks[pair[1]]
		local keys = Poses.track(pair[1], Config)
		local pose = Poses.sample(keys, def.Windup)
		local target = Poses.Library[pair[2]]
		for joint, jp in target do
			near(pose[joint].rx or 0, jp.rx or 0, 1e-6, pair[1] .. " " .. joint)
		end
		near(Poses.duration(keys), def.Windup + def.Active + def.Recovery, 1e-6, pair[1] .. " Dauer")
	end
end)

test("Spiegeln ist umkehrbar; leere Pose = Identität", function()
	local twice = Poses.mirror(Poses.mirror(Poses.Library.Dodge))
	for joint, jp in Poses.Library.Dodge do
		near(twice[joint].rx or 0, jp.rx or 0, 1e-9)
		near(twice[joint].ry or 0, jp.ry or 0, 1e-9)
		near(twice[joint].rz or 0, jp.rz or 0, 1e-9)
	end
	local cf = Poses.toCFrame({}, 1)
	near(cf.Position.Magnitude, 0, 1e-9)
	near(cf.LookVector.Z, -1, 1e-6)
end)

test("Rotationskonvention: rx > 0 hebt den hängenden Arm nach vorne (-Z)", function()
	local cf = Poses.toCFrame({ rx = 90 }, 1)
	local hanging = roblox.Vector3.new(0, -1, 0)
	local rotated = cf:VectorToWorldSpace(hanging)
	near(rotated.Z, -1, 1e-6)
	local yaw = Poses.toCFrame({ ry = 90 }, 1):VectorToWorldSpace(roblox.Vector3.new(1, 0, 0))
	near(yaw.Z, -1, 1e-6, "ry > 0 dreht rechte Schulter nach vorne")
end)

-- Balancing-Simulation -------------------------------------------------------------------
-- Vereinfachtes 1D-Modell (Abstand auf einer Linie, keine Physik/Latenz) mit einem einfachen
-- Spieler-Bot. Aussagekraft: Tendenz der Schwierigkeit, kein Ersatz für echte Playtests.
print("Balancing-Simulation (vereinfachtes Modell)")

local function simulate(opponentId: number, seed: number, botSkill: number)
	local def = Opponents.Get(opponentId)
	local rng = RandomShim.new(seed)
	local botRng = RandomShim.new(seed * 31 + 7)
	local p = CombatRules.newFighter(Config.Fighter.PlayerMaxHP, Config, 1)
	local n = CombatRules.newFighter(def.MaxHP, Config, def.DamageMultiplier)
	local brain = NPCBrain.new(0)
	local px, nx = -4, 4
	local pending = {}
	local dt = 1 / 30
	local t = 0
	local npcThreatAt = nil
	local npcThreatStart = 0
	local botReacted = true
	local botNextAt = 0
	local blockUntil = 0

	local function start(side: string, f, name: string, extra: number): boolean
		local ok = CombatRules.canStart(f, name, t, Config)
		if not ok then
			return false
		end
		CombatRules.begin(f, name, t, Config, extra)
		local windupEnd, activeEnd =
			CombatRules.attackTimings(Config.Attacks[name] or { Windup = 0, Active = 0, Recovery = 0 }, extra)
		if CombatRules.isAttack(name) then
			table.insert(
				pending,
				{ side = side, name = name, id = f.actionId, hitAt = t + windupEnd, activeEnd = t + activeEnd }
			)
			if side == "player" then
				NPCBrain.onOpponentAttack(brain, def.AI, rng, t, t + windupEnd)
			else
				npcThreatAt = t + windupEnd
				npcThreatStart = t
				botReacted = false
			end
		end
		return true
	end

	while t < Config.Match.FightDuration do
		t += dt
		for _, f in { p, n } do
			CombatRules.settle(f, t)
			CombatRules.regenGuard(f, t, dt, Config)
		end
		local dist = math.abs(nx - px)

		-- Spieler-Bot mit menschlichen Grenzen: Entscheidungstakt ~0,25 s, Reaktionszeit ~0,28 s.
		if not p.ko then
			if npcThreatAt and not botReacted and t >= npcThreatStart + 0.28 then
				botReacted = true
				if npcThreatAt > t + 0.04 and botRng:NextNumber() < botSkill * 0.6 then
					if botRng:NextNumber() < 0.7 then
						p.blocking = CombatRules.canBlock(p, t)
						blockUntil = npcThreatAt + 0.15
					else
						start("player", p, "Dodge", 0)
					end
				end
			end
			if p.blocking and t > blockUntil then
				p.blocking = false
			end
			local free = CombatRules.canStart(p, "Light", t, Config)
			if dist > 3.8 and free and not p.blocking then
				px += math.min(dist - 3.6, Config.Fighter.WalkSpeed * dt)
			elseif t >= botNextAt and not p.blocking then
				botNextAt = t + botRng:NextNumber(0.18, 0.34)
				local cancel = p.cancelUntil >= t
				if (free or (cancel and botRng:NextNumber() < 0.45 * botSkill)) and botRng:NextNumber() < 0.8 then
					if p.energy >= 100 and botRng:NextNumber() < 0.7 then
						start("player", p, "Special", 0)
					elseif botRng:NextNumber() < 0.68 then
						start("player", p, "Light", 0)
					else
						start("player", p, "Heavy", 0)
					end
				end
			end
		end

		-- NPC
		if not n.ko then
			local freeOk, reason = CombatRules.canStart(n, "Light", t, Config)
			local cmd = NPCBrain.think(brain, def.AI, rng, {
				now = t,
				distance = dist,
				free = freeOk and reason == "Free",
				canCancel = freeOk and reason == "Cancel",
				energyFull = n.energy >= 100,
				hpPct = n.hp / n.maxHp,
				stunned = t < n.stunUntil,
				opponentAttacking = CombatRules.isAttack(p.action) and t < p.actionEndsAt,
				opponentStunned = t < p.stunUntil,
				opponentBlocking = p.blocking,
				reachLight = Config.Attacks.Light.Reach,
				reachSpecial = Config.Attacks.Special.Reach,
			})
			if cmd.block and CombatRules.canBlock(n, t) then
				n.blocking = true
			elseif not cmd.block then
				n.blocking = false
			end
			if cmd.action then
				local accepted = start("npc", n, cmd.action, cmd.extraWindup or 0)
				NPCBrain.confirm(
					brain,
					def.AI,
					rng,
					cmd,
					accepted,
					if accepted then "Started" else "Busy",
					t,
					n.hp / n.maxHp
				)
			elseif n.action == "Idle" and t >= n.stunUntil then
				nx -= cmd.forward * def.MoveSpeed * dt * (if nx > px then 1 else -1)
				nx = math.max(nx, px + 1.5)
			end
		end

		-- Treffer auflösen
		for i = #pending, 1, -1 do
			local a = pending[i]
			local attacker = if a.side == "player" then p else n
			local target = if a.side == "player" then n else p
			local done = attacker.actionId ~= a.id
			if not done and t >= a.hitAt then
				if math.abs(nx - px) <= Config.Attacks[a.name].Reach then
					local r = CombatRules.applyHit(attacker, target, a.name, t, Config, true)
					-- dieselben Rückmeldungen wie NPCController.onHitResolved
					if a.side == "player" then
						if r.outcome == "Blocked" then
							NPCBrain.onBlockedHit(brain, t)
						elseif r.outcome == "Hit" or r.outcome == "Burst" or r.outcome == "GuardBreak" then
							NPCBrain.onStunned(brain)
						end
					end
					if r.knockback > 0 then
						local push = r.knockback * 0.12
						if a.side == "player" then
							nx += push
						else
							px -= push
						end
					end
					done = true
				elseif t > a.activeEnd then
					done = true
				end
			end
			if done then
				table.remove(pending, i)
			end
		end
		if p.ko or n.ko then
			return CombatRules.decideResult("KO", p, n, Config.Match.DrawTolerance).result, t
		end
	end
	return CombatRules.decideResult("Timeout", p, n, Config.Match.DrawTolerance).result, t
end

local balance = {}
test("Simulation: jeder Kampf endet, Siegquote sinkt mit der Gegnerstufe", function()
	local runs = 120
	for _, def in Opponents.List do
		local wins, draws, totalTime, kos = 0, 0, 0, 0
		for seed = 1, runs do
			local result, duration = simulate(def.Id, seed, 0.75)
			truthy(duration <= Config.Match.FightDuration + 0.05, "Kampf überschreitet 60 s")
			totalTime += duration
			if duration < Config.Match.FightDuration then
				kos += 1
			end
			if result == "Victory" then
				wins += 1
			elseif result == "Draw" then
				draws += 1
			end
		end
		balance[def.Id] = wins / runs
		print(
			("       %-13s Siegquote Bot %3d %%  · Remis %2d  · K.-o.-Quote %3d %%  · Ø Dauer %4.1f s"):format(
				def.Name,
				math.floor(wins / runs * 100 + 0.5),
				draws,
				math.floor(kos / runs * 100 + 0.5),
				totalTime / runs
			)
		)
	end
	for i = 2, #balance do
		truthy(balance[i - 1] >= balance[i], ("Gegner %d sollte nicht schwerer sein als Gegner %d"):format(i - 1, i))
	end
	truthy(balance[1] >= 0.5, "Rookie sollte für den Bot meist schlagbar sein")
	truthy(balance[4] <= 0.85, "Boss sollte eine Herausforderung sein")
end)

print(("\n%d bestanden, %d fehlgeschlagen"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end
