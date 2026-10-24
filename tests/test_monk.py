"""The monk's extras (Classes/Monk.lua): stagger bar for brewmasters, chi as gems or a bar."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
CLASS, SPEC = "MONK", 1
function UnitClass(u) if u == "player" or u == nil then return "Monge", CLASS end return "Guerreiro", "WARRIOR" end
function GetSpecialization() return SPEC end
STAGGER = 4000
function UnitStagger() return STAGGER end
local bHM = UnitHealthMax
function UnitHealthMax(u) if u == "player" then return 20000 end return bHM(u) end
"""


def preview(db=None, cls="MONK", spec=1):
    pre = GAME.replace('CLASS, SPEC = "MONK", 1', f'CLASS, SPEC = "{cls}", {spec}')
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=pre)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def tick(ns):
    f = ns.Monk.frame
    f.GetScript(f, "OnUpdate")(f, 0.2)


def test_page_has_the_monk_card():
    _, ns, _ = preview()
    ns.Panel.Open("classes")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    assert "Barra de Estagnar" in labels and "Chi em gemas" in labels


def test_stagger_bar_for_brewmasters():
    _, ns, g = preview()
    tick(ns)
    b = ns.Monk.stagger
    assert visible(b) and b.GetValue(b) == 4000 and b.GetMinMaxValues(b)[1] == 20000
    green = tuple(b.GetStatusBarTexture(b).vc.values())[:3]
    g.STAGGER = 14000                                       # 70% of health: heavy
    tick(ns)
    red = tuple(b.GetStatusBarTexture(b).vc.values())[:3]
    assert green[1] > green[0] and red[0] > red[1]
    bar = ns.ActionBars.modernFrame
    assert rect(bar)[1] + rect(bar)[3] < rect(b)[1] < rect(bar)[1] + rect(bar)[3] + 120   # the gems' spot


def test_stagger_hidden_when_empty_out_of_combat_and_for_other_specs():
    _, ns, g = preview()
    g.STAGGER = 0
    tick(ns)
    assert not visible(ns.Monk.stagger)
    _, ns, g = preview(spec=3)
    tick(ns)
    assert not visible(ns.Monk.stagger)
    _, ns, g = preview({"c_mon_stagger": False})
    tick(ns)
    assert not visible(ns.Monk.stagger)


def test_chi_as_gems_or_a_bar():
    _, ns, g = preview(spec=3)
    cr = ns.ClassResource
    assert visible(cr.gems[1]) and not visible(cr.bar)
    ns.db.c_mon_chi = False
    cr.Redraw()
    assert visible(cr.bar) and not visible(cr.gems[1])
    assert ns.db.resStyle != "bar"                           # only the monk's chi, not every class


def test_nothing_for_other_classes():
    _, ns, g = preview(cls="ROGUE")
    f = ns.Monk.frame
    assert f.GetScript(f, "OnUpdate") is None and not visible(ns.Monk.stagger)
