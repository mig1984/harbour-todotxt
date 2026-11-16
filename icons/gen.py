#!/usr/bin/env python3
"""Launcher icon: dark rounded square with a checked list."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = [86, 108, 128, 172]
SS = 4

def make(size):
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=(24, 36, 52, 255))
    w = int(s * 0.07)
    rows = [0.30, 0.50, 0.70]
    for i, y in enumerate(rows):
        cy = y * s
        bx = s * 0.20
        # checkbox
        d.rounded_rectangle([bx, cy - s*0.07, bx + s*0.14, cy + s*0.07], radius=int(s*0.02),
                            outline=(255, 255, 255, 255), width=int(s*0.03))
        if i < 2:
            d.line([(bx + s*0.03, cy), (bx + s*0.065, cy + s*0.04), (bx + s*0.12, cy - s*0.045)],
                   fill=(90, 200, 120, 255), width=int(s*0.03), joint="curve")
        # text line
        d.rounded_rectangle([s*0.42, cy - w/2, s*0.82 - (i*s*0.08), cy + w/2], radius=w//2,
                            fill=(255, 255, 255, 230 if i < 2 else 140))
    return img.resize((size, size), Image.LANCZOS)

for sz in SIZES:
    out = os.path.join(HERE, f"{sz}x{sz}")
    os.makedirs(out, exist_ok=True)
    make(sz).save(os.path.join(out, "harbour-todotxt.png"), optimize=True)
    print("wrote", sz)
