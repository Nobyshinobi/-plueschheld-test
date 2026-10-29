# Phase A – Analyse, Sicherung, Risiken

## Was ich im realen Projekt gefunden habe

**Nichts – weil kein Zugriff bestand.** In dieser Sitzung war Roblox Studio nicht verbunden (kein
Studio-MCP-Werkzeug verfügbar). Ich kenne deshalb weder die Namen noch die Hierarchie deines
Boxstands, noch die alten Box-Skripte. Ich behaupte keine gefundenen Pfade.

Stattdessen gibt es `studio-tools/01_Inventar_Analyse.luau`. Das Werkzeug liest in Studio aus
(ohne etwas zu verändern):

- Kandidaten für Boxstand/Ring (Namenssuche nach box/boxing/ring/punch/fight/kampf/arena … oder die
  aktuelle Explorer-Auswahl) mit Pfad, Bounding Box, Anzahl Parts/MeshParts/Neon-Teile, Lichtern,
  Sounds, Sitzen, Tags
- darin enthaltene Skripte (aktiv/deaktiviert), ProximityPrompts, ClickDetectors, Animationen,
  Surface-/BillboardGuis, Remotes
- mögliche Ringböden (große flache Teile)
- alle Skripte im Spiel mit Box-Bezug im Namen oder Quelltext (mit Zeilenauszügen)
- Remotes/Bindables mit Box-Bezug
- Projekteinstellungen, die das Minispiel betreffen: StreamingEnabled,
  PlayerScriptsUseInputActionSystem, AuthorityMode, SignalBehavior, Avatar-Typ (R15/R6),
  WalkSpeed/JumpPower-Modus, Shift-Lock-Option
- ob NEON K.O. bereits installiert ist

Bitte den Ausgabeblock zurückschicken. Danach liefere ich: konkrete Explorer-Pfade, die genaue
Liste der alten Box-Skripte zum Deaktivieren, ggf. angepasste Marker/Einstellungen.

## Sicherung (vor jeder Änderung)

1. **Ganzer Place:** `File › Save to File As…` → `Park_vor_NEON_KO.rbxl` (lokale Kopie).
   Nur wenn diese Datei existiert, weitermachen.
2. **Alte Boxlogik separat:** Werkzeug 02 mit `MODE = "backup"` kopiert die markierten
   Instanzen nach `ServerStorage.NEON_KO_Backup_<Datum>` (Kopien deaktiviert, Originalpfad als
   Attribut, Manifest als StringValue). Originale bleiben unverändert.
3. **Deaktivieren erst später** (Werkzeug 02, `MODE = "disable"`): nur Instanzen mit
   nachgewiesener Sicherung; es wird nichts gelöscht; Rückweg per Strg+Z oder Werkzeug 05.

## Geplante Änderungen (konkret)

| Ort | Änderung | Optik betroffen? |
|---|---|---|
| `ReplicatedStorage` | neuer Ordner `ArcadeBoxing` (Module) | nein |
| `ServerScriptService` | neuer Ordner `ArcadeBoxing` (Main + Module) | nein |
| `StarterPlayer.StarterPlayerScripts` | neues LocalScript `ArcadeBoxingClient` | nein |
| Ringboden des Boxstands | CollectionService-Tag `ArcadeBoxingFloor` | nein |
| neben dem Ringboden (optional) | Ordner `ArcadeBoxingAnchors` mit unsichtbaren, nicht kollidierenden Markern | nein |
| alte Box-Skripte/Prompts/GUIs | `Enabled = false` (nach Sicherung, nur eindeutig zugehörige) | nein |
| `Workspace` (zur Laufzeit) | `ArcadeBoxingRuntime` (Prompt-Anker, Zuschauertafel, NPC während des Kampfs) | nur unsichtbare Anker + NPC im Kampf |

Andere Attraktionen, Musik, Shop, Spawn, Kamera außerhalb des Kampfs und Weltskripte werden
nicht angefasst. Alles läuft im selben Place, keine Teleports.

## Risikoliste

| # | Risiko | Wirkung | Gegenmaßnahme im Paket | Offen |
|---|---|---|---|---|
| 1 | Ringboden ist Union/Mesh, gedreht, rund oder mehrteilig | falsche Kampfzone/Startpunkte | Achsenerkennung, Rund-Ring-Sonderfall, Größenprüfung in Werkzeug 03, verschiebbare Marker | reale Form unbekannt |
| 2 | Alte Boxlogik läuft parallel | zwei FIGHT-Prompts, doppelte Steuerung | Inventur (01), Sicherung + gezieltes Deaktivieren (02) | Liste der alten Skripte |
| 3 | Andere Parksysteme setzen WalkSpeed, Kamera, CoreGui (Sprint, Kamera-Skripte, Inventar) | Konflikte im Kampf; nach dem Kampf werden die Werte von *vor* dem Kampf gesetzt | nur während des Kampfs, sauber gesichert/wiederhergestellt | in Studio prüfen |
| 4 | StreamingEnabled | NPC/Prompt noch nicht geladen | NPC als Atomic-Model, Client wartet bis 5 s, Prompt-Anker im Ring | testen |
| 5 | Server-Authority (`Workspace.AuthorityMode`) aktiv | Ausweichschritt/Rückstoß des eigenen Charakters (Client-Impuls) verhält sich anders | – | prüfen, ggf. Server-Variante |
| 6 | R6-Avatare oder stark skalierte Avatare | vereinfachte Posen; Handschuhe sitzen anders | R6-Fallback (Ellbogen/Taille gefaltet), Größe aus Teilmaßen | Optik testen |
| 7 | E-Taste anderer Prompts in Ringnähe | harter Schlag löst Shop/Prompt aus | `HidePromptsDuringFight` (lokal, nur im Kampf) | testen |
| 8 | Park-Tasten auf F/Q/R/E | Doppelbelegung im Kampf | `SinkDuringFight` optional (Standard aus) | testen |
| 9 | Input Action System im Projekt nicht verfügbar | keine Kampfeingaben | automatischer Fallback auf ContextActionService | beide Pfade testen |
| 10 | `rbxasset://`-Sounds fehlen im Client | Output-Warnung „Failed to load sound“ | zentral abschaltbar / eigene lizenzierte IDs | prüfen |
| 11 | Mobile Performance | Ruckler | wenige Partikel, kurze Highlights, kein Post-Processing, alles mit Debris | Gerätetest |
| 12 | Animationen ohne Asset-IDs | Posen statt Editor-Animationen | prozedurale Posen sofort lauffähig; Export (04) zum Selbst-Veröffentlichen | Optik beurteilen |
| 13 | Exploits (Client besitzt die eigene Charakter-Physik) | Teleport/Speedhack | Zonen-/Geschwindigkeits-/Distanz-/Blickprüfung, Treffer-Sperre, Rate-Limit | kein vollständiges Anti-Cheat |
| 14 | Mehrere Ringe im Park | – | jeder getaggte Ringboden wird eine eigene Arena mit eigenem Zustand | – |
