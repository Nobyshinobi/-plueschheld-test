-- Getrennte Zuschauer-Anzeige über dem Ring (nur für Unbeteiligte). Liest ausschließlich die
-- replizierten Arena-Attribute – Zuschauer können den Kampf nicht beeinflussen.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Keys = require(Shared:WaitForChild("Keys"))
local UI = require(script.Parent:WaitForChild("UI"))

local Spectator = {}

local AK = Keys.Arena
local C = UI.Colors
local boards = {}

local function buildBoard(folder: Folder)
	local anchor = folder:FindFirstChild(Keys.Instances.BoardPart)
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local board = UI.new("BillboardGui", {
		Name = "ABX_SpectatorBoard",
		Adornee = anchor,
		Size = UDim2.fromOffset(380, 120),
		LightInfluence = 0,
		MaxDistance = 150,
		AlwaysOnTop = false,
		Enabled = false,
		Parent = anchor,
	})
	local frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.2,
		Parent = board,
	}, { UI.corner(UDim.new(0, 14)), UI.stroke(C.Violet, 3, 0), UI.padding(8) })
	local title = UI.label({
		Text = "NEON K.O. · LIVE",
		Size = UDim2.fromScale(1, 0.24),
		FontFace = UI.TitleFont,
		TextColor3 = C.Toxic,
		Parent = frame,
	})
	local names =
		UI.label({ Text = "", Position = UDim2.fromScale(0, 0.26), Size = UDim2.fromScale(1, 0.22), Parent = frame })
	local left =
		UI.bar(frame, { Size = UDim2.fromScale(0.43, 0.16), Position = UDim2.fromScale(0, 0.55) }, C.Cyan, false)
	local right =
		UI.bar(frame, { Size = UDim2.fromScale(0.43, 0.16), Position = UDim2.fromScale(0.57, 0.55) }, C.Magenta, true)
	local status = UI.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.13, 0.26),
		FontFace = UI.TitleFont,
		Parent = frame,
	})
	local info = UI.label({
		Text = "",
		Position = UDim2.fromScale(0, 0.78),
		Size = UDim2.fromScale(1, 0.2),
		FontFace = UI.TextFont,
		Parent = frame,
	})
	return { board = board, title = title, names = names, left = left, right = right, status = status, info = info }
end

local RESULT = { Victory = "SIEG", Defeat = "NIEDERLAGE", Draw = "UNENTSCHIEDEN", Aborted = "ABGEBROCHEN" }

local function updateBoard(folder: Folder, b, dt: number)
	local state = folder:GetAttribute(AK.State) or "Idle"
	local fighterId = folder:GetAttribute(AK.FighterUserId) or 0
	local show = state ~= "Idle"
		and state ~= "Queued"
		and state ~= "Cleanup"
		and fighterId ~= Players.LocalPlayer.UserId
	b.board.Enabled = show
	if not show then
		return
	end
	local t = Workspace:GetServerTimeNow()
	b.names.Text = ("%s  vs  %s"):format(
		folder:GetAttribute(AK.FighterName) or "?",
		folder:GetAttribute(AK.OpponentName) or "?"
	)
	local pMax = folder:GetAttribute(AK.PlayerMaxHP) or 0
	local nMax = folder:GetAttribute(AK.NpcMaxHP) or 0
	UI.setBar(b.left, if pMax > 0 then (folder:GetAttribute(AK.PlayerHP) or 0) / pMax else 1, dt)
	UI.setBar(b.right, if nMax > 0 then (folder:GetAttribute(AK.NpcHP) or 0) / nMax else 1, dt)
	local fightEndsAt = folder:GetAttribute(AK.FightEndsAt) or 0
	if state == "Fighting" and fightEndsAt > 0 then
		b.status.Text = tostring(math.ceil(math.max(0, fightEndsAt - t)))
	elseif state == "Countdown" then
		b.status.Text = "…"
	else
		b.status.Text = ""
	end
	local queue = folder:GetAttribute(AK.QueueLength) or 0
	if state == "Finished" then
		local result = folder:GetAttribute(AK.Result) or ""
		b.info.Text = RESULT[result] or ""
	else
		b.info.Text = if queue > 0 then ("Warteschlange: %d"):format(queue) else "Zum Mitmachen am Ring FIGHT drücken"
	end
end

function Spectator.start()
	if not Config.Arena.SpectatorBoard then
		return
	end
	task.spawn(function()
		local runtime = Workspace:WaitForChild(Keys.RuntimeFolder, 60)
		if not runtime then
			return
		end
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, folder in runtime:GetChildren() do
				if folder:IsA("Folder") then
					local b = boards[folder]
					if b == nil or (b and not b.board.Parent) then
						b = buildBoard(folder) or false
						boards[folder] = b
					end
					if b then
						local ok, err = pcall(updateBoard, folder, b, dt)
						if not ok then
							warn("[NEON K.O.] Zuschauer-Anzeige:", err)
							boards[folder] = false
						end
					end
				end
			end
		end
	end)
end

return Spectator
