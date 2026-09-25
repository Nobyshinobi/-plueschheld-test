#!/usr/bin/env node
/**
 * Interaktions- & Robustheitstests der Story:
 *  - Buch: Buttons, Pfeiltasten, Swipe, Tippen (Scroll bleibt Quelle der Wahrheit)
 *  - Reload mitten in der Szene, Resize/Orientation, schnelles Scrollen, Rückwärts-Scrollen
 *  - Frame-Zeiten während Mausrad-Scroll (Long-Frames)
 * node scripts/qa/interactions.mjs [--url http://localhost:3000]
 */
import { chromium } from "playwright-core";
import { existsSync, mkdirSync } from "node:fs";

const base = (() => {
  const i = process.argv.indexOf("--url");
  return i > -1 ? process.argv[i + 1] : "http://localhost:3000";
})();
const out = "qa-artifacts/interactions";
mkdirSync(out, { recursive: true });
const CHROME = process.env.CHROME_PATH || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const browser = await chromium.launch({ executablePath: existsSync(CHROME) ? CHROME : undefined });
const ok = (c, m) => {
  console.log(`${c ? "✓" : "✗"} ${m}`);
  if (!c) process.exitCode = 1;
};
const settle = (page, ms = 900) => page.waitForTimeout(ms);
const state = (page) => page.evaluate(() => ({ p: window.__plh.progress(), st: window.__plh.state(), r: window.__plh.renderer(), y: scrollY }));
const gotoP = async (page, p) => {
  const y = await page.evaluate((pp) => window.__plh.scrollYFor(pp), p);
  await page.evaluate((yy) => scrollTo(0, yy), y);
  await settle(page);
};

async function run(name, ctxOpts, fn) {
  const ctx = await browser.newContext(ctxOpts);
  const page = await ctx.newPage();
  const logs = [];
  page.on("console", (m) => (m.type() === "error" || m.type() === "warning") && logs.push(`[${m.type()}] ${m.text()}`));
  page.on("pageerror", (e) => logs.push(`[pageerror] ${e.message}`));
  await page.goto(base + "/", { waitUntil: "load" });
  await page.waitForFunction(() => window.__plh?.renderer().drawn.frame > 0, null, { timeout: 20000 });
  console.log(`\n== ${name}`);
  await fn(page, ctx);
  ok(logs.filter((l) => !/ERR_ABORTED/.test(l)).length === 0, `Konsole sauber${logs.length ? `: ${logs.join(" | ")}` : ""}`);
  await ctx.close();
}

// ---------------------------------------------------------------- Desktop
await run("Desktop 1440×900", { viewport: { width: 1440, height: 900 } }, async (page) => {
  // "Beispiel ansehen" in der Navigation -> Buch offen
  await page.getByRole("link", { name: "Beispiel ansehen" }).first().click();
  await settle(page, 1500);
  let s = await state(page);
  ok(s.st.book.open > 0.99 && Math.round(s.st.book.flip) === 0, `Nav "Beispiel ansehen" öffnet das Buch (open=${s.st.book.open.toFixed(2)})`);
  await page.screenshot({ path: `${out}/desktop-beispiel.png` });

  await page.getByRole("button", { name: "Nächste Seite" }).click();
  await settle(page, 1600);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 1, `Button "Nächste Seite" blättert (flip=${s.st.book.flip.toFixed(2)})`);
  ok((await page.getByText(/Doppelseite 2/).count()) > 0, "Seitenanzeige aktualisiert (Doppelseite 2)");

  await page.keyboard.press("ArrowRight");
  await settle(page, 1600);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 2, `Pfeiltaste → blättert (flip=${s.st.book.flip.toFixed(2)})`);
  ok(await page.getByRole("button", { name: "Nächste Seite" }).isDisabled(), "Letzte Seite: 'Nächste' deaktiviert");

  await page.keyboard.press("ArrowLeft");
  await settle(page, 1600);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 1, `Pfeiltaste ← blättert zurück (flip=${s.st.book.flip.toFixed(2)})`);

  // Klick auf linke Buchhälfte -> zurück
  const hit = await page.locator(".book-hit").boundingBox();
  await page.mouse.click(hit.x + hit.width * 0.2, hit.y + hit.height * 0.5);
  await settle(page, 1600);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 0, `Klick links auf das Buch blättert zurück (flip=${s.st.book.flip.toFixed(2)})`);

  // Tastatur: Tab erreicht die Buch-Buttons, sichtbarer Fokus
  await page.getByRole("button", { name: "Nächste Seite" }).focus();
  const outline = await page.evaluate(() => getComputedStyle(document.activeElement).outlineStyle);
  ok(outline !== "none", `Sichtbarer Fokus auf Buch-Button (${outline})`);

  // Reload mitten in der Transformation
  await gotoP(page, 0.24);
  await page.reload({ waitUntil: "load" });
  await page.waitForFunction(() => window.__plh?.renderer().drawn.frame > 0, null, { timeout: 20000 });
  await settle(page, 1200);
  s = await state(page);
  ok(Math.abs(s.p - 0.24) < 0.02, `Reload mitten in der Szene: Position erhalten (p=${s.p.toFixed(3)}, Frame ${s.r.drawn.frame})`);
  await page.screenshot({ path: `${out}/desktop-reload-024.png` });

  // Mausrad: schnelles Scrollen hin & zurück. Bewertet wird die eigene Script-Zeit pro Frame
  // (Canvas-Rastern läuft headless ohne GPU auf der CPU und ist nicht repräsentativ).
  await gotoP(page, 0.0);
  const cdp = await page.context().newCDPSession(page);
  await cdp.send("Performance.enable");
  const metric = async () => Object.fromEntries((await cdp.send("Performance.getMetrics")).metrics.map((m) => [m.name, m.value]));
  await page.evaluate(() => {
    window.__frames = [];
    let last = performance.now();
    const loop = (t) => {
      window.__frames.push(t - last);
      last = t;
      if (window.__frames.length < 600) requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  });
  const m0 = await metric();
  await page.mouse.move(700, 450);
  for (let i = 0; i < 60; i++) {
    await page.mouse.wheel(0, 180);
    await page.waitForTimeout(16);
  }
  for (let i = 0; i < 40; i++) {
    await page.mouse.wheel(0, -260); // Richtungswechsel
    await page.waitForTimeout(16);
  }
  await settle(page, 800);
  const m1 = await metric();
  const frames = await page.evaluate(() => window.__frames.slice(2));
  const long = frames.filter((f) => f > 50).length;
  const avg = frames.reduce((a, b) => a + b, 0) / frames.length;
  const scriptPerFrame = ((m1.ScriptDuration - m0.ScriptDuration) * 1000) / frames.length;
  ok(scriptPerFrame < 2, `Mausrad hin & zurück: eigene Script-Zeit ${scriptPerFrame.toFixed(2)} ms/Frame (Budget < 2 ms)`);
  console.log(`  ℹ Frame-Statistik (Software-Rendering, ohne GPU): Ø ${avg.toFixed(1)} ms, ${long} Frames > 50 ms`);
  s = await state(page);
  ok(s.r.drawn.frame > 0, "Nach Richtungswechsel: Canvas zeichnet weiter");

  // Sehr schneller Sprung ans Ende und zurück (Leerframes?)
  await page.evaluate(() => scrollTo(0, document.body.scrollHeight));
  await settle(page, 600);
  await page.evaluate(() => scrollTo(0, 0));
  await settle(page, 900);
  s = await state(page);
  ok(s.p < 0.001 && s.r.drawn.frame === 1, `Sprung Ende→Anfang: wieder Frame 1 (Frame ${s.r.drawn.frame})`);
});

// ---------------------------------------------------------------- Direkter Sprung vor dem Laden
{
  console.log("\n== Direkter Sprung ins Buch/Morph, bevor die Sequenz geladen ist (Regression)");
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  const page = await ctx.newPage();
  await page.route(/\/media\/hero\/[plf]\/(?!001)/, (r) => new Promise((res) => setTimeout(() => res(r.continue()), 4000))); // Sequenz künstlich langsam
  await page.goto(base + "/", { waitUntil: "load" });
  await page.waitForFunction(() => window.__plh?.story, null, { timeout: 20000 });
  await page.evaluate(() => document.getElementById("beispiel").scrollIntoView());
  await settle(page, 900);
  const vis = await page.evaluate(() => getComputedStyle(document.querySelector(".story-stage img.hero-poster")).visibility);
  ok(vis === "hidden", `Buch sofort nach dem Laden: Poster verdeckt das Buch nicht (poster=${vis})`);
  await page.screenshot({ path: `${out}/jump-book-before-load.png` });
  const story = await page.evaluate(() => window.__plh.story());
  const pm = (story.seg.morph[0] + story.seg.morph[1]) / 2;
  await page.evaluate((y) => scrollTo(0, y), await page.evaluate((pp) => window.__plh.scrollYFor(pp), pm));
  await settle(page, 1500);
  const op = await page.evaluate(() => getComputedStyle(document.querySelector(".story-stage canvas")).opacity);
  ok(op === "1", `Direkt im Morph: Canvas-Karte sichtbar (opacity=${op})`);
  await page.screenshot({ path: `${out}/jump-morph-before-load.png` });
  await ctx.close();
}

// ---------------------------------------------------------------- Mobile + Rotation
await run("iPhone 390×844 (touch)", { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true }, async (page, ctx) => {
  const example = await page.evaluate(() => window.__plh.scrollYFor(0) + 0);
  void example;
  await page.evaluate(() => document.getElementById("beispiel").scrollIntoView());
  await settle(page, 1200);
  let s = await state(page);
  ok(s.st.book.open > 0.99, `Anker #beispiel öffnet das Buch auf Mobile (open=${s.st.book.open.toFixed(2)})`);
  ok(s.st.book && (await page.getByText(/Seite 1/).count()) > 0, "Einzelseiten-Modus: 'Seite 1 von 6'");

  // Swipe nach links (CDP-Touch)
  const hit = await page.locator(".book-hit").boundingBox();
  const cdp = await ctx.newCDPSession(page);
  const swipe = async (x0, x1, y) => {
    await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: x0, y }] });
    for (let k = 1; k <= 8; k++) await cdp.send("Input.dispatchTouchEvent", { type: "touchMove", touchPoints: [{ x: x0 + ((x1 - x0) * k) / 8, y }] });
    await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
  };
  await swipe(hit.x + hit.width * 0.8, hit.x + hit.width * 0.15, hit.y + hit.height * 0.5);
  await settle(page, 1500);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 1, `Swipe nach links blättert vor (flip=${s.st.book.flip.toFixed(2)})`);
  // Tippen rechts
  await page.touchscreen.tap(hit.x + hit.width * 0.75, hit.y + hit.height * 0.5);
  await settle(page, 1500);
  s = await state(page);
  ok(Math.round(s.st.book.flip) === 2, `Tippen rechts blättert vor (flip=${s.st.book.flip.toFixed(2)})`);
  await page.screenshot({ path: `${out}/mobile-flip2.png` });

  // Rotation ins Querformat mitten im Hero
  await gotoP(page, 0.12);
  await page.setViewportSize({ width: 844, height: 390 });
  await settle(page, 1500);
  s = await state(page);
  ok(s.r.set === "l" && s.r.drawn.frame > 0, `Querformat: Landscape-Set aktiv, Canvas zeichnet (set=${s.r.set}, Frame ${s.r.drawn.frame})`);
  await page.screenshot({ path: `${out}/mobile-landscape-012.png` });
  await page.setViewportSize({ width: 390, height: 844 });
  await settle(page, 1500);
  s = await state(page);
  ok(s.r.set === "p", `Zurück ins Hochformat: Portrait-Set (set=${s.r.set})`);
  await page.screenshot({ path: `${out}/mobile-portrait-back-012.png` });
});

await browser.close();
