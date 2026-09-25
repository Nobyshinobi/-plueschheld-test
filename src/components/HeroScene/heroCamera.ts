/**
 * Virtuelle Kamera für die Hero-Transformation
 * ============================================
 * Jeder Frame der Sequenz ist über eine affine Matrix in eine von zwei "Welten" registriert
 * (Welt 0 = Koordinaten von Frame 1, Welt 1 = Koordinaten des Endframes; siehe Pipeline).
 *
 * Die Kamera bestimmt für einen kontinuierlichen Frame-Index t:
 *   - die interpolierte Lage von Frame t in seiner Welt (M_t),
 *   - den Bildausschnitt (Crop) im Seitenverhältnis des Viewports um den "Look-at"-Punkt
 *     (Bildkomposition → Auge, wie in der Pipeline kalibriert).
 * Gezeichnet wird ein *geladener* Nachbarframe j, per Transformation exakt auf die Kamera
 * von t gewarpt. Ergebnis: stufenloser Zoom zwischen Frames, Auge bleibt verankert, und bei
 * fehlenden Frames wird ein Nachbar verwendet statt zu ruckeln.
 *
 * Koordinaten: "W-Einheiten" (x in [0,1], y in [0, H], H = Quellhöhe/Quellbreite).
 * Affine Matrizen als [a, b, c, d, e, f] (Canvas-Konvention).
 */
export type Mat = [number, number, number, number, number, number];
export type SetName = "p" | "f" | "l";
export type Rect = [number, number, number, number]; // x, y, w, h

export type HeroManifest = {
  version: number;
  source: { w: number; h: number };
  end: number;
  k: number;
  swap: [number, number];
  worlds: { from: number; to: number; m: Mat[] }[];
  eye: [number, number][];
  look: [number, number][];
  sets: Record<SetName, { w: number; h: number; bw: number; bh: number }>;
  frames: { i: number; r: Partial<Record<SetName, Rect>> }[];
  path: string;
};

export const mul = (m: Mat, n: Mat): Mat => [
  m[0] * n[0] + m[2] * n[1],
  m[1] * n[0] + m[3] * n[1],
  m[0] * n[2] + m[2] * n[3],
  m[1] * n[2] + m[3] * n[3],
  m[0] * n[4] + m[2] * n[5] + m[4],
  m[1] * n[4] + m[3] * n[5] + m[5],
];
export const inv = (m: Mat): Mat => {
  const det = m[0] * m[3] - m[1] * m[2];
  const a = m[3] / det, b = -m[1] / det, c = -m[2] / det, d = m[0] / det;
  return [a, b, c, d, -(a * m[4] + c * m[5]), -(b * m[4] + d * m[5])];
};
export const apply = (m: Mat, x: number, y: number): [number, number] => [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]];
const lerpMat = (a: Mat, b: Mat, f: number): Mat => a.map((v, i) => v + (b[i] - v) * f) as Mat;
const scaleOf = (m: Mat) => Math.sqrt(Math.abs(m[0] * m[3] - m[1] * m[2]));

export type Camera = {
  t: number;
  world: 0 | 1;
  /** Frame t → Welt */
  mt: Mat;
  /** Kamera-Rechteck in Koordinaten von Frame t */
  rect: Rect;
};

export class HeroCamera {
  readonly H: number;
  private zin: number[] = []; // kumulierter Log-Zoom Welt 0 (Index = Frame-1)
  private zout: number[] = []; // Welt 1 (Index = Frame - k)
  readonly exported: number[];

  constructor(readonly m: HeroManifest) {
    this.H = m.source.h / m.source.w;
    const w0 = m.worlds[0].m;
    let max = 0;
    for (const mat of w0) {
      max = Math.max(max, -Math.log(scaleOf(mat)));
      this.zin.push(max); // monoton gemacht (Messrauschen)
    }
    const w1 = m.worlds[1].m;
    const raw = w1.map((mat) => -Math.log(scaleOf(mat)));
    // von hinten monoton fallend machen
    let min = 0;
    const mono = new Array(raw.length);
    for (let i = raw.length - 1; i >= 0; i--) {
      min = Math.max(min, raw[i]);
      mono[i] = min;
    }
    this.zout = mono;
    this.exported = m.frames.map((f) => f.i);
  }

  /** Welt-Matrix eines Quellframes i in Welt w */
  matOf(i: number, w: 0 | 1): Mat {
    const W = this.m.worlds[w];
    const idx = Math.min(W.to, Math.max(W.from, i)) - W.from;
    return W.m[idx];
  }

  /** heroPhase (0..3, siehe storyTimeline) → kontinuierlicher Quellframe t */
  tForPhase(phase: number): number {
    const { swap, end, k } = this.m;
    if (phase <= 1) {
      const target = Math.max(0, phase) * this.zin[swap[0] - 1];
      return 1 + this.invert(this.zin, target, 0, swap[0] - 1, true);
    }
    if (phase <= 2) return swap[0] + (swap[1] - swap[0]) * (phase - 1);
    const a = Math.min(1, phase - 2);
    const zStart = this.zout[swap[1] - k];
    const target = (1 - a) * zStart;
    return k + this.invert(this.zout, target, swap[1] - k, end - k, false);
  }

  /** Binäre Suche in monotonem Array → fraktionaler Index */
  private invert(arr: number[], target: number, lo: number, hi: number, increasing: boolean): number {
    let a = lo, b = hi;
    const val = (i: number) => (increasing ? arr[i] : -arr[i]);
    const tv = increasing ? target : -target;
    if (tv <= val(a)) return a;
    if (tv >= val(b)) return b;
    while (b - a > 1) {
      const mid = (a + b) >> 1;
      if (val(mid) <= tv) a = mid;
      else b = mid;
    }
    const va = val(a), vb = val(b);
    return a + (vb === va ? 0 : (tv - va) / (vb - va));
  }

  camera(t: number, aspect: number, over: number): Camera {
    const { k, end } = this.m;
    const tt = Math.min(end, Math.max(1, t));
    const world: 0 | 1 = tt <= k ? 0 : 1;
    const W = this.m.worlds[world];
    const i0 = Math.min(W.to - 1, Math.max(W.from, Math.floor(tt)));
    const f = Math.min(1, Math.max(0, tt - i0));
    const mt = lerpMat(W.m[i0 - W.from], W.m[i0 + 1 - W.from], f);
    const la = this.m.look[i0 - 1], lb = this.m.look[i0];
    const lx = la[0] + (lb[0] - la[0]) * f;
    const ly = la[1] + (lb[1] - la[1]) * f;
    const FA = 1 / this.H;
    let cw: number, ch: number;
    if (aspect <= FA) {
      ch = this.H / over;
      cw = ch * aspect;
    } else {
      cw = 1 / over;
      ch = cw / aspect;
    }
    const cx = Math.min(1 - cw / 2, Math.max(cw / 2, lx));
    const cy = Math.min(this.H - ch / 2, Math.max(ch / 2, ly));
    return { t: tt, world, mt, rect: [cx - cw / 2, cy - ch / 2, cw, ch] };
  }

  /** Augenposition (Frame-t-Koordinaten) – für QA-Overlay */
  eyeAt(t: number): [number, number] {
    const i0 = Math.min(this.m.end - 1, Math.max(1, Math.floor(t)));
    const f = t - i0;
    const a = this.m.eye[i0 - 1], b = this.m.eye[i0];
    return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f];
  }

  /**
   * Kandidaten-Reihenfolge der exportierten Frames für Kamera-Zeitpunkt t:
   * Welt 0 → nächstkleinere (weniger gezoomt = deckt mehr ab), Welt 1 → nächstgrößere.
   */
  candidates(t: number): number[] {
    const { k } = this.m;
    const ex = this.exported;
    if (t <= k) return ex.filter((i) => i <= Math.max(1, t + 1e-6) && i <= k).reverse();
    return ex.filter((i) => i >= t - 1e-6 && i >= k);
  }

  /**
   * Transformation Bildpixel(Frame j, Set s) → Canvas-Pixel (CSS px, ohne DPR)
   */
  transformFor(cam: Camera, j: number, set: SetName, imgW: number, imgH: number, canvasW: number): Mat {
    const frame = this.m.frames.find((f) => f.i === j);
    const band: Rect = frame?.r[set] ?? [0, 0, 1, this.H];
    const B: Mat = [band[2] / imgW, 0, 0, band[3] / imgH, band[0], band[1]];
    const Mj = this.matOf(j, cam.world);
    const kpx = canvasW / cam.rect[2];
    const C: Mat = [kpx, 0, 0, kpx, -cam.rect[0] * kpx, -cam.rect[1] * kpx];
    return mul(C, mul(inv(cam.mt), mul(Mj, B)));
  }

  /** Prüft, ob das Bild den Canvas vollständig abdeckt (keine Ränder sichtbar). */
  covers(T: Mat, imgW: number, imgH: number, cw: number, chh: number): boolean {
    const Ti = inv(T);
    const tol = 0.75;
    for (const [x, y] of [[0, 0], [cw, 0], [0, chh], [cw, chh]] as const) {
      const [u, v] = apply(Ti, x, y);
      if (u < -tol || v < -tol || u > imgW + tol || v > imgH + tol) return false;
    }
    return true;
  }

  frameUrl(set: SetName, i: number) {
    return this.m.path.replace("{set}", set).replace("{i}", String(i).padStart(3, "0"));
  }
}

/** Set-Auswahl nach Seitenverhältnis der Bühne (siehe Pipeline: Bandbreiten + 1.5 % Reserve) */
export function pickSet(aspect: number): SetName {
  if (aspect <= 0.57) return "p";
  if (aspect >= 1.43) return "l";
  return "f";
}
