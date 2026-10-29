-- Serverseitige Kampfabwicklung: Aktionen starten, Trefferfenster prüfen (Overlap-Hitbox +
-- Distanz/Blickrichtung/Zone), Schaden über CombatRules anwenden, Zustand an Clients spiegeln.
-- Der Client meldet nur "ich möchte X" – Zeitpunkte, Treffer und Schaden bestimmt der Server.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))
local Motion = require(Shared:WaitForChild("Motion"))
local ArenaService = require(script.Parent:WaitForChild("ArenaService"))
local PlayerGuard = require(script.Parent:WaitForChild("PlayerGuard"))

local CombatService = {}

local FA = Keys.Fighter
local SHOW_HITBOXES = Config.Debug.ShowHitboxes and RunService:IsStudio()

local function other(side: string): string
	return if side == "player" then "npc" else "player"
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Spiegelt den Aktionszustand eines Kämpfers als Attribute (für Animationen bei allen Clients).
local function publishAction(match, side: string, opts)
	local f = match.fighters[side]
	local model: Model = match.models[side].model
	if not model.Parent then
		return
	end
	local duration = f.actionEndsAt - f.actionStartedAt
	if duration ~= duration or duration == math.huge or duration < 0 then
		duration = -1
	end
	local o = opts or {}
	model:SetAttribute(FA.Action, f.action)
	model:SetAttribute(FA.ActionStart, f.actionStartedAt)
	model:SetAttribute(FA.ActionDuration, duration)
	model:SetAttribute(FA.ExtraWindup, o.extraWindup or 0)
	model:SetAttribute(FA.DodgeSide, o.dodgeSide or 0)
	model:SetAttribute(FA.Seq, o.seq or 0)
	model:SetAttribute(FA.Telegraph, if (o.extraWindup or 0) > 0 then f.action else "")
	model:SetAttribute(FA.ActionId, f.actionId)
	match.published[side] = f.action
end

local function setBlocking(match, side: string, blocking: boolean)
	local f = match.fighters[side]
	f.blocking = blocking
	local m = match.models[side]
	if m.model.Parent then
		m.model:SetAttribute(FA.Block, blocking)
	end
	if side == "player" then
		PlayerGuard.setMovement(match.guard, if blocking then "Block" else "Fight")
	else
		m.humanoid.WalkSpeed = if blocking
			then match.opponent.MoveSpeed * (Config.Fighter.BlockWalkSpeed / Config.Fighter.WalkSpeed)
			else match.opponent.MoveSpeed
	end
end

function CombatService.setup(match)
	local playerMax = Config.Fighter.PlayerMaxHP
	match.fighters = {
		player = CombatRules.newFighter(playerMax, Config, 1),
		npc = CombatRules.newFighter(match.opponent.MaxHP, Config, match.opponent.DamageMultiplier),
	}
	match.pending = {}
	match.published = { player = "Idle", npc = "Idle" }
	match.buffered = {}
	match.suspectUntil = { player = 0, npc = 0 }
end

-- Startet eine Aktion, sofern die Regeln es erlauben. Liefert accepted, reason.
local function startAction(match, side: string, name: string, now: number, opts): (boolean, string)
	local f = match.fighters[side]
	local ok, reason = CombatRules.canStart(f, name, now, Config)
	if not ok then
		if reason == "Busy" and f.actionEndsAt - now <= Config.Fighter.InputBuffer then
			match.buffered[side] = { name = name, at = now, opts = opts }
			return true, "Buffered"
		end
		return false, reason
	end
	local wasBlocking = f.blocking
	local extra = if CombatRules.isAttack(name) then (opts and opts.extraWindup or 0) else 0
	local id = CombatRules.begin(f, name, now, Config, extra)
	if wasBlocking then
		setBlocking(match, side, false)
	end
	match.buffered[side] = nil

	if CombatRules.isAttack(name) then
		local def = Config.Attacks[name]
		local windupEnd, activeEnd = CombatRules.attackTimings(def, extra)
		table.insert(match.pending, {
			side = side,
			name = name,
			actionId = id,
			hitAt = now + windupEnd,
			activeEnd = now + activeEnd,
		})
		if match.onAttackStarted then
			match.onAttackStarted(side, name, now, now + windupEnd)
		end
	elseif name == "Dodge" and side == "npc" then
		local m = match.models.npc
		local toPlayer = flat(match.models.player.root.Position - m.root.Position)
		local right = if toPlayer.Magnitude > 1e-3 then toPlayer.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
		local dir = right * ((opts and opts.dodgeSide) or 1)
		Motion.push(m.root, dir * (Config.Dodge.Distance / (Config.Dodge.Duration * 0.6)), Config.Dodge.Duration * 0.6)
	end
	publishAction(match, side, opts)
	return true, "Started"
end

-- Anfrage eines Kämpfers (Spieler über Remote, NPC über NPCController).
function CombatService.request(match, side: string, action: string, opts, now: number): (boolean, string)
	if match.state ~= "Fighting" then
		return false, "NotFighting"
	end
	local f = match.fighters[side]
	if action == "BlockStart" then
		if f.blocking then
			return true, "Already"
		end
		if not CombatRules.canBlock(f, now) then
			return false, "Busy"
		end
		setBlocking(match, side, true)
		return true, "Started"
	elseif action == "BlockEnd" then
		if f.blocking then
			setBlocking(match, side, false)
		end
		return true, "Stopped"
	elseif action == "Dodge" then
		return startAction(match, side, "Dodge", now, opts)
	elseif CombatRules.isAttack(action) then
		return startAction(match, side, action, now, opts)
	end
	return false, "Unknown"
end

local function showHitbox(cf: CFrame, size: Vector3, hit: boolean)
	local part = Instance.new("Part")
	part.Name = "ABX_DebugHitbox"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.ForceField
	part.Color = if hit then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(80, 160, 255)
	part.Transparency = 0.4
	part.CFrame = cf
	part.Size = size
	part.Parent = Workspace
	Debris:AddItem(part, 0.25)
end

local function afterHit(
	match,
	aSide: string,
	tSide: string,
	attackName: string,
	result,
	now: number,
	position: Vector3,
	dir: Vector3
)
	local target = match.models[tSide]
	local tf = match.fighters[tSide]
	local hitLanded = result.outcome == "Hit" or result.outcome == "Burst"
	if result.outcome == "Blocked" or result.outcome == "GuardBreak" or hitLanded then
		if tSide == "npc" and result.knockback > 0 then
			Motion.push(target.root, dir * result.knockback, 0.14)
		end
	end
	if hitLanded or result.outcome == "GuardBreak" or result.ko then
		if result.outcome == "GuardBreak" then
			setBlocking(match, tSide, false)
		end
		publishAction(match, tSide, nil)
	end
	if match.onHitResolved then
		match.onHitResolved(aSide, tSide, attackName, result, now)
	end
	if match.broadcast then
		match.broadcast("Hit", {
			matchId = match.id,
			arenaId = match.arena.id,
			attacker = match.models[aSide].model,
			target = target.model,
			attackerSide = aSide,
			attack = attackName,
			outcome = result.outcome,
			damage = result.damage,
			combo = result.comboCount,
			comboName = result.comboName,
			position = position,
			knockback = if tSide == "player" then dir * result.knockback else nil,
			ko = result.ko,
			guardBreak = result.outcome == "GuardBreak",
			stun = if tf.stunUntil > now then tf.stunUntil - now else 0,
		})
	end
	if result.ko and match.onKO then
		match.onKO(tSide)
	end
end

-- Prüft, ob ein laufender Angriff jetzt trifft. true = Angriff ist erledigt (Treffer/Ausgewichen/ungültig).
local function tryHit(match, p, now: number): boolean
	local aSide, tSide = p.side, other(p.side)
	local a, t = match.models[aSide], match.models[tSide]
	if not a.root.Parent or not t.root.Parent then
		return true
	end
	local def = Config.Attacks[p.name]
	local aPos, tPos = a.root.Position, t.root.Position
	local delta = flat(tPos - aPos)
	local dist = delta.Magnitude
	if dist < 1e-3 then
		return false
	end
	local dir = delta.Unit
	local look = flat(a.root.CFrame.LookVector)
	if look.Magnitude < 1e-3 then
		return false
	end
	look = look.Unit

	-- Plausibilität (wichtig für Spielerangriffe, deren Position der Client simuliert)
	if dist > def.Reach + 2.2 then
		return false
	end
	if look:Dot(dir) < 0.3 then
		return false
	end
	local tolerance = Config.Fighter.BoundsHardTolerance
	if
		not ArenaService.isInFightZone(match.arena, aPos, tolerance)
		or not ArenaService.isInFightZone(match.arena, tPos, tolerance)
	then
		return false
	end
	if now < match.suspectUntil[aSide] then
		return false
	end

	local size = def.HitboxSize
	local boxCf = CFrame.lookAt(aPos, aPos + look) * CFrame.new(0, 0.2, -(size.Z / 2 + 0.3))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { t.model }
	params.MaxParts = 1
	local parts = Workspace:GetPartBoundsInBox(boxCf, size, params)
	if SHOW_HITBOXES then
		showHitbox(boxCf, size, #parts > 0)
	end
	if #parts == 0 then
		return false
	end

	local tLook = flat(t.root.CFrame.LookVector)
	local facing = tLook.Magnitude > 1e-3 and tLook.Unit:Dot(-dir) > 0.2
	local result = CombatRules.applyHit(match.fighters[aSide], match.fighters[tSide], p.name, now, Config, facing)
	local hitPos = tPos:Lerp(aPos, 0.35) + Vector3.new(0, 1.2, 0)
	afterHit(match, aSide, tSide, p.name, result, now, hitPos, dir)
	return true
end

function CombatService.step(match, now: number, dt: number)
	if match.state ~= "Fighting" then
		return
	end
	for _, side in { "player", "npc" } do
		local f = match.fighters[side]
		local before = f.action
		CombatRules.settle(f, now)
		CombatRules.regenGuard(f, now, dt, Config)
		if before ~= f.action and match.published[side] ~= f.action then
			publishAction(match, side, nil)
		end
		local buffered = match.buffered[side]
		if buffered then
			if now - buffered.at > Config.Fighter.InputBuffer + 0.25 then
				match.buffered[side] = nil
			else
				local ok = CombatRules.canStart(f, buffered.name, now, Config)
				if ok then
					startAction(match, side, buffered.name, now, buffered.opts)
				end
			end
		end
	end

	for i = #match.pending, 1, -1 do
		local p = match.pending[i]
		local f = match.fighters[p.side]
		local done = false
		if f.actionId ~= p.actionId or match.state ~= "Fighting" then
			done = true -- unterbrochen (z. B. selbst getroffen)
		elseif now >= p.hitAt then
			done = tryHit(match, p, now) or now > p.activeEnd
		end
		if match.state ~= "Fighting" then
			break -- Kampf endete in diesem Schritt (K. o.); finish() hat pending bereits geleert
		end
		if done then
			table.remove(match.pending, i)
		end
	end
end

-- Kampfende: laufende Angriffe verwerfen, Endposen setzen.
function CombatService.finish(match, winnerSide: string?)
	table.clear(match.pending)
	table.clear(match.buffered)
	for _, side in { "player", "npc" } do
		local f = match.fighters[side]
		if f.blocking then
			setBlocking(match, side, false)
		end
		if side == winnerSide and not f.ko then
			f.action = "Victory"
			f.actionId += 1
			f.actionStartedAt = Workspace:GetServerTimeNow()
			f.actionEndsAt = math.huge
			publishAction(match, side, nil)
		end
	end
end

function CombatService.markSuspect(match, side: string, untilTime: number)
	match.suspectUntil[side] = math.max(match.suspectUntil[side], untilTime)
end

return CombatService
