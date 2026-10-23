"""Orb cap redrawn with dragon wings (tools/cap_art.py)."""
import sys

import numpy as np
from PIL import Image

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import cap_art  # noqa: E402


def cap():
    return Image.open(ROOT / "art" / "processed" / "hud_bottom.png").convert("RGBA").crop((0, 0, 656, 381))


def built():
    return np.asarray(cap_art.build(cap())).astype(int)


def test_same_size_as_the_cap():
    assert cap_art.build(cap()).size == (656, 381)


# The orb liquid shows through the opening: the wing never covers the flask.
def test_orb_opening_stays_empty():
    a = built()
    ys, xs = np.mgrid[0:381, 0:656]
    inside = np.hypot(xs - cap_art.CX, ys - cap_art.CY) < cap_art.OPENING - 2
    assert a[..., 3][inside].max() == 0


# The menu slots and the right half of the ring are the original art: the menu buttons and the
# orb stay where the addon places them.
def test_menu_slots_and_right_ring_are_untouched():
    a, o = built(), np.asarray(cap()).astype(int)
    x0, y0, x1, y1 = cap_art.SLOTS
    same = a[y0:y1, x0:x1] == o[y0:y1, x0:x1]
    cx0, cy0, cx1, cy1 = cap_art.CLEAN_SLOT
    for dx in cap_art.CLEAN_COPIES:  # the cleaned bottom corner slots, see below
        same[cy0 - y0:cy1 - y0, cx0 + dx - x0:cx1 + dx - x0] = True
    assert same.all()
    ys, xs = np.mgrid[0:381, 0:656]
    ring = (np.hypot(xs - cap_art.CX, ys - cap_art.CY) <= cap_art.RING) & (xs >= cap_art.CX)
    ring &= o[..., 3] == 255  # holes in the tracery get stone behind them (see below)
    assert (a[ring] == o[ring]).all()


def test_menu_slots_hold_every_button():
    x0, y0, x1, y1 = cap_art.SLOTS
    cols, rows, w, h = (429, 488, 547), (143, 202, 262), 35, 41  # Data.HUD menuCols/menuRows/menuSlot
    assert x0 <= cols[0] and cols[-1] + w <= x1
    assert y0 <= rows[0] and rows[-1] + h <= y1


# In game, the background showed between the gargoyle and the screen edge. The stone behind the
# wing fills the side from the top of the ring down to the screen bottom (the last rows of the
# art are sunk below the screen).
def test_wing_fills_the_screen_edge():
    a = built()
    edge = a[40:355, 0:6, 3]
    assert edge.min() > 200


def test_gargoyle_is_gone():
    a, o = built(), np.asarray(cap()).astype(int)
    left = (slice(40, 340), slice(0, 60))
    assert np.abs(a[left][..., :3] - o[left][..., :3]).mean() > 15


# In game the user wanted the panel's wings off the menu slots: the sculpture covered the outer
# edge of the two bottom corner slots. They are copies of the clean bottom middle slot.
def test_bottom_corner_slots_are_clean():
    a = built()
    x0, y0, x1, y1 = cap_art.CLEAN_SLOT
    middle = a[y0:y1, x0:x1]
    for dx in (-59, 59):
        assert (a[y0:y1, x0 + dx:x1 + dx] == middle).all()


# In game the background showed through the holes of the tracery between the ring and the panel:
# apart from the orb opening, no enclosed see-through hole is left in the art.
def test_no_see_through_holes_besides_the_orb():
    from scipy import ndimage
    a = built()
    clear = a[..., 3] < 128
    labels, n = ndimage.label(clear)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
    orb = labels[cap_art.CY, cap_art.CX]
    holes = [i for i in range(1, n + 1) if i not in border and i != orb]
    assert holes == [], [int((labels == i).sum()) for i in holes]
