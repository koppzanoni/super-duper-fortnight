"""Orb caps of the "Relicário" HUD style (tools/relic_art.py)."""
import sys

import numpy as np

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import cap_art  # noqa: E402
import relic_art  # noqa: E402


def opening(margin=0):
    ys, xs = np.mgrid[0:cap_art.CAP_H, 0:cap_art.CAP_W]
    return np.hypot(xs - cap_art.CX, ys - cap_art.CY) < cap_art.OPENING - margin


# The orb liquid shows through the frame's opening; what lies over the orb is in the overlay.
def test_frames_leave_the_orb_opening_empty():
    for n in relic_art.CAPS:
        a = np.asarray(relic_art.frame(n))
        assert a.shape[:2] == (cap_art.CAP_H, cap_art.CAP_W)
        assert a[..., 3][opening()].max() == 0


def test_overlays_only_cover_the_orb():
    for n in relic_art.CAPS:
        a = np.asarray(relic_art.overlay(n))
        assert a[..., 3][~opening()].max() == 0
        assert (a[..., 3][opening()] > 200).sum() > 2000, n  # the claws / the dragon's wing


# Meshy painted a dark purple void inside the claws' ring: it must not darken the liquid.
def test_claws_overlay_drops_the_dark_void():
    a = np.asarray(relic_art.overlay("claws"))
    assert a[cap_art.CY + 40, cap_art.CX + 20, 3] == 0  # lower middle of the orb, under the claws


def test_frames_have_no_see_through_holes_besides_the_orb():
    from scipy import ndimage
    for n in relic_art.CAPS:
        a = np.asarray(relic_art.frame(n))
        labels, k = ndimage.label(a[..., 3] < 128)
        border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])))
        orb = labels[cap_art.CY, cap_art.CX]
        assert [i for i in range(1, k + 1) if i not in border and i != orb] == [], n


# The 3x3 menu buttons sit in the art's slots (Data.HUD menuCols/menuRows/menuSlot).
def test_menu_buttons_sit_on_dark_slot_recesses():
    for n in relic_art.CAPS:
        a = np.asarray(relic_art.frame(n)).astype(int)
        for x in (429, 488, 547):
            for y in (143, 202, 262):
                inner = a[y + 8:y + 33, x + 8:x + 27, :3]
                assert inner.max(axis=2).mean() < 45, (n, x, y)
