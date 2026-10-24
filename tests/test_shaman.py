"""The shaman's extras (Classes/Shaman.lua): totem bar, weapon imbue, Lightning/Water Shield, five second rule."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "SHAMAN"
function UnitClass(u) if u == "player" or u == nil then return "Xamã", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
TOTEMS = { { true, "Totem Searing", 990, 60, "ICON:2" }, { false }, { true, "Totem de Corrente de Cura", 995, 120, "ICON:5" }, { false } }
function GetTotemInfo(i) local t = TOTEMS[i]; return t[1], t[2], t[3], t[4], t[5] end
ENCHANT = { false, 0 }
function GetWeaponEnchantInfo() return ENCHANT[1], ENCHANT[2] end
KNOWN = { [8017] = true, [324] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [324] = "Escudo de Raios", [52127] = "Escudo d'Água", [8017] = "Arma Dentefirme" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end,
  GetSpellPowerCost = function() return { { type = 0, cost = 50 } } end }
AURAS = {}
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if unit ~= "player" or filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
"""


def preview(db=None, cls="SHAMAN"):
    pre = GAME.replace('CLASS = "SHAMAN"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def totems(g):
    g.PREVIEW_FIRE("PLAYER_TOTEM_UPDATE", 1)


# ---------------------------------------------------------------- page
def test_page_has_the_shaman_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Barra de totens", "Onde", "Arma encantada acabando", "Escudo de Raios / Água", "Regra dos 5 segundos"):
        assert label in labels, label


# ---------------------------------------------------------------- totems
def test_totem_bar_shows_each_element_with_its_time():
    _, ns, g = preview()
    totems(g)
    bar, slots = ns.Shaman.totems, ns.Shaman.slots
    assert visible(bar)
    assert slots[1].icon.file == "ICON:2" and slots[1].icon.alpha == 1
    assert slots[1].cd.cdStart == 990 and slots[1].cd.cdDuration == 60   # the game counts it down
    assert slots[2].icon.alpha < 1                                        # empty element: dim
    assert slots[3].icon.file == "ICON:5"


def test_totem_bar_hidden_without_totems_and_when_off():
    rt, ns, g = preview()
    rt.execute("TOTEMS = { { false }, { false }, { false }, { false } }")
    totems(g)
    assert not visible(ns.Shaman.totems)
    _, ns, g = preview({"c_sha_totems": False})
    totems(g)
    assert not visible(ns.Shaman.totems)


def test_totem_bar_place():
    _, ns, g = preview()
    totems(g)
    t, p = rect(ns.Shaman.totems), rect(ns.UnitFrames.frames.player)
    assert t[1] + t[3] <= p[1] + 1 and t[1] > p[1] - 90                    # under the player frame
    _, ns, g = preview({"c_sha_totpos": "bar"})
    totems(g)
    t, b = rect(ns.Shaman.totems), rect(ns.ActionBars.modernFrame)
    assert b[1] + b[3] < t[1] < b[1] + b[3] + 120                          # just above the action bar
    assert abs((t[0] + t[2] / 2) - (b[0] + b[2] / 2)) < 2


# ---------------------------------------------------------------- weapon and shield (reminders)
def test_weapon_imbue_reminder():
    rt, ns, g = preview()
    rt.execute("AURAS = { 'Escudo de Raios' }")
    k = keys(ns)
    assert "weapon" in k and "poison" not in k                            # one reminder, not two
    g.ENCHANT = rt.eval("{ true, 20 * 60 * 1000 }")
    assert "weapon" not in keys(ns)
    g.ENCHANT = rt.eval("{ true, 60 * 1000 }")
    assert "weapon" in keys(ns)
    _, ns, g = preview({"c_sha_weapon": False})
    assert "weapon" not in keys(ns)


def test_shield_reminder():
    rt, ns, g = preview()
    assert "shashield" in keys(ns)
    rt.execute("AURAS = { [[Escudo d'Água]] }")
    assert "shashield" not in keys(ns)
    _, ns, g = preview({"c_sha_shield": False})
    assert "shashield" not in keys(ns)


# ---------------------------------------------------------------- five second rule
def test_five_second_rule_for_shamans():
    _, ns, g = preview()
    g.PREVIEW_FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "C", 331)
    g.NOW = 1001
    f = ns.FiveSecond.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)
    assert visible(ns.FiveSecond.spark)


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="MAGE")
    totems(g)
    assert not visible(ns.Shaman.totems)
    k = keys(ns)
    assert "weapon" not in k and "shashield" not in k
