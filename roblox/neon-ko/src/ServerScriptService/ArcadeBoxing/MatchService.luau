-- Ablaufsteuerung je Arena (Server ist die einzige Wahrheit):
--   Idle → Queued (Gegnerauswahl reserviert) → Intro → Countdown → Fighting → Finished → Cleanup → Idle
-- Dazu: Warteschlange, sitzungsbezogene Freischaltungen, Abbruch/Disconnect/Respawn, Zuschauer-Sperre.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local Net = require(Shared:WaitForChild("Net"))
local Opponents = require(Shared:WaitForChild("Opponents"))
local CombatRules = require(Shared:WaitForChild("CombatRules"))

local ArenaService = require(script.Parent:WaitForChild("ArenaService"))
local CombatService = require(script.Parent:WaitForChild("CombatService"))
local NPCController = require(script.Parent:WaitForChild("NPCController"))
local NPCFactory = require(script.Parent:WaitForChild("NPCFactory"))
local PlayerGuard = require(script.Parent:WaitForChild("PlayerGuard"))

local MatchService = {}

local AK = Keys.Arena
local OBSERVER_RADIUS = 160

local states = {} -- arenaId → Arena-Zustand
local membership: { [Player]: { arenaId: string, role: string } } = {}
local unlocks: { [number]: { highest: number, beaten: { [number]: boolean } } } = {}
local buckets: { [Player]: { tokens: number, at: number, dropped: number } } = {}
local matchCounter = 0
local eventRemote: RemoteEvent? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function log(...)
	if Config.Debug.Log then
		print("[NEON K.O.]", ...)
	end
end

local function send(player: Player, kind: string, payload)
	if eventRemote and player.Parent == Players then
		eventRemote:FireClient(player, kind, payload or {})
	end
end

local function notice(player: Player, text: string, kind: string?)
	send(player, "Notice", { text = text, kind = kind or "info" })
end

local function setAttr(st, name: string, value)
	local folder = st.arena.folder
	if folder:GetAttribute(name) ~= value then
		folder:SetAttribute(name, value)
	end
end

local function getCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character or not character.Parent then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function observers(arena): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		local _, _, root = getCharacter(player)
		if root and (root.Position - arena.cframe.Position).Magnitude <= OBSERVER_RADIUS then
			table.insert(list, player)
		end
	end
	return list
end

-- Token-Bucket je Spieler: schützt vor Remote-Spam (Überschuss wird verworfen).
local function allowRequest(player: Player): boolean
	local t = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = 20, at = t, dropped = 0 }
		buckets[player] = b
	end
	b.tokens = math.min(20, b.tokens + (t - b.at) * 14)
	b.at = t
	if b.tokens < 1 then
		b.dropped += 1
		if b.dropped == 100 then
			warn(("[NEON K.O.] %s sendet ungewöhnlich viele Anfragen (verworfen)."):format(player.Name))
		end
		return false
	end
	b.tokens -= 1
	return true
end

local function unlockInfo(player: Player)
	local info = unlocks[player.UserId]
	if not info then
		info = { highest = 1, beaten = {} }
		unlocks[player.UserId] = info
	end
	if Config.Debug.UnlockAllInStudio and RunService:IsStudio() then
		info.highest = Opponents.Count()
	end
	return info
end

local function opponentList(player: Player)
	local info = unlockInfo(player)
	local list = {}
	for _, def in Opponents.List do
		table.insert(list, {
			id = def.Id,
			name = def.Name,
			title = def.Title,
			style = def.Style,
			difficulty = def.Difficulty,
			maxHp = def.MaxHP,
			special = def.SpecialName,
			color = def.Colors.Shirt,
			accent = def.Colors.Accent,
			unlocked = def.Id <= info.highest,
			beaten = info.beaten[def.Id] == true,
		})
	end
	return list
end

local function queuePosition(st, player: Player): number?
	return table.find(st.queue, player)
end

local function updateQueueNotices(st)
	setAttr(st, AK.QueueLength, #st.queue)
	for index, player in st.queue do
		send(player, "Queue", { arenaId = st.arena.id, position = index })
	end
end

local reserve, advanceQueue, cleanup, finish

local function setState(st, state: string)
	st.state = state
	if st.match then
		st.match.state = state
	end
	setAttr(st, AK.State, state)
	ArenaService.setBusy(st.arena, state ~= "Idle")
end

function reserve(st, player: Player, timeout: number, invited: boolean)
	st.reservedBy = player
	st.reservedUntil = now() + timeout
	membership[player] = { arenaId = st.arena.id, role = "Selecting" }
	setState(st, "Queued")
	send(player, "OpenSelect", {
		arenaId = st.arena.id,
		opponents = opponentList(player),
		timeout = timeout,
		deadline = st.reservedUntil,
		invited = invited,
	})
end

local function releaseReservation(st, reasonText: string?)
	local player = st.reservedBy
	st.reservedBy = nil
	if player then
		local m = membership[player]
		if m and m.role == "Selecting" then
			membership[player] = nil
		end
		send(player, "CloseSelect", {})
		if reasonText then
			notice(player, reasonText)
		end
	end
	if st.state == "Queued" then
		setState(st, "Idle")
	end
	advanceQueue(st)
end

function advanceQueue(st)
	if st.state ~= "Idle" then
		return
	end
	while #st.queue > 0 do
		local player = table.remove(st.queue, 1)
		local m = membership[player]
		if m and m.role == "Queued" then
			membership[player] = nil
		end
		local _, _, root = getCharacter(player)
		if
			player.Parent == Players
			and root
			and (root.Position - st.arena.cframe.Position).Magnitude <= Config.Match.QueueMaxDistance
		then
			notice(player, "Du bist dran! Wähle deinen Gegner.", "success")
			reserve(st, player, Config.Match.QueueInviteTimeout, true)
			break
		end
	end
	updateQueueNotices(st)
end

local function removeFromQueue(st, player: Player)
	local index = queuePosition(st, player)
	if index then
		table.remove(st.queue, index)
		updateQueueNotices(st)
	end
	local m = membership[player]
	if m and m.role == "Queued" then
		membership[player] = nil
	end
	send(player, "Queue", { arenaId = st.arena.id, position = 0 })
end

local function enqueue(st, player: Player)
	if queuePosition(st, player) then
		return
	end
	if #st.queue >= Config.Match.QueueMax then
		notice(player, "Arena besetzt – die Warteschlange ist voll. Schau gern zu!", "warn")
		return
	end
	table.insert(st.queue, player)
	membership[player] = { arenaId = st.arena.id, role = "Queued" }
	notice(player, ("Arena besetzt – du bist Platz %d. Du kannst solange zuschauen."):format(#st.queue), "warn")
	updateQueueNotices(st)
end

local function resetArenaAttributes(st)
	for _, name in { AK.MatchId, AK.FighterUserId, AK.OpponentId } do
		setAttr(st, name, 0)
	end
	for _, name in { AK.FighterName, AK.OpponentName, AK.Result } do
		setAttr(st, name, "")
	end
	for _, name in
		{
			AK.PlayerHP,
			AK.PlayerMaxHP,
			AK.NpcHP,
			AK.NpcMaxHP,
			AK.PlayerEnergy,
			AK.NpcEnergy,
			AK.PlayerCombo,
			AK.NpcCombo,
			AK.IntroEndsAt,
			AK.CountdownEndsAt,
			AK.FightEndsAt,
		}
	do
		setAttr(st, name, 0)
	end
end

local function syncArena(match)
	local st = match.st
	local pf, nf = match.fighters.player, match.fighters.npc
	setAttr(st, AK.PlayerHP, pf.hp)
	setAttr(st, AK.NpcHP, nf.hp)
	setAttr(st, AK.PlayerEnergy, math.floor(pf.energy))
	setAttr(st, AK.NpcEnergy, math.floor(nf.energy))
	setAttr(st, AK.PlayerCombo, pf.comboCount)
	setAttr(st, AK.NpcCombo, nf.comboCount)
end

-- Kampfstart -----------------------------------------------------------------------
local function startMatch(st, player: Player, def)
	local arena = st.arena
	local character, humanoid, root = getCharacter(player)
	if not character then
		releaseReservation(st)
		return
	end
	membership[player] = { arenaId = arena.id, role = "Fighting" }
	st.reservedBy = nil
	send(player, "CloseSelect", {})

	matchCounter += 1
	local match = {
		id = matchCounter,
		st = st,
		arena = arena,
		player = player,
		opponent = def,
		state = "Starting",
		connections = {},
		cancelled = false,
		cleaned = false,
	}
	st.match = match
	setState(st, "Intro")
	setAttr(st, AK.IntroEndsAt, 0)

	local npc, err = NPCFactory.build(def, arena.npcStart, arena.folder, arena.id)
	if match.cancelled then
		if npc then
			npc.model:Destroy()
		end
		return
	end
	if not npc then
		warn("[NEON K.O.] Gegner konnte nicht erstellt werden:", err)
		notice(player, "Der Gegner konnte nicht geladen werden. Bitte später erneut versuchen.", "warn")
		cleanup(match, "NpcFailed")
		return
	end
	local c2, h2, r2 = getCharacter(player)
	if c2 ~= character or not h2 or not r2 then
		npc.model:Destroy()
		cleanup(match, "Respawn")
		return
	end

	match.models = {
		player = { model = character, humanoid = humanoid, root = root },
		npc = npc,
	}
	match.guard = PlayerGuard.capture(player, character, humanoid, root, arena.id)
	PlayerGuard.setMovement(match.guard, "Frozen")
	CombatService.setup(match)
	local t = now()
	NPCController.setup(match, t)
	match.broadcast = function(kind: string, payload)
		for _, p in observers(arena) do
			send(p, kind, payload)
		end
	end
	match.onKO = function()
		finish(match, "KO")
	end

	table.insert(
		match.connections,
		humanoid.Died:Connect(function()
			MatchService.abort(match, "Died")
		end)
	)
	table.insert(
		match.connections,
		player.CharacterRemoving:Connect(function()
			MatchService.abort(match, "Respawn")
		end)
	)
	table.insert(
		match.connections,
		npc.model.Destroying:Connect(function()
			if not match.cleaned then
				task.defer(MatchService.abort, match, "NpcLost")
			end
		end)
	)

	character:PivotTo(arena.playerStart)
	root.AssemblyLinearVelocity = Vector3.zero
	match.teleportGraceUntil = t + 0.75
	match.introEndsAt = t + Config.Match.IntroDuration

	setAttr(st, AK.MatchId, match.id)
	setAttr(st, AK.FighterUserId, player.UserId)
	setAttr(st, AK.FighterName, player.DisplayName)
	setAttr(st, AK.OpponentId, def.Id)
	setAttr(st, AK.OpponentName, def.Name)
	setAttr(st, AK.PlayerMaxHP, match.fighters.player.maxHp)
	setAttr(st, AK.NpcMaxHP, match.fighters.npc.maxHp)
	setAttr(st, AK.Result, "")
	setAttr(st, AK.CountdownEndsAt, 0)
	setAttr(st, AK.FightEndsAt, 0)
	syncArena(match)
	setAttr(st, AK.IntroEndsAt, match.introEndsAt)
	match.state = "Intro"

	send(player, "MatchSetup", {
		arenaId = arena.id,
		matchId = match.id,
		opponentId = def.Id,
		npc = npc.model,
		npcName = npc.model.Name,
		folder = arena.folder,
		arenaCFrame = arena.cframe,
		fightHalfX = arena.fightHalfX,
		fightHalfZ = arena.fightHalfZ,
		introEndsAt = match.introEndsAt,
	})
	log(("Match %d: %s vs %s"):format(match.id, player.Name, def.Name))
end

local function beginCountdown(match, t: number)
	setState(match.st, "Countdown")
	match.countdownEndsAt = t + Config.Match.CountdownStep * 3
	setAttr(match.st, AK.CountdownEndsAt, match.countdownEndsAt)
end

local function beginFight(match, t: number)
	setState(match.st, "Fighting")
	match.fightEndsAt = t + Config.Match.FightDuration
	setAttr(match.st, AK.FightEndsAt, match.fightEndsAt)
	PlayerGuard.setMovement(match.guard, "Fight")
end

-- Kampfende ------------------------------------------------------------------------
-- reason: "KO" | "Timeout" | "Leave" | "Died" | "Respawn" | "Left" | "NpcLost" | "Error" | "Shutdown"
function finish(match, reason: string)
	if match.state == "Finished" or match.state == "Cleanup" or match.cleaned then
		return
	end
	local t = now()
	local decision
	if (reason == "KO" or reason == "Timeout") and match.fighters then
		decision =
			CombatRules.decideResult(reason, match.fighters.player, match.fighters.npc, Config.Match.DrawTolerance)
	else
		decision = { result = "Aborted", byKO = false }
	end
	match.result = decision

	local winner = if decision.result == "Victory" then "player" elseif decision.result == "Defeat" then "npc" else nil
	if match.fighters then
		CombatService.finish(match, winner)
		syncArena(match)
	end
	NPCController.stop(match)
	if match.guard then
		PlayerGuard.setMovement(match.guard, "Frozen")
	end

	local unlockedNew = nil
	if decision.result == "Victory" then
		local info = unlockInfo(match.player)
		info.beaten[match.opponent.Id] = true
		if match.opponent.Id >= info.highest and match.opponent.Id < Opponents.Count() then
			info.highest = match.opponent.Id + 1
			local nextDef = Opponents.Get(info.highest)
			unlockedNew = nextDef and nextDef.Name
		end
	end

	setState(match.st, "Finished")
	setAttr(match.st, AK.Result, decision.result)
	local aborted = decision.result == "Aborted"
	match.resultEndsAt = t + (if aborted then Config.Match.AbortResultDuration else Config.Match.ResultDuration)

	local pf = match.fighters and match.fighters.player
	send(match.player, "Result", {
		matchId = match.id,
		result = decision.result,
		byKO = decision.byKO,
		reason = reason,
		opponentName = match.opponent.Name,
		hits = pf and pf.stats.hits or 0,
		maxCombo = pf and pf.stats.maxCombo or 0,
		damage = pf and pf.stats.damageDealt or 0,
		timeLeft = if match.fightEndsAt then math.max(0, match.fightEndsAt - t) else Config.Match.FightDuration,
		unlocked = unlockedNew,
		resultEndsAt = match.resultEndsAt,
	})
	log(("Match %d beendet: %s (%s)"):format(match.id, decision.result, reason))
end

function cleanup(match, reason: string)
	if match.cleaned then
		return
	end
	match.cleaned = true
	match.cancelled = true
	local st = match.st
	pcall(setState, st, "Cleanup")

	for _, connection in match.connections do
		connection:Disconnect()
	end
	table.clear(match.connections)
	pcall(NPCController.stop, match)

	if match.guard then
		local target = nil
		local guard = match.guard
		if PlayerGuard.isSameCharacter(guard) then
			local pos = guard.root.Position
			if ArenaService.isInRing(st.arena, pos) or ArenaService.isInFightZone(st.arena, pos, 4) then
				target = st.arena.exitPoint or guard.startCFrame
			end
		end
		local ok, err = pcall(PlayerGuard.restore, guard, target)
		if not ok then
			warn("[NEON K.O.] Wiederherstellung des Spielers fehlgeschlagen:", err)
		end
	end
	if match.models and match.models.npc then
		pcall(function()
			match.models.npc.model:Destroy()
		end)
	end

	send(match.player, "Cleanup", { matchId = match.id, reason = reason })
	local m = membership[match.player]
	if m and m.arenaId == st.arena.id and m.role == "Fighting" then
		membership[match.player] = nil
	end
	if st.match == match then
		st.match = nil
	end
	pcall(resetArenaAttributes, st)
	setState(st, "Idle")
	log(("Match %d aufgeräumt (%s)"):format(match.id, reason))
	advanceQueue(st)
end

function MatchService.abort(match, reason: string)
	if match.cleaned then
		return
	end
	if match.state == "Starting" or not match.models then
		cleanup(match, reason)
		return
	end
	finish(match, reason)
	if reason ~= "Leave" then
		-- Spieler ist weg, tot oder respawnt: ohne Ergebnisbildschirm sofort aufräumen.
		cleanup(match, reason)
	end
end

-- Laufender Betrieb ------------------------------------------------------------------
local function enforceFighterZone(match, t: number)
	local p = match.models.player
	local pos = p.root.Position
	if match.lastPos and match.lastPosAt and t > (match.teleportGraceUntil or 0) then
		local dt = t - match.lastPosAt
		if dt > 0 then
			local speed = (pos - match.lastPos).Magnitude / dt
			if speed > Config.Fighter.MaxPlausibleSpeed * 1.5 then
				CombatService.markSuspect(match, "player", t + 0.5)
			end
		end
	end
	if not ArenaService.isInFightZone(match.arena, pos, Config.Fighter.BoundsHardTolerance) then
		local back = ArenaService.clampToFightZone(match.arena, pos)
		p.model:PivotTo(CFrame.new(back) * p.root.CFrame.Rotation)
		p.root.AssemblyLinearVelocity = Vector3.zero
		match.teleportGraceUntil = t + 0.5
		CombatService.markSuspect(match, "player", t + 0.5)
		pos = back
	end
	match.lastPos = pos
	match.lastPosAt = t
end

local function keepSpectatorsOut(st, t: number)
	if not Config.Arena.KeepSpectatorsOutOfRing or t < (st.keepOutAt or 0) then
		return
	end
	st.keepOutAt = t + 0.4
	local match = st.match
	for _, player in Players:GetPlayers() do
		if player ~= match.player then
			local character, _, root = getCharacter(player)
			if character and root and ArenaService.isInRing(st.arena, root.Position) then
				local out = ArenaService.nearestOutside(st.arena, root.Position)
				character:PivotTo(CFrame.new(out) * root.CFrame.Rotation)
				match.warned = match.warned or {}
				if not match.warned[player] then
					match.warned[player] = true
					notice(
						player,
						"Der Ring ist während des Kampfs gesperrt – Zuschauen ist von außen möglich.",
						"warn"
					)
				end
			end
		end
	end
end

local function maintainQueue(st, t: number)
	if t < (st.queueCheckAt or 0) then
		return
	end
	st.queueCheckAt = t + 1
	for i = #st.queue, 1, -1 do
		local player = st.queue[i]
		local _, _, root = getCharacter(player)
		local tooFar = root and (root.Position - st.arena.cframe.Position).Magnitude > Config.Match.QueueMaxDistance
		if player.Parent ~= Players or tooFar then
			table.remove(st.queue, i)
			local m = membership[player]
			if m and m.role == "Queued" then
				membership[player] = nil
			end
			if player.Parent == Players then
				notice(player, "Du hast dich vom Boxstand entfernt und die Warteschlange verlassen.")
				send(player, "Queue", { arenaId = st.arena.id, position = 0 })
			end
			updateQueueNotices(st)
		end
	end
end

local function stepArena(st, t: number, dt: number)
	maintainQueue(st, t)
	if st.state == "Queued" and st.reservedBy then
		local character = getCharacter(st.reservedBy)
		if st.reservedBy.Parent ~= Players or not character then
			releaseReservation(st)
		elseif t > st.reservedUntil then
			releaseReservation(st, "Zeit für die Auswahl abgelaufen.")
		end
		return
	end
	local match = st.match
	if not match or not match.models or match.cleaned then
		return
	end
	local state = match.state
	if state == "Intro" then
		NPCController.face(match)
		enforceFighterZone(match, t)
		if t >= match.introEndsAt then
			beginCountdown(match, t)
		end
	elseif state == "Countdown" then
		NPCController.face(match)
		enforceFighterZone(match, t)
		if t >= match.countdownEndsAt then
			beginFight(match, t)
		end
	elseif state == "Fighting" then
		CombatService.step(match, t, dt)
		if match.state == "Fighting" then
			NPCController.step(match, t)
			enforceFighterZone(match, t)
			syncArena(match)
			if t >= match.fightEndsAt then
				finish(match, "Timeout")
			end
		end
	elseif state == "Finished" then
		NPCController.face(match)
		if t >= match.resultEndsAt then
			cleanup(match, "Done")
		end
	end
	if st.match and (match.state == "Intro" or match.state == "Countdown" or match.state == "Fighting") then
		keepSpectatorsOut(st, t)
	end
end

-- Anfragen ---------------------------------------------------------------------------
local function handleRequest(player: Player, kind: string, a: any, b: any, c: any)
	local m = membership[player]
	local st = m and states[m.arenaId]

	if kind == "SelectOpponent" then
		if not m or m.role ~= "Selecting" or not st or st.state ~= "Queued" or st.reservedBy ~= player then
			return
		end
		if typeof(a) ~= "number" or a ~= a or a % 1 ~= 0 then
			return
		end
		local def = Opponents.Get(a)
		if not def then
			return
		end
		if def.Id > unlockInfo(player).highest then
			notice(player, "Dieser Gegner ist noch gesperrt.", "warn")
			return
		end
		local _, _, root = getCharacter(player)
		if not root or (root.Position - st.arena.cframe.Position).Magnitude > Config.Match.QueueMaxDistance then
			releaseReservation(st, "Du bist zu weit vom Ring entfernt.")
			return
		end
		startMatch(st, player, def)
	elseif kind == "CancelSelect" then
		if m and m.role == "Selecting" and st and st.reservedBy == player then
			releaseReservation(st)
		end
	elseif kind == "LeaveQueue" then
		if m and m.role == "Queued" and st then
			removeFromQueue(st, player)
			notice(player, "Du hast die Warteschlange verlassen.")
		end
	elseif kind == "SkipIntro" then
		local match = st and st.match
		if match and match.player == player and match.state == "Intro" and match.introEndsAt then
			match.introEndsAt = math.min(match.introEndsAt, now())
		end
	elseif kind == "Leave" then
		if not m or not st then
			return
		end
		if m.role == "Selecting" then
			releaseReservation(st)
		elseif m.role == "Queued" then
			removeFromQueue(st, player)
		elseif m.role == "Fighting" then
			local match = st.match
			if match and match.player == player then
				if match.state == "Finished" then
					cleanup(match, "Done")
				else
					MatchService.abort(match, "Leave")
				end
			end
		end
	elseif kind == "Action" then
		local match = st and st.match
		if not match or match.player ~= player or match.state ~= "Fighting" then
			return
		end
		if typeof(a) ~= "string" or not Net.Actions[a] then
			return
		end
		local seq = nil
		if typeof(b) == "number" and b == b and b % 1 == 0 and b >= 0 and b < 2 ^ 31 then
			seq = b
		end
		local side = 0
		if typeof(c) == "number" and (c == -1 or c == 1) then
			side = c
		end
		local accepted, reason = CombatService.request(match, "player", a, { seq = seq, dodgeSide = side }, now())
		if not accepted and seq then
			send(player, "Reject", { seq = seq, reason = reason })
		end
	end
end

local function onPrompt(arena, player: Player)
	if not allowRequest(player) then
		return
	end
	local st = states[arena.id]
	if not st then
		return
	end
	local _, _, root = getCharacter(player)
	if not root then
		return
	end
	local maxDistance = arena.prompt.MaxActivationDistance + Config.Arena.PromptDistanceTolerance
	if (root.Position - arena.promptPart.Position).Magnitude > maxDistance then
		return
	end
	local m = membership[player]
	if m then
		if m.role == "Queued" then
			local other = states[m.arenaId]
			local position = other and queuePosition(other, player)
			if position then
				notice(player, ("Du bist Platz %d in der Warteschlange."):format(position))
			end
		end
		return
	end
	if st.state == "Idle" then
		reserve(st, player, Config.Match.SelectTimeout, false)
	else
		enqueue(st, player)
	end
end

function MatchService.init(request: RemoteEvent, event: RemoteEvent)
	eventRemote = event
	ArenaService.init(onPrompt)
	for _, arena in ArenaService.all() do
		states[arena.id] =
			{ arena = arena, state = "Idle", reservedBy = nil, reservedUntil = 0, queue = {}, match = nil }
		resetArenaAttributes(states[arena.id])
	end

	request.OnServerEvent:Connect(function(player: Player, kind: any, a: any, b: any, c: any)
		if typeof(kind) ~= "string" or not Net.RequestKinds[kind] then
			return
		end
		if not allowRequest(player) then
			return
		end
		local ok, err = pcall(handleRequest, player, kind, a, b, c)
		if not ok then
			warn("[NEON K.O.] Fehler bei Anfrage", kind, err)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local m = membership[player]
		local st = m and states[m.arenaId]
		if st then
			if m.role == "Fighting" and st.match and st.match.player == player then
				MatchService.abort(st.match, "Left")
			elseif m.role == "Selecting" and st.reservedBy == player then
				releaseReservation(st)
			elseif m.role == "Queued" then
				removeFromQueue(st, player)
			end
		end
		membership[player] = nil
		buckets[player] = nil
		unlocks[player.UserId] = nil
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local t = now()
		for _, st in states do
			local ok, err = pcall(stepArena, st, t, dt)
			if not ok then
				warn("[NEON K.O.] Fehler im Arena-Ablauf – Kampf wird sicher beendet:", err)
				local match = st.match
				if match then
					pcall(cleanup, match, "Error")
				end
				-- Falls auch das Aufräumen scheiterte: Arena trotzdem freigeben, damit sie nicht hängen bleibt.
				st.match = nil
				if st.state ~= "Idle" then
					local reserved = st.reservedBy
					st.reservedBy = nil
					if reserved then
						membership[reserved] = nil
						send(reserved, "CloseSelect", {})
					end
					pcall(setState, st, "Idle")
					pcall(advanceQueue, st)
				end
			end
		end
	end)

	-- Arenen, die nach dem Start auftauchen (z. B. Streaming), nachträglich übernehmen.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, arena in ArenaService.all() do
				if not states[arena.id] then
					states[arena.id] =
						{ arena = arena, state = "Idle", reservedBy = nil, reservedUntil = 0, queue = {}, match = nil }
					resetArenaAttributes(states[arena.id])
				end
			end
		end
	end)
end

function MatchService.shutdown()
	for _, st in states do
		if st.match then
			pcall(cleanup, st.match, "Shutdown")
		end
	end
end

return MatchService
