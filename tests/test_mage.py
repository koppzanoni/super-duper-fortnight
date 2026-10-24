"""The mage's extras (Classes/Mage.lua): five second rule, armor and mana gem reminders, proc alert."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "MAGE"
function UnitClass(u) if u == "player" or u == nil then return "Mago", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
KNOWN = { [168] = true, [759] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [168] = "Armadura de Gelo", [6117] = "Armadura de Mago", [57761] = "Congelamento Cerebral",
  [12536] = "Lançamento Livre", [759] = "Conjurar Ágata de Mana" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end,
  GetSpellPowerCost = function() return { { type = 0, cost = 50 } } end }
AURAS = {}
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if unit ~= "player" or filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
GEMS = {}
C_Item.GetItemCount = function(id) return GEMS[id] or 0 end
"""


def preview(db=None, cls="MAGE"):
    pre = GAME.replace('CLASS = "MAGE"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def visible(region):
    return bool(region.IsVisible(region))


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def test_page_has_the_mage_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Regra dos 5 segundos", "Lembrete de armadura", "Gemas de mana prontas",
                  "Procs (Congelamento Cerebral, Lançamento Livre)"):
        assert label in labels, label


def test_armor_reminder():
    rt, ns, g = preview()
    assert "armor" in keys(ns)
    rt.execute("AURAS = { 'Armadura de Mago' }")
    assert "armor" not in keys(ns)
    _, ns, g = preview({"c_mag_armor": False})
    assert "armor" not in keys(ns)


def test_mana_gem_reminder():
    rt, ns, g = preview()
    assert "managem" in keys(ns)
    rt.execute("GEMS = { [5514] = 1 }")
    assert "managem" not in keys(ns)
    rt, ns, g = preview()
    rt.execute("KNOWN = { [168] = true }")                  # cannot conjure one yet
    assert "managem" not in keys(ns)
    _, ns, g = preview({"c_mag_gem": False})
    assert "managem" not in keys(ns)


def test_proc_alert_follows_the_games_overlay():
    _, ns, g = preview()
    a = ns.Mage.alert
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 57761)
    assert visible(a) and a.text.text == "Congelamento Cerebral!"
    r, t = a.Rect(a), a.text.Rect(a.text)
    assert abs((r[1] + r[3]) - (t[1] + t[3])) < 6            # the frame ends with its text: centred as a whole
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 12536)
    assert visible(a)
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_HIDE", 57761)
    assert visible(a) and a.text.text == "Lançamento Livre!"
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_HIDE", 12536)
    assert not visible(a)
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 99999)  # not a mage proc
    assert not visible(a)


def test_overlay_hide_without_an_id_clears_everything():
    _, ns, g = preview()
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 57761)
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_HIDE")
    assert not visible(ns.Mage.alert)


def test_procs_off_and_other_classes():
    _, ns, g = preview({"c_mag_procs": False})
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 57761)
    assert not visible(ns.Mage.alert)
    _, ns, g = preview(cls="ROGUE")
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_SHOW", 57761)
    assert not visible(ns.Mage.alert)
    k = keys(ns)
    assert "armor" not in k and "managem" not in k


def test_five_second_rule_for_mages():
    _, ns, g = preview()
    g.PREVIEW_FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "C", 133)
    g.NOW = 1001
    f = ns.FiveSecond.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)
    assert visible(ns.FiveSecond.spark)
