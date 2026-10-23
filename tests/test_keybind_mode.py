"""Key binding mode: hover an action button and press a key to bind it (the default quick
keybind mode does not reach the addon's buttons)."""
from conftest import load_addon_file, toc_files

PRE = """
  BINDINGS, SAVED = {}, 0
  function SetBinding(key, command) BINDINGS[key] = command or "CLEARED"; return true end
  function SaveBindings() SAVED = SAVED + 1 end
  function GetCurrentBindingSet() return 1 end
  function GetBindingKey(command)
    local keys = {}
    for k, c in pairs(BINDINGS) do if c == command then keys[#keys + 1] = k end end
    table.sort(keys)
    return unpack(keys)
  end
  SHIFT, CTRL, ALT = false, false, false
  function IsShiftKeyDown() return SHIFT end
  function IsControlKeyDown() return CTRL end
  function IsAltKeyDown() return ALT end
  SettingsPanel = { IsShown = function() return false end }
"""


def boot(lua, ns):
    lua.execute(PRE)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


def hover(ns, i=1):
    b = ns.ActionBars.buttons[i]
    b.hooks["OnEnter"](b)
    return b


def press(ns, key):
    c = ns.KeybindMode.catcher
    c.handlers["OnKeyDown"](c, key)


def test_hover_and_press_binds_the_buttons_command(lua, ns):
    boot(lua, ns)
    ns.KeybindMode.Start()
    b = hover(ns)
    press(ns, "Q")
    g = lua.globals()
    assert g.BINDINGS["Q"] == b.binding and g.SAVED == 1


def test_modifiers_are_part_of_the_key(lua, ns):
    boot(lua, ns)
    ns.KeybindMode.Start()
    b = hover(ns, 2)
    lua.execute("SHIFT, CTRL = true, true")
    press(ns, "LSHIFT")  # a modifier alone binds nothing
    press(ns, "F")
    g = lua.globals()
    assert "LSHIFT" not in dict(g.BINDINGS) and g.BINDINGS["CTRL-SHIFT-F"] == b.binding


def test_backspace_clears_the_buttons_keys(lua, ns):
    boot(lua, ns)
    b = ns.ActionBars.buttons[1]
    lua.globals().BINDINGS["1"] = b.binding
    ns.KeybindMode.Start()
    hover(ns)
    press(ns, "BACKSPACE")
    assert lua.globals().BINDINGS["1"] == "CLEARED"


def test_escape_leaves_the_mode_without_binding(lua, ns):
    boot(lua, ns)
    ns.KeybindMode.Start()
    hover(ns)
    press(ns, "ESCAPE")
    assert not ns.KeybindMode.active and "ESCAPE" not in dict(lua.globals().BINDINGS)


def test_keys_pass_through_when_not_over_a_button_or_mode_off(lua, ns):
    boot(lua, ns)
    b = hover(ns)  # mode off: hovering does nothing
    press(ns, "Q")
    ns.KeybindMode.Start()
    b.hooks["OnLeave"](b)
    press(ns, "W")
    assert len(dict(lua.globals().BINDINGS)) == 0


def test_combat_ends_the_mode(lua, ns):
    boot(lua, ns)
    ns.KeybindMode.Start()
    lua.execute('STUB_FIRE("PLAYER_REGEN_DISABLED")')
    assert not ns.KeybindMode.active


# In game nothing was bound: the settings window stayed open (keys were passed on while it was
# open) and the keyboard catcher had no size. Keys over a button bind even with it open.
def test_binds_while_the_settings_window_is_open(lua, ns):
    boot(lua, ns)
    lua.execute("SettingsPanel.IsShown = function() return true end")
    ns.KeybindMode.Start()
    b = hover(ns)
    press(ns, "E")
    assert lua.globals().BINDINGS["E"] == b.binding


def test_escape_with_settings_open_closes_them_and_keeps_the_mode(lua, ns):
    boot(lua, ns)
    lua.execute("SettingsPanel.IsShown = function() return true end")
    ns.KeybindMode.Start()
    press(ns, "ESCAPE")
    assert ns.KeybindMode.active


def test_catcher_covers_the_screen(lua, ns):
    lua.execute("ALLPOINTS = {}")
    lua.execute("""
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        f.SetAllPoints = function(self, rel) ALLPOINTS[self] = rel end
        return f
      end
    """)
    boot(lua, ns)
    assert lua.globals().ALLPOINTS[ns.KeybindMode.catcher] is not None
