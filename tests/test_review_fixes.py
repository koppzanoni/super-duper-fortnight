"""Regression tests for the final review findings (Important 1-4, 6-8)."""
import pytest

from conftest import load_addon_file, toc_files

BLIZZ_BAGS = """
BLIZZ_OPEN = false
function OpenAllBags() BLIZZ_OPEN = true end
function CloseAllBags() BLIZZ_OPEN = false end
function ToggleAllBags() if BLIZZ_OPEN then CloseAllBags() else OpenAllBags() end end
"""


def boot(lua, ns, pre=""):
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


def test_paging_in_combat_does_not_call_blizzard_update_action(lua, ns):
    boot(lua, ns)
    b = ns.ActionBars.buttons[1]
    before = b.calls.UpdateAction or 0
    lua.globals().STUB_COMBAT = True
    b.hooks.OnAttributeChanged(b, "action", 13)
    assert (b.calls.UpdateAction or 0) == before


def test_paging_out_of_combat_updates_action(lua, ns):
    boot(lua, ns)
    b = ns.ActionBars.buttons[1]
    before = b.calls.UpdateAction or 0
    b.hooks.OnAttributeChanged(b, "action", 13)
    assert (b.calls.UpdateAction or 0) == before + 1


def test_every_button_registers_its_action_at_login(lua, ns):
    boot(lua, ns)
    for i in range(1, len(ns.ActionBars.buttons) + 1):
        assert (ns.ActionBars.buttons[i].calls.UpdateAction or 0) >= 1


def test_inventory_toggle_in_combat_waits_when_protected(lua, ns):
    boot(lua, ns)
    shown = {"v": False}
    f = ns.Inventory.frame
    f.Show = lambda self: shown.__setitem__("v", True)
    f.Hide = lambda self: shown.__setitem__("v", False)
    f.IsShown = lambda self: shown["v"]
    f.IsProtected = lambda self: True
    lua.globals().STUB_COMBAT = True
    ns.Inventory.Toggle()
    assert shown["v"] is False
    lua.globals().STUB_COMBAT = False
    lua.execute('STUB_FIRE("PLAYER_REGEN_ENABLED")')
    assert shown["v"] is True


def test_orb_update_survives_secret_formatting_errors(lua, ns):
    boot(lua, ns, pre='function AbbreviateNumbers() error("secret value") end')
    lua.execute('STUB_FIRE("UNIT_HEALTH", "player")')
    lua.execute('STUB_FIRE("UNIT_POWER_FREQUENT", "player")')
    lua.execute('STUB_FIRE("UNIT_HEALTH", "target")')


def test_b_key_opens_in_one_press_after_closing_from_our_button(lua, ns):
    boot(lua, ns, pre=BLIZZ_BAGS)
    g = lua.globals()
    shown = {"v": False}
    f = ns.Inventory.frame
    f.Show = lambda self: shown.__setitem__("v", True)
    f.Hide = lambda self: shown.__setitem__("v", False)
    f.IsShown = lambda self: shown["v"]
    g.ToggleAllBags()
    assert shown["v"] is True
    g.STUB_TIME = 101
    ns.Inventory.Toggle()  # closed by our HUD button
    assert shown["v"] is False
    g.STUB_TIME = 102
    g.ToggleAllBags()  # one B press must open again
    assert shown["v"] is True


def test_chat_moved_off_the_hud_every_login(lua, ns):
    boot(lua, ns, pre="""
      CHAT_MOVES = 0
      ChatFrame1 = CreateFrame()
      ChatFrame1.GetBottom = function() return 20 end
      ChatFrame1.SetPoint = function() CHAT_MOVES = CHAT_MOVES + 1 end
    """)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    assert lua.globals().CHAT_MOVES == 2


def test_chat_left_alone_when_user_put_it_above_hud(lua, ns):
    boot(lua, ns, pre="""
      CHAT_MOVES = 0
      ChatFrame1 = CreateFrame()
      ChatFrame1.GetBottom = function() return 900 end
      ChatFrame1.SetPoint = function() CHAT_MOVES = CHAT_MOVES + 1 end
    """)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    assert lua.globals().CHAT_MOVES == 0


def test_override_action_bar_is_hidden(lua, ns):
    boot(lua, ns)
    assert "OverrideActionBar" in list(ns.Data.FRAME_CANDIDATES.overridebar.values())
