--[[
NEON K.O. · Werkzeug 05 · Rückbau

MODE = "disable" – NEON K.O. abschalten, alles bleibt installiert (Main + Client deaktiviert).
MODE = "enable"  – wieder einschalten.
MODE = "remove"  – NEON K.O. vollständig herauslösen: die drei ArcadeBoxing-Teile werden nach
                   ServerStorage.NEON_KO_Removed_<Datum> verschoben (nicht gelöscht), der Tag
                   ArcadeBoxingFloor wird entfernt.
RESTORE_OLD_LOGIC = true – zusätzlich alles, was Werkzeug 02 deaktiviert hat, exakt auf den
                   vorherigen Wert zurücksetzen (alte Boxlogik wieder aktiv).

Danach Place speichern. Komplett-Rückfall jederzeit: gesicherte .rbxl-Datei öffnen.
]]

local MODE = "disable" -- "disable" | "enable" | "remove"
local RESTORE_OLD_LOGIC = false

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local shared = ReplicatedStorage:FindFirstChild("ArcadeBoxing")
local server = ServerScriptService:FindFirstChild("ArcadeBoxing")
local scripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local client = scripts and scripts:FindFirstChild("ArcadeBoxingClient")
local main = server and server:FindFirstChild("Main")

local recording = nil
pcall(function()
	recording = ChangeHistoryService:TryBeginRecording("NEON K.O. Rückbau", "NEON K.O. Rückbau")
end)

local ok, err = pcall(function()
	if MODE == "disable" or MODE == "enable" then
		local enabled = MODE == "enable"
		for _, s in { main, client } do
			if s and s:IsA("BaseScript") then
				s.Enabled = enabled
				print(("   %s → Enabled = %s"):format(s:GetFullName(), tostring(enabled)))
			end
		end
	elseif MODE == "remove" then
		local folder = Instance.new("Folder")
		folder.Name = "NEON_KO_Removed_" .. os.date("%Y%m%d_%H%M%S")
		folder.Parent = ServerStorage
		for _, instance in { shared, server, client } do
			if instance then
				local path = instance:GetFullName()
				if instance:IsA("BaseScript") then
					instance.Enabled = false
				end
				instance:SetAttribute("NEONKO_OriginalPath", path)
				instance.Parent = folder
				print("   verschoben:", path, "→", folder:GetFullName())
			end
		end
		for _, floor in CollectionService:GetTagged("ArcadeBoxingFloor") do
			floor:RemoveTag("ArcadeBoxingFloor")
			print("   Tag entfernt:", floor:GetFullName())
		end
	else
		error("Unbekannter MODE: " .. tostring(MODE))
	end

	if RESTORE_OLD_LOGIC then
		local restored = 0
		local candidates = {}
		for _, name in
			{
				"Workspace",
				"ServerScriptService",
				"ServerStorage",
				"ReplicatedStorage",
				"ReplicatedFirst",
				"StarterPlayer",
				"StarterGui",
				"StarterPack",
			}
		do
			for _, d in game:GetService(name):GetDescendants() do
				table.insert(candidates, d)
			end
		end
		for _, d in candidates do
			local by = d:GetAttribute("NEONKO_DisabledBy")
			if by ~= nil then
				local original = d:GetAttribute("NEONKO_Original")
				if d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("LayerCollector") then
					(d :: any).Enabled = original ~= false
				elseif d:IsA("ClickDetector") and typeof(original) == "number" then
					d.MaxActivationDistance = original
				end
				d:SetAttribute("NEONKO_DisabledBy", nil)
				d:SetAttribute("NEONKO_Original", nil)
				restored += 1
				print("   alte Logik wiederhergestellt:", d:GetFullName())
			end
		end
		print(("[NEON K.O.] %d alte Instanzen wiederhergestellt."):format(restored))
	end
end)

if recording then
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
end
if ok then
	print("[NEON K.O.] Rückbau-Schritt abgeschlossen (" .. MODE .. "). Bitte Place speichern.")
else
	warn("[NEON K.O.] Rückbau abgebrochen:", err)
end
