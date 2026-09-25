#!/usr/bin/env node
/** Zwischenstände eines Umblättervorgangs (Schattierung, Tiefe, z-Reihenfolge) */
import { chromium } from "playwright-core";
import { mkdirSync } from "node:fs";
const url = process.argv[2] || process.env.QA_URL || "http://localhost:3000";
mkdirSync("qa-artifacts/flip", { recursive: true });
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
for (const vp of [{ width: 390, height: 844 }, { width: 1440, height: 900 }]) {
  const page = await browser.newPage({ viewport: vp, deviceScaleFactor: 1 });
  await page.goto(url + "/", { waitUntil: "load" });
  await page.waitForFunction(() => window.__plh?.story, null, { timeout: 20000 });
  const story = await page.evaluate(() => window.__plh.story());
  const [a, b] = story.seg.flip2;
  for (const f of [0.45, 0.58, 0.68, 0.76, 0.86, 1]) {
    const p = a + (b - a) * f;
    await page.evaluate((y) => scrollTo(0, y), await page.evaluate((pp) => window.__plh.scrollYFor(pp), p));
    await page.waitForTimeout(1300);
    await page.screenshot({ path: `qa-artifacts/flip/${vp.width}-${String(Math.round(f * 100)).padStart(3, "0")}.png` });
  }
  await page.close();
}
await browser.close();
