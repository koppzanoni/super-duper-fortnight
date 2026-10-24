"""Hotkey text always visible, action button texts and template pieces fit the button."""
from conftest import load_addon_file, load_pure, toc_files


def boot(lua, ns, pre="", db=None):
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    for k, v in (db or {}).items():
        ns.db[k] = v
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


# Frames and their textures remember whether they are shown.
SHOWN_PRE = """
  local cf = CreateFrame
  local function track(o)
    o.Show = function(self) self.shown = true end
    o.Hide = function(self) self.shown = false end
    o.SetShown = function(self, v) self.shown = v and true or false end
    return o
  end
  function CreateFrame(...)
    local f = track(cf(...))
    f.CreateTexture = function() return track(cf()) end
    return f
  end
"""


HOTKEY_PRE = """
  local cf = CreateFrame
  function CreateFrame(...)
    local f = cf(...)
    local hk = setmetatable({ shown = true }, { __index = function() return function() end end })
    hk.SetText = function(self, t) self.text = t end
    hk.Show = function(self) self.shown = true end
    hk.Hide = function(self) self.shown = false end
    hk.SetShown = function(self, v) self.shown = v and true or false end
    f.HotKey = hk
    -- Blizzard finds no binding for our buttons: it blanks and hides the text.
    f.UpdateHotkeys = function(self) self.HotKey:SetText(""); self.HotKey:Hide() end
    return f
  end
  function GetBindingKey(b) if b == "ACTIONBUTTON1" then return "1" end return nil end
  function GetBindingText(k) return k end
"""


def test_hotkey_shown_again_after_blizzard_hides_it(lua, ns):
    boot(lua, ns, pre=HOTKEY_PRE)
    b = ns.ActionBars.buttons[1]
    b.UpdateHotkeys(b)
    assert b.HotKey.text == "1" and b.HotKey.shown is True


def test_hotkeys_can_be_turned_off(lua, ns):
    boot(lua, ns, pre=HOTKEY_PRE, db={"showHotkeys": False})
    b = ns.ActionBars.buttons[1]
    b.UpdateHotkeys(b)
    assert b.HotKey.shown is False


def test_media_apply_range(pure):
    pure.execute("""
      function fakeTexture()
        local t = {}
        function t:SetTexture(f) self.file = f end
        function t:SetTexCoord(...) self.coords = { ... } end
        return t
      end
    """)
    ns = load_pure(pure, "Core/Media.lua")
    ns.MediaManifest = pure.eval('{ bar = { file = "X/bar", w = 512, h = 256, potW = 1024, potH = 512 } }')
    t = pure.eval("fakeTexture()")
    ns.Media.ApplyRange(t, "bar", False, 0.25, 0.5)
    assert list(t.coords.values()) == [0.125, 0.25, 0, 0.5]
    ns.Media.ApplyRange(t, "bar", True, 0.25, 0.5)
    assert list(t.coords.values()) == [0.25, 0.125, 0, 0.5]


# In-game (small HUD): key text and stack count overlapped, icons covered the slot frames.
SIZE_PRE = """
  local cf = CreateFrame
  local function text()
    local t = setmetatable({}, { __index = function() return function() end end })
    t.GetFont = function() return "Fonts/ARIALN.TTF", 12, "OUTLINE" end
    t.SetFont = function(self, _, size) self.size = size end
    return t
  end
  function CreateFrame(...)
    local f = cf(...)
    f.HotKey, f.Count, f.Name = text(), text(), text()
    f.icon = setmetatable({}, { __index = function() return function() end end })
    f.icon.SetSize = function(self, w, h) self.w, self.h = w, h end
    return f
  end
"""


def test_button_text_and_icon_scale_with_the_button(lua, ns):
    boot(lua, ns, pre=SIZE_PRE)
    b = ns.ActionBars.buttons[1]
    b.hooks.OnSizeChanged(b, 26, 28)
    assert b.HotKey.size <= 9 and b.Count.size <= 10
    assert b.icon.w == 26 and b.icon.h == 26          # square, inside the slot
    b.hooks.OnSizeChanged(b, 56, 61)
    assert b.HotKey.size >= 14


# In-game: Blizzard's template keeps fixed-size highlight/pushed/checked/cooldown pieces and a
# mask that crops the icon; on our smaller buttons they were offset and bigger than the slot.
PIECES_PRE = """
  FIT = {}
  REMOVED_MASK = 0
  local cf = CreateFrame
  local function piece(name)
    local t = setmetatable({}, { __index = function() return function() end end })
    t.SetAllPoints = function(_, target) FIT[name] = target end
    return t
  end
  function CreateFrame(...)
    local f = cf(...)
    f.icon = piece("icon")
    f.icon.RemoveMaskTexture = function() REMOVED_MASK = REMOVED_MASK + 1 end
    f.IconMask = piece("mask")
    f.cooldown = piece("cooldown")
    f.Flash = piece("flash")
    local hl, pu, ch = piece("highlight"), piece("pushed"), piece("checked")
    f.GetHighlightTexture = function() return hl end
    f.GetPushedTexture = function() return pu end
    f.GetCheckedTexture = function() return ch end
    return f
  end
"""


def test_template_pieces_fit_the_icon(lua, ns):
    boot(lua, ns, pre=PIECES_PRE)
    g = lua.globals()
    b = ns.ActionBars.buttons[1]
    same = lua.eval("rawequal")
    for name in ("highlight", "pushed", "checked", "cooldown", "flash"):
        assert g.FIT[name] is not None, name
    assert g.REMOVED_MASK >= 1


# The "connect the bar to the sides" option was removed: the bar always floats free, even for a
# player whose saved settings still have it on, and the option is gone from the settings panel.
CHECKBOX_STUB = """
  CHECKBOXES = {}
  local function setting(key)
    return { SetValueChangedCallback = function() end }
  end
  Settings = {
    RegisterVerticalLayoutCategory = function()
      return { GetID = function() return 1 end }, { AddInitializer = function() end }
    end,
    RegisterAddOnSetting = function(cat, variable, key) local s = setting(key); s.key = key; return s end,
    CreateCheckbox = function(cat, s) CHECKBOXES[s.key] = true end,
    CreateSlider = function() end,
    CreateSliderOptions = function() return { SetLabelFormatter = function() end } end,
    CreateControlTextContainer = function()
      return { Add = function() end, GetData = function() return {} end }
    end,
    CreateDropdown = function() end,
    RegisterAddOnCategory = function() end,
  }
  MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
"""
