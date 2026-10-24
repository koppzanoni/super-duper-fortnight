"""The priest's extras (Classes/Priest.lua, Classes/FiveSecond.lua): five second rule, shield on the
group frames, missing Fortitude in the group."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "PRIEST"
function UnitClass(u) if u == "player" or u == nil then return "Sacerdote", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
COSTS = { [2050] = { { type = 0, cost = 120 } }, [8092] = {} }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end,
  GetSpellPowerCost = function(id) return COSTS[id] end }
KNOWN = { [21562] = true, [17] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [21562] = "Palavra de Poder: Fortitude", [21564] = "Prece de Fortitude", [17] = "Palavra de Poder: Escudo",
  [6788] = "Alma Enfraquecida" }
AURAS = { player = {} }
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS[unit] or {}) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
BY_ID = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) return BY_ID[unit .. ":" .. id] end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return BY_ID["player:" .. id] end
function UnitIsVisible() return true end
"""


def preview(db=None, group=None, cls="PRIEST"):
    pre = GAME.replace('CLASS = "PRIEST"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    g = rt.globals()
    if group:
        g.PREVIEW_ROSTER(*group)
    return rt, g.PREVIEW_NS, g


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def cast(g, spell):
    g.PREVIEW_FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", spell)


def tick(ns):
    f = ns.FiveSecond.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)


# ---------------------------------------------------------------- page
def test_page_has_the_priest_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Regra dos 5 segundos", "Escudo e Alma Enfraquecida no grupo", "Fortitude faltando no grupo"):
        assert label in labels, label


# ---------------------------------------------------------------- five second rule
def test_five_second_mark_after_a_mana_spell():
    _, ns, g = preview()
    s = ns.FiveSecond.spark
    cast(g, 8092)                                          # no mana cost: nothing
    tick(ns)
    assert not visible(s)
    cast(g, 2050)
    g.NOW = 1002.5
    tick(ns)
    assert visible(s)
    bar = ns.UnitFrames.frames.player.power
    x = rect(s)[0] + rect(s)[2] / 2 - rect(bar)[0]
    assert abs(x - rect(bar)[2] / 2) < 1.5                 # halfway through the five seconds
    g.NOW = 1005.1
    tick(ns)
    assert not visible(s)


def test_five_second_rule_switch_and_other_classes():
    _, ns, g = preview({"c_pri_5sr": False})
    cast(g, 2050)
    tick(ns)
    assert not visible(ns.FiveSecond.spark)
    _, ns, g = preview(cls="ROGUE")
    cast(g, 2050)
    tick(ns)
    assert not visible(ns.FiveSecond.spark)


# ---------------------------------------------------------------- shield on the group frames
def test_shield_and_weakened_soul_on_the_party_frames():
    rt, ns, g = preview(group=("party", 3))
    rt.execute('BY_ID["party1:17"] = { auraInstanceID = 1 }; BY_ID["party2:6788"] = { auraInstanceID = 2 }')
    for u in ("party1", "party2", "party3"):
        g.PREVIEW_FIRE("UNIT_AURA", u)
    p1, p2, p3 = (ns.GroupFrames.party[i] for i in (1, 2, 3))
    assert p1.priestIcon.IsShown(p1.priestIcon) and p1.priestIcon.file == "ICON:17"
    assert p2.priestIcon.IsShown(p2.priestIcon) and p2.priestIcon.file == "ICON:6788" and p2.priestIcon.alpha < 1
    assert p3.priestIcon is None or not p3.priestIcon.IsShown(p3.priestIcon)
    rt.execute('BY_ID["party1:17"] = nil')
    g.PREVIEW_FIRE("UNIT_AURA", "party1")
    assert not p1.priestIcon.IsShown(p1.priestIcon)


def test_shield_as_a_line_on_raid_cells():
    rt, ns, g = preview(group=("raid", 10))
    rt.execute('BY_ID["raid1:17"] = { auraInstanceID = 1 }; BY_ID["raid2:6788"] = { auraInstanceID = 2 }')
    for u in ("raid1", "raid2", "raid3"):
        g.PREVIEW_FIRE("UNIT_AURA", u)
    c1, c2, c3 = (ns.GroupFrames.raid[i] for i in (1, 2, 3))
    assert c1.priestLine.IsShown(c1.priestLine) and c1.priestIcon is None
    top = rect(c1.health)
    line = rect(c1.priestLine)
    assert abs(line[2] - top[2]) < 0.5 and abs((line[1] + line[3]) - (top[1] + top[3])) < 0.5   # along the top edge
    assert c2.priestLine.IsShown(c2.priestLine) and tuple(c2.priestLine.color.values())[0] < 0.6
    assert c3.priestLine is None or not c3.priestLine.IsShown(c3.priestLine)


def test_shield_icons_off():
    rt, ns, g = preview({"c_pri_shield": False}, group=("party", 3))
    rt.execute('BY_ID["party1:17"] = { auraInstanceID = 1 }')
    g.PREVIEW_FIRE("UNIT_AURA", "party1")
    p1 = ns.GroupFrames.party[1]
    assert p1.priestIcon is None or not p1.priestIcon.IsShown(p1.priestIcon)


# ---------------------------------------------------------------- Fortitude
def test_fortitude_missing_counted_in_the_group():
    rt, ns, g = preview(group=("party", 4))
    rt.execute("AURAS.player = { 'Palavra de Poder: Fortitude' }; AURAS.party1 = { 'Prece de Fortitude' }")
    ns.Reminders.Update()
    entry = [e for e in ns.Reminders.List().values() if e.key == "fort"]
    assert entry and "2" in entry[0].text                    # party2 and party3; party4 is dead
    rt.execute("AURAS.party2 = { 'Palavra de Poder: Fortitude' }; AURAS.party3 = { 'Prece de Fortitude' }")
    assert "fort" not in keys(ns)


def test_fortitude_solo_is_the_class_buff_reminder():
    rt, ns, g = preview()
    k = keys(ns)
    assert "buff" in k and "fort" not in k                   # no double reminder when alone
    _, ns, g = preview({"c_pri_fort": False}, group=("party", 4))
    assert "fort" not in keys(ns)


def test_paladin_blessings_still_counted():
    rt, ns, g = preview(cls="PALADIN", group=("party", 2))
    rt.execute("KNOWN = { [19740] = true }; NAMES[19740] = 'Bênção de Poder'; AURAS.player = { 'Bênção de Poder' }")
    ns.Reminders.Update()
    entry = [e for e in ns.Reminders.List().values() if e.key == "bless"]
    assert entry and "2" in entry[0].text
