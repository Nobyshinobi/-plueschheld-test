/**
 * Motion-Tokens (JS-Seite). CSS-Pendants: --dur-*, --ease-* in globals.css.
 */
export const motion = {
  /** Zeitkonstante der gedämpften Scroll-Kopplung in Sekunden (größer = träger/filmischer) */
  scrubTau: { desktop: 0.14, touch: 0.085 },
  /** Ab diesem Sprung im Fortschritt wird nicht animiert, sondern direkt gesetzt (Reload, Anker) */
  snapThreshold: 0.12,
  /** Dauer der Buch-Crossfades im Reduced-Motion-Modus (ms) */
  reducedFadeMs: 180,
} as const;

/** Unter dieser Breite zeigt das Buch Einzelseiten statt Doppelseiten (== --breakpoint-md). */
export const BOOK_SPREAD_MIN_WIDTH = 768;
