/**
 * In-Page-Navigation: kurze Distanzen weich scrollen, lange Distanzen direkt springen
 * (sonst würde die komplette Story im Zeitraffer "vorgespult"). Kein globales CSS smooth-scroll.
 */
export function scrollToId(id: string) {
  const el = document.getElementById(id);
  if (!el) return;
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const top = el.getBoundingClientRect().top + window.scrollY;
  const far = Math.abs(top - window.scrollY) > window.innerHeight * 3.5;
  window.scrollTo({ top, behavior: reduce || far ? "auto" : "smooth" });
  history.replaceState(null, "", `#${id}`);
  // Fokus für Tastatur-/Screenreader-Nutzer an das Ziel übergeben
  const focusTarget = (el.matches("[tabindex],a,button,input,textarea,select,h1,h2,h3") ? el : el.querySelector<HTMLElement>("h1,h2,h3")) as HTMLElement | null;
  if (focusTarget) {
    if (!focusTarget.hasAttribute("tabindex") && /^H[1-3]$/.test(focusTarget.tagName)) focusTarget.setAttribute("tabindex", "-1");
    focusTarget.focus({ preventScroll: true });
  }
}
