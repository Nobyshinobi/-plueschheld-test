--[[
NEON K.O. · Werkzeug 03 · Ringboden markieren (keine optische Änderung)

Anwendung: Im Explorer die BODENPLATTE des vorhandenen Rings markieren (die Fläche, auf der
gekämpft wird – nicht Seile, Pfosten oder das ganze Gebäude). Datei in die Befehlsleiste
einfügen, Enter. Das Werkzeug setzt nur den CollectionService-Tag "ArcadeBoxingFloor" und
zeigt die berechnete Kampfzone an.

Optional CREATE_ANCHORS = true: legt neben der Bodenplatte einen Ordner "ArcadeBoxingAnchors"
mit unsichtbaren, nicht kollidierenden Markern an (PlayerStart, OpponentStart, PromptPoint).
Diese kann man verschieben, um Startpunkte/Interaktion fein einzustellen. Ein zusätzlicher
Part "ExitPoint" in diesem Ordner legt den Rückkehrpunkt fest (sonst: Position beim FIGHT-Drücken).
REMOVE = true entfernt den Tag (und mit CREATE_ANCHORS = true auch den Marker-Ordner) wieder.
]]

local CREATE_ANCHORS = false
local REMOVE = false

local TAG = "ArcadeBoxingFloor"
local EDGE_MARGIN = 2.25 -- wie Config.Arena.EdgeMargin
local START_SPREAD = 0.42 -- wie Config.Arena.StartSpread

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local selected = Selection:Get()
local floor = selected[1]
if #selected ~= 1 or not floor or not floor:IsA("BasePart") then
	warn("[NEON K.O.] Bitte GENAU EINE Bodenplatte (BasePart) des Rings auswählen.")
	return
end

local function computeFrame(part: BasePart): (CFrame, number, number)
	local cf, size = part.CFrame, part.Size
	local axes = {
		{ vec = cf.RightVector, len = size.X },
		{ vec = cf.UpVector, len = size.Y },
		{ vec = -cf.LookVector, len = size.Z },
	}
	local upIndex = 1
	for i = 2, 3 do
		if math.abs(axes[i].vec.Y) > math.abs(axes[upIndex].vec.Y) then
			upIndex = i
		end
	end
	local up = axes[upIndex]
	local upVec = if up.vec.Y >= 0 then up.vec else -up.vec
	local top = part.Position + upVec * (up.len / 2)
	local horizontal = {}
	for i = 1, 3 do
		if i ~= upIndex then
			table.insert(horizontal, axes[i])
		end
	end
	table.sort(horizontal, function(a, b)
		return a.len > b.len
	end)
	local flatX = Vector3.new(horizontal[1].vec.X, 0, horizontal[1].vec.Z)
	flatX = if flatX.Magnitude > 1e-3 then flatX.Unit else Vector3.xAxis
	return CFrame.fromMatrix(top, flatX, Vector3.yAxis), horizontal[1].len / 2, horizontal[2].len / 2
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
	end
	if not ok then
		warn("[NEON K.O.] Abgebrochen:", err)
	end
end

local function marker(name: string, cf: CFrame, parent: Instance)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Locked = false
	part.Parent = parent
end

if REMOVE then
	record("NEON K.O. Ringmarkierung entfernen", function()
		floor:RemoveTag(TAG)
		if CREATE_ANCHORS and floor.Parent then
			local anchors = floor.Parent:FindFirstChild("ArcadeBoxingAnchors")
			if anchors then
				anchors.Parent = nil
			end
		end
		print("[NEON K.O.] Tag entfernt von", floor:GetFullName())
	end)
	return
end

local frame, halfX, halfZ = computeFrame(floor)
local fightX, fightZ = halfX - EDGE_MARGIN, halfZ - EDGE_MARGIN
print(("[NEON K.O.] Bodenplatte %s"):format(floor:GetFullName()))
print(
	("   Ringfläche %.1f × %.1f Studs · Kampfzone %.1f × %.1f · Oberkante Y = %.2f"):format(
		halfX * 2,
		halfZ * 2,
		fightX * 2,
		fightZ * 2,
		frame.Y
	)
)
if fightX < 3 or fightZ < 2 then
	warn("[NEON K.O.] Kampfzone zu klein – ist das wirklich die Bodenplatte? Es wurde nichts verändert.")
	return
end
if floor:IsA("Part") and floor.Shape == Enum.PartType.Cylinder then
	print("   Runder Ring erkannt – die Kampfzone wird quadratisch innerhalb des Kreises gelegt.")
end

record("NEON K.O. Ring markieren", function()
	floor:AddTag(TAG)
	print("   Tag", TAG, "gesetzt (keine optische Änderung).")
	if CREATE_ANCHORS and floor.Parent then
		local existing = floor.Parent:FindFirstChild("ArcadeBoxingAnchors")
		if existing then
			print("   Ordner ArcadeBoxingAnchors existiert bereits – unverändert gelassen.")
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "ArcadeBoxingAnchors"
		local spread = math.max(2.5, fightX * START_SPREAD)
		local p = frame:PointToWorldSpace(Vector3.new(-spread, 3, 0))
		local n = frame:PointToWorldSpace(Vector3.new(spread, 3, 0))
		marker("PlayerStart", CFrame.lookAt(p, Vector3.new(n.X, p.Y, n.Z)), folder)
		marker("OpponentStart", CFrame.lookAt(n, Vector3.new(p.X, n.Y, p.Z)), folder)
		marker("PromptPoint", frame * CFrame.new(0, 3.5, 0), folder)
		folder.Parent = floor.Parent
		print("   Unsichtbare Marker angelegt in", folder:GetFullName(), "– bei Bedarf verschieben.")
	end
end)
