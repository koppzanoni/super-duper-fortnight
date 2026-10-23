"""Unit frame art from the chosen party frame B (tools/unit_art.py) and Data.UNIT."""
import sys

import numpy as np

from conftest import ROOT, load_addon_file, new_runtime

sys.path.insert(0, str(ROOT / "tools"))
import unit_art  # noqa: E402


def spec():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data.UNIT


# The world must not show behind a bar that is not full: only the portrait ring stays open.
def test_only_the_portrait_opening_is_see_through():
    a = np.asarray(unit_art.build())
    assert unit_art.holes(a) == unit_art.holes(np.asarray(unit_art.trimmed()))[:1]


def test_spec_matches_the_art():
    s = spec()
    img = unit_art.build()
    assert (s.w, s.h) == img.size
    portrait, name, health, power = unit_art.holes(np.asarray(unit_art.trimmed()))
    def inside(r, box, tuck=0):
        x, y, w, h = box
        return r.x >= x - tuck and r.y >= y - tuck and r.x + r.w <= x + w + tuck and r.y + r.h <= y + h + tuck
    assert inside(s.name, name) and inside(s.health, health) and inside(s.power, power)
    # the portrait tucks under the ring: it covers the whole opening
    x, y, w, h = portrait
    p = s.portrait
    assert p.x <= x - 2 and p.y <= y - 2 and p.x + p.w >= x + w + 2 and p.y + p.h >= y + h + 2
