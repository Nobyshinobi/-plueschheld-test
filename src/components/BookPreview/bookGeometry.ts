/**
 * Buch-Geometrie – reine Funktion der Bühnengröße.
 * Wird von Buch (DOM) UND Canvas-Morph benutzt, damit das Cover-Rechteck pixelgenau übereinstimmt.
 */
import type { BookMode } from "@/animations/storyTimeline";

export const PAGE_ASPECT = 3 / 4; // Breite/Höhe
/** Überstand des Buchdeckels über den Buchblock (px) */
export const BOARD = 5;

export type BookGeometry = {
  mode: BookMode;
  pageW: number;
  pageH: number;
  /** x des Buchrückens (Bühnenkoordinaten), geschlossen / offen */
  spineClosedX: number;
  spineOpenX: number;
  /** y-Oberkante der Seiten */
  top: number;
  /** Frontales Cover-Rechteck (inkl. Deckelüberstand) im geschlossenen Zustand */
  cover: { x: number; y: number; w: number; h: number };
  radius: number;
};

export function computeBookGeometry(stageW: number, stageH: number, mode: BookMode): BookGeometry {
  const navH = 64;
  if (mode === "spread") {
    const topZone = navH + Math.min(150, stageH * 0.17);
    const bottomZone = Math.min(104, stageH * 0.13);
    const availH = stageH - topZone - bottomZone;
    const maxSpreadW = Math.min(stageW * 0.86, 1180);
    const pageH = Math.max(160, Math.min(availH, maxSpreadW / 2 / PAGE_ASPECT));
    const pageW = pageH * PAGE_ASPECT;
    const top = topZone + (availH - pageH) / 2;
    const cx = stageW / 2;
    return geometry(mode, pageW, pageH, cx - pageW / 2, cx, top);
  }
  const topZone = navH + Math.min(92, stageH * 0.11);
  const bottomZone = Math.min(112, stageH * 0.14);
  const availH = stageH - topZone - bottomZone;
  const pageW = Math.max(150, Math.min(stageW - 2 * 22, availH * PAGE_ASPECT, 460));
  const pageH = pageW / PAGE_ASPECT;
  const top = topZone + (availH - pageH) / 2;
  const x = (stageW - pageW) / 2;
  return geometry(mode, pageW, pageH, x, x, top);
}

function geometry(mode: BookMode, pageW: number, pageH: number, closedX: number, openX: number, top: number): BookGeometry {
  const r = (v: number) => Math.round(v * 100) / 100;
  return {
    mode,
    pageW: r(pageW),
    pageH: r(pageH),
    spineClosedX: r(closedX),
    spineOpenX: r(openX),
    top: r(top),
    cover: { x: r(closedX), y: r(top - BOARD), w: r(pageW + BOARD), h: r(pageH + 2 * BOARD) },
    radius: 4,
  };
}
