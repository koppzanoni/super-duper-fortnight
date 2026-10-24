"""Art of the "Moderno" HUD style, copied from the concept art/concept_modern.png (the user's Meshy
agent image "WoW Modern Clean HUD"): near-black navy panels, thin teal hairlines with a faint glow,
small arrow tips at the ends of the lines, gold only on the level badge. The action bar is the
concept's without its wings, gems and gold rails (the user's call).

Colors are sampled from the concept. Each piece is drawn at SS times its texture size and scaled
down, so lines stay crisp; textures are about twice their size on a 1080p screen.

Usage: python tools/modern_art.py OUT_DIR   (writes the pieces and mockup.png)
"""
import pathlib
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SS = 4
PANEL = (3, 13, 21)
EDGE = (0, 4, 10)
LINE = (34, 128, 162)        # the teal hairline
LINE_LIT = (88, 186, 214)    # its lit top side
LINE_DIM = (28, 62, 78)
GOLD = (214, 172, 70)
HEALTH = ((96, 214, 52), None)
MANA = ((22, 132, 244), None)
CAST = ((44, 172, 222), None)


class Canvas:
    """A piece being drawn at SS times its size: body (panels), lines (also blurred into a soft
    glow under themselves) and top (crisp details over everything)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.layers = {k: Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0)) for k in ("body", "lines", "top")}

    @staticmethod
    def s(v):
        return [c * SS for c in v]

    def draw(self, layer):
        return ImageDraw.Draw(self.layers[layer])

    def rrect(self, box, r, fill=None, outline=None, width=1.0, layer="lines"):
        self.draw(layer).rounded_rectangle(self.s(box), r * SS, fill=fill, outline=outline,
                                           width=max(1, round(width * SS)) if outline else 0)

    def ellipse(self, box, fill=None, outline=None, width=1.0, layer="lines"):
        self.draw(layer).ellipse(self.s(box), fill=fill, outline=outline, width=max(1, round(width * SS)) if outline else 0)

    def poly(self, pts, fill, layer="lines"):
        self.draw(layer).polygon([tuple(self.s(p)) for p in pts], fill=fill)

    def line(self, pts, color, width=1.0, layer="lines"):
        self.draw(layer).line([tuple(self.s(p)) for p in pts], fill=color, width=max(1, round(width * SS)))

    def vgrad(self, box, r, top, bottom, alpha=(230, 230), layer="body"):
        """A rounded box filled with a vertical gradient."""
        x0, y0, x1, y1 = [round(v) for v in self.s(box)]
        g = Image.new("RGBA", (1, y1 - y0))
        for y in range(g.height):
            f = y / max(1, g.height - 1)
            g.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * f) for i in range(3))
                       + (round(alpha[0] + (alpha[1] - alpha[0]) * f),))
        g = g.resize((x1 - x0, g.height))
        m = Image.new("L", g.size, 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, g.width - 1, g.height - 1), r * SS, fill=255)
        piece = Image.new("RGBA", g.size, (0, 0, 0, 0))
        piece.paste(g, (0, 0), m)
        self.layers[layer].alpha_composite(piece, (x0, y0))

    def hfade(self, box, layers=("body", "lines")):
        """Fade the given layers to nothing from the left of box to its right (a soft end)."""
        x0, y0, x1, y1 = [round(v) for v in self.s(box)]
        ramp = Image.new("L", (x1 - x0, 1))
        for x in range(ramp.width):
            f = 1 - x / max(1, ramp.width - 1)
            ramp.putpixel((x, 0), round(255 * f * f))
        ramp = ramp.resize((x1 - x0, y1 - y0))
        for k in layers:
            img = self.layers[k]
            m = Image.new("L", img.size, 255)
            m.paste(ramp, (x0, y0))
            m.paste(0, (x1, y0, img.width, y1))
            img.putalpha(ImageChops.multiply(img.getchannel("A"), m))

    def cut(self, box, r=0, ellipse=False):
        """A see-through hole in every layer (portrait, icon, map show through)."""
        for img in self.layers.values():
            m = Image.new("L", img.size, 255)
            d = ImageDraw.Draw(m)
            (d.ellipse if ellipse else lambda b, fill: d.rounded_rectangle(b, r * SS, fill=fill))(self.s(box), fill=0)
            img.putalpha(ImageChops.multiply(img.getchannel("A"), m))

    def render(self, glow=0.8, shadow=0.75):
        out = Image.new("RGBA", self.layers["body"].size, (0, 0, 0, 0))
        if shadow:
            a = self.layers["body"].getchannel("A")
            for k in ("lines", "top"):
                a = ImageChops.lighter(a, self.layers[k].getchannel("A"))
            sh = Image.new("RGBA", a.size, (0, 2, 6, 0))
            sh.putalpha(a.point(lambda v: round(v * shadow)))
            sh = sh.filter(ImageFilter.GaussianBlur(3.5 * SS))
            out.alpha_composite(sh, (0, round(2.5 * SS)))
        out.alpha_composite(self.layers["body"])
        if glow:
            g = self.layers["lines"].filter(ImageFilter.GaussianBlur(2.2 * SS))
            g.putalpha(g.getchannel("A").point(lambda v: min(255, round(v * glow))))
            out.alpha_composite(g)
        out.alpha_composite(self.layers["lines"])
        out.alpha_composite(self.layers["top"])
        return out.resize((self.w, self.h), Image.LANCZOS)


def hairline_box(c, box, r, lit=True, width=1.6):
    """The concept's frame edge: a dark outer line, the teal line, lit along the top."""
    x0, y0, x1, y1 = box
    c.rrect((x0 - 1.2, y0 - 1.2, x1 + 1.2, y1 + 1.2), r + 1.2, outline=EDGE + (255,), width=1.4, layer="body")
    c.rrect(box, r, outline=LINE + (255,), width=width)
    if lit:
        c.line([(x0 + r + 2, y0 + 0.2), (x1 - r - 2, y0 + 0.2)], LINE_LIT + (200,), 0.9, layer="top")


def tip(c, x, y, direction, size=5, color=LINE):
    """Small arrow tip where a hairline ends (direction: -1 points left, 1 right, 2 down)."""
    if direction == 2:
        c.poly([(x - size * 0.7, y), (x + size * 0.7, y), (x, y + size)], color + (255,))
    else:
        c.poly([(x, y - size * 0.7), (x, y + size * 0.7), (x + direction * size, y)], color + (255,))


# ------------------------------------------------------------------ unit frame (player, target)
# Rects in px of the 700x220 texture (Data.MODERN_UNIT mirrors them).
UNIT = {"w": 720, "h": 250, "ring": (12, 12, 232, 232), "portrait": (28, 28, 216, 216),
        "name": (250, 26, 704, 80), "health": (186, 91, 694, 141), "power": (186, 157, 686, 195),
        "level": (4, 168, 80, 244)}


def unit_frame():
    c = Canvas(UNIT["w"], UNIT["h"])
    for key in ("health", "power"):
        x0, y0, x1, y1 = UNIT[key]
        r, rim = 8, 8
        # each bar in its own thick dark rim (the user found the bars too close together): a teal
        # line outside it, a dark line where it meets the groove, the groove dark inside
        c.rrect((x0 - rim, y0 - rim, x1 + rim, y1 + rim), r + rim, fill=(4, 14, 24, 250), layer="body")
        c.rrect((x0 - rim, y0 - rim, x1 + rim, y1 + rim), r + rim, outline=(40, 112, 140, 255), width=2.0)
        c.rrect((x0 - 1.5, y0 - 1.5, x1 + 1.5, y1 + 1.5), r + 1.5, outline=(0, 0, 0, 255), width=1.6, layer="body")
        c.rrect((x0, y0, x1, y1), r, fill=(1, 6, 11, 255), layer="body")
        c.line([(x0 + 16, y0 - rim + 1.2), (x1 - 16, y0 - rim + 1.2)], (96, 170, 196, 170), 1.0, layer="top")
    # the ring: a thick dark navy band between a teal line outside and a dark edge inside
    x0, y0, x1, y1 = UNIT["ring"]
    c.ellipse((x0, y0, x1, y1), fill=(5, 18, 30, 255), layer="body")
    c.ellipse((x0, y0, x1, y1), outline=(58, 150, 182, 255), width=2.6)
    c.draw("top").arc(c.s((x0 + 1, y0 + 1, x1 - 1, y1 - 1)), 196, 344, fill=(140, 214, 236, 220), width=round(1.6 * SS))
    c.ellipse((x0 + 9, y0 + 9, x1 - 9, y1 - 9), outline=(22, 70, 92, 255), width=2.0, layer="top")
    c.ellipse((x0 + 12, y0 + 12, x1 - 12, y1 - 12), fill=(0, 0, 0, 255), layer="top")
    c.cut(UNIT["portrait"], ellipse=True)
    # level badge: dark disc in a gold ring, overlapping the portrait ring
    lx0, ly0, lx1, ly1 = UNIT["level"]
    c.ellipse((lx0 - 3, ly0 - 3, lx1 + 3, ly1 + 3), fill=(4, 12, 20, 255), layer="top")
    c.ellipse((lx0, ly0, lx1, ly1), fill=(8, 12, 16, 255), outline=GOLD + (255,), width=3.4, layer="top")
    c.draw("top").arc(c.s((lx0 + 1, ly0 + 1, lx1 - 1, ly1 - 1)), 200, 330, fill=(250, 222, 140, 230), width=round(1.2 * SS))
    return c.render()


def arcane_ring(color=(170, 70, 255), seed=3):
    """Swirling arcane energy just inside the portrait ring (the purple effect the user liked).
    Drawn over the portrait, under the ring; turned slowly in game."""
    import math
    import random
    rnd = random.Random(seed)
    n = 256
    c = Canvas(n, n)
    d = c.draw("lines")
    cx = cy = n / 2 * SS
    for _ in range(46):
        r = (n / 2 - rnd.uniform(6, 24)) * SS
        a0 = rnd.uniform(0, 360)
        span = rnd.uniform(25, 95)
        w = rnd.uniform(1.0, 3.2) * SS
        lift = rnd.uniform(0.3, 1.0)
        col = tuple(min(255, round(v * lift + 255 * (1 - lift) * 0.35)) for v in color) + (round(255 * rnd.uniform(0.5, 1)),)
        d.arc((cx - r, cy - r, cx + r, cy + r), a0, a0 + span, fill=col, width=round(w))
    for _ in range(26):  # sparks
        ang = rnd.uniform(0, 2 * math.pi)
        r = (n / 2 - rnd.uniform(8, 22)) * SS
        x, y = cx + r * math.cos(ang), cy + r * math.sin(ang)
        s = rnd.uniform(1, 2.6) * SS
        d.ellipse((x - s, y - s, x + s, y + s), fill=(235, 200, 255, 255))
    # fade toward the middle: the face stays clear
    m = Image.new("L", c.layers["lines"].size, 0)
    md = ImageDraw.Draw(m)
    for i in range(40):
        rr = (n / 2 - i * 1.6) * SS
        md.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=round(255 * max(0, 1 - i / 22)))
    c.layers["lines"].putalpha(ImageChops.multiply(c.layers["lines"].getchannel("A"), m))
    return c.render(glow=1.6, shadow=0)


# ------------------------------------------------------------------ cast bar
CASTBAR = {"w": 940, "h": 124, "icon": (14, 14, 110, 110), "tab": (122, 8, 520, 62),
           "bar": (122, 64, 906, 106), "name": (140, 12, 510, 60)}


def cast_bar():
    c = Canvas(CASTBAR["w"], CASTBAR["h"])
    ix0, iy0, ix1, iy1 = CASTBAR["icon"]
    c.rrect((ix0 - 4, iy0 - 4, ix1 + 4, iy1 + 4), 8, fill=PANEL + (235,), layer="body")
    hairline_box(c, (ix0 - 4, iy0 - 4, ix1 + 4, iy1 + 4), 8, width=2.2)
    tip(c, ix0 - 7, (iy0 + iy1) / 2, -1, 7)
    tip(c, (ix0 + ix1) / 2, iy1 + 6, 2, 6)
    # name tab: dark plate and a hairline along its top, both fading out to the right (no hard
    # end); the groove below is drawn after the fade, so it stays whole
    tx0, ty0, tx1, ty1 = CASTBAR["tab"]
    bx0, by0, bx1, by1 = CASTBAR["bar"]
    c.rrect((tx0, ty0, tx1 + 60, ty1 + 10), 14, fill=PANEL + (190,), layer="body")
    c.line([(tx0 + 10, ty0), (tx1 + 50, ty0)], LINE_DIM + (255,), 1.4)
    c.hfade((tx0 + (tx1 - tx0) * 0.55, ty0 - 4, tx1 + 62, by0))
    # progress groove, pointed at the right end
    c.rrect((bx0, by0, bx1, by1), (by1 - by0) / 2, fill=(1, 8, 14, 240), layer="body")
    hairline_box(c, (bx0, by0, bx1, by1), (by1 - by0) / 2)
    tip(c, bx1 + 1, (by0 + by1) / 2, 1, 8)
    c.cut((ix0, iy0, ix1, iy1), 5)
    return c.render()


# ------------------------------------------------------------------ action bar pieces
SLOT_TEX = 104  # one slot frame texture (the icon goes inside, 10 px in)


def slot_frame():
    c = Canvas(SLOT_TEX, SLOT_TEX)
    b = (6, 6, SLOT_TEX - 6, SLOT_TEX - 6)
    c.rrect(b, 9, fill=(1, 6, 12, 240), layer="body")
    c.rrect((b[0] - 1.4, b[1] - 1.4, b[2] + 1.4, b[3] + 1.4), 10, outline=EDGE + (255,), width=1.6, layer="body")
    c.rrect(b, 9, outline=(86, 128, 142, 255), width=3.2)
    c.rrect((b[0] + 3.4, b[1] + 3.4, b[2] - 3.4, b[3] - 3.4), 6, outline=(0, 0, 0, 255), width=1.4, layer="top")
    c.line([(b[0] + 10, b[1] + 0.6), (b[2] - 10, b[1] + 0.6)], (170, 210, 222, 220), 1.0, layer="top")
    c.cut((b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4), 6)
    return c.render(glow=0.3, shadow=0.6)


PANEL_TEX, PANEL_CORNER = 96, 32  # 9-slice panel for bars of any size


def bar_panel():
    """A panel to stretch as a 9-slice (corners PANEL_CORNER px): dark navy body, the teal
    hairline at the edge and a dim one inside it."""
    n = PANEL_TEX
    c = Canvas(n, n)
    c.vgrad((6, 6, n - 6, n - 6), 14, (8, 22, 34), PANEL, (225, 238))
    hairline_box(c, (6, 6, n - 6, n - 6), 14, lit=False, width=1.8)
    c.rrect((12, 12, n - 12, n - 12), 9, outline=LINE_DIM + (170,), width=1.0)
    return c.render(glow=0.6)


def nine_slice(tex, w, h, corner):
    """Stretch a 9-slice texture to w x h (what the game does with SetTextureSliceMargins)."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    n, k = tex.width, corner
    xs, ys = [(0, k, 0, k), (k, n - k, k, w - k), (n - k, n, w - k, w)], [(0, k, 0, k), (k, n - k, k, h - k), (n - k, n, h - k, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if dx1 > dx0 and dy1 > dy0:
                out.alpha_composite(tex.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS), (dx0, dy0))
    return out


# ------------------------------------------------------------------ minimap
MAP = {"w": 340, "h": 360, "hole": (26, 72, 314, 360 - 2), "plate": (10, 4, 270, 50), "button": (282, 4, 330, 52)}


def minimap_ring():
    c = Canvas(MAP["w"], MAP["h"])
    x0, y0, x1, y1 = MAP["hole"]
    c.ellipse((x0 - 4, y0 - 4, x1 + 4, y1 + 4), fill=EDGE + (255,), layer="body")
    c.ellipse((x0 - 2.5, y0 - 2.5, x1 + 2.5, y1 + 2.5), outline=(150, 196, 214, 255), width=2.6)
    c.cut((x0, y0, x1, y1), ellipse=True)
    # N marker: a small teal diamond on top of the ring
    cx = (x0 + x1) / 2
    c.poly([(cx, y0 - 14), (cx + 10, y0), (cx, y0 + 14), (cx - 10, y0)], (60, 170, 210, 255), layer="top")
    c.poly([(cx, y0 - 14), (cx + 10, y0), (cx, y0 + 2)], (130, 214, 240, 255), layer="top")
    # zone plate: dark band with hairlines top and bottom, an arrow tip at the left end
    px0, py0, px1, py1 = MAP["plate"]
    c.rrect(MAP["plate"], 6, fill=PANEL + (200,), layer="body")
    c.line([(px0 + 6, py0), (px1, py0)], LINE_DIM + (255,), 1.3)
    c.line([(px0 + 6, py1), (px1 - 30, py1)], LINE + (255,), 1.3)
    tip(c, px0 - 2, (py0 + py1) / 2, -1, 7)
    c.line([(px0 + 4, (py0 + py1) / 2 - 10), (px0 - 2, (py0 + py1) / 2)], LINE + (255,), 1.3)
    c.line([(px0 + 4, (py0 + py1) / 2 + 10), (px0 - 2, (py0 + py1) / 2)], LINE + (255,), 1.3)
    # round button socket (calendar / day-night) at its right
    bx0, by0, bx1, by1 = MAP["button"]
    c.ellipse((bx0, by0, bx1, by1), fill=PANEL + (235,), layer="body")
    c.ellipse((bx0, by0, bx1, by1), outline=LINE + (255,), width=1.8)
    return c.render()


# ------------------------------------------------------------------ micro menu band
def menu_band(w=620, h=92):
    """Dark band with a hairline on top and bottom, arrow tips at the left end (stretched
    horizontally in game: the middle is uniform)."""
    c = Canvas(w, h)
    c.vgrad((20, 10, w, h - 10), 0, (6, 18, 28), PANEL, (215, 230))
    c.line([(20, 10), (w, 10)], LINE + (255,), 1.6)
    c.line([(20, h - 10), (w, h - 10)], LINE + (255,), 1.6)
    c.line([(20, 10), (4, h / 2), (20, h - 10)], LINE + (255,), 1.6)
    tip(c, 4, h / 2, -1, 6)
    return c.render()


def gloss():
    """Status bar fill, grayscale (tinted by the bar color in game): bright glassy top half
    with a light edge, darker lower half, a dark line at the bottom."""
    img = Image.new("RGBA", (8, 64))
    for y in range(64):
        f = y / 63
        if y < 3:
            v = 1.0
        elif f < 0.48:
            v = 0.98 - 0.12 * (f / 0.48)
        else:
            v = 0.74 - 0.22 * ((f - 0.48) / 0.52)
        if y > 60:
            v *= 0.55
        for x in range(8):
            img.putpixel((x, y), (round(255 * v),) * 3 + (255,))
    return img


def bar_fill(colors):
    """The gloss tinted by a bar color (mockup only; the game tints the gray texture)."""
    g = gloss()
    tint = Image.new("RGB", g.size, colors[0])
    return Image.merge("RGBA", (*ImageChops.multiply(g.convert("RGB"), tint).split(), g.getchannel("A")))


# ------------------------------------------------------------------ mockup
def _font(size, bold=False):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/" + ("seguisb.ttf" if bold else "segoeui.ttf"), size)
    except OSError:
        return ImageFont.load_default()


def _text(canvas, xy, text, size, color=(236, 240, 246), anchor="la", bold=False):
    d = ImageDraw.Draw(canvas)
    f = _font(size, bold)
    d.text((xy[0] + 1, xy[1] + 1), text, font=f, fill=(0, 0, 0, 230), anchor=anchor)
    d.text(xy, text, font=f, fill=color, anchor=anchor)


def _paste_round(canvas, img, box, radius=None, ellipse=False):
    x0, y0, x1, y1 = [round(v) for v in box]
    img = img.resize((x1 - x0, y1 - y0), Image.LANCZOS)
    m = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(m)
    if ellipse:
        d.ellipse((0, 0, img.width - 1, img.height - 1), fill=255)
    else:
        d.rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius or 0, fill=255)
    canvas.paste(img.convert("RGB"), (x0, y0), m)


def _fill(canvas, box, frac, colors, radius=3):
    x0, y0, x1, y1 = [round(v) for v in box]
    w = round((x1 - x0) * frac)
    if w > 1:
        _paste_round(canvas, bar_fill(colors), (x0, y0, x0 + w, y1), radius)


def _unit(canvas, x, y, k, name, values, colors, fracs, portrait, level, mirror=False, arcane=None):
    art = unit_frame()
    if mirror:
        art = art.transpose(Image.FLIP_LEFT_RIGHT)

    def rect(key, inset=0):
        x0, y0, x1, y1 = UNIT[key]
        if mirror:
            x0, x1 = UNIT["w"] - x1, UNIT["w"] - x0
        return (x + (x0 + inset) * k, y + (y0 + inset) * k, x + (x1 - inset) * k, y + (y1 - inset) * k)

    _paste_round(canvas, portrait, rect("portrait"), ellipse=True)
    if arcane is not None:
        p = rect("portrait")
        canvas.alpha_composite(arcane.resize((round(p[2] - p[0]), round(p[3] - p[1])), Image.LANCZOS), (round(p[0]), round(p[1])))
    canvas.alpha_composite(art.resize((round(UNIT["w"] * k), round(UNIT["h"] * k)), Image.LANCZOS), (round(x), round(y)))
    for key, frac, col, val, size in (("health", fracs[0], colors[0], values[0], 18), ("power", fracs[1], colors[1], values[1], 16)):
        r = rect(key)
        ring = rect("ring")
        r = (r[0], r[1], ring[0] - 2 * k, r[3]) if mirror else (ring[2] - 2 * k, r[1], r[2], r[3])
        if mirror:
            r = (rect(key, 3)[0], r[1], r[2], r[3])
        _fill(canvas, r, frac, col, round(9 * k))
        _text(canvas, ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2), val, size, anchor="mm", bold=True)
    n = rect("name")
    _text(canvas, (n[2] if mirror else n[0], (n[1] + n[3]) / 2), name, 20, anchor="rm" if mirror else "lm")
    lv = rect("level")
    _text(canvas, ((lv[0] + lv[2]) / 2, (lv[1] + lv[3]) / 2 - 1), str(level), 18, (244, 210, 112), anchor="mm")
    return rect


def mockup(out_path, cols=12):
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from preview_render import ICONS, WOLF, REF, scene_image, map_image, W, H
    canvas = scene_image(REF)
    k = 0.5  # textures are twice the 1080p size

    concept = Image.open(pathlib.Path(__file__).resolve().parent.parent / "art" / "concept_modern.png").convert("RGBA")
    elf, eagle = concept.crop((33, 27, 114, 108)), concept.crop((570, 30, 642, 102))
    prect = _unit(canvas, 18, 14, k, "Elanora", ("48.320 / 48.320", "32.000 / 32.000"), (HEALTH, MANA), (1, 1), elf, 70,
                  arcane=arcane_ring())
    _unit(canvas, 410, 14, k, "Stormtalon Gryphon", ("28.450 / 28.450", "0 / 100"),
          (((226, 52, 44), None), MANA), (1, 0), eagle, 72, mirror=True)
    # buffs under the player's bars
    slot = slot_frame()
    for i in range(2):
        bx, by = prect("ring")[2] + 6 + i * 36, prect("power")[3] + 8
        _paste_round(canvas, ICONS[6 + i], (bx + 4, by + 4, bx + 30, by + 30), 3)
        canvas.alpha_composite(slot.resize((34, 34), Image.LANCZOS), (round(bx), round(by)))

    # action bar: 9-slice panel + slot frames, 2 rows
    s, gap, padx, pady, numh = 54, 7, 18, 10, 18
    bw = cols * s + (cols - 1) * gap + 2 * padx
    bh = 2 * s + gap + 2 * pady + numh
    bx, by = (W - bw) // 2, H - bh - 16
    canvas.alpha_composite(nine_slice(bar_panel(), bw * 2, bh * 2, PANEL_CORNER * 1).resize((bw, bh), Image.LANCZOS), (bx, by))
    sl = slot.resize((s, s), Image.LANCZOS)
    keys = "1234567890-="
    for r in range(2):
        for cidx in range(cols):
            sx = bx + padx + cidx * (s + gap)
            sy = by + pady + numh + r * (s + gap)
            _paste_round(canvas, ICONS[(r * cols + cidx) % len(ICONS)], (sx + 5, sy + 5, sx + s - 5, sy + s - 5), 3)
            canvas.alpha_composite(sl, (sx, sy))
            if r == 0 and cidx < len(keys):
                _text(canvas, (sx + s / 2, by + pady + numh / 2), keys[cidx], 14, anchor="mm", bold=True)
                if cidx < cols - 1:  # small teal diamond between the key numbers
                    dx, dy = sx + s + gap / 2, by + pady + numh / 2
                    ImageDraw.Draw(canvas).polygon([(dx, dy - 3), (dx + 3, dy), (dx, dy + 3), (dx - 3, dy)], fill=(60, 160, 200))

    # cast bar above it
    cb = cast_bar()
    cw, ch = round(CASTBAR["w"] * k), round(CASTBAR["h"] * k)
    cx, cy = (W - cw) // 2, by - ch - 12
    ic = CASTBAR["icon"]
    _paste_round(canvas, ICONS[13], (cx + ic[0] * k, cy + ic[1] * k, cx + ic[2] * k, cy + ic[3] * k), 3)
    canvas.alpha_composite(cb.resize((cw, ch), Image.LANCZOS), (cx, cy))
    b = CASTBAR["bar"]
    _fill(canvas, (cx + (b[0] + 4) * k, cy + (b[1] + 4) * k, cx + (b[2] - 4) * k, cy + (b[3] - 4) * k), 0.48, CAST, 6)
    nm = CASTBAR["name"]
    _text(canvas, (cx + nm[0] * k, cy + (nm[1] + nm[3]) / 2 * k), "Frostbolt", 16, anchor="lm")
    _text(canvas, (cx + (b[2] - 16) * k, cy + (b[1] + b[3]) / 2 * k), "1.2 / 2.5", 13, (236, 200, 96), anchor="rm")

    # minimap
    mr = minimap_ring()
    mk = 0.62
    mw, mh = round(MAP["w"] * mk), round(MAP["h"] * mk)
    mx, my = W - mw - 18, 10
    hx0, hy0, hx1, hy1 = MAP["hole"]
    _paste_round(canvas, map_image((300, 300)), (mx + hx0 * mk, my + hy0 * mk, mx + hx1 * mk, my + hy1 * mk), ellipse=True)
    canvas.alpha_composite(mr.resize((mw, mh), Image.LANCZOS), (mx, my))
    pl = MAP["plate"]
    _text(canvas, (mx + (pl[0] + pl[2]) / 2 * mk, my + (pl[1] + pl[3]) / 2 * mk), "Stormwind Overlook", 15, anchor="mm")
    _text(canvas, (mx + (hx0 + hx1) / 2 * mk, my + mh + 12), "10:24", 14, anchor="mm")

    # micro menu band + money
    band = menu_band()
    bk = 0.5
    nw, nh = round(band.width * bk), round(band.height * bk)
    nx, ny = W - nw - 10, H - nh - 40
    canvas.alpha_composite(band.resize((nw, nh), Image.LANCZOS), (nx, ny))
    d = ImageDraw.Draw(canvas)
    for i in range(8):
        cxm, cym = nx + 26 + i * 34, ny + nh / 2
        d.rounded_rectangle((cxm - 9, cym - 9, cxm + 9, cym + 9), 4, outline=(200, 200, 204), width=2)
    _text(canvas, (nx + nw - 6, ny + nh + 14), "12.468 g  53 s  27 c", 14, anchor="rm")
    canvas.convert("RGB").save(out_path, quality=93)
    return out_path


def main():
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    unit_frame().save(out / "mod_unit.png")
    cast_bar().save(out / "mod_cast.png")
    slot_frame().save(out / "mod_slot.png")
    bar_panel().save(out / "mod_panel.png")
    minimap_ring().save(out / "mod_map.png")
    menu_band().save(out / "mod_menu.png")
    print(mockup(out / "mockup.png"))


if __name__ == "__main__":
    main()


def blackify(img, alpha=0.72):
    """The black theme (user's choice): every blue/teal pixel loses its color (panels become
    black, lines neutral grey), and the dark panel areas turn see-through. Gold, the bar fills
    and the arcane purple keep their colors."""
    import numpy as np
    rgba = np.asarray(img.convert("RGBA")).astype(np.float32)
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(np.float32)
    blue = (hsv[..., 0] > 105) & (hsv[..., 0] < 185)
    grey = rgba[..., :3].mean(axis=2, keepdims=True)
    lum = 0.30 * rgba[..., :1] + 0.59 * rgba[..., 1:2] + 0.11 * rgba[..., 2:3]
    neutral = np.clip((grey * 0.4 + lum * 0.6) * 0.9, 0, 255)
    rgba[..., :3] = np.where(blue[..., None], np.repeat(neutral, 3, axis=2), rgba[..., :3])
    dark = (rgba[..., :3].max(axis=2) < 40) & (rgba[..., 3] > 0)
    rgba[..., 3] = np.where(dark, rgba[..., 3] * alpha, rgba[..., 3])
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


GEM_TEX = 96


def gem_socket():
    """Class resource point, empty: a dark diamond with the teal hairline."""
    c = Canvas(GEM_TEX, GEM_TEX)
    m = GEM_TEX / 2
    r = m - 8
    c.poly([(m, m - r), (m + r, m), (m, m + r), (m - r, m)], EDGE + (255,), layer="body")
    c.poly([(m, m - r + 3), (m + r - 3, m), (m, m + r - 3), (m - r + 3, m)], (52, 92, 108, 255))
    c.poly([(m, m - r + 7), (m + r - 7, m), (m, m + r - 7), (m - r + 7, m)], (4, 10, 16, 245), layer="top")
    return c.render(glow=0.4, shadow=0.5)


def gem_lit():
    """Class resource point, full: a bright faceted diamond, greyscale (tinted by the resource's
    colour in game), with a soft glow around it."""
    c = Canvas(GEM_TEX, GEM_TEX)
    m = GEM_TEX / 2
    r = m - 10
    c.poly([(m, m - r - 4), (m + r + 4, m), (m, m + r + 4), (m - r - 4, m)], (200, 200, 200, 160))
    c.poly([(m, m - r), (m + r, m), (m, m + r), (m - r, m)], (215, 215, 215, 255), layer="top")
    c.poly([(m, m - r), (m + r, m), (m, m)], (255, 255, 255, 255), layer="top")
    c.poly([(m, m), (m + r, m), (m, m + r)], (165, 165, 165, 255), layer="top")
    c.poly([(m, m - r * 0.55), (m + r * 0.3, m - r * 0.1), (m, m), (m - r * 0.3, m - r * 0.1)], (255, 255, 255, 255), layer="top")
    return c.render(glow=1.4, shadow=0.4)
