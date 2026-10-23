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
    assert L.MapX(710, W, u, extra) == L.MapX(710, W, u)                     # first slots stay


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
