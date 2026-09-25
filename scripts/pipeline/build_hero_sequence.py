#!/usr/bin/env python3
"""
PlüschHeld – Hero-Sequenz-Pipeline
==================================

Erzeugt aus dem Transformationsvideo (reales Kind -> Auge -> Aquarell-Illustration)
eine scroll-steuerbare Bildsequenz plus Kamera-Manifest.

Warum nicht einfach das Video scrubben?
  * video.currentTime-Seeking stottert auf iOS/Android.
  * Die KI-generierte Kamerafahrt im Video hat ungleichmäßige Zoomgeschwindigkeit
    (gemessen: 0,5 %/Frame bis 6,7 %/Frame, abruptes Abbremsen bei ~Frame 180).

Was die Pipeline macht:
  1. Frames extrahieren (ffmpeg aus imageio-ffmpeg).
  2. Aufeinanderfolgende Frames registrieren (ORB+RANSAC und ECC, Auswahl per NCC).
     Ergebnis: Ähnlichkeitstransformation (Zoom, Rotation, Verschiebung) je Frame.
  3. Transformationen zu zwei "Welten" verketten:
        Welt 0 = Koordinaten von Frame 1 (Realbild, Zoom hinein)
        Welt 1 = Koordinaten des Endframes (Illustration, Zoom heraus)
  4. Zielauge (Pupille) im tiefsten Real- und ersten Aquarell-Frame detektieren und
     über die Kette in jeden Frame zurückverfolgen -> Augen-Anker je Frame.
  5. "Look-at"-Punkt je Frame = Mischung aus Bildkomposition und Auge
     (Gewicht wächst mit dem Zoom). Das ist der Anchor Point der virtuellen Kamera.
  6. Export je Gerätekategorie als WebP:
        p = Portrait-Band 9:16 (Phones),   f = Vollbild 3:4 (Tablets),
        l = Landscape-Band 1.43:1 (Desktop)
     Bänder sind entlang des Look-at-Pfads zugeschnitten -> kleinere Dateien.
  7. Manifest (src/content/heroSequence.json) für den Canvas-Renderer.

Aufruf:  npm run assets:hero      (benötigt: pip install -r scripts/pipeline/requirements.txt)
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC_VIDEO = ROOT / "assets-src/hero/transformation.mp4"
CACHE = ROOT / ".cache/hero"
OUT_DIR = ROOT / "public/media/hero"
MANIFEST = ROOT / "src/content/heroSequence.json"

SRC_W, SRC_H = 1248, 1664
ASPECT_H = SRC_H / SRC_W  # Frame-Höhe in "W-Einheiten" (x in [0,1], y in [0,1.3333])

END = 216          # ab 218 blendet das Video einen Papierrand ein -> nicht verwenden
K = 126            # Weltenwechsel (Mitte des Real->Aquarell-Crossfades 122..130)
SWAP = (122, 130)

# Bildkomposition (Weltkoordinaten, W-Einheiten), im QA-Prozess kalibriert:
#   Welt 0 / Frame 1: Gesicht + Faultier + Buchtitel
#   Welt 1 / Endframe: Gesicht + Faultier + leuchtende Schaukel
COMP = [(0.62, 0.607), (0.46, 0.533)]

# Export: jeder 2. Frame, im Crossfade jeder Frame
EXPORT = sorted(set(list(range(1, SWAP[0], 2)) + list(range(SWAP[0], SWAP[1] + 1)) + list(range(SWAP[1] + 2, END + 1, 2)) + [END]))

SETS = {
    # name: (Bandbreite, Bandhöhe) in W-Einheiten, Exportgröße
    "p": dict(bw=0.75, bh=ASPECT_H, out=(720, 1280)),
    "f": dict(bw=1.0, bh=ASPECT_H, out=(960, 1280)),
    "l": dict(bw=1.0, bh=0.70, out=(1248, 874)),
}
WEBP_QUALITY = 64


def ffmpeg_bin() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg  # type: ignore

    return imageio_ffmpeg.get_ffmpeg_exe()


def extract_frames() -> Path:
    d = CACHE / "frames"
    if d.exists() and len(list(d.glob("f*.png"))) >= END:
        return d
    d.mkdir(parents=True, exist_ok=True)
    subprocess.run([ffmpeg_bin(), "-loglevel", "error", "-y", "-i", str(SRC_VIDEO), str(d / "f%03d.png")], check=True)
    return d


def load_gray(frames: Path, i: int, sc: float) -> np.ndarray:
    im = cv2.imread(str(frames / f"f{i:03d}.png"), cv2.IMREAD_GRAYSCALE)
    return cv2.resize(im, (int(SRC_W * sc), int(SRC_H * sc)), interpolation=cv2.INTER_AREA).astype(np.float32)


def to_px(M: np.ndarray, sc: float) -> np.ndarray:
    P = np.array(M, dtype=np.float64).copy()
    P[:, 2] *= SRC_W * sc
    return P


def ncc_after_warp(a, b, M, sc) -> float:
    wa = cv2.warpAffine(a, to_px(M, sc), (b.shape[1], b.shape[0]), flags=cv2.INTER_LINEAR, borderValue=-1)
    h, w = b.shape
    A = wa[int(h * .15):int(h * .85), int(w * .15):int(w * .85)]
    B = b[int(h * .15):int(h * .85), int(w * .15):int(w * .85)]
    m = A >= 0
    A, B = A[m] - A[m].mean(), B[m] - B[m].mean()
    return float((A * B).sum() / math.sqrt((A * A).sum() * (B * B).sum() + 1e-9))


def register(frames: Path) -> list[np.ndarray]:
    """Liefert M_i (2x3), das normierte Koordinaten von Frame i auf Frame i+1 abbildet."""
    cache = CACHE / "registration.json"
    if cache.exists():
        data = json.loads(cache.read_text())
        if len(data) == END - 1:
            return [np.array(m) for m in data]
    orb = cv2.ORB_create(4000, scaleFactor=1.2, nlevels=8)
    bf = cv2.BFMatcher(cv2.NORM_HAMMING, crossCheck=True)
    out = []
    for i in range(1, END):
        a5, b5 = load_gray(frames, i, .5).astype(np.uint8), load_gray(frames, i + 1, .5).astype(np.uint8)
        cands = {"id": np.eye(2, 3)}
        ka, da = orb.detectAndCompute(a5, None)
        kb, db = orb.detectAndCompute(b5, None)
        if da is not None and db is not None:
            m = bf.match(da, db)
            if len(m) >= 12:
                pa = np.float32([ka[x.queryIdx].pt for x in m]) / (SRC_W * .5)
                pb = np.float32([kb[x.trainIdx].pt for x in m]) / (SRC_W * .5)
                M, _ = cv2.estimateAffinePartial2D(pa, pb, method=cv2.RANSAC, ransacReprojThreshold=0.003, maxIters=5000, confidence=0.999)
                if M is not None:
                    cands["orb"] = M
        sc = .35
        a, b = load_gray(frames, i, sc), load_gray(frames, i + 1, sc)
        try:
            P = to_px(cands.get("orb", np.eye(2, 3)), sc).astype(np.float32)
            _, P = cv2.findTransformECC(a, b, P, cv2.MOTION_AFFINE, (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-7), None, 5)
            Q = P.astype(np.float64)
            Q[:, 2] /= SRC_W * sc
            cands["ecc"] = Q  # volle Affine: bildet leichte Perspektive/Parallaxe besser ab
        except cv2.error:
            pass
        scores = {k: ncc_after_warp(a, b, v, sc) for k, v in cands.items()}
        best = max(scores, key=scores.get)
        out.append(cands[best])
        if i % 20 == 0:
            print(f"  registriert {i}/{END - 1}  best={best} ncc={scores[best]:.4f}")
    CACHE.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps([m.tolist() for m in out]))
    return out


def h3(M):
    return np.vstack([M, [0, 0, 1]])


def apply(M, p):
    v = M @ np.array([p[0], p[1], 1.0])
    return v[:2]


def detect_pupil(frames: Path, i: int) -> tuple[float, float]:
    im = cv2.imread(str(frames / f"f{i:03d}.png"), cv2.IMREAD_GRAYSCALE).astype(np.float32)
    h, w = im.shape
    y0, x0 = int(h * .25), int(w * .2)
    c = cv2.GaussianBlur(im[y0:int(h * .75), x0:int(w * .8)], (0, 0), 9)
    y, x = np.unravel_index(np.argmin(c), c.shape)
    m = (c < c.min() + 25).astype(np.uint8)
    _, lab, _, cen = cv2.connectedComponentsWithStats(m)
    cx, cy = cen[lab[y, x]]
    return (cx + x0) / SRC_W, (cy + y0) / SRC_W


def aff_params(M) -> list[float]:
    """2x3-Matrix Frame->Welt als [a, b, c, d, e, f] (Canvas-Konvention: x' = a*x + c*y + e, y' = b*x + d*y + f)."""
    return [round(float(v), 8) for v in (M[0, 0], M[1, 0], M[0, 1], M[1, 1], M[0, 2], M[1, 2])]


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def main() -> None:
    print("1/5 Frames extrahieren …")
    frames = extract_frames()
    print("2/5 Registrierung …")
    steps = [h3(m) for m in register(frames)]  # steps[i-1]: i -> i+1

    print("3/5 Welten verketten …")
    A = {1: np.eye(3)}
    for i in range(1, K):
        A[i + 1] = A[i] @ np.linalg.inv(steps[i - 1])
    B = {END: np.eye(3)}
    for i in range(END - 1, K - 1, -1):
        B[i] = B[i + 1] @ steps[i - 1]

    eyeA = apply(A[121], detect_pupil(frames, 121))
    eyeB = apply(B[130], detect_pupil(frames, 130))
    print(f"  Auge Welt0={eyeA.round(4)}  Welt1={eyeB.round(4)}")

    def world_of(i):
        return (A, eyeA, 0) if i <= K else (B, eyeB, 1)

    # Zoomfortschritt je Frame (0 = Weltbezug, 1 = maximal im Auge)
    zin = {i: math.log(1 / math.sqrt(abs(np.linalg.det(A[i][:2, :2])))) for i in range(1, K + 1)}
    zout = {i: math.log(1 / math.sqrt(abs(np.linalg.det(B[i][:2, :2])))) for i in range(K, END + 1)}
    zin_max, zout_max = max(zin.values()), max(zout.values())

    eye, look = {}, {}
    for i in range(1, END + 1):
        W, e_world, wi = world_of(i)
        inv = np.linalg.inv(W[i])
        e = apply(inv, e_world)
        comp = apply(inv, COMP[wi])
        z = zin[i] / zin_max if i <= K else zout[i] / zout_max
        wgt = smoothstep(0.02, 0.55, z)
        eye[i] = e
        look[i] = comp * (1 - wgt) + e * wgt

    print("4/5 Export …")
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    frames_meta = []
    total = {k: 0 for k in SETS}
    for i in EXPORT:
        src = Image.open(frames / f"f{i:03d}.png").convert("RGB")
        rects = {}
        for name, cfg in SETS.items():
            bw, bh = cfg["bw"], cfg["bh"]
            cx = min(max(look[i][0], bw / 2), 1 - bw / 2)
            cy = min(max(look[i][1], bh / 2), ASPECT_H - bh / 2)
            x0, y0 = cx - bw / 2, cy - bh / 2
            box = (round(x0 * SRC_W), round(y0 * SRC_W), round((x0 + bw) * SRC_W), round((y0 + bh) * SRC_W))
            # Exakte Pixelbox zurückrechnen (Rundung!) -> Manifest stimmt pixelgenau
            rects[name] = [round(box[0] / SRC_W, 6), round(box[1] / SRC_W, 6), round((box[2] - box[0]) / SRC_W, 6), round((box[3] - box[1]) / SRC_W, 6)]
            img = src.crop(box).resize(cfg["out"], Image.LANCZOS)
            d = OUT_DIR / name
            d.mkdir(parents=True, exist_ok=True)
            p = d / f"{i:03d}.webp"
            img.save(p, "WEBP", quality=WEBP_QUALITY, method=6)
            total[name] += p.stat().st_size
        frames_meta.append({"i": i, "r": {k: v for k, v in rects.items() if k != "f"}})
    for k, v in total.items():
        print(f"  Set {k}: {len(EXPORT)} Frames, {v / 1e6:.2f} MB")

    print("5/5 Manifest …")
    manifest = {
        "version": 2,
        "source": {"w": SRC_W, "h": SRC_H, "video": "assets-src/hero/transformation.mp4"},
        "end": END,
        "k": K,
        "swap": list(SWAP),
        "worlds": [
            {"from": 1, "to": K, "m": [aff_params(A[i]) for i in range(1, K + 1)]},
            {"from": K, "to": END, "m": [aff_params(B[i]) for i in range(K, END + 1)]},
        ],
        "eye": [[round(float(eye[i][0]), 5), round(float(eye[i][1]), 5)] for i in range(1, END + 1)],
        "look": [[round(float(look[i][0]), 5), round(float(look[i][1]), 5)] for i in range(1, END + 1)],
        "sets": {k: {"w": v["out"][0], "h": v["out"][1], "bw": round(v["bw"], 6), "bh": round(v["bh"], 6)} for k, v in SETS.items()},
        "frames": frames_meta,
        "path": "/media/hero/{set}/{i}.webp",
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(manifest, separators=(",", ":")))
    print(f"  {MANIFEST.relative_to(ROOT)} ({MANIFEST.stat().st_size / 1e3:.1f} kB)")


if __name__ == "__main__":
    sys.exit(main())
