#!/usr/bin/env node
/**
 * PlüschHeld – Buchseiten-Renderer (Interim-Vorschauseiten)
 * =========================================================
 *
 * WICHTIG: Das Kinderbuch-PDF lag den Projektdateien nicht bei. Diese Seiten werden
 * deshalb aus dem echten Bildmaterial des Buches "Emma und die leuchtende Schaukel"
 * (Illustrationen aus dem Transformationsvideo, Titel + Rückseitentext vom echten Cover)
 * gesetzt. Sobald das PDF vorliegt:
 *
 *     npm run book:import-pdf -- pfad/zum/buch.pdf --pages 1,2,5,6,9,10
 *
 * Das Import-Skript rendert die echten Seiten in dieselben Dateinamen
 * (public/media/book/pN-{720,1080}.webp); die Website muss nicht angepasst werden.
 *
 * Aufruf: npm run assets:book
 */
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const OUT_TMP = resolve(ROOT, ".cache/book");
const OUT = resolve(ROOT, "public/media/book");
mkdirSync(OUT_TMP, { recursive: true });
mkdirSync(OUT, { recursive: true });

const url = (p) => pathToFileURL(resolve(ROOT, p)).href;
const CHROME = process.env.CHROME_PATH || ["/opt/pw-browsers/chromium-1194/chrome-linux/chrome"].find(existsSync);

const base = /* css */ `
@font-face { font-family: Fraunces; src: url(${url("src/fonts/fraunces-soft.woff2")}) format("woff2"); font-weight: 100 900; }
@font-face { font-family: Fraunces; src: url(${url("src/fonts/fraunces-soft-italic.woff2")}) format("woff2"); font-weight: 100 900; font-style: italic; }
@font-face { font-family: Figtree; src: url(${url("src/fonts/figtree.woff2")}) format("woff2"); font-weight: 300 900; }
* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 540px; height: 720px; overflow: hidden; }
body { font-family: Fraunces, serif; font-variation-settings: "SOFT" 100; color: #1b2a44; -webkit-font-smoothing: antialiased; }
.page { position: relative; width: 540px; height: 720px; overflow: hidden; background: #fbf5ea; }
.page.paper::before { content: ""; position: absolute; inset: 0; opacity: .55; mix-blend-mode: multiply; pointer-events: none;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='300' height='300'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='3' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 .55  0 0 0 0 .45  0 0 0 0 .32  0 0 0 .09 0'/></filter><rect width='300' height='300' filter='url(%23n)'/></svg>"); }
.page.paper::after { content: ""; position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(120% 90% at 50% 45%, transparent 60%, rgba(150,110,60,.10) 100%); }
.folio { position: absolute; bottom: 30px; left: 0; right: 0; text-align: center; font: 500 13px/1 Figtree, sans-serif; letter-spacing: .12em; color: #9a8466; }
.star { color: #c9a45a; }
.body { position: absolute; left: 62px; right: 62px; font-size: 21px; line-height: 1.62; font-weight: 380; letter-spacing: .002em; hyphens: auto; }
.body p + p { margin-top: .85em; }
.drop::first-letter { float: left; font-size: 78px; line-height: .82; font-weight: 620; color: #10264a; padding: 7px 10px 0 0; }
.epigraph { font-style: italic; font-size: 22px; line-height: 1.45; text-align: center; color: #6b5a42; }
.orn { display: flex; align-items: center; justify-content: center; gap: 12px; color: #c9a45a; font-size: 15px; }
.orn::before, .orn::after { content: ""; width: 58px; height: 1px; background: linear-gradient(90deg, transparent, #cfb074, transparent); }
`;

const pages = [
  {
    id: "p0",
    html: /* html */ `
<div class="page" style="background:#10264a">
  <svg width="540" height="720" style="position:absolute;inset:0">
    <defs>
      <pattern id="s" width="90" height="90" patternUnits="userSpaceOnUse" patternTransform="rotate(8)">
        <path d="M18 14l2.2 5 5.3.4-4 3.4 1.3 5.2-4.8-2.8-4.6 2.8 1.2-5.2-4-3.4 5.3-.4z" fill="#d6b36a" opacity=".55"/>
        <circle cx="62" cy="58" r="1.6" fill="#f3e2b8" opacity=".7"/>
        <circle cx="40" cy="76" r="1" fill="#f3e2b8" opacity=".5"/>
        <path d="M70 20a8 8 0 1 0 6 13 6.5 6.5 0 1 1-6-13z" fill="#d6b36a" opacity=".4"/>
      </pattern>
      <radialGradient id="g" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#1c3a66"/><stop offset="1" stop-color="#0b1d36"/></radialGradient>
    </defs>
    <rect width="540" height="720" fill="url(#g)"/>
    <rect width="540" height="720" fill="url(#s)"/>
  </svg>
  <div style="position:absolute;left:78px;right:78px;top:218px;height:284px;background:#fbf5ea;border-radius:18px;box-shadow:0 18px 40px rgba(0,0,0,.35);display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">
    <div style="position:absolute;inset:10px;border:1.5px solid #cfb074;border-radius:12px"></div>
    <div style="position:absolute;inset:15px;border:1px solid rgba(207,176,116,.55);border-radius:9px"></div>
    <div style="font:600 13px/1 Figtree,sans-serif;letter-spacing:.28em;text-transform:uppercase;color:#9a8466">Dieses Buch gehört</div>
    <div style="font-style:italic;font-weight:560;font-size:84px;line-height:1.05;color:#10264a;margin:14px 0 6px">Emma</div>
    <div class="orn">♥</div>
    <div style="font-size:17px;font-style:italic;color:#6b5a42;margin-top:14px">Geschrieben für ein ganz besonderes Kind.</div>
  </div>
</div>`,
  },
  {
    id: "p1",
    html: /* html */ `
<div class="page paper" style="text-align:center">
  <div class="orn" style="position:absolute;top:70px;left:0;right:0">✦</div>
  <div style="position:absolute;top:112px;left:0;right:0">
    <div style="font-weight:700;font-size:104px;line-height:.95;color:#10264a;letter-spacing:-.01em">Emma</div>
    <div style="font-style:italic;font-weight:420;font-size:33px;line-height:1.25;color:#8a6a2e;margin-top:10px">und die leuchtende Schaukel</div>
  </div>
  <div style="position:absolute;left:50%;top:318px;width:250px;height:250px;margin-left:-125px;border-radius:50%;overflow:hidden;
      -webkit-mask-image:radial-gradient(circle at 50% 50%, #000 62%, transparent 71%)">
    <img src="${url(".cache/hero/frames/f216.png")}" style="position:absolute;width:820px;left:-488px;top:-300px" />
  </div>
  <div style="position:absolute;bottom:70px;left:0;right:0">
    <div class="epigraph" style="font-size:18px">Eine Geschichte über Mut, Freundschaft<br/>und ein kleines bisschen Magie</div>
    <div style="font:600 12px/1 Figtree,sans-serif;letter-spacing:.3em;text-transform:uppercase;color:#9a8466;margin-top:22px">PlüschHeld</div>
  </div>
</div>`,
  },
  {
    id: "p2",
    html: /* html */ `
<div class="page paper">
  <div style="position:absolute;top:66px;left:0;right:0">
    <p class="epigraph">„Manchmal beginnt die größte Magie<br/>mit einem kleinen Traum …“</p>
    <div class="orn" style="margin-top:18px">✦</div>
  </div>
  <div class="body" style="top:230px">
    <p class="drop">An diesem Abend konnte Emma einfach nicht einschlafen. Sie drückte ihr Faultier ganz fest an sich – ihren allerbesten Freund, der sie überallhin begleitete.</p>
    <p>Draußen im Garten raschelte es. Leise. Geheimnisvoll. Und irgendwo zwischen den Blättern blitzte ein goldenes Funkeln auf.</p>
  </div>
  <div class="folio">4</div>
</div>`,
  },
  {
    id: "p3",
    html: /* html */ `
<div class="page">
  <img src="${url("assets-src/book/illu-closeup.png")}" style="position:absolute;inset:0;width:540px;height:720px;object-fit:cover" />
</div>`,
  },
  {
    id: "p4",
    html: /* html */ `
<div class="page paper">
  <div class="body" style="top:84px">
    <p class="drop">Emma schlich zum Fenster und schob den Vorhang zur Seite. Unter dem alten Baum hing die Schaukel, auf der sie jeden Nachmittag spielte.</p>
    <p>Doch heute Nacht war alles anders: Die Seile glitzerten wie Sternenstaub, und das Holz leuchtete, als hätte jemand den Mond darin versteckt.</p>
    <p>„Siehst du das?“, flüsterte Emma. Ihr Faultier sagte kein Wort. Aber Emma war ganz sicher, dass es lächelte.</p>
  </div>
  <div class="orn" style="position:absolute;bottom:82px;left:0;right:0">☾</div>
  <div class="folio">6</div>
</div>`,
  },
  {
    id: "p5",
    html: /* html */ `
<div class="page paper" style="text-align:center">
  <img src="${url("assets-src/book/illu-window.png")}" style="position:absolute;left:30px;top:34px;width:480px;height:480px" />
  <p class="epigraph" style="position:absolute;left:58px;right:58px;top:548px;font-size:21px;color:#1b2a44">
    Heute Nacht, das spürte Emma ganz genau,<br/>würde ein Abenteuer beginnen.
  </p>
  <div class="folio">7</div>
</div>`,
  },
];

const browser = await chromium.launch({ executablePath: CHROME });
const ctx = await browser.newContext({ viewport: { width: 540, height: 720 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
for (const p of pages) {
  // Als Datei laden (nicht setContent): about:blank darf keine file://-Ressourcen nachladen
  const htmlFile = resolve(OUT_TMP, `${p.id}.html`);
  writeFileSync(htmlFile, `<!doctype html><html lang="de"><head><meta charset="utf-8"><style>${base}</style></head><body>${p.html}</body></html>`);
  await page.goto(pathToFileURL(htmlFile).href, { waitUntil: "load" });
  await page.evaluate(() => document.fonts.ready);
  const broken = await page.evaluate(() => [...document.images].filter((i) => !i.naturalWidth).map((i) => i.src));
  if (broken.length) throw new Error(`Bild nicht geladen: ${broken.join(", ")}`);
  const png = resolve(OUT_TMP, `${p.id}.png`);
  await page.screenshot({ path: png });
  console.log(`  ${p.id}.png`);
}
await browser.close();

// PNG -> WebP (1080 / 720 px Breite)
execFileSync("python3", [
  "-c",
  `
from PIL import Image
import sys
for pid in sys.argv[1:]:
    im = Image.open('${OUT_TMP}/' + pid + '.png').convert('RGB')
    for w in (1080, 720):
        h = round(im.height * w / im.width)
        im.resize((w, h), Image.LANCZOS).save('${OUT}/' + pid + '-' + str(w) + '.webp', 'WEBP', quality=82, method=6)
    print('  ' + pid + '-{1080,720}.webp')
`,
  ...pages.map((p) => p.id),
], { stdio: "inherit" });
