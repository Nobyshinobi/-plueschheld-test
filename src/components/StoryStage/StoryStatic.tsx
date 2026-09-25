"use client";

/**
 * Reduced-Motion-Variante der Story: keine Kamerafahrt, kein Pinning, kein Scroll-Zwang.
 * Gleiche Inhalte als ruhige Abfolge: Foto → Illustration → Buch (per Buttons, kurze Überblendung).
 * Sichtbar per CSS-Media-Query (prefers-reduced-motion), JS läuft nur, wenn aktiv.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import { BOOK_SPREAD_MIN_WIDTH, motion } from "@/animations/motionTokens";
import { FLIPS } from "@/animations/storyTimeline";
import { BookControls } from "@/components/BookPreview/BookControls";
import { BookFlip, type BookHandle } from "@/components/BookPreview/BookFlip";
import { computeBookGeometry } from "@/components/BookPreview/bookGeometry";
import { bookMeta, bookPages } from "@/content/book";
import { copy } from "@/content/copy";
import { useMediaQuery, useReducedMotion } from "@/lib/hooks/useMediaQuery";
import { navTheme } from "@/lib/navTheme";
import { HeroPoster } from "./HeroPoster";

export function StoryStatic() {
  const reduced = useReducedMotion();
  const spread = useMediaQuery(`(min-width: ${BOOK_SPREAD_MIN_WIDTH}px)`, false);
  const mode = spread ? "spread" : "single";
  const flips = FLIPS[mode];
  const [kRaw, setK] = useState(0);
  const k = Math.min(kRaw, flips); // Moduswechsel (Einzel-/Doppelseite) ohne Effekt klemmen
  const bookRef = useRef<BookHandle>(null);
  const boxRef = useRef<HTMLDivElement>(null);
  const fadeRef = useRef<HTMLDivElement>(null);
  const heroRef = useRef<HTMLDivElement>(null);

  const apply = useCallback(
    (idx: number) => {
      const box = boxRef.current;
      if (!box) return;
      const g = computeBookGeometry(box.clientWidth, box.clientHeight + 64, mode);
      bookRef.current?.apply({ body: 1, handoff: true, title: 1, tilt: 0, open: 1, flip: idx, exit: 0 }, { ...g, top: g.top - 64 });
    },
    [mode],
  );

  useEffect(() => {
    if (!reduced) return;
    const ro = new ResizeObserver(() => apply(k));
    if (boxRef.current) ro.observe(boxRef.current);
    apply(k);
    return () => ro.disconnect();
  }, [reduced, apply, k]);

  // Navigationsfarbe: hell über dem Foto, dunkel danach
  useEffect(() => {
    if (!reduced || !heroRef.current) return;
    const io = new IntersectionObserver(([e]) => navTheme.set(e.isIntersecting ? "dark" : "light"), { rootMargin: "-64px 0px -85% 0px" });
    io.observe(heroRef.current);
    return () => io.disconnect();
  }, [reduced]);

  const go = (dir: 1 | -1) => {
    const next = Math.max(0, Math.min(flips, k + dir));
    if (next === k) return;
    const el = fadeRef.current;
    if (!el) return setK(next);
    el.style.opacity = "0";
    window.setTimeout(() => {
      setK(next);
      el.style.opacity = "1";
    }, motion.reducedFadeMs);
  };

  return (
    <section className="story-static" aria-label="Die Geschichte: vom Foto zum Kinderbuch">
      <div ref={heroRef} className="relative h-[92svh] min-h-[540px] overflow-hidden bg-night">
        <HeroPoster className="absolute inset-0 h-full w-full object-cover" alt={copy.hero.sceneDescription} />
        <div className="story-scrim" aria-hidden="true" />
        <div className="absolute inset-x-0 bottom-[max(56px,env(safe-area-inset-bottom))]">
          <div className="container-page">
            <h1 className="max-w-[9.3em] text-display text-cream">{copy.hero.headline}</h1>
            <p className="mt-4 max-w-[30ch] text-lead text-cream/90">{copy.hero.subline}</p>
          </div>
        </div>
      </div>

      <div className="relative overflow-hidden bg-night">
        <picture>
          <source type="image/avif" srcSet={`${bookMeta.coverArt}-640.avif 640w, ${bookMeta.coverArt}-960.avif 960w`} sizes="100vw" />
          <img
            src={`${bookMeta.coverArt}-960.webp`}
            srcSet={`${bookMeta.coverArt}-640.webp 640w, ${bookMeta.coverArt}-960.webp 960w, ${bookMeta.coverArt}-1248.webp 1248w`}
            sizes="100vw"
            width={960}
            height={1280}
            loading="lazy"
            alt="Dieselbe Szene als gemalte Kinderbuch-Illustration: Emma mit ihrem Faultier am Fenster, draußen leuchtet die Schaukel."
            className="h-[88svh] min-h-[520px] w-full object-cover"
          />
        </picture>
        <div className="story-scrim" aria-hidden="true" />
        <div className="absolute inset-x-0 bottom-12 text-center">
          <div className="container-page">
            <h2 className="mx-auto max-w-[10.6em] text-headline text-cream">{copy.transformation.headline}</h2>
            <p className="mx-auto mt-3 max-w-[34ch] text-lead text-cream/90">{copy.transformation.subline}</p>
          </div>
        </div>
      </div>

      <div className="bg-paper pb-10 pt-24 md:pt-28">
        <div className="container-page text-center">
          <ul className="mx-auto flex max-w-3xl flex-wrap justify-center gap-x-4 gap-y-1 font-display text-title text-ink" aria-label="So entsteht euer Buch">
            {copy.proof.map((l) => (
              <li key={l}>{l}</li>
            ))}
          </ul>
          <p className="mx-auto mt-3 max-w-[34ch] text-ink-soft">{copy.book.headline}</p>
        </div>
        <div id={reduced ? "beispiel" : undefined} className="relative mx-auto mt-4 h-[min(78svh,760px)] min-h-[440px] w-full max-w-[1200px]" ref={boxRef}>
          <div ref={fadeRef} className="absolute inset-0 transition-opacity" style={{ transitionDuration: `${motion.reducedFadeMs}ms` }} role="region" aria-roledescription="Buch" aria-label={copy.book.regionLabel}>
            {reduced && <BookFlip ref={bookRef} mode={mode} pages={bookPages} load />}
          </div>
        </div>
        <div className="mt-2">
          <BookControls index={k} total={flips + 1} mode={mode} onPrev={() => go(-1)} onNext={() => go(1)} />
        </div>
      </div>
    </section>
  );
}
