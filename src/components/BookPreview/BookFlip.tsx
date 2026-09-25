"use client";

/**
 * BookFlip – räumliches Buch mit Umblättern (CSS 3D)
 * ==================================================
 * Rendert die statische Struktur (Deckel, Buchblock-Kanten, Blätter mit Vorder-/Rückseite).
 * Bewegung ausschließlich imperativ über `apply()` (Transforms/Opacity, keine React-Renders
 * pro Frame). Treiber sind austauschbar: Scroll-Timeline (Story) oder Buttons (Reduced Motion).
 */
import { type Ref, useImperativeHandle, useMemo, useRef } from "react";
import type { BookMode } from "@/animations/storyTimeline";
import { clamp01, lerp } from "@/animations/easing";
import { bookMeta, type BookPage } from "@/content/book";
import { BOARD, type BookGeometry } from "./bookGeometry";
import s from "./BookFlip.module.css";

export type BookVisual = {
  body: number;
  handoff: boolean;
  title: number;
  tilt: number;
  open: number;
  flip: number;
  exit: number;
};

export type BookHandle = {
  apply: (v: BookVisual, g: BookGeometry) => void;
};

type Face = { kind: "cover" } | { kind: "page"; page: BookPage } | { kind: "endpaper"; page?: BookPage } | { kind: "plain" };
type Sheet = { key: string; cover?: boolean; front: Face; back: Face };

export function buildSheets(mode: BookMode, pages: BookPage[]): Sheet[] {
  if (mode === "spread") {
    const [p0, p1, p2, p3, p4, p5] = pages;
    return [
      { key: "cover", cover: true, front: { kind: "cover" }, back: { kind: "endpaper", page: p0 } },
      { key: "s1", front: { kind: "page", page: p1 }, back: { kind: "page", page: p2 } },
      { key: "s2", front: { kind: "page", page: p3 }, back: { kind: "page", page: p4 } },
      { key: "s3", front: { kind: "page", page: p5 }, back: { kind: "plain" } },
    ];
  }
  return [
    { key: "cover", cover: true, front: { kind: "cover" }, back: { kind: "endpaper" } },
    ...pages.map((p) => ({ key: p.id, front: { kind: "page", page: p } as Face, back: { kind: "plain" } as Face })),
  ];
}

const SIZES = "(min-width: 768px) 34vw, 86vw";

function PageImage({ page, load }: { page: BookPage; load: boolean }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      className={s.pageImg}
      src={load ? `${page.src}-720.webp` : undefined}
      srcSet={load ? `${page.src}-720.webp 720w, ${page.src}-1080.webp 1080w` : undefined}
      sizes={SIZES}
      width={720}
      height={960}
      alt={page.alt}
      decoding="async"
      draggable={false}
    />
  );
}

function CoverFace({ load, artRef, titleRef, foilRef, hingeRef, sheenRef }: {
  load: boolean;
  artRef: Ref<HTMLImageElement>;
  titleRef: Ref<HTMLDivElement>;
  foilRef: Ref<HTMLDivElement>;
  hingeRef: Ref<HTMLDivElement>;
  sheenRef: Ref<HTMLDivElement>;
}) {
  return (
    <>
      <picture>
        {load && <source type="image/avif" srcSet={`${bookMeta.coverArt}-640.avif 640w, ${bookMeta.coverArt}-960.avif 960w`} sizes={SIZES} />}
        <img
          ref={artRef}
          className={s.coverArt}
          src={load ? `${bookMeta.coverArt}-960.webp` : undefined}
          srcSet={load ? `${bookMeta.coverArt}-640.webp 640w, ${bookMeta.coverArt}-960.webp 960w, ${bookMeta.coverArt}-1248.webp 1248w` : undefined}
          sizes={SIZES}
          width={960}
          height={1280}
          alt="Buchcover: Emma mit ihrem Faultier am Fenster, draußen leuchtet die Schaukel im Mondlicht."
          decoding="async"
          draggable={false}
        />
      </picture>
      <div ref={titleRef} className={s.coverTitle} aria-hidden="true">
        <span className={s.coverName}>{bookMeta.hero}</span>
        <span className={s.coverSub}>und die leuchtende Schaukel</span>
      </div>
      <div ref={foilRef} className={s.coverFoil} aria-hidden="true" />
      <div ref={sheenRef} className={s.coverSheen} aria-hidden="true" />
      <div ref={hingeRef} className={s.coverHinge} aria-hidden="true" />
    </>
  );
}

type Props = {
  mode: BookMode;
  pages: BookPage[];
  load: boolean;
  ref?: Ref<BookHandle>;
};

export function BookFlip({ mode, pages, load, ref }: Props) {
  const sheets = useMemo(() => buildSheets(mode, pages), [mode, pages]);
  const sceneRef = useRef<HTMLDivElement>(null);
  const bookRef = useRef<HTMLDivElement>(null);
  const bodyRefs = useRef<(HTMLDivElement | null)[]>([]);
  const sheetRefs = useRef<(HTMLDivElement | null)[]>([]);
  const shadeRefs = useRef<{ fs: HTMLDivElement | null; bs: HTMLDivElement | null; fc: HTMLDivElement | null; bc: HTMLDivElement | null }[]>([]);
  const floorRef = useRef<HTMLDivElement>(null);
  const artRef = useRef<HTMLImageElement>(null);
  const titleRef = useRef<HTMLDivElement>(null);
  const foilRef = useRef<HTMLDivElement>(null);
  const hingeRef = useRef<HTMLDivElement>(null);
  const sheenRef = useRef<HTMLDivElement>(null);
  const lastGeom = useRef<string>("");

  useImperativeHandle(
    ref,
    () => ({
      apply(v, g) {
        const scene = sceneRef.current;
        const book = bookRef.current;
        if (!scene || !book) return;
        const gk = `${g.pageW}|${g.pageH}|${g.mode}`;
        if (gk !== lastGeom.current) {
          lastGeom.current = gk;
          const thick = Math.max(6, Math.round(g.pageW * 0.024));
          scene.style.setProperty("--pw", String(g.pageW));
          scene.style.setProperty("--ph", String(g.pageH));
          scene.style.setProperty("--board", String(BOARD));
          scene.style.setProperty("--thick", String(thick));
        }
        const thick = Math.max(6, Math.round(g.pageW * 0.024));
        const open = clamp01(v.open);
        const spineX = lerp(g.spineClosedX, g.spineOpenX, open);
        const pivotX = lerp(g.pageW / 2, g.mode === "spread" ? 0 : g.pageW / 2, open);
        const tiltY = -17 * v.tilt;
        const tiltX = 9 * v.tilt;
        const sc = 1 - 0.16 * v.exit;
        const ey = -g.pageH * 0.1 * v.exit;
        book.style.transform =
          `translate3d(${spineX + pivotX}px, ${g.top + g.pageH / 2 + ey}px, 0) rotateX(${tiltX}deg) rotateY(${tiltY}deg) scale(${sc}) ` +
          `translate3d(${-pivotX}px, ${-g.pageH / 2}px, 0)`;
        scene.style.perspectiveOrigin = `${spineX + pivotX}px ${g.top + g.pageH / 2}px`;

        // Buchkörper einblenden (Opacity nur auf Blatt-Elementen, nie auf preserve-3d)
        const body = String(v.body);
        for (const el of bodyRefs.current) if (el) el.style.opacity = body;
        if (floorRef.current) {
          const openW = g.mode === "spread" ? 1 + open : 1;
          floorRef.current.style.opacity = String(v.body * (1 - 0.5 * v.exit));
          floorRef.current.style.transform = `translate3d(${g.mode === "spread" ? -g.pageW * open : 0}px, 0, ${-thick - 1}px) scaleX(${openW})`;
        }

        // Cover-Übergabe vom Canvas
        if (artRef.current) artRef.current.style.visibility = v.handoff ? "visible" : "hidden";
        if (titleRef.current) titleRef.current.style.opacity = String(v.title);
        if (foilRef.current) foilRef.current.style.opacity = String(v.title * 0.95);
        if (hingeRef.current) hingeRef.current.style.opacity = String(Math.max(v.title, v.tilt));
        if (sheenRef.current) {
          sheenRef.current.style.opacity = String(v.tilt * 0.9);
          sheenRef.current.style.setProperty("--sheen", `${-35 + 55 * v.tilt}%`);
        }

        // Blätter
        const n = sheets.length;
        const angles = sheets.map((sh, i) => (sh.cover ? 180 * open : 180 * clamp01(v.flip - (i - 1))));
        for (let i = 0; i < n; i++) {
          const el = sheetRefs.current[i];
          if (!el) continue;
          const a = angles[i];
          const flipped = a >= 90;
          // z-Staffelung gegen z-Fighting: rechts oben liegt das kleinste Blatt, links das zuletzt geblätterte
          const z = sheets[i].cover ? (flipped ? 0.2 : n * 0.9 + 1.2) : flipped ? 0.6 + i * 0.9 : (n - i) * 0.9;
          el.style.transform = `translate3d(0,0,${z}px) rotateY(${-a}deg)`;
          const lift = Math.sin((a * Math.PI) / 180);
          const sh = shadeRefs.current[i];
          if (sh) {
            if (sh.fs) sh.fs.style.opacity = String(a > 0 && a < 90 ? lift * 0.55 : 0);
            if (sh.bs) sh.bs.style.opacity = String(a > 90 && a < 180 ? lift * 0.5 : 0);
            // Schlagschatten des darüberliegenden Blatts auf diese Seite
            const above = i > 0 ? angles[i - 1] : 0;
            if (sh.fc) sh.fc.style.opacity = String(above > 0 && above < 90 ? Math.sin((above * Math.PI) / 180) * 0.8 : 0);
            const next = i < n - 1 ? angles[i + 1] : 0;
            if (sh.bc) sh.bc.style.opacity = String(next > 90 && next < 180 ? Math.sin((next * Math.PI) / 180) * 0.7 : 0);
          }
        }
      },
    }),
    [sheets],
  );

  const face = (f: Face) => {
    switch (f.kind) {
      case "cover":
        return <CoverFace load={load} artRef={artRef} titleRef={titleRef} foilRef={foilRef} hingeRef={hingeRef} sheenRef={sheenRef} />;
      case "page":
        return <PageImage page={f.page} load={load} />;
      case "endpaper":
        return f.page ? (
          <div className={s.endpaper}>
            <PageImage page={f.page} load={load} />
          </div>
        ) : (
          <div className={`${s.endpaper} ${s.endpaperPlain}`} />
        );
      default:
        return null;
    }
  };

  return (
    <div ref={sceneRef} className={s.scene} data-book-mode={mode}>
      <div ref={bookRef} className={s.book}>
        <div ref={floorRef} className={s.floorShadow} aria-hidden="true" />
        <div ref={(el) => void (bodyRefs.current[0] = el)} className={s.boardBack} aria-hidden="true" style={{ transform: `translateZ(calc(var(--thick) * -1px))` }} />
        <div ref={(el) => void (bodyRefs.current[1] = el)} className={s.edgeRight} aria-hidden="true" />
        <div ref={(el) => void (bodyRefs.current[2] = el)} className={s.edgeTop} aria-hidden="true" />
        <div ref={(el) => void (bodyRefs.current[3] = el)} className={s.edgeBottom} aria-hidden="true" />
        {sheets.map((sh, i) => (
          <div key={sh.key} ref={(el) => void (sheetRefs.current[i] = el)} className={`${s.sheet} ${sh.cover ? s.coverSheet : ""}`}>
            <div className={`${s.face} ${s.front} ${sh.cover ? s.coverFront : ""}`}>
              {face(sh.front)}
              <div className={s.cast} ref={(el) => void ((shadeRefs.current[i] ??= { fs: null, bs: null, fc: null, bc: null }).fc = el)} />
              <div className={s.shade} ref={(el) => void ((shadeRefs.current[i] ??= { fs: null, bs: null, fc: null, bc: null }).fs = el)} />
            </div>
            <div className={`${s.face} ${s.back} ${sh.cover ? s.coverInside : sh.back.kind === "plain" ? s.plainBack : ""}`}>
              {face(sh.back)}
              <div className={s.cast} ref={(el) => void ((shadeRefs.current[i] ??= { fs: null, bs: null, fc: null, bc: null }).bc = el)} />
              <div className={s.shade} ref={(el) => void ((shadeRefs.current[i] ??= { fs: null, bs: null, fc: null, bc: null }).bs = el)} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
