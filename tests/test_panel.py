"""ObsidianUI's own settings window (Settings/Panel.lua)."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=db)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def rows(ns):
    return [r for r in ns.Panel.rows.values() if r.row is not None]


def row(ns, label):
    return next(r for r in rows(ns) if r.row.label == label)


def test_slash_opens_and_closes_the_panel():
    rt, ns = preview()
    rt.globals().SlashCmdList.OBSIDIANUI("")
    assert visible(ns.Panel.frame) and ns.Panel.current == "general"
    rt.globals().SlashCmdList.OBSIDIANUI("")
    assert not visible(ns.Panel.frame)


def test_sidebar_lists_built_and_planned_modules_in_groups():
    _, ns = preview()
    names = [s.name for s in ns.Panel.SECTIONS.values()]
    assert names[0] == "Geral" and names[-1] == "Perfis"
    built = {s.id for s in ns.Panel.SECTIONS.values() if not s.soon}
    assert built == {"general", "bar", "frames", "cast", "inventory"}
    for planned in ("chat", "raid", "plates", "classes", "automation"):
        assert any(s.id == planned and s.soon for s in ns.Panel.SECTIONS.values())


def test_steps_change_the_bar_live():
    _, ns = preview()
    ns.Panel.Open("bar")
    r = row(ns, "Colunas")
    r.control.minus.GetScript(r.control.minus, "OnClick")(r.control.minus)
    assert ns.db.modernCols == 11
    assert abs(rect(ns.ActionBars.modernFrame)[2] - (11 * 54 + 10 * 7)) < 1


def test_toggle_switches_the_vertical_bar():
    _, ns = preview()
    ns.Panel.Open("bar")
    s = row(ns, "Barra vertical 1").control
    s.GetScript(s, "OnClick")(s)
    assert ns.db.vbar1 is True and visible(ns.VerticalBars.container)


def test_colour_choice_asks_for_a_reload():
    rt, ns = preview()
    rt.execute("POPUPS = {}; function StaticPopup_Show(n) POPUPS[#POPUPS + 1] = n end")
    ns.Panel.Open("general")
    seg = row(ns, "Cor da HUD").control
    blue = next(b for b in seg.buttons.values() if b.value == "blue")
    blue.GetScript(blue, "OnClick")(blue)
    assert ns.db.modernColor == "blue" and list(rt.globals().POPUPS.values()) == ["OBSIDIANUI_RELOAD"]


def test_search_finds_options_across_modules():
    _, ns = preview()
    ns.Panel.Open()
    ns.Panel.Search("lat")
    labels = [r.row.label for r in rows(ns)]
    assert labels == ["Zona da latência (verde)"]
    ns.Panel.Search("vertical")
    assert [r.row.label for r in rows(ns)] == ["Barra vertical 1", "Barra vertical 2"]


def test_cast_toggles_hide_the_zone_parts():
    rt, ns = preview()
    rt.execute("""
      function GetTime() return T end
      function UnitCastingInfo() return "x", "", 1, 10120, 12620 end
      T = 10; PREVIEW_FIRE("UNIT_SPELLCAST_SENT", "player"); T = 10.12; PREVIEW_FIRE("UNIT_SPELLCAST_START", "player")
    """)
    assert visible(ns.CastBar.queue)
    ns.Panel.Open("cast")
    s = row(ns, "Marca da janela de fila").control
    s.GetScript(s, "OnClick")(s)
    assert ns.db.castQueue is False and not visible(ns.CastBar.queue)
    s = row(ns, "Zona da latência (verde)").control
    s.GetScript(s, "OnClick")(s)
    assert not visible(ns.CastBar.lag) and not visible(ns.CastBar.lagText)


def test_planned_module_shows_em_breve():
    _, ns = preview()
    ns.Panel.Open("chat")
    assert "Em breve" in ns.Panel.lead.text and rows(ns) == []


def test_headings_upper_case_keeps_accents():
    _, ns = preview()
    assert ns.Panel.Upper("Latência e Aparência") == "LATÊNCIA E APARÊNCIA"
