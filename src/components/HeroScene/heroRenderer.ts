/**
 * HeroRenderer – zeichnet die Transformation auf ein <canvas>
 * ===========================================================
 * Eingabe pro Frame: { heroPhase, over, morph } aus der Story-Timeline.
 *  - Phase Hero/Transformation: bester geladener Sequenzframe, per Kamera-Warp exakt platziert.
 *  - Phase Morph: Endframe (volle Auflösung) schrumpft vom Vollbild auf das Buchcover-Rechteck;
 *    Bildausschnitt öffnet sich dabei von "Viewport-Crop" zu "ganzes Motiv" (= Cover-Motiv).
 * Keine React-Renders pro Frame; nur Canvas-Zeichnen, wenn sich etwas geändert hat.
 */
import { easeInOutCubic } from "@/animations/easing";
import { FrameStore } from "./frameStore";
import { apply, type Camera, type HeroCamera, type Mat, pickSet, type Rect, type SetName } from "./heroCamera";

export type HeroDrawState = { heroPhase: number; over: number; morph: number };
type Box = { x: number; y: number; w: number; h: number };

const OVERSCAN_STEPS = [1, 1.03, 1.07, 1.12, 1.2, 1.35, 1.6, 2, 3];

export class HeroRenderer {
  private ctx: CanvasRenderingContext2D;
  private w = 0;
  private h = 0;
  private dpr = 1;
  private store: FrameStore | null = null;
  private prevStore: FrameStore | null = null;
  private coverImg: HTMLImageElement | null = null;
  private coverReady = false;
  private coverRect: Box | null = null;
  private coverRadius = 4;
  private last: HeroDrawState | null = null;
  private dirty = true;
  private firstDraw = false;
  private readonly coarse: boolean;
  private readonly debugEye: boolean;
  onFirstDraw: (() => void) | null = null;
  /** zuletzt gezeichneter Frame (für QA) */
  lastDrawn = { set: "" as SetName | "", frame: 0, t: 0 };

  constructor(private canvas: HTMLCanvasElement, private cam: HeroCamera, private coverSrc: { webp: string; width: number }) {
    const ctx = canvas.getContext("2d", { alpha: true, desynchronized: false });
    if (!ctx) throw new Error("Canvas 2D nicht verfügbar");
    this.ctx = ctx;
    this.coarse = window.matchMedia?.("(pointer: coarse)").matches ?? false;
    this.debugEye = new URLSearchParams(window.location.search).has("debug-eye");
  }

  get set(): SetName | null {
    return this.store?.set ?? null;
  }

  get loadState() {
    return this.store?.size ?? null;
  }

  resize(cssW: number, cssH: number) {
    if (cssW < 2 || cssH < 2) return;
    const maxPx = this.coarse ? 2.4e6 : 3.6e6;
    const dpr = Math.min(window.devicePixelRatio || 1, 2, Math.sqrt(maxPx / (cssW * cssH)));
    if (cssW === this.w && cssH === this.h && dpr === this.dpr) return;
    this.w = cssW;
    this.h = cssH;
    this.dpr = dpr;
    this.canvas.width = Math.round(cssW * dpr);
    this.canvas.height = Math.round(cssH * dpr);
    const set = pickSet(cssW / cssH);
    if (!this.store || this.store.set !== set) {
      this.prevStore?.dispose();
      this.prevStore = this.store;
      this.store = new FrameStore(this.cam, set, { coarsePointer: this.coarse });
      this.store.onReady = () => {
        this.dirty = true;
        this.redraw();
      };
      this.store.start();
    }
    this.dirty = true;
    this.redraw();
  }

  /** Ziel-Rechteck des Buchcovers (CSS px, frontal, ungedreht) */
  setCoverTarget(rect: Box, radius: number) {
    this.coverRect = rect;
    this.coverRadius = radius;
    this.dirty = true;
  }

  /** Cover-Motiv (Endframe in voller Auflösung) vorladen */
  preloadCover() {
    if (this.coverImg) return;
    const img = new Image();
    img.decoding = "async";
    img.src = this.coverSrc.webp;
    this.coverImg = img;
    img
      .decode()
      .then(() => {
        this.coverReady = true;
        this.dirty = true;
        this.redraw();
      })
      .catch(() => {});
  }

  render(s: HeroDrawState) {
    const l = this.last;
    if (!this.dirty && l && l.heroPhase === s.heroPhase && l.over === s.over && l.morph === s.morph) return;
    this.last = { ...s };
    this.dirty = false;
    this.draw(s);
  }

  private redraw() {
    if (this.last) {
      this.dirty = false;
      this.draw(this.last);
    }
  }

  private draw(s: HeroDrawState) {
    const { ctx } = this;
    if (!this.store || !this.w) return;
    const t = this.cam.tForPhase(s.heroPhase);
    this.store.focus(t);
    if (s.heroPhase > 1.2) this.preloadCover();

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    if (s.morph > 0) {
      this.drawMorph(s);
      return;
    }
    const cam = this.cam.camera(t, this.w / this.h, s.over);
    if (this.drawCamera(cam, this.store) || (this.prevStore && this.drawCamera(cam, this.prevStore))) {
      if (this.prevStore && this.store.has(this.cam.candidates(t)[0] ?? -1)) {
        this.prevStore.dispose();
        this.prevStore = null;
      }
      if (this.debugEye) this.drawEye(cam);
      if (!this.firstDraw) {
        this.firstDraw = true;
        this.onFirstDraw?.();
      }
    }
  }

  /** Zeichnet die Kamera mit dem besten verfügbaren Frame. true, wenn gezeichnet wurde. */
  private drawCamera(cam: Camera, store: FrameStore): boolean {
    const cands = this.cam.candidates(cam.t);
    let j: number | undefined = cands.find((i) => store.has(i));
    if (j === undefined) {
      // Notfall: irgendein Frame derselben Welt
      const near = store.nearestDecoded(cam.t);
      if (near === undefined) return false;
      if ((near <= this.cam.m.k) !== (cam.world === 0) && near !== this.cam.m.k) return false;
      j = near;
    }
    const img = store.get(j)!;
    const sz = store.set;
    const iw = "naturalWidth" in img ? img.naturalWidth : img.width;
    const ih = "naturalHeight" in img ? img.naturalHeight : img.height;
    let T = this.cam.transformFor(cam, j, sz, iw, ih, this.w);
    if (!this.cam.covers(T, iw, ih, this.w, this.h)) {
      // Deckung erzwingen: Ausschnitt minimal verkleinern, bis keine Kante sichtbar ist
      const [x, y, w, h] = cam.rect;
      const cx = x + w / 2, cy = y + h / 2;
      for (const f of OVERSCAN_STEPS.slice(1)) {
        const rect: Rect = [cx - w / f / 2, cy - h / f / 2, w / f, h / f];
        const T2 = this.cam.transformFor({ ...cam, rect }, j, sz, iw, ih, this.w);
        T = T2;
        if (this.cam.covers(T2, iw, ih, this.w, this.h)) break;
      }
    }
    const d = this.dpr;
    const { ctx } = this;
    ctx.setTransform(T[0] * d, T[1] * d, T[2] * d, T[3] * d, T[4] * d, T[5] * d);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, 0, 0);
    this.lastDrawn = { set: sz, frame: j, t: cam.t };
    return true;
  }

  private drawMorph(s: HeroDrawState) {
    const { ctx, w, h, dpr } = this;
    const m = easeInOutCubic(s.morph);
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const target = this.coverRect;
    if (!target) return;
    if (!this.coverReady || !this.coverImg) {
      // Fallback bis das Cover-Motiv da ist: letzter Sequenzframe im Zielrechteck
      const cam = this.cam.camera(this.cam.m.end, w / h, 1);
      this.drawCamera(cam, this.store!);
      return;
    }
    const H = this.cam.H;
    const cam0 = this.cam.camera(this.cam.m.end, w / h, 1).rect; // Endframe = Weltkoordinaten Welt 1
    const D: Box = {
      x: target.x * m,
      y: target.y * m,
      w: w + (target.w - w) * m,
      h: h + (target.h - h) * m,
    };
    // Quell-Ausschnitt: Viewport-Crop -> ganzes Motiv, Seitenverhältnis immer = Ziel
    let sw = cam0[2] + (1 - cam0[2]) * m;
    let sh = cam0[3] + (H - cam0[3]) * m;
    const cx = cam0[0] + cam0[2] / 2 + (0.5 - (cam0[0] + cam0[2] / 2)) * m;
    const cy = cam0[1] + cam0[3] / 2 + (H / 2 - (cam0[1] + cam0[3] / 2)) * m;
    const ar = D.w / D.h;
    if (sw / sh > ar) sw = sh * ar;
    else sh = sw / ar;
    const sx = Math.min(1 - sw, Math.max(0, cx - sw / 2));
    const sy = Math.min(H - sh, Math.max(0, cy - sh / 2));
    const img = this.coverImg;
    const k = img.naturalWidth; // px pro W-Einheit
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.save();
    const r = this.coverRadius * m;
    ctx.beginPath();
    if (r > 0.1 && "roundRect" in ctx) ctx.roundRect(D.x, D.y, D.w, D.h, r);
    else ctx.rect(D.x, D.y, D.w, D.h);
    ctx.clip();
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, sx * k, sy * k, sw * k, sh * k, D.x, D.y, D.w, D.h);
    ctx.restore();
  }

  private drawEye(cam: Camera) {
    const [ex, ey] = this.cam.eyeAt(cam.t);
    const k = this.w / cam.rect[2];
    const x = (ex - cam.rect[0]) * k * this.dpr;
    const y = (ey - cam.rect[1]) * k * this.dpr;
    const { ctx } = this;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.strokeStyle = "#00ff88";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x - 30, y);
    ctx.lineTo(x + 30, y);
    ctx.moveTo(x, y - 30);
    ctx.lineTo(x, y + 30);
    ctx.stroke();
  }

  dispose() {
    this.store?.dispose();
    this.prevStore?.dispose();
    this.store = this.prevStore = null;
  }
}

// Hilfsexport für QA-Tests (Punkt aus Frame-Koordinaten in Canvas-Pixel)
export const _frameToCanvas = (cam: Camera, canvasW: number, x: number, y: number): [number, number] => {
  const k = canvasW / cam.rect[2];
  const M: Mat = [k, 0, 0, k, -cam.rect[0] * k, -cam.rect[1] * k];
  return apply(M, x, y);
};
