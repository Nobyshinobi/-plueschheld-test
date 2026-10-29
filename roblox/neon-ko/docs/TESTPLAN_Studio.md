# Phase F – Testplan für Roblox Studio

Legende: ✅ automatisiert geprüft (ohne Studio) · ⬜ **noch nicht getestet** (braucht Studio/Gerät)

Automatisiert heißt: `tests/run.luau` (Unit-Tests, Balancing-Simulation) und
`tests/integration.luau` (echte Server-Module in einer Fake-Engine: Instanzen, Signale, Zeit,
vereinfachte Bewegung/Overlap). Diese Tests decken **Logik und Abläufe** ab, nicht Roblox-Physik,
Replikation, Rendering oder den Client-Code.

## Vorbereitung

- Output-Fenster offen, Filter auf Errors/Warnings.
- Für Tests: `Config.Debug.UnlockAllInStudio = true` (alle Gegner), `Config.Debug.ShowHitboxes = true`
  (rote/blaue Hitbox-Würfel), danach wieder auf `false`.
- Mehrspieler: `Test › Clients and Servers`, 2 Spieler. Touch: `Test › Device` (Emulation).

## Ablauf & Ende

| Test | Automatisiert | Studio |
|---|---|---|
| FIGHT-Prompt erscheint am Ring, „Arena besetzt“ wenn belegt | ✅ (Server) | ⬜ |
| Gegnerauswahl öffnet sich, gesperrte Gegner nicht wählbar | ✅ (Server) | ⬜ (UI) |
| Intro ≤ 3 s, überspringbar | ✅ (Server) | ⬜ (Kamera) |
| Countdown 3-2-1-FIGHT, Spieler bis dahin eingefroren | ✅ | ⬜ (Anzeige) |
| Kampf endet nach max. 60 s | ✅ | ⬜ |
| K.O. → VICTORY/DEFEAT, Zeitablauf → Entscheidung nach HP %, DRAW bei Gleichstand | ✅ | ⬜ |
| Ergebnis → Rückkehr an den Ausgangspunkt, Steuerung/Kamera wie vorher | ✅ (Server-Werte) | ⬜ (Kamera, Client) |
| Freischaltung Gegner 2 nach Sieg über Gegner 1 (nur Sitzung) | ✅ | ⬜ |
| Kein echter Schaden am Humanoid | ✅ | ⬜ |

## Abbruch, Disconnect, Respawn, Fehler

| Test | Automatisiert | Studio |
|---|---|---|
| VERLASSEN in Auswahl / Intro / Countdown / Kampf / Ergebnis | ✅ (Intro, Kampf) | ⬜ alle Phasen inkl. Button |
| Tod im Kampf (z. B. Reset-Charakter) | ✅ | ⬜ |
| Respawn im Countdown | ✅ | ⬜ |
| Disconnect des Kämpfers | ✅ | ⬜ (echter Leave) |
| Auswahl-Zeitlimit | ✅ | ⬜ |
| Server-Shutdown (BindToClose) | ✅ | ⬜ |
| Client-Fehler → lokaler Wachhund stellt alles wieder her | – | ⬜ |
| Wiedereintritt direkt nach Kampfende | ✅ (mehrfach nacheinander) | ⬜ |

## Mehrspieler

| Test | Automatisiert | Studio |
|---|---|---|
| Zweiter Spieler: „Arena besetzt“, Warteschlange, Einladung nach Kampfende | ✅ | ⬜ |
| Zuschauer im Ring wird hinausgesetzt, Hinweis erscheint | ✅ | ⬜ |
| Fremder Spieler kann Kampf nicht beeinflussen (SkipIntro/Leave/Action) | ✅ | ⬜ |
| Zuschauertafel zeigt Namen, HP, Zeit; HUD nur beim Kämpfer | – | ⬜ |
| Effekte/Animationen für Zuschauer sichtbar und synchron | – | ⬜ |

## Kampf

| Test | Automatisiert | Studio |
|---|---|---|
| Light/Heavy/Block/Dodge/Special-Regeln, Cooldowns, Energie | ✅ | ⬜ (Gefühl/Timing) |
| Hit-Cancel-Kombos L-L-H, L-L-L, H-Special | ✅ | ⬜ |
| Guard Break, Perfect Dodge, Combo Break nach 5 Treffern | ✅ | ⬜ |
| Hitbox trifft nur den eigenen Gegner, ein Treffer pro Angriff | ✅ | ⬜ (mit ShowHitboxes) |
| NPC-KI: alle 4 Gegner kämpfen, Telegraph vor Heavy/Special sichtbar | ✅ (Logik) | ⬜ (Optik) |
| Schwierigkeit steigt von Gegner 1 → 4 | ✅ (Simulation, Tendenz) | ⬜ (echte Spieler) |
| Spieler bleibt in der Kampfzone, Gegner dreht sich immer zum Spieler | ✅ (Server) | ⬜ |

## Missbrauch / Spam

| Test | Automatisiert | Studio |
|---|---|---|
| Falsche Typen, NaN/Inf, unbekannte Aktionen, Tabellen als Argument | ✅ | – |
| 600 Anfragen pro Tick → gedrosselt, kein Absturz | ✅ | ⬜ (Executor-Test nicht nötig) |
| Teleport aus der Kampfzone → Rücksetzung + Treffer-Sperre | ✅ | ⬜ |
| Prompt aus großer Entfernung ignoriert | ✅ | – |
| Gesperrten Gegner per Remote anfordern | ✅ | – |

## Geräte & Eingaben

| Test | Studio |
|---|---|
| PC: Linksklick/Rechtsklick/E/F/Q/R, WASD relativ zur Kampfkamera, kein Konflikt mit Kamera | ⬜ |
| PC: Shift-Lock während des Kampfs aus, danach wieder verfügbar | ⬜ |
| Touch: 5 große Buttons, Stick links nutzbar, BLOCK beim Abrutschen gelöst | ⬜ |
| Echtes iPhone/iPad (Lesbarkeit, Safe Area, Notch) | ⬜ |
| Gamepad: X/Y/LT/B/RT, A überspringt Intro, ↓ halten verlässt, Auswahlmenü per Gamepad | ⬜ |
| Input Action System aktiv (Output: kein „nutze ContextActionService“) | ⬜ |
| Fallback ContextActionService (`Config.Input.PreferInputActionSystem = false`) | ⬜ |
| Nach dem Kampf: Rucksack, Sprung, Shift-Lock, Prompts wie vorher | ⬜ |

## Optik, Animation, Performance

| Test | Studio |
|---|---|
| Boxstand sieht vor/nach Einbau identisch aus (Screenshots vergleichen) | ⬜ (automatisiert nur: Server verändert Boxstand nicht ✅) |
| Prozedurale Posen R15 (Guard, Jab, Cross, Uppercut, Block, Dodge, Treffer, K.O., Sieg) | ⬜ |
| R6-Avatar (falls im Spiel erlaubt) | ⬜ |
| Neon-Effekte gut sichtbar, nicht überstrahlt; FX Voll/Sanft/Aus wirkt | ⬜ |
| Sounds laden ohne Warnung | ⬜ |
| Schwächere Hardware / Mobilgerät: Bildrate im Kampf | ⬜ |
| Studio-Output ohne neue Errors/Warnings | ⬜ |

Bitte Ergebnisse (inkl. Output-Meldungen) zurückmelden – Fehler korrigiere ich gezielt.
