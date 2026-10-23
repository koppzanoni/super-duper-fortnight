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
    assert (a[y0:y1, x0:x1] == o[y0:y1, x0:x1]).all()
    ys, xs = np.mgrid[0:381, 0:656]
    ring = (np.hypot(xs - cap_art.CX, ys - cap_art.CY) <= cap_art.RING) & (xs >= cap_art.CX)
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
