#!/usr/bin/env node
/** Prüft die Übergabe Canvas-Karte -> DOM-Cover: Pixel-Differenz im Cover-Bereich direkt vor/nach dem Wechsel. */
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
const url = process.argv[2] || "http://localhost:3001";
mkdirSync("qa-artifacts/handoff", { recursive: true });
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
for (const vp of [{ width: 390, height: 844 }, { width: 1440, height: 900 }]) {
  const page = await browser.newPage({ viewport: vp, deviceScaleFactor: 2 });
  await page.goto(url + "/", { waitUntil: "load" });
  await page.waitForFunction(() => { const l = window.__plh?.renderer().load; return l && l.loaded >= l.total; }, null, { timeout: 30000 });
  const story = await page.evaluate(() => window.__plh.story());
  const [a, b] = story.seg.morph;
  const shots = [];
  for (const [name, p] of [["vor", b - (b - a) * 0.002], ["nach", b + 0.0005]]) {
    const y = await page.evaluate((pp) => window.__plh.scrollYFor(pp), p);
    await page.evaluate((yy) => scrollTo(0, yy), y);
    await page.waitForTimeout(1200);
    const g = await page.evaluate(() => window.__plh.geometry());
    const st = await page.evaluate(() => window.__plh.state());
    const clip = { x: g.cover.x + 3, y: g.cover.y + 3, width: g.cover.w - 6, height: g.cover.h - 6 };
    const f = `qa-artifacts/handoff/${vp.width}-${name}.png`;
    await page.screenshot({ path: f, clip });
    shots.push(f);
    console.log(`${vp.width}px ${name}: morph=${st.morph.toFixed(4)} handoff=${st.book.handoff} title=${st.book.title.toFixed(3)}`);
  }
  const diff = execFileSync("python3", ["-c", `
import sys
from PIL import Image, ImageChops, ImageStat
a=Image.open(sys.argv[1]).convert('RGB'); b=Image.open(sys.argv[2]).convert('RGB').resize(a.size)
d=ImageChops.difference(a,b); st=ImageStat.Stat(d)
print(f"mittlere Abweichung {sum(st.mean)/3:.2f}/255, max {max(x[1] for x in d.getextrema())}")
`, ...shots]).toString().trim();
  console.log(`${vp.width}px Übergabe Canvas→DOM: ${diff}`);
  await page.close();
}
await browser.close();
