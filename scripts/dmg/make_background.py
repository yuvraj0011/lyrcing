#!/usr/bin/env python3
"""Draws the DMG installer background (660x400 pt, plus a 2x retina version). Needs Pillow."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
S = 2                       # retina scale
W, H = 660 * S, 400 * S
random.seed(7)

def font(size, bold=False):
    for path, idx in (("/System/Library/Fonts/Avenir Next.ttc", 1 if bold else 0), ("/System/Library/Fonts/Helvetica.ttc", 1 if bold else 0)):
        try: return ImageFont.truetype(path, size, index=idx)
        except Exception: pass
    return ImageFont.load_default()

# vertical gradient
img = Image.new("RGB", (W, H))
px = img.load()
top, bottom = (10, 10, 26), (24, 14, 52)
for y in range(H):
    t = y / H
    row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    for x in range(W): px[x, y] = row

# soft color glows
glow = Image.new("RGB", (W, H), (0, 0, 0))
g = ImageDraw.Draw(glow)
for (cx, cy, r, col) in ((200, 120, 330, (96, 70, 220)), (1120, 700, 380, (30, 150, 170)), (660, 40, 300, (190, 70, 150))):
    g.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.blend(img, Image.composite(glow, img, glow.convert("L").point(lambda v: min(255, v * 2))), 0.55)

d = ImageDraw.Draw(img, "RGBA")

def star(cx, cy, r, color):
    k = r * 0.22
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else k
        pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
    d.polygon(pts, fill=color)

# faint constellation lines + stars
nodes = [(70, 60), (150, 110), (110, 190), (60, 270), (590, 70), (520, 130), (600, 210), (560, 320), (330, 384), (250, 372)]
nodes = [(x * S, y * S) for x, y in nodes]
for a, b in ((0, 1), (1, 2), (2, 3), (4, 5), (5, 6), (6, 7), (8, 9)):
    d.line([nodes[a], nodes[b]], fill=(255, 255, 255, 34), width=S)
for i, (x, y) in enumerate(nodes):
    star(x, y, (4 + (i % 3) * 2) * S, (255, 255, 255, 150))
for _ in range(90):
    x, y, r = random.randint(0, W), random.randint(0, H), random.choice((1, 1, 2))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, random.randint(40, 140)))

def centered(text, y, f, fill):
    w = d.textlength(text, font=f)
    d.text(((W - w) / 2, y), text, font=f, fill=fill)

centered("Lyrcing", 28 * S, font(46 * S, True), (255, 255, 255, 255))
centered("Your music, as a living constellation.", 92 * S, font(15 * S), (200, 200, 230, 220))

# light plates behind the icon labels: Finder always draws those labels in black
for cx in (170, 490):
    d.rounded_rectangle(((cx - 66) * S, 265 * S, (cx + 66) * S, 291 * S), radius=13 * S, fill=(255, 255, 255, 232))

# arrow between the two icons (icon centres at x=170 and x=490, y=200)
ax0, ax1, ay = 262 * S, 398 * S, 200 * S
for i in range(0, ax1 - ax0 - 14 * S, 14 * S):
    d.rounded_rectangle((ax0 + i, ay - S, ax0 + i + 8 * S, ay + S), radius=S, fill=(255, 255, 255, 200))
d.polygon([(ax1, ay), (ax1 - 15 * S, ay - 11 * S), (ax1 - 15 * S, ay + 11 * S)], fill=(255, 255, 255, 230))

centered("Drag Lyrcing into your Applications folder", 338 * S, font(14 * S), (220, 220, 245, 235))

img.save(os.path.join(OUT, "background@2x.png"))
img.resize((660, 400), Image.LANCZOS).save(os.path.join(OUT, "background.png"))
print("wrote background.png and background@2x.png")
