-- Gemeinsame Namen für Tags, Attribute und Laufzeit-Instanzen (alle mit Präfix, um Konflikte zu vermeiden).

return {
	RuntimeFolder = "ArcadeBoxingRuntime",
	FighterTag = "ABX_Fighter",

	-- Attribute an Kämpfer-Modellen (Spieler-Charakter und NPC), repliziert an alle Clients.
	Fighter = {
		Arena = "ABX_Arena",
		Role = "ABX_Role", -- "Player" | "NPC"
		OpponentKey = "ABX_OpponentKey",
		Action = "ABX_Action",
		ActionId = "ABX_ActionId",
		ActionStart = "ABX_ActionStart",
		ActionDuration = "ABX_ActionDur",
		ExtraWindup = "ABX_ExtraWindup",
		DodgeSide = "ABX_DodgeSide",
		Block = "ABX_Block",
		Seq = "ABX_Seq",
		Telegraph = "ABX_Telegraph",
	},

	-- Attribute am Arena-Laufzeitordner (Workspace.ArcadeBoxingRuntime.Arena_<n>).
	Arena = {
		Id = "ArenaId",
		State = "State",
		MatchId = "MatchId",
		FighterUserId = "FighterUserId",
		FighterName = "FighterName",
		OpponentId = "OpponentId",
		OpponentName = "OpponentName",
		PlayerHP = "PlayerHP",
		PlayerMaxHP = "PlayerMaxHP",
		NpcHP = "NpcHP",
		NpcMaxHP = "NpcMaxHP",
		PlayerEnergy = "PlayerEnergy",
		NpcEnergy = "NpcEnergy",
		PlayerCombo = "PlayerCombo",
		NpcCombo = "NpcCombo",
		IntroEndsAt = "IntroEndsAt",
		CountdownEndsAt = "CountdownEndsAt",
		FightEndsAt = "FightEndsAt",
		Result = "Result",
		QueueLength = "QueueLength",
	},

	Instances = {
		PromptPart = "ABX_PromptAnchor",
		Prompt = "ArcadeBoxingPrompt",
		BoardPart = "ABX_BoardAnchor",
		Gear = "ABX_Gear",
		ForceField = "ABX_ForceField",
		Align = "ABX_Align",
		AlignAttachment = "ABX_AlignAttachment",
	},
}
