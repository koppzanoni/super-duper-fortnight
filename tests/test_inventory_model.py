import pytest

from conftest import load_pure


@pytest.fixture
def inv(pure):
    return load_pure(pure, "Inventory/Filters.lua", "Inventory/GridModel.lua")


def slots(pure, items):
    """items: list of (bag, slot, classID or None)."""
    t = pure.table()
    for i, (bag, slot, cls) in enumerate(items, 1):
        e = pure.table()
        e.bag, e.slot, e.classID = bag, slot, cls
        t[i] = e
    return t


def keys(lua_list):
    return [(e.bag, e.slot) for e in lua_list.values()]


def test_category(inv):
    C = inv.Filters.Category
    assert C(2, 0) == "equip" and C(4, 1) == "equip"
    assert C(0, 0) == "consumable"
    assert all(C(c, 0) == "material" for c in (7, 5, 3, 8))
    assert C(2, 5) == "reagent"
    assert C(None, 0) == "other"


def test_tabs(inv):
    assert list(inv.Filters.TABS.values()) == ["all", "equip", "consumable", "material", "reagent"]
    assert inv.Filters.LABELS.all == "Tudo"


def test_build_all_keeps_bag_order(inv, pure):
    s = slots(pure, [(1, 2, 0), (0, 2, None), (0, 1, 2), (1, 1, 7)])
    assert keys(inv.GridModel.Build(s, "all")) == [(0, 1), (0, 2), (1, 1), (1, 2)]


def test_build_filter_excludes_empty(inv, pure):
    s = slots(pure, [(0, 1, 2), (0, 2, None), (0, 3, 0), (1, 1, 4)])
    assert keys(inv.GridModel.Build(s, "equip")) == [(0, 1), (1, 1)]


def test_grid_rows_min_and_growth(inv):
    R = inv.GridModel.Rows
    assert [R(10, 8), R(48, 8), R(49, 8), R(160, 8)] == [6, 6, 7, 20]


def test_grid_handles_missing_bag(inv, pure):
    s = slots(pure, [(0, 1, 2), (1, 1, 7)])
    assert keys(inv.GridModel.Build(s, "reagent")) == []


def test_pos(inv):
    P = inv.GridModel.Pos
    assert [P(1, 8), P(8, 8), P(9, 8)] == [(1, 1), (8, 1), (1, 2)]
