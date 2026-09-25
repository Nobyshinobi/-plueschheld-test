"use client";
import { useSyncExternalStore } from "react";

/**
 * Media-Query als React-Wert – hydration-sicher:
 * Server-Snapshot = `serverDefault` (Mobile-first), der Client aktualisiert nach der Hydration.
 */
export function useMediaQuery(query: string, serverDefault = false): boolean {
  return useSyncExternalStore(
    (cb) => {
      const mql = window.matchMedia(query);
      mql.addEventListener("change", cb);
      return () => mql.removeEventListener("change", cb);
    },
    () => window.matchMedia(query).matches,
    () => serverDefault,
  );
}

export const useReducedMotion = () => useMediaQuery("(prefers-reduced-motion: reduce)", false);
