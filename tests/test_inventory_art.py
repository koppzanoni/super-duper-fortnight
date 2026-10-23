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


# In-game: the button plate showed a seam (cut across two plates of the moved row).
def test_button_plate_is_cut_from_a_single_plate():
    x0, _, x1, _ = ia.PLATE_TEX_SRC
    assert any(px == x0 and px + ia.PLATE_W == x1 for px in ia.PLATES_X)


def test_wing_rects_match_the_wing_art():
    WG = data().wing
    assert (WG.w, WG.overlap) == (ia.WING_W, ia.WING_OVERLAP)
    x0, y0, x1, y1 = ia.WING_TITLE
    assert (WG.title.x, WG.title.y, WG.title.w, WG.title.h) == (x0, y0, x1 - x0, y1 - y0)
    # everything visible stays left of the hidden pillar and inside the stone
    ix0, iy0, ix1, iy1 = ia.WING_INNER
    for r in (WG.search, WG.buttons):
        x = r.x if r.x else r.x0
        assert x >= ix0
    assert WG.rows.x1 <= ix1 - WG.overlap
    assert WG.buttons.y + WG.buttons.h <= iy1


# In-game: scrolling moved the items but not the slot frames baked into the art. The grid area
# is plain stone now; every item button draws its own frame (cut from the original art).
def test_grid_slot_frames_removed_from_the_art():
    out = np.asarray(ia.rework(base())).astype(int)
    x0, y0, x1, y1 = ia.GRID_SLOT_SRC
    before = np.asarray(base()).astype(int)
    # the frame's bright bevel (top edge) is gone where the first slot was
    assert before[y0 + 1, x0 + 20:x1 - 20, :3].mean() > 100
    assert out[y0 + 1, x0 + 20:x1 - 20, :3].mean() < 50


def test_bag_slot_texture_and_its_placement():
    p = ia.pieces(ia.rework(base()), base())
    x0, y0, x1, y1 = ia.GRID_SLOT_SRC
    assert p["bag_slot"].size == (x1 - x0, y1 - y0)
    S = data()
    gx, gy = S.gridCols[1], S.gridRows[1]
    assert (S.gridFrame.dx, S.gridFrame.dy) == (x0 - gx, y0 - gy)
    assert (S.gridFrame.w, S.gridFrame.h) == (x1 - x0, y1 - y0)


# The art paints its own scroll bar; the real one sits on it (in game there were two, one
# over the other). The painted thumb is erased (the real thumb moves) and becomes a texture.
def test_scroll_bar_rects_match_the_painted_rail():
    S = data()
    sc = S.scroll
    for key, box in (("up", ia.SCROLL_UP), ("down", ia.SCROLL_DOWN), ("track", ia.SCROLL_TRACK)):
        r = sc[key]
        assert (r.x, r.y, r.x + r.w, r.y + r.h) == box


def test_painted_thumb_is_erased():
    orig = np.asarray(base().convert("L"), dtype=float)
    new = np.asarray(ia.rework(base()).convert("L"), dtype=float)
    x0, y0, x1, y1 = ia.SCROLL_THUMB
    # The thumb's bright rim is gone: the area now looks like the empty groove.
    assert new[y0:y1, x0:x1].max() < orig[y0:y1, x0:x1].max() - 40
    gx0, gy0, gx1, gy1 = ia.SCROLL_TRACK
    groove = new[y1 + 20:gy1 - 20, gx0:gx1].mean()
    assert abs(new[y0:y1, x0:x1].mean() - groove) < 8


def test_scroll_thumb_piece():
    reworked = ia.rework(base())
    thumb = ia.pieces(reworked, base())["scroll_thumb"]
    assert thumb.size == ia.SCROLL_THUMB_SIZE
