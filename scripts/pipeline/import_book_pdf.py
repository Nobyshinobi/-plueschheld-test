#!/usr/bin/env python3
"""
Echte Buchseiten aus dem Kinderbuch-PDF importieren
===================================================

Ersetzt die Interim-Vorschauseiten (public/media/book/p0..p5) durch echte PDF-Seiten.
Die Website liest nur diese Dateinamen – es ist keine Code-Änderung nötig; lediglich
Alt-Texte/Seitentexte in src/content/book.ts sollten danach angepasst werden.

Beispiele:
  # 6 Einzelseiten (links/rechts im Wechsel): Innenumschlag, Titelseite, 2 Doppelseiten
  npm run book:import-pdf -- buch.pdf --pages 2,3,8,9,14,15

  # PDF enthält bereits Doppelseiten (Querformat) -> in linke/rechte Seite teilen
  npm run book:import-pdf -- buch.pdf --spreads 2,5,8 --split

Optionen:
  --pages   1-basierte Seitennummern (genau 6 Stück -> p0..p5)
  --spreads 1-basierte Nummern von Querformat-Doppelseiten (genau 3 Stück), mit --split
  --cover   Seitennummer des Covers (optional -> public/media/story/cover-real-*.webp)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pymupdf  # type: ignore
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "public/media/book"
WIDTHS = (1080, 720)
PAGE_ASPECT = 3 / 4  # Breite/Höhe einer Buchseite in der Website


def render(doc, n: int, target_w: int) -> Image.Image:
    page = doc[n - 1]
    zoom = target_w / page.rect.width * 1.25
    pix = page.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), alpha=False)
    return Image.frombytes("RGB", (pix.width, pix.height), pix.samples)


def fit(img: Image.Image) -> Image.Image:
    """Auf das Seitenformat 3:4 zuschneiden (zentriert), falls das PDF abweicht."""
    w, h = img.size
    if abs(w / h - PAGE_ASPECT) < 0.01:
        return img
    if w / h > PAGE_ASPECT:
        nw = round(h * PAGE_ASPECT)
        return img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    nh = round(w / PAGE_ASPECT)
    return img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))


def save(img: Image.Image, stem: str, out: Path = OUT) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for w in WIDTHS:
        h = round(img.height * w / img.width)
        img.resize((w, h), Image.LANCZOS).save(out / f"{stem}-{w}.webp", "WEBP", quality=82, method=6)
    print(f"  {stem}-{{{','.join(map(str, WIDTHS))}}}.webp")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("--pages", type=lambda s: [int(x) for x in s.split(",")])
    ap.add_argument("--spreads", type=lambda s: [int(x) for x in s.split(",")])
    ap.add_argument("--split", action="store_true")
    ap.add_argument("--cover", type=int)
    a = ap.parse_args()

    doc = pymupdf.open(a.pdf)
    print(f"{a.pdf}: {doc.page_count} Seiten")
    singles: list[Image.Image] = []
    if a.pages:
        if len(a.pages) != 6:
            print("--pages erwartet genau 6 Seiten (p0..p5)", file=sys.stderr)
            return 2
        singles = [fit(render(doc, n, 1080)) for n in a.pages]
    elif a.spreads and a.split:
        if len(a.spreads) != 3:
            print("--spreads erwartet genau 3 Doppelseiten", file=sys.stderr)
            return 2
        for n in a.spreads:
            img = render(doc, n, 2160)
            w, h = img.size
            singles += [fit(img.crop((0, 0, w // 2, h))), fit(img.crop((w // 2, 0, w, h)))]
    else:
        print("Bitte --pages oder --spreads … --split angeben.", file=sys.stderr)
        return 2

    for i, img in enumerate(singles):
        save(img, f"p{i}")
    if a.cover:
        save(fit(render(doc, a.cover, 1248)), "cover-real", ROOT / "public/media/story")
    print("Fertig. Bitte Alt-Texte in src/content/book.ts an die echten Seiten anpassen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
