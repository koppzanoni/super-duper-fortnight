"""Reworked inventory art: bigger equipment frames, tabs moved left, a plate for the sort button."""
import sys

import numpy as np
from PIL import Image

from conftest import ROOT, load_addon_file, new_runtime

sys.path.insert(0, str(ROOT / "tools"))
import inventory_art as ia  # noqa: E402


def data():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data.INV


def base():
    return Image.open(ROOT / "art" / "processed" / "inventory.png").convert("RGBA")


def test_rework_keeps_size():
    assert ia.rework(base()).size == (690, 1334)


def test_tab_and_sort_rects_match_the_art():
    S = data()
    assert [S.tabs[i] for i in range(1, 6)] == [x + ia.PLATE_INSET for x in ia.PLATES_X]
    assert S.tabW == ia.PLATE_W - 2 * ia.PLATE_INSET
    x0, y0, x1, y1 = ia.SORT_BOX
    assert (S.sort.x, S.sort.y) == (x0 + ia.PLATE_INSET, y0 + ia.PLATE_INSET)
    assert (S.sort.w, S.sort.h) == (x1 - x0 - 2 * ia.PLATE_INSET, y1 - y0 - 2 * ia.PLATE_INSET)


def test_tabs_sit_left_with_sort_plate_right_after():
    last_tab_end = ia.PLATES_X[-1] + ia.PLATE_W
    assert ia.PLATES_X[0] < 45
    assert 0 < ia.SORT_BOX[0] - last_tab_end <= 12


def test_equipment_frames_bigger_and_icons_fill_them():
    S = data()
    assert ia.FRAME_SIZE >= 68
    assert S.equipSize == ia.FRAME_SIZE - 2 * ia.FRAME_INSET
    assert S.equipSize >= 60
    # icon centers stay on the frame centers
    assert S.equipTop + S.equipSize / 2 == ia.FRAME_CY0


def test_sort_plate_is_drawn():
    out = np.asarray(ia.rework(base())).astype(int)
    before = np.asarray(base()).astype(int)
    x0, y0, x1, y1 = ia.SORT_BOX
    assert np.abs(out[y0:y1, x0:x1] - before[y0:y1, x0:x1]).mean() > 5
