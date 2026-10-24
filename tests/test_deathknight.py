"""The death knight's extras (Classes/DeathKnight.lua): runes by type, rune cooldowns, runic power bar,
diseases on the target."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "DEATHKNIGHT"
function UnitClass(u) if u == "player" or u == nil then return "Cavaleiro da Morte", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
RUNES = { { 0, 10, true }, { 0, 10, true }, { 995, 10, false }, { 0, 10, true }, { 998, 10, false }, { 0, 10, true } }
function GetRuneCooldown(i) local r = RUNES[i]; return r[1], r[2], r[3] end
TYPES = { 1, 1, 2, 2, 3, 4 }
function GetRuneType(i) return TYPES and TYPES[i] end
RP = 70
local basePower, basePowerMax, basePowerType = UnitPower, UnitPowerMax, UnitPowerType
function UnitPowerType(u) if u == "player" then return 6, "RUNIC_POWER" end return basePowerType(u) end
function UnitPower(u, t) if u == "player" and (t == 6 or t == nil) then return RP end return basePower(u, t) end
function UnitPowerMax(u, t) if u == "player" and (t == 6 or t == nil) then return 100 end return basePowerMax(u, t) end
TARGET_AURAS = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "target" then return TARGET_AURAS[id] end end
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
C_UnitAuras.GetAuraDuration = function(unit, inst) return { unit = unit, inst = inst } end
"""


def preview(db=None, cls="DEATHKNIGHT", extra=""):
    pre = GAME.replace('CLASS = "DEATHKNIGHT"', f'CLASS = "{cls}"') + extra
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def vc(tex):
    return tuple(round(v, 2) for v in tex.vc.values())[:3]


def tick(ns):
    f = ns.DeathKnight.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)


# ---------------------------------------------------------------- page
def test_page_has_the_death_knight_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Runas por tipo (sangue, gelo, profano)", "Tempo de recarga em cada runa", "Poder rúnico em barra",
                  "Doenças no alvo"):
        assert label in labels, label


# ---------------------------------------------------------------- runes by type
def test_ready_runes_in_their_type_colour():
    _, ns, g = preview()
    gems = ns.ClassResource.gems
    blood, unholy, death = vc(gems[1]), vc(gems[4]), vc(gems[6])
    assert blood[0] > 0.6 and blood[1] < 0.3                 # red
    assert unholy[1] > 0.6 and unholy[0] < 0.5               # green
    assert death[2] > 0.8 and death[0] > 0.5                 # purple
    assert vc(gems[3]) == (1, 1, 1)                          # recharging: the plain unlit gem


def test_without_rune_types_the_spec_colour_is_used():
    _, ns, g = preview(extra="\nGetRuneType = nil\nfunction GetSpecialization() return 2 end\n")   # frost
    c = vc(ns.ClassResource.gems[1])
    assert c[2] > 0.8 and c[0] < 0.3


def test_one_colour_when_switched_off():
    _, ns, g = preview({"c_dk_types": False})
    assert vc(ns.ClassResource.gems[1]) == vc(ns.ClassResource.gems[4])


# ---------------------------------------------------------------- cooldowns
def test_seconds_left_on_recharging_runes():
    _, ns, g = preview()
    tick(ns)
    texts = ns.DeathKnight.cdTexts
    assert visible(texts[3]) and texts[3].text == "5"          # 995 + 10 - 1000
    assert visible(texts[5]) and texts[5].text == "8"
    assert not visible(texts[1])
    _, ns, g = preview({"c_dk_cd": False})
    tick(ns)
    assert not visible(ns.DeathKnight.cdTexts[3])


# ---------------------------------------------------------------- runic power
def test_runic_power_bar_under_the_runes():
    _, ns, g = preview()
    b = ns.DeathKnight.rp
    assert visible(b) and b.GetValue(b) == 70 and b.GetMinMaxValues(b)[1] == 100
    h = rect(ns.ClassResource.holder)
    assert rect(b)[1] + rect(b)[3] <= h[1] + 0.5 and abs(rect(b)[2] - h[2]) < 1
    g.RP = 30
    g.PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "RUNIC_POWER")
    assert b.GetValue(b) == 30
    _, ns, g = preview({"c_dk_rp": False})
    assert not visible(ns.DeathKnight.rp)


# ---------------------------------------------------------------- diseases
def test_disease_timers_on_the_target():
    rt, ns, g = preview()
    g.TARGET_AURAS = rt.eval("{ [55095] = { auraInstanceID = 4, expirationTime = 1012, duration = 21, isFromPlayerOrPlayerPet = true },"
                             " [55078] = { auraInstanceID = 5, expirationTime = 1009, duration = 21, isFromPlayerOrPlayerPet = true } }")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    b1, b2 = ns.DeathKnight.bars[1], ns.DeathKnight.bars[2]
    assert visible(b1) and visible(b2) and b1.label.text == "Febre Gélida" and b2.label.text == "Peste Sanguínea"
    assert "dktimers" in list(ns.Movers["items"].keys())


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="ROGUE")
    f = ns.DeathKnight.frame
    assert f.GetScript(f, "OnUpdate") is None                 # no per-frame work for other classes
    assert not visible(ns.DeathKnight.rp) and not any(visible(t) for t in ns.DeathKnight.cdTexts.values())
