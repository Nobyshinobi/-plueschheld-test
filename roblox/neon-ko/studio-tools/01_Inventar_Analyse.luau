--[[
NEON K.O. · Werkzeug 01 · Inventar & Analyse (NUR LESEN – verändert nichts)

Zweck (Phase A): Findet den vorhandenen Boxstand, seine Teile, Skripte, Interaktionen und alle
Skripte im Spiel, die nach Boxlogik aussehen. Ergebnis erscheint im Output-Fenster zwischen
"===== NEON K.O. INVENTAR BEGINN =====" und "ENDE". Diesen Block bitte komplett zurückschicken.

Anwendung: Gesamten Dateiinhalt in die Studio-Befehlsleiste (View › Command Bar) einfügen, Enter.
Optional: Vorher den Boxstand im Explorer markieren – dann wird genau diese Auswahl analysiert.
]]

local KEYWORDS =
	{ "box", "boxing", "boxen", "boxer", "ring", "punch", "fight", "kampf", "arena", "glove", "handschuh", "ko" }
local MAX_SCRIPT_HITS = 3
local MAX_LIST = 40

local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")

local lines = {}
local function out(fmt: string, ...)
	table.insert(lines, if select("#", ...) > 0 then string.format(fmt, ...) else fmt)
end

local function matches(name: string): string?
	local lower = string.lower(name)
	for _, word in KEYWORDS do
		if word == "ko" then
			if lower == "ko" or string.find(lower, "%f[%a]ko%f[%A]") then
				return word
			end
		elseif string.find(lower, word, 1, true) then
			return word
		end
	end
	return nil
end

local function safe(fn, default)
	local ok, value = pcall(fn)
	if ok then
		return value
	end
	return default
end

local function describeContainer(root: Instance)
	local parts, meshes, scripts, prompts, clicks, seats, lights, sounds, anims, guis, remotes =
		0, 0, {}, {}, {}, 0, 0, 0, {}, {}, {}
	local neon = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d:IsA("MeshPart") then
				meshes += 1
			end
			if d.Material == Enum.Material.Neon then
				neon += 1
			end
			if d:IsA("Seat") or d:IsA("VehicleSeat") then
				seats += 1
			end
		elseif d:IsA("LuaSourceContainer") then
			table.insert(scripts, d)
		elseif d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		elseif d:IsA("ClickDetector") then
			table.insert(clicks, d)
		elseif d:IsA("Light") then
			lights += 1
		elseif d:IsA("Sound") then
			sounds += 1
		elseif d:IsA("Animation") then
			table.insert(anims, d)
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			table.insert(guis, d)
		elseif d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent") then
			table.insert(remotes, d)
		end
	end
	out("  Pfad: %s (%s)", root:GetFullName(), root.ClassName)
	if root:IsA("Model") then
		local cf, size = (root :: Model):GetBoundingBox()
		out(
			"  Bounding Box: Mitte (%.1f, %.1f, %.1f) · Größe %.1f × %.1f × %.1f",
			cf.X,
			cf.Y,
			cf.Z,
			size.X,
			size.Y,
			size.Z
		)
	elseif root:IsA("BasePart") then
		out(
			"  Teil: Position (%.1f, %.1f, %.1f) · Größe %.1f × %.1f × %.1f",
			root.Position.X,
			root.Position.Y,
			root.Position.Z,
			root.Size.X,
			root.Size.Y,
			root.Size.Z
		)
	end
	out(
		"  Parts %d (MeshParts %d, Neon %d) · Lichter %d · Sounds %d · Sitze %d",
		parts,
		meshes,
		neon,
		lights,
		sounds,
		seats
	)
	local tags = safe(function()
		return root:GetTags()
	end, {})
	if #tags > 0 then
		out("  Tags: %s", table.concat(tags, ", "))
	end
	for _, s in scripts do
		local enabled = safe(function()
			return (s :: any).Enabled
		end, nil)
		out(
			"  SKRIPT %s (%s%s)",
			s:GetFullName(),
			s.ClassName,
			if enabled == false then ", deaktiviert" elseif enabled == true then ", aktiv" else ""
		)
	end
	for _, p in prompts do
		out(
			"  PROMPT %s · ActionText=%q ObjectText=%q Enabled=%s",
			p:GetFullName(),
			p.ActionText,
			p.ObjectText,
			tostring(p.Enabled)
		)
	end
	for _, c in clicks do
		out("  CLICKDETECTOR %s · Reichweite %.0f", c:GetFullName(), c.MaxActivationDistance)
	end
	for _, a in anims do
		out("  ANIMATION %s · %s", a:GetFullName(), a.AnimationId)
	end
	for _, g in guis do
		out("  GUI %s (%s)", g:GetFullName(), g.ClassName)
	end
	for _, r in remotes do
		out("  REMOTE/BINDABLE %s (%s)", r:GetFullName(), r.ClassName)
	end
end

out("===== NEON K.O. INVENTAR BEGINN =====")
out("Place: %s · PlaceId %d · Datum %s", game.Name, game.PlaceId, os.date("%Y-%m-%d %H:%M"))

-- Projekt-Einstellungen, die das Minispiel betreffen
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
out("")
out("[Einstellungen]")
for _, entry in
	{
		{
			"Workspace.StreamingEnabled",
			function()
				return Workspace.StreamingEnabled
			end,
		},
		{
			"Workspace.PlayerScriptsUseInputActionSystem",
			function()
				return (Workspace :: any).PlayerScriptsUseInputActionSystem
			end,
		},
		{
			"Workspace.AuthorityMode",
			function()
				return (Workspace :: any).AuthorityMode
			end,
		},
		{
			"Workspace.SignalBehavior",
			function()
				return Workspace.SignalBehavior
			end,
		},
		{
			"StarterPlayer.GameSettingsAvatar",
			function()
				return (StarterPlayer :: any).GameSettingsAvatar
			end,
		},
		{
			"StarterPlayer.CharacterWalkSpeed",
			function()
				return StarterPlayer.CharacterWalkSpeed
			end,
		},
		{
			"StarterPlayer.CharacterUseJumpPower",
			function()
				return StarterPlayer.CharacterUseJumpPower
			end,
		},
		{
			"StarterPlayer.EnableMouseLockOption",
			function()
				return StarterPlayer.EnableMouseLockOption
			end,
		},
		{
			"StarterPlayer.LoadCharacterAppearance",
			function()
				return StarterPlayer.LoadCharacterAppearance
			end,
		},
	}
do
	out("  %s = %s", entry[1], tostring(safe(entry[2], "?")))
end

-- Bereits installiert?
out("")
out("[NEON K.O. bereits vorhanden?]")
local rs = game:GetService("ReplicatedStorage"):FindFirstChild("ArcadeBoxing")
local sss = game:GetService("ServerScriptService"):FindFirstChild("ArcadeBoxing")
local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local client = sps and sps:FindFirstChild("ArcadeBoxingClient")
out("  ReplicatedStorage.ArcadeBoxing: %s", if rs then "ja" else "nein")
out("  ServerScriptService.ArcadeBoxing: %s", if sss then "ja" else "nein")
out("  StarterPlayerScripts.ArcadeBoxingClient: %s", if client then "ja" else "nein")
local floors = CollectionService:GetTagged("ArcadeBoxingFloor")
out("  Markierte Ringböden (Tag ArcadeBoxingFloor): %d", #floors)
for _, f in floors do
	out("    %s", f:GetFullName())
end

-- Kandidaten für den Boxstand
out("")
out("[Kandidaten Boxstand / Ring]")
local selected = Selection:Get()
local candidates = {}
if #selected > 0 then
	out("  (Analysiere die aktuelle Explorer-Auswahl)")
	candidates = selected
else
	for _, d in Workspace:GetDescendants() do
		if (d:IsA("Model") or d:IsA("Folder")) and matches(d.Name) then
			-- nur oberste Treffer (keine Unterordner bereits gefundener Kandidaten)
			local nested = false
			for _, c in candidates do
				if d:IsDescendantOf(c) then
					nested = true
					break
				end
			end
			if not nested then
				table.insert(candidates, d)
			end
		end
	end
end
if #candidates == 0 then
	out("  Keine Treffer über Namen. Bitte Boxstand im Explorer markieren und erneut ausführen.")
end
for index, c in candidates do
	if index > MAX_LIST then
		out("  … weitere %d Treffer ausgelassen", #candidates - MAX_LIST)
		break
	end
	out("")
	out("Kandidat %d: %s", index, c.Name)
	describeContainer(c)
	-- große, flache Teile = mögliche Ringböden
	local floorsFound = 0
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") and floorsFound < 5 then
			local s = d.Size
			local dims = { s.X, s.Y, s.Z }
			table.sort(dims)
			if dims[1] <= 3 and dims[2] >= 8 and dims[3] >= 8 then
				floorsFound += 1
				out(
					"  MÖGLICHER RINGBODEN %s · %.1f × %.1f × %.1f · Material %s",
					d:GetFullName(),
					s.X,
					s.Y,
					s.Z,
					d.Material.Name
				)
			end
		end
	end
end

-- Skripte im ganzen Spiel mit Box-Bezug (Name oder Quelltext)
out("")
out("[Skripte mit Box-Bezug im gesamten Spiel]")
local services = {
	"Workspace",
	"ServerScriptService",
	"ServerStorage",
	"ReplicatedStorage",
	"ReplicatedFirst",
	"StarterPlayer",
	"StarterGui",
	"StarterPack",
	"Lighting",
	"SoundService",
}
local function isNeonKo(d: Instance): boolean
	for _, root in { sss, rs, client } do
		if root and (d == root or d:IsDescendantOf(root)) then
			return true
		end
	end
	return false
end
local hits = 0
for _, serviceName in services do
	local service = safe(function()
		return game:GetService(serviceName)
	end, nil)
	if service then
		for _, d in service:GetDescendants() do
			if d:IsA("LuaSourceContainer") and not isNeonKo(d) then
				local source = safe(function()
					return (d :: any).Source
				end, "")
				local reasons = {}
				if matches(d.Name) then
					table.insert(reasons, "Name")
				end
				local found = 0
				local lineNo = 0
				for line in string.gmatch(source .. "\n", "(.-)\n") do
					lineNo += 1
					if found < MAX_SCRIPT_HITS then
						local lower = string.lower(line)
						for _, word in { "punch", "boxing", "boxen", "boxer", "glove", "fight", "kampf", "ring" } do
							if string.find(lower, word, 1, true) then
								found += 1
								table.insert(
									reasons,
									("Z.%d: %s"):format(lineNo, string.sub(string.gsub(line, "^%s+", ""), 1, 90))
								)
								break
							end
						end
					end
				end
				if #reasons > 0 then
					hits += 1
					local enabled = safe(function()
						return (d :: any).Enabled
					end, nil)
					out(
						"  %s (%s, %s, %d Zeilen)",
						d:GetFullName(),
						d.ClassName,
						if enabled == false then "deaktiviert" else "aktiv",
						lineNo
					)
					for _, r in reasons do
						out("      %s", r)
					end
				end
			end
		end
	end
end
if hits == 0 then
	out("  keine")
end

-- Remotes/Bindables mit Box-Bezug
out("")
out("[Remotes/Bindables mit Box-Bezug]")
local remoteHits = 0
for _, serviceName in { "ReplicatedStorage", "ServerScriptService", "ServerStorage", "Workspace" } do
	for _, d in game:GetService(serviceName):GetDescendants() do
		if
			(
				d:IsA("RemoteEvent")
				or d:IsA("RemoteFunction")
				or d:IsA("UnreliableRemoteEvent")
				or d:IsA("BindableEvent")
			) and matches(d.Name)
		then
			remoteHits += 1
			out("  %s (%s)", d:GetFullName(), d.ClassName)
		end
	end
end
if remoteHits == 0 then
	out("  keine")
end

out("")
out("Hinweis: Dieses Werkzeug hat nichts verändert.")
out("===== NEON K.O. INVENTAR ENDE =====")
-- In Blöcken ausgeben, damit das Output-Fenster nichts abschneidet.
for i = 1, #lines, 40 do
	print(table.concat(lines, "\n", i, math.min(#lines, i + 39)))
end
