import pytest

from conftest import load_pure


@pytest.fixture
def L(pure):
    return load_pure(pure, "Core/Layout.lua").Layout


def test_rect_scales(L):
    assert L.Rect(2692, 381, 1346, 190.5, 710, 114, 56, 61) == (355, -57, 28, 30.5)


def test_mirror(L):
    assert L.MirrorX(2692, 710, 56) == 1926

