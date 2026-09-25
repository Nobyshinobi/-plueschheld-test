/** Easing-Funktionen (t in [0,1]). Keine linearen Kamerabewegungen im Story-Teil. */
export const clamp01 = (x: number) => (x < 0 ? 0 : x > 1 ? 1 : x);
export const clamp = (x: number, a: number, b: number) => (x < a ? a : x > b ? b : x);
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
/** Anteil von x zwischen a und b, auf [0,1] begrenzt. */
export const range = (x: number, a: number, b: number) => clamp01((x - a) / (b - a));

export const smoothstep = (t: number) => {
  const x = clamp01(t);
  return x * x * (3 - 2 * x);
};
export const smootherstep = (t: number) => {
  const x = clamp01(t);
  return x * x * x * (x * (x * 6 - 15) + 10);
};
export const easeInOutSine = (t: number) => -(Math.cos(Math.PI * clamp01(t)) - 1) / 2;
export const easeInOutCubic = (t: number) => {
  const x = clamp01(t);
  return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
};
export const easeOutCubic = (t: number) => 1 - Math.pow(1 - clamp01(t), 3);
export const easeInCubic = (t: number) => Math.pow(clamp01(t), 3);

/**
 * "Kamera"-Kurve für die Kamerafahrt: sehr sanfter Anlauf (länger als Sinus),
 * gleichmäßige Fahrt, weiches Abbremsen. Mischung aus Sinus und Smootherstep.
 */
export const cinema = (t: number) => {
  const x = clamp01(t);
  return 0.55 * easeInOutSine(x) + 0.45 * smootherstep(x);
};

/** Glockenkurve 0 -> 1 -> 0 (für Impulse wie den Lichtimpuls im Auge). */
export const bell = (t: number) => Math.sin(Math.PI * clamp01(t));
