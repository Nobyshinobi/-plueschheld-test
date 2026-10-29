-- NEON K.O. – zentrale Konfiguration (Server und Client lesen dieselben Werte).
-- Alle Zeiten in Sekunden, Distanzen in Studs. Schadenswerte gelten nur serverseitig;
-- der Client nutzt sie ausschließlich für Anzeige und Animations-Timing.

local Config = {}

Config.Version = "0.9.0"

-- Arena / vorhandener Boxring --------------------------------------------------------
Config.Arena = {
	-- Bevorzugt: die Bodenplatte des vorhandenen Rings mit diesem CollectionService-Tag markieren
	-- (Studio-Werkzeug 03_Ring_markieren.luau). Ein Tag verändert die Optik nicht.
	FloorTag = "ArcadeBoxingFloor",
	-- Optionaler Ordner mit unsichtbaren Markern (PlayerStart, OpponentStart, PromptPoint, ExitPoint).
	-- Wird neben bzw. in der Bodenplatte gesucht; fehlt er, berechnet ArenaService alles aus der Bodenplatte.
	AnchorsFolderName = "ArcadeBoxingAnchors",
	-- Abstand der Kampfzone zum Ringrand (Seile/Pfosten).
	EdgeMargin = 2.25,
	-- Startabstand der Kämpfer als Anteil der halben Ringlänge.
	StartSpread = 0.42,
	-- Höhe der Kampfzone über dem Boden (für Zuschauer-Sperre und Grenzprüfung).
	ZoneHeight = 12,
	-- ProximityPrompt
	PromptActionText = "FIGHT",
	PromptObjectText = "NEON K.O.",
	PromptBusyActionText = "Anstellen",
	PromptBusyObjectText = "Arena besetzt",
	PromptMinDistance = 12,
	PromptMaxDistance = 28,
	-- Serverseitige Toleranz auf die Prompt-Reichweite (Latenz).
	PromptDistanceTolerance = 6,
	-- Unbeteiligte Spieler während eines Kampfs sanft aus dem Ring schieben.
	KeepSpectatorsOutOfRing = true,
	-- Zuschauer-Anzeige über dem Ring
	SpectatorBoard = true,
}

-- Ablauf ---------------------------------------------------------------------------
Config.Match = {
	SelectTimeout = 25, -- Zeit für die Gegnerauswahl
	IntroDuration = 2.8, -- maximal ~3 s, überspringbar
	CountdownStep = 0.65, -- 3 · 2 · 1 · FIGHT!
	FightDuration = 60,
	ResultDuration = 4.5,
	AbortResultDuration = 1.5,
	DrawTolerance = 0.005, -- HP-Prozent-Differenz, ab der ein Zeitsieg zählt
	QueueMax = 8,
	QueueInviteTimeout = 15,
	QueueMaxDistance = 70, -- weiter weg = Warteschlange verlassen
	ServerTick = 1 / 30,
}

-- Kämpfer --------------------------------------------------------------------------
Config.Fighter = {
	PlayerMaxHP = 120,
	EnergyMax = 100,
	GuardMax = 100,
	GuardRegenPerSecond = 22,
	GuardRegenDelay = 0.6,
	GuardBreakStun = 0.9,
	WalkSpeed = 13,
	BlockWalkSpeed = 6,
	-- Zeitfenster, in dem nach einem Treffer in die nächste Attacke abgebrochen werden darf.
	HitCancelWindow = 0.28,
	-- Eingabepuffer: Eingaben kurz vor Ende einer Aktion werden nachgeholt.
	InputBuffer = 0.16,
	ComboWindow = 1.1,
	ComboMaxHits = 5,
	-- Nach ComboMaxHits: kurze Unverwundbarkeit + Rückstoß, damit niemand festgehalten wird.
	ComboBurstInvuln = 0.75,
	ComboDamageFalloff = 0.08,
	ComboDamageFloor = 0.55,
	-- Energiegewinn
	EnergyOnTakeHit = 5,
	EnergyOnPerfectDodge = 15,
	PerfectDodgeWindow = 0.22,
	-- Temporäre Neon-Handschuhe für den Spieler (werden beim Cleanup entfernt).
	GivePlayerGloves = true,
	-- Unsichtbares ForceField während des Kampfs (schützt vor fremdem Parkschaden).
	ProtectWithForceField = true,
	-- Server-Positionsprüfung: Kämpfer weiter außerhalb als dieser Wert wird zurückgesetzt.
	BoundsHardTolerance = 3,
	MaxPlausibleSpeed = 40, -- Studs/s, darüber gilt eine Positionsänderung als unplausibel
}

-- Angriffe. Windup = Ausholen, Active = Trefferfenster, Recovery = Nachlauf.
-- Hitbox: Box vor dem Angreifer (Breite, Höhe, Reichweite).
Config.Attacks = {
	Light = {
		Damage = 5,
		Windup = 0.1,
		Active = 0.08,
		Recovery = 0.2,
		Cooldown = 0.05,
		Hitstun = 0.32,
		Knockback = 4,
		Reach = 4.6,
		HitboxSize = Vector3.new(3.2, 3.4, 4.6),
		BlockDamageMultiplier = 0.15,
		GuardDamage = 9,
		EnergyOnHit = 8,
		EnergyOnBlock = 3,
		CancelInto = { "Light", "Heavy", "Special" },
		Shake = 0.25,
		Hitstop = 0.045,
	},
	Heavy = {
		Damage = 11,
		Windup = 0.28,
		Active = 0.1,
		Recovery = 0.38,
		Cooldown = 0.25,
		Hitstun = 0.6,
		Knockback = 12,
		Reach = 5.2,
		HitboxSize = Vector3.new(3.6, 3.6, 5.2),
		BlockDamageMultiplier = 0.3,
		GuardDamage = 34,
		EnergyOnHit = 12,
		EnergyOnBlock = 5,
		CancelInto = { "Special" },
		Shake = 0.55,
		Hitstop = 0.075,
	},
	Special = {
		Damage = 20,
		Windup = 0.45,
		Active = 0.14,
		Recovery = 0.55,
		Cooldown = 1.0,
		Hitstun = 0.9,
		Knockback = 26,
		Reach = 6,
		HitboxSize = Vector3.new(4.4, 4.2, 6),
		BlockDamageMultiplier = 0.45,
		GuardDamage = 60,
		EnergyOnHit = 0,
		EnergyOnBlock = 0,
		EnergyCost = 100,
		CancelInto = {},
		Shake = 0.9,
		Hitstop = 0.11,
	},
}

Config.Dodge = {
	Duration = 0.36,
	Invulnerable = 0.3,
	Cooldown = 1.1,
	Distance = 6,
}

-- Benannte Kurz-Kombos (Reihenfolge der zuletzt gelandeten Treffer, letzter Treffer zuletzt).
Config.Combos = {
	{ Id = "NeonRush", Name = "NEON RUSH", Sequence = { "Light", "Light", "Heavy" }, DamageBonus = 0.35 },
	{ Id = "TripleJab", Name = "TRIPLE JAB", Sequence = { "Light", "Light", "Light" }, DamageBonus = 0.2 },
	{ Id = "VoltFinish", Name = "VOLT FINISH", Sequence = { "Heavy", "Special" }, DamageBonus = 0.15 },
}

-- Eingaben -------------------------------------------------------------------------
Config.Input = {
	-- Input Action System (InputContext/InputAction/InputBinding) verwenden, wenn verfügbar.
	-- Fällt automatisch auf ContextActionService zurück, falls die Instanzen nicht erstellt werden können.
	PreferInputActionSystem = true,
	-- true = Kampftasten während des Kampfs für andere (niedriger priorisierte) Bindungen blockieren.
	-- Standard false, damit keine fremden Systeme beeinflusst werden. Wenn Park-Tasten (E/F/Q/R)
	-- im Kampf stören: auf true setzen und danach prüfen, dass HUD-Buttons weiter klickbar sind.
	SinkDuringFight = false,
	Priority = 2000,
	-- Alle ProximityPrompts nur lokal beim Kämpfer ausblenden, solange der Kampf läuft
	-- (verhindert, dass E für den harten Schlag einen Shop-/Park-Prompt in der Nähe auslöst).
	HidePromptsDuringFight = true,
	Keyboard = {
		Light = { Enum.KeyCode.MouseLeftButton },
		Heavy = { Enum.KeyCode.MouseRightButton, Enum.KeyCode.E },
		Block = { Enum.KeyCode.F },
		Dodge = { Enum.KeyCode.Q },
		Special = { Enum.KeyCode.R },
		Skip = { Enum.KeyCode.Space },
		Leave = { Enum.KeyCode.Backspace },
	},
	Gamepad = {
		Light = { Enum.KeyCode.ButtonX },
		Heavy = { Enum.KeyCode.ButtonY },
		Block = { Enum.KeyCode.ButtonL2 },
		Dodge = { Enum.KeyCode.ButtonB },
		Special = { Enum.KeyCode.ButtonR2 },
		Skip = { Enum.KeyCode.ButtonA },
		Leave = { Enum.KeyCode.DPadDown },
	},
	-- Verlassen per Taste muss kurz gehalten werden (versehentliches Abbrechen vermeiden).
	LeaveHoldTime = 0.8,
	Hints = {
		KeyboardAndMouse = "LMB Leicht  ·  RMB/E Hart  ·  F halten Block  ·  Q Ausweichen  ·  R Special  ·  WASD Bewegen",
		Gamepad = "X Leicht  ·  Y Hart  ·  LT halten Block  ·  B Ausweichen  ·  RT Special  ·  ↓ halten Verlassen",
		Touch = "",
	},
}

-- Kamera und Effekte -----------------------------------------------------------------
Config.Camera = {
	FieldOfView = 60,
	Distance = 9.5,
	ExtraDistancePerStud = 0.45,
	Height = 4.2,
	SideOffset = 3.2,
	Damping = 9,
	ShakeFrequency = 18,
	-- Effektstufen: Faktor für Kamerawackeln und Hitstop.
	EffectLevels = {
		{ Id = "Full", Label = "FX: VOLL", Shake = 1, Hitstop = 1 },
		{ Id = "Reduced", Label = "FX: SANFT", Shake = 0.35, Hitstop = 0.5 },
		{ Id = "Off", Label = "FX: AUS", Shake = 0, Hitstop = 0 },
	},
	DefaultEffectLevel = 2, -- bewusst "SANFT" als Standard, damit niemandem schlecht wird
}

Config.Effects = {
	MaxParticlesPerHit = 14,
	HitLight = true,
	ComicWords = { Light = { "POW!", "PAF!", "TAP!" }, Heavy = { "BAM!", "WUMMS!" }, Special = { "K-ZAP!", "VOLT!" } },
	Colors = {
		Violet = Color3.fromRGB(157, 78, 255),
		Cyan = Color3.fromRGB(0, 236, 255),
		Toxic = Color3.fromRGB(132, 255, 0),
		Magenta = Color3.fromRGB(255, 46, 196),
		White = Color3.fromRGB(245, 240, 255),
		Night = Color3.fromRGB(14, 8, 30),
		Danger = Color3.fromRGB(255, 70, 110),
		Gold = Color3.fromRGB(255, 214, 64),
	},
}

-- Sounds: rbxasset://-Pfade stammen aus dem Roblox-Client selbst (keine Uploads, keine Kosten).
-- Für eigene, rechtmäßig lizenzierte Sounds hier "rbxassetid://<ID>" eintragen; leer = stumm.
Config.Sounds = {
	Enabled = true,
	Volume = 0.55,
	Swing = "rbxasset://sounds/swordlunge.wav",
	HitLight = "rbxasset://sounds/action_jump_land.mp3",
	HitHeavy = "rbxasset://sounds/action_jump_land.mp3",
	Block = "rbxasset://sounds/clickfast.wav",
	Special = "rbxasset://sounds/electronicpingshort.wav",
	Countdown = "rbxasset://sounds/electronicpingshort.wav",
	KO = "rbxasset://sounds/action_falling.mp3",
	Ui = "rbxasset://sounds/button.wav",
}

-- Animationen ---------------------------------------------------------------------
-- Ohne IDs laufen alle Animationen prozedural (Motor6D-Posen, siehe Poses.luau) – das funktioniert
-- sofort und ohne Upload. Für Animator/AnimationTrack-Animationen die mit Werkzeug 04 erzeugten
-- KeyframeSequences im Animation Editor öffnen, selbst veröffentlichen und die IDs hier eintragen
-- (Format "rbxassetid://123"). Es sind bewusst KEINE IDs vorbelegt.
Config.Animations = {
	Guard = "",
	Light = "",
	Heavy = "",
	Special = "",
	Dodge = "",
	Hit = "",
	Block = "",
	KO = "",
	Victory = "",
}

-- Debug ------------------------------------------------------------------------------
Config.Debug = {
	Log = false,
	ShowHitboxes = false, -- nur in Studio wirksam
	UnlockAllInStudio = false,
}

return Config
