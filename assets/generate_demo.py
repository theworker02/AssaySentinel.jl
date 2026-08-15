"""Generate AssaySentinel demo GIF and still screenshots.

Frames follow the real showcase_dataset() run (glucose, 1460 observations,
PELT/CUSUM, lot R21→R22→R23, CAL-08, combined SD 2.866, score 33.3).
The reconstruction chain is the pedagogical story scientists read first:
Stable → Calibration → Lot change → Drift.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

NAVY = (27, 40, 56, 255)
NAVY_DEEP = (22, 33, 46, 255)
TEAL = (47, 122, 120, 255)
AMBER = (201, 137, 42, 255)
CREAM = (244, 241, 234, 255)
CARD = (255, 252, 246, 255)
RULE = (216, 210, 196, 255)
GRAPHITE = (44, 51, 56, 255)
MUTED = (92, 101, 96, 255)
SOFT = (138, 145, 138, 255)
WINE = (139, 46, 46, 255)
CODEBG = (231, 226, 214, 255)

W, H = 880, 500
HERE = Path(__file__).resolve().parent


def fonts():
    def load(name, size):
        try:
            return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            return ImageFont.load_default()

    return {
        "title": load("segoeuib.ttf", 28),
        "h1": load("segoeuib.ttf", 22),
        "h2": load("segoeuib.ttf", 16),
        "body": load("segoeui.ttf", 14),
        "small": load("segoeui.ttf", 12),
        "tiny": load("segoeui.ttf", 11),
        "italic": load("segoeuii.ttf", 14),
        "mono": load("consola.ttf", 13),
        "mono_s": load("consola.ttf", 11),
        "serif": load("georgia.ttf", 14),
        "mark": load("segoeuib.ttf", 12),
    }


F = fonts()


def hexagon(cx, cy, r):
    pts = []
    for i in range(6):
        a = math.radians(-90 + i * 60)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_mark(draw, cx, cy, scale, dark=True):
    stroke = TEAL
    trace = CREAM if dark else NAVY
    for w in range(max(2, int(0.018 * scale))):
        draw.polygon(hexagon(cx, cy, 0.38 * scale - w), outline=stroke)
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
    dx = cx + 0.08 * scale
    dy = cy - 0.10 * scale
    rr = max(3, int(0.025 * scale))
    draw.ellipse((dx - rr, dy - rr, dx + rr, dy + rr), fill=AMBER)


def chrome(title: str, step: int, nsteps: int = 8) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (W, H), CREAM)
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, W, 56), fill=NAVY)
    draw_mark(draw, 34, 28, 42, dark=True)
    draw.text((62, 16), "AssaySentinel.jl", font=F["h2"], fill=CREAM)
    draw.text((240, 18), title, font=F["small"], fill=(197, 212, 211, 255))
    # step dots
    x0 = W - 28 - nsteps * 16
    for i in range(nsteps):
        r = 5
        cx = x0 + i * 16
        fill = AMBER if i == step else (TEAL if i < step else (80, 96, 110, 255))
        draw.ellipse((cx - r, 24 - r, cx + r, 24 + r), fill=fill)
    draw.rectangle((0, H - 28, W, H), fill=NAVY_DEEP)
    draw.text(
        (20, H - 22),
        "Research / analytical-quality / scientific decision support  ·  not a diagnostic medical device",
        font=F["tiny"],
        fill=(197, 212, 211, 255),
    )
    return img, draw


def card(draw, xywh, fill=CARD, outline=RULE):
    x, y, w, h = xywh
    draw.rounded_rectangle((x, y, x + w, y + h), radius=10, fill=fill, outline=outline)


def frame_title():
    img, draw = chrome("analyze → explain → report", 0)
    draw_mark(draw, W / 2, 168, 110, dark=False)
    draw.text((W / 2, 236), "AssaySentinel.jl", font=F["title"], fill=NAVY, anchor="ma")
    draw.text(
        (W / 2, 276),
        "Know when the measurement changed before the science does.",
        font=F["italic"],
        fill=TEAL,
        anchor="ma",
    )
    draw.text(
        (W / 2, 312),
        "A year of glucose controls  ·  three lots  ·  two instruments  ·  one reconstruction",
        font=F["small"],
        fill=MUTED,
        anchor="ma",
    )
    draw.rounded_rectangle((210, 348, 670, 392), radius=8, fill=CODEBG)
    draw.text(
        (W / 2, 370),
        "showcase_dataset()  →  analyze()  →  explain()  →  report()",
        font=F["mono_s"],
        fill=NAVY,
        anchor="ma",
    )
    return img


def frame_ingest():
    img, draw = chrome("01  Ingest a measurement history", 1)
    card(draw, (24, 76, 420, 380))
    draw.text((44, 92), "What the laboratory drops in", font=F["h2"], fill=NAVY)
    rows = [
        ("Analyte", "glucose  (mg/dL)"),
        ("Span", "12 months  ·  n = 1,460"),
        ("Instruments", "Analyzer-A, Analyzer-B"),
        ("Reagent lots", "R21 → R22 → R23"),
        ("Calibration", "CAL-07, then CAL-08"),
        ("Controls", "every 8th observation"),
        ("Uncertainty", "u = 0.4 mg/dL on each point"),
        ("Policy", "NaN omitted, never zero-filled"),
    ]
    y = 132
    for k, v in rows:
        draw.text((44, y), k, font=F["small"], fill=MUTED)
        draw.text((200, y), v, font=F["body"], fill=NAVY)
        y += 34
    card(draw, (460, 76, 396, 380), fill=NAVY)
    draw.text((480, 92), "History arriving", font=F["h2"], fill=CREAM)
    draw.text((480, 122), "Scientists keep the process metadata.", font=F["small"], fill=(197, 212, 211, 255))
    rng = random.Random(14)
    xs, ys = [], []
    for i in range(120):
        mu = 100.0
        if i > 40:
            mu += 1.2
        if 58 <= i < 64:
            mu -= 0.8
        if i > 80:
            mu += 2.0 + 0.035 * (i - 80)
        xs.append(i)
        ys.append(mu + rng.gauss(0, 2.0))
    plot_box = (492, 168, 828, 410)
    _sparkline(draw, xs, ys, plot_box, line=AMBER, fill_under=True)
    draw.text((480, 424), "lot   cal   lot   drift", font=F["tiny"], fill=SOFT)
    return img


def _sparkline(draw, xs, ys, box, line=NAVY, fill_under=False):
    x0, y0, x1, y1 = box
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys) - 1, max(ys) + 1
    pts = []
    for x, y in zip(xs, ys):
        px = x0 + (x - xmin) / (xmax - xmin) * (x1 - x0)
        py = y1 - (y - ymin) / (ymax - ymin) * (y1 - y0)
        pts.append((px, py))
    if fill_under and len(pts) >= 2:
        poly = [(pts[0][0], y1)] + pts + [(pts[-1][0], y1)]
        draw.polygon(poly, fill=(47, 122, 120, 40))
    if len(pts) >= 2:
        draw.line(pts, fill=line, width=2)


def frame_detect():
    img, draw = chrome("02  analyze() — explainable detectors", 2)
    draw.text((28, 76), "Did the measurement process change?", font=F["h1"], fill=NAVY)
    draw.text(
        (28, 108),
        "Each detector states what it saw. :auto explains why a method was chosen.",
        font=F["serif"],
        fill=MUTED,
    )
    chips = [
        ("CUSUM", "33 decision-interval crossings", TEAL, CREAM),
        ("PELT", "4 mean-level segments  ·  MBIC 21.86", TEAL, CREAM),
        ("Distribution", "KS D = 0.362  ·  Wasserstein 2.24", NAVY, CREAM),
        ("Westgard QC", "1-3s, 1-2s, 2-2s, 4-1s, 10x", NAVY, CREAM),
        ("Calibration", "CAL-08 recorded at 2025-11", AMBER, NAVY),
        ("Lots", "R21 → R22 → R23  ·  KW H = 339", AMBER, NAVY),
    ]
    for i, (name, detail, bg, fg) in enumerate(chips):
        col, row = i % 2, i // 2
        x = 28 + col * 420
        y = 150 + row * 96
        card(draw, (x, y, 404, 84), fill=bg)
        draw.text((x + 20, y + 16), name, font=F["h2"], fill=fg)
        draw.text((x + 20, y + 48), detail, font=F["small"], fill=fg)
    return img


def frame_story():
    img, draw = chrome("03  Reconstruction story", 3)
    draw.text((28, 76), "The dated analytical story", font=F["h1"], fill=NAVY)
    draw.text(
        (28, 108),
        "Temporal association with operational events is not causation.",
        font=F["serif"],
        fill=MUTED,
    )
    beats = [
        ("Stable", TEAL, CREAM),
        ("Calibration", NAVY, CREAM),
        ("Lot change", NAVY, CREAM),
        ("Drift", AMBER, NAVY),
    ]
    x = 28
    for i, (label, bg, fg) in enumerate(beats):
        card(draw, (x, 160, 176, 72), fill=bg)
        draw.text((x + 88, 196), label, font=F["h2"], fill=fg, anchor="mm")
        if i < 3:
            draw.text((x + 188, 196), "→", font=F["h1"], fill=AMBER, anchor="mm")
        x += 212
    card(draw, (28, 260, 824, 196))
    draw.text((48, 276), "Status", font=F["tiny"], fill=MUTED)
    draw.text((48, 296), "DRIFT SUSPECTED", font=F["h2"], fill=AMBER)
    rows = [
        ("Change point", "2025-11-30T12:00:00"),
        ("Direction", "+36.2% distributional shift (KS D = 0.362)"),
        ("Associated event", "reagent lot change  ·  score 0.99  ·  not causation"),
        ("Sentinel Score", "33.3 / 100  (analytical stability, not patient risk)"),
        ("Fingerprint", "2124c5404968faa1   rng_seed=430270780018012308"),
    ]
    y = 332
    for k, v in rows:
        draw.text((48, y), k, font=F["tiny"], fill=MUTED)
        draw.text((200, y), v, font=F["small"], fill=NAVY)
        y += 22
    return img


def frame_uncertainty():
    img, draw = chrome("04  Uncertainty budget", 4)
    draw.text((28, 76), "Every reconstruction carries an uncertainty budget", font=F["h1"], fill=NAVY)
    draw.text(
        (28, 108),
        "Combined SD = √(analytical² + RMS(u)²). Magnitude has a standard error.",
        font=F["serif"],
        fill=MUTED,
    )
    headers = ("Quantity", "Value")
    rows = [
        ("n with uncertainty", "1,460 / 1,460"),
        ("RMS(u)", "0.40 mg/dL"),
        ("Analytical SD", "2.838 mg/dL"),
        ("Combined SD", "2.866 mg/dL"),
        ("Weighted mean", "101.66 mg/dL"),
        ("Magnitude SE", "0.075"),
    ]
    card(draw, (28, 148, 520, 288))
    draw.rectangle((28, 148, 548, 186), fill=TEAL)
    draw.text((48, 158), headers[0], font=F["h2"], fill=CREAM)
    draw.text((320, 158), headers[1], font=F["h2"], fill=CREAM)
    y = 200
    for i, (k, v) in enumerate(rows):
        if i % 2 == 0:
            draw.rectangle((28, y - 8, 548, y + 28), fill=CODEBG)
        draw.text((48, y), k, font=F["body"], fill=NAVY)
        draw.text((320, y), v, font=F["mono"], fill=NAVY)
        y += 36
    card(draw, (568, 148, 284, 288), fill=NAVY)
    draw.text((588, 172), "What this is", font=F["h2"], fill=CREAM)
    for i, line in enumerate((
        "Measurement uncertainty",
        "stays attached to the",
        "series. The score is an",
        "analytical-stability index,",
        "not a clinical risk grade.",
        "",
        "Outliers are annotated.",
        "They are not deleted",
        "unless you ask.",
    )):
        draw.text((588, 214 + i * 22), line, font=F["small"], fill=(197, 212, 211, 255))
    return img


def _series():
    rng = random.Random(20260814)
    xs, ys = [], []
    for i in range(180):
        mu, sig = 100.0, 2.0
        if i >= 58:
            mu += 1.2
        if 88 <= i < 94:
            mu -= 0.8
        if i >= 120:
            mu += 2.0 + 0.045 * (i - 120)
            sig = 3.4
        v = mu + rng.gauss(0, sig)
        if i in (136, 137, 160):
            v = mu + 3.6 * sig
        xs.append(i)
        ys.append(v)
    return xs, ys


def frame_chart():
    img, draw = chrome("05  Control chart", 5)
    draw.text((28, 72), "Levey–Jennings view of the same history", font=F["h1"], fill=NAVY)
    xs, ys = _series()
    box = (56, 130, 840, 400)
    x0, y0, x1, y1 = box
    mu = sum(ys) / len(ys)
    var = sum((y - mu) ** 2 for y in ys) / (len(ys) - 1)
    sig = math.sqrt(var)
    ymin, ymax = mu - 3.4 * sig, mu + 3.4 * sig
    draw.rounded_rectangle((24, 112, 856, 430), radius=10, fill=CARD, outline=RULE)

    def mapx(x):
        return x0 + x / (len(xs) - 1) * (x1 - x0)

    def mapy(y):
        return y1 - (y - ymin) / (ymax - ymin) * (y1 - y0)

    guides = [
        (mu + 3 * sig, WINE, (4, 3), 1),
        (mu + 2 * sig, AMBER, (3, 3), 1),
        (mu + 1 * sig, TEAL, (2, 2), 1),
        (mu, NAVY, None, 2),
        (mu - 1 * sig, TEAL, (2, 2), 1),
        (mu - 2 * sig, AMBER, (3, 3), 1),
        (mu - 3 * sig, WINE, (4, 3), 1),
    ]
    for y, col, dash, width in guides:
        yy = mapy(y)
        if dash:
            _dashed(draw, x0, yy, x1, yy, col, dash, width)
        else:
            draw.line((x0, yy, x1, yy), fill=col, width=width)
    events = [(58, "lot"), (88, "cal"), (120, "lot")]
    for xi, label in events:
        xx = mapx(xi)
        _dashed(draw, xx, y0, xx, y1, TEAL, (3, 2), 1)
        draw.text((xx + 4, y0 + 4), label, font=F["tiny"], fill=TEAL)
    pts = [(mapx(x), mapy(y)) for x, y in zip(xs, ys)]
    draw.line(pts, fill=NAVY, width=2)
    draw.text((36, 118), "Control chart  ·  glucose mg/dL  ·  ±1 / 2 / 3 SD", font=F["tiny"], fill=MUTED)
    return img


def _dashed(draw, x0, y0, x1, y1, color, dash, width):
    on, off = dash
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1
    ux, uy = dx / length, dy / length
    pos = 0.0
    draw_on = True
    while pos < length:
        step = on if draw_on else off
        nxt = min(pos + step, length)
        if draw_on:
            draw.line(
                (x0 + ux * pos, y0 + uy * pos, x0 + ux * nxt, y0 + uy * nxt),
                fill=color,
                width=width,
            )
        pos = nxt
        draw_on = not draw_on


def frame_report():
    img, draw = chrome("06  HTML analytical report", 6)
    # report page
    card(draw, (40, 76, 800, 380), fill=CARD)
    draw.text((64, 92), "AssaySentinel analytical report", font=F["h1"], fill=NAVY)
    draw.rectangle((64, 128, 68, 176), fill=AMBER)
    draw.text((80, 132), "This software is intended for research, analytical-quality", font=F["serif"], fill=GRAPHITE)
    draw.text((80, 152), "assessment, and scientific decision support. It is not a", font=F["serif"], fill=GRAPHITE)
    draw.text((80, 172), "diagnostic medical device.", font=F["serif"], fill=GRAPHITE)
    headers = ("Field", "Value")
    rows = [
        ("Analyte", "glucose"),
        ("Unit", "mg/dL"),
        ("Status", "DRIFT SUSPECTED"),
        ("Sentinel Score", "33.3"),
        ("n", "1460"),
        ("Package", "AssaySentinel.jl 1.3.0"),
    ]
    draw.rectangle((64, 196, 816, 228), fill=TEAL)
    draw.text((80, 204), headers[0], font=F["small"], fill=CREAM)
    draw.text((280, 204), headers[1], font=F["small"], fill=CREAM)
    y = 236
    for i, (k, v) in enumerate(rows):
        if i % 2 == 0:
            draw.rectangle((64, y - 4, 816, y + 24), fill=CODEBG)
        draw.text((80, y), k, font=F["small"], fill=NAVY)
        color = AMBER if k == "Status" else NAVY
        draw.text((280, y), v, font=F["small"], fill=color)
        y += 28
    return img


def frame_provenance():
    img, draw = chrome("07  Provenance-complete", 7)
    draw.text((28, 76), "Every step is recorded and fingerprintable", font=F["h1"], fill=NAVY)
    steps = [
        ("1  ingest → analyze", "[observed]", "Raw measurements ingested. Missing/NaN omitted."),
        ("2  outliers → detect_outliers", "[statistical]", "13 outliers annotated with MAD, not removed."),
        ("3  changepoint → detect_changes", "[algorithmic]", "CUSUM crossings selected PELT for mean segments."),
        ("4  drift → detect_drift", "[algorithmic]", "Auto compared linear, sudden, variance, distribution."),
        ("5  reconstruct → reconstruct", "[algorithmic]", "Ordered story, uncertainty budget, and charts."),
    ]
    y = 118
    for title, kind, note in steps:
        card(draw, (28, y, 824, 52), fill=NAVY)
        draw.text((48, y + 8), title, font=F["mono_s"], fill=CREAM)
        draw.text((420, y + 8), kind, font=F["tiny"], fill=AMBER)
        draw.text((48, y + 28), note, font=F["tiny"], fill=(197, 212, 211, 255))
        y += 60
    draw.text((28, 430), "fingerprint=2124c5404968faa1    package v1.3.0", font=F["mono_s"], fill=MUTED)
    return img


def to_gif_frames(images):
    base = images[0].convert("RGB").quantize(colors=64, method=Image.Quantize.MEDIANCUT)
    out = [base]
    for im in images[1:]:
        out.append(im.convert("RGB").quantize(palette=base))
    return out


def main():
    frames = [
        frame_title(),
        frame_ingest(),
        frame_detect(),
        frame_story(),
        frame_uncertainty(),
        frame_chart(),
        frame_report(),
        frame_provenance(),
    ]
    stills = {
        "screenshot-reconstruction.png": frames[3],
        "screenshot-control-chart.png": frames[5],
        "screenshot-report.png": frames[6],
    }
    for name, im in stills.items():
        path = HERE / name
        im.convert("RGB").save(path, "PNG")
        print("wrote", path)

    gif_path = HERE / "demo.gif"
    gif_frames = to_gif_frames(frames)
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=1800,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print("wrote", gif_path, "bytes", gif_path.stat().st_size)


if __name__ == "__main__":
    main()
