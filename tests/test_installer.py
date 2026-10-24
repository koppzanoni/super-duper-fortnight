"""Installer (Settings/Installer.lua, NaowhUI's idea): a few steps on the first login."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

PRE = "POPUPS = {}; function StaticPopup_Show(n) POPUPS[#POPUPS + 1] = n end"


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=db, pre=PRE)
    return rt, rt.globals().PREVIEW_NS


def visible(region):
    return bool(region.IsVisible(region))


def click(b):
    b.GetScript(b, "OnClick")(b)


def choose(ns, value):
    b = next(c for c in ns.Installer.choices.values() if c.value == value and visible(c))
    click(b)


def test_opens_on_the_first_login_only():
    _, ns = preview()
    assert visible(ns.Installer.frame) and ns.Installer.step == 1
    _, ns = preview({"installed": True})
    assert not visible(ns.Installer.frame)


def test_steps_go_forward_and_back():
    _, ns = preview()
    I = ns.Installer
    click(I.nextButton)
    assert I.step == 2 and I.counter.text == "2 / 5"
    click(I.prevButton)
    assert I.step == 1 and not visible(I.prevButton)


def test_choices_apply_on_finish():
    rt, ns = preview()
    I = ns.Installer
    click(I.nextButton)               # 2: size
    choose(ns, "1440")
    click(I.nextButton)               # 3: role
    choose(ns, "healer")
    click(I.nextButton)               # 4: colour
    choose(ns, "black")
    click(I.nextButton)               # 5: done
    assert I.nextButton.label.text == "Concluir"
    click(I.nextButton)
    assert not visible(I.frame) and ns.db.installed is True
    assert ns.db.scale == 0.9 and ns.db.modernRows == 3 and ns.db.layout.player is not None
    assert list(rt.globals().POPUPS.values()) == []          # same colour: no reload


def test_another_colour_asks_for_a_reload():
    rt, ns = preview()
    I = ns.Installer
    for _ in range(3):
        click(I.nextButton)
    choose(ns, "blue")
    click(I.nextButton)
    click(I.nextButton)
    assert ns.db.modernColor == "blue" and list(rt.globals().POPUPS.values()) == ["OBSIDIANUI_RELOAD"]


def test_skip_marks_it_done_and_keeps_the_settings():
    _, ns = preview()
    click(ns.Installer.skipButton)
    assert not visible(ns.Installer.frame) and ns.db.installed is True and ns.db.scale == 1


def test_slash_and_panel_reopen_it():
    rt, ns = preview({"installed": True})
    rt.globals().SlashCmdList.OBSIDIANUI("instalar")
    assert visible(ns.Installer.frame) and ns.Installer.step == 1
