#!/usr/bin/env python3
"""Generate the Autophagy168 app icon: a glowing orange->pink fasting ring with a
centered flame, on a warm dark background. Outputs a 1024x1024 PNG."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

S = 1024
OUT = sys.argv[1] if len(sys.argv) > 1 else "icon-1024.png"

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def grad(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]; t1, c1 = stops[i + 1]
        if t0 <= t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0))
    return stops[-1][1]

# --- background: warm dark radial vignette ---
img = Image.new("RGBA", (S, S), (0, 0, 0, 255))
d = ImageDraw.Draw(img)
cx = cy = S / 2
bg = [(0.0, (40, 26, 22)), (0.55, (24, 16, 18)), (1.0, (9, 7, 8))]
maxr = S * 0.72
steps = 256
for i in range(steps, 0, -1):
    r = maxr * i / steps
    c = grad(bg, i / steps) + (255,)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)

# --- ring (drawn on its own layer, then a blurred copy for glow) ---
ring_stops = [(0.0, (255, 176, 32)), (0.5, (255, 90, 24)), (1.0, (255, 61, 119))]
R = S * 0.34          # ring radius
W = int(S * 0.092)    # ring thickness
bbox = [cx - R, cy - R, cx + R, cy + R]
start_deg, sweep = -90, 292   # leave a gap at the bottom

ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
rd = ImageDraw.Draw(ring)
segs = 300
for i in range(segs):
    a0 = start_deg + sweep * i / segs
    a1 = start_deg + sweep * (i + 1) / segs
    col = grad(ring_stops, i / segs) + (255,)
    rd.arc(bbox, a0, a1 + 0.6, fill=col, width=W)
# rounded caps
for ang, t in [(start_deg, 0.0), (start_deg + sweep, 1.0)]:
    px = cx + R * math.cos(math.radians(ang)); py = cy + R * math.sin(math.radians(ang))
    col = grad(ring_stops, t) + (255,)
    rd.ellipse([px - W/2, py - W/2, px + W/2, py + W/2], fill=col)

glow = ring.filter(ImageFilter.GaussianBlur(34))
img.alpha_composite(glow)       # soft glow under
img.alpha_composite(glow)
img.alpha_composite(ring)

# --- flame in the center, filled with a vertical gradient ---
fw, fh = S * 0.30, S * 0.40
fx, fy = cx, cy + S * 0.03
pts = []
N = 60
for i in range(N + 1):                 # right side down
    t = i / N
    y = fy - fh/2 + fh * t
    w = (math.sin(t * math.pi) ** 0.8) * (fw/2) * (0.35 + 0.65 * t)
    pts.append((fx + w, y))
for i in range(N + 1):                 # left side up, with a tip
    t = 1 - i / N
    y = fy - fh/2 + fh * t
    w = (math.sin(t * math.pi) ** 0.8) * (fw/2) * (0.35 + 0.65 * t)
    pts.append((fx - w, y))
# pointed top
top = (fx, fy - fh * 0.62)

mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).polygon([top] + pts, fill=255)

flame_stops = [(0.0, (255, 224, 138)), (0.45, (255, 138, 28)), (1.0, (255, 61, 119))]
fgrad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fp = fgrad.load()
y0, y1 = int(fy - fh * 0.62), int(fy + fh/2)
for y in range(y0, y1 + 1):
    c = grad(flame_stops, (y - y0) / max(1, (y1 - y0))) + (255,)
    for x in range(S):
        fp[x, y] = c
flame = Image.new("RGBA", (S, S), (0, 0, 0, 0))
flame.paste(fgrad, (0, 0), mask)
img.alpha_composite(flame.filter(ImageFilter.GaussianBlur(2)))

os.makedirs(os.path.dirname(OUT), exist_ok=True) if os.path.dirname(OUT) else None
img.convert("RGB").save(OUT)
print("wrote", OUT, img.size)
