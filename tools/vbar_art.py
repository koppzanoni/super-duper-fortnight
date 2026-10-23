"""Vertical action bars built from the Meshy vertical bar art (art/processed/vbar_slim1_b.png:
two columns of 10 slots). Only the slots are kept (each with its bronze edge); the stone frame
around and between them is cut away. Rows are stretched to 12 by repeating bands of the art cut
through the middle of the slots (the dark slot hides the seam); the one-bar art keeps the outer
half of each column, also cut through the slots. The result is scaled to fit a 1024 px texture.
Used by export_textures.py for the "vbar1" and "vbar2" textures.
"""
from PIL import Image, ImageChops, ImageDraw

SOURCE = "vbar_slim1_b.png"
# Slot rows of the source art (top, bottom) and its two slot columns (left, right), in source px.
SRC_ROWS = [(60, 157), (188, 284), (316, 412), (443, 538), (570, 664),
            (695, 790), (820, 915), (946, 1040), (1070, 1164), (1195, 1290)]
SRC_COLS = [(46, 135), (164, 252)]
SRC_W, SRC_H = 300, 1352
SLOT_W, SLOT_H = 89, 95
# Bronze edge around each slot's dark recess, and the cut of its chamfered corners (source px).
EDGE, CHAMFER = 7, 9
ROWS = 12
# Bands between slot centers, in order: band i joins source rows i and i+1 (1-based). Two
# middle bands are repeated to get from 10 to 12 rows.
BANDS = [1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9]
SCALE = 0.625


def _center(i):
    top, bottom = SRC_ROWS[i - 1]
    return (top + bottom) // 2


def _layout():
    """Source y ranges to stack, and the slot top of each output row (source px, unscaled)."""
    pieces = [(0, _center(1))]
    tops = [SRC_ROWS[0][0]]
    y = _center(1)
    for i in BANDS:
        tops.append(y + SRC_ROWS[i][0] - _center(i))
        pieces.append((_center(i), _center(i + 1)))
        y += _center(i + 1) - _center(i)
    pieces.append((_center(len(SRC_ROWS)), SRC_H))
    return pieces, tops


def _col_center(c):
    left, right = SRC_COLS[c]
    return (left + right) // 2


def _x_ranges(cols):
    if cols == 2:
        return [(0, SRC_W)]
    return [(0, _col_center(0)), (_col_center(1), SRC_W)]


def _lefts(cols):
    """Slot column lefts in the stacked art, before cropping (source px)."""
    return [left for left, _ in SRC_COLS[:cols]]


def _crop_origin():
    return SRC_COLS[0][0] - EDGE, SRC_ROWS[0][0] - EDGE


def _s(v):
    return round(v * SCALE)


def _slots_mask(size, cols, tops):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for left in _lefts(cols):
        for top in tops:
            x0, y0 = left - EDGE, top - EDGE
            x1, y1 = left + SLOT_W + EDGE, top + SLOT_H + EDGE
            c = CHAMFER
            d.polygon([(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c),
                       (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)], fill=255)
    return mask


def build(src, cols):
    pieces, tops = _layout()
    xs = _x_ranges(cols)
    w = sum(x1 - x0 for x0, x1 in xs)
    h = sum(y1 - y0 for y0, y1 in pieces)
    out = Image.new("RGBA", (w, h))
    y = 0
    for y0, y1 in pieces:
        x = 0
        for x0, x1 in xs:
            out.paste(src.crop((x0, y0, x1, y1)), (x, y))
            x += x1 - x0
        y += y1 - y0
    out.putalpha(ImageChops.multiply(out.getchannel("A"), _slots_mask(out.size, cols, tops)))
    ox, oy = _crop_origin()
    out = out.crop((ox, oy, _lefts(cols)[-1] + SLOT_W + EDGE, tops[-1] + SLOT_H + EDGE))
    return out.resize((_s(out.width), _s(out.height)), Image.LANCZOS)


def slot_offsets():
    """Top y of each of the 12 slots in the built art."""
    oy = _crop_origin()[1]
    return [_s(t - oy) for t in _layout()[1]]


def columns(cols):
    """Left x of each slot column in the built art."""
    ox = _crop_origin()[0]
    return [_s(left - ox) for left in _lefts(cols)]


def slot_size():
    return _s(SLOT_W), _s(SLOT_H)
