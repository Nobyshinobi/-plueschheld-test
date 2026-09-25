#!/usr/bin/env python3
"""Kontaktabzug aus QA-Screenshots: python3 scripts/qa/sheet.py <dir> <out.jpg> [cols] [thumbW]"""
import sys, glob
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 6
tw = int(sys.argv[4]) if len(sys.argv) > 4 else 260
fs = sorted(glob.glob(d + "/*.png"))
ims = []
for f in fs:
    im = Image.open(f).convert("RGB")
    th = round(im.height * tw / im.width)
    ims.append((f.split("/")[-1][:-4], im.resize((tw, th), Image.LANCZOS)))
th = max(i.height for _, i in ims)
rows = (len(ims) + cols - 1) // cols
S = Image.new("RGB", (cols * tw, rows * (th + 18)), "white")
dr = ImageDraw.Draw(S)
for k, (n, im) in enumerate(ims):
    x, y = (k % cols) * tw, (k // cols) * (th + 18)
    S.paste(im, (x, y + 18)); dr.text((x + 4, y + 3), n, fill="black")
S.save(out, quality=86)
print(out, S.size)
