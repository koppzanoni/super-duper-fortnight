"""The "Aço" look (2026-10-25): crafted but modern and subtle steel. Graphite brushed plates with
silver edges, a bevel that gives them thickness, an engraved line inside the panels, small corner
brackets and rivets, a machined plate on top of the portrait ring. No blue.

It redraws modern_art's pieces with the same geometry (so everything stays on the screen grid):
the pieces call modern_art.backing/groove/ring, which are swapped for the steel ones while drawing.
Its pieces are also the moulds Meshy redraws with real metal (tools/meshy_gen.py, pieces steel_*).

Usage: python tools/steel_art.py OUT_DIR   (writes the steel pieces as PNG)
"""
import math
import pathlib
import random
import sys
from contextlib import contextmanager

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import modern_art as ma
from modern_art import SS, Canvas

PANEL = (22, 23, 26, 244)       # graphite plate
RIM = (30, 31, 35, 252)         # the bars' rim band
EDGE = (120, 124, 132, 240)     # the silver edge line
LIT = (232, 234, 238, 200)      # light along top edges
RING = (150, 154, 162, 255)
RING_FILL = (26, 27, 31, 255)
RING_LIT = (240, 242, 246, 230)
RING_INNER = (58, 60, 66, 255)
SLOT = (128, 132, 140, 255)
METAL = (150, 154, 162, 255)    # brackets, rivets, plates
SHINE = (245, 246, 250, 230)


def _mask(box, r):
    x0, y0, x1, y1 = [round(v * SS) for v in box]
    m = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, m.width - 1, m.height - 1), r * SS, fill=255)
    return (x0, y0), m


def sheen(c, box, r, strength=20):
    """A soft light across the top half of a plate."""
    at, m = _mask(box, r)
    ramp = Image.new("L", (1, m.height))
    for y in range(m.height):
        ramp.putpixel((0, y), round(strength * max(0.0, 1 - y / max(1, m.height - 1) / 0.5)))
    light = Image.new("RGBA", m.size, (255, 255, 255, 0))
    light.putalpha(ImageChops.multiply(m, ramp.resize(m.size)))
    c.layers["body"].alpha_composite(light, at)


def brushed(c, box, r, strength=26, seed=7):
    """Brushed steel: fine horizontal streaks of light and dark, clipped to a plate."""
    rnd = random.Random(seed)
    at, m = _mask(box, r)
    streak = Image.new("L", (1, m.height), 128)
    for y in range(m.height):
        streak.putpixel((0, y), max(0, min(255, round(128 + rnd.gauss(0, 34)))))
    streak = streak.resize(m.size).filter(ImageFilter.GaussianBlur(radius=0.6 * SS))
    for color, part in (((0, 0, 0), lambda v: max(0, 128 - v)), ((255, 255, 255), lambda v: max(0, v - 128))):
        layer = Image.new("RGBA", m.size, color + (0,))
        layer.putalpha(ImageChops.multiply(m, streak.point(lambda v: part(v) * strength // 64)))
        c.layers["body"].alpha_composite(layer, at)


def bevel(c, box, r, w=1.4):
    """Plate thickness: a light line along the top inside edge, a dark one along the bottom."""
    x0, y0, x1, y1 = box
    c.line([(x0 + r * 0.7, y0 + w), (x1 - r * 0.7, y0 + w)], (255, 255, 255, 70), w, layer="top")
    c.line([(x0 + r * 0.7, y1 - w), (x1 - r * 0.7, y1 - w)], (0, 0, 0, 150), w, layer="top")


def etch(c, box, r, inset=6):
    """An engraved line inside a plate's edge: a dark cut with a fine light lip under it."""
    x0, y0, x1, y1 = box
    b = (x0 + inset, y0 + inset, x1 - inset, y1 - inset)
    rr = max(1, r - inset)
    c.rrect(b, rr, outline=(0, 0, 0, 120), width=1.0, layer="top")
    c.rrect((b[0] + 0.8, b[1] + 0.8, b[2] + 0.8, b[3] + 0.8), rr, outline=(255, 255, 255, 26), width=0.8, layer="top")


def rivet(c, x, y, s=2.2):
    c.ellipse((x - s - 0.6, y - s - 0.6, x + s + 0.6, y + s + 0.6), fill=(0, 0, 0, 200), layer="top")
    c.ellipse((x - s, y - s, x + s, y + s), fill=METAL, layer="top")
    c.ellipse((x - s * 0.5, y - s * 0.7, x + s * 0.2, y - s * 0.1), fill=SHINE, layer="top")


def bracket(c, x, y, sx, sy, k=14, t=3.2):
    """An L-shaped corner fitting with a rivet: (x, y) the corner, sx/sy the inward directions."""
    def ell(o, i):
        return [(x + sx * o, y + sy * o), (x + sx * (k - o), y + sy * o), (x + sx * (k - o), y + sy * (t - i)),
                (x + sx * (t - i), y + sy * (t - i)), (x + sx * (t - i), y + sy * (k - o)), (x + sx * o, y + sy * (k - o))]
    c.poly(ell(0, 0), (0, 0, 0, 180), layer="top")
    c.poly(ell(0.8, 0.4), METAL, layer="top")
    rivet(c, x + sx * (t + 3.2), y + sy * (t + 3.2), 1.7)


def keystone(c, cx, y, w=40, h=10):
    """A small machined plate seated on an edge (the top of the portrait ring)."""
    pts = [(cx - w / 2, y), (cx + w / 2, y), (cx + w / 2 - h * 0.7, y + h), (cx - w / 2 + h * 0.7, y + h)]
    c.poly([(p[0], p[1] - 1) for p in pts], (0, 0, 0, 200), layer="top")
    c.poly(pts, (128, 132, 140, 255), layer="top")
    c.line([(cx - w / 2 + 2, y + 1.2), (cx + w / 2 - 2, y + 1.2)], (240, 242, 246, 220), 1.0, layer="top")
    rivet(c, cx, y + h / 2, 1.6)


# ------------------------------------------------------------------ the pieces' parts in steel
def backing(c, box, r=20):
    x0, y0, x1, y1 = box
    c.rrect(box, r, fill=PANEL, layer="body")
    sheen(c, box, r)
    brushed(c, box, r)
    c.rrect(box, r, outline=EDGE, width=1.3)
    c.line([(x0 + r + 2, y0 + 1.2), (x1 - r - 2, y0 + 1.2)], LIT, 1.0, layer="top")
    bevel(c, box, r)
    if (x1 - x0) > 120 and (y1 - y0) > 40:  # big plates only: on small ones the details turn to noise
        etch(c, box, r)
        for x, sx in ((x0 + 2, 1), (x1 - 2, -1)):
            for y, sy in ((y0 + 2, 1), (y1 - 2, -1)):
                bracket(c, x, y, sx, sy)


def groove(c, box, r=8, rim=7):
    x0, y0, x1, y1 = box
    outer = (x0 - rim, y0 - rim, x1 + rim, y1 + rim)
    c.rrect(outer, r + rim, fill=RIM, layer="body")
    brushed(c, outer, r + rim, seed=3)
    c.rrect(outer, r + rim, outline=EDGE, width=1.3)
    c.rrect((x0 - 1.5, y0 - 1.5, x1 + 1.5, y1 + 1.5), r + 1.5, outline=(0, 0, 0, 255), width=1.6, layer="body")
    c.rrect(box, r, fill=(2, 2, 3, 255), layer="body")
    c.line([(x0 + 16, y0 - rim + 1.2), (x1 - 16, y0 - rim + 1.2)], LIT, 1.0, layer="top")
    bevel(c, outer, r + rim, w=1.1)
    if (y1 - y0) > 20:  # a rivet at each end of a tall rim
        for x in (x0 - rim / 2, x1 + rim / 2):
            rivet(c, x, (y0 + y1) / 2, 1.5)


def ring(c, box, band=12):
    x0, y0, x1, y1 = box
    c.ellipse(box, fill=RING_FILL, layer="body")
    c.ellipse(box, outline=RING, width=2.2)
    c.draw("top").arc(c.s((x0 + 1, y0 + 1, x1 - 1, y1 - 1)), 196, 344, fill=RING_LIT, width=round(1.4 * SS))
    c.ellipse((x0 + band - 3, y0 + band - 3, x1 - band + 3, y1 - band + 3), outline=RING_INNER, width=2.0, layer="top")
    c.ellipse((x0 + band, y0 + band, x1 - band, y1 - band), fill=(0, 0, 0, 255), layer="top")
    if (x1 - x0) > 120:  # the portrait and map rings, not the small buttons
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        keystone(c, cx, y0 - 3)
        c.ellipse((x0 + band / 2, y0 + band / 2, x1 - band / 2, y1 - band / 2), outline=(0, 0, 0, 110), width=1.0, layer="top")
        rr = (x1 - x0) / 2 - band / 2
        for a in (205, 335):
            rivet(c, cx + rr * math.cos(math.radians(a)), cy + rr * math.sin(math.radians(a)), 1.8)


def slot_frame():
    n = ma.SLOT_TEX
    c = Canvas(n, n)
    b = (6, 6, n - 6, n - 6)
    c.rrect(b, 9, fill=RIM, layer="body")
    c.rrect((b[0] - 1.4, b[1] - 1.4, b[2] + 1.4, b[3] + 1.4), 10, outline=(0, 0, 0, 255), width=1.6, layer="body")
    c.rrect(b, 9, outline=SLOT, width=1.8)
    c.line([(b[0] + 11, b[1] + 0.8), (b[2] - 11, b[1] + 0.8)], LIT, 1.0, layer="top")
    bevel(c, b, 9, w=1.6)
    for x, y in ((b[0] + 5, b[1] + 5), (b[2] - 5, b[1] + 5), (b[0] + 5, b[3] - 5), (b[2] - 5, b[3] - 5)):
        rivet(c, x, y, 1.6)
    c.cut((b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4), 6)
    return c.render(glow=0.05, shadow=0.6)


@contextmanager
def steel():
    """modern_art's pieces drawn in steel while inside the block."""
    saved = ma.backing, ma.groove, ma.ring
    ma.backing, ma.groove, ma.ring = backing, groove, ring
    try:
        yield
    finally:
        ma.backing, ma.groove, ma.ring = saved


def pieces():
    """Every HUD piece in steel, by texture name."""
    with steel():
        return {"mod_unit": ma.unit_frame(), "mod_unit_small": ma.unit_frame(level=False), "mod_cast": ma.cast_bar(),
                "mod_map": ma.minimap_ring(), "mod_menu": ma.menu_band(), "mod_slot": slot_frame()}


def main():
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, img in pieces().items():
        img.save(out / f"{name}.png")


if __name__ == "__main__":
    main()
