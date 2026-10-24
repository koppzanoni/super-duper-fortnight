"""The hunter's extras (Classes/Hunter.lua): Auto Shot timer, pet happiness, pet health, ammo, aspect."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "HUNTER"
function UnitClass(u) if u == "player" or u == nil then return "Caçador", CLASS end return "Guerreiro", "WARRIOR" end
NOW = 1000
function GetTime() return NOW end
RANGED = 2.8
function UnitRangedDamage() return RANGED end
HAPPY = 2
function GetPetHappiness() if HAPPY then return HAPPY, 100, 0 end end
PET_HP = 3000
local baseHealth, baseMax = UnitHealth, UnitHealthMax
function UnitHealth(u) if u == "pet" then return PET_HP end return baseHealth(u) end
function UnitHealthMax(u) if u == "pet" then return 6000 end return baseMax(u) end
AMMO_ITEM, AMMO = true, 150
function GetInventoryItemID(_, slot) if slot == 0 and AMMO_ITEM then return 2512 end end
function GetInventoryItemCount(_, slot) if slot == 0 then return AMMO end return 0 end
KNOWN = { [13165] = true }
function IsPlayerSpell(id) return KNOWN[id] or false end
NAMES = { [13165] = "Aspecto do Falcão", [13163] = "Aspecto do Macaco", [75] = "Tiro Automático" }
C_Spell = { GetSpellName = function(id) return NAMES[id] end, GetSpellTexture = function(id) return "ICON:" .. id end }
AURAS = {}
C_UnitAuras.GetUnitAuras = function(unit, filter)
  if unit ~= "player" or filter ~= "HELPFUL" then return {} end
  local out = {}
  for i, n in ipairs(AURAS) do out[i] = { name = n, expirationTime = 0, duration = 0 } end
  return out
end
"""


def preview(db=None, cls="HUNTER"):
    pre = GAME.replace('CLASS = "HUNTER"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def keys(ns):
    ns.Reminders.Update()
    return [e.key for e in ns.Reminders.List().values()]


def shot(g, spell=75):
    g.PREVIEW_FIRE("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", spell)


def tick(ns):
    f = ns.Hunter.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)


# ---------------------------------------------------------------- page
def test_page_has_the_hunter_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Timer do Tiro Automático", "Felicidade do pet", "Vida do pet no quadro do jogador",
                  "Aviso de munição acabando", "Lembrete de Aspecto"):
        assert label in labels, label


# ---------------------------------------------------------------- Auto Shot
def test_auto_shot_timer_while_shooting():
    _, ns, g = preview()
    bar = ns.Hunter.shot
    g.PREVIEW_FIRE("START_AUTOREPEAT_SPELL")
    shot(g)
    assert visible(bar)
    lo, hi = bar.GetMinMaxValues(bar)
    assert abs(hi - 2.8) < 1e-6
    w = rect(bar.window)[2] / rect(bar)[2]
    assert abs(w - 0.5 / 2.8) < 0.01                       # the last half second shaded
    g.NOW = 1001.4
    tick(ns)
    assert abs(bar.GetValue(bar) - 1.4) < 1e-6
    shot(g, spell=3044)                                    # Arcane Shot does not reset it
    tick(ns)
    assert abs(bar.GetValue(bar) - 1.4) < 1e-6
    g.PREVIEW_FIRE("STOP_AUTOREPEAT_SPELL")
    assert not visible(bar)


def test_auto_shot_switch_and_mover():
    _, ns, g = preview({"c_hun_auto": False})
    g.PREVIEW_FIRE("START_AUTOREPEAT_SPELL")
    shot(g)
    assert not visible(ns.Hunter.shot)
    assert "huntshot" in list(ns.Movers["items"].keys())


# ---------------------------------------------------------------- pet
def test_pet_happiness_on_the_pet_frame():
    _, ns, g = preview()
    icon = ns.Hunter.happy
    assert visible(icon)
    pet = ns.UnitFrames.frames.pet
    assert icon.GetParent(icon) is not None and rect(icon)[0] >= rect(pet)[0]
    assert icon.happiness == 2
    g.HAPPY = 1
    g.PREVIEW_FIRE("UNIT_HAPPINESS", "pet")
    assert icon.happiness == 1
    g.HAPPY = None                                         # a client without pet happiness
    g.PREVIEW_FIRE("UNIT_HAPPINESS", "pet")
    assert not visible(icon)


def test_pet_health_under_the_player_bars():
    _, ns, g = preview()
    bar = ns.Hunter.petHealth
    assert visible(bar)
    assert bar.GetValue(bar) == 3000 and bar.GetMinMaxValues(bar)[1] == 6000
    p = ns.UnitFrames.frames.player.power
    assert abs(rect(bar)[0] - rect(p)[0]) < 1 and rect(bar)[1] + rect(bar)[3] <= rect(p)[1] + 0.5
    g.PET_HP = 1200
    g.PREVIEW_FIRE("UNIT_HEALTH", "pet")
    assert bar.GetValue(bar) == 1200
    _, ns, g = preview({"c_hun_pethp": False})
    assert not visible(ns.Hunter.petHealth)


# ---------------------------------------------------------------- ammo and aspect (reminders)
def test_low_ammo_reminder():
    rt, ns, g = preview()
    rt.execute("AURAS = { 'Aspecto do Falcão' }")
    entry = [e for e in ns.Reminders.List().values() if e.key == "ammo"]
    keys(ns)
    entry = [e for e in ns.Reminders.List().values() if e.key == "ammo"]
    assert entry and "150" in entry[0].text
    g.AMMO = 800
    assert "ammo" not in keys(ns)
    g.AMMO_ITEM, g.AMMO = False, 0                         # no ammo slot item (or a client without ammo)
    assert "ammo" not in keys(ns)


def test_aspect_reminder():
    rt, ns, g = preview()
    assert "aspect" in keys(ns)
    rt.execute("AURAS = { 'Aspecto do Macaco' }")
    assert "aspect" not in keys(ns)
    _, ns, g = preview({"c_hun_aspect": False})
    assert "aspect" not in keys(ns)


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="MAGE")
    g.PREVIEW_FIRE("START_AUTOREPEAT_SPELL")
    shot(g)
    assert not visible(ns.Hunter.shot) and not visible(ns.Hunter.happy) and not visible(ns.Hunter.petHealth)
    k = keys(ns)
    assert "ammo" not in k and "aspect" not in k
