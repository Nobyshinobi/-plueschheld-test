#!/usr/bin/env node
/**
 * Führt die komplette QA-Suite gegen eine laufende Instanz aus (bevorzugt Production: next build && next start).
 *   QA_URL=http://localhost:3000 npm run qa
 * Voraussetzung: Chromium unter /opt/pw-browsers (oder CHROME_PATH), Python 3 mit Pillow; Testbilder in .cache/fixtures
 * (werden bei Bedarf aus dem Transformationsvideo erzeugt: npm run assets:hero).
 */
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";

const url = process.env.QA_URL || "http://localhost:3000";
if (!existsSync(".cache/fixtures/kind.jpg")) {
  mkdirSync(".cache/fixtures", { recursive: true });
  spawnSync("python3", ["-c", `
from PIL import Image
im=Image.open('.cache/hero/frames/f001.png').convert('RGB'); W,H=im.size
im.crop((int(.3*W),int(.12*H),int(.75*W),int(.55*H))).save('.cache/fixtures/kind.jpg',quality=90)
im.crop((int(.62*W),int(.34*H),int(.98*W),int(.66*H))).save('.cache/fixtures/teddy.png')
open('.cache/fixtures/kaputt.jpg','wb').write(b'not an image'*200)
try:
    import pillow_heif; pillow_heif.register_heif_opener()
    Image.open('.cache/fixtures/kind.jpg').save('.cache/fixtures/kind.heic', format='HEIF', quality=80)
except Exception as e: print('HEIC-Testbild übersprungen:', e)
`], { stdio: "inherit" });
}
const suites = [
  ["interactions", ["scripts/qa/interactions.mjs", "--url", url]],
  ["configurator (mobile)", ["scripts/qa/configurator.mjs", "--url", url, "--vp", "390x844", "--out", "qa-artifacts/config-390"]],
  ["configurator (desktop)", ["scripts/qa/configurator.mjs", "--url", url, "--vp", "1440x900", "--out", "qa-artifacts/config-1440"]],
  ["keyboard", ["scripts/qa/keyboard.mjs", url]],
  ["fontshift", ["scripts/qa/fontshift.mjs", url + "/"]],
  ["handoff", ["scripts/qa/handoff.mjs", url]],
  ["perf (mobile)", ["scripts/qa/perf.mjs", "--url", url, "--vp", "390x844"]],
];
let failed = 0;
for (const [name, args] of suites) {
  console.log(`\n### ${name}`);
  const r = spawnSync("node", args, { stdio: "inherit" });
  if (r.status !== 0) failed++;
}
console.log(failed ? `\n${failed} Suite(s) mit Fehlern` : "\nAlle Suiten grün");
process.exit(failed ? 1 : 0);
