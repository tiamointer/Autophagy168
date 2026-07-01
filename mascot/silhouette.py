#!/usr/bin/env python3
"""Turn an isolated squirrel sprite (solid-ish background) into a clean single-color
silhouette + a transparent cutout, and emit small-size previews to check legibility
at Dynamic-Island / Always-On-Display sizes."""
import sys, os
from PIL import Image, ImageDraw, ImageFilter

src = sys.argv[1]
outdir = sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(src)
name = os.path.splitext(os.path.basename(src))[0]
TINT = (255, 255, 255)  # silhouette color (white; tint later in-app)

im = Image.open(src).convert("RGB")
w, h = im.size
flood = im.copy()
# eat the background + soft shadow from all four corners up to the squirrel's dark outline
seed_bg = (0, 0, 0)  # sentinel fill color marking "background"
for corner in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
    ImageDraw.floodfill(flood, corner, seed_bg, thresh=62)

# subject mask = pixels NOT turned into the sentinel
mask = Image.new("L", (w, h), 0)
mp = mask.load()
fp = flood.load()
for y in range(h):
    for x in range(w):
        mp[x, y] = 0 if fp[x, y] == seed_bg else 255

# clean up tiny specks
mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))

# transparent cutout (original colors)
cut = Image.new("RGBA", (w, h), (0, 0, 0, 0))
cut.paste(im, (0, 0), mask)
cut.save(os.path.join(outdir, f"{name}_cut.png"))

# solid silhouette on transparent
sil = Image.new("RGBA", (w, h), (0, 0, 0, 0))
solid = Image.new("RGBA", (w, h), TINT + (255,))
sil.paste(solid, (0, 0), mask)
# trim to bbox + pad
bbox = mask.getbbox()
if bbox:
    sil = sil.crop(bbox)
sil.save(os.path.join(outdir, f"{name}_sil.png"))

# small previews (on a dark card to mimic island/AOD)
for px in (44, 28):
    s = sil.copy()
    s.thumbnail((px, px), Image.LANCZOS)
    card = Image.new("RGBA", (px + 16, px + 16), (15, 12, 14, 255))
    card.alpha_composite(s, ((card.width - s.width) // 2, (card.height - s.height) // 2))
    card.save(os.path.join(outdir, f"{name}_sil_{px}.png"))

print(f"{name}: mask bbox={bbox}, wrote _cut/_sil/_sil44/_sil28")
