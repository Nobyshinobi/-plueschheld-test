# Änderungsprotokoll NEON K.O.

Stand: Paketversion 0.9.0 (siehe `Config.Version`). **Es wurden noch keine Änderungen an deinem
realen Place vorgenommen** – diese Liste beschreibt, was beim Einbau entsteht.

## 1. Installierte Instanzen (aus den `.rbxm`-Dateien)

```
ReplicatedStorage
└─ ArcadeBoxing (Folder)
   ├─ CombatRules, Config, Keys, Motion, Net, Opponents, Poses (ModuleScript)
ServerScriptService
└─ ArcadeBoxing (Folder)
   ├─ Main (Script)
   └─ ArenaService, CombatService, Gear, MatchService, NPCBrain, NPCController,
      NPCFactory, PlayerGuard (ModuleScript)
StarterPlayer
└─ StarterPlayerScripts
   └─ ArcadeBoxingClient (LocalScript)
      └─ CameraController, Effects, HUD, InputController, PoseDriver, SelectMenu,
         Spectator, UI (ModuleScript)
```

## 2. Änderungen an vorhandenen Objekten (nur durch die Studio-Werkzeuge, nur auf deine Auswahl)

| Werkzeug | Änderung | Rückweg |
|---|---|---|
| 03 | Tag `ArcadeBoxingFloor` am Ringboden | 03 mit `REMOVE = true` oder 05 `remove` |
| 03 (optional) | Ordner `ArcadeBoxingAnchors` (unsichtbare Parts) neben dem Ringboden | Ordner löschen |
| 02 `backup` | neuer Ordner `ServerStorage.NEON_KO_Backup_<Datum>` (Kopien) | Ordner löschen |
| 02 `disable` | alte Box-Skripte/Prompts/GUIs `Enabled = false`, ClickDetector-Reichweite 0; Originalwert in Attribut `NEONKO_Original`, Markierung `NEONKO_DisabledBy` | 05 mit `RESTORE_OLD_LOGIC = true` |
| 04 | `ServerStorage.RBX_ANIMSAVES.<Rig>.NEONKO_*` (KeyframeSequences) | löschen |

## 3. Zur Laufzeit erzeugt (Server)

| Instanz | Lebensdauer |
|---|---|
| `ReplicatedStorage.ArcadeBoxing.Remotes` mit `Request`, `Event` (RemoteEvent) | solange der Server läuft |
| `Workspace.ArcadeBoxingRuntime.Arena_<n>` (Folder mit Zustandsattributen) | solange der Server läuft |
| darin `ABX_PromptAnchor` (unsichtbarer Part) + `ArcadeBoxingPrompt` (ProximityPrompt) | dauerhaft |
| darin `ABX_BoardAnchor` (unsichtbarer Part für die Zuschauertafel) | dauerhaft |
| darin `NEON_KO_<Gegner>` (NPC-Model) | nur während eines Kampfs |
| am Kämpfer-Charakter: `ABX_ForceField` (unsichtbar), `ABX_Gear` (Handschuhe), Attribute `ABX_*`, Tag `ABX_Fighter` | nur während des Kampfs |
| am Kämpfer-Humanoid: WalkSpeed, JumpPower/JumpHeight/UseJumpPower, AutoRotate | während des Kampfs geändert, danach exakt zurückgesetzt |

## 4. Zur Laufzeit erzeugt/geändert (nur beim jeweiligen Client)

| Was | Lebensdauer |
|---|---|
| `PlayerGui.ArcadeBoxingHUD`, `ArcadeBoxingSelect`, `ArcadeBoxingToast` (ScreenGuis) | HUD nur im Kampf, Auswahl nur beim Wählen, Toasts kurz |
| `Workspace.ABX_ClientFX` (lokale Effekte, selbstlöschend) | Sekunden |
| `InputContext ABX_FightContext` unter `ArcadeBoxingClient` | aktiv nur im Kampf |
| AlignOrientation `ABX_Face` + Attachment am eigenen HumanoidRootPart | nur im Kampf |
| Kamera (Scriptable), FOV | nur im Kampf, danach vorheriger CameraType/Subject/FOV |
| CoreGui Backpack aus, `DevEnableMouseLock` aus, Sprung-Zustand aus, ProximityPromptService aus | nur im Kampf, danach vorheriger Wert |
| `Motor6D.Transform` der Kämpfer (prozedurale Posen) | nur solange der Kämpfer-Tag gesetzt ist |
| Zuschauertafel (BillboardGui) am Board-Anker | sichtbar nur während eines fremden Kampfs |

## 5. Bewusst nicht verändert

Boxstand-Optik und -Teile, andere Attraktionen, Musik, Shop, Spawn, Kamera außerhalb des Kampfs,
DataStores, Währungen, Monetarisierung, Avatar-Aussehen (kein Skin-Wechsel), Live-Version.

## 6. Rückbau

1. Abschalten: `05_Rueckbau.luau`, `MODE = "disable"`.
2. Herauslösen: `MODE = "remove"` (verschiebt nach `ServerStorage.NEON_KO_Removed_<Datum>`,
   entfernt den Ring-Tag), optional `RESTORE_OLD_LOGIC = true`.
3. Vollständig: `Park_vor_NEON_KO.rbxl` öffnen.

## 7. Versionen

| Version | Inhalt |
|---|---|
| 0.9.0 | Erstlieferung: MVP + alle 4 Gegner, HUD, Touch/Gamepad/PC, Warteschlange, Zuschauer, prozedurale Animationen, Studio-Werkzeuge, automatisierte Tests. Noch ohne Studio-Abnahme. |

## 8. Bekannte Lücken

- Keine Studio-Tests durchgeführt (siehe `TESTPLAN_Studio.md`).
- Keine veröffentlichten Animationen (prozedurale Posen als Ersatz; Export für den Animation Editor vorhanden).
- Sounds sind Platzhalter aus dem Roblox-Client (`rbxasset://`), ihr Vorhandensein ist ungeprüft.
- Hitstop ist rein visuell (Server-Timing läuft weiter).
- R6-Posen vereinfacht.
- Kein vollständiges Anti-Cheat (bewusste Grenzen: Zone, Tempo, Distanz, Blickrichtung, Rate-Limit).
