"""Edit mode (Unlock Mode, spec docs/superpowers/plans/2026-10-23-hud-moderno-pendencias.md): every HUD
element can be dragged, snapped, resized and nudged; positions and sizes are saved per element."""
import sys

from conftest import ROOT, load_pure

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

KEYS = {"player", "target", "targettarget", "focus", "pet", "bar", "cast", "map", "menu", "buffs", "vbars", "info", "res", "databars", "party", "raid"}


def preview(db=None, vbars=False):
    rt = preview_render.run_addon(vbars=vbars, db=db)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


# ------------------------------------------------------------------ snapping (pure)
def test_snaps_to_the_grid_when_nothing_is_near(pure):
    L = load_pure(pure, "Core/Layout.lua").Layout
    x, y, gx, gy = L.Snap(103, 517, 50, 20, pure.table(), 8, 6, 1920, 1080)
    assert (x, y) == (104, 520) and gx is None and gy is None


def test_snaps_edges_and_centers_to_other_elements(pure):
    L = load_pure(pure, "Core/Layout.lua").Layout
    other = pure.table_from({1: pure.table_from({"x": 300, "y": 800, "w": 100, "h": 40})})
    # left edge 4 px from the other's right edge (400): it sticks there, with a guide line
    x, y, gx, gy = L.Snap(404, 600, 80, 30, other, 8, 6, 1920, 1080)
    assert x == 400 and gx == 400
    # top 1 px under the other's top (800), nearer than any other edge or center
    x, y, gx, gy = L.Snap(700, 799, 80, 30, other, 8, 6, 1920, 1080)
    assert y == 800 and gy == 800


def test_snaps_to_the_screen_center(pure):
    L = load_pure(pure, "Core/Layout.lua").Layout
    x, y, gx, gy = L.Snap(912, 300, 100, 20, pure.table(), 8, 6, 1920, 1080)   # center at 962
    assert x == 910 and gx == 960


# ------------------------------------------------------------------ saved layout
def test_every_element_is_registered():
    _, ns = preview()
    assert set(ns.Movers['items'].keys()) == KEYS


def test_saved_position_and_size_are_applied():
    _, ns = preview({"layout": {"player": {"x": 500, "y": 900, "s": 1.2}}})
    p = ns.UnitFrames.frames.player
    r = rect(p)
    assert abs(r[0] - 500) < 0.5 and abs(r[1] + r[3] - 900) < 0.5
    _, base = preview()
    assert abs(r[2] - rect(base.UnitFrames.frames.player)[2] * 1.2) < 0.5


def test_without_a_saved_position_the_default_stays():
    _, ns = preview()
    r = rect(ns.UnitFrames.frames.player)
    assert r[0] < 40 and r[1] + r[3] > 1040


def test_moving_the_bar_takes_its_buttons_xp_cast_and_stack_along():
    _, ns = preview({"layout": {"bar": {"x": 200, "y": 400}}})
    bar = rect(ns.ActionBars.modernFrame)
    assert abs(bar[0] - 200) < 0.5 and abs(bar[1] + bar[3] - 400) < 0.5
    b1 = rect(ns.ActionBars.buttons[1])
    assert bar[0] < b1[0] < bar[0] + 60
    xp = rect(ns.XPBar.xp)
    assert abs(xp[0] - bar[0]) < 0.5 and xp[1] < bar[1]
    cast = rect(ns.CastBar.art)
    assert cast[1] > bar[1] + bar[3] and abs((cast[0] + cast[2] / 2) - (bar[0] + bar[2] / 2)) < 1


def test_bar_size_changes_the_slots():
    _, ns = preview({"layout": {"bar": {"s": 0.5}}})
    assert abs(ns.HUD.modernBar.slot - 27) < 0.01


# ------------------------------------------------------------------ edit mode
def test_start_shows_a_box_over_each_element():
    _, ns = preview()
    ns.EditMode.Start()
    assert ns.EditMode.active
    for key, item in ns.Movers['items'].items():
        box = ns.EditMode.boxes[key]
        if visible(item.box):
            assert visible(box), key
            a, b = rect(box), rect(item.box)
            # same top-left; thin elements get a box of at least 24 x 16 to grab
            w, h = max(b[2], 24), max(b[3], 16)
            assert abs(a[0] - b[0]) < 1 and abs(a[1] + a[3] - b[1] - b[3]) < 1, key
            assert abs(a[2] - w) < 1 and abs(a[3] - h) < 1, key
    assert visible(ns.EditMode.grid)


def test_moving_saves_and_places_the_element():
    _, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.MoveTo("map", 1000, 700)
    m = rect(ns.Minimap.frame)
    assert abs(m[0] - 1000) < 0.5 and abs(m[1] + m[3] - 700) < 0.5
    saved = ns.db.layout.map
    assert abs(saved.x - 1000) < 0.5 and abs(saved.y - 700) < 0.5


def test_wheel_resizes_and_arrows_nudge():
    _, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.Select("player")
    before = rect(ns.UnitFrames.frames.player)
    ns.EditMode.Resize("player", 1)                 # one wheel step up
    assert abs(ns.db.layout.player.s - 1.05) < 1e-9
    after = rect(ns.UnitFrames.frames.player)
    assert after[2] > before[2]
    ns.EditMode.Nudge(10, -1)
    now = rect(ns.UnitFrames.frames.player)
    assert abs(now[0] - after[0] - 10) < 0.5 and abs((now[1] + now[3]) - (after[1] + after[3]) + 1) < 0.5


def test_center_and_reset():
    _, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.MoveTo("menu", 100, 500)
    ns.EditMode.Center("menu")
    r = rect(ns.MenuPanels.bandFrame)
    assert abs(r[0] + r[2] / 2 - 960) < 1
    ns.EditMode.Reset("menu")
    assert ns.db.layout.menu is None
    r = rect(ns.MenuPanels.bandFrame)
    assert r[0] + r[2] > 1900


def test_combat_ends_edit_mode():
    rt, ns = preview()
    ns.EditMode.Start()
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_DISABLED")')
    assert not ns.EditMode.active and not visible(ns.EditMode.grid)


def test_slash_command_starts_it():
    rt, ns = preview()
    rt.globals().SlashCmdList.OBSIDIANUI("editar")
    assert ns.EditMode.active


def test_reset_command_forgets_the_edit_mode_positions():
    rt, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.MoveTo("map", 1000, 700)
    ns.EditMode.Stop()
    rt.globals().SlashCmdList.OBSIDIANUI("reset")
    assert ns.db.layout is None
    assert rect(ns.Minimap.frame)[0] + rect(ns.Minimap.frame)[2] > 1880
