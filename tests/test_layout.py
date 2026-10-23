import pytest

from conftest import load_pure


@pytest.fixture
def L(pure):
    return load_pure(pure, "Core/Layout.lua").Layout


def test_rect_scales(L):
    assert L.Rect(2692, 381, 1346, 190.5, 710, 114, 56, 61) == (355, -57, 28, 30.5)


def test_mirror(L):
    assert L.MirrorX(2692, 710, 56) == 1926


def test_hud_size_16_9(L):
    h, u, stretch = L.HudSize(1920, 1080, 1)
    assert h == pytest.approx(270)
    assert stretch == pytest.approx(10.39, abs=0.01)


def test_hud_size_21_9(L):
    h, u, stretch = L.HudSize(2560, 1080, 1)
    assert h == pytest.approx(270)
    assert stretch == pytest.approx(330.39, abs=0.01)


def test_hud_size_16_10(L):
    h, u, stretch = L.HudSize(1920, 1200, 1)
    assert h == pytest.approx(272.96, abs=0.01)
    assert stretch == pytest.approx(0, abs=0.01)


def test_hud_size_user_scale_never_overflows_width(L):
    h, u, stretch = L.HudSize(1920, 1080, 1.4)
    assert 1340 * u <= 960 + 1e-6
    assert stretch == pytest.approx(0, abs=0.01)


def test_mapx(L):
    u = 270 / 381
    assert L.MapX(656, 1920, u) == pytest.approx(464.88, abs=0.01)
    assert L.MapX(1346, 1920, u) == pytest.approx(960)

