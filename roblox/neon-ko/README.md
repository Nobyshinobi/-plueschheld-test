# NEON K.O. – Arcade-Boxen für den vorhandenen Boxstand

Eigenständiges 3D-Box-Minispiel (Spieler vs. NPC) für deine Roblox-Park-Map. Es läuft im selben
Place, nutzt den vorhandenen Ring und verändert den Boxstand optisch nicht.

> **Wichtiger Stand (ehrlich):** In der Sitzung, in der dieses Paket entstand, gab es **keine
> Verbindung zu Roblox Studio (kein Studio-MCP)**. Ich habe dein reales Projekt deshalb **nicht
> gesehen, nichts darin verändert und nichts in Studio getestet**. Geliefert werden die fertigen
> Luau-Skripte, importierbare Modelldateien, Studio-Werkzeuge für Inventur/Sicherung/Rückbau,
> Einbau- und Testanleitungen. Alles, was außerhalb von Studio prüfbar ist, wurde automatisiert
> geprüft (siehe [Prüfstand](#prüfstand)). Die Abnahme in Studio steht noch aus.

---

## Inhalt

| Pfad | Zweck |
|---|---|
| `build/NEON_KO_ReplicatedStorage.rbxm` | → `ReplicatedStorage` (Ordner `ArcadeBoxing`: Config, Regeln, Gegner, Posen) |
| `build/NEON_KO_ServerScriptService.rbxm` | → `ServerScriptService` (Ordner `ArcadeBoxing`: Main + Server-Module) |
| `build/NEON_KO_StarterPlayerScripts.rbxm` | → `StarterPlayer › StarterPlayerScripts` (LocalScript `ArcadeBoxingClient`) |
| `studio-tools/01_Inventar_Analyse.luau` | Phase A: liest Boxstand, Skripte, Prompts, Einstellungen aus (ändert nichts) |
| `studio-tools/02_Sicherung_AlteBoxlogik.luau` | alte Boxlogik sichern, danach gezielt deaktivieren |
| `studio-tools/03_Ring_markieren.luau` | Ringboden per Tag markieren (keine Optikänderung), optional Marker |
| `studio-tools/04_Animationen_vorbereiten.luau` | KeyframeSequences für den Animation Editor erzeugen |
| `studio-tools/05_Rueckbau.luau` | abschalten / herauslösen / alte Logik wiederherstellen |
| `src/` | Quelltext (Rojo-Struktur), identisch mit den `.rbxm`-Dateien |
| `docs/PHASE_A_Analyse_und_Risiken.md` | Was vor dem Einbau zu prüfen ist + Risikoliste |
| `docs/TESTPLAN_Studio.md` | Phase-F-Testliste mit Status |
| `docs/AENDERUNGSPROTOKOLL.md` | alle erzeugten/geänderten Instanzen, Rückbauweg |
| `tests/`, `dev/` | automatische Prüfungen (Lune, selene, StyLua, API-Abgleich) |

---

## Einbau Schritt für Schritt

**0. Sicherung des ganzen Place (Pflicht).** `File › Save to File As…` →
`Park_vor_NEON_KO.rbxl`. Bei veröffentlichten Places gibt es zusätzlich die Versionshistorie
(Asset Manager / Game Settings), sie ersetzt die lokale Datei aber nicht.

**1. Inventur (Phase A).** `View › Command Bar` öffnen, Inhalt von
`studio-tools/01_Inventar_Analyse.luau` einfügen, Enter. Den Block zwischen
`NEON K.O. INVENTAR BEGINN` und `ENDE` aus dem Output-Fenster kopieren und mir schicken. Damit
passe ich Pfade, Ringgröße und die zu deaktivierenden alten Skripte an dein echtes Projekt an.

**2. Alte Boxlogik sichern.** Die Instanzen markieren, die *nur* zum alten Boxspiel gehören →
`02_Sicherung_AlteBoxlogik.luau` mit `MODE = "backup"` ausführen. Es entsteht
`ServerStorage.NEON_KO_Backup_<Datum>`. Originale bleiben unverändert.

**3. NEON K.O. einfügen.** Rechtsklick auf `ReplicatedStorage` › *Insert from File…* →
`NEON_KO_ReplicatedStorage.rbxm`. Ebenso `ServerScriptService` ← `NEON_KO_ServerScriptService.rbxm`
und `StarterPlayer › StarterPlayerScripts` ← `NEON_KO_StarterPlayerScripts.rbxm`.
Danach muss es geben:
`ReplicatedStorage.ArcadeBoxing`, `ServerScriptService.ArcadeBoxing.Main`,
`StarterPlayer.StarterPlayerScripts.ArcadeBoxingClient`.
*(Alternative für Rojo-Nutzer: `rojo serve default.project.json`.)*

**4. Ring markieren.** Die **Bodenplatte** des Rings im Explorer markieren →
`03_Ring_markieren.luau` ausführen. Es wird nur der Tag `ArcadeBoxingFloor` gesetzt.

**5. Testen.** `Test › Play` (F5), dann `Test › Clients and Servers` mit 2 Spielern und der
Geräte-Emulation (Handy/Tablet). Testliste: `docs/TESTPLAN_Studio.md`.

**6. Alte Boxlogik abschalten** (erst wenn NEON K.O. läuft): dieselbe Auswahl wie in Schritt 2
markieren, `02_…` mit `MODE = "disable"` ausführen.

**7. Veröffentlichen** nur nach deiner eigenen Abnahme. Das Paket veröffentlicht nichts selbst,
lädt keine Assets hoch und verursacht keine Kosten.

---

## Spielablauf

`FIGHT` am Ring (ProximityPrompt, Server prüft Reichweite) → Gegnerauswahl (4 Karten, nacheinander
freigeschaltet, nur für die Sitzung) → Intro ≤ 3 s (überspringbar) → Countdown 3 · 2 · 1 ·
FIGHT! → 60-Sekunden-Kampf → `K.O.!`/`TIME!` → `VICTORY` / `DEFEAT` / `DRAW` (bei Zeitablauf
nach verbleibenden HP in Prozent) → Rückkehr an den Ausgangspunkt. Jederzeit `VERLASSEN`.
Ist der Ring belegt: „Arena besetzt“, Warteschlange (mit Verlassen-Button) oder zuschauen
(Zuschauertafel über dem Ring). Der Ring ist während eines Kampfs für Unbeteiligte gesperrt.

### Steuerung

| Aktion | PC | Gamepad | Touch |
|---|---|---|---|
| Leichter Schlag | Linksklick | X | LIGHT |
| Harter Schlag | Rechtsklick oder E | Y | HEAVY |
| Deckung (halten) | F | LT | BLOCK |
| Ausweichen | Q (Richtung mit A/D) | B | DODGE |
| Special (volle Energie) | R | RT | SPECIAL |
| Bewegen | WASD | linker Stick | Standard-Stick |
| Intro überspringen | Leertaste / Linksklick | A | Button |
| Verlassen | Backspace halten / Button | Steuerkreuz ↓ halten | Button |

Kurze Kombos per Hit-Cancel: **L, L, H = NEON RUSH**, **L, L, L = TRIPLE JAB**,
**H → Special = VOLT FINISH**. Perfektes Ausweichen kurz vor dem Treffer gibt Energie.
Nach 5 Treffern in Folge gibt es einen „Combo Break“ (kein Dauer-Stunlock).
Hitstop und Kamerawackeln: Button `FX` (Voll / Sanft / Aus), Standard ist **Sanft**.

### Die vier Gegner

| # | Name | Stil | HP | Simulierte Siegquote* |
|---|---|---|---|---|
| 1 | ROOKIE RUDI | Anfänger, holt weit aus, blockt selten | 140 | 100 % |
| 2 | BLITZ BELLA | schnelle Serien, weicht gern aus | 135 | 66 % |
| 3 | BUNKER BRUNO | hohe Deckung, kontert geblockte Angriffe | 165 | 50 % |
| 4 | MEGA VOLT | Boss, alles gemischt, starkes Special, Enrage < 40 % HP | 175 | 35 % |

\*Siegquote eines einfachen Test-Bots mit menschlicher Reaktionszeit (~0,28 s) in einer
vereinfachten 1D-Simulation (`tests/run.luau`, 120 Kämpfe je Gegner). Das ist ein
Tendenzwert für die Reihenfolge der Schwierigkeit, **kein** Ersatz für echte Playtests.
Spieler-HP: 120. Feintuning: `Config.luau` und `Opponents.luau`.

---

## Architektur

```
ReplicatedStorage/ArcadeBoxing/        (geteilt, keine Geheimnisse)
  Config        alle Werte (Zeiten, Schaden, Tasten, Kamera, Sounds, Animation-IDs)
  Opponents     vier Gegner: Aussehen, Werte, KI-Parameter
  CombatRules   reine Kampfregeln (Aktionsfreigabe, Schaden, Kombos, Ergebnis)
  Poses         Posen + Zeitachsen (prozedurale Animationen, KeyframeSequence-Export)
  Keys, Net, Motion   Namen/Attribute, Remotes, kurze Bewegungsimpulse
  Remotes/      (vom Server zur Laufzeit angelegt: Request, Event)
ServerScriptService/ArcadeBoxing/
  Main          Start, BindToClose
  MatchService  Zustandsmaschine je Arena, Warteschlange, Freischaltung, Abbruch/Disconnect
  CombatService Aktionen, Overlap-Hitbox, Validierung, Schaden, Rückmeldungen
  NPCController / NPCBrain   KI: deterministische Zustandsmaschine mit Telegraphing
  ArenaService  findet den getaggten Ringboden, Kampfzone, Prompt
  NPCFactory / Gear   NPC aus R15-HumanoidDescription + selbst gebaute Ausrüstung
  PlayerGuard   sichert & stellt Spielerwerte wieder her
StarterPlayerScripts/ArcadeBoxingClient (LocalScript)
  PoseDriver, InputController, CameraController, HUD, SelectMenu, Effects, Spectator, UI
Workspace/ArcadeBoxingRuntime/Arena_1  (Laufzeit: Prompt, Zuschauertafel, NPC, Attribute)
```

**Zustände (Server = Wahrheit):** `Idle → Queued (Auswahl reserviert) → Intro → Countdown →
Fighting → Finished → Cleanup → Idle`.

**Sicherheit:** Der Client sendet nur Wünsche („Light“, „BlockStart“ …). Der Server prüft
Anfrageart, Typen (NaN/Inf/Strings), Zustand, Zugehörigkeit zum Kampf, Cooldowns und eine
Rate-Begrenzung (Token-Bucket). Treffer entstehen nur serverseitig im Trefferfenster: Overlap-Box
vor dem Angreifer, die **nur** den zugehörigen Gegner enthält (kein Friendly Fire in den Park),
dazu Distanz-, Blickrichtungs- und Kampfzonenprüfung, ein Treffer pro Angriff.
Unplausible Positionssprünge sperren Treffer kurz und setzen den Spieler in die Zone zurück.
Schaden ist nur virtuell – das Minispiel verändert niemals `Humanoid.Health`.

**Animationen:** Standardmäßig prozedural über `Motor6D.Transform` (auf jedem Client, zeitlich
exakt am Server-Treffermoment). Es sind **keine Asset-IDs eingetragen und keine erfunden**.
Für echte AnimationTracks: Werkzeug 04 → Animation Editor → *Publish to Roblox* (durch dich) →
IDs in `Config.Animations`.

---

## Wichtige Einstellungen (`ReplicatedStorage.ArcadeBoxing.Config`)

| Wert | Bedeutung |
|---|---|
| `Arena.FloorTag` | Tag des Ringbodens (Standard `ArcadeBoxingFloor`) |
| `Arena.KeepSpectatorsOutOfRing` | Unbeteiligte während des Kampfs aus dem Ring setzen |
| `Match.FightDuration` | Rundenzeit (60) |
| `Fighter.GivePlayerGloves` | temporäre Neon-Handschuhe für den Spieler |
| `Fighter.ProtectWithForceField` | unsichtbares ForceField während des Kampfs |
| `Input.PreferInputActionSystem` | Input Action System (Fallback: ContextActionService) |
| `Input.SinkDuringFight` | Kampftasten für andere Bindungen sperren (Standard aus) |
| `Input.HidePromptsDuringFight` | andere ProximityPrompts lokal ausblenden (Standard an) |
| `Camera.DefaultEffectLevel` | 1 Voll · 2 Sanft · 3 Aus |
| `Sounds.*` | eingebaute `rbxasset://`-Klänge; eigene lizenzierte IDs möglich, `Enabled = false` = stumm |
| `Animations.*` | eigene veröffentlichte Animation-IDs (leer = prozedural) |
| `Debug.UnlockAllInStudio` / `ShowHitboxes` / `Log` | Testhilfen nur für Studio |

---

## Prüfstand

Ausgeführt mit `dev/check-all.sh` (ohne Roblox Studio):

| Prüfung | Ergebnis |
|---|---|
| Rojo-Build der drei `.rbxm` + Strukturprüfung | ok |
| Luau-Kompilierung aller Dateien (Lune) | 0 Fehler |
| Abgleich aller Klassen/Eigenschaften/Methoden/Enums gegen Roblox-API-Dump v0.745 inkl. Deprecation | 0 Fehler (8 geprüfte Fehlalarme) |
| selene (Lint) / StyLua (Format) | 0 Fehler / sauber |
| Unit-Tests (Regeln, Kombos, Block, Dodge, KI-Determinismus, Posen) | 27/27 |
| Integrationstest des Server-Ablaufs mit Fake-Engine (echte Server-Module) | 20/20 Szenarien |

**Nicht** geprüft (braucht Studio): Physik, Replikation, Kamera, HUD-Layout, Touch/Gamepad,
Input-Action-System-Verhalten, Optik der Posen und Effekte, Sounds, Performance auf Mobilgeräten.
Details: `docs/TESTPLAN_Studio.md`.

## Rückbau

`studio-tools/05_Rueckbau.luau`: `MODE = "disable"` (abschalten), `"remove"` (nach
`ServerStorage.NEON_KO_Removed_<Datum>` verschieben, Tag entfernen), `RESTORE_OLD_LOGIC = true`
(alte Boxlogik exakt wieder aktivieren). Notfall: gesicherte `.rbxl` öffnen.
