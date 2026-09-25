/**
 * Kleiner Store für das Farbschema der Navigation (hell auf dunklem Hero / dunkel auf Papier).
 * Wird von der Story-Timeline bei Schwellwerten gesetzt – nicht pro Frame.
 */
export type NavTheme = "dark" | "light";
let theme: NavTheme = "dark";
const subs = new Set<() => void>();

export const navTheme = {
  get: () => theme,
  set(next: NavTheme) {
    if (next === theme) return;
    theme = next;
    subs.forEach((s) => s());
  },
  subscribe(cb: () => void) {
    subs.add(cb);
    return () => void subs.delete(cb);
  },
};
