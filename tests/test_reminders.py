"""Reminders (HUD/Reminders.lua): class buff, food and flask in raids, poisons/oils, durability, bags."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "MAGE"
function UnitClass() return "Mago", CLASS end
KNOWN = { [1459] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [1459] = "Intelecto Arcano", [23028] = "Brilho Arcano", [21562] = "Palavra de Poder: Fortitude",
  [1126] = "Marca da Natureza", [6673] = "Brado de Batalha", [19705] = "Bem Alimentado",
  [315584] = "Veneno Instantâneo", [2823] = "Veneno Mortal", [3408] = "Veneno Aleijante" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end }
AURAS = {}
function PREVIEW_SET_AURAS(list) AURAS = list end
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if unit ~= "player" or filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, a in ipairs(AURAS) do out[i] = { name = a[1], expirationTime = a[2] or 0, duration = a[3] or 0 } end
  return out
end
NOW = 1000
function GetTime() return NOW end
ENCHANT = { false, 0 }
function GetWeaponEnchantInfo() return ENCHANT[1], ENCHANT[2] end
DURA = 1
function GetInventoryItemDurability(slot) if slot == 5 then return math.floor(DURA * 100), 100 end end
FREE = 20
C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and FREE or 0 end
"""


def preview(db=None, group=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=GAME)
    g = rt.globals()
    if group:
        g.PREVIEW_ROSTER(*group)
    return rt, g.PREVIEW_NS, g


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def auras(rt, *names):
    rt.globals().PREVIEW_SET_AURAS(rt.eval("{" + ",".join("{%r}" % n for n in names) + "}"))


def visible(region):
    return bool(region.IsVisible(region))


def test_missing_class_buff():
    rt, ns, g = preview()
    assert "buff" in keys(ns)
    entry = next(e for e in ns.Reminders.List().values() if e.key == "buff")
    assert "Intelecto Arcano" in entry.text and entry.icon == "ICON:1459"
    auras(rt, "Intelecto Arcano")
    assert "buff" not in keys(ns)
    auras(rt, "Brilho Arcano")                              # the group version counts too
    assert "buff" not in keys(ns)


def test_no_buff_reminder_for_classes_without_one():
    rt, ns, g = preview()
    g.KNOWN = rt.eval("{}")                                  # mage below the level of the spell
    assert "buff" not in keys(ns)
    g.CLASS = "ROGUE"
    assert "buff" not in keys(ns)


def test_food_and_flask_only_in_raids():
    rt, ns, g = preview()
    auras(rt, "Intelecto Arcano")
    assert "food" not in keys(ns) and "flask" not in keys(ns)
    rt, ns, g = preview(group=("raid", 10))
    auras(rt, "Intelecto Arcano")
    assert "food" in keys(ns) and "flask" in keys(ns)
    auras(rt, "Intelecto Arcano", "Bem Alimentado", "Frasco do Titã")
    assert "food" not in keys(ns) and "flask" not in keys(ns)


def test_rogue_poisons():
    rt, ns, g = preview()
    g.CLASS, g.KNOWN = "ROGUE", rt.eval("{ [315584] = true }")
    assert "poison" in keys(ns)
    g.AURAS = rt.eval('{ { "Veneno Instantâneo", 1000 + 3600, 3600 } }')
    assert "poison" not in keys(ns)
    g.AURAS = rt.eval('{ { "Veneno Instantâneo", 1000 + 120, 3600 } }')    # two minutes left
    assert "poison" in keys(ns)


def test_weapon_oil_running_out():
    rt, ns, g = preview()
    auras(rt, "Intelecto Arcano")
    g.ENCHANT = rt.eval("{ true, 30 * 60 * 1000 }")
    assert "poison" not in keys(ns)
    g.ENCHANT = rt.eval("{ true, 90 * 1000 }")
    assert "poison" in keys(ns)


def test_durability_and_bags():
    rt, ns, g = preview()
    auras(rt, "Intelecto Arcano")
    assert keys(ns) == []
    g.DURA, g.FREE = 0.2, 2
    k = keys(ns)
    assert "repair" in k and "bags" in k
    texts = {e.key: e.text for e in ns.Reminders.List().values()}
    assert "20%" in texts["repair"] and "2" in texts["bags"]


def test_each_switch():
    rt, ns, g = preview({"rmBuff": False, "rmRepair": False, "rmBags": False})
    g.DURA, g.FREE = 0.2, 2
    assert keys(ns) == []


def test_chips_drawn_and_hidden_in_combat():
    rt, ns, g = preview()
    g.DURA = 0.2
    ns.Reminders.Update()
    chips = [c for c in ns.Reminders.chips.values() if visible(c)]
    assert len(chips) == 2                                   # buff + repair
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert not visible(ns.Reminders.frame)
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    assert visible(ns.Reminders.frame)


def test_nothing_is_checked_in_combat():
    rt, ns, g = preview()
    auras(rt, "Intelecto Arcano")
    ns.Reminders.Update()
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    g.InCombatLockdown = lambda: True
    auras(rt)                                                # aura data may be secret now
    ns.Reminders.Update()
    assert "buff" not in [e.key for e in ns.Reminders.List().values()]


def test_movable_in_edit_mode():
    _, ns, _ = preview()
    assert "reminders" in list(ns.Movers["items"].keys())


def test_panel_page():
    _, ns, _ = preview()
    ns.Panel.Open("reminders")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Buff da classe faltando", "Comida e frasco faltando em raide", "Veneno ou óleo de arma acabando",
                  "Durabilidade baixa", "Bolsas quase cheias"):
        assert label in labels, label
