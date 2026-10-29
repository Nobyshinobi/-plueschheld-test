-- Deterministische Entscheidungslogik der NPC-Gegner (reine Funktionen, kein Roblox-Dienst).
-- Gleicher Seed + gleiche Eingaben = gleiche Entscheidungen. Der NPCController setzt die
-- Befehle über dieselbe CombatService-Validierung um wie Spielereingaben – der NPC schummelt nicht.

local NPCBrain = {}

export type Rng = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
}

export type Brain = {
	state: string, -- Approach | Neutral | Pattern | Guard | Recover
	nextThinkAt: number,
	pattern: { string }?,
	patternIndex: number,
	blockUntil: number,
	strafeDir: number,
	reaction: { at: number, hitAt: number, kind: string }?,
	counterArmedUntil: number,
	countered: boolean,
	lastBlockedAt: number,
}

export type Context = {
	now: number,
	distance: number,
	free: boolean, -- kann jetzt eine Aktion beginnen
	canCancel: boolean, -- darf in nächste Attacke abbrechen (Treffer gelandet)
	energyFull: boolean,
	hpPct: number,
	stunned: boolean,
	opponentAttacking: boolean,
	opponentStunned: boolean,
	opponentBlocking: boolean,
	reachLight: number,
	reachSpecial: number,
}

export type Command = {
	forward: number, -- -1..1 (zum Gegner hin positiv)
	strafe: number, -- -1..1
	block: boolean,
	action: string?,
	extraWindup: number?,
	dodgeSide: number?,
	fromPattern: boolean?,
}

function NPCBrain.new(now: number): Brain
	return {
		state = "Approach",
		nextThinkAt = now + 0.4,
		pattern = nil,
		patternIndex = 0,
		blockUntil = 0,
		strafeDir = 1,
		reaction = nil,
		counterArmedUntil = 0,
		countered = false,
		lastBlockedAt = -math.huge,
	}
end

local function pickPattern(ai, rng: Rng): { string }
	local total = 0
	for _, p in ai.Patterns do
		total += p.Weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, p in ai.Patterns do
		acc += p.Weight
		if roll <= acc then
			return p.Sequence
		end
	end
	return ai.Patterns[#ai.Patterns].Sequence
end

local function thinkDelay(ai, rng: Rng, hpPct: number): number
	local delay = rng:NextNumber(ai.Think[1], ai.Think[2])
	if ai.EnrageBelow and hpPct <= ai.EnrageBelow then
		delay *= ai.EnrageThinkMultiplier or 1
	end
	return delay
end

local function telegraphFor(ai, attack: string): number
	if attack == "Heavy" or attack == "Special" then
		return ai.Telegraph
	end
	return 0
end

-- Der Spieler beginnt einen Angriff. Plant ggf. eine Reaktion nach der Reaktionszeit.
-- Eine Reaktion ist nur möglich, wenn sie vor dem Treffermoment liegt (faire Reaktionszeiten).
function NPCBrain.onOpponentAttack(brain: Brain, ai, rng: Rng, now: number, hitAt: number)
	local reactAt = now + ai.ReactionTime * rng:NextNumber(0.85, 1.15)
	if reactAt >= hitAt - 0.02 then
		return
	end
	local roll = rng:NextNumber(0, 1)
	local kind
	if roll < ai.BlockChance then
		kind = "Block"
	elseif roll < ai.BlockChance + ai.DodgeChance then
		kind = "Dodge"
	end
	if kind then
		brain.reaction = { at = reactAt, hitAt = hitAt, kind = kind }
	end
end

-- Ein Angriff des NPC wurde geblockt / der NPC hat geblockt – für Konter.
function NPCBrain.onBlockedHit(brain: Brain, now: number)
	brain.lastBlockedAt = now
	brain.counterArmedUntil = now + 0.45
	brain.countered = false
end

function NPCBrain.onStunned(brain: Brain)
	brain.pattern = nil
	brain.patternIndex = 0
	brain.reaction = nil
	brain.blockUntil = 0
	brain.state = "Recover"
end

-- Rückmeldung, ob die Aktion eines Befehls angenommen wurde.
function NPCBrain.confirm(
	brain: Brain,
	ai,
	rng: Rng,
	cmd: Command,
	accepted: boolean,
	reason: string?,
	now: number,
	hpPct: number
)
	if not cmd.fromPattern or not brain.pattern then
		return
	end
	if accepted then
		brain.patternIndex += 1
		if brain.patternIndex >= #brain.pattern then
			brain.pattern = nil
			brain.nextThinkAt = now + thinkDelay(ai, rng, hpPct)
		end
	elseif reason == "NoEnergy" or reason == "KO" or reason == "Finished" then
		brain.pattern = nil
	end
end

function NPCBrain.think(brain: Brain, ai, rng: Rng, ctx: Context): Command
	local now = ctx.now
	local cmd: Command =
		{ forward = 0, strafe = 0, block = false, action = nil, extraWindup = nil, dodgeSide = nil, fromPattern = nil }

	if ctx.stunned then
		brain.state = "Recover"
		return cmd
	end
	if brain.state == "Recover" then
		-- Aufstehen aus dem Treffer: kurze Chance, sich aus dem Druck zu befreien (wie ein Mensch).
		brain.state = "Neutral"
		brain.nextThinkAt = now + thinkDelay(ai, rng, ctx.hpPct) * 0.5
		local roll = rng:NextNumber(0, 1)
		local guard = ai.BlockChance * 0.6
		local dodge = guard + ai.DodgeChance * 0.6
		local poke = dodge + ai.Aggression * 0.35
		if roll < guard then
			brain.blockUntil = now + rng:NextNumber(0.35, 0.6)
			cmd.block = true
			return cmd
		elseif roll < dodge and ctx.free then
			brain.strafeDir = if rng:NextNumber(0, 1) < 0.5 then -1 else 1
			cmd.action = "Dodge"
			cmd.dodgeSide = brain.strafeDir
			return cmd
		elseif roll < poke and ctx.free and ctx.distance <= ctx.reachLight then
			cmd.action = "Light"
			return cmd
		end
	end

	-- 1) Geplante Reaktion auf einen Spielerangriff
	local reaction = brain.reaction
	if reaction and now >= reaction.at then
		brain.reaction = nil
		if now < reaction.hitAt then
			if reaction.kind == "Block" then
				brain.blockUntil = reaction.hitAt + 0.25
				brain.pattern = nil
			elseif reaction.kind == "Dodge" and ctx.free then
				brain.strafeDir = if rng:NextNumber(0, 1) < 0.5 then -1 else 1
				cmd.action = "Dodge"
				cmd.dodgeSide = brain.strafeDir
				brain.pattern = nil
				return cmd
			end
		end
	end

	-- 2) Konter nach erfolgreichem Block
	if not brain.countered and now <= brain.counterArmedUntil and ctx.free and ctx.distance <= ctx.reachLight + 1 then
		brain.countered = true
		if rng:NextNumber(0, 1) < ai.CounterChance then
			-- Konter: schneller Jab, bei Treffer per Hit-Cancel in den Heavy
			brain.blockUntil = 0
			brain.pattern = { "Light", "Heavy" }
			brain.patternIndex = 0
			brain.state = "Pattern"
			cmd.action = "Light"
			cmd.fromPattern = true
			return cmd
		end
	end

	-- 3) Halten der Deckung
	if now < brain.blockUntil then
		cmd.block = true
		cmd.strafe = brain.strafeDir * 0.25
		if ctx.distance > ai.Range + 1.5 then
			cmd.forward = 0.4
		end
		return cmd
	end

	-- 4) Laufende Angriffsfolge (Index rückt erst nach Bestätigung durch CombatService vor)
	local pattern = brain.pattern
	if pattern then
		if ctx.distance > ai.Range + 2.5 then
			brain.pattern = nil
		elseif ctx.free or ctx.canCancel then
			local attack = pattern[brain.patternIndex + 1]
			if attack then
				cmd.action = attack
				cmd.extraWindup = telegraphFor(ai, attack)
				cmd.fromPattern = true
				return cmd
			end
			brain.pattern = nil
		else
			return cmd
		end
	end

	-- 5) Bewegung zur bevorzugten Distanz
	if ctx.distance > ai.Range + 0.6 then
		cmd.forward = 1
		brain.state = "Approach"
	elseif ctx.distance < ai.Range - 1.4 then
		cmd.forward = -0.6
		brain.state = "Neutral"
	else
		brain.state = "Neutral"
		cmd.strafe = brain.strafeDir * 0.55
	end

	-- 6) Neue Entscheidung
	if now < brain.nextThinkAt or not ctx.free then
		return cmd
	end
	brain.nextThinkAt = now + thinkDelay(ai, rng, ctx.hpPct)

	if rng:NextNumber(0, 1) < ai.Hesitation then
		return cmd
	end

	if ctx.energyFull and ctx.distance <= ctx.reachSpecial and rng:NextNumber(0, 1) < ai.SpecialChance then
		cmd.action = "Special"
		cmd.extraWindup = telegraphFor(ai, "Special")
		return cmd
	end

	local inRange = ctx.distance <= ctx.reachLight + 0.4
	local aggression = ai.Aggression
	if ctx.opponentStunned then
		aggression = math.min(1, aggression + 0.35)
	end
	if ctx.opponentBlocking then
		aggression *= 0.6
	end
	if inRange and rng:NextNumber(0, 1) < aggression then
		local seq = pickPattern(ai, rng)
		brain.pattern = seq
		brain.patternIndex = 0
		brain.state = "Pattern"
		cmd.action = seq[1]
		cmd.extraWindup = telegraphFor(ai, seq[1])
		cmd.fromPattern = true
		return cmd
	end

	if rng:NextNumber(0, 1) < ai.GuardStance then
		local duration = ai.GuardDuration or { 0.45, 0.95 }
		brain.blockUntil = now + rng:NextNumber(duration[1], duration[2])
		cmd.block = true
		return cmd
	end

	if rng:NextNumber(0, 1) < 0.35 then
		brain.strafeDir = -brain.strafeDir
	end
	return cmd
end

return NPCBrain
