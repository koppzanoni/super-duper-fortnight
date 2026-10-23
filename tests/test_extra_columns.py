"""Hotkey text always visible, extra action bar columns in freed HUD space, more settings."""
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


# Pure layout: extra columns sit between the bar's outer end and its first slots.
def test_max_extra_columns_fit_the_free_space(pure):
    ns = load_pure(pure, "Core/Layout.lua")
    L = ns.Layout
    u = 0.5
    assert L.MaxExtraColumns(0, u) == 0
    assert L.MaxExtraColumns(L.EXTRA_PITCH * u * 2.5, u) == 2
    assert L.MaxExtraColumns(10000, u) == L.MAX_EXTRA


def test_mapx_shifts_only_the_bar_part_outside_the_split(pure):
    ns = load_pure(pure, "Core/Layout.lua")
    L = ns.Layout
    W, u, extra = 2000, 0.5, 100
    assert L.MapX(100, W, u, extra) == L.MapX(100, W, u)                     # cap: pinned left
    assert L.MapX(L.BAR_SPLIT, W, u, extra) == L.MapX(L.BAR_SPLIT, W, u)     # inner bar: pinned center
    assert L.MapX(680, W, u, extra) == L.MapX(680, W, u) - extra             # outer end: moves out
    assert L.MapX(710, W, u, extra) == L.MapX(710, W, u) - extra             # with the first column's art
    assert L.MapX(782, W, u, extra) == L.MapX(782, W, u)                     # the rest stays


def enabled_extras(ns):
    return sum(1 for b in ns.ActionBars.extra.values() if b.obEnabled)


def test_extra_columns_enable_four_buttons_each(lua, ns):
    boot(lua, ns, db={"extraCols": 2, "scale": 0.6})
    assert ns.HUD.extra == 2
    assert enabled_extras(ns) == 8
    assert len(ns.ActionBars.extra) == ns.Layout.MAX_EXTRA * 4


def test_extra_columns_limited_by_space(lua, ns):
    boot(lua, ns, db={"extraCols": 6, "scale": 1.0})  # 1920 wide at full scale: almost no free space
    _, u, stretch = ns.Layout.HudSize(1920, 1080, 1.0)
    assert ns.HUD.extra == ns.Layout.MaxExtraColumns(stretch, u)
    assert enabled_extras(ns) == ns.HUD.extra * 4


def test_extra_buttons_use_action_bars_6_and_7(lua, ns):
    boot(lua, ns)
    ids = sorted(b.binding for b in ns.ActionBars.extra.values())
    assert ids[0].startswith("MULTIACTIONBAR5BUTTON") and ids[-1].startswith("MULTIACTIONBAR6BUTTON")
    assert all(not b.obEnabled for b in ns.ActionBars.extra.values())


def test_orb_numbers_can_be_hidden(lua, ns):
    boot(lua, ns, db={"orbText": False})
    lua.execute("SHOWN = nil")
    ns.Orbs.health.pct.SetShown = lua.eval("function(_, v) SHOWN = v end")
    ns.Orbs.ApplyTextVisibility()
    assert lua.globals().SHOWN is False


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


# In-game: the copied column carried the bar end's bracket and the XP groove's cap, so pieces of
# them showed between the extra slots. The copy comes from a plain middle column instead.
def test_extra_column_art_is_copied_from_a_plain_middle_column(pure):
    ns = load_pure(pure, "Core/Layout.lua")
    L = ns.Layout
    assert L.SLICE_SRC >= 845                       # past the first two columns and the groove cap
    assert L.BAR_SPLIT == 774                       # between columns 1 and 2


# The 36 main buttons stay together: the first main column takes the slot next to column 2,
# the extra columns take the outer slots.
def test_main_buttons_stay_contiguous_with_extra_columns(lua, ns):
    boot(lua, ns, db={"extraCols": 2, "scale": 0.6})
    u = ns.HUD.u
    first_main = ns.ActionBars.buttons[1]       # row 1, column 1
    second_main = ns.ActionBars.buttons[2]
    extra1 = [b for b in ns.ActionBars.extra.values() if b.obColumn == 1][0]
    assert abs((second_main.obLeft - first_main.obLeft) - 71 * u) < 1.5 * u
    assert abs((first_main.obLeft - extra1.obLeft) - 72 * u) < 1.5 * u


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


def test_action_bar_always_floats_free(lua, ns):
    boot(lua, ns, pre=CHECKBOX_STUB, db={"scale": 0.7, "connectBar": True})
    used = []
    apply = ns.Media.Apply
    def recording(tex, key, *rest):
        used.append(key)
        return apply(tex, key, *rest)
    ns.Media.Apply = recording
    ns.HUD.Layout()
    assert "hud_connector" not in used
    assert lua.globals().CHECKBOXES["connectBar"] is None
    assert lua.globals().CHECKBOXES["showHotkeys"] is True
