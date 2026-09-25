#!/usr/bin/env python3
"""
PlüschHeld – statische Bild-Derivate
====================================

Quellen (unverändert in assets-src/):
  brand/logo-original.png          Logo auf Navy (vom Auftraggeber)
  hero/transformation.mp4          Transformationsvideo (Frames 142, 188, 216)
  hero/illustration-loop.mp4       Illustrierte Fensterszene (Frame 1)

Ausgaben:
  public/brand/*.webp              Wortmarke/Lockup freigestellt (Gold, Navy, Creme)
  src/app/icon.png, apple-icon.png Herz aus dem Logo
  public/media/story/cover-art-*   Endframe der Transformation = Buchcover-Motiv
  assets-src/book/illu-*.png       Illustrationen für den Buchseiten-Renderer
  public/og.jpg                    Social-Preview 1200x630

Aufruf: npm run assets:images
"""
from __future__ import annotations

import subprocess
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets-src"
PUB = ROOT / "public"
FRAMES = ROOT / ".cache/hero/frames"  # von build_hero_sequence.py erzeugt

NAVY_BG = np.array([3, 19, 44], np.float32)  # gemessener Logo-Hintergrund #03132C
INK = (14, 33, 64)       # --color-ink
CREAM = (255, 248, 238)  # --color-cream


def ffmpeg_bin() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg  # type: ignore

    return imageio_ffmpeg.get_ffmpeg_exe()


def frame(i: int) -> Image.Image:
    p = FRAMES / f"f{i:03d}.png"
    if not p.exists():
        raise SystemExit("Bitte zuerst `npm run assets:hero` ausführen (extrahiert die Frames).")
    return Image.open(p).convert("RGB")


def save_webp(img: Image.Image, path: Path, q: int = 80, widths: list[int] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if widths is None:
        img.save(path, "WEBP", quality=q, method=6)
        return
    for w in widths:
        h = round(img.height * w / img.width)
        img.resize((w, h), Image.LANCZOS).save(path.with_name(f"{path.stem}-{w}.webp"), "WEBP", quality=q, method=6)


def save_avif(img: Image.Image, path: Path, q: int = 55, widths: list[int] | None = None) -> None:
    try:
        for w in widths or [img.width]:
            h = round(img.height * w / img.width)
            img.resize((w, h), Image.LANCZOS).save(path.with_name(f"{path.stem}-{w}.avif"), "AVIF", quality=q)
    except (KeyError, OSError) as e:  # Pillow ohne AVIF-Encoder
        print(f"  (AVIF übersprungen: {e})")


# ---------------------------------------------------------------- Logo
def logo() -> None:
    im = np.array(Image.open(SRC / "brand/logo-original.png").convert("RGB")).astype(np.float32)
    d = np.sqrt(((im - NAVY_BG) ** 2).sum(axis=2))

    def alpha(lo, hi):
        a = np.clip((d - lo) / (hi - lo), 0, 1)
        return a * a * (3 - 2 * a)

    # Farbe "un-premultiplizieren", damit der Goldverlauf erhalten bleibt
    aa = np.clip(d / 330.0, 1e-3, 1)[..., None]
    gold = np.clip(NAVY_BG + (im - NAVY_BG) / aa, 0, 255)
    soft, crisp = alpha(90, 300), alpha(150, 290)
    box = (slice(440, 772), slice(140, 1135))

    def export(name, A, color, with_sub):
        A = A.copy()
        if not with_sub:
            A[700:, 240:] = 0  # Unterzeile "Personalisierte Kinderbücher" entfernen
        C = gold if color is None else np.broadcast_to(np.array(color, np.float32), gold.shape)
        rgba = np.dstack([C, A * 255]).astype(np.uint8)[box]
        img = Image.fromarray(rgba, "RGBA")
        bb = img.getbbox()
        img = img.crop(bb)
        img.save(PUB / "brand" / f"{name}.webp", "WEBP", quality=90, method=6)
        print(f"  brand/{name}.webp {img.size}")

    (PUB / "brand").mkdir(parents=True, exist_ok=True)
    export("wordmark-gold", soft, None, False)
    export("wordmark-ink", crisp, INK, False)
    export("wordmark-cream", crisp, CREAM, False)
    export("lockup-gold", soft, None, True)
    export("lockup-ink", crisp, INK, True)

    # App-Icon: Herz aus der Wortmarke, Gold auf Navy
    heart_rgba = np.dstack([gold, soft * 255]).astype(np.uint8)[450:700, 880:1130]
    heart = Image.fromarray(heart_rgba, "RGBA")
    heart = heart.crop(heart.getbbox())
    for size, name in [(512, "icon.png"), (180, "apple-icon.png")]:
        canvas = Image.new("RGBA", (size, size), (11, 29, 54, 255))
        s = int(size * 0.62)
        h = heart.resize((s, round(heart.height * s / heart.width)), Image.LANCZOS)
        canvas.alpha_composite(h, ((size - h.width) // 2, (size - h.height) // 2 + size // 40))
        canvas.convert("RGB").save(ROOT / "src/app" / name, optimize=True)
    print("  src/app/icon.png, apple-icon.png")


# ---------------------------------------------------------------- Story / Buch
def story() -> None:
    cover = frame(216)  # Endframe der Transformation (vor dem Papierrand)
    out = PUB / "media/story/cover-art.webp"
    save_webp(cover, out, q=78, widths=[640, 960, 1248])
    save_avif(cover, out, q=55, widths=[640, 960])
    print("  media/story/cover-art-{640,960,1248}.webp")

    book = SRC / "book"
    book.mkdir(parents=True, exist_ok=True)
    frame(188).save(book / "illu-closeup.png")
    tmp = ROOT / ".cache/illu-loop-f001.png"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg_bin(), "-loglevel", "error", "-y", "-i", str(SRC / "hero/illustration-loop.mp4"), "-frames:v", "1", str(tmp)], check=True)
    Image.open(tmp).convert("RGB").save(book / "illu-window.png")
    print("  assets-src/book/illu-{closeup,window}.png")


def og() -> None:
    base = frame(1)
    W, H = base.size
    # Landscape-Ausschnitt um Gesicht + Buchtitel
    crop_h = round(W * 630 / 1200)
    y0 = round(0.607 * W - crop_h / 2)
    img = base.crop((0, y0, W, y0 + crop_h)).resize((1200, 630), Image.LANCZOS)
    grad = Image.new("L", (1200, 630))
    gd = ImageDraw.Draw(grad)
    for x in range(1200):
        gd.line([(x, 0), (x, 630)], fill=int(max(0, 1 - x / 700) ** 1.6 * 225))
    shade = Image.new("RGB", (1200, 630), (8, 20, 40))
    img = Image.composite(shade, img, grad)
    mark = Image.open(PUB / "brand/lockup-gold.webp").convert("RGBA")
    w = 470
    mark = mark.resize((w, round(mark.height * w / mark.width)), Image.LANCZOS)
    img = img.convert("RGBA")
    img.alpha_composite(mark, (64, 630 // 2 - mark.height // 2))
    img.convert("RGB").save(PUB / "og.jpg", quality=86, optimize=True, progressive=True)
    print("  og.jpg")


if __name__ == "__main__":
    logo()
    story()
    og()
