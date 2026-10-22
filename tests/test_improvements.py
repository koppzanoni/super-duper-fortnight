"""Analysis round 2: in-game bugs, lost Blizzard features and inventory polish."""
from conftest import load_addon_file, load_pure, new_runtime, toc_files


def data_ns(rt=None):
    rt = rt or new_runtime()
    return load_addon_file(rt, "Core/Data.lua", rt.table())


def boot(lua, ns, pre=""):
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


# 1. Unit frames are filled right after creation (/reload with a target or pet).
def test_unit_frames_filled_on_login_without_target_change(lua, ns):
    boot(lua, ns, pre="""
      ASKED = {}
      function UnitExists() return true end
      function UnitName(u) ASKED[u] = true; return "X" end
    """)
    asked = lua.globals().ASKED
    for unit in ("target", "focus", "pet", "targettarget"):
        assert asked[unit], unit


# 2. Blizzard's UpdateHotkeys must not wipe our key text.
HOTKEY_PRE = """
  local cf = CreateFrame
  function CreateFrame(...)
    local f = cf(...)
    local hk = setmetatable({}, { __index = function() return function() end end })
    hk.SetText = function(self, t) self.text = t end
    f.HotKey = hk
    f.UpdateHotkeys = function(self) self.HotKey:SetText("\\226\\151\\143") end
    return f
  end
  function GetBindingKey(b) if b == "ACTIONBUTTON1" then return "1" end return nil end
  function GetBindingText(k) return k end
"""


def test_hotkey_text_survives_blizzard_update(lua, ns):
    boot(lua, ns, pre=HOTKEY_PRE)
    b = ns.ActionBars.buttons[1]
    assert b.HotKey.text == "1"
    b.UpdateHotkeys(b)
    assert b.HotKey.text == "1"


# 3. Inventory: default spot clears the minimap and the HUD; dragged spot is remembered.
def test_inventory_default_placement_clears_minimap_and_hud(lua, ns):
    boot(lua, ns)
    W, H, hud = 1920.0, 1080.0, 270.0
    point, x, y, h = ns.Inventory.DefaultPlacement(W, H, hud)
    assert point == "BOTTOMRIGHT"
    assert -x >= 0.25 * H          # right edge left of the minimap
    assert y >= hud                # bottom above the HUD
    assert y + h <= H              # top inside the screen


def test_inventory_default_placement_shrinks_with_big_hud(lua, ns):
    boot(lua, ns)
    _, _, y, h = ns.Inventory.DefaultPlacement(1920.0, 1080.0, 400.0)
    assert y + h <= 1080.0


def test_inventory_position_saved_and_restored(lua, ns):
    boot(lua, ns)
    f = ns.Inventory.frame
    lua.execute("SAVED_POINTS = {}")
    f.GetPoint = lua.eval('function() return "CENTER", nil, "CENTER", 12, -34 end')
    ns.Inventory.SavePosition()
    pos = ns.db.invPos
    assert (pos.point, pos.x, pos.y) == ("CENTER", 12, -34)
    f.SetPoint = lua.eval('function(_, p, _, _, x, y) SAVED_POINTS[#SAVED_POINTS + 1] = { p, x, y } end')
    f.obPlaced = False
    ns.Inventory.Layout()
    last = lua.globals().SAVED_POINTS[1]
    assert (last[1], last[2], last[3]) == ("CENTER", 12, -34)


# 4. Combo gems ignore energy ticks and do not rebuild when nothing changed.
GEMS_PRE = """
  POWER_READS = 0
  function issecretvalue() return false end
  function UnitClass() return "Ladino", "ROGUE" end
  function UnitPower(_, t) if t == 4 then POWER_READS = POWER_READS + 1 end return 2 end
  function UnitPowerMax() return 5 end
"""


def test_class_resource_ignores_other_power_tokens(lua, ns):
    boot(lua, ns, pre=GEMS_PRE)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    g = lua.globals()
    before = g.POWER_READS
    lua.execute('STUB_FIRE("UNIT_POWER_FREQUENT", "player", "ENERGY")')
    assert g.POWER_READS == before
    lua.execute('STUB_FIRE("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")')
    assert g.POWER_READS == before + 1


def test_class_resource_skips_redraw_when_unchanged(lua, ns):
    boot(lua, ns, pre=GEMS_PRE)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    calls = {"n": 0}
    orig = ns.Media.Apply
    ns.Media.Apply = lambda *a: calls.__setitem__("n", calls["n"] + 1)
    lua.execute('STUB_FIRE("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")')
    assert calls["n"] == 0
    ns.Media.Apply = orig


# 5. Buff row is centered on the screen for any number of auras.
def test_aura_row_offset_centers_row(pure):
    ns = load_pure(pure, "Core/Init.lua", "Core/Resolve.lua", "Core/Layout.lua", "Core/Data.lua") \
        if False else None
    from conftest import new_runtime
    rt = new_runtime()
    ns = rt.table()
    load_addon_file(rt, "Core/Data.lua", ns)
    assert ns.Data.AuraRowOffset(1, 16, 30) == 0
    assert ns.Data.AuraRowOffset(5, 16, 30) == -60
    assert ns.Data.AuraRowOffset(40, 16, 30) == -225
    assert ns.Data.AuraRowOffset(0, 16, 30) == 0


# 6. Target and focus cast bars come back under our frames.
def test_target_and_focus_castbars_reparented(lua, ns):
    boot(lua, ns, pre="""
      PARENTS = {}
      for _, n in ipairs({ "TargetFrameSpellBar", "FocusFrameSpellBar" }) do
        local f = CreateFrame()
        f.SetParent = function(_, p) PARENTS[n] = p end
        _G[n] = f
      end
    """)
    same = lua.eval("function(a, b) return rawequal(a, b) end")
    parents = lua.globals().PARENTS
    assert same(parents.TargetFrameSpellBar, ns.UnitFrames.frames.target)
    assert same(parents.FocusFrameSpellBar, ns.UnitFrames.frames.focus)


# 7. Hovering a unit frame shows its tooltip.
def test_unit_frames_have_tooltips(lua, ns):
    boot(lua, ns)
    for unit in ("target", "focus", "pet", "targettarget"):
        f = ns.UnitFrames.frames[unit]
        assert f.handlers.OnEnter is not None and f.handlers.OnLeave is not None


# 8. Health color: tapped grey, players by class, NPCs by reaction.
def test_health_color_rules():
    rt = new_runtime()
    ns = data_ns(rt)
    hc = ns.Data.HealthColor
    mage = rt.eval("{ r = 0.25, g = 0.78, b = 0.92 }")
    assert hc(True, mage, 2) == (0.5, 0.5, 0.5)
    assert hc(False, mage, 2) == (0.25, 0.78, 0.92)
    assert hc(False, None, 2) == (0.78, 0.16, 0.12)
    r, g, b = hc(False, None, 4)
    assert r > 0.7 and g > 0.6 and b < 0.3
    r, g, b = hc(False, None, 5)
    assert g > r and g > b
    assert hc(False, None, None) == (0.78, 0.16, 0.12)


# 9. Debuff border by dispel type.
def test_debuff_color_by_dispel_type():
    ns = data_ns()
    dc = ns.Data.DebuffColor
    assert dc("Magic") == (0.2, 0.6, 1.0)
    assert dc("Curse") == (0.6, 0.0, 1.0)
    assert dc("Disease") == (0.6, 0.4, 0.0)
    assert dc("Poison") == (0.0, 0.6, 0.0)
    assert dc(None) == (0.77, 0.15, 0.11)


# 10. Bag search and sort.
def test_search_matches_names_case_insensitive(pure):
    ns = load_pure(pure, "Inventory/Filters.lua")
    m = ns.Filters.MatchesSearch
    assert m("", "Pedra de Regresso") is True
    assert m("pedra", "Pedra de Regresso") is True
    assert m("PEDRA", "Pedra de Regresso") is True
    assert m("poção", "Pedra de Regresso") is False
    assert m("pedra", None) is False
    assert m("[", "Item [x]") is True  # plain find, no pattern errors


def test_sort_button_sorts_bags(lua, ns):
    boot(lua, ns, pre="SORTED = false")
    lua.execute("C_Container.SortBags = function() SORTED = true end")
    b = ns.Inventory.sortButton
    b.handlers.OnClick(b)
    assert lua.globals().SORTED is True


def test_search_box_pushes_text_to_game_search(lua, ns):
    boot(lua, ns, pre="SEARCH = nil")
    lua.execute("C_Container.SetItemSearch = function(t) SEARCH = t end")
    box = ns.Inventory.searchBox
    box.GetText = lua.eval('function() return "pedra" end')
    box.handlers.OnTextChanged(box)
    assert lua.globals().SEARCH == "pedra"


# 11. Bag item markers.
def test_item_markers(pure):
    ns = load_pure(pure, "Inventory/Filters.lua")
    mk = ns.Filters.Markers
    t = pure.eval
    junk = mk(t("{ quality = 0 }"), None, False)
    assert junk.junk is True and junk.quest is False and junk.new is False
    novalue = mk(t("{ quality = 0, hasNoValue = true }"), None, False)
    assert novalue.junk is False
    quest = mk(t("{ quality = 1 }"), t("{ isQuestItem = true, isActive = false }"), True)
    assert quest.quest is True and quest.questStarter is False and quest.new is True
    starter = mk(t("{ quality = 1 }"), t("{ questID = 42, isActive = false }"), False)
    assert starter.questStarter is True
    empty = mk(None, None, False)
    assert empty.junk is False and empty.quest is False
