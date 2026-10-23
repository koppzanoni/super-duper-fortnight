"""Orb liquid textures: looping fluid flipbooks, glass and spark (tools/orb_fluid.py)."""
import sys

import numpy as np

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import export_textures as ex  # noqa: E402
import orb_fluid as of  # noqa: E402


def grids():
    rng = np.random.default_rng(3)
    return [rng.random((8, 8)), rng.random((8, 8))]


def test_sheet_size_and_grid():
    assert (of.SIZE, of.GRID, of.FRAMES) == (128, 8, 64)
    for s in "abc":
        assert of.sheet(s).size == (1024, 1024)


def test_loop_is_seamless_and_motion_is_slow():
    g = grids()
    first, last = of.frame("a", 0.0, g), of.frame("a", 1.0, g)
    step = of.frame("a", 1 / of.FRAMES, g)
    assert np.abs(first - last).max() < 1e-6
    # Neighbouring frames stay close (approved v5 pace: ~0.11); unrelated frames differ ~0.33.
    assert np.abs(first - step).mean() < 0.15


def test_mist_style_is_mostly_dark():
    a = np.asarray(of.sheet("c"))[..., 3] / 255
    assert a.mean() < 0.45


def test_spark_is_a_soft_dot():
    a = np.asarray(of.spark())[..., 3]
    assert of.spark().size == (32, 32)
    assert a[16, 16] > 200 and a[0, 0] == 0


def test_export_registers_orb_textures_and_drops_swirl(tmp_path):
    e = ex.export_all(tmp_path)
    assert {"fluid_a", "fluid_b", "fluid_c", "orb_glass", "orb_spark"} <= set(e)
    assert (e["fluid_a"]["w"], e["fluid_a"]["potW"]) == (1024, 1024)
    assert "swirl" not in e
