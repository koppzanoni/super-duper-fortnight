"""PoE2-style orb liquid: styles, palettes, flipbook playback, settings."""
import pytest

from conftest import load_pure


@pytest.fixture
def D(pure):
    return load_pure(pure, "Core/Data.lua").Data


def rgb255(c):
    return [round(c[i] * 255) for i in (1, 2, 3)]


def test_style_fallback(D):
    assert D.OrbStyle("b") == "b"
    assert D.OrbStyle(None) == "a" and D.OrbStyle("zzz") == "a"
    assert [D.ORB_STYLE_ORDER[i] for i in range(1, 5)] == ["a", "b", "c", "d"]
    assert D.ORB_STYLE_LABELS.d == "Parado"


def test_style_values_match_the_approved_preview(D):
    a, b, d = D.ORB_STYLES.a, D.ORB_STYLES.b, D.ORB_STYLES.d
    assert (a.sheet, a.fps, a.wisp, a.wisp2, a.spin, a.spin2) == ("fluid_a", 7, 0.62, 0.22, 0.05, -0.03)
    assert b.sparks and b.core == 0.5 and not a.sparks
    assert D.ORB_STYLES.c.sheet == "fluid_c" and D.ORB_STYLES.c.wisp2 == 0
    assert d.still and d.sheet == "fluid_a" and d.stillFrame == 21 and not a.still


def test_flipbook_coords(D):
    assert D.FlipbookCoords(0) == (0, 0.125, 0, 0.125)
    assert D.FlipbookCoords(9) == (0.125, 0.25, 0.125, 0.25)
    assert D.FlipbookCoords(63) == (0.875, 1, 0.875, 1)
    assert D.FlipbookCoords(64) == D.FlipbookCoords(0)


def test_health_and_mana_palettes_are_exact(D):
    h = D.OrbPalette("HEALTH")
    assert (rgb255(h.deep), rgb255(h.body), rgb255(h.wisp), rgb255(h.line)) == \
        ([12, 0, 2], [62, 2, 7], [230, 46, 30], [255, 150, 110])
    m = D.OrbPalette("MANA")
    assert (rgb255(m.deep), rgb255(m.body), rgb255(m.wisp), rgb255(m.line)) == \
        ([0, 3, 16], [5, 22, 80], [44, 130, 245], [170, 220, 255])


def test_other_power_palette_is_derived(D):
    p = D.OrbPalette("RAGE")  # ORB_COLORS.RAGE = 0.62, 0.08, 0.05
    assert abs(p.deep[1] - 0.62 * 0.08) < 1e-9 and abs(p.body[1] - 0.62 * 0.35) < 1e-9
    assert abs(p.wisp[1] - (0.62 + 0.38 * 0.10)) < 1e-9 and abs(p.line[1] - (0.62 + 0.38 * 0.55)) < 1e-9
