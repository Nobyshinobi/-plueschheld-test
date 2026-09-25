/**
 * Story-Timeline (Choreografie)
 * =============================
 * Eine einzige, deterministische Timeline für die komplette gepinnte Story:
 *
 *   Hero (Realbild) → Zoom ins Auge → Swap in der Iris → Zoom aus dem gemalten Auge
 *   → Illustration → wird zum Buchcover → Buch öffnet sich → Seiten blättern → Ausstieg
 *
 * `sampleStory(story, p)` ist eine reine Funktion (Fortschritt → Zustand) und damit testbar.
 * Längen in "Bildschirmhöhen" (svh) Scrollstrecke.
 */
import { bell, cinema, clamp01, easeInOutCubic, easeInOutSine, lerp, range, smoothstep } from "./easing";

export type BookMode = "single" | "spread";

const HEAD = [
  ["establish", 0.35],
  ["zoomIn", 2.8],
  ["swap", 0.55],
  ["zoomOut", 2.1],
  ["illusHold", 0.7],
  ["morph", 1.0],
  ["coverHold", 0.5],
  ["open", 0.8],
] as const;
/** Länge des Ausstiegs = Überlappung der Konfigurator-Sektion mit der gepinnten Bühne */
export const EXIT_LEN = 0.9;
const TAIL = [
  ["finalHold", 0.5],
  ["exit", EXIT_LEN],
] as const;

/** Anzahl Blättervorgänge nach dem Öffnen des Covers */
export const FLIPS: Record<BookMode, number> = { spread: 2, single: 5 };
const FLIP_LEN: Record<BookMode, number> = { spread: 1.0, single: 0.7 };
/** Anteil jeder Blätter-Einheit, in dem die aktuelle Seite ruhig stehen bleibt */
const FLIP_HOLD = 0.42;

export type Story = {
  mode: BookMode;
  /** Scrollstrecke in Bildschirmhöhen */
  length: number;
  seg: Record<string, [number, number]>;
  flips: number;
};

export function buildStory(mode: BookMode): Story {
  const list: [string, number][] = [...HEAD.map(([a, b]) => [a, b] as [string, number])];
  for (let i = 1; i <= FLIPS[mode]; i++) list.push([`flip${i}`, FLIP_LEN[mode]]);
  list.push(...TAIL.map(([a, b]) => [a, b] as [string, number]));
  const length = list.reduce((s, [, l]) => s + l, 0);
  const seg: Story["seg"] = {};
  let acc = 0;
  for (const [id, l] of list) {
    seg[id] = [acc / length, (acc + l) / length];
    acc += l;
  }
  return { mode, length, seg, flips: FLIPS[mode] };
}

export type StoryState = {
  /** 0..3: [0,1] Zoom hinein, [1,2] Swap, [2,3] Zoom heraus (bereits ge-eased) */
  heroPhase: number;
  /** zusätzlicher Kamera-Zoom (Overscan) ≥ 1 */
  over: number;
  /** 0..1 Morph Illustration → Buchcover (roh; Renderer wendet Easing an) */
  morph: number;
  heroCopy: number;
  cue: number;
  vignette: number;
  glow: number;
  scrim: number;
  illusCopy: number;
  /** Beweis-Zeilen: kontinuierlicher Index (1.5 = Überblendung Zeile 1→2), -1 = aus */
  caption: number;
  captionAlpha: number;
  book: {
    /** Buchkörper (Rückdeckel, Seitenblock, Schatten) sichtbar 0..1 */
    body: number;
    /** DOM-Cover übernimmt vom Canvas */
    handoff: boolean;
    title: number;
    tilt: number;
    open: number;
    /** Anzahl geblätterter Seiten nach dem Cover (kontinuierlich) */
    flip: number;
    exit: number;
  };
  bookUi: number;
  bookHeadline: number;
  navTheme: "dark" | "light";
};

const local = (story: Story, id: string, p: number) => {
  const [a, b] = story.seg[id];
  return range(p, a, b);
};

export function sampleStory(story: Story, p: number): StoryState {
  const L = (id: string) => local(story, id, p);
  const est = L("establish");
  const zin = L("zoomIn");
  const swp = L("swap");
  const zout = L("zoomOut");
  const hold = L("illusHold");
  const morph = L("morph");
  const cover = L("coverHold");
  const open = L("open");
  const exit = L("exit");

  // --- Kamera ---------------------------------------------------------
  let heroPhase: number;
  let over = 1.02;
  if (zin < 1) {
    heroPhase = cinema(zin);
    over = zin > 0 ? 1.02 : 1 + 0.02 * easeInOutSine(est);
  } else if (swp < 1) {
    heroPhase = 1 + easeInOutSine(swp);
    over = 1.02 + 0.08 * bell(swp);
  } else {
    heroPhase = 2 + cinema(zout);
    over = 1.02 - 0.02 * easeInOutSine(hold);
  }

  // --- Texte & Licht ---------------------------------------------------
  const heroCopy = 1 - smoothstep(range(zin, 0.015, 0.14));
  const cue = 1 - smoothstep(range(zin + est * 0.02, 0.0, 0.05));
  const vignette = 0.62 * smoothstep(range(zin, 0.04, 0.55)) * (1 - smoothstep(range(zout, 0.15, 0.75)));
  const glow = 0.85 * bell(range(swp, 0.15, 0.85));
  const [zoStart, zoEnd] = story.seg.zoomOut;
  const illusIn = smoothstep(range(p, zoStart + (zoEnd - zoStart) * 0.86, story.seg.illusHold[0] + (story.seg.illusHold[1] - story.seg.illusHold[0]) * 0.35));
  const illusCopy = illusIn * (1 - smoothstep(range(morph, 0.0, 0.22)));
  const scrim = 1 - smoothstep(range(morph, 0.05, 0.45));

  // --- Beweiszeilen: Kind → Kuscheltier → Idee → Geschichte → Buch ---------
  let caption = -1;
  let captionAlpha = 0;
  if (morph > 0.18) {
    caption = lerp(0, 2, smoothstep(range(morph, 0.3, 0.95)));
    captionAlpha = smoothstep(range(morph, 0.18, 0.38));
    if (cover > 0) caption = 2 + smoothstep(range(cover, 0.15, 0.85));
    if (open > 0) caption = 3 + smoothstep(range(open, 0.55, 1));
    captionAlpha *= 1 - smoothstep(range(exit, 0, 0.35));
  }

  // --- Buch ------------------------------------------------------------
  let flip = 0;
  for (let i = 1; i <= story.flips; i++) {
    const a = L(`flip${i}`);
    flip += easeInOutCubic(range(a, FLIP_HOLD, 1));
  }
  const book = {
    body: smoothstep(range(morph, 0.5, 1)),
    handoff: morph >= 1,
    title: smoothstep(range(cover, 0.0, 0.7)),
    tilt: easeInOutSine(range(cover, 0.1, 1)) * (1 - 0.65 * easeInOutSine(open)),
    open: easeInOutCubic(open),
    flip,
    exit: easeInOutSine(exit),
  };
  const bookUi = smoothstep(range(open, 0.7, 1)) * (1 - smoothstep(range(exit, 0, 0.25)));
  const bookHeadline = smoothstep(range(open, 0.45, 0.95)) * (1 - smoothstep(range(exit, 0, 0.3)));

  return {
    heroPhase,
    over,
    morph,
    heroCopy,
    cue,
    vignette,
    glow,
    scrim,
    illusCopy,
    caption,
    captionAlpha,
    book,
    bookUi,
    bookHeadline,
    navTheme: morph < 0.08 ? "dark" : "light",
  };
}

/** Fortschritt p, bei dem nach `k` Blättervorgängen die Seite ruhig steht (für Buttons/Swipe). */
export function progressForFlip(story: Story, k: number): number {
  const kk = Math.max(0, Math.min(story.flips, Math.round(k)));
  if (kk === story.flips) {
    const [a, b] = story.seg.finalHold;
    return lerp(a, b, 0.5);
  }
  const [a, b] = story.seg[`flip${kk + 1}`];
  return lerp(a, b, FLIP_HOLD * 0.5);
}

/** Fortschritt, bei dem das Buch gerade geöffnet ist ("Beispiel ansehen"). */
export const progressForExample = (story: Story) => progressForFlip(story, 0);

/** Aktuelle, gerundete Seite für Anzeige/ARIA. */
export const currentFlip = (s: StoryState) => Math.round(clamp01(s.book.open) < 0.5 ? -1 : s.book.flip);
