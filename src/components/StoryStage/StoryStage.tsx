"use client";

/**
 * StoryStage – die gepinnte Cinematic-Szene
 * =========================================
 * Hero → Kamerafahrt ins Auge → Illustration → Buchcover → Blättern → Ausstieg.
 * Eine Sticky-Bühne, EINE Timeline (sampleStory), Updates direkt ins DOM/Canvas.
 */
import { type CSSProperties, useCallback, useEffect, useRef, useState } from "react";
import { scrollTimeline } from "@/animations/scrollTimeline";
import { BOOK_SPREAD_MIN_WIDTH } from "@/animations/motionTokens";
import { buildStory, progressForExample, progressForFlip, sampleStory, type StoryState } from "@/animations/storyTimeline";
import { BookControls } from "@/components/BookPreview/BookControls";
import { BookFlip, type BookHandle } from "@/components/BookPreview/BookFlip";
import { computeBookGeometry, type BookGeometry } from "@/components/BookPreview/bookGeometry";
import { HeroCamera, type HeroManifest } from "@/components/HeroScene/heroCamera";
import { HeroRenderer } from "@/components/HeroScene/heroRenderer";
import { bookPages } from "@/content/book";
import { copy } from "@/content/copy";
import { useMediaQuery, useReducedMotion } from "@/lib/hooks/useMediaQuery";
import { navTheme } from "@/lib/navTheme";
import { HeroPoster } from "./HeroPoster";
import "./story.css";

const STORIES = { single: buildStory("single"), spread: buildStory("spread") };
const COVER_SRC = { webp: "/media/story/cover-art-1248.webp", width: 1248 };
const MANIFEST_URL = "/media/hero/manifest.json";
/** Manifest einmal pro Seitenaufruf laden (nicht im JS-Bundle: wird erst nach dem LCP gebraucht) */
let manifestPromise: Promise<HeroManifest> | null = null;
const loadManifest = () => (manifestPromise ??= fetch(MANIFEST_URL).then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`)))));

const px = (n: number) => `${Math.round(n * 100) / 100}px`;

export function StoryStage() {
  const reduced = useReducedMotion();
  const spread = useMediaQuery(`(min-width: ${BOOK_SPREAD_MIN_WIDTH}px)`, false);
  const mode = spread ? "spread" : "single";
  const story = STORIES[mode];

  const trackRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const probeRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const posterRef = useRef<HTMLImageElement>(null);
  const heroCopyRef = useRef<HTMLDivElement>(null);
  const cueRef = useRef<HTMLDivElement>(null);
  const vignetteRef = useRef<HTMLDivElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);
  const scrimRef = useRef<HTMLDivElement>(null);
  const paperRef = useRef<HTMLDivElement>(null);
  const illusRef = useRef<HTMLDivElement>(null);
  const captionRefs = useRef<(HTMLParagraphElement | null)[]>([]);
  const captionWrapRef = useRef<HTMLDivElement>(null);
  const subRef = useRef<HTMLParagraphElement>(null);
  const controlsRef = useRef<HTMLDivElement>(null);
  const hitRef = useRef<HTMLDivElement>(null);
  const bookRef = useRef<BookHandle>(null);
  const geomRef = useRef<BookGeometry | null>(null);
  const stateRef = useRef<StoryState | null>(null);

  const [loadBook, setLoadBook] = useState(false);
  const loadBookRef = useRef(false);
  const [pageIndex, setPageIndex] = useState(-1);
  const pageIndexRef = useRef(-1);

  // ---------- Navigation im Buch: Scroll ist die einzige Quelle der Wahrheit ----------
  const goToFlip = useCallback(
    (k: number) => {
      const track = trackRef.current;
      if (!track) return;
      scrollTimeline.scrollToProgress(track, progressForFlip(story, k), true);
    },
    [story],
  );
  const step = useCallback(
    (dir: 1 | -1) => {
      const st = stateRef.current;
      if (!st) return;
      const cur = st.book.open < 0.98 ? -1 : Math.round(st.book.flip);
      goToFlip(Math.max(0, Math.min(story.flips, cur + dir)));
    },
    [goToFlip, story.flips],
  );

  // ---------- Haupt-Effekt: Renderer + Timeline ----------
  useEffect(() => {
    if (reduced) return;
    const track = trackRef.current!;
    const stage = stageRef.current!;
    const canvas = canvasRef.current!;
    let renderer: HeroRenderer | null = null;
    let disposed = false;
    let wantLoading = false;
    const layout = () => {
      const w = stage.clientWidth;
      const h = stage.clientHeight;
      const layoutH = Math.min(h, probeRef.current?.clientHeight || h);
      renderer?.resize(w, h);
      const g = computeBookGeometry(w, layoutH, mode);
      geomRef.current = g;
      renderer?.setCoverTarget(g.cover, g.radius);
      const hit = hitRef.current;
      if (hit) {
        const left = mode === "spread" ? g.spineOpenX - g.pageW : g.spineOpenX;
        const width = mode === "spread" ? g.pageW * 2 : g.pageW;
        Object.assign(hit.style, { left: px(left), top: px(g.top), width: px(width), height: px(g.pageH) });
      }
      if (controlsRef.current) controlsRef.current.style.top = px(g.top + g.pageH + Math.min(26, layoutH * 0.03));
      if (captionWrapRef.current) captionWrapRef.current.style.bottom = px(h - g.top + Math.min(22, layoutH * 0.025));
    };

    let lastTheme = "";
    const update = (p: number) => {
      const st = sampleStory(story, p);
      stateRef.current = st;
      const g = geomRef.current;
      renderer?.render({ heroPhase: st.heroPhase, over: st.over, morph: st.morph });
      canvas.style.visibility = st.book.handoff ? "hidden" : "visible";
      if (g) bookRef.current?.apply(st.book, g);

      const hc = heroCopyRef.current;
      if (hc) {
        hc.style.opacity = String(st.heroCopy);
        hc.style.transform = `translate3d(0, ${(-28 * (1 - st.heroCopy)).toFixed(2)}px, 0)`;
        hc.style.visibility = st.heroCopy > 0.001 ? "visible" : "hidden";
      }
      if (cueRef.current) cueRef.current.style.opacity = String(st.cue);
      if (vignetteRef.current) vignetteRef.current.style.opacity = String(st.vignette);
      if (glowRef.current) {
        glowRef.current.style.opacity = String(st.glow);
        glowRef.current.style.transform = `scale(${(0.7 + 0.5 * st.glow).toFixed(3)})`;
      }
      if (scrimRef.current) scrimRef.current.style.opacity = String(st.scrim);
      if (paperRef.current) paperRef.current.style.opacity = st.morph > 0 ? "1" : "0";
      const ic = illusRef.current;
      if (ic) {
        ic.style.opacity = String(st.illusCopy);
        ic.style.transform = `translate3d(0, ${(18 * (1 - st.illusCopy)).toFixed(2)}px, 0)`;
        ic.style.visibility = st.illusCopy > 0.001 ? "visible" : "hidden";
      }
      // Beweiszeilen: aktive Zeile voll, Nachbarn überblenden
      captionRefs.current.forEach((el, i) => {
        if (!el) return;
        const d = st.caption < 0 ? 9 : Math.abs(st.caption - i);
        const a = Math.max(0, 1 - d * 1.6) * st.captionAlpha;
        el.style.opacity = String(a);
        el.style.transform = `translate3d(0, ${((i - st.caption) * 14).toFixed(2)}px, 0)`;
        el.style.visibility = a > 0.001 ? "visible" : "hidden";
      });
      if (subRef.current) subRef.current.style.opacity = String(st.bookHeadline);
      if (captionWrapRef.current) captionWrapRef.current.style.visibility = st.captionAlpha > 0.001 || st.bookHeadline > 0.001 ? "visible" : "hidden";
      const ctr = controlsRef.current;
      if (ctr) {
        ctr.style.opacity = String(st.bookUi);
        const on = st.bookUi > 0.5;
        ctr.style.visibility = st.bookUi > 0.01 ? "visible" : "hidden";
        ctr.style.pointerEvents = on ? "auto" : "none";
        if (hitRef.current) {
          hitRef.current.style.visibility = on ? "visible" : "hidden";
        }
      }
      if (st.navTheme !== lastTheme) {
        lastTheme = st.navTheme;
        navTheme.set(st.navTheme);
      }
      if (!loadBookRef.current && p > 0.2) {
        loadBookRef.current = true;
        setLoadBook(true);
      }
      const idx = st.book.open < 0.98 ? -1 : Math.round(st.book.flip);
      if (idx !== pageIndexRef.current) {
        pageIndexRef.current = idx;
        setPageIndex(idx);
      }
    };

    // Sequenz erst laden, wenn die Seite steht (LCP/JS zuerst) – sofort, wenn schon gescrollt wurde
    let started = false;
    const startLoading = () => {
      if (started) return;
      started = true;
      wantLoading = true;
      renderer?.startLoading();
      window.removeEventListener("scroll", startLoading);
    };
    let idleId = 0;
    const whenIdle = () => {
      const ric = window.requestIdleCallback ?? ((cb: () => void) => window.setTimeout(cb, 200));
      idleId = ric(startLoading, { timeout: 1500 }) as unknown as number;
    };
    if (window.scrollY > 0) startLoading();
    else {
      window.addEventListener("scroll", startLoading, { passive: true, once: true });
      if (document.readyState === "complete") whenIdle();
      else window.addEventListener("load", whenIdle, { once: true });
    }

    layout();
    const ro = new ResizeObserver(() => {
      layout();
      update(scrollTimeline.getProgress(track));
    });
    ro.observe(stage);
    const unregister = scrollTimeline.register({ track, stage, onUpdate: update });

    // Kamera + Canvas-Renderer, sobald das Manifest da ist (bis dahin zeigt das Poster den Startzustand)
    loadManifest()
      .then((m) => {
        if (disposed) return;
        try {
          renderer = new HeroRenderer(canvas, new HeroCamera(m), COVER_SRC);
        } catch {
          return; // kein Canvas -> Poster bleibt
        }
        renderer.onFirstDraw = () => {
          canvas.style.opacity = "1";
          requestAnimationFrame(() => {
            if (posterRef.current) posterRef.current.style.visibility = "hidden";
          });
        };
        layout();
        if (wantLoading) renderer.startLoading();
        update(scrollTimeline.getProgress(track));
      })
      .catch(() => {
        /* Manifest fehlt -> statisches Poster bleibt sichtbar, Story funktioniert ohne Canvas */
      });

    // QA-/Debug-Zugriff (enthält keine personenbezogenen Daten)
    (window as unknown as { __plh?: unknown }).__plh = {
      progress: () => scrollTimeline.getProgress(track),
      state: () => stateRef.current,
      renderer: () => ({ set: renderer?.set ?? null, load: renderer?.loadState ?? null, drawn: renderer?.lastDrawn ?? { set: "", frame: 0, t: 0 } }),
      scrollTo: (p: number) => scrollTimeline.scrollToProgress(track, p, false),
      scrollYFor: (p: number) => scrollTimeline.scrollYFor(track, p),
      story: () => story,
      geometry: () => geomRef.current,
    };

    return () => {
      window.removeEventListener("scroll", startLoading);
      window.removeEventListener("load", whenIdle);
      if (idleId) (window.cancelIdleCallback ?? window.clearTimeout)(idleId);
      disposed = true;
      ro.disconnect();
      unregister();
      renderer?.dispose();
      navTheme.set("light");
    };
  }, [reduced, mode, story]);

  // ---------- Tastatur: Pfeiltasten blättern, wenn das Buch offen ist ----------
  useEffect(() => {
    if (reduced) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "ArrowRight" && e.key !== "ArrowLeft") return;
      const t = e.target as HTMLElement | null;
      if (t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName))) return;
      const st = stateRef.current;
      if (!st || st.bookUi < 0.5) return;
      e.preventDefault();
      step(e.key === "ArrowRight" ? 1 : -1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [reduced, step]);

  // ---------- Wischen / Tippen auf dem Buch ----------
  const pointer = useRef<{ x: number; y: number; id: number } | null>(null);
  const onPointerDown = (e: React.PointerEvent) => {
    pointer.current = { x: e.clientX, y: e.clientY, id: e.pointerId };
  };
  const onPointerUp = (e: React.PointerEvent) => {
    const s = pointer.current;
    pointer.current = null;
    if (!s || s.id !== e.pointerId) return;
    const dx = e.clientX - s.x;
    const dy = e.clientY - s.y;
    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy) * 1.3) {
      step(dx < 0 ? 1 : -1);
    } else if (Math.abs(dx) < 10 && Math.abs(dy) < 10) {
      const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
      const rel = (e.clientX - r.left) / r.width;
      step(rel > (mode === "spread" ? 0.5 : 0.3) ? 1 : -1);
    }
  };

  const exampleSingle = progressForExample(STORIES.single) * STORIES.single.length;
  const exampleSpread = progressForExample(STORIES.spread) * STORIES.spread.length;
  const trackStyle = {
    "--len-single": STORIES.single.length,
    "--len-spread": STORIES.spread.length,
    "--ex-single": exampleSingle.toFixed(4),
    "--ex-spread": exampleSpread.toFixed(4),
  } as CSSProperties;
  const total = story.flips + 1;

  return (
    <section className="story-motion" aria-label="Die Geschichte: vom Foto zum Kinderbuch">
      <div ref={trackRef} className="story-track" style={trackStyle}>
        <span id={reduced ? undefined : "beispiel"} className="story-anchor" aria-hidden="true" />
        <div ref={stageRef} className="story-stage">
          <div ref={probeRef} className="svh-probe" aria-hidden="true" />
          <div ref={paperRef} className="story-paper" aria-hidden="true" />

          {/* Buch (unter dem Canvas: die Karte "landet" auf dem Cover) */}
          <div
            className="absolute inset-0"
            role="region"
            aria-roledescription="Buch"
            aria-label={copy.book.regionLabel}
          >
            <BookFlip ref={bookRef} mode={mode} pages={bookPages} load={loadBook} />
            <div
              ref={hitRef}
              className="book-hit"
              style={{ visibility: "hidden" }}
              onPointerDown={onPointerDown}
              onPointerUp={onPointerUp}
              onPointerCancel={() => (pointer.current = null)}
              aria-hidden="true"
            />
          </div>

          <HeroPoster ref={posterRef} className="story-layer object-cover" />
          <canvas ref={canvasRef} className="story-layer" style={{ opacity: 0 }} aria-hidden="true" />

          <div ref={vignetteRef} className="story-vignette" aria-hidden="true" />
          <div ref={glowRef} className="story-glow" aria-hidden="true" />
          <div ref={scrimRef} className="story-scrim" aria-hidden="true" />

          <p className="sr-only">{copy.hero.sceneDescription}</p>

          {/* Hero-Text */}
          <div ref={heroCopyRef} className="hero-copy">
            <div className="container-page">
              <h1 className="max-w-[9.3em] text-display text-cream drop-shadow-[0_2px_18px_rgba(0,0,0,0.35)]">{copy.hero.headline}</h1>
              <p className="mt-4 max-w-[30ch] text-lead text-cream/90 md:mt-5">{copy.hero.subline}</p>
            </div>
          </div>
          <div ref={cueRef} className="scroll-cue" aria-hidden="true">
            <span>{copy.hero.scrollCue}</span>
            <i />
          </div>

          {/* Nach der Verwandlung */}
          <div ref={illusRef} className="illus-copy" style={{ visibility: "hidden", opacity: 0 }}>
            <div className="container-page text-center">
              <h2 className="mx-auto max-w-[10.6em] text-headline text-cream drop-shadow-[0_2px_16px_rgba(0,0,0,0.45)]">{copy.transformation.headline}</h2>
              <p className="mx-auto mt-3 max-w-[34ch] text-lead text-cream/90">{copy.transformation.subline}</p>
            </div>
          </div>

          {/* Kind + Teddy → Geschichte → Buch */}
          <div ref={captionWrapRef} className="proof-wrap" style={{ visibility: "hidden" }}>
            <div className="proof-lines" aria-live="off">
              {copy.proof.map((line, i) => (
                <p key={line} ref={(el) => void (captionRefs.current[i] = el)} className="proof-line" style={{ visibility: "hidden", opacity: 0 }}>
                  {line}
                </p>
              ))}
            </div>
            <p ref={subRef} className="proof-sub" style={{ opacity: 0 }}>
              {copy.book.headline}
            </p>
          </div>

          <div ref={controlsRef} className="book-controls" style={{ visibility: "hidden", opacity: 0 }}>
            <BookControls index={pageIndex} total={total} mode={mode} onPrev={() => step(-1)} onNext={() => step(1)} />
            <p className="mt-2 text-center text-[0.82rem] text-ink-soft md:hidden">{copy.book.swipeHint}</p>
          </div>
        </div>
      </div>
    </section>
  );
}
