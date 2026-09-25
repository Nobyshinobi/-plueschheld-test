# Analyse & Konzept (G0–G3)

## G0 – Inventar der Anhänge

| Datei | Inhalt | Verwendung |
|---|---|---|
| `PlueschHeld_Scroll_Experience_Produktionshandbuch_Claude.pdf` (32 S.) | Technisches/kreatives Regelwerk („Bible“) inkl. Screenshots des Referenz-Walkthroughs (Archer-Jet-Website) | verbindliche Spezifikation (Timeline, Farben, Asset-Regeln, DoD) |
| `…51a2cf….MP4` (10 s, 1248×1664, 24 fps) | **Transformationsvideo**: echtes Mädchen „Emma“ liest im Bett mit Faultier-Kuscheltier das Buch „Emma und die leuchtende Schaukel“ → Kamerafahrt ins Auge → reale Iris → Crossfade (Frames 124–128) → Aquarell-Iris → Zoom heraus → illustrierte Emma mit Faultier am Fenster, leuchtende Schaukel im Garten → ab Frame 218 Papierrand | Hero-Sequenz (Frames 1–216), Buchcover-Motiv, Buchillustrationen |
| `…51a2cf….mov` (9,7 s) | Variante desselben Motivs, schnellerer Swap (Frames 117–121), Iris füllt das Bild weniger | nicht verwendet (MP4 hat die bessere Verdeckung im Auge) |
| `…54138456….MP4` (5 s, 960×960) | Lebendige Illustration der Fensterszene mit Papierrand | Buchseite 7 (Illustration) |
| Logo (PNG, 1254×1254) | Script-Wortmarke mit Herz, Gold auf Navy #03132C, Unterzeile „Personalisierte Kinderbücher“ | freigestellt: Gold/Navy/Creme-Varianten, App-Icon (Herz) |

**Asset-Lücke:** Das im Auftrag genannte **Kinderbuch-PDF lag nicht bei**. Gemäß Regelwerk („keine stillen Ersatzassets“)
ist die Lücke gekennzeichnet (README, `src/content/book.ts`) und ein Import-Skript für die echten Seiten vorbereitet.

Aus dem Video gewonnenes echtes Buchmaterial: Titel „Emma und die leuchtende Schaukel“, Cover-Stil (Nachtblau, Goldsterne,
runde Gold-Serif), Rückseitenzitat „Manchmal beginnt die größte Magie mit einem kleinen Traum …“, Illustrationen.

## Was die Referenz lehrt (Motion-Grammatik)

Aus den Walkthrough-Screenshots im Handbuch (Flugzeugfenster → Wolken → Jet):
- **ein dominantes, zentrales Motiv**, das über lange **gepinnte** Strecken bleibt;
- **Scale + Translation als Kapitelwechsel** („das Objekt wird zum nächsten Kapitel“: Fenster → Himmel);
- **große Editorial-Typografie + kleine Utility-Texte**, Text erscheint erst, wenn die Bewegung ruht;
- **Wechsel dunkler und heller Kapitel** als Rhythmus;
- Bewegung ruhig, Scrollstrecke lang im Verhältnis zur Bewegung (kein hektisches 1:1).

Übertragung: Auge = Fenster in die Geschichte; Illustration → Buchcover = „Objekt wird zum Kapitel“;
Nacht (Foto) → Iris-Dunkel → warme Illustration → helles Papier (Buch/Formular).

## G1 – Anforderungen (Priorität)

1. Hero → langsamer Zoom aufs Kind → nahtloser Übergang → echtes Buch (wichtigste Sequenz).
2. Buch mit 4–8 echten Seiten, Blättern per Scroll, Wischen, Klicken, Tippen, Pfeiltasten.
3. Einfacher Konfigurator (5 Schritte + CTA), mobile first, datenschutzfreundlich.
4. Reduced Motion, Accessibility, Performance (60 fps, kein CLS), Dokumentation, Fehlerprotokoll.

## G2 – Visuelles Konzept

- **Farben (Tokens):** Nacht `#0B1D36`, Ink `#10264A`, Creme `#FFF8EE`, Papier `#F8F0E3`, Sand `#EADCC6`, Gold `#D6B36A`
  (als Text: `#7A5C24`, 5,5:1 auf Papier), Koralle `#EF6A67` (CTA-Fläche `#B8473F`, 5:1 Kontrast). Navy aus dem Logo abgeleitet.
- **Typografie:** Fraunces „Soft“ (weiche, märchenhafte Serif – nahe am Titel des echten Buches) für Headlines, Gewicht 500;
  Figtree für UI/Fließtext. Fluid Type mit `clamp()`.
- **Dramaturgie:** warmes Nachtzimmer → Dunkel der Pupille (+ dezenter Lichtimpuls) → leuchtende Illustration → helles
  Papier mit schwebendem 3D-Buch → Konfigurator als „Blatt“, das über das Buch gleitet.
- **Texte:** kurz, emotional („Jedes Kind verdient seine eigene Geschichte.“ · „Und plötzlich beginnt eure Geschichte.“ ·
  „Dein Kind. Sein Lieblingskuscheltier. Eure Idee. Unsere Geschichte. Ein Buch, das es nur einmal gibt.“).

## G3 – Technische Architektur & Entscheidungen

| Frage | Entscheidung | Begründung |
|---|---|---|
| Video scrubben oder Bildsequenz? | **Bildsequenz auf Canvas** | `currentTime`-Seeking stottert auf iOS; Sequenz ist framegenau und reversibel (Bible 5.2, Variante C) |
| Video 1:1 abspielen? | **Nein – virtuelle Kamera** | gemessene Zoomrate des KI-Videos schwankt 0,5–6,7 %/Frame; Auge driftet (siehe LEARNINGS L1) |
| Asset-Swap Real → Illustration | im Material (Crossfade in der Pupille, Frames 124–128) + Kamera-Push + Lichtimpuls | exakt wie Bible Kap. 5 („Swap in der Pupille verstecken“) |
| GSAP/ScrollTrigger? | **nein**, eigene Engine (~150 Zeilen) | Sticky ist nativ und iOS-stabil; eine Timeline, ein Loop; kein Pin-Spacer-Reflow; weniger JS |
| Smooth Scroll (Lenis)? | **nein** | natives Momentum bleibt; Dämpfung nur in der Visualisierung (τ 85–140 ms) |
| 3D-Buch: WebGL oder CSS? | **CSS 3D** | ausreichend räumlich (Deckel, Buchblock, Perspektive, Schatten), GPU, kein Three.js-Bundle |
| Übergang Illustration → Buch | Canvas zeichnet den Endframe in das exakte Cover-Rechteck (`bookGeometry` geteilt), dann Übergabe an DOM-Cover | pixelgleiche Übergabe (gemessen: nur Resampling-Kanten, kein Versatz) |
| Mobile Buch | Einzelseiten (6), Buchrücken links, geblätterte Seiten laufen aus dem Bild | Lesbarkeit (Bible 8.1/16) |
| Buttons/Swipe/Tasten | scrollen zur Zielseite | eine Quelle der Wahrheit, reversibel |
| Formular | react-hook-form + zod/mini, lokale Zwischenspeicherung | Bible 6/10; Kinderfotos verlassen das Gerät nicht |
