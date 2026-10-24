"""Moderno inventory (Inventory/Window.lua + BagGrid.lua): one wide black window, the character
on the left and the bags on the right (prototype in the sketch, 1240 x 780)."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

PRE = "function GetAverageItemLevel() return 214.6, 208.2 end"


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, inventory=True, db=dict({"installed": True}, **(db or {})), pre=PRE)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def items(ns):
    return sorted((b for b in ns.Inventory.bagButtons().values() if visible(b)), key=lambda b: (-rect(b)[1], rect(b)[0]))


def test_one_wide_black_window():
    _, ns = preview()
    I = ns.Inventory
    x, y, w, h = rect(I.frame)
    assert abs(w / h - 1240 / 780) < 0.01
    assert visible(I.backdrop)
    assert I.statsPanel.GetParent(I.statsPanel) is not None
    # no wing outside the window any more
    sx, sy, sw, sh = rect(I.statsPanel)
    assert sx >= x - 0.5 and sx + sw <= x + w + 0.5


def test_character_on_the_left_bags_on_the_right():
    _, ns = preview()
    I = ns.Inventory
    sep = rect(I.separator)[0]
    model = rect(I.model)
    assert model[0] + model[2] < sep
    first = items(ns)[0]
    assert rect(first)[0] > sep and rect(I.searchBox)[0] > sep


def test_equipment_beside_the_model_and_weapons_below():
    _, ns = preview()
    I = ns.Inventory
    model = rect(I.model)
    slots = [b for b in I.slotButtons.values() if visible(b)]
    left = [b for b in slots if rect(b)[0] + rect(b)[2] <= model[0] + 0.5]
    right = [b for b in slots if rect(b)[0] >= model[0] + model[2] - 0.5]
    below = [b for b in slots if b not in left and b not in right and rect(b)[1] + rect(b)[3] <= model[1] + 0.5]
    assert len(left) == 8 and len(right) == 8 and len(below) == 3
    assert len({round(rect(b)[2]) for b in left + right}) == 1                 # one size per column
    assert str(slots[0].border.file).endswith("mod_slot_black")


def test_bag_grid_has_nine_columns():
    _, ns = preview()
    it = items(ns)
    assert len(it) >= 10
    assert abs(rect(it[0])[1] - rect(it[8])[1]) < 0.5 and rect(it[9])[1] < rect(it[0])[1]
    assert str(it[0].obBorder.file).endswith("mod_slot_black")


def test_bag_bar_tabs_and_footer():
    _, ns = preview()
    I = ns.Inventory
    search, sort = rect(I.searchBox), rect(I.sortButton)
    assert abs(search[1] - sort[1]) < 0.5 and sort[0] > search[0]
    tabs = [t for t in I.filterTabs.values() if visible(t)]
    assert len(tabs) == 5 and rect(tabs[0])[1] < search[1]
    grid_top = max(rect(b)[1] + rect(b)[3] for b in items(ns))
    assert grid_top <= rect(tabs[0])[1]
    bags = [b for b in I.footerBags.values() if visible(b)]
    assert len(bags) == 5 and all(rect(b)[1] + rect(b)[3] < rect(I.gridArea)[1] for b in bags)
    assert "Livres" in I.freeText.text and visible(I.gold)


def test_stats_in_two_columns_under_the_character_tabs():
    _, ns = preview()
    I = ns.Inventory
    names = [t.text.text for t in I.charTabs.values()]
    assert names == ["Atributos", "Reputação", "Moedas"]
    lines = [l for l in I.statLines.values() if visible(l.label) and l.key]
    xs = sorted({round(rect(l.label)[0]) for l in lines})
    assert len(xs) == 2                                                        # two columns
    tab_bottom = rect(I.charTabs[1])[1]
    assert all(rect(l.label)[1] + rect(l.label)[3] <= tab_bottom + 0.5 for l in lines)
    weapons_bottom = min(rect(b)[1] for b in I.slotButtons.values() if visible(b))
    assert tab_bottom + rect(I.charTabs[1])[3] <= weapons_bottom + 0.5


def test_head_name_level_class_item_level_and_close():
    _, ns = preview()
    I = ns.Inventory
    assert I.titleText.text == "Você"
    assert "58" in I.subText.text and "Ladino" in I.subText.text
    assert I.itemLevel.text == "208"
    close = I.closeButton
    close.GetScript(close, "OnClick")(close)
    assert not visible(I.frame)


def test_default_place_centred_above_the_hud():
    _, ns = preview()
    point, x, y, h = ns.Inventory.DefaultPlacement(1920.0, 1080.0, 270.0)
    assert point == "BOTTOM" and x == 0 and y >= 270 and y + h <= 1080
    w = h * 1240 / 780
    assert w <= 0.9 * 1920
