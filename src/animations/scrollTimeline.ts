/**
 * Zentrale Scroll-Engine
 * ======================
 * EIN passiver Scroll-Listener + EIN requestAnimationFrame-Loop für alle Scroll-Szenen.
 *
 *  - Pinning über natives `position: sticky` (kein Pin-Spacer, keine Reflows, iOS-stabil).
 *  - Fortschritt 0..1 = (scrollY - trackTop) / (trackHeight - stageHeight).
 *  - Gedämpfte Kopplung ("scrub"): exponentielle Glättung, bildratenunabhängig.
 *  - Große Sprünge (Reload, Anker) werden direkt gesetzt statt "vorgespult".
 *  - Messungen gecacht; neu gemessen nur bei Resize/Orientation/Font-Load/ResizeObserver.
 *  - Loop schläft, sobald Ziel erreicht ist -> 0 % CPU im Ruhezustand.
 *
 * Kein Lenis/Smooth-Scroll: nativer Scroll bleibt unangetastet (Barrierefreiheit, iOS-Momentum).
 */
import { motion } from "./motionTokens";

export type TrackInfo = { target: number; dt: number; jumped: boolean };
export type TrackOptions = {
  /** hohes Element, dessen Höhe die Scrollstrecke definiert */
  track: HTMLElement;
  /** gepinnte Bühne (sticky) – ihre Höhe wird von der Strecke abgezogen */
  stage: HTMLElement;
  onUpdate: (progress: number, info: TrackInfo) => void;
};

type TrackState = TrackOptions & {
  top: number;
  length: number;
  current: number;
  target: number;
  initialized: boolean;
};

class ScrollTimeline {
  private tracks = new Set<TrackState>();
  private raf = 0;
  private last = 0;
  private listening = false;
  private tau: number = motion.scrubTau.desktop;
  private ro: ResizeObserver | null = null;

  register(opts: TrackOptions): () => void {
    const t: TrackState = { ...opts, top: 0, length: 1, current: 0, target: 0, initialized: false };
    this.tracks.add(t);
    this.listen();
    this.ro?.observe(opts.track);
    this.ro?.observe(opts.stage);
    this.measure();
    this.kick();
    return () => {
      this.tracks.delete(t);
      this.ro?.unobserve(opts.track);
      this.ro?.unobserve(opts.stage);
      if (!this.tracks.size) this.unlisten();
    };
  }

  /** Scrollposition (px) für einen Fortschritt p eines Tracks. */
  scrollYFor(track: HTMLElement, p: number): number | null {
    for (const t of this.tracks) if (t.track === track) return Math.round(t.top + p * t.length);
    return null;
  }

  scrollToProgress(track: HTMLElement, p: number, smooth = true) {
    const y = this.scrollYFor(track, p);
    if (y == null) return;
    window.scrollTo({ top: y, behavior: smooth ? "smooth" : "auto" });
  }

  getProgress(track: HTMLElement): number {
    for (const t of this.tracks) if (t.track === track) return t.current;
    return 0;
  }

  /** Nach Layout-Änderungen von außen aufrufen (z. B. Buchmodus-Wechsel). */
  refresh = () => {
    this.measure();
    this.kick();
  };

  private listen() {
    if (this.listening || typeof window === "undefined") return;
    this.listening = true;
    const coarse = window.matchMedia?.("(pointer: coarse)").matches;
    this.tau = coarse ? motion.scrubTau.touch : motion.scrubTau.desktop;
    window.addEventListener("scroll", this.onScroll, { passive: true });
    window.addEventListener("resize", this.refresh, { passive: true });
    window.addEventListener("orientationchange", this.refresh);
    window.addEventListener("load", this.refresh);
    document.fonts?.ready.then(this.refresh).catch(() => {});
    if ("ResizeObserver" in window) this.ro = new ResizeObserver(this.refresh);
  }

  private unlisten() {
    this.listening = false;
    window.removeEventListener("scroll", this.onScroll);
    window.removeEventListener("resize", this.refresh);
    window.removeEventListener("orientationchange", this.refresh);
    window.removeEventListener("load", this.refresh);
    this.ro?.disconnect();
    this.ro = null;
    cancelAnimationFrame(this.raf);
    this.raf = 0;
  }

  private measure() {
    const sy = window.scrollY;
    for (const t of this.tracks) {
      const r = t.track.getBoundingClientRect();
      t.top = r.top + sy;
      t.length = Math.max(1, t.track.offsetHeight - t.stage.offsetHeight);
    }
  }

  private onScroll = () => this.kick();

  private kick() {
    if (!this.raf) {
      this.last = performance.now();
      this.raf = requestAnimationFrame(this.tick);
    }
  }

  private tick = (now: number) => {
    this.raf = 0;
    const dt = Math.min(0.1, Math.max(0.001, (now - this.last) / 1000));
    this.last = now;
    const sy = window.scrollY;
    const k = 1 - Math.exp(-dt / this.tau);
    let active = false;
    for (const t of this.tracks) {
      const target = Math.min(1, Math.max(0, (sy - t.top) / t.length));
      t.target = target;
      let jumped = false;
      if (!t.initialized || Math.abs(target - t.current) > motion.snapThreshold) {
        t.current = target;
        t.initialized = true;
        jumped = true;
      } else {
        t.current += (target - t.current) * k;
        if (Math.abs(target - t.current) < 0.00005) t.current = target;
      }
      if (t.current !== target) active = true;
      t.onUpdate(t.current, { target, dt, jumped });
    }
    if (active) {
      this.raf = requestAnimationFrame(this.tick);
    }
  };
}

export const scrollTimeline = new ScrollTimeline();
