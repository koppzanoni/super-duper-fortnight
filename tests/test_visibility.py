"""Per-element visibility (HUD/Visibility.lua): always, in combat, out of combat, with a target, on
mouseover, hidden — by alpha, so it works in combat and never fights the modules' own show/hide."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

PRE = """
COMBAT, HAS_TARGET, OVER = false, true, nil
function InCombatLockdown() return COMBAT end
local baseExists = UnitExists
function UnitExists(u) if u == "target" then return HAS_TARGET end return baseExists(u) end
"""


def preview(vis=None):
    db = {"installed": True}
    if vis:
        db["visibility"] = vis
    rt = preview_render.run_addon(vbars=True, db=db, pre=PRE)
    g = rt.globals()
    return rt, g.PREVIEW_NS, g


def alpha(f):
    return f.GetAlpha(f)


def real(frames):
    # the preview's stand-ins for Blizzard buttons (the menu's real game-menu button) have no alpha
    return [f for f in frames if isinstance(alpha(f), (int, float))]


def tick(ns):
    f = ns.Visibility.frame
    f.GetScript(f, "OnUpdate")(f, 0.2)


def test_everything_shown_by_default():
    _, ns, _ = preview()
    tick(ns)
    for key in ("player", "target", "bar", "map", "menu", "info", "vbars", "buffs"):
        for f in real(ns.Visibility.Frames(key).values()):
            assert alpha(f) == 1, key


def test_combat_only():
    _, ns, g = preview({"player": "combat", "bar": "combat"})
    tick(ns)
    p = ns.UnitFrames.frames.player
    assert alpha(p) == 0
    bar_frames = list(ns.Visibility.Frames("bar").values())
    assert len(bar_frames) >= 2 and all(alpha(f) == 0 for f in bar_frames)   # the frame and its buttons' header
    g.COMBAT = True
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert alpha(p) == 1 and all(alpha(f) == 1 for f in bar_frames)
    g.COMBAT = False
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    assert alpha(p) == 0


def test_out_of_combat_and_hidden():
    _, ns, g = preview({"map": "nocombat", "info": "hidden"})
    tick(ns)
    m, i = ns.Visibility.Frames("map")[1], ns.Visibility.Frames("info")[1]
    assert alpha(m) == 1 and alpha(i) == 0
    g.COMBAT = True
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert alpha(m) == 0 and alpha(i) == 0


def test_with_a_target_or_in_combat():
    _, ns, g = preview({"vbars": "target"})
    v = ns.Visibility.Frames("vbars")[1]
    tick(ns)
    assert alpha(v) == 1
    g.HAS_TARGET = False
    g.PREVIEW_FIRE("PLAYER_TARGET_CHANGED")
    assert alpha(v) == 0
    g.COMBAT = True
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert alpha(v) == 1


def test_on_mouseover():
    rt, ns, g = preview({"menu": "mouse"})
    frames = real(ns.Visibility.Frames("menu").values())
    band = frames[0]
    tick(ns)
    assert all(alpha(f) == 0 for f in frames)
    band.IsMouseOver = lambda *_: True
    tick(ns)
    assert all(alpha(f) == 1 for f in frames)                 # the whole menu, buttons too


def test_edit_mode_shows_everything():
    _, ns, g = preview({"player": "hidden"})
    tick(ns)
    p = ns.UnitFrames.frames.player
    assert alpha(p) == 0
    ns.EditMode.Start()
    tick(ns)
    assert alpha(p) == 1
    ns.EditMode.Stop()
    tick(ns)
    assert alpha(p) == 0


def test_panel_page():
    _, ns, g = preview()
    ns.Panel.Open("visibility")
    rows = {r.row.label: r for r in ns.Panel.rows.values() if r.row is not None}
    for label in ("Jogador", "Alvo", "Barra de ações", "Minimapa", "Menu", "Barra de informações"):
        assert label in rows, label
    row = rows["Jogador"].row
    options = [o[1] for o in row.options().values()]
    assert options == ["always", "combat", "nocombat", "target", "mouse", "hidden"]
    row.set("combat")
    assert ns.db.visibility.player == "combat"
    tick(ns)
    assert alpha(ns.UnitFrames.frames.player) == 0
