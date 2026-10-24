"""Nameplates (HUD/Nameplates.lua) in the Moderno look over the game's own plates."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

PRE = "function UnitCastingDuration() return nil end"


def preview(db=None, n=3):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=PRE)
    rt.execute(f"PREVIEW_PLATES({n})")
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def plate(ns, i):
    return ns.Nameplates.plates[f"nameplate{i}"]


def colour(bar):
    return list(bar.GetStatusBarTexture(bar).vc.values())[:3]


def test_our_plate_replaces_the_games_look():
    rt, ns = preview()
    p = plate(ns, 1)
    assert visible(p) and p.name.text == "Ravenfang Alpha"
    assert p.health.value == 770 and p.health.max == 1000
    game = rt.globals().PLATES.nameplate1.UnitFrame
    assert game.alpha == 0


def test_colour_by_reaction():
    _, ns = preview()
    r, g, b = colour(plate(ns, 2).health)
    assert r > g                                                       # hostile red
    r, g, b = colour(plate(ns, 3).health)
    assert r > 0.6 and g > 0.5 and b < 0.4                             # neutral yellow


def test_health_percent_text():
    _, ns = preview()
    assert plate(ns, 1).hp.text == "77%"
    _, ns = preview({"plateHP": False})
    assert not visible(plate(ns, 1).hp)


def test_target_stands_out_and_others_fade():
    _, ns = preview()
    t, o = plate(ns, 1), plate(ns, 2)
    assert visible(t.glow) and not visible(o.glow)
    assert (t.alpha or 1) == 1 and o.alpha < 1
    _, ns = preview({"plateFade": False})
    assert (plate(ns, 2).alpha or 1) == 1


def test_cast_bar_interruptible_and_locked():
    _, ns = preview()
    c2, c3 = plate(ns, 2).cast, plate(ns, 3).cast
    assert visible(c2) and c2.text.text == "Raio Sombrio" and not visible(plate(ns, 1).cast)
    blue, grey = colour(c2), colour(c3)
    assert blue[2] > blue[0] and abs(grey[0] - grey[2]) < 0.1
    assert abs(c2.value - 0.5) < 0.01                                  # half way (fake times)
    rcast = rect(c2)
    assert rcast[1] + rcast[3] <= rect(plate(ns, 2).health)[1] + 0.5   # under the health bar


def test_cast_stops():
    rt, ns = preview()
    rt.execute('PLATE_UNITS.nameplate2.cast = nil; PREVIEW_FIRE("UNIT_SPELLCAST_STOP", "nameplate2")')
    assert not visible(plate(ns, 2).cast)


def test_marker_and_debuffs():
    rt, ns = preview()
    assert visible(plate(ns, 1).marker) and not visible(plate(ns, 2).marker)
    _, ns = preview({"plateCast": False})
    assert not visible(plate(ns, 2).cast)


def test_unit_removed_hides_ours():
    rt, ns = preview()
    p = plate(ns, 2)
    rt.execute('PREVIEW_FIRE("NAME_PLATE_UNIT_REMOVED", "nameplate2")')
    assert not visible(p) and ns.Nameplates.plates.nameplate2 is None


def test_size_settings_and_switch_off_gives_the_game_back():
    rt, ns = preview({"plateW": 180, "plateH": 14})
    p = plate(ns, 1)
    w, h = rect(p.health)[2:]
    assert abs(w - 180) < 1 and abs(h - 14) < 1
    ns.db.plates_on = False
    ns.Nameplates.Refresh()
    assert not visible(p) and rt.globals().PLATES.nameplate1.UnitFrame.alpha == 1


def test_panel_page():
    _, ns = preview()
    ns.Panel.Open("plates")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Largura")
    row.control.plus.GetScript(row.control.plus, "OnClick")(row.control.plus)
    assert ns.db.plateW == 150
