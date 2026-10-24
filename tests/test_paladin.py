"""The paladin's extras (Classes/Paladin.lua): aura and seal reminders, Judgement timer, missing blessings."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "PALADIN"
function UnitClass(u) if u == "player" or u == nil then return "Paladino", CLASS end return "Guerreiro", "WARRIOR" end
KNOWN = { [465] = true, [21084] = true, [19740] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [465] = "Aura de Devoção", [7294] = "Aura de Retribuição", [21084] = "Selo da Retidão",
  [19740] = "Bênção de Poder", [20217] = "Bênção dos Reis", [25782] = "Bênção Maior de Poder", [20185] = "Julgamento da Luz" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end }
AURAS = { player = {} }
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS[unit] or {}) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
PLAYER_AURAS, TARGET_AURAS = {}, {}
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return PLAYER_AURAS[id] end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "target" then return TARGET_AURAS[id] end end
C_UnitAuras.GetAuraDuration = function(unit, inst) return { unit = unit, inst = inst } end
function UnitIsVisible() return true end
HOSTILE = true
function UnitCanAttack() return HOSTILE end
NOW = 1000
function GetTime() return NOW end
"""


def preview(db=None, group=None, cls="PALADIN"):
    pre = GAME.replace('CLASS = "PALADIN"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    g = rt.globals()
    if group:
        g.PREVIEW_ROSTER(*group)
    return rt, g.PREVIEW_NS, g


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def auras(rt, unit, *names):
    rt.execute("AURAS[%r] = {%s}" % (unit, ",".join("%r" % n for n in names)))


def visible(region):
    return bool(region.IsVisible(region))


# ---------------------------------------------------------------- page
def test_page_has_the_paladin_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Lembrete de aura e selo", "Duração do julgamento no alvo", "Bênçãos do grupo faltando"):
        assert label in labels, label


# ---------------------------------------------------------------- aura
def test_missing_aura_reminder():
    rt, ns, g = preview()
    auras(rt, "player", "Bênção de Poder")
    assert "palaura" in keys(ns)
    auras(rt, "player", "Bênção de Poder", "Aura de Devoção")
    assert "palaura" not in keys(ns)
    _, ns, g = preview({"c_pal_aura": False})
    assert "palaura" not in keys(ns)


# ---------------------------------------------------------------- seal (in combat)
def test_seal_alert_only_once_the_game_shows_seals_in_combat():
    rt, ns, g = preview()
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert not visible(ns.Paladin.alert)                   # never seen a seal answer: cannot tell
    g.PLAYER_AURAS = rt.eval("{ [21084] = { auraInstanceID = 3 } }")
    g.PREVIEW_FIRE("UNIT_AURA", "player")
    assert not visible(ns.Paladin.alert)
    g.PLAYER_AURAS = rt.eval("{}")
    g.PREVIEW_FIRE("UNIT_AURA", "player")
    assert visible(ns.Paladin.alert) and ns.Paladin.alert.text.text == "Sem selo!"
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    assert not visible(ns.Paladin.alert)


def test_no_seal_alert_without_seals_or_a_foe():
    rt, ns, g = preview()
    g.KNOWN = rt.eval("{ [465] = true }")                    # no seals in this client's paladin
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    g.PLAYER_AURAS = rt.eval("{}")
    g.PREVIEW_FIRE("UNIT_AURA", "player")
    assert not visible(ns.Paladin.alert)


# ---------------------------------------------------------------- Judgement
def test_judgement_timer_on_the_target():
    rt, ns, g = preview()
    g.TARGET_AURAS = rt.eval("{ [20185] = { auraInstanceID = 5, expirationTime = 1010, duration = 20, isFromPlayerOrPlayerPet = true } }")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    b = ns.Paladin.bars[1]
    assert visible(b) and b.timer.inst == 5 and b.label.text == "Julgamento"
    assert "paltimers" in list(ns.Movers["items"].keys())
    rt, ns, g = preview({"c_pal_judge": False})
    g.TARGET_AURAS = rt.eval("{ [20185] = { auraInstanceID = 5, expirationTime = 1010, duration = 20, isFromPlayerOrPlayerPet = true } }")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    assert not visible(ns.Paladin.bars[1])


# ---------------------------------------------------------------- blessings
def test_missing_blessings_counted_in_the_group():
    rt, ns, g = preview(group=("party", 4))
    auras(rt, "player", "Aura de Devoção", "Bênção de Poder")
    auras(rt, "party1", "Bênção dos Reis")
    auras(rt, "party2", "Bênção Maior de Poder")
    # party3 has none; party4 is dead (not counted)
    entry = None
    ns.Reminders.Update()
    for e in ns.Reminders.List().values():
        if e.key == "bless":
            entry = e
    assert entry is not None and "1" in entry.text
    auras(rt, "party3", "Bênção dos Reis")
    assert "bless" not in keys(ns)


def test_solo_blessing_and_switch():
    rt, ns, g = preview()
    auras(rt, "player", "Aura de Devoção")
    assert "bless" in keys(ns)
    _, ns, g = preview({"c_pal_bless": False})
    assert "bless" not in keys(ns)


def test_nothing_for_other_classes():
    rt, ns, g = preview(cls="MAGE")
    k = keys(ns)
    assert "palaura" not in k and "bless" not in k
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert not visible(ns.Paladin.alert)
