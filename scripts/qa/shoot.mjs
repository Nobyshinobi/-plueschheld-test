#!/usr/bin/env node
/**
 * Screenshot-QA an definierten Story-Fortschritten.
 *   node scripts/qa/shoot.mjs --vp 390x844 --dpr 3 --at 0,0.25,0.5 --out qa-artifacts/mobile [--url http://localhost:3000] [--reduced] [--debug-eye]
 */
import { chromium } from "playwright-core";
import { existsSync, mkdirSync } from "node:fs";

const arg = (k, d) => {
  const i = process.argv.indexOf(`--${k}`);
  return i > -1 ? process.argv[i + 1] : d;
};
const flag = (k) => process.argv.includes(`--${k}`);
const [W, H] = arg("vp", "390x844").split("x").map(Number);
const dpr = Number(arg("dpr", "2"));
const at = arg("at", "0,0.05,0.12,0.2,0.25,0.3,0.35,0.4,0.45,0.5,0.55,0.6,0.7,0.8,0.9,1").split(",").map(Number);
const out = arg("out", "qa-artifacts/shots");
const base = arg("url", "http://localhost:3000");
const url = base + (flag("debug-eye") ? "/?debug-eye" : "/");
mkdirSync(out, { recursive: true });

const CHROME = process.env.CHROME_PATH || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const browser = await chromium.launch({ executablePath: existsSync(CHROME) ? CHROME : undefined });
const ctx = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: dpr,
  isMobile: W < 700,
  hasTouch: W < 700,
  reducedMotion: flag("reduced") ? "reduce" : "no-preference",
});
const page = await ctx.newPage();
const errors = [];
page.on("console", (m) => (m.type() === "error" || m.type() === "warning") && errors.push(`[${m.type()}] ${m.text()}`));
page.on("pageerror", (e) => errors.push(`[pageerror] ${e.message}`));
page.on("requestfailed", (r) => errors.push(`[requestfailed] ${r.url()} ${r.failure()?.errorText}`));

await page.goto(url, { waitUntil: "load" });
if (!flag("reduced")) {
  await page.waitForFunction(() => window.__plh?.renderer().drawn.frame > 0, null, { timeout: 20000 });
  // alle Frames laden lassen (für deterministische Screenshots)
  await page.waitForFunction(() => {
    const l = window.__plh.renderer().load;
    return l && l.loaded >= l.total;
  }, null, { timeout: 30000 }).catch(() => console.warn("Nicht alle Frames geladen"));
}

for (const p of at) {
  if (!flag("reduced")) {
    const y = await page.evaluate((pp) => window.__plh.scrollYFor(pp), p);
    await page.evaluate((yy) => window.scrollTo(0, yy), y);
    await page.waitForFunction((pp) => Math.abs(window.__plh.progress() - pp) < 0.0005, p, { timeout: 8000 }).catch(() => {});
    await page.waitForTimeout(450);
    const info = await page.evaluate(() => ({ st: window.__plh.state(), r: window.__plh.renderer() }));
    console.log(`p=${p.toFixed(3)} frame=${info.r.drawn.frame} t=${info.r.drawn.t?.toFixed(2)} set=${info.r.set} morph=${info.st.morph.toFixed(2)} open=${info.st.book.open.toFixed(2)} flip=${info.st.book.flip.toFixed(2)}`);
  } else {
    const y = await page.evaluate((pp) => (document.documentElement.scrollHeight - innerHeight) * pp, p);
    await page.evaluate((yy) => window.scrollTo(0, yy), y);
    await page.waitForTimeout(400);
  }
  await page.screenshot({ path: `${out}/p${String(Math.round(p * 1000)).padStart(4, "0")}.png` });
}
// Zusätzlich: Positionen NACH der Story (Vielfache der Viewporthöhe)
const after = arg("after", "");
if (after && !flag("reduced")) {
  for (const k of after.split(",").map(Number)) {
    const y = await page.evaluate((kk) => window.__plh.scrollYFor(1) + kk * innerHeight, k);
    await page.evaluate((yy) => window.scrollTo(0, yy), y);
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${out}/z${String(Math.round(k * 100)).padStart(4, "0")}.png` });
  }
}
console.log(errors.length ? `KONSOLE:\n${errors.join("\n")}` : "Konsole: keine Fehler/Warnungen");
await browser.close();
