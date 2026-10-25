"""Visual (Core/Look.lua): font, outline, bar texture, number format and reaction/power colours."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=db)
    return rt, rt.globals().PREVIEW_NS


def frames(ns):
    return ns.UnitFrames.frames


def test_defaults_keep_the_current_look():
    _, ns = preview()
    assert ns.Look.Font() is None and ns.Look.Outline() == "OUTLINE"
    assert str(ns.Look.BarTexture()).endswith("mod_gloss")
    p = frames(ns).player
    assert "/" in p.hpText.text


def test_font_and_outline_reach_the_hud_texts():
    _, ns = preview({"font": "friz", "outline": "THICKOUTLINE"})
    p = frames(ns).player
    for t in (p.name, p.hpText, p.levelText):
        assert t.fontPath == "Fonts\\FRIZQT__.TTF" and t.fontFlags == "THICKOUTLINE"
    assert ns.CastBar.time.fontPath == "Fonts\\FRIZQT__.TTF"


def test_bar_texture_reaches_every_bar():
    _, ns = preview({"barTex": "flat"})
    p = frames(ns).player
    flat = "Interface\\Buttons\\WHITE8X8"
    assert p.health.GetStatusBarTexture(p.health).file == flat
    bar = ns.Resolve.First(ns.Data.FRAME_CANDIDATES.castbar)[0]
    assert bar.GetStatusBarTexture(bar).file == flat
    assert ns.XPBar.xp.GetStatusBarTexture(ns.XPBar.xp).file == flat


def test_number_format():
    _, ns = preview({"numFmt": "full"})
    assert frames(ns).player.hpText.text == "28.400 / 39.500"
    _, ns = preview({"numFmt": "short"})
    assert frames(ns).player.hpText.text == "28.4K / 39.5K"


def test_reaction_and_power_colours():
    _, ns = preview({"colors": {"hostile": [0, 0, 1], "MANA": [1, 0, 1]}})
    t = frames(ns).target
    vc = list(t.health.GetStatusBarTexture(t.health).vc.values())[:3]
    assert vc == [0, 0, 1]
    p = frames(ns).player
    assert list(p.power.GetStatusBarTexture(p.power).vc.values())[:3] == [1, 0, 1]


def test_changes_apply_live_from_the_panel():
    _, ns = preview()
    ns.Panel.Open("visual")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Textura das barras")
    flat = next(b for b in row.control.buttons.values() if b.value == "flat")
    flat.GetScript(flat, "OnClick")(flat)
    p = frames(ns).player
    assert p.health.GetStatusBarTexture(p.health).file == "Interface\\Buttons\\WHITE8X8"
    assert ns.db.profiles["Padrão"].barTex == "flat"


def test_every_hud_text_is_on_the_type_scale():
    """Names, values, labels: four sizes (Look.TYPE), all in the chosen font (the zone name used to
    keep the game's serif)."""
    import sys
    from conftest import ROOT
    sys.path.insert(0, str(ROOT / "tools"))
    import preview_render
    rt = preview_render.run_addon(vbars=True, db={"installed": True, "font": "arial"})
    ns = rt.globals().PREVIEW_NS
    sizes = set(ns.Look.TYPE.values())
    for r in rt.globals().REGIONS.values():
        if r.kind == "font" and r.IsVisible(r) and r.text and r.fsize:
            assert round(r.fsize) in sizes, (r.text, r.fsize)
    zone = [r for r in rt.globals().REGIONS.values() if r.kind == "font" and r.text == "Raven Hill"][0]
    assert zone.fsize == ns.Look.TYPE.label
