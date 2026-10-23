"""Round 6 (in-game feedback): auras without the classic-only secure header, game menu button,
menu icons and press feedback, inventory title, equal equipment/weapon frames, model tuning."""
import sys

from conftest import ROOT, load_addon_file, new_runtime, toc_files

sys.path.insert(0, str(ROOT / "tools"))
import inventory_art as ia  # noqa: E402


def boot(lua, ns, pre=""):
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


AURAS_PRE = """
  BUFFS = 3
  C_UnitAuras = {
    GetUnitAuras = function(unit, filter)
      local list = {}
      local n = filter == "HELPFUL" and BUFFS or 1
      for i = 1, n do list[i] = { icon = i, applications = 0, duration = 0, expirationTime = 0, auraInstanceID = i } end
      return list
    end,
  }
"""


# WoW Forever loads as game type "camelot": SecureAuraHeaderTemplate (classic only) is missing.
def test_auras_do_not_need_the_secure_aura_header():
    for path in ("HUD/Auras.lua",):
        assert "SecureAuraHeaderTemplate" not in (ROOT / "ObsidianUI" / path).read_text(encoding="utf-8")
    toc = (ROOT / "ObsidianUI" / "ObsidianUI.toc").read_text(encoding="utf-8")
    assert "Auras.xml" not in toc


def test_buff_row_shows_one_button_per_aura(lua, ns):
    boot(lua, ns, pre=AURAS_PRE)
    lua.execute('STUB_FIRE("UNIT_AURA", "player")')
    assert ns.Auras.count.HELPFUL == 3
    assert ns.Auras.count.HARMFUL == 1
    lua.globals().BUFFS = 1
    lua.execute('STUB_FIRE("UNIT_AURA", "player")')
    assert ns.Auras.count.HELPFUL == 1


def test_buff_row_is_centered(lua, ns):
    boot(lua, ns, pre=AURAS_PRE)
    lua.execute('STUB_FIRE("UNIT_AURA", "player")')
    xs = [ns.Auras.OffsetX(i, 3) for i in (1, 2, 3)]
    assert xs[0] == -xs[2] and xs[1] == 0


# The game menu micro button only reacts when the mouse is over it: we use the real button.
def test_game_menu_uses_the_real_micro_button(lua, ns):
    boot(lua, ns, pre="""
      PARENT = nil
      MainMenuMicroButton = CreateFrame()
      MainMenuMicroButton.SetParent = function(_, p) PARENT = p end
    """)
    same = lua.eval("function(a, b) return rawequal(a, b) end")
    assert same(lua.globals().PARENT, ns.HUD.over)


def test_character_button_shows_the_player_portrait(lua, ns):
    boot(lua, ns, pre="""
      PORTRAITS = {}
      function SetPortraitTexture(_, unit) PORTRAITS[#PORTRAITS + 1] = unit end
    """)
    assert "player" in list(lua.globals().PORTRAITS.values())


def test_menu_buttons_have_press_feedback(lua, ns):
    boot(lua, ns)
    assert len(ns.MenuPanels.buttons) >= 1
    for i in range(1, len(ns.MenuPanels.buttons) + 1):
        b = ns.MenuPanels.buttons[i]
        assert b.obPress is True


def test_inventory_title_is_the_character_name(lua, ns):
    boot(lua, ns, pre='function UnitName() return "Arthurzinha" end')
    assert ns.Inventory.TitleText() == "Arthurzinha"


# Equipment and weapon frames all the same size; the model uses the space above the weapons.
def test_equipment_and_weapon_frames_match():
    rt = new_runtime()
    S = load_addon_file(rt, "Core/Data.lua", rt.table()).Data.INV
    assert S.weaponSize == ia.FRAME_SIZE
    assert S.weaponSize - 2 * S.weaponInset == S.equipSize
    assert S.weaponY == ia.WEAPON_BOTTOM - ia.FRAME_SIZE
    assert [S.weapons[i] for i in (1, 2, 3)] == [cx - ia.FRAME_SIZE / 2 for cx in ia.WEAPON_CX]
    assert S.model.y + S.model.h <= S.weaponY - 4
    assert S.model.y + S.model.h >= S.weaponY - 12


def test_model_command_saves_camera(lua, ns):
    boot(lua, ns)
    lua.globals().SlashCmdList.OBSIDIANUI("modelo 0.9 -0.2")
    assert ns.db.modelDistance == 0.9
    assert ns.db.modelHeight == -0.2


# The window title shows the name the way the default character sheet does (with title).
def test_inventory_title_uses_the_pvp_name(lua, ns):
    boot(lua, ns, pre='function UnitPVPName() return "Agni, a Exploradora" end')
    assert ns.Inventory.TitleText() == "Agni, a Exploradora"


# Menu buttons stay lit and sunk while their window is open (Blizzard pushes the micro button).
MICRO_PRE = """
  SpellbookMicroButton = CreateFrame()
  SpellbookMicroButton.SetPushed = function() end
  SpellbookMicroButton.SetNormal = function() end
  SpellbookMicroButton.GetButtonState = function() return "NORMAL" end
"""


def test_menu_button_active_while_its_window_is_open(lua, ns):
    boot(lua, ns, pre=MICRO_PRE)
    micro = lua.globals().SpellbookMicroButton
    proxy = [b for b in ns.MenuPanels.buttons.values() if b.obMicro and lua.eval("rawequal")(b.obMicro, micro)][0]
    assert proxy.obActive is False
    micro.SetPushed(micro)
    assert proxy.obActive is True
    micro.SetNormal(micro)
    assert proxy.obActive is False


def test_character_and_bag_buttons_active_while_inventory_open(lua, ns):
    boot(lua, ns)
    inv = ns.Inventory.frame
    inv.hooks.OnShow(inv)
    actives = [b.obActive for b in ns.MenuPanels.buttons.values() if b.obInventory]
    assert actives and all(a is True for a in actives)
    inv.hooks.OnHide(inv)
    assert all(b.obActive is False for b in ns.MenuPanels.buttons.values() if b.obInventory)


# Minimap terrain only re-renders at its new size/place after a zoom change.
def test_minimap_refreshes_zoom_after_layout(lua, ns):
    boot(lua, ns, pre="""
      ZOOMS = {}
      Minimap = CreateFrame()
      Minimap.GetZoom = function() return 2 end
      Minimap.GetZoomLevels = function() return 6 end
      Minimap.SetZoom = function(_, z) ZOOMS[#ZOOMS + 1] = z end
    """)
    zooms = list(lua.globals().ZOOMS.values())
    assert len(zooms) >= 2 and zooms[-1] == 2 and zooms[-2] != 2


# In-game: calling Blizzard's panel functions from addon code tainted the panel manager, and
# afterwards every menu button failed to open its window. The addon never calls them.
def test_addon_never_calls_blizzard_panel_functions():
    import re
    pattern = re.compile(r"\b(HideUIPanel|ShowUIPanel|ToggleCharacter|ToggleGameMenu|CloseAllWindows)\s*\(")
    for path in (ROOT / "ObsidianUI").rglob("*.lua"):
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("--")[0]
            assert not pattern.search(code), f"{path.name}:{n}: {line.strip()}"


# C (and any key bound to the character sheet) opens the unified window through our own binding.
def test_character_key_opens_the_unified_window(lua, ns):
    boot(lua, ns, pre="""
      OVERRIDES = {}
      function GetBindingKey(b) if b == "TOGGLECHARACTER0" then return "C", "SHIFT-P" end end
      function SetOverrideBindingClick(_, _, key, button) OVERRIDES[key] = button end
    """)
    o = lua.globals().OVERRIDES
    assert o["C"] == "ObsidianUIInventoryToggle"
    assert o["SHIFT-P"] == "ObsidianUIInventoryToggle"


# Reputation and Currency click Blizzard's own tabs through secure buttons (no taint).
def test_reputation_and_currency_click_the_blizzard_tabs(lua, ns):
    boot(lua, ns, pre="""
      CharacterFrameTab2 = CreateFrame()
      CharacterFrameTab3 = CreateFrame()
      local cf = CreateFrame
      function CreateFrame(kind, name, parent, template)
        local f = cf(kind, name, parent, template)
        f.attrs = {}
        f.SetAttribute = function(self, k, v) self.attrs[k] = v end
        f.template = template
        return f
      end
    """)
    same = lua.eval("rawequal")
    g = lua.globals()
    for key, tab in (("repButton", g.CharacterFrameTab2), ("tokenButton", g.CharacterFrameTab3)):
        b = ns.Inventory[key]
        assert b.template == "SecureActionButtonTemplate"
        assert b.attrs.type == "click"
        assert same(b.attrs.clickbutton, tab)


# In-game: the target frame was too big and its portrait smaller than the ring opening.
def test_target_frame_smaller_and_portrait_fills_the_ring():
    rt = new_runtime()
    D = load_addon_file(rt, "Core/Data.lua", rt.table()).Data
    p = D.TARGET.portrait
    hole = (104, 407, 68, 377)  # opening of the portrait ring in target_frame art
    assert p.x <= hole[0] - 3 and p.x + p.w >= hole[1] + 4
    assert p.y <= hole[2] - 3 and p.y + p.h >= hole[3] + 4


def test_target_frame_width_reduced(lua, ns):
    boot(lua, ns)
    assert ns.UnitFrames.KINDS.large.width <= 0.37


# In-game: the map stayed offset inside the ring. Anchored with zero offsets to a frame placed
# on the ring opening, so the Minimap's own scale cannot shift or shrink it.
def test_minimap_anchored_without_offsets(lua, ns):
    boot(lua, ns, pre="""
      MAP_POINTS = {}
      Minimap = CreateFrame()
      Minimap.SetPoint = function(_, p, rel, rp, x, y) MAP_POINTS[#MAP_POINTS + 1] = { p, x or 0, y or 0 } end
      Minimap.ClearAllPoints = function() end
    """)
    pts = lua.globals().MAP_POINTS
    last = [pts[len(pts) - 1], pts[len(pts)]]
    assert [(q[1], q[2], q[3]) for q in last] == [("TOPLEFT", 0, 0), ("BOTTOMRIGHT", 0, 0)]


# The C key's click button toggles once even when the key sends both a down and an up click.
def test_character_key_toggles_once_per_press(lua, ns):
    boot(lua, ns)
    toggles = {"n": 0}
    ns.Inventory.Toggle = lambda: toggles.__setitem__("n", toggles["n"] + 1)
    b = ns.Inventory.toggleButton
    b.handlers.OnClick(b, "LeftButton", True)
    b.handlers.OnClick(b, "LeftButton", False)
    assert toggles["n"] == 1
    lua.globals().STUB_TIME = 200
    b.handlers.OnClick(b, "LeftButton", True)
    assert toggles["n"] == 2


# In-game: the small frames' portraits left a dark band in their ring too.
def test_small_and_focus_portraits_fill_their_rings():
    rt = new_runtime()
    D = load_addon_file(rt, "Core/Data.lua", rt.table()).Data
    for spec, hole in ((D.UNIT_SMALL, (66, 417, 66, 425)), (D.FOCUS, (60, 419, 58, 425))):
        p = spec.portrait
        assert p.x <= hole[0] - 3 and p.x + p.w >= hole[1] + 4
        assert p.y <= hole[2] - 3 and p.y + p.h >= hole[3] + 4


# The HUD bag panel shows the same bags as the inventory footer (no reagent bag slot).
def test_hud_bag_slots_match_the_inventory_footer():
    rt = new_runtime()
    D = load_addon_file(rt, "Core/Data.lua", rt.table()).Data
    bags = [D.MENU_RIGHT[i].bag for i in range(1, len(D.MENU_RIGHT) + 1) if D.MENU_RIGHT[i].bag is not None]
    assert bags == [0, 1, 2, 3, 4]
    assert len(D.INV.bags) == 5


# Empty equipment slots show the game's empty-slot picture (like the default character sheet).
def test_empty_equipment_slots_show_their_placeholder(lua, ns):
    boot(lua, ns, pre="""
      TEXTURES = {}
      function GetInventorySlotInfo(name) return 1, "EMPTY:" .. name end
      function GetInventoryItemTexture() return nil end
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        local cfTex = f.CreateTexture
        f.CreateTexture = function(self, ...)
          local t = cfTex(self, ...)
          t.SetTexture = function(tt, file) tt.file = file end
          t.SetShown = function(tt, v) tt.shown = v end
          t.Show = function(tt) tt.shown = true end
          t.Hide = function(tt) tt.shown = false end
          return t
        end
        return f
      end
    """)
    ns.Inventory.Open()
    icons = [b.icon for b in ns.Inventory.slotButtons.values()]
    assert icons and all(str(i.file).startswith("EMPTY:") and i.shown for i in icons)


def test_hovering_an_empty_equipment_slot_names_it(lua, ns):
    boot(lua, ns, pre="""
      TIP = nil
      RANGEDSLOT = "Relic"
      GameTooltip = setmetatable({}, { __index = function() return function() end end })
      GameTooltip.SetInventoryItem = function() return false end
      GameTooltip.SetText = function(_, t) TIP = t end
    """)
    ranged = [b for b in ns.Inventory.slotButtons.values() if b.slotName == "RangedSlot"][0]
    ranged.handlers.OnEnter(ranged)
    assert lua.globals().TIP == "Relic"
