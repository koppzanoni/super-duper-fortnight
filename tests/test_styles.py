"""Glass of the window panels and unit frame styles, chosen on the Visual page."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})))
    return rt, rt.globals().PREVIEW_NS


def inv_alpha(ns):
    return ns.Inventory.frame.obFillAlpha


def test_glass_makes_window_panels_see_through():
    _, solid = preview({"glass": "solid"})
    _, smoke = preview({"glass": "smoke"})
    assert inv_alpha(smoke) < inv_alpha(solid) - 0.2
    assert smoke.Inventory.frame.sheen.IsShown(smoke.Inventory.frame.sheen)


def test_glass_changes_live_and_buttons_stay_solid():
    _, ns = preview({"glass": "solid"})
    before = inv_alpha(ns)
    ns.db.glass = "crystal"
    ns.Widgets.ApplyGlass()
    assert inv_alpha(ns) < before
    assert ns.Inventory.frame.inner is not None
    ns.db.glass = "arcane"
    ns.Widgets.ApplyGlass()
    assert ns.Inventory.frame.gems[1].IsShown(ns.Inventory.frame.gems[1])


def test_frame_styles():
    _, ns = preview({"frameStyle": "flat"})
    p = ns.UnitFrames.frames.player
    assert not p.health.obShine.IsShown(p.health.obShine)
    ns.db.frameStyle = "arcane"
    ns.UnitFrames.ApplyStyle()
    # the level is a clean baked chip now; the arcane style keeps its glow ring and gold line
    assert p.obRing.IsShown(p.obRing) and p.obGold.IsShown(p.obGold)
    ns.db.frameStyle = "plate"
    ns.UnitFrames.ApplyStyle()
    assert p.obPlate.IsShown(p.obPlate) and not p.obRing.IsShown(p.obRing)


def test_choices_on_the_visual_page():
    _, ns = preview()
    ns.Panel.Open("visual")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    assert "Vidro das janelas" in labels and "Quadros" in labels


def test_panels_have_rounded_corners_and_windows_a_soft_shadow():
    _, ns = preview()
    inv = ns.Inventory.frame
    assert inv.fill.slice is not None and "soft_fill" in inv.fill.file
    assert inv.rim[1].slice is not None and inv.rim[1].grad is not None  # lit from above
    assert inv.shadow.IsShown(inv.shadow) and inv.shadow.GetLeft(inv.shadow) < inv.GetLeft(inv)
    sort = ns.Inventory.sortButton
    assert sort.fill.slice is not None and sort.shadow is None  # buttons: no shadow


def test_selected_tab_keeps_its_look_when_the_glass_changes():
    _, ns = preview()
    tab = ns.Inventory.statsTab
    before = tab.obFillAlpha
    ns.db.glass = "crystal"
    ns.Widgets.ApplyGlass()
    assert tab.obFillAlpha == before == 0.1
