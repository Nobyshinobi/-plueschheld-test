#!/usr/bin/env node
/** Vergleicht Hero-Textblock mit Fallback-Font (Webfonts blockiert) vs. Webfont -> Layout-Shift-Risiko. */
import { chromium } from "playwright-core";
const url = process.argv[2] || (process.env.QA_URL || "http://localhost:3000") + "/";
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
for (const vp of [{ width: 390, height: 844 }, { width: 430, height: 932 }, { width: 1440, height: 900 }]) {
  const res = {};
  for (const block of [true, false]) {
    const page = await browser.newPage({ viewport: vp });
    if (block) await page.route(/\.woff2$/, (r) => r.abort());
    await page.goto(url, { waitUntil: "load" });
    await page.waitForTimeout(300);
    res[block ? "fallback" : "webfont"] = await page.evaluate(() => {
      const h1 = document.querySelector(".hero-copy h1").getBoundingClientRect();
      const box = document.querySelector(".hero-copy").getBoundingClientRect();
      const p = document.querySelector(".hero-copy p").getBoundingClientRect();
      return { h1: Math.round(h1.height), p: Math.round(p.height), boxTop: Math.round(box.top), boxH: Math.round(box.height) };
    });
    await page.close();
  }
  const same = JSON.stringify(res.fallback) === JSON.stringify(res.webfont);
  console.log(`${same ? "✓" : "✗"} ${vp.width}x${vp.height} Fallback = Webfont`, JSON.stringify(res));
  if (!same) process.exitCode = 1;
}
await browser.close();
