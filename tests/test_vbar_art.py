"""Vertical bars built from the Meshy vertical bar art (art/processed/vbar_slim1_b.png): only
its slots are kept, 10 rows stretched to 12 by repeating rows; the one-bar art has one column."""
import sys

import numpy as np
from PIL import Image

from conftest import ROOT, load_addon_file, new_runtime

sys.path.insert(0, str(ROOT / "tools"))
import vbar_art as va  # noqa: E402


def data():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data


def src():
    return Image.open(ROOT / "art" / "processed" / va.SOURCE).convert("RGBA")


def test_two_bars_art_has_twelve_slots_in_two_columns():
    img = va.build(src(), 2)
    D = data().VBAR2
    assert img.size == (D.w, D.h)
    assert [D.cols[i] for i in (1, 2)] == va.columns(2)
    assert [D.rows[i] for i in range(1, 13)] == va.slot_offsets()
    assert (D.slot.w, D.slot.h) == va.slot_size()


def test_one_bar_art_has_one_column():
    img = va.build(src(), 1)
    D = data().VBAR1
    assert img.size == (D.w, D.h)
    assert [D.cols[1]] == va.columns(1)
    assert [D.rows[i] for i in range(1, 13)] == va.slot_offsets()
    assert img.width < va.build(src(), 2).width


def test_fits_in_a_texture():
    for cols in (1, 2):
        assert max(va.build(src(), cols).size) <= 1024


# Every button lies over a dark empty slot of the art.
def test_buttons_sit_on_the_art_slots():
    for cols, key in ((1, "VBAR1"), (2, "VBAR2")):
        D = getattr(data(), key)
        a = np.asarray(va.build(src(), cols)).astype(int)
        for c in range(1, cols + 1):
            for r in range(1, 13):
                x, y, w, h = D.cols[c], D.rows[r], D.slot.w, D.slot.h
                inner = a[y + 4:y + h - 4, x + 4:x + w - 4]
                assert inner[..., 3].min() > 200, (key, c, r)
                assert inner[..., :3].sum(axis=2).mean() < 75, (key, c, r)


# In game the user wanted only the slots, without the stone frame around and between them: each
# slot keeps its bronze edge, everything else is transparent.
def test_art_is_only_the_slots():
    for cols, key in ((1, "VBAR1"), (2, "VBAR2")):
        D = getattr(data(), key)
        a = np.asarray(va.build(src(), cols)).astype(int)
        h, w = a.shape[:2]
        # the slots fill the art up to their bronze edge
        assert D.cols[1] <= 6 and D.rows[1] <= 6
        assert w - (D.cols[cols] + D.slot.w) <= 6 and h - (D.rows[12] + D.slot.h) <= 6
        # bronze edge around a slot
        x, y = D.cols[1], D.rows[3]
        assert a[y + D.slot.h // 2, max(0, x - 3):x, 3].max() > 200
        # nothing between two rows of slots
        for r in range(1, 12):
            gap_top, gap_bottom = D.rows[r] + D.slot.h + 6, D.rows[r + 1] - 6
            if gap_bottom > gap_top:
                assert a[gap_top:gap_bottom, x + D.slot.w // 2, 3].max() < 20, (key, r)
        # image corners (outside the chamfered slot corners) are empty
        assert a[0, 0, 3] < 20 and a[h - 1, w - 1, 3] < 20
        if cols == 2:
            mid = (D.cols[1] + D.slot.w + D.cols[2]) // 2
            assert a[:, mid, 3].max() < 20
