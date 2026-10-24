"""Class resource (HUD/ClassResource.lua) and auras (HUD/Auras.lua) in the Moderno look, with options."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# A rogue with 3 of 5 combo points.
ROGUE = """
  POWER = 3; COMBAT = true
  function UnitClass() return "Ladino", "ROGUE" end
  function UnitPowerType(u) if u == "pet" then return 2, "FOCUS" end return 3, "ENERGY" end
  local up, upm = UnitPower, UnitPowerMax
  function UnitPower(u, t) if t == 4 then return POWER end return up(u, t) end
  function UnitPowerMax(u, t) if t == 4 then return 5 end return upm(u, t) end
  function UnitAffectingCombat() return COMBAT end
"""


def preview(db=None, pre=ROGUE):
    rt = preview_render.run_addon(vbars=False, db=db, pre=pre)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def gems(ns):
    return [g for g in ns.ClassResource.gems.values() if visible(g)]


# ------------------------------------------------------------------ class resource
def test_gems_in_the_modern_look():
    _, ns = preview()
    g = gems(ns)
    assert len(g) == 5
    assert sum(str(x.file).endswith("mod_gem_on") for x in g) == 3
    assert sum(str(x.file).endswith("mod_gem_off_black") for x in g) == 2


def test_bar_style():
    _, ns = preview({"resStyle": "bar"})
    bar = ns.ClassResource.bar
    assert visible(bar) and gems(ns) == []
    assert bar.value == 3 and bar.max == 5
    ticks = [t for t in ns.ClassResource.ticks.values() if visible(t)]
    assert len(ticks) == 4                                   # a line between each point


def test_colour_override():
    _, ns = preview({"colors": {"COMBO_POINTS": [0, 1, 0]}})
    lit = [x for x in gems(ns) if str(x.file).endswith("mod_gem_on")][0]
    assert list(lit.vc.values())[:3] == [0, 1, 0]


def test_hidden_out_of_combat_when_empty():
    rt, ns = preview({"resHide": True})
    assert visible(ns.ClassResource.holder)
    rt.globals().POWER, rt.globals().COMBAT = 0, False
    rt.execute('PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")')
    assert not visible(ns.ClassResource.holder)
    rt.globals().COMBAT = True
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_DISABLED")')
    assert visible(ns.ClassResource.holder)


def test_switched_off():
    _, ns = preview({"res_on": False})
    assert not visible(ns.ClassResource.holder)


def test_movable_and_resizable_in_edit_mode():
    _, ns = preview()
    w = rect(ns.ClassResource.holder)[2]
    ns.EditMode.Start()
    ns.EditMode.MoveTo("res", 300, 600)
    ns.EditMode.Resize("res", 1)
    r = rect(ns.ClassResource.holder)
    assert abs(r[0] - 300) < 1 and r[2] > w


# ------------------------------------------------------------------ auras
def buffs(ns):
    return [b for b in ns.Auras.rows.HELPFUL.buttons.values() if visible(b)]


def test_aura_borders_in_the_modern_look():
    _, ns = preview()
    b = buffs(ns)[0]
    assert str(b.border.file).endswith("mod_slot_black")


def test_aura_size_and_per_row():
    _, ns = preview({"buffSize": 40, "buffRow": 2})
    b = buffs(ns)
    assert abs(rect(b[0])[2] - 40 * 1080 / 900) < 1
    assert abs(rect(b[0])[1] - rect(b[1])[1]) < 0.5 and rect(b[2])[1] < rect(b[0])[1]   # third wraps


def test_buffs_and_debuffs_switch_off():
    _, ns = preview({"buffs_on": False})
    assert buffs(ns) == []
    _, ns = preview({"debuffs_on": False})
    assert [b for b in ns.Auras.rows.HARMFUL.buttons.values() if visible(b)] == []


def test_panel_pages_exist_and_apply_live():
    _, ns = preview()
    ns.Panel.Open("resources")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Estilo")
    bar = next(b for b in row.control.buttons.values() if b.value == "bar")
    bar.GetScript(bar, "OnClick")(bar)
    assert visible(ns.ClassResource.bar)
    ns.Panel.Open("auras")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Tamanho dos ícones")
    row.control.plus.GetScript(row.control.plus, "OnClick")(row.control.plus)
    assert ns.db.buffSize == 28
