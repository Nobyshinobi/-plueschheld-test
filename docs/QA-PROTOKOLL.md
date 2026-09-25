# QA-Protokoll – Build 1

Getestet gegen den **Production-Build** (`next build && next start`), Chromium 141 headless (Playwright), ohne GPU.
Alle Tests sind als Skripte reproduzierbar (`scripts/qa/`), Screenshots entstehen in `qa-artifacts/` (nicht versioniert).

## Viewports

| Viewport | Gerätetyp | Sequenz-Set | Buchmodus | Ergebnis |
|---|---|---|---|---|
| 390 × 844 @3x | iPhone 12–15 | p (9:16) | Einzelseiten | ✓ Story, Buch, Konfigurator, Touch-Swipe/Tippen |
| 393 × 852 | iPhone 14/15 Pro | p | Einzelseiten | ✓ |
| 430 × 932 | iPhone Pro Max | p | Einzelseiten | ✓ |
| 844 × 390 | iPhone quer (Rotation) | l | Doppelseiten | ✓ Set-Wechsel p→l→p ohne Leerframe |
| 768 × 1024 | Tablet hoch | f (3:4) | Doppelseiten | ✓ |
| 1366 × 768 | Laptop | l | Doppelseiten | ✓ Buch + Steuerung passen in die Höhe |
| 1440 × 900 | Desktop | l | Doppelseiten | ✓ |
| 1920 × 1080 | Desktop FHD | l | Doppelseiten | ✓ (Quellmaterial 1,5× hochskaliert) |

Screenshot-QA je Viewport an p = 0 / 10 / 25 / 40 / 52 / 60 / 66 / 76 / 92 % + Konfigurator:
Zentrierung, Crop, Gesicht, Text, Übergänge, Buchposition und Formular geprüft.

## Automatisierte Tests (letzter Lauf: alle grün)

| Skript | Prüfungen | Ergebnis |
|---|---|---|
| `interactions.mjs` | Nav „Beispiel ansehen“, Buttons, Pfeiltasten ←/→, Klick/Tippen auf Buchhälften, Swipe (Touch), Fokus sichtbar, Reload mitten in der Szene, Mausrad hin & zurück, Sprung Ende→Anfang, Rotation hoch/quer, **direkter Sprung ins Buch/Morph vor dem Asset-Load**, Konsole | 22/22 ✓ |
| `configurator.mjs` (390 + 1440) | Pflichtfeld-Fehler, defekte Datei, **HEIC-Konvertierung**, **EXIF entfernt**, Fokus auf erstes Fehlerfeld, Input ≥ 16 px, Reload: Texte **und Foto** wiederhergestellt, Vor/Zurück behält Eingaben, Chips `aria-pressed`, personalisierte Inspiration, Einwilligung Pflicht, Absenden, Entwurf gelöscht, Konsole | je 18/18 ✓ |
| `keyboard.mjs` | Skip-Link, Nav per Tab, Buch-Buttons per Tab/Enter, aria-live-Seitenansage, Skip-Link → Konfigurator | 7/7 ✓ |
| `fontshift.mjs` | Layout mit Fallback-Font = Layout mit Webfont (390/430/1440) | identisch ✓ |
| `handoff.mjs` | Canvas-Karte → DOM-Cover: kein Versatz (nur Resampling-Kanten, Ø 4,8/255) | ✓ |
| `shoot.mjs --debug-eye` | getracktes Auge liegt in jedem Zustand in der Pupille | ✓ |
| `shoot.mjs --reduced` | Reduced Motion: Foto → Illustration → Buch (Buttons) → Konfigurator, kein Pinning | ✓ |
| `perf.mjs` | Script-Zeit pro Frame beim Scrollen | 0,4–0,6 ms ✓ |

Scroll-Szenarien: langsam (120 Schritte), schnell (Mausrad-Salven), Richtungswechsel, Sprung ans Ende und zurück,
Refresh mitten in der Szene, Resize/Orientation – keine Leerframes, kein weißes/schwarzes Aufblitzen, keine Konsolenfehler.

## Lighthouse (Production)

| Seite / Profil | Performance | Accessibility | Best Practices | SEO | LCP | CLS | TBT |
|---|---|---|---|---|---|---|---|
| Start · Mobile · **echte Drosselung** (4G, 4× CPU) | **99** | 100 | 100 | 100 | 0,9 s | 0 | 130 ms |
| Start · Mobile · simulierte Drosselung | 88 | 100 | 100 | 100 | 3,8 s* | 0 | 30 ms |
| Start · Desktop | **100** | 100 | 100 | 100 | 0,8 s | 0 | 0 ms |
| Datenschutz · Mobile | 96 | 100 | 100 | 100 | – | 0 | – |

\* Simulations-Artefakt: Lantern rechnet alle vor dem LCP angefragten JS-Chunks (≈ 180 kB gzip Next/React-Grundlast) in den
pessimistischen Graphen ein. Gemessenes LCP bei echter Drosselung: 0,9 s.

## Performance-Kennzahlen

- Initial-JS 232 kB gzip (vorher 316 kB): Zod → zod/mini, Manifest per fetch, CSS inline.
- LCP-Bild (Poster) 40–70 kB; Framesequenz (3,7–4,8 MB je Set) erst nach `load`/Idle oder erstem Scroll.
- Canvas: max. 2,4 MP Backing-Store, `imageSmoothingQuality: medium`, Redraws per rAF gebündelt.
- Mobile-Scroll durch den Hero (390 px, headless ohne GPU): Ø 16,7 ms/Frame, p95 16,7 ms (60 fps).
- Desktop 1440 px headless ohne GPU: Ø ~20 ms/Frame (CPU-Rastern; auf GPU-Geräten deutlich darunter).

## Verbleibende Risiken

1. **iOS Safari/WebKit nicht real getestet** (nur Chromium verfügbar). Zu prüfen: `lvh/svh`-Verhalten mit ein-/ausfahrender
   Leiste, `createImageBitmap`-Speicher auf älteren iPhones, `preserve-3d`-Sortierung beim Blättern, Foto-Auswahl/HEIC.
2. GPU-Performance nur indirekt belegt (eigene Script-Zeit < 1 ms/Frame; Rastern headless auf CPU).
3. Buchseiten sind Interim-Seiten (Kinderbuch-PDF fehlte) – Import-Skript vorhanden.
4. Kein Backend: API validiert nur; Speicherung, Upload, Zahlung, Impressum/Datenschutzerklärung fehlen bewusst.
5. Sehr alte Browser ohne `svh/lvh` fallen auf `vh` zurück (funktional, auf iOS < 15.4 ggf. kleine Sprünge durch die Adressleiste).
