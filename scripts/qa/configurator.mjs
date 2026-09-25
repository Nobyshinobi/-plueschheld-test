#!/usr/bin/env node
/**
 * E2E-Durchlauf Konfigurator: Validierung, Uploads (JPG/PNG/HEIC/defekt), Reload-Wiederherstellung,
 * Tastatur, Absenden. node scripts/qa/configurator.mjs [--vp 390x844] [--out qa-artifacts/config]
 */
import { chromium } from "playwright-core";
import { existsSync, mkdirSync } from "node:fs";

const arg = (k, d) => {
  const i = process.argv.indexOf(`--${k}`);
  return i > -1 ? process.argv[i + 1] : d;
};
const [W, H] = arg("vp", "390x844").split("x").map(Number);
const out = arg("out", "qa-artifacts/config");
const base = arg("url", "http://localhost:3000");
mkdirSync(out, { recursive: true });
const FX = ".cache/fixtures";

const CHROME = process.env.CHROME_PATH || "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const browser = await chromium.launch({ executablePath: existsSync(CHROME) ? CHROME : undefined });
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: W < 700, hasTouch: W < 700 });
const page = await ctx.newPage();
const logs = [];
page.on("console", (m) => (m.type() === "error" || m.type() === "warning") && logs.push(`[${m.type()}] ${m.text()}`));
page.on("pageerror", (e) => logs.push(`[pageerror] ${e.message}`));

let n = 0;
const shot = async (name) => {
  const card = page.locator("#buch-erstellen .card").first();
  await card.scrollIntoViewIfNeeded();
  await page.waitForTimeout(350);
  await page.screenshot({ path: `${out}/${String(++n).padStart(2, "0")}-${name}.png` });
};
const ok = (cond, msg) => {
  console.log(`${cond ? "✓" : "✗"} ${msg}`);
  if (!cond) process.exitCode = 1;
};
const next = () => page.getByRole("button", { name: /^Weiter/ }).click();

await page.goto(base + "/", { waitUntil: "load" });
await page.evaluate(() => localStorage.clear());
await page.goto(base + "/#buch-erstellen", { waitUntil: "load" });
await page.evaluate(() => document.getElementById("buch-erstellen").scrollIntoView());
await page.waitForTimeout(500);

// Schritt 1: ohne Foto weiter -> Fehler
await next();
ok(await page.getByText("Bitte lade ein Foto deines Kindes hoch.").isVisible(), "Fehlermeldung ohne Kinderfoto");
await shot("kind-fehler");
// defekte Datei
await page.locator('input[type="file"]').setInputFiles(`${FX}/kaputt.jpg`);
await page.waitForTimeout(600);
ok(await page.getByRole("alert").filter({ hasText: /beschädigt|nicht geöffnet/ }).isVisible(), "Fehlermeldung bei defekter Datei");
// HEIC
await page.locator('input[type="file"]').setInputFiles(`${FX}/kind.heic`);
await page.waitForSelector(".upload-preview img", { timeout: 30000 }).catch(() => {});
ok(await page.locator(".upload-preview img").isVisible(), "HEIC wird konvertiert und angezeigt");
// ersetzen durch JPG
await page.locator('input[type="file"]').setInputFiles(`${FX}/kind.jpg`);
await page.waitForTimeout(800);
const exifFree = await page.evaluate(async () => {
  const src = document.querySelector(".upload-preview img").src;
  const buf = new Uint8Array(await (await fetch(src)).arrayBuffer());
  // JPEG ohne APP1/Exif-Segment?
  const s = String.fromCharCode(...buf.slice(0, 64));
  return buf[0] === 0xff && buf[1] === 0xd8 && !s.includes("Exif");
});
ok(exifFree, "Neu-kodiertes JPEG ohne EXIF");
await shot("kind-ok");
await next();

// Schritt 2: Teddy
await page.locator('input[type="file"]').setInputFiles(`${FX}/teddy.png`);
await page.waitForSelector(".upload-preview img");
await page.getByLabel(/Wie heißt das Kuscheltier/).fill("Fauli");
await shot("teddy");
await next();

// Schritt 3: Details – leer -> Fehler
await next();
ok(await page.getByText("Wie heißt dein Kind?").isVisible(), "Fehlermeldung Name");
ok(await page.getByText("Bitte wähle das Alter aus.").isVisible(), "Fehlermeldung Alter");
const focused = await page.evaluate(() => document.activeElement?.id);
ok(focused === "childName", "Fokus springt auf erstes fehlerhaftes Feld");
await shot("details-fehler");
await page.getByLabel("Name des Kindes").fill("Emma");
await page.getByLabel("Alter").selectOption("5");
await page.getByText("sie / ihr").click();
const fontSize = await page.evaluate(() => parseFloat(getComputedStyle(document.getElementById("childName")).fontSize));
ok(fontSize >= 16, `Input-Schriftgröße ≥ 16px (iOS-Zoom): ${fontSize}px`);
await shot("details-ok");

// Reload mitten im Formular -> Wiederherstellung
await page.waitForTimeout(600);
await page.reload({ waitUntil: "load" });
await page.evaluate(() => document.getElementById("buch-erstellen").scrollIntoView());
await page.waitForTimeout(900);
ok((await page.getByLabel("Name des Kindes").inputValue()) === "Emma", "Nach Reload: Name wiederhergestellt");
// zurück zu Schritt 1: Foto muss aus IndexedDB wiederhergestellt sein
await page.getByRole("button", { name: "Zurück" }).click();
await page.getByRole("button", { name: "Zurück" }).click();
await page.waitForTimeout(400);
ok(await page.locator(".upload-preview img").isVisible(), "Nach Reload: Kinderfoto wiederhergestellt (IndexedDB)");
await next();
await next();
ok((await page.getByLabel("Name des Kindes").inputValue()) === "Emma", "Vor/Zurück behält Eingaben");
await next();

// Schritt 4: Interessen
await next();
ok(await page.getByText(/Wähle mindestens ein Interesse/).isVisible(), "Fehlermeldung Interessen");
await page.getByRole("button", { name: /Magie/ }).click();
await page.getByRole("button", { name: /Tiere/ }).click();
ok((await page.getByRole("button", { name: /Magie/ }).getAttribute("aria-pressed")) === "true", "Chip aria-pressed");
await page.getByRole("button", { name: /Eigene Idee/ }).click();
await page.locator("input[placeholder^='z. B. Bagger']").fill("Schaukeln");
await shot("interessen");
await next();

// Schritt 5: Story (Tastatur: Inspiration)
await page.getByRole("button", { name: "Geheime Tür" }).click();
const story = await page.locator("textarea").inputValue();
ok(story.startsWith("Emma und Fauli"), `Inspiration personalisiert: "${story.slice(0, 40)}…"`);
await shot("story");
await next();

// Schritt 6: Prüfen + Einwilligung
ok(await page.getByText("Fast geschafft!").isVisible(), "Zusammenfassung sichtbar");
await page.getByRole("button", { name: /Mein Kinderbuch starten/ }).click();
ok(await page.getByText(/Bitte bestätige die Einwilligung/).isVisible(), "Einwilligung erforderlich");
await shot("review-fehler");
await page.locator(".consent-box").check();
await page.getByRole("button", { name: /Mein Kinderbuch starten/ }).click();
await page.waitForSelector("text=Geschichte beginnt", { timeout: 8000 }).catch(() => {});
ok(await page.getByText(/Emmas Geschichte beginnt/).isVisible(), "Erfolgszustand nach Absenden");
const left = await page.evaluate(() => localStorage.getItem("plh:draft:v1"));
ok(left === null, "Entwurf nach Absenden gelöscht");
await shot("erfolg");

console.log(logs.length ? `KONSOLE:\n${logs.join("\n")}` : "Konsole: keine Fehler/Warnungen");
await browser.close();
