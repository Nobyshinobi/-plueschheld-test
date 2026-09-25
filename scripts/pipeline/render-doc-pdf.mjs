#!/usr/bin/env node
/** Markdown-Dokument -> PDF im Stil des Produktionshandbuchs.  node scripts/pipeline/render-doc-pdf.mjs <in.md> <out.pdf> */
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
const [inp, out] = process.argv.slice(2);
const body = execFileSync("python3", ["-c", "import sys,markdown;print(markdown.markdown(open(sys.argv[1],encoding='utf-8').read(),extensions=['tables','fenced_code']))", inp]).toString();
const font = (f) => pathToFileURL(resolve(f)).href;
const html = `<!doctype html><html lang="de"><head><meta charset="utf-8"><style>
@font-face{font-family:Fraunces;src:url(${font("src/fonts/fraunces-soft.woff2")});font-weight:100 900}
@font-face{font-family:Figtree;src:url(${font("src/fonts/figtree.woff2")});font-weight:300 900}
@page{size:A4;margin:22mm 18mm 20mm}
body{font-family:Figtree,sans-serif;color:#1b2a44;font-size:10.5pt;line-height:1.55}
h1{font-family:Fraunces;font-variation-settings:"SOFT" 100;font-weight:600;color:#10264a;font-size:24pt;line-height:1.15;border-bottom:3px solid #ef6a67;padding-bottom:10px}
h2{font-family:Fraunces;font-variation-settings:"SOFT" 100;font-weight:600;color:#10264a;font-size:15pt;margin-top:22px;break-after:avoid}
p{margin:6px 0 10px}strong{color:#10264a}em{color:#4a5670}
code{font-size:9pt;background:#f3eadb;padding:1px 4px;border-radius:4px}
table{border-collapse:collapse;width:100%;font-size:9.5pt;margin:8px 0 14px;break-inside:avoid}
th,td{border:1px solid #e0d2b8;padding:6px 8px;text-align:left;vertical-align:top}th{background:#10264a;color:#fff8ee}
hr{border:0;border-top:1px solid #e0d2b8;margin:16px 0}ol li{margin:3px 0}
</style></head><body>${body}</body></html>`;
const tmp = resolve(".cache/doc.html");
writeFileSync(tmp, html);
const CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome";
const browser = await chromium.launch({ executablePath: existsSync(CHROME) ? CHROME : undefined });
const page = await browser.newPage();
await page.goto(pathToFileURL(tmp).href, { waitUntil: "load" });
await page.evaluate(() => document.fonts.ready);
await page.pdf({ path: out, format: "A4", printBackground: true, displayHeaderFooter: true,
  headerTemplate: '<div style="font:7pt sans-serif;color:#9a8466;width:100%;text-align:right;padding-right:18mm">PLÜSCHHELD · SCROLL EXPERIENCE · BIBLE v1.1 NACHTRAG</div>',
  footerTemplate: '<div style="font:7pt sans-serif;color:#9a8466;width:100%;text-align:center"><span class="pageNumber"></span></div>',
  margin: { top: "22mm", bottom: "20mm", left: "18mm", right: "18mm" } });
await browser.close();
console.log(out);
