"""The druid's extras (Classes/Druid.lua): mana in animal forms, form bar, cat energy tick, combo points
only in cat form, five second rule."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "DRUID"
function UnitClass(u) if u == "player" or u == nil then return "Druida", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
FORM = 3 -- power type now: 3 energy (cat), 1 rage (bear), 0 mana (caster)
MANA, ENERGY = 2500, 40
local bP, bPM, bPT = UnitPower, UnitPowerMax, UnitPowerType
function UnitPowerType(u) if u == "player" then return FORM, ({ [0] = "MANA", [1] = "RAGE", [3] = "ENERGY" })[FORM] end return bPT(u) end
function UnitPower(u, t)
  if u == "player" then
    if t == nil then t = FORM end
    if t == 0 then return MANA elseif t == 3 then return ENERGY elseif t == 4 then return 2 end
  end
  return bP(u, t)
end
function UnitPowerMax(u, t)
  if u == "player" then
    if t == nil then t = FORM end
    if t == 0 then return 5000 elseif t == 3 then return 100 elseif t == 4 then return 5 end
  end
  return bPM(u, t)
end
StanceBar = CreateFrame("Frame", "StanceBar", UIParent)
StanceBar:SetSize(90, 30)
C_Spell = { GetSpellName = function() return nil end, GetSpellTexture = function(id) return "ICON:" .. id end,
  GetSpellPowerCost = function() return { { type = 0, cost = 80 } } end }
"""


def preview(db=None, cls="DRUID", form=3):
    pre = GAME.replace('CLASS = "DRUID"', f'CLASS = "{cls}"').replace("FORM = 3", f"FORM = {form}")
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def shift(g, form):
    g.FORM = form
    g.PREVIEW_FIRE("UPDATE_SHAPESHIFT_FORM")
    g.PREVIEW_FIRE("UNIT_DISPLAYPOWER", "player")


def test_page_has_the_druid_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Mana enquanto está em forma animal", "Barra de formas", "Tick de energia em Felino",
                  "Pontos de combo só em Felino", "Regra dos 5 segundos"):
        assert label in labels, label


def test_mana_bar_in_animal_forms():
    _, ns, g = preview()
    m = ns.Druid.mana
    assert visible(m) and m.GetValue(m) == 2500 and m.GetMinMaxValues(m)[1] == 5000
    p = ns.UnitFrames.frames.player.power
    assert rect(m)[1] + rect(m)[3] <= rect(p)[1] + 0.5
    shift(g, 0)                                              # caster form: the power bar is mana already
    assert not visible(m)
    shift(g, 1)
    assert visible(m)
    _, ns, g = preview({"c_dru_mana": False})
    assert not visible(ns.Druid.mana)


def test_form_bar_under_the_player_frame_by_default():
    _, ns, g = preview()
    sb, pr = rect(g.StanceBar), rect(ns.UnitFrames.frames.player)
    assert sb[1] + sb[3] <= pr[1] + 1 and sb[1] > pr[1] - 80
    _, ns, g = preview({"c_dru_forms": False})
    assert rect(g.StanceBar)[1] < 300


def test_energy_tick_in_cat_form_only():
    _, ns, g = preview()
    e = ns.EnergyTick
    for v, t in ((40, 1000), (60, 1000.2)):
        g.ENERGY, g.NOW = v, t
        g.PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "ENERGY")
    g.NOW = 1001
    e.frame.GetScript(e.frame, "OnUpdate")(e.frame, 0.1)
    assert visible(e.spark)
    shift(g, 1)
    e.frame.GetScript(e.frame, "OnUpdate")(e.frame, 0.1)
    assert not visible(e.spark)


def test_combo_points_only_in_cat_unless_asked():
    _, ns, g = preview(form=1)
    assert not visible(ns.ClassResource.holder)              # bear: no combo points
    _, ns, g = preview({"c_dru_combo": False}, form=1)
    assert visible(ns.ClassResource.holder)                  # kept in every form


def test_five_second_rule_in_caster_form():
    _, ns, g = preview(form=0)
    g.PREVIEW_FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "C", 5185)
    g.NOW = 1001
    f = ns.FiveSecond.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)
    assert visible(ns.FiveSecond.spark)


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="ROGUE")
    assert not visible(ns.Druid.mana)
