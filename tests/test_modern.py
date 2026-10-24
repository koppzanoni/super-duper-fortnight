"""HUD style "Moderno" (docs/superpowers/specs/2026-10-23-hud-moderno-design.md)."""
import sys

from conftest import ROOT, load_addon_file, new_runtime, toc_files

sys.path.insert(0, str(ROOT / "tools"))
import export_textures as ex  # noqa: E402
import modern_art  # noqa: E402


def data():
    rt = new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table()).Data


def box(r):
    """A Data rect {x, y, w, h} as modern_art's (x0, y0, x1, y1)."""
    return (r.x, r.y, r.x + r.w, r.y + r.h)


def test_unit_spec_matches_the_art():
    s = data().MODERN_UNIT
    u = modern_art.UNIT
    assert (s.w, s.h) == (u["w"], u["h"])
    for key in ("portrait", "health", "power", "name", "level", "ring"):
        assert box(s[key]) == u[key], key


def test_cast_spec_matches_the_art():
    s = data().MODERN_CAST
    c = modern_art.CASTBAR
    assert (s.w, s.h) == (c["w"], c["h"])
    for key in ("icon", "bar", "name"):
        assert box(s[key]) == c[key], key


def test_minimap_spec_matches_the_art():
    s = data().MODERN_MAP
    m = modern_art.MAP
    assert (s.w, s.h) == (m["w"], m["h"])
    for key in ("hole", "plate", "button"):
        assert box(s[key]) == m[key], key


def test_modern_textures_are_exported(tmp_path):
    manifest = ex.export_all(tmp_path)
    for name in ("mod_unit", "mod_cast", "mod_slot", "mod_map", "mod_menu"):
        for color in ("", "_black"):
            assert name + color in manifest, name + color
    assert manifest["mod_unit"]["w"] == modern_art.UNIT["w"]
    assert "mod_arcane" in manifest and "mod_gloss" in manifest


def loaded(lua, ns, db=None):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    for k, v in (db or {}).items():
        ns.db[k] = v
    return ns


def test_stone_stays_the_default(lua, ns):
    loaded(lua, ns)
    assert ns.db.hudTheme == "obsidian"
    assert ns.db.modernColor == "black"
    assert ns.db.arcaneRing is True
    assert (ns.db.modernRows, ns.db.modernCols) == (2, 12)


# ------------------------------------------------------------------ action bar grid
import preview_render  # noqa: E402


def preview(db=None, vbars=False):
    rt = preview_render.run_addon(vbars=vbars, db=db)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


MODERN = {"hudTheme": "modern"}


def test_bar_geometry(pure):
    from conftest import load_pure
    L = load_pure(pure, "Core/Layout.lua").Layout
    g = L.ModernBar(1080, 1, 2, 12)
    assert (g.slot, g.gap, g.numbers, g.bottom) == (54, 7, 18, 14)
    assert g.width == 12 * 54 + 11 * 7 and g.height == 18 + 2 * 54 + 7
    small = L.ModernBar(1080, 0.5, 3, 4)
    assert small.slot == 27 and small.height == 9 + 3 * 27 + 2 * 3.5


def test_stone_hud_stays_as_it_was():
    _, ns = preview()
    assert ns.HUD.art.shown and ns.HUD.under.shown
    assert not ns.HUD.modern


def test_modern_hides_the_stone_hud():
    _, ns = preview(MODERN)
    assert ns.HUD.modern
    assert not ns.HUD.art.shown and not ns.HUD.under.shown


def test_modern_bar_is_a_grid_in_reading_order():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons
    row1 = [rect(b[i]) for i in range(1, 13)]
    row2 = [rect(b[i]) for i in range(19, 31)]
    assert len({round(r[1]) for r in row1}) == 1 and len({round(r[1]) for r in row2}) == 1
    assert row1[0][1] > row2[0][1]                            # main bar on top
    steps = {round(row1[i + 1][0] - row1[i][0], 1) for i in range(11)}
    assert steps == {54 + 7}
    # centered at the bottom of the screen
    left, right = row1[0][0], row1[-1][0] + row1[-1][2]
    assert abs((left + right) / 2 - 960) < 1


def test_buttons_outside_the_grid_are_hidden_and_unbound():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons
    for i in list(range(13, 19)) + list(range(31, 37)):
        assert b[i].obEnabled is False and not b[i].IsVisible(b[i]), i
    for i in list(range(1, 13)) + list(range(19, 31)):
        assert b[i].obEnabled is True and b[i].IsVisible(b[i]), i


def test_rows_and_columns_come_from_the_settings():
    _, ns = preview({"hudTheme": "modern", "modernRows": 3, "modernCols": 12})
    b = ns.ActionBars.buttons
    assert all(b[i].obEnabled for i in range(1, 37))
    assert rect(b[13])[1] < rect(b[19])[1]                    # bottom left bar is the third row


def test_slots_have_frames_in_the_chosen_colour():
    _, ns = preview(MODERN)
    slot = ns.ActionBars.buttons[1].obModernSlot
    assert slot.IsVisible(slot) and str(slot.file).endswith("mod_slot_black")
    _, ns = preview({"hudTheme": "modern", "modernColor": "blue"})
    assert str(ns.ActionBars.buttons[1].obModernSlot.file).endswith("mod_slot")


def test_key_numbers_sit_above_the_first_row():
    _, ns = preview(MODERN)
    b = ns.ActionBars.buttons[1]
    hk = b.HotKey
    assert hk.points[1].point == "BOTTOM" and hk.points[1].relPoint == "TOP"


# ------------------------------------------------------------------ the rest of the stone HUD
def visible(region):
    return bool(region.IsVisible(region))


def test_orb_numbers_and_orb_status_icons_are_hidden():
    _, ns = preview(MODERN)
    assert not visible(ns.Orbs.health.pct) and not visible(ns.Orbs.power.val)
    assert not visible(ns.PlayerStatus.holder)
    _, ns = preview()
    assert visible(ns.Orbs.health.pct) and visible(ns.PlayerStatus.holder)


def test_xp_bar_runs_under_the_action_bar():
    _, ns = preview(MODERN)
    bar = rect(ns.ActionBars.modernFrame)
    xp = rect(ns.XPBar.xp)
    assert xp[1] + xp[3] <= bar[1]                            # below the slots
    assert abs(xp[0] - bar[0]) < 1 and abs(xp[2] - bar[2]) < 1


def test_menu_is_one_row_at_the_bottom_right():
    _, ns = preview(MODERN)
    shown = [ns.MenuPanels.byId[i] for i in ns.Data.MODERN_MENU.values()]
    rects = [rect(b) for b in shown]
    assert all(visible(b) for b in shown)
    assert len({round(r[1]) for r in rects}) == 1             # one row
    assert all(rects[i + 1][0] > rects[i][0] for i in range(len(rects) - 1))
    assert rects[-1][0] + rects[-1][2] <= 1920 and rects[0][0] > 1300
    assert not visible(ns.MenuPanels.byId["bag1"])
    assert visible(ns.MenuPanels.band) and str(ns.MenuPanels.band.file).endswith("mod_menu_black")
