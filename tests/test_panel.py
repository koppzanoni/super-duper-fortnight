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


# Every control of every page that is not "em breve": clicked, the value changes, nothing errors.
def click(b):
    b.GetScript(b, "OnClick")(b)


def test_every_control_of_every_built_page_works():
    rt, ns = preview()
    rt.execute("POPUPS = {}; function StaticPopup_Show(n) POPUPS[#POPUPS + 1] = n end")
    checked = []
    for sec in [s for s in ns.Panel.SECTIONS.values() if not s.soon]:
        ns.Panel.Open(sec.id)
        for r in rows(ns):
            row = r.row
            c = r.control
            if row.kind == "toggle":
                before = ns.Panel.Get(row)
                click(c)
                assert ns.Panel.Get(row) == (not before), row.label
                click(c)
                assert ns.Panel.Get(row) == before, row.label
            elif row.kind == "steps":
                before = ns.Panel.Get(row)
                click(c.plus if before < row.max else c.minus)
                assert ns.Panel.Get(row) != before, row.label
                click(c.minus if before < row.max else c.plus)
                assert abs(ns.Panel.Get(row) - before) < 1e-9, row.label
            elif row.kind == "choice":
                for b in c.buttons.values():
                    click(b)
                    assert ns.Panel.Get(row) == b.value, row.label
            else:
                if row.label in ("Modo de edição", "Teclas de atalho da barra"):
                    click(c)
                    assert not visible(ns.Panel.frame), row.label     # the panel gives way to the mode
                    ns.EditMode.Stop(); ns.KeybindMode.Stop()
                    ns.Panel.Open(sec.id)
                elif row.label == "Abrir inventário":
                    click(c)
                    assert ns.Inventory.frame.IsShown(ns.Inventory.frame)
                    ns.Panel.Open(sec.id)
                else:
                    click(c)
            checked.append(row.label)
    assert len(checked) == 16
    assert "OBSIDIANUI_RELOAD" in list(rt.globals().POPUPS.values())


def test_edit_mode_button_really_starts_the_mode():
    _, ns = preview()
    ns.Panel.Open("general")
    click(row(ns, "Modo de edição").control)
    assert ns.EditMode.active


def test_keybind_button_really_starts_the_mode():
    _, ns = preview()
    ns.Panel.Open("general")
    click(row(ns, "Teclas de atalho da barra").control)
    assert ns.KeybindMode.active


def test_restore_positions_button_forgets_the_layout():
    _, ns = preview({"layout": {"map": {"x": 900, "y": 600}}})
    ns.Panel.Open("general")
    click(row(ns, "Restaurar posições").control)
    assert ns.db.layout is None


def test_header_buttons_start_the_edit_mode_and_close():
    _, ns = preview()
    ns.Panel.Open()
    click(ns.Panel.editButton)
    assert ns.EditMode.active and not visible(ns.Panel.frame)
    ns.EditMode.Stop()
    ns.Panel.Open()
    click(ns.Panel.closeButton)
    assert not visible(ns.Panel.frame)
