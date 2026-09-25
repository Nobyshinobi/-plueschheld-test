# Fehlerprotokoll & Learnings (PlüschHeld, Build 1)

Jeder Eintrag wurde reproduziert, die Ursache isoliert, minimal behoben und per Regressionstest abgesichert.
Die Spalte „Neue Regel“ ist für die nächste Version der *Scroll Experience Engineering Bible* gedacht
(siehe `docs/Scroll-Experience-Bible-v1.1-Nachtrag.md`).

---

## L1 · KI-Video hat ungleichmäßige Kamerafahrt – Zoom wirkt ruckelig, Auge driftet

| | |
|---|---|
| **Problem** | Das Transformationsvideo sollte scrollgesteuert „langsam und kontrolliert“ ins Auge zoomen. |
| **Symptom** | 1:1-Mapping Scroll → Videoframe: Zoomgeschwindigkeit schwankt (0,5 %–6,7 % pro Frame), abruptes Abbremsen bei Frame ~180, Fixpunkt des Zooms wandert. |
| **Ursache** | Generierte Videos haben keine konstante virtuelle Kamera. Die „Kamera“ steckt im Material, nicht im Code. |
| **Fix** | Frames registriert (ORB + ECC, Auswahl per NCC), Transformationen zu zwei Welten verkettet, Pupille getrackt. Scroll steuert jetzt den **Log-Zoom** (wahrgenommen gleichmäßig) mit eigener Easing-Kurve; Frame-Index wird daraus invertiert; zwischen Frames wird stufenlos gewarpt. |
| **Regressionstest** | `node scripts/qa/shoot.mjs --debug-eye …` zeichnet das getrackte Auge als Fadenkreuz; es muss in jedem Screenshot in der Pupille liegen. |
| **Neue Regel** | *Nie ein generiertes Video 1:1 auf Scroll mappen. Erst Kamerapfad messen (Registrierung), dann Scroll → Zoomlevel → Frame. Die Kamera gehört in den Code.* |

## L2 · Affine → Ähnlichkeit projiziert verschlechtert Registrierung

| | |
|---|---|
| **Symptom** | Nach „Vereinfachung“ auf reine Ähnlichkeitstransformation fiel die NCC an Frame 180 von 0,92 auf 0,82; Augenpfad ungenauer. |
| **Ursache** | Das generierte Video enthält leichte Perspektive/Parallaxe; Ähnlichkeit (4 DoF) kann das nicht abbilden. |
| **Fix** | Volle Affine (6 DoF) speichern; Canvas `setTransform` kann jede Affine direkt. |
| **Regressionstest** | Pipeline gibt NCC je 20 Frames aus; Augen-Overlay (L1). |
| **Neue Regel** | *Registrierung mit dem allgemeinsten Modell, das der Renderer kostenlos kann (Canvas: affin).* |

## L3 · `imageSmoothingQuality = "high"` kostet 3× ohne sichtbaren Gewinn

| | |
|---|---|
| **Symptom** | Desktop-Scroll durch den Hero: Ø 26 ms/Frame, p95 50 ms (Headless). |
| **Ursache** | Bikubische Glättung beim *Hochskalieren* großer Canvas ist teuer; Unterschied zu „medium“ visuell nicht erkennbar (A/B-Screenshot). |
| **Fix** | „medium“ + Canvas-Backing-Store auf 2,4 MP begrenzt (Quelle ist nur 1248 px breit). |
| **Regressionstest** | `node scripts/qa/perf.mjs` (Task-Zeit 3,1 s → 1,7 s; Mobile konstant 16,7 ms/Frame). |
| **Neue Regel** | *Canvas-Auflösung an der Quellauflösung deckeln, nicht an devicePixelRatio. Glättungsqualität per A/B-Screenshot entscheiden.* |

## L4 · Mehrfaches Neuzeichnen pro Frame durch Decode-Callbacks

| | |
|---|---|
| **Symptom** | Long-Frames bei schnellem Scrollen, obwohl eigenes Script < 1 ms. |
| **Ursache** | Jeder fertig dekodierte Frame (`createImageBitmap`) löste sofort ein Canvas-Zeichnen aus – mehrere pro Frame, teils mit schlechteren Frames als dem gezeigten. |
| **Fix** | Redraws per `requestAnimationFrame` bündeln und nur, wenn der neue Frame näher an der Kamera liegt. |
| **Regressionstest** | `interactions.mjs` (Script-Zeit/Frame < 2 ms, gemessen 0,4–0,6 ms). |
| **Neue Regel** | *Asynchrone Ressourcen melden „dirty“, gezeichnet wird ausschließlich im rAF.* |

## L5 · Framesequenz konkurriert mit LCP

| | |
|---|---|
| **Symptom** | Lighthouse: 4,2 MB Transfer, LCP verzögert. |
| **Ursache** | FrameStore startete 113 Downloads sofort nach Hydration. |
| **Fix** | Laden erst nach `load` + `requestIdleCallback` – oder sofort beim ersten Scroll/bei Reload mitten in der Seite. Manifest per `fetch` statt im JS-Bundle. |
| **Regressionstest** | Lighthouse (DevTools-Throttling): LCP 1,0 s. `interactions.mjs` (Reload mitten in der Szene). |
| **Neue Regel** | *Nichts, was erst beim Scrollen gebraucht wird, darf vor dem LCP ins Netz.* |

## L6 · Layout-Shift beim Font-Swap trotz `adjustFontFallback`

| | |
|---|---|
| **Symptom** | CLS 0,013 unter echter Drosselung; Hero-H1 mit Fallback 4 Zeilen, mit Webfont 3. |
| **Ursache** | (a) `next/font` berechnet `size-adjust` für die variable Fraunces am Default-Instance-Schnitt (126,7 % statt korrekt 117,2 % bei wght 500) und nur für `local("Times New Roman")` – auf Android/Linux fehlt der Font. (b) **`max-width: 14ch`**: `ch` = Breite der „0“ im *aktuellen* Font → Fallback 309 px, Webfont 349 px. |
| **Fix** | Eigene, gemessene Fallback-Faces (Times/Liberation/Tinos, Noto Serif, DejaVu) mit fontTools an deutschem Beispieltext; Headline-Breiten in `em` statt `ch`. |
| **Regressionstest** | `node scripts/qa/fontshift.mjs` – Fallback- und Webfont-Layout müssen identisch sein (390, 430, 1440 px). |
| **Neue Regel** | *Keine `ch`-Einheiten für Breiten von Webfont-Text. Fallback-Metriken pro Zielplattform messen (Gewicht & Achsen berücksichtigen).* |

## L7 · Headlines unbemerkt in Gewicht 400

| | |
|---|---|
| **Symptom** | Überschriften wirkten dünner als geplant (540). |
| **Ursache** | `:where(h1,…)` hat Spezifität 0; Tailwind-Preflight `h1 { font-weight: inherit }` gewinnt im selben Layer. |
| **Fix** | Selektor ohne `:where()` nach dem Preflight. |
| **Regressionstest** | `fontshift.mjs` gibt das berechnete Gewicht aus (500). |
| **Neue Regel** | *Basis-Typo nie mit `:where()` gegen einen Reset definieren; berechnete Werte (`getComputedStyle`) in der QA prüfen, nicht nur Screenshots.* |

## L8 · Ungelayertes CSS schlägt Tailwind-Utilities

| | |
|---|---|
| **Symptom** | Burger-Menü auf Desktop sichtbar trotz `md:hidden`. |
| **Ursache** | Eigene Klassen außerhalb von `@layer` stehen in Tailwind v4 über allen Layern. |
| **Fix** | Komponenten-CSS in `@layer components`; in separat importierten CSS-Dateien zusätzlich die Layer-Reihenfolge deklarieren. |
| **Regressionstest** | Desktop-Screenshots (1366/1440/1920). |
| **Neue Regel** | *Tailwind v4: jedes eigene CSS in einen Layer.* |

## L9 · Poster verdeckt das Buch bei direktem Sprung

| | |
|---|---|
| **Symptom** | „Beispiel ansehen“ direkt nach dem Laden bzw. Reload im Buchbereich: Hero-Foto liegt über dem Buch. Direkt im Morph: Canvas-Karte unsichtbar. |
| **Ursache** | Poster wurde nur nach dem ersten *Kamera*-Frame ausgeblendet; im Buch-/Morph-Bereich wird nie ein Kamera-Frame gezeichnet. Canvas-Opacity hing am selben Ereignis. |
| **Fix** | Poster-Sichtbarkeit aus dem Story-Zustand ableiten (`!canvasReady && morph == 0`); „erstes Zeichnen“ auch beim Morph melden. |
| **Regressionstest** | `interactions.mjs` → „Direkter Sprung ins Buch/Morph, bevor die Sequenz geladen ist“ (Sequenz künstlich verzögert). |
| **Neue Regel** | *Jede Ebene der Bühne muss ihre Sichtbarkeit aus dem Timeline-Zustand ableiten können – nie nur aus einem einmaligen Ereignis. Testfall „Sprung an jede Anker-Position vor dem Asset-Load“ ist Pflicht.* |

## L10 · Negative Überlappung zerstört Reduced-Motion-Layout

| | |
|---|---|
| **Symptom** | Reduced Motion: Buch fehlt – Konfigurator liegt darüber. |
| **Ursache** | `margin-top: -0.9 × 100svh` (Überlappung mit gepinnter Bühne) galt auch ohne Pinning. |
| **Fix** | Überlappung als CSS-Variable, in `prefers-reduced-motion` auf 0. |
| **Regressionstest** | `shoot.mjs --reduced` (390 + 1440). |
| **Neue Regel** | *Jede Layout-Kopplung an die Scroll-Choreografie braucht einen expliziten Reduced-Motion-Wert.* |

## L11 · Unsichtbares, per JS positioniertes Element zählt als CLS

| | |
|---|---|
| **Symptom** | CLS 0,02 durch `.proof-wrap` (opacity 0). |
| **Ursache** | `bottom` wurde nach Hydration gesetzt; opacity-0-Elemente zählen für CLS. |
| **Fix** | `visibility: hidden`, bis positioniert und gebraucht. |
| **Regressionstest** | Lighthouse `layout-shifts` = 0. |
| **Neue Regel** | *JS-positionierte Overlays starten mit `visibility: hidden`, nicht mit `opacity: 0`.* |

## L12 · Kontrast gegen den falschen Hintergrund berechnet

| | |
|---|---|
| **Symptom** | Lighthouse (Datenschutzseite): Gold-Eyebrow 4,43:1 < 4,5:1. |
| **Ursache** | Token `--color-gold-text` wurde gegen Creme `#FFF8EE` (4,76:1) geprüft, steht aber meist auf Papier `#F8F0E3`. |
| **Fix** | `#7A5C24` (5,5:1 auf Papier, 6:1 auf Creme). |
| **Regressionstest** | Lighthouse Accessibility = 100 auf allen Seiten. |
| **Neue Regel** | *Kontrast-Tokens gegen **jeden** Hintergrund-Token prüfen, auf dem sie vorkommen – nicht nur gegen den hellsten.* |

## L13 · Skip-Link ohne Ziel auf Unterseiten

| | |
|---|---|
| **Symptom** | Lighthouse: „Skip links are not focusable“ auf `/datenschutz`. |
| **Ursache** | Navigation hatte ein festes Sprungziel `#buch-erstellen` (existiert nur auf der Startseite). |
| **Fix** | Sprungziel als Prop (`skipTo`), Unterseiten springen zu `#inhalt`. |
| **Regressionstest** | `node scripts/qa/keyboard.mjs`, Lighthouse a11y. |
| **Neue Regel** | *Globale Komponenten dürfen keine seitenspezifischen Anker hart kodieren.* |

## L14 · Werkzeug-/Umgebungsfallen (für den Workflow)

- `page.setContent()` in Playwright lädt keine `file://`-Ressourcen (about:blank) → Templates als Datei schreiben und per `goto(file://…)` öffnen.
- `pkill -f "next start"` trifft die eigene Shell, wenn das Muster im Befehl steht → Prozesse per PID beenden.
- React-StrictMode (nur `next dev`) mountet Effekte doppelt → abgebrochene Fetches (`ERR_ABORTED`) im Dev-Log sind erwartbar; Messungen immer gegen `next build && next start`.
- Lighthouse „simulated throttling“ (Lantern) bewertet Next.js-Seiten mit ~180 kB Framework-JS pessimistisch (LCP 3,8 s simuliert vs. 1,0 s mit echter Drosselung). Immer beide Methoden messen.
- `eslint --fix` hinterlässt `{ }` in JSX, wenn es unbenutzte Disable-Kommentare entfernt → nach `--fix` nach `^\s*{ }\s*$` suchen.
