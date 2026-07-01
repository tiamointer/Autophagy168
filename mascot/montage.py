#!/usr/bin/env python3
"""Assemble a labeled contact sheet of the squirrel states (+ silhouettes if present)."""
import os
from PIL import Image, ImageDraw

D = "/Users/laike/laike-projects/Autophagy168/mascot"
states = [("awake_v1.png", "清醒/进食待机"), ("fed_v1.png", "贴膘·进食"),
          ("digest_v1.png", "消化"), ("torpor_v1.png", "深度蛰眠"),
          ("arousal_v1.png", "唤醒·自噬")]
sils = [("sil_active.png", "剪影·活跃"), ("sil_curled.png", "剪影·蛰眠")]

cell, pad, labelh = 300, 16, 26
cols = len(states)
W = cols * cell + (cols + 1) * pad
rowh = cell + labelh
H = pad + rowh + pad + (rowh if any(os.path.exists(f"{D}/{f}") for f, _ in sils) else 0) + pad

sheet = Image.new("RGB", (W, H), (18, 15, 17))
draw = ImageDraw.Draw(sheet)

def place(fname, label, cx, cy, dark=False):
    p = f"{D}/{fname}"
    if not os.path.exists(p):
        return
    im = Image.open(p).convert("RGBA")
    im.thumbnail((cell, cell), Image.LANCZOS)
    bg = Image.new("RGBA", (cell, cell), (40, 40, 46, 255) if dark else (250, 250, 250, 255))
    bg.alpha_composite(im, ((cell - im.width) // 2, (cell - im.height) // 2))
    sheet.paste(bg.convert("RGB"), (cx, cy))
    draw.text((cx + 6, cy + cell + 5), label, fill=(220, 215, 210))

x = pad
for f, l in states:
    place(f, l, x, pad); x += cell + pad
# silhouettes row (on dark)
if any(os.path.exists(f"{D}/{f}") for f, _ in sils):
    y2 = pad + rowh + pad
    x = pad
    for f, l in sils:
        place(f, l, x, y2, dark=True); x += cell + pad

sheet.save(f"{D}/CONTACT_SHEET.png")
print("wrote CONTACT_SHEET.png", sheet.size)
