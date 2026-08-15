"""Generate raster brand assets from the AssaySentinel geometry."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

NAVY = (27, 40, 56, 255)
TEAL = (47, 122, 120, 255)
AMBER = (201, 137, 42, 255)
CREAM = (244, 241, 234, 255)
GRAPHITE = (44, 51, 56, 255)

HERE = Path(__file__).resolve().parent


def hexagon(cx, cy, r):
    pts = []
    for i in range(6):
        a = math.radians(-90 + i * 60)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_mark(draw: ImageDraw.ImageDraw, cx, cy, scale, dark=True):
    stroke = TEAL
    trace = CREAM if dark else NAVY
    draw.polygon(hexagon(cx, cy, 0.38 * scale), outline=stroke)
    # thicker hex via extra outlines
    for w in range(max(2, int(0.018 * scale))):
        draw.polygon(hexagon(cx, cy, 0.38 * scale - w), outline=stroke)
    # waveform
    pts = []
    for i in range(0, 101):
        t = i / 100
        x = cx - 0.46 * scale + t * 0.92 * scale
        if t < 0.42:
            y = cy + 0.10 * scale
        elif t < 0.62:
            u = (t - 0.42) / 0.20
            y = cy + 0.10 * scale - (0.22 * scale) * (u * u)
        else:
            u = (t - 0.62) / 0.38
            y = cy - 0.12 * scale - 0.10 * scale * u
        pts.append((x, y))
    draw.line(pts, fill=trace, width=max(2, int(0.02 * scale)))
    # amber detect
    dx = cx + 0.08 * scale
    dy = cy - 0.10 * scale
    rr = max(3, int(0.025 * scale))
    draw.ellipse((dx - rr, dy - rr, dx + rr, dy + rr), fill=AMBER)


def icon(size: int, path: Path, dark=True):
    img = Image.new("RGBA", (size, size), NAVY if dark else CREAM)
    draw = ImageDraw.Draw(img)
    # rounded rect already via background; mark centered
    draw_mark(draw, size / 2, size / 2, size, dark=dark)
    img.save(path)


def social(path: Path):
    w, h = 1280, 640
    img = Image.new("RGBA", (w, h), NAVY)
    draw = ImageDraw.Draw(img)
    # subtle left panel
    draw.rectangle((0, 0, 430, h), fill=(22, 33, 46, 255))
    draw_mark(draw, 215, 320, 340, dark=True)
    try:
        title = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 54)
        italic = ImageFont.truetype("C:/Windows/Fonts/segoeuii.ttf", 28)
        small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
    except OSError:
        title = italic = small = ImageFont.load_default()
    x = 500
    draw.text((x, 200), "AssaySentinel.jl", font=title, fill=CREAM)
    draw.text((x, 280), "Know when the measurement changed", font=italic, fill=TEAL)
    draw.text((x, 320), "before the science does.", font=italic, fill=TEAL)
    draw.text((x, 400), "Scientific assay drift & quality intelligence", font=small, fill=(168, 178, 184, 255))
    draw.text((x, 430), "for Julia.", font=small, fill=(168, 178, 184, 255))
    draw.rectangle((x, 470, x + 80, 474), fill=AMBER)
    img.convert("RGB").save(path, "PNG")


def main():
    icon(256, HERE / "icon-256.png")
    icon(512, HERE / "icon-512.png")
    icon(256, HERE / "icon.png")
    social(HERE / "social-preview.png")
    print("wrote", HERE / "icon-256.png")
    print("wrote", HERE / "icon-512.png")
    print("wrote", HERE / "icon.png")
    print("wrote", HERE / "social-preview.png")


if __name__ == "__main__":
    main()
