#!/usr/bin/env node
/** Tastatur-only-Durchlauf: Skip-Link, Navigation, Buch, Konfigurator. */
import { chromium } from "playwright-core";
const url = process.argv[2] || process.env.QA_URL || "http://localhost:3000";
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
const ok = (c, m) => { console.log(`${c ? "✓" : "✗"} ${m}`); if (!c) process.exitCode = 1; };
const active = () => page.evaluate(() => { const a = document.activeElement; return `${a.tagName.toLowerCase()}:${(a.getAttribute("aria-label") || a.textContent || "").trim().slice(0, 40)}`; });
await page.goto(url + "/", { waitUntil: "load" });
await page.keyboard.press("Tab");
ok((await active()).includes("Direkt zum Buch-Konfigurator"), `1. Tab: Skip-Link (${await active()})`);
const vis = await page.evaluate(() => document.activeElement.getBoundingClientRect().top >= 0);
ok(vis, "Skip-Link wird bei Fokus sichtbar");
await page.keyboard.press("Tab"); await page.keyboard.press("Tab"); await page.keyboard.press("Tab");
ok((await active()).includes("Beispiel ansehen"), `Navigation per Tab erreichbar (${await active()})`);
await page.keyboard.press("Enter");
await page.waitForTimeout(1500);
await page.keyboard.press("Tab");
let a = await active();
if (!/Seite/.test(a)) { await page.keyboard.press("Tab"); a = await active(); }
if (!/Seite/.test(a)) { await page.keyboard.press("Tab"); a = await active(); }
ok(/Nächste Seite|Vorherige Seite/.test(a), `Nach "Beispiel ansehen": Buch-Buttons per Tab erreichbar (${a})`);
if (!/Nächste Seite/.test(a)) await page.keyboard.press("Tab");
await page.keyboard.press("Enter");
await page.waitForTimeout(1600);
const flip = await page.evaluate(() => Math.round(window.__plh.state().book.flip));
ok(flip === 1, `Enter auf "Nächste Seite" blättert (flip=${flip})`);
const live = await page.evaluate(() => document.querySelector('[aria-live="polite"]')?.textContent);
ok(/Doppelseite 2/.test(live || ""), `Seitenansage (aria-live): "${live}"`);
// Skip-Link springt zum Konfigurator
await page.evaluate(() => scrollTo(0, 0));
await page.waitForTimeout(500);
await page.evaluate(() => document.activeElement?.blur());
await page.keyboard.press("Tab");
await page.keyboard.press("Enter");
await page.waitForTimeout(900);
await page.keyboard.press("Tab");
a = await active();
ok(/Foto|Datei|input|label/i.test(a) || (await page.evaluate(() => !!document.activeElement.closest("#buch-erstellen"))), `Skip-Link → Fokus im Konfigurator (${a})`);
await browser.close();
