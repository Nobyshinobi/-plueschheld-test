--[[
NEON K.O. · Werkzeug 02 · Sicherung und gezieltes Deaktivieren der ALTEN Boxlogik

VOR diesem Werkzeug: Place als Datei sichern (File › Save to File As… → z. B. Park_vor_NEON_KO.rbxl).

Schritt 1 – SICHERN (Standard, verändert keine Originale):
  Im Explorer genau die Instanzen markieren, die NUR zum alten Boxspiel gehören (Skripte,
  alte ProximityPrompts/ClickDetectors, alte Box-GUIs). MODE = "backup" lassen, Datei in die
  Befehlsleiste einfügen, Enter. Kopien landen in ServerStorage.NEON_KO_Backup_<Datum>.

Schritt 2 – DEAKTIVIEREN (erst nach geprüfter Sicherung):
  Dieselbe Auswahl erneut markieren, MODE = "disable" setzen, ausführen.
  Skripte → Enabled = false · ProximityPrompt → Enabled = false · ClickDetector → Reichweite 0 ·
  ScreenGui/SurfaceGui/BillboardGui → Enabled = false. Nichts wird gelöscht.
  Rückgängig: Strg+Z direkt danach, oder Werkzeug 05 (RESTORE_OLD_LOGIC = true).
]]

local MODE = "backup" -- "backup" | "disable"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

local ATTR_DISABLED_BY = "NEONKO_DisabledBy"
local ATTR_ORIGINAL = "NEONKO_Original"

local selected = Selection:Get()
if #selected == 0 then
	warn("[NEON K.O.] Nichts ausgewählt. Bitte die alten Box-Instanzen im Explorer markieren.")
	return
end

local function isNeonKo(instance: Instance): boolean
	local full = instance:GetFullName()
	return string.find(full, "ArcadeBoxing", 1, true) ~= nil or string.find(full, "NEON_KO", 1, true) ~= nil
end

local function record(name: string, fn: () -> ())
	local id = nil
	pcall(function()
		id = ChangeHistoryService:TryBeginRecording(name, name)
	end)
	local ok, err = pcall(fn)
	if id then
		ChangeHistoryService:FinishRecording(
			id,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	else
		pcall(function()
			ChangeHistoryService:SetWaypoint(name)
		end)
	end
	if not ok then
		warn("[NEON K.O.] Abgebrochen:", err)
	end
end

local function findBackupFor(instance: Instance): Instance?
	local full = instance:GetFullName()
	for _, folder in ServerStorage:GetChildren() do
		if folder:IsA("Folder") and string.sub(folder.Name, 1, 14) == "NEON_KO_Backup" then
			for _, copy in folder:GetChildren() do
				if copy:GetAttribute("NEONKO_OriginalPath") == full then
					return folder
				end
			end
		end
	end
	return nil
end

if MODE == "backup" then
	record("NEON K.O. Sicherung alte Boxlogik", function()
		local stamp = os.date("%Y%m%d_%H%M%S")
		local folder = Instance.new("Folder")
		folder.Name = "NEON_KO_Backup_" .. stamp
		folder:SetAttribute("CreatedAt", stamp)
		local count = 0
		local manifest = {}
		for _, instance in selected do
			if isNeonKo(instance) then
				warn("[NEON K.O.] Übersprungen (gehört zu NEON K.O.):", instance:GetFullName())
				continue
			end
			local archivable = instance.Archivable
			instance.Archivable = true
			local ok, copy = pcall(function()
				return instance:Clone()
			end)
			instance.Archivable = archivable
			if ok and copy then
				copy:SetAttribute("NEONKO_OriginalPath", instance:GetFullName())
				copy:SetAttribute("NEONKO_OriginalClass", instance.ClassName)
				-- Kopien dürfen in ServerStorage nicht laufen
				for _, d in copy:GetDescendants() do
					if d:IsA("BaseScript") then
						d.Enabled = false
					end
				end
				if copy:IsA("BaseScript") then
					copy.Enabled = false
				end
				copy.Parent = folder
				count += 1
				table.insert(manifest, instance:GetFullName() .. " (" .. instance.ClassName .. ")")
			else
				warn("[NEON K.O.] Konnte nicht kopiert werden:", instance:GetFullName())
			end
		end
		local list = Instance.new("StringValue")
		list.Name = "Manifest"
		list.Value = table.concat(manifest, "\n")
		list.Parent = folder
		folder.Parent = ServerStorage
		print(("[NEON K.O.] Sicherung erstellt: %s (%d Instanzen)"):format(folder:GetFullName(), count))
		for _, line in manifest do
			print("   ", line)
		end
		print('[NEON K.O.] Originale unverändert. Nächster Schritt: Auswahl behalten, MODE = "disable".')
	end)
elseif MODE == "disable" then
	record("NEON K.O. alte Boxlogik deaktivieren", function()
		local changed = 0
		for _, instance in selected do
			if isNeonKo(instance) then
				warn("[NEON K.O.] Übersprungen (gehört zu NEON K.O.):", instance:GetFullName())
				continue
			end
			local backup = findBackupFor(instance)
			if not backup then
				warn("[NEON K.O.] KEINE Sicherung gefunden – nicht deaktiviert:", instance:GetFullName())
				continue
			end
			local targets = { instance }
			for _, d in instance:GetDescendants() do
				table.insert(targets, d)
			end
			for _, target in targets do
				local before = nil
				if target:IsA("BaseScript") or target:IsA("ProximityPrompt") or target:IsA("LayerCollector") then
					before = (target :: any).Enabled;
					(target :: any).Enabled = false
				elseif target:IsA("ClickDetector") then
					before = target.MaxActivationDistance
					target.MaxActivationDistance = 0
				end
				if before ~= nil and target:GetAttribute(ATTR_DISABLED_BY) == nil then
					target:SetAttribute(ATTR_ORIGINAL, before)
					target:SetAttribute(ATTR_DISABLED_BY, backup.Name)
					changed += 1
					print("   deaktiviert:", target:GetFullName())
				end
			end
		end
		print(("[NEON K.O.] %d Instanzen deaktiviert. Rückgängig: Strg+Z oder Werkzeug 05."):format(changed))
	end)
else
	warn("[NEON K.O.] Unbekannter MODE:", MODE)
end
