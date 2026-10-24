"""The warlock's extras (Classes/Warlock.lua): soul shard counter, soul/health stone reminders, DoT timers,
demon health and mana."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "WARLOCK"
function UnitClass(u) if u == "player" or u == nil then return "Bruxo", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
KNOWN = { [1120] = true, [6201] = true, [693] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [20707] = "Pedra da Alma", [6201] = "Criar Pedra de Vida", [693] = "Criar Pedra da Alma" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end }
ITEMS = { [6265] = 12 }
C_Item.GetItemCount = function(id) return ITEMS[id] or 0 end
AURAS = { player = {} }
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS[unit] or {}) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
TARGET_AURAS = {}
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "target" then return TARGET_AURAS[id] end end
C_UnitAuras.GetPlayerAuraBySpellID = function() return nil end
C_UnitAuras.GetAuraDuration = function(unit, inst) return { unit = unit, inst = inst } end
function UnitIsVisible() return true end
PET = { 3000, 6000, 400, 1000 }
local bH, bHM, bP, bPM = UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax
function UnitHealth(u) if u == "pet" then return PET[1] end return bH(u) end
function UnitHealthMax(u) if u == "pet" then return PET[2] end return bHM(u) end
function UnitPower(u, t) if u == "pet" then return PET[3] end return bP(u, t) end
function UnitPowerMax(u, t) if u == "pet" then return PET[4] end if u == "player" and t == 7 then return SHARD_MAX end return bPM(u, t) end
SHARD_MAX = 0 -- shards are bag items here (no resource gems)
"""


def preview(db=None, cls="WARLOCK", group=None):
    pre = GAME.replace('CLASS = "WARLOCK"', f'CLASS = "{cls}"')
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


def test_page_has_the_warlock_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Contador de fragmentos na mochila", "Pedra de alma e de vida", "DoTs no alvo (tempo restante)",
                  "Vida e mana do demônio"):
        assert label in labels, label


# ---------------------------------------------------------------- soul shards
def test_soul_shard_counter():
    rt, ns, g = preview()
    c = ns.Warlock.shards
    assert visible(c) and c.text.text == "12"
    rt.execute("ITEMS[6265] = 2")
    g.PREVIEW_FIRE("BAG_UPDATE_DELAYED")
    assert c.text.text == "2"
    rt.execute("ITEMS[6265] = 0; KNOWN = {}")              # a client with shards as a resource: no counter
    g.PREVIEW_FIRE("BAG_UPDATE_DELAYED")
    assert not visible(c)
    _, ns, g = preview({"c_wl_shards": False})
    assert not visible(ns.Warlock.shards)
    rt = preview_render.run_addon(vbars=False, db={"installed": True}, pre=GAME + "\nSHARD_MAX = 5\n")
    ns = rt.globals().PREVIEW_NS
    assert visible(ns.ClassResource.holder) and not visible(ns.Warlock.shards)   # the gems already count them


# ---------------------------------------------------------------- stones
def test_healthstone_and_soulstone_reminders():
    rt, ns, g = preview()
    k = keys(ns)
    assert "healthstone" in k and "soulstone" in k
    rt.execute("ITEMS[5512] = 1; ITEMS[5232] = 1")
    k = keys(ns)
    assert "healthstone" not in k and "soulstone" not in k


def test_soulstone_on_someone_in_the_group_counts():
    rt, ns, g = preview(group=("party", 2))
    rt.execute("AURAS.party2 = { 'Pedra da Alma' }")
    assert "soulstone" not in keys(ns)


def test_stones_off():
    _, ns, g = preview({"c_wl_stones": False})
    k = keys(ns)
    assert "healthstone" not in k and "soulstone" not in k


# ---------------------------------------------------------------- DoTs
def test_dot_timers_stack_without_gaps():
    rt, ns, g = preview()
    g.TARGET_AURAS = rt.eval("{ [172] = { auraInstanceID = 1, expirationTime = 1012, duration = 18, isFromPlayerOrPlayerPet = true },"
                             " [348] = { auraInstanceID = 3, expirationTime = 1008, duration = 15, isFromPlayerOrPlayerPet = true } }")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    shown = [b for b in ns.Warlock.bars.values() if visible(b)]
    assert [b.label.text for b in shown] == ["Corrupção", "Imolar"]
    top = rect(ns.Warlock.timers)
    assert abs((rect(shown[0])[1] + rect(shown[0])[3]) - (top[1] + top[3])) < 0.5   # first one at the top
    assert rect(shown[1])[1] + rect(shown[1])[3] < rect(shown[0])[1] + 0.5           # the next one right under
    assert rect(shown[0])[1] - (rect(shown[1])[1] + rect(shown[1])[3]) < 6


# ---------------------------------------------------------------- demon
def test_demon_health_and_mana_under_the_player_bars():
    _, ns, g = preview()
    hp, mp = ns.Warlock.pet.health, ns.Warlock.pet.mana
    assert visible(hp) and visible(mp)
    assert hp.GetValue(hp) == 3000 and mp.GetValue(mp) == 400 and mp.GetMinMaxValues(mp)[1] == 1000
    assert rect(mp)[1] + rect(mp)[3] <= rect(hp)[1] + 0.5
    _, ns, g = preview({"c_wl_pet": False})
    assert not visible(ns.Warlock.pet.health)


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="MAGE")
    assert not visible(ns.Warlock.shards) and not visible(ns.Warlock.pet.health)
    k = keys(ns)
    assert "healthstone" not in k and "soulstone" not in k
