"""The warrior's extras (Classes/Warrior.lua): swing timer, Overpower/Execute alert, stance bar, rage text."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS = "WARRIOR"
function UnitClass() return "Guerreiro", CLASS end
NOW = 1000
function GetTime() return NOW end
function UnitGUID(u) if u == "player" then return "Player-me" end return "Creature-1" end
SPEED = 2.6
function UnitAttackSpeed() return SPEED, nil end
RESTRICTED = false
C_CombatLog = { IsCombatLogRestricted = function() return RESTRICTED end }
CLEU = {}
function CombatLogGetCurrentEventInfo() return unpack(CLEU) end
function PREVIEW_CLEU(...) CLEU = { ... }; PREVIEW_FIRE("COMBAT_LOG_EVENT_UNFILTERED") end
USABLE = {}
C_Spell = C_Spell or {}
C_Spell.IsSpellUsable = function(id) return USABLE[id] or false, false end
C_Spell.GetSpellTexture = function(id) return "ICON:" .. id end
C_Spell.GetSpellName = function(id) return ({ [7384] = "Sobrepujar", [5308] = "Executar" })[id] end
function IsPlayerSpell() return true end
HOSTILE = true
function UnitCanAttack() return HOSTILE end
RAGE = 45
local basePower, basePowerType = UnitPower, UnitPowerType
function UnitPowerType(u) if u == "player" then return 1, "RAGE" end return basePowerType(u) end
function UnitPower(u, t) if u == "player" and (t == 1 or t == nil) then return RAGE end return basePower(u, t) end
StanceBar = CreateFrame("Frame", "StanceBar", UIParent)
StanceBar:SetSize(90, 30)
"""


def preview(db=None, cls="WARRIOR"):
    pre = GAME.replace('CLASS = "WARRIOR"', f'CLASS = "{cls}"')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def swing(g, sub="SWING_DAMAGE", source="Player-me", spell=None):
    args = [g.NOW, sub, False, source, "Eu", 0, 0, "Creature-1", "Lobo", 0, 0]
    if spell:
        args += [spell, "Golpe Heroico", 1]
    g.PREVIEW_CLEU(*args)


def tick(ns):
    f = ns.Warrior.frame
    f.GetScript(f, "OnUpdate")(f, 0.05)


# ---------------------------------------------------------------- page
def test_page_has_the_warrior_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Timer do ataque automático (swing)", "Aviso de Sobrepujar / Executar disponível",
                  "Barra de posturas no quadro do jogador", "Fúria em texto"):
        assert label in labels, label


# ---------------------------------------------------------------- swing timer
def test_swing_timer_starts_on_each_of_your_swings():
    _, ns, g = preview()
    bar = ns.Warrior.swing
    assert not visible(bar)
    swing(g)
    assert visible(bar)
    lo, hi = bar.GetMinMaxValues(bar)
    assert abs(hi - 2.6) < 1e-6
    g.NOW = 1001.3
    tick(ns)
    assert abs(bar.GetValue(bar) - 1.3) < 1e-6
    swing(g, source="Player-other")                       # someone else's swing: no reset
    tick(ns)
    assert abs(bar.GetValue(bar) - 1.3) < 1e-6


def test_misses_and_next_swing_abilities_reset_it():
    _, ns, g = preview()
    swing(g)
    g.NOW = 1002
    swing(g, "SWING_MISSED")
    tick(ns)
    assert bar_value(ns) < 0.01
    g.NOW = 1003
    swing(g, "SPELL_DAMAGE", spell=78)                     # Heroic Strike lands on the swing
    tick(ns)
    assert bar_value(ns) < 0.01


def bar_value(ns):
    return ns.Warrior.swing.GetValue(ns.Warrior.swing)


def test_swing_timer_hidden_when_the_log_is_restricted_or_out_of_combat():
    _, ns, g = preview()
    g.RESTRICTED = True
    swing(g)
    assert not visible(ns.Warrior.swing)
    _, ns, g = preview()
    swing(g)
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    assert not visible(ns.Warrior.swing)
    _, ns, g = preview({"c_war_swing": False})
    swing(g)
    assert not visible(ns.Warrior.swing)


def test_swing_timer_movable():
    _, ns, _ = preview()
    assert "warswing" in list(ns.Movers["items"].keys())


# ---------------------------------------------------------------- Overpower / Execute
def test_overpower_alert_follows_the_games_glow():
    _, ns, g = preview()
    a = ns.Warrior.alert
    assert not visible(a)
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)
    assert visible(a) and a.text.text == "Sobrepujar!" and a.icon.file == "ICON:7384"
    g.PREVIEW_FIRE("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", 7384)
    assert not visible(a)


def test_execute_alert_when_usable_on_an_enemy():
    rt, ns, g = preview()
    g.USABLE = rt.eval("{ [5308] = true }")
    g.PREVIEW_FIRE("SPELL_UPDATE_USABLE")
    assert visible(ns.Warrior.alert) and ns.Warrior.alert.text.text == "Executar!"
    g.HOSTILE = False
    g.PREVIEW_FIRE("PLAYER_TARGET_CHANGED")
    assert not visible(ns.Warrior.alert)
    rt, ns, g = preview({"c_war_proc": False})
    g.USABLE = rt.eval("{ [5308] = true }")
    g.PREVIEW_FIRE("SPELL_UPDATE_USABLE")
    assert not visible(ns.Warrior.alert)


# ---------------------------------------------------------------- stance bar
def test_stance_bar_under_the_player_frame_when_asked():
    _, ns, g = preview()
    p = ns.UnitFrames.frames.player
    assert rect(g.StanceBar)[1] < 300                     # by default near the action bar
    _, ns, g = preview({"c_war_stance": True})
    p = ns.UnitFrames.frames.player
    sb, pr = rect(g.StanceBar), rect(p)
    assert sb[1] + sb[3] <= pr[1] + 1 and sb[1] > pr[1] - 80   # right under the player frame


# ---------------------------------------------------------------- rage text
def test_rage_number_where_the_gems_would_be():
    _, ns, g = preview()
    t = ns.Warrior.rage
    assert visible(t) and t.text == "45"
    bar = ns.ActionBars.modernFrame
    tr, br = rect(t), rect(bar)
    assert abs((tr[0] + tr[2] / 2) - (br[0] + br[2] / 2)) < 2             # centred over the action bar
    assert br[1] + br[3] < tr[1] < br[1] + br[3] + 120                     # just above it
    g.RAGE = 80
    g.PREVIEW_FIRE("UNIT_POWER_FREQUENT", "player", "RAGE")
    assert t.text == "80"
    _, ns, g = preview({"c_war_text": False})
    assert not visible(ns.Warrior.rage)


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="MAGE")
    swing(g)
    assert not visible(ns.Warrior.swing) and not visible(ns.Warrior.rage)
    assert "warswing" not in list(ns.Movers["items"].keys())
