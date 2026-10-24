"""Cursor (HUD/Cursor.lua): a ring that follows the mouse, a fading trail, colour, combat only."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

MOUSE = """
CURSOR_X, CURSOR_Y, LOOKING = 400, 300, false
function GetCursorPosition() return CURSOR_X, CURSOR_Y end
function IsMouselooking() return LOOKING end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=MOUSE)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def center(region):
    x, y, w, h = rect(region)
    return x + w / 2, y + h / 2


def visible(region):
    return bool(region.IsVisible(region))


def tick(ns, times=1, elapsed=0.016):
    f = ns.Cursor.frame
    for _ in range(times):
        f.GetScript(f, "OnUpdate")(f, elapsed)


def move(g, ns, x, y):
    g.CURSOR_X, g.CURSOR_Y = x, y
    tick(ns)


def test_off_by_default():
    _, ns, _ = preview()
    assert not visible(ns.Cursor.ring)


def test_ring_follows_the_mouse():
    _, ns, g = preview({"curRing": True, "curCombat": False})
    tick(ns)
    assert visible(ns.Cursor.ring)
    cx, cy = center(ns.Cursor.ring)
    assert abs(cx - 400) < 0.5 and abs(cy - 300) < 0.5
    move(g, ns, 900, 120)
    cx, cy = center(ns.Cursor.ring)
    assert abs(cx - 900) < 0.5 and abs(cy - 120) < 0.5
    assert ns.Cursor.frame.strata == "TOOLTIP"


def test_size_setting():
    _, ns, _ = preview({"curRing": True, "curCombat": False})
    w = rect(ns.Cursor.ring)[2]
    _, ns, _ = preview({"curRing": True, "curCombat": False, "curSize": 1.5})
    assert abs(rect(ns.Cursor.ring)[2] - w * 1.5) < 0.5


def test_only_in_combat():
    _, ns, g = preview({"curRing": True})
    tick(ns)
    assert not visible(ns.Cursor.ring)
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    tick(ns)
    assert visible(ns.Cursor.ring)
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    tick(ns)
    assert not visible(ns.Cursor.ring)


def test_hidden_while_turning_the_camera():
    _, ns, g = preview({"curRing": True, "curCombat": False})
    g.LOOKING = True
    tick(ns)
    assert not visible(ns.Cursor.ring)
    g.LOOKING = False
    tick(ns)
    assert visible(ns.Cursor.ring)


def test_trail_fades_behind_the_mouse():
    _, ns, g = preview({"curTrail": True, "curCombat": False})
    for i in range(12):
        move(g, ns, 100 + i * 20, 300)
    dots = [d for d in ns.Cursor.dots.values() if visible(d)]
    assert len(dots) >= 6
    alphas = [d.GetAlpha(d) for d in ns.Cursor.dots.values()]
    assert alphas[0] > alphas[5] > 0                      # newest brightest, older fading
    assert center(ns.Cursor.dots[1])[0] > center(ns.Cursor.dots[6])[0]
    assert not visible(ns.Cursor.ring)                    # the ring has its own switch
    tick(ns, 60)                                          # mouse still: the trail catches up and goes
    assert not any(visible(d) for d in ns.Cursor.dots.values())


def test_colour_from_the_presets():
    _, ns, _ = preview({"curRing": True, "curCombat": False})
    accent = tuple(ns.Widgets.ACCENT.values())
    assert tuple(ns.Cursor.ring.vc.values())[:3] == accent
    ns.Panel.ColorSet("cursor", "green")
    assert tuple(round(v, 2) for v in ns.Cursor.ring.vc.values())[:3] == (0.25, 0.75, 0.25)


def test_switching_off_stops_the_updates():
    _, ns, _ = preview({"curRing": True, "curCombat": False})
    assert ns.Cursor.frame.GetScript(ns.Cursor.frame, "OnUpdate") is not None
    ns.db.curRing = False
    ns.Cursor.Refresh()
    assert ns.Cursor.frame.GetScript(ns.Cursor.frame, "OnUpdate") is None
    assert not visible(ns.Cursor.ring)


def test_panel_page():
    _, ns, _ = preview()
    ns.Panel.Open("cursor")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    for label in ("Anel em volta do cursor", "Rastro", "Cor", "Só em combate", "Tamanho"):
        assert label in labels
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Anel em volta do cursor")
    row.control.GetScript(row.control, "OnClick")(row.control)
    assert ns.db.curRing is True and ns.Cursor.frame.GetScript(ns.Cursor.frame, "OnUpdate") is not None
