/**
 * FrameStore – progressives Laden + speicherbegrenztes Dekodieren der Sequenz
 * ===========================================================================
 * - Komprimierte Frames (WebP, ~33 kB) werden vollständig als Blob gehalten (≈ 4 MB).
 * - Dekodiert (ImageBitmap, ≈ 3–4 MB je Frame!) wird nur ein Fenster um die Kamera
 *   (LRU, Obergrenze nach Gerät) -> kein Speicher-Crash auf iOS.
 * - Ladereihenfolge: erst Frame 1 + Endframe, dann grob → fein (jeder 16., 8., 4., 2. …),
 *   Frames nahe der aktuellen Scrollposition werden vorgezogen.
 * - createImageBitmap dekodiert off-main-thread -> kein Jank beim Zeichnen.
 */
import type { HeroCamera, SetName } from "./heroCamera";

type Drawable = ImageBitmap | HTMLImageElement;

export class FrameStore {
  private blobs = new Map<number, Blob>();
  private decoded = new Map<number, Drawable>(); // Einfüge-Reihenfolge = LRU
  private decoding = new Set<number>();
  private queue: number[] = [];
  private inflight = 0;
  private aborter = new AbortController();
  private disposed = false;
  private pinned: Set<number>;
  private focusT = 1;
  private readonly concurrency: number;
  private readonly maxDecoded: number;
  onReady: (() => void) | null = null;

  constructor(private cam: HeroCamera, readonly set: SetName, opts: { coarsePointer: boolean }) {
    this.concurrency = opts.coarsePointer ? 4 : 6;
    this.maxDecoded = opts.coarsePointer ? 18 : 32;
    const ex = cam.exported;
    this.pinned = new Set([ex[0], ex[ex.length - 1]]);
    // Grob → fein
    const order: number[] = [ex[0], ex[ex.length - 1]];
    for (const stride of [16, 8, 4, 2, 1]) for (let k = 0; k < ex.length; k += stride) order.push(ex[k]);
    this.queue = [...new Set(order)];
  }

  get size() {
    return { loaded: this.blobs.size, total: this.cam.exported.length, decoded: this.decoded.size };
  }

  start() {
    this.pump();
  }

  /** Kamera-Position mitteilen: priorisiert Laden & Dekodieren in der Nähe. */
  focus(t: number) {
    this.focusT = t;
    const near = this.nearby(t, 6);
    // Laden: nahe Frames nach vorne ziehen
    const missing = near.filter((i) => !this.blobs.has(i) && this.queue.includes(i));
    if (missing.length) {
      this.queue = [...missing, ...this.queue.filter((i) => !missing.includes(i))];
      this.pump();
    }
    for (const i of near) this.decode(i);
  }

  get(i: number): Drawable | undefined {
    const d = this.decoded.get(i);
    if (d) {
      // LRU auffrischen
      this.decoded.delete(i);
      this.decoded.set(i, d);
    }
    return d;
  }

  /** Irgendein dekodierter Frame nahe t (Notfall-Fallback). */
  nearestDecoded(t: number): number | undefined {
    let best: number | undefined;
    let bd = Infinity;
    for (const i of this.decoded.keys()) {
      const d = Math.abs(i - t);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  has(i: number) {
    return this.decoded.has(i);
  }

  dispose() {
    this.disposed = true;
    this.aborter.abort();
    for (const d of this.decoded.values()) if ("close" in d) d.close();
    this.decoded.clear();
    this.blobs.clear();
  }

  private nearby(t: number, n: number): number[] {
    const ex = this.cam.exported;
    return [...ex].sort((a, b) => Math.abs(a - t) - Math.abs(b - t)).slice(0, n);
  }

  private pump() {
    while (!this.disposed && this.inflight < this.concurrency && this.queue.length) {
      const i = this.queue.shift()!;
      if (this.blobs.has(i)) continue;
      this.inflight++;
      fetch(this.cam.frameUrl(this.set, i), { signal: this.aborter.signal })
        .then((r) => {
          if (!r.ok) throw new Error(`HTTP ${r.status}`);
          return r.blob();
        })
        .then((b) => {
          this.blobs.set(i, b);
          // Frames nahe der Kamera sofort dekodieren
          if (this.pinned.has(i) || Math.abs(i - this.focusT) <= 8) this.decode(i);
        })
        .catch(() => {
          /* Netzfehler: Frame fehlt -> Nachbarframes übernehmen */
        })
        .finally(() => {
          this.inflight--;
          this.pump();
        });
    }
  }

  private decode(i: number) {
    if (this.disposed || this.decoded.has(i) || this.decoding.has(i)) return;
    const blob = this.blobs.get(i);
    if (!blob) return;
    this.decoding.add(i);
    const done = (d: Drawable) => {
      this.decoding.delete(i);
      if (this.disposed) {
        if ("close" in d) d.close();
        return;
      }
      this.decoded.set(i, d);
      this.evict();
      this.onReady?.();
    };
    const viaImage = () => {
      const url = URL.createObjectURL(blob);
      const img = new Image();
      img.src = url;
      img
        .decode()
        .then(() => done(img))
        .catch(() => this.decoding.delete(i))
        .finally(() => URL.revokeObjectURL(url));
    };
    if (typeof createImageBitmap === "function") {
      createImageBitmap(blob).then(done, viaImage);
    } else viaImage();
  }

  private evict() {
    while (this.decoded.size > this.maxDecoded) {
      let victim: number | undefined;
      let far = -1;
      for (const i of this.decoded.keys()) {
        if (this.pinned.has(i)) continue;
        const d = Math.abs(i - this.focusT);
        if (d > far) {
          far = d;
          victim = i;
        }
      }
      if (victim === undefined) return;
      const d = this.decoded.get(victim)!;
      if ("close" in d) d.close();
      this.decoded.delete(victim);
    }
  }
}
