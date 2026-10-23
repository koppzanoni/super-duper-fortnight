"""Vertical bars built from the Meshy vertical bar art (art/processed/vbar_slim1_b.png): its
10 slot rows are stretched to 12 by repeating rows, and the one-bar art drops a column."""
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


# Every button lies over a dark empty slot of the art, not over the frame between slots.
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
                # the frame between two rows is lighter than the slot
                if r < 12:
                    gap = a[y + h + 3:D.rows[r + 1] - 3, x + w // 3:x + 2 * w // 3]
                    assert gap[..., :3].sum(axis=2).mean() > inner[..., :3].sum(axis=2).mean() + 20, (key, c, r)
