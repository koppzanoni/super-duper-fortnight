"""Vertical bars built from the main action bar art (same look), rotated."""
import sys

from PIL import Image

from conftest import ROOT, load_addon_file, new_runtime

sys.path.insert(0, str(ROOT / "tools"))
import vbar_art as va  # noqa: E402


def data():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data


def hud():
    return Image.open(ROOT / "art" / "processed" / "hud_bottom.png").convert("RGBA")


def test_two_bars_art_has_twelve_slots_in_two_columns():
    img = va.build(hud(), rows=2)
    D = data().VBAR2
    assert img.size == (D.w, D.h)
    assert [D.cols[i] for i in (1, 2)] == va.columns(2)
    assert [D.rows[i] for i in range(1, 13)] == va.slot_offsets()
    assert (D.slot.w, D.slot.h) == va.SLOT_ROTATED


def test_one_bar_art_has_one_column():
    img = va.build(hud(), rows=1)
    D = data().VBAR1
    assert img.size == (D.w, D.h)
    assert [D.cols[1]] == va.columns(1)
    assert [D.rows[i] for i in range(1, 13)] == va.slot_offsets()


def test_slots_lie_inside_the_art():
    for rows, key in ((1, "VBAR1"), (2, "VBAR2")):
        D = getattr(data(), key)
        for c in range(1, rows + 1):
            for r in range(1, 13):
                assert 0 <= D.cols[c] and D.cols[c] + D.slot.w <= D.w
                assert 0 <= D.rows[r] and D.rows[r] + D.slot.h <= D.h
