# PlüschHeld – personalisierte Kinderbücher

Cinematic-Scroll-Homepage mit Konfigurator: Ein echtes Kind mit seinem Kuscheltier → die Kamera fährt langsam ins Auge
→ aus dem gemalten Auge heraus entsteht die Kinderbuch-Illustration → sie wird zum Buchcover → das Buch öffnet sich und
blättert → „Jetzt beginnt eure Geschichte“ mit Upload von Kind- und Kuscheltierfoto, Name, Alter, Interessen und Idee.

```bash
npm install
npm run dev            # http://localhost:3000
npm run build && npm start
npm run lint && npm run typecheck
```

Weitere Dokumente: [Analyse & Konzept](docs/ANALYSE-UND-KONZEPT.md) · [QA-Protokoll](docs/QA-PROTOKOLL.md) ·
[Fehlerprotokoll/Learnings](docs/LEARNINGS.md) · [Bible v1.1 – Nachtrag](docs/Scroll-Experience-Bible-v1.1-Nachtrag.md)

---

## Tech-Stack

| Bereich | Wahl | Warum |
|---|---|---|
| Framework | **Next.js 16.3** (App Router, Turbopack), **React 19.3**, **TypeScript 5.9** | stabile Produktionsbasis, statisches Prerendering, API-Route |
| Styling | **Tailwind CSS 4.3** + Design-Tokens (`@theme` in `src/app/globals.css`), CSS-Module für das 3D-Buch | Tokens zentral, keine Zufallswerte |
| Scroll/Motion | **eigene zentrale Scroll-Engine** (1 passiver Listener, 1 rAF-Loop) + `position: sticky` | einfachste saubere Lösung; kein Pin-Spacer, stabil auf iOS |
| Hero | **Canvas 2D + Bildsequenz** (113 Frames/Gerätetyp, WebP) mit virtueller Kamera | framegenau, reversibel, kein Video-Seeking |
| Buch | **CSS 3D** (`preserve-3d`, `rotateY`), dynamische Schatten | GPU, leicht, kein WebGL nötig |
| Formular | **react-hook-form** + **zod/mini** (Schemas geteilt mit der API) | saubere Validierung, kleines Bundle |
| HEIC | **heic-to** (libheif 1.22), nur bei Bedarf dynamisch geladen | Chrome/Firefox können HEIC nicht nativ |
| Fonts | **Fraunces** (Soft, Display) + **Figtree** (UI), selbst gehostet | 2 Familien, keine Drittanbieter-Anfragen |
| Assets | Python-Pipeline (OpenCV, Pillow, pymupdf), Playwright-Renderer | reproduzierbar aus den Originaldateien |

Bewusst **nicht** verwendet: GSAP/ScrollTrigger, Lenis, Three.js – die Anforderungen ließen sich mit weniger Code,
weniger JS und ohne konkurrierende Scroll-Engines umsetzen (Begründung in `docs/ANALYSE-UND-KONZEPT.md`).

## Struktur

```
src/
  app/                    layout (Fonts, Metadata), page, datenschutz/, api/orders/ (Entwurf validieren)
  animations/
    scrollTimeline.ts     zentrale Scroll-Engine (Fortschritt 0..1, gedämpfte Kopplung, Snap bei Sprüngen)
    storyTimeline.ts      Choreografie als reine Funktion sampleStory(p) → Zustand
    easing.ts             Easing-Kurven (cinema, easeInOutCubic, smoothstep …)
    motionTokens.ts       Zeitkonstanten, Breakpoint für Doppelseiten
  components/
    StoryStage/           gepinnte Bühne: Canvas, Poster (LCP), Texte, Buch, Steuerung; StoryStatic = Reduced Motion
    HeroScene/            heroCamera.ts (virtuelle Kamera), heroRenderer.ts (Canvas), frameStore.ts (Laden/Dekodieren)
    BookPreview/          BookFlip (3D-Buch), bookGeometry (geteilt mit Canvas-Morph), BookControls
    Configurator/         Stepper, Review, Erfolg, HowItWorks, Live-Cover-Vorschau
    ImageUpload/  InterestSelector/  StoryInput/  Navigation/  Footer/
  content/                copy.ts (alle Texte), book.ts (Buchseiten + Alt-Texte), interests.ts
  lib/                    image.ts (HEIC, EXIF-Entfernung), validation.ts, order.ts, draftStorage.ts, navTheme.ts
scripts/
  pipeline/               build_hero_sequence.py, build_static_images.py, render-book-pages.mjs, import_book_pdf.py
  qa/                     shoot, interactions, configurator, perf, fontshift, handoff, flipframes, sheet.py
assets-src/               unveränderte Quellen (Transformationsvideo, Illustrations-Loop, Logo)
public/media/             generierte Derivate (Sequenz p/f/l + manifest.json, Buchseiten, Cover)
```

## Scrollsystem

- **Eine** gepinnte Story (`.story-track` mit `position: sticky`-Bühne). Länge: 12,2 Bildschirmhöhen (Doppelseiten)
  bzw. 13,7 (Einzelseiten, Mobile). Höhen in `svh`/`lvh` → keine Sprünge durch die iOS-Adressleiste.
- `scrollTimeline` misst Track-Position gecacht (Resize/Orientation/Fonts/ResizeObserver) und liefert `p ∈ [0,1]`,
  exponentiell gedämpft (τ 0,14 s Desktop / 0,085 s Touch). Sprünge > 12 % (Reload, Anker) werden direkt gesetzt.
- `sampleStory(story, p)` berechnet deterministisch den gesamten Szenenzustand. Updates gehen direkt an Canvas/DOM –
  **keine React-Renders pro Frame** (React-State nur bei Seitenwechsel für ARIA-Anzeige).
- Buch-Buttons, Pfeiltasten, Swipe und Tippen **scrollen** zur Zielseite: Scroll bleibt die einzige Quelle der Wahrheit,
  Vor/Zurück ist immer konsistent.

| Segment | Anteil (Desktop) | Inhalt |
|---|---|---|
| establish | 0–2,9 % | Ganzaufnahme, 2 % Kamera-Push, Headline |
| zoomIn | 2,9–25,8 % | Log-Zoom ins Auge (≈ 59×), Text weg, Vignette |
| swap | 25,8–30,3 % | Iris füllt Bild, Real → Aquarell (Crossfade im Material), Lichtimpuls |
| zoomOut | 30,3–47,5 % | aus dem gemalten Auge heraus (≈ 30×) |
| illusHold | 47,5–53,3 % | „Und plötzlich beginnt eure Geschichte.“ |
| morph | 53,3–61,5 % | Illustration schrumpft zur Buchcover-Karte; Buchkörper blendet ein; „Dein Kind. / Kuscheltier. / Idee.“ |
| coverHold | 61,5–65,6 % | Übergabe Canvas → DOM-Cover, Goldtitel, 3D-Neigung, „Unsere Geschichte.“ |
| open | 65,6–72,1 % | Deckel öffnet, „Ein Buch, das es nur einmal gibt.“ |
| flip1–2 | 72,1–88,5 % | je Haltephase + Umblättern |
| finalHold / exit | 88,5–100 % | Buch weicht zurück, Konfigurator gleitet darüber |

## Hero: virtuelle Kamera

Das gelieferte Transformationsvideo (1248×1664, 24 fps) wird **nicht** als Video gescrubbt. Die Pipeline registriert
alle Frames (ORB+ECC, affin), verkettet sie in zwei Weltkoordinatensysteme, trackt die Pupille (Anchor Point) und
exportiert drei Zuschnitte: **p** Portrait 9:16 (Phones), **f** 3:4 (Tablets), **l** 1,43:1 (Desktop).
Zur Laufzeit ist der Zoom eine Funktion des *Log-Zoomlevels* (gleichmäßig wahrgenommen, eigene Easing-Kurve); der
nächstliegende geladene Frame wird exakt auf die Kamera gewarpt → stufenloser Zoom, das Auge bleibt verankert,
fehlende Frames werden durch Nachbarn ersetzt (keine Leerframes). Aktivierbares QA-Overlay: `/?debug-eye`.

Assets neu erzeugen: `pip install -r scripts/pipeline/requirements.txt && npm run assets:hero && npm run assets:images && npm run assets:book`

## Assets

| Datei | Größe | Laden |
|---|---|---|
| Poster = Frame 1 (je Set, WebP) | 40–70 kB | sofort, `fetchpriority=high` (LCP) |
| Sequenz p / f / l | 3,7 / 4,8 / 4,0 MB (113 Frames) | nach `load`+Idle bzw. erstem Scroll, grob→fein, nur ein Set |
| Kamera-Manifest | 31 kB JSON | per `fetch` |
| Cover-Motiv | 70–140 kB (WebP/AVIF) | ab Mitte der Transformation |
| Buchseiten p0–p5 | 20–175 kB je Seite (720/1080 px) | ab 20 % Story-Fortschritt |
| Initial-JS | ~232 kB gzip (davon ~180 kB Next/React) | HEIC-Konverter (~0,7 MB gzip) nur bei Bedarf |

Dekodiert wird nur ein Fenster um die Kamera (`ImageBitmap`-LRU, 18 Mobile / 32 Desktop) → kein Speicherproblem auf iOS.

## Konfigurator & Daten

Schritte: Foto Kind → Foto Kuscheltier (+ optional Name) → Name, Alter, Ansprache → Interessen (Mehrfachauswahl +
eigene Idee) → Story-Idee (mit personalisierten Inspirationen) → Zusammenfassung + Einwilligung → **„Mein Kinderbuch starten“**.

- Fotos: JPG/PNG/HEIC/WebP bis 25 MB, Drag & Drop, Vorschau, Ersetzen, Entfernen, Statusanzeige, verständliche Fehler.
  Neu-Kodierung im Browser entfernt EXIF/GPS, lange Kante max. 2400 px.
- Zwischenspeichern **nur lokal**: Texte in `localStorage`, Fotos in IndexedDB; Verfall nach 14 Tagen; nach Absenden gelöscht.
- `POST /api/orders` validiert einen versionierten **Bestell-Entwurf** (nur Metadaten, keine Fotos) mit demselben Schema.
  Das Schema enthält bereits `extras.people` (Geschwister, Eltern, Großeltern, Haustier), Lieblingsort, Anlass, Widmung,
  Ausschlüsse sowie `product` (SKU/Menge) für Warenkorb/Checkout.

## Bekannte Einschränkungen

1. **Kinderbuch-PDF fehlte in den Anhängen** (beigefügt war nur das Produktionshandbuch). Die Buchvorschau nutzt
   Interim-Seiten aus echtem Material von „Emma und die leuchtende Schaukel“ (Illustrationen aus dem Video, Titel und
   Rückseitenzitat vom echten Cover; Fließtext als Platzhaltertext gekennzeichnet in `src/content/book.ts`).
   Austausch ohne Code-Änderung: `npm run book:import-pdf -- buch.pdf --pages 2,3,8,9,14,15` (oder `--spreads … --split`).
2. **Kein echter iOS-Safari-Test** in dieser Umgebung möglich (nur Chromium). iPhone-Viewports wurden mit Touch-Emulation
   geprüft; vor dem Livegang auf echten Geräten (iOS 17+) testen.
3. Frame-Zeiten wurden headless **ohne GPU** gemessen (CPU-Rastern). Eigene Script-Zeit: 0,4–0,6 ms/Frame.
4. Keine Speicherung, kein Checkout, kein Konto – bewusst (Scope). Impressum und rechtlich geprüfte Datenschutzerklärung fehlen noch.
5. Quellvideo ist 1248 px breit → auf 1920-px-Displays leicht weich (1,5× Hochskalierung).
6. Logo: Der Schriftzug liest sich wie „Plüschfeld“/„Plüschteld“ – bitte prüfen, ob das „H“ von *Held* so gewollt ist.

## Erweiterungen (vorbereitet)

- **Uploads**: `lib/order.ts` beschreibt den Produktionsfluss – Entwurf anlegen → signierte, zeitlich begrenzte Upload-URLs
  (privater, verschlüsselter Bucket) → Checkout.
- **Stripe/Warenkorb**: `product` im Entwurf; Checkout-Session mit `draftId` als Metadaten; Webhook → Auftrag.
- **Weitere Personen/Orte/Anlässe**: Felder in `orderDraftSchema.extras`, UI-Schritt ergänzen (Stepper ist datengetrieben: `STEPS`).
- **Kundenkonto/Admin**: Entwürfe serverseitig persistieren; Lösch- und Korrekturprozess (Datenschutz) mitdenken.
- **Echte Buchseiten/weitere Bücher**: `book:import-pdf`, Manifest `src/content/book.ts`.
- **Texte**: alle in `src/content/copy.ts`.
