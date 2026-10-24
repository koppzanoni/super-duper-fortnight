"""Classes page (Classes/Classes.lua) and the rogue's extras (Classes/Rogue.lua)."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
ENERGY, NOW = 40, 1000
local basePowerType, basePower, basePowerMax = UnitPowerType, UnitPower, UnitPowerMax
function UnitPowerType(u) if u == "player" then return 3, "ENERGY" end return basePowerType(u) end
function UnitPower(u, t) if u == "player" and (t == 3 or t == nil) then return ENERGY end return basePower(u, t) end
function UnitPowerMax(u, t) if u == "player" and (t == 3 or t == nil) then return 100 end return basePowerMax(u, t) end
function GetTime() return NOW end
HOSTILE = true
function UnitCanAttack() return HOSTILE end
PLAYER_AURAS, TARGET_AURAS = {}, {}
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return PLAYER_AURAS[id] end
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "target" then return TARGET_AURAS[id] end end
C_UnitAuras.GetAuraDuration = function(unit, inst) return { unit = unit, inst = inst } end
function IsPlayerSpell() return true end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=GAME)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def energy(g, v, now=None):
    g.ENERGY = v
    if now is not None:
        g.NOW = now
    g.PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "ENERGY")


def page_labels(ns):
    return [r.row.label for r in ns.Panel.rows.values() if r.row is not None]


# ---------------------------------------------------------------- the page
def test_page_opens_on_the_players_class():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = page_labels(ns)
    assert labels[0] == "Classe"
    for label in ("Tick de energia", "Pontos de combo no alvo", "Duração de Picar e Rasgar", "Venenos acabando"):
        assert label in labels, label


def test_other_classes_listed_and_not_built_ones_say_so():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Classe")
    names = [o[2] for o in row.row.options().values()]
    assert len(names) == 11 and names[0].startswith("Ladino")             # yours first
    assert all(ns.Classes.cards[c[1]] is not None for c in ns.Classes.LIST.values())   # every class is built
    row.row.set("DRUID")
    assert ns.Classes.selected == "DRUID" and "Tick de energia em Felino" in page_labels(ns)
    ns.Classes.cards.DRUID = None                                          # a class without its file
    ns.Panel.Show("classes")
    heads = [r.label.text for r in ns.Panel.rows.values() if r.row is None]
    assert any("EM BREVE" in (h or "") for h in heads)


# ---------------------------------------------------------------- energy tick
def test_energy_tick_spark_follows_the_two_second_rhythm():
    _, ns, g = preview()
    r = ns.EnergyTick
    energy(g, 40, 1000)
    energy(g, 60, 1000.2)                                    # a tick of 20
    assert r.ticking
    bar = ns.UnitFrames.frames.player.power
    g.NOW = 1001.2                                           # halfway to the next tick
    r.frame.GetScript(r.frame, "OnUpdate")(r.frame, 0.1)
    assert visible(r.spark)
    x = rect(r.spark)[0] + rect(r.spark)[2] / 2 - rect(bar)[0]
    assert abs(x - rect(bar)[2] / 2) < 1.5


def test_smooth_regeneration_means_no_spark():
    _, ns, g = preview()
    for i in range(6):
        energy(g, 40 + i * 2, 1000 + i * 0.2)
    ns.EnergyTick.frame.GetScript(ns.EnergyTick.frame, "OnUpdate")(ns.EnergyTick.frame, 0.1)
    assert not ns.EnergyTick.ticking and not visible(ns.EnergyTick.spark)


def test_spark_hidden_at_full_energy_and_when_off():
    _, ns, g = preview()
    energy(g, 40, 1000); energy(g, 60, 1000.2)
    energy(g, 100, 1002.2)
    ns.EnergyTick.frame.GetScript(ns.EnergyTick.frame, "OnUpdate")(ns.EnergyTick.frame, 0.1)
    assert not visible(ns.EnergyTick.spark)
    _, ns, g = preview({"c_rog_tick": False})
    energy(g, 40, 1000); energy(g, 60, 1000.2)
    ns.EnergyTick.frame.GetScript(ns.EnergyTick.frame, "OnUpdate")(ns.EnergyTick.frame, 0.1)
    assert not visible(ns.EnergyTick.spark)


# ---------------------------------------------------------------- combo points on the target
def test_combo_points_under_the_target_when_asked():
    _, ns, g = preview()
    assert not visible(ns.Rogue.combo)                       # off by default
    _, ns, g = preview({"c_rog_ontarget": True})
    g.PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    assert visible(ns.Rogue.combo)
    lit = [d for d in ns.Rogue.dots.values() if visible(d) and d.lit]
    assert len(lit) == 3                                     # the preview has 3 of 5
    t = ns.UnitFrames.frames.target.health
    assert rect(ns.Rogue.combo)[1] >= rect(t)[1] + rect(t)[3]           # above the bar and its name
    g.HOSTILE = False
    g.PREVIEW_FIRE("PLAYER_TARGET_CHANGED")
    assert not visible(ns.Rogue.combo)


# ---------------------------------------------------------------- Slice and Dice / Rupture
def test_slice_and_rupture_bars():
    rt, ns, g = preview()
    assert not visible(ns.Rogue.bars[1])
    g.PLAYER_AURAS = rt.eval("{ [315496] = { auraInstanceID = 7, expirationTime = 1012, duration = 24 } }")
    g.TARGET_AURAS = rt.eval("{ [1943] = { auraInstanceID = 9, expirationTime = 1006, duration = 16, isFromPlayerOrPlayerPet = true } }")
    g.PREVIEW_FIRE("UNIT_AURA", "player")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    b1, b2 = ns.Rogue.bars[1], ns.Rogue.bars[2]
    assert visible(b1) and visible(b2)
    assert b1.timer.inst == 7 and b2.timer.inst == 9          # the game's duration object drives the bars
    assert b1.label.text == "Picar" and b2.label.text == "Rasgar"


def test_someone_elses_rupture_does_not_count():
    rt, ns, g = preview()
    g.TARGET_AURAS = rt.eval("{ [1943] = { auraInstanceID = 9, expirationTime = 1006, duration = 16, isFromPlayerOrPlayerPet = false } }")
    g.PREVIEW_FIRE("UNIT_AURA", "target")
    assert not any(visible(b) for b in ns.Rogue.bars.values())


def test_timer_bars_movable_and_switchable():
    rt, ns, g = preview({"c_rog_snd": False})
    g.PLAYER_AURAS = rt.eval("{ [315496] = { auraInstanceID = 7, expirationTime = 1012, duration = 24 } }")
    g.PREVIEW_FIRE("UNIT_AURA", "player")
    assert not visible(ns.Rogue.bars[1])
    assert "roguetimers" in list(ns.Movers["items"].keys())


# ---------------------------------------------------------------- poisons go through the reminders
def test_rogue_poison_option_feeds_the_reminders():
    rt, ns, g = preview()
    ns.Reminders.Update()
    assert "poison" in [e.key for e in ns.Reminders.List().values()]
    ns.db.c_rog_poison = False
    ns.Reminders.Update()
    assert "poison" not in [e.key for e in ns.Reminders.List().values()]


def test_nothing_for_other_classes():
    rt = preview_render.run_addon(vbars=False, db={"installed": True}, pre=GAME + '\nfunction UnitClass() return "Mago", "MAGE" end\n')
    ns, g = rt.globals().PREVIEW_NS, rt.globals()
    energy(g, 40, 1000); energy(g, 60, 1000.2)
    assert not ns.EnergyTick.ticking
    assert "roguetimers" not in list(ns.Movers["items"].keys())
