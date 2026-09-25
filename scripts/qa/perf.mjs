#!/usr/bin/env node
/** Frame-Budget-Analyse beim Scrollen: CDP-Metriken (Script/Layout/Style/Paint) + rAF-Intervalle. */
import { chromium } from "playwright-core";
import { existsSync } from "node:fs";
const arg = (k, d) => { const i = process.argv.indexOf(`--${k}`); return i > -1 ? process.argv[i + 1] : d; };
const url = arg("url", "http://localhost:3001");
const [W, H] = arg("vp", "1440x900").split("x").map(Number);
const gpu = process.argv.includes("--gpu");
const CHROME = process.env.CHROME_PATH || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const browser = await chromium.launch({ executablePath: existsSync(CHROME) ? CHROME : undefined, args: gpu ? ["--enable-gpu-rasterization", "--ignore-gpu-blocklist"] : [] });
const page = await browser.newPage({ viewport: { width: W, height: H } });
const q = arg("smooth", "");
if (q) await page.addInitScript((qq) => {
  const d = Object.getOwnPropertyDescriptor(CanvasRenderingContext2D.prototype, "imageSmoothingQuality");
  Object.defineProperty(CanvasRenderingContext2D.prototype, "imageSmoothingQuality", { get() { return d.get.call(this); }, set() { d.set.call(this, qq); } });
}, q);
await page.goto(url + "/", { waitUntil: "load" });
await page.waitForFunction(() => { const l = window.__plh?.renderer().load; return l && l.loaded >= l.total; }, null, { timeout: 30000 });
const cdp = await page.context().newCDPSession(page);
await cdp.send("Performance.enable");
const metric = async () => Object.fromEntries((await cdp.send("Performance.getMetrics")).metrics.map((m) => [m.name, m.value]));
const range = arg("range", "0,0.45").split(",").map(Number);
const y0 = await page.evaluate((p) => window.__plh.scrollYFor(p), range[0]);
const y1 = await page.evaluate((p) => window.__plh.scrollYFor(p), range[1]);
await page.evaluate((y) => scrollTo(0, y), y0);
await page.waitForTimeout(600);
// eigene Update-Zeit messen (Timeline-Callback)
await page.evaluate(() => {
  window.__f = []; let last = performance.now();
  const loop = (t) => { window.__f.push(t - last); last = t; if (window.__run) requestAnimationFrame(loop); };
  window.__run = true; requestAnimationFrame(loop);
});
const m0 = await metric();
const steps = 120;
for (let i = 1; i <= steps; i++) {
  await page.evaluate((y) => scrollTo(0, y), y0 + ((y1 - y0) * i) / steps);
  await page.waitForTimeout(16);
}
await page.waitForTimeout(500);
const m1 = await metric();
const f = await page.evaluate(() => { window.__run = false; return window.__f.slice(3); });
const d = (k) => ((m1[k] - m0[k]) * 1000).toFixed(0);
const wall = (m1.Timestamp - m0.Timestamp) * 1000;
console.log(`Bereich p=${range.join("→")} · ${W}x${H} · ${steps} Scroll-Schritte · Wandzeit ${wall.toFixed(0)} ms`);
console.log(`Script ${d("ScriptDuration")} ms · Layout ${d("LayoutDuration")} ms · Style ${d("RecalcStyleDuration")} ms · Task gesamt ${d("TaskDuration")} ms`);
const avg = f.reduce((a, b) => a + b, 0) / f.length;
console.log(`rAF: ${f.length} Frames, Ø ${avg.toFixed(1)} ms, p95 ${[...f].sort((a, b) => a - b)[Math.floor(f.length * 0.95)].toFixed(1)} ms, >50ms: ${f.filter((x) => x > 50).length}`);
await browser.close();
