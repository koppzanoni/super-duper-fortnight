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
    assert built == {"general", "visual", "bar", "frames", "cast", "inventory", "profiles", "infobar", "resources", "auras", "databars", "party", "raid", "plates", "chat", "tooltip", "quests", "skins", "cooldowns", "cursor", "automation"}
    for planned in ("reminders", "classes"):
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
    ns.Panel.Search("zona da lat")
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
    ns.Panel.Open("reminders")
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
    for sec in [s for s in ns.Panel.SECTIONS.values() if not s.soon and s.id != "profiles"]:  # Perfis: own tests
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
            elif row.kind == "cycle":
                options = [o[1] for o in row.options().values()]
                seen = set()
                for _ in options:
                    click(c.next)
                    seen.add(ns.Panel.Get(row))
                assert seen == set(options), row.label             # every option reachable, back to the start
            else:
                if row.label in ("Modo de edição", "Teclas de atalho da barra"):
                    click(c)
                    assert not visible(ns.Panel.frame), row.label     # the panel gives way to the mode
                    ns.EditMode.Stop(); ns.KeybindMode.Stop()
                    ns.Panel.Open(sec.id)
                elif row.label == "Instalador":
                    click(c)
                    assert visible(ns.Installer.frame) and not visible(ns.Panel.frame)
                    ns.Installer.frame.Hide(ns.Installer.frame)
                    ns.Panel.Open(sec.id)
                elif row.label == "Abrir inventário":
                    click(c)
                    assert ns.Inventory.frame.IsShown(ns.Inventory.frame)
                    ns.Panel.Open(sec.id)
                else:
                    click(c)
            checked.append(row.label)
    assert len(checked) == 93
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


# ------------------------------------------------------------------ Perfis page
def test_profiles_page_creates_switches_and_deletes():
    _, ns = preview()
    ns.Panel.Open("profiles")
    click(row(ns, "Novo perfil").control)
    assert ns.Profiles.Current() == "Perfil 2"
    cyc = row(ns, "Perfil deste personagem").control
    click(cyc.prev)
    assert ns.Profiles.Current() == "Padrão"
    click(cyc.next)
    assert ns.Profiles.Current() == "Perfil 2"
    click(row(ns, "Excluir este perfil").control)
    assert ns.Profiles.Current() == "Padrão" and ns.db.profiles["Perfil 2"] is None


def test_profiles_page_export_and_import_box():
    _, ns = preview()
    ns.db.modernCols = 9
    ns.Panel.Open("profiles")
    click(row(ns, "Exportar tudo").control)
    text = ns.Panel.textEdit.GetText(ns.Panel.textEdit)
    assert isinstance(text, str) and visible(ns.Panel.textBox) and text.startswith("OBUI1:")
    ns.db.modernCols = 12
    click(row(ns, "Importar").control)
    ns.Panel.textEdit.SetText(ns.Panel.textEdit, text)
    click(ns.Panel.textApply)
    assert ns.db.modernCols == 9 and "importado" in ns.Panel.textStatus.text
    ns.Panel.textEdit.SetText(ns.Panel.textEdit, "lixo")
    click(ns.Panel.textApply)
    assert "Não deu" in ns.Panel.textStatus.text


def test_profiles_page_presets_and_content():
    _, ns = preview()
    ns.Panel.Open("profiles")
    click(row(ns, "Compacto").control)
    assert ns.db.modernCols == 10
    s = row(ns, "Trocar sozinho pelo tipo de conteúdo").control
    click(s)
    assert ns.Profiles.AutoContent() is True


def test_changes_in_the_panel_land_in_the_active_profile():
    _, ns = preview()
    ns.Panel.Open("bar")
    r = row(ns, "Colunas")
    click(r.control.minus)
    assert ns.db.profiles["Padrão"].modernCols == 11


def test_tall_page_scrolls_inside_the_window():
    _, ns = preview()
    ns.Panel.Open("profiles")
    view, body = ns.Panel.view, ns.Panel.body
    assert view.clips and body.GetHeight(body) > view.GetHeight(view)
    view.GetScript(view, "OnMouseWheel")(view, -1)
    assert view.GetVerticalScroll(view) == 40
    for _ in range(100):
        view.GetScript(view, "OnMouseWheel")(view, -1)
    assert abs(view.GetVerticalScroll(view) - (body.GetHeight(body) - view.GetHeight(view))) < 0.5
