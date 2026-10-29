-- Reine Kampfregeln ohne Roblox-Dienste: Aktionsfreigabe, Schaden, Kombos, Ergebnis.
-- Der Server ruft diese Funktionen mit seinem eigenen Zustand auf; Client-Werte fließen nie ein.
-- Weil das Modul nur mit Tabellen und Zahlen arbeitet, ist es außerhalb von Studio testbar (tests/).

local CombatRules = {}

export type FighterState = {
	hp: number,
	maxHp: number,
	energy: number,
	guard: number,
	action: string, -- Idle | Light | Heavy | Special | Dodge | Hitstun | GuardBreak | KO | Victory
	actionId: number,
	actionStartedAt: number,
	actionEndsAt: number,
	stunUntil: number,
	invulnUntil: number,
	dodgeStartedAt: number,
	blocking: boolean,
	guardRegenAt: number,
	cooldowns: { [string]: number },
	cancelUntil: number,
	comboCount: number,
	comboLastAt: number,
	comboHistory: { string },
	damageMultiplier: number,
	ko: boolean,
	stats: { hits: number, blocked: number, maxCombo: number, damageDealt: number },
}

export type HitResult = {
	outcome: string, -- Hit | Blocked | GuardBreak | Dodged | PerfectDodge | Burst
	damage: number,
	comboCount: number,
	comboName: string?,
	knockback: number,
	ko: boolean,
}

local ATTACKS = { Light = true, Heavy = true, Special = true }

function CombatRules.isAttack(name: string): boolean
	return ATTACKS[name] == true
end

function CombatRules.newFighter(maxHp: number, cfg, damageMultiplier: number?): FighterState
	return {
		hp = maxHp,
		maxHp = maxHp,
		energy = 0,
		guard = cfg.Fighter.GuardMax,
		action = "Idle",
		actionId = 0,
		actionStartedAt = 0,
		actionEndsAt = 0,
		stunUntil = 0,
		invulnUntil = 0,
		dodgeStartedAt = -math.huge,
		blocking = false,
		guardRegenAt = 0,
		cooldowns = {},
		cancelUntil = -math.huge,
		comboCount = 0,
		comboLastAt = -math.huge,
		comboHistory = {},
		damageMultiplier = damageMultiplier or 1,
		ko = false,
		stats = { hits = 0, blocked = 0, maxCombo = 0, damageDealt = 0 },
	}
end

-- Zeitpunkte relativ zum Aktionsstart: Ende Ausholen, Ende Trefferfenster, Ende Nachlauf.
function CombatRules.attackTimings(def, extraWindup: number?)
	local windup = def.Windup + (extraWindup or 0)
	return windup, windup + def.Active, windup + def.Active + def.Recovery
end

-- Darf der Kämpfer jetzt die Aktion beginnen? Liefert ok, Grund.
-- Grund "Busy" + Restzeit <= InputBuffer bedeutet: Server darf die Eingabe puffern.
function CombatRules.canStart(f: FighterState, name: string, now: number, cfg): (boolean, string)
	if f.ko then
		return false, "KO"
	end
	if f.action == "Victory" then
		return false, "Finished"
	end
	if now < f.stunUntil then
		return false, "Stunned"
	end
	if name == "Special" and f.energy < cfg.Attacks.Special.EnergyCost then
		return false, "NoEnergy"
	end
	if f.action == "Idle" or now >= f.actionEndsAt then
		local ready = f.cooldowns[name]
		if ready and now < ready then
			return false, "Cooldown"
		end
		return true, "Free"
	end
	-- Hit-Cancel ignoriert den Cooldown bewusst (sonst wären L→L-Kombos unmöglich).
	if CombatRules.isAttack(f.action) and CombatRules.isAttack(name) and now <= f.cancelUntil then
		local current = cfg.Attacks[f.action]
		if current and table.find(current.CancelInto, name) then
			return true, "Cancel"
		end
	end
	-- Während einer laufenden Aktion immer "Busy" (der Server darf kurz vor Ende puffern).
	return false, "Busy"
end

-- Startet eine Aktion im Zustand (ohne Prüfung – vorher canStart aufrufen).
function CombatRules.begin(f: FighterState, name: string, now: number, cfg, extraWindup: number?): number
	f.actionId += 1
	f.action = name
	f.actionStartedAt = now
	f.blocking = false
	f.cancelUntil = -math.huge
	if CombatRules.isAttack(name) then
		local def = cfg.Attacks[name]
		local _, _, total = CombatRules.attackTimings(def, extraWindup)
		f.actionEndsAt = now + total
		f.cooldowns[name] = now + total + def.Cooldown
		if name == "Special" then
			f.energy = math.max(0, f.energy - def.EnergyCost)
		end
	elseif name == "Dodge" then
		f.actionEndsAt = now + cfg.Dodge.Duration
		f.invulnUntil = math.max(f.invulnUntil, now + cfg.Dodge.Invulnerable)
		f.dodgeStartedAt = now
		f.cooldowns.Dodge = now + cfg.Dodge.Cooldown
	else
		f.actionEndsAt = now
	end
	return f.actionId
end

function CombatRules.canBlock(f: FighterState, now: number): boolean
	if f.ko or now < f.stunUntil then
		return false
	end
	return f.action == "Idle" or now >= f.actionEndsAt
end

-- Kombo-Skalierung: jeder weitere Treffer einer Serie zählt etwas weniger.
function CombatRules.comboScale(comboIndex: number, cfg): number
	local scale = 1 - cfg.Fighter.ComboDamageFalloff * math.max(0, comboIndex - 1)
	return math.max(cfg.Fighter.ComboDamageFloor, scale)
end

-- Sucht die längste benannte Kombo, deren Folge am Ende der Trefferhistorie steht.
function CombatRules.detectCombo(history: { string }, combos)
	local best = nil
	for _, combo in combos do
		local seq = combo.Sequence
		local n = #seq
		if n <= #history and (best == nil or n > #best.Sequence) then
			local match = true
			for i = 1, n do
				if history[#history - n + i] ~= seq[i] then
					match = false
					break
				end
			end
			if match then
				best = combo
			end
		end
	end
	return best
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function addEnergy(f: FighterState, amount: number, cfg)
	f.energy = math.clamp(f.energy + amount, 0, cfg.Fighter.EnergyMax)
end

-- Wendet einen bestätigten Treffer an (Hitbox/Distanz/Blickrichtung prüft der Aufrufer vorher).
-- targetFacingAttacker: Deckung wirkt nur nach vorne.
function CombatRules.applyHit(
	attacker: FighterState,
	target: FighterState,
	attackName: string,
	now: number,
	cfg,
	targetFacingAttacker: boolean
): HitResult
	local def = cfg.Attacks[attackName]
	local result: HitResult = {
		outcome = "Hit",
		damage = 0,
		comboCount = attacker.comboCount,
		comboName = nil,
		knockback = 0,
		ko = false,
	}

	if now < target.invulnUntil then
		-- Perfekt = Ausweichen kurz bevor der Treffer gelandet wäre.
		local dodgeAge = now - target.dodgeStartedAt
		if target.action == "Dodge" and dodgeAge >= 0 and dodgeAge <= cfg.Fighter.PerfectDodgeWindow then
			result.outcome = "PerfectDodge"
			addEnergy(target, cfg.Fighter.EnergyOnPerfectDodge, cfg)
		else
			result.outcome = "Dodged"
		end
		return result
	end

	if target.blocking and targetFacingAttacker then
		result.outcome = "Blocked"
		result.damage = math.max(1, round(def.Damage * attacker.damageMultiplier * def.BlockDamageMultiplier))
		target.guard -= def.GuardDamage
		target.guardRegenAt = now + cfg.Fighter.GuardRegenDelay
		target.stats.blocked += 1
		addEnergy(attacker, def.EnergyOnBlock, cfg)
		result.knockback = def.Knockback * 0.35
		if target.guard <= 0 then
			result.outcome = "GuardBreak"
			target.guard = cfg.Fighter.GuardMax * 0.5
			target.blocking = false
			target.actionId += 1
			target.action = "GuardBreak"
			target.actionStartedAt = now
			target.actionEndsAt = now + cfg.Fighter.GuardBreakStun
			target.stunUntil = target.actionEndsAt
		end
	else
		-- Kombozählung
		if now - attacker.comboLastAt <= cfg.Fighter.ComboWindow then
			attacker.comboCount += 1
		else
			attacker.comboCount = 1
			table.clear(attacker.comboHistory)
		end
		attacker.comboLastAt = now
		table.insert(attacker.comboHistory, attackName)
		if #attacker.comboHistory > 6 then
			table.remove(attacker.comboHistory, 1)
		end

		local combo = CombatRules.detectCombo(attacker.comboHistory, cfg.Combos)
		local bonus = 0
		if combo and #combo.Sequence >= 2 and attacker.comboCount >= #combo.Sequence then
			bonus = combo.DamageBonus
			result.comboName = combo.Name
		end

		local scale = CombatRules.comboScale(attacker.comboCount, cfg)
		result.damage = math.max(1, round(def.Damage * attacker.damageMultiplier * scale * (1 + bonus)))
		result.comboCount = attacker.comboCount
		result.knockback = def.Knockback
		attacker.cancelUntil = now + cfg.Fighter.HitCancelWindow
		attacker.stats.hits += 1
		attacker.stats.maxCombo = math.max(attacker.stats.maxCombo, attacker.comboCount)
		addEnergy(attacker, def.EnergyOnHit, cfg)
		addEnergy(target, cfg.Fighter.EnergyOnTakeHit, cfg)

		-- Ziel unterbrechen
		target.blocking = false
		target.comboCount = 0
		table.clear(target.comboHistory)
		target.actionId += 1
		target.action = "Hitstun"
		target.actionStartedAt = now
		target.actionEndsAt = now + def.Hitstun
		target.stunUntil = target.actionEndsAt

		if attacker.comboCount >= cfg.Fighter.ComboMaxHits then
			result.outcome = "Burst"
			result.knockback = math.max(result.knockback, cfg.Attacks.Heavy.Knockback * 1.4)
			target.invulnUntil = now + cfg.Fighter.ComboBurstInvuln
			attacker.comboCount = 0
			table.clear(attacker.comboHistory)
		end
	end

	target.hp = math.max(0, target.hp - result.damage)
	attacker.stats.damageDealt += result.damage
	if target.hp <= 0 then
		target.ko = true
		target.action = "KO"
		target.actionId += 1
		target.actionStartedAt = now
		target.actionEndsAt = math.huge
		result.ko = true
	end
	return result
end

-- Deckung regeneriert, wenn nicht geblockt wird.
function CombatRules.regenGuard(f: FighterState, now: number, dt: number, cfg)
	if not f.blocking and now >= f.guardRegenAt and f.guard < cfg.Fighter.GuardMax then
		f.guard = math.min(cfg.Fighter.GuardMax, f.guard + cfg.Fighter.GuardRegenPerSecond * dt)
	end
end

-- Aktionen, deren Zeit abgelaufen ist, zurück auf Idle setzen.
function CombatRules.settle(f: FighterState, now: number)
	if f.ko or f.action == "Victory" then
		return
	end
	if f.action ~= "Idle" and now >= f.actionEndsAt and now >= f.stunUntil then
		f.action = "Idle"
	end
end

-- Ergebnis aus Sicht des Spielers.
-- reason: "KO" | "Timeout" | "Abort"
function CombatRules.decideResult(reason: string, player: FighterState, npc: FighterState, tolerance: number)
	if reason == "Abort" then
		return { result = "Aborted", byKO = false }
	end
	if reason == "KO" then
		if npc.ko and not player.ko then
			return { result = "Victory", byKO = true }
		elseif player.ko and not npc.ko then
			return { result = "Defeat", byKO = true }
		end
		return { result = "Draw", byKO = true }
	end
	local p = player.hp / player.maxHp
	local n = npc.hp / npc.maxHp
	if math.abs(p - n) <= tolerance then
		return { result = "Draw", byKO = false }
	elseif p > n then
		return { result = "Victory", byKO = false }
	end
	return { result = "Defeat", byKO = false }
end

return CombatRules
