"""Vertical action bars built from the main action bar art (art/processed/hud_bottom.png), so
both bars look alike: the bar's outer end with its first column, 10 copies of a plain middle
column and the mirrored end (with its own slot) make a 12-slot horizontal strip of 1 or 2 rows,
rotated 90 degrees clockwise.
Used by export_textures.py for the "vbar1" and "vbar2" textures.
"""
from PIL import Image

END = (662, 774)          # bar end + first slot column (x range in hud_bottom)
SLICE = (845, 917)        # a plain middle column: gap + slot + gap
FIRST_SLOT_X = 710        # first column's slot x
SLICE_SLOT_DX = 8         # slot x inside a slice
COLUMNS = 12
TOP = 85                  # bar frame top
ROW_Y = (114, 215)        # slot y of rows 1 and 2
SLOT = (56, 61)           # slot w, h in the horizontal bar
ONE_ROW = (85, 197)       # top rail + row 1 with its lip
TWO_ROWS = (85, 318)      # top rail + rows 1-2 + bottom rail
BOTTOM_RAIL = (296, 318)  # closes the one-row strip

SLOT_ROTATED = (SLOT[1], SLOT[0])


def _strip(hud, y_ranges):
    """Horizontal strip of COLUMNS columns over the given stacked y ranges."""
    def band(x0, x1):
        parts = [hud.crop((x0, y0, x1, y1)) for y0, y1 in y_ranges]
        h = sum(p.height for p in parts)
        out = Image.new("RGBA", (x1 - x0, h))
        y = 0
        for p in parts:
            out.paste(p, (0, y))
            y += p.height
        return out

    end = band(*END)
    mid = band(*SLICE)
    w = end.width * 2 + mid.width * (COLUMNS - 2)
    strip = Image.new("RGBA", (w, end.height))
    strip.paste(end, (0, 0))
    for k in range(COLUMNS - 2):
        strip.paste(mid, (end.width + k * mid.width, 0))
    strip.paste(end.transpose(Image.FLIP_LEFT_RIGHT), (w - end.width, 0))
    return strip


def build(hud, rows):
    ranges = [TWO_ROWS] if rows == 2 else [ONE_ROW, BOTTOM_RAIL]
    return _strip(hud, ranges).transpose(Image.ROTATE_270)


def _strip_height(rows):
    if rows == 2:
        return TWO_ROWS[1] - TWO_ROWS[0]
    return (ONE_ROW[1] - ONE_ROW[0]) + (BOTTOM_RAIL[1] - BOTTOM_RAIL[0])


def slot_offsets():
    """Top y of each of the 12 slots in the rotated art (strip x before rotation)."""
    first = FIRST_SLOT_X - END[0]
    middle = [(END[1] - END[0]) + k * (SLICE[1] - SLICE[0]) + SLICE_SLOT_DX for k in range(COLUMNS - 2)]
    total = (END[1] - END[0]) * 2 + (SLICE[1] - SLICE[0]) * (COLUMNS - 2)
    return [first] + middle + [total - first - SLOT[0]]


def columns(rows):
    """Left x of each column in the rotated art: bar 1 then bar 2 (strip rows 2 and 1)."""
    h = _strip_height(rows)
    left = [h - (ROW_Y[r] - TOP) - SLOT[1] for r in range(rows)]
    return sorted(left)
