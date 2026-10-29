-- Setzt die Entscheidungen von NPCBrain in Bewegung, Blickrichtung und Aktionen um.
-- Aktionen laufen durch CombatService.request – also durch dieselben Regeln wie beim Spieler.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local NPCBrain = require(script.Parent:WaitForChild("NPCBrain"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))

local NPCController = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function NPCController.setup(match, now: number)
	local seed = match.id * 7919 + match.opponent.Id * 104729
	match.ai = {
		def = match.opponent.AI,
		rng = Random.new(seed),
		brain = NPCBrain.new(now),
		seed = seed,
	}
	match.onAttackStarted = function(side: string, _name: string, startedAt: number, hitAt: number)
		if side == "player" then
			NPCBrain.onOpponentAttack(match.ai.brain, match.ai.def, match.ai.rng, startedAt, hitAt)
		end
	end
	match.onHitResolved = function(_aSide: string, tSide: string, _attack: string, result, now: number)
		local brain = match.ai.brain
		if tSide == "npc" then
			if result.outcome == "Blocked" then
				NPCBrain.onBlockedHit(brain, now)
			elseif result.outcome == "Hit" or result.outcome == "Burst" or result.outcome == "GuardBreak" then
				NPCBrain.onStunned(brain)
			end
		end
	end
end

-- Blick zum Gegner, auch außerhalb der Kampfphase (Intro/Countdown).
function NPCController.face(match)
	local npc = match.models.npc
	local target = match.models.player.root
	if not npc.root.Parent or not target.Parent then
		return
	end
	local from = npc.root.Position
	local to = Vector3.new(target.Position.X, from.Y, target.Position.Z)
	if (to - from).Magnitude > 0.05 then
		npc.align.CFrame = CFrame.lookAt(from, to).Rotation
	end
end

function NPCController.step(match, now: number)
	local npc = match.models.npc
	local player = match.models.player
	if not npc.root.Parent or not player.root.Parent then
		return
	end
	NPCController.face(match)

	if match.state ~= "Fighting" then
		npc.humanoid:Move(Vector3.zero, false)
		return
	end

	local f = match.fighters.npc
	local pf = match.fighters.player
	local ai = match.ai
	local delta = flat(player.root.Position - npc.root.Position)
	local distance = delta.Magnitude
	local freeOk, freeReason = CombatRules.canStart(f, "Light", now, Config)

	local ctx = {
		now = now,
		distance = distance,
		free = freeOk and freeReason == "Free",
		canCancel = freeOk and freeReason == "Cancel",
		energyFull = f.energy >= Config.Attacks.Special.EnergyCost,
		hpPct = f.hp / f.maxHp,
		stunned = now < f.stunUntil or f.ko,
		opponentAttacking = CombatRules.isAttack(pf.action) and now < pf.actionEndsAt,
		opponentStunned = now < pf.stunUntil,
		opponentBlocking = pf.blocking,
		reachLight = Config.Attacks.Light.Reach,
		reachSpecial = Config.Attacks.Special.Reach,
	}
	local cmd = NPCBrain.think(ai.brain, ai.def, ai.rng, ctx)

	if cmd.block ~= f.blocking then
		CombatService.request(match, "npc", if cmd.block then "BlockStart" else "BlockEnd", nil, now)
	end
	if cmd.action then
		local accepted, reason = CombatService.request(match, "npc", cmd.action, {
			extraWindup = cmd.extraWindup,
			dodgeSide = cmd.dodgeSide,
		}, now)
		NPCBrain.confirm(ai.brain, ai.def, ai.rng, cmd, accepted, reason, now, ctx.hpPct)
	end

	-- Bewegung: nur wenn nicht gerade angegriffen/getroffen wird.
	local busy = f.action ~= "Idle" and now < f.actionEndsAt
	if busy or ctx.stunned or distance < 1e-3 then
		npc.humanoid:Move(Vector3.zero, false)
		return
	end
	local forward = delta.Unit
	local right = forward:Cross(Vector3.yAxis)
	local move = forward * cmd.forward + right * cmd.strafe
	if move.Magnitude > 1 then
		move = move.Unit
	end
	-- In der Kampfzone bleiben: Bewegungsanteil nach außen entfernen.
	local nextPos = npc.root.Position + move * 1.5
	if not ArenaService.isInFightZone(match.arena, nextPos, 0) then
		local inward = flat(match.arena.cframe.Position - npc.root.Position)
		if inward.Magnitude > 1e-3 then
			move = (move + inward.Unit * 0.8)
			move = if move.Magnitude > 1 then move.Unit else move
		end
	end
	npc.humanoid:Move(move, false)
end

function NPCController.stop(match)
	local npc = match.models and match.models.npc
	if npc and npc.humanoid.Parent then
		npc.humanoid:Move(Vector3.zero, false)
	end
end

return NPCController
