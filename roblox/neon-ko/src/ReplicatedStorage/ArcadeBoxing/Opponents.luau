-- Die vier NEON-K.O.-Gegner. Eigene Figuren aus Studio-R15-Rigs + Parts, keine fremden Modelle.
-- Freischaltung erfolgt nacheinander (Sieg gegen Gegner n schaltet n+1 frei, nur für die Sitzung).
--
-- AI-Werte (siehe NPCBrain.luau):
--   ReactionTime    Sekunden bis der NPC auf einen begonnenen Spielerangriff reagieren kann
--   Think           {min, max} Sekunden zwischen Entscheidungen im neutralen Zustand
--   Aggression      Wahrscheinlichkeit, in Reichweite anzugreifen
--   BlockChance     Wahrscheinlichkeit zu blocken, wenn rechtzeitig reagiert werden kann
--   DodgeChance     Wahrscheinlichkeit auszuweichen, wenn rechtzeitig reagiert werden kann
--   GuardStance     Wahrscheinlichkeit, im neutralen Zustand vorsorglich zu blocken
--   GuardDuration   {min, max} Sekunden, die diese vorsorgliche Deckung gehalten wird
--   CounterChance   Wahrscheinlichkeit, nach einem geblockten Treffer sofort zu kontern
--   Telegraph       zusätzliche, sichtbare Ausholzeit vor Heavy/Special (Fairness)
--   Patterns        Angriffsfolgen mit Gewicht
--   SpecialChance   Wahrscheinlichkeit, bei voller Energie das Special zu nutzen
--   Range           bevorzugte Kampfdistanz
--   Hesitation      Chance, eine Entscheidung auszulassen (macht leichte Gegner fehlerhafter)

local Opponents = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Opponents.List = {
	{
		Id = 1,
		Key = "Rookie",
		Name = "ROOKIE RUDI",
		Title = "Der Anfänger",
		Style = "Langsam, ehrlich, holt weit aus",
		Difficulty = 1,
		MaxHP = 140,
		DamageMultiplier = 0.9,
		MoveSpeed = 9,
		Body = { Height = 0.95, Width = 1.0, Depth = 1.0, Head = 1.05 },
		Colors = {
			Skin = rgb(255, 204, 153),
			Shirt = rgb(40, 210, 120),
			Shorts = rgb(20, 120, 80),
			Gloves = rgb(0, 236, 255),
			Accent = rgb(132, 255, 0),
		},
		Gear = { "Gloves", "Waistband", "Headband" },
		SpecialName = "ROOKIE ROCKET",
		AI = {
			ReactionTime = 0.5,
			Think = { 0.55, 0.95 },
			Aggression = 0.6,
			BlockChance = 0.2,
			DodgeChance = 0.05,
			GuardStance = 0.12,
			GuardDuration = { 0.45, 0.9 },
			CounterChance = 0,
			Telegraph = 0.35,
			Patterns = {
				{ Weight = 5, Sequence = { "Light" } },
				{ Weight = 3, Sequence = { "Light", "Light" } },
				{ Weight = 2, Sequence = { "Heavy" } },
			},
			SpecialChance = 0.35,
			Range = 4.2,
			Hesitation = 0.2,
		},
	},
	{
		Id = 2,
		Key = "Speed",
		Name = "BLITZ BELLA",
		Title = "Die Kombo-Rakete",
		Style = "Schnelle Serien, weicht gern aus",
		Difficulty = 2,
		MaxHP = 135,
		DamageMultiplier = 0.85,
		MoveSpeed = 14,
		Body = { Height = 0.92, Width = 0.9, Depth = 0.9, Head = 1.0 },
		Colors = {
			Skin = rgb(141, 85, 56),
			Shirt = rgb(255, 46, 196),
			Shorts = rgb(120, 20, 140),
			Gloves = rgb(255, 46, 196),
			Accent = rgb(0, 236, 255),
		},
		Gear = { "Gloves", "Waistband", "Mohawk", "Wristbands" },
		SpecialName = "BLITZ-GEWITTER",
		AI = {
			ReactionTime = 0.24,
			Think = { 0.3, 0.55 },
			Aggression = 0.7,
			BlockChance = 0.15,
			DodgeChance = 0.45,
			GuardStance = 0.08,
			GuardDuration = { 0.35, 0.7 },
			CounterChance = 0.2,
			Telegraph = 0.22,
			Patterns = {
				{ Weight = 3, Sequence = { "Light", "Light" } },
				{ Weight = 4, Sequence = { "Light", "Light", "Light" } },
				{ Weight = 2, Sequence = { "Light", "Light", "Heavy" } },
				{ Weight = 1, Sequence = { "Heavy" } },
			},
			SpecialChance = 0.6,
			Range = 3.8,
			Hesitation = 0.1,
		},
	},
	{
		Id = 3,
		Key = "Defender",
		Name = "BUNKER BRUNO",
		Title = "Der Konterkönig",
		Style = "Hohe Deckung, bestraft wilde Angriffe",
		Difficulty = 3,
		MaxHP = 165,
		DamageMultiplier = 1.0,
		MoveSpeed = 8.5,
		Body = { Height = 1.0, Width = 1.22, Depth = 1.12, Head = 0.98 },
		Colors = {
			Skin = rgb(234, 184, 146),
			Shirt = rgb(0, 140, 255),
			Shorts = rgb(10, 40, 110),
			Gloves = rgb(0, 236, 255),
			Accent = rgb(157, 78, 255),
		},
		Gear = { "Gloves", "Waistband", "ShoulderPads", "Visor" },
		SpecialName = "BUNKER-BRECHER",
		AI = {
			ReactionTime = 0.16,
			Think = { 0.45, 0.8 },
			Aggression = 0.45,
			BlockChance = 0.75,
			DodgeChance = 0.05,
			GuardStance = 0.6,
			GuardDuration = { 0.9, 1.7 },
			CounterChance = 0.65,
			Telegraph = 0.28,
			Patterns = {
				{ Weight = 3, Sequence = { "Heavy" } },
				{ Weight = 2, Sequence = { "Light", "Heavy" } },
				{ Weight = 2, Sequence = { "Light" } },
			},
			SpecialChance = 0.5,
			Range = 4.4,
			Hesitation = 0.08,
		},
	},
	{
		Id = 4,
		Key = "Boss",
		Name = "MEGA VOLT",
		Title = "Der Neon-Boss",
		Style = "Alles drauf – und ein gewaltiges Special",
		Difficulty = 4,
		MaxHP = 175,
		DamageMultiplier = 1.05,
		MoveSpeed = 11,
		Body = { Height = 1.12, Width = 1.1, Depth = 1.05, Head = 1.0 },
		Colors = {
			Skin = rgb(90, 60, 140),
			Shirt = rgb(30, 10, 50),
			Shorts = rgb(60, 20, 110),
			Gloves = rgb(132, 255, 0),
			Accent = rgb(132, 255, 0),
		},
		Gear = { "Gloves", "Waistband", "Crown", "Cape", "ChestCore" },
		SpecialName = "VOLT-STURM",
		AI = {
			ReactionTime = 0.26,
			Think = { 0.3, 0.6 },
			Aggression = 0.55,
			BlockChance = 0.5,
			DodgeChance = 0.25,
			GuardStance = 0.2,
			GuardDuration = { 0.5, 1.0 },
			CounterChance = 0.4,
			Telegraph = 0.3,
			Patterns = {
				{ Weight = 3, Sequence = { "Light", "Light", "Heavy" } },
				{ Weight = 2, Sequence = { "Heavy" } },
				{ Weight = 2, Sequence = { "Light", "Light" } },
				{ Weight = 1, Sequence = { "Light", "Heavy" } },
			},
			SpecialChance = 0.85,
			Range = 4.3,
			Hesitation = 0.05,
			-- Unter 40 % HP: schneller denken (Enrage)
			EnrageBelow = 0.4,
			EnrageThinkMultiplier = 0.7,
		},
	},
}

function Opponents.Get(id: number)
	for _, def in Opponents.List do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function Opponents.Count(): number
	return #Opponents.List
end

return Opponents
