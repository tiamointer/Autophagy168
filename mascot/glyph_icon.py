#!/usr/bin/env python3
"""Turn a dark-silhouette-on-white glyph into a clean transparent, single-tint icon
(dark pixels -> opaque tint, light pixels -> transparent, so interior negative space
like the eye / face lines is preserved). Emits small previews on a dark card."""
import sys, os
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
TINT = (245, 245, 248)

im = Image.open(src).convert("RGB")
im.thumbnail((512, 512), Image.LANCZOS)
w, h = im.size
ip = im.load()
ic = Image.new("RGBA", (w, h), (0, 0, 0, 0))
oc = ic.load()
for y in range(h):
    for x in range(w):
        r, g, b = ip[x, y]
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        if lum < 120:                       # dark squirrel body
            oc[x, y] = TINT + (255,)
        elif lum < 180:                     # soft edge -> partial alpha for anti-alias
            oc[x, y] = TINT + (int((180 - lum) / 60 * 255),)

bbox = ic.getbbox()
if bbox:
    ic = ic.crop(bbox)
ic.save(out)

base = os.path.splitext(out)[0]
for px in (44, 28):
    s = ic.copy()
    s.thumbnail((px, px), Image.LANCZOS)
    card = Image.new("RGBA", (px + 16, px + 16), (15, 12, 14, 255))
    card.alpha_composite(s, ((card.width - s.width) // 2, (card.height - s.height) // 2))
    card.save(f"{base}_{px}.png")
print(f"{os.path.basename(out)}: icon bbox={bbox}")
