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
      PRIORITY = {}
      function SetOverrideBindingClick(_, prio, key, button) OVERRIDES[key] = button; PRIORITY[key] = prio end
    """)
    o = lua.globals().OVERRIDES
    assert o["C"] == "ObsidianUIInventoryToggle"
    assert o["SHIFT-P"] == "ObsidianUIInventoryToggle"
    # priority override: wins over other overrides on the same key
    assert lua.globals().PRIORITY["C"] is True


# After login the addon checks the character key really clicks its button, and says in chat
# what holds the key when it doesn't (nothing for the player to type).
def test_character_key_check_reports_what_holds_the_key(lua, ns):
    boot(lua, ns, pre="""
      PRINTED = {}
      function print(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        PRINTED[#PRINTED + 1] = table.concat(parts, " ")
      end
      function GetBindingKey(b) if b == "TOGGLECHARACTER0" then return "C" end end
      function GetBindingAction(key, override) return "SOMETHING_ELSE" end
      C_Timer = { After = function(_, fn) fn() end }
    """)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    printed = " ".join(str(v) for v in lua.globals().PRINTED.values())
    assert "SOMETHING_ELSE" in printed and "C" in printed


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


# The ranged slot is a relic slot for some classes: same picture and name as the default sheet.
def test_relic_slot_uses_the_relic_picture(lua, ns):
    boot(lua, ns, pre="""
      C_PaperDollInfo = { GetInventorySlotInfo = function(name)
        return 18, "EMPTY:" .. name, name == "RangedSlot"
      end }
      function GetInventorySlotInfo(name) return 18, "EMPTY:" .. name end
      function UnitHasRelicSlot() return true end
      function GetInventoryItemTexture() return nil end
      RELICSLOT = "Relic"
      TIP = nil
      GameTooltip = setmetatable({}, { __index = function() return function() end end })
      GameTooltip.SetInventoryItem = function() return false end
      GameTooltip.SetText = function(_, t) TIP = t end
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        local ct = f.CreateTexture
        f.CreateTexture = function(self, ...)
          local t = ct(self, ...)
          t.SetTexture = function(tt, file) tt.file = file end
          return t
        end
        return f
      end
    """)
    ns.Inventory.Open()
    ranged = [b for b in ns.Inventory.slotButtons.values() if b.slotName == "RangedSlot"][0]
    assert "Relic" in str(ranged.icon.file)
    ranged.handlers.OnEnter(ranged)
    assert lua.globals().TIP == "Relic"


# In game SetInventoryItem hides the tooltip when the slot is empty, so the slot name was set
# on a hidden tooltip: the owner must be set again first (like ItemUtil.DisplayEquipSlotTooltip).
def test_empty_slot_tooltip_survives_set_inventory_item_hiding_it(lua, ns):
    boot(lua, ns, pre="""
      TIP, OWNED, SHOWN = nil, false, false
      GameTooltip = setmetatable({}, { __index = function() return function() end end })
      GameTooltip.SetOwner = function() OWNED = true end
      GameTooltip.SetInventoryItem = function() OWNED = false; SHOWN = false; return false end
      GameTooltip.SetText = function(_, t) if OWNED then TIP = t end end
      GameTooltip.Show = function() SHOWN = OWNED end
      function GetInventorySlotInfo() return 6, "EMPTY" end
      ItemUtil = { GetEmptyEquipSlotTooltip = function(slot) return "SLOT" .. slot end }
    """)
    b = [b for b in ns.Inventory.slotButtons.values() if b.slotName == "WaistSlot"][0]
    b.handlers.OnEnter(b)
    g = lua.globals()
    assert g.TIP == "SLOT6" and g.SHOWN


# WoW Forever binds the character key to ToggleWoWHackCharacterUI (its own character window).
# Whenever that window shows, it is hidden and the unified window toggles instead.
FOREVER_PRE = """
  FOREVER_WIN = CreateFrame()
  FOREVER_WIN.shown = false
  FOREVER_WIN.GetName = function() return "WoWHackCharacterUIFrame" end
  FOREVER_WIN.IsForbidden = function() return false end
  FOREVER_WIN.Hide = function(self) self.shown = false end
  FOREVER_WIN.IsShown = function(self) return self.shown end
  FOREVER_WIN.HookScript = function(self, name, fn) self.hooks[name] = fn end
  function EnumerateFrames(f) if f == nil then return FOREVER_WIN end return nil end
  function DEFINE_FOREVER_TOGGLE()
    function ToggleWoWHackCharacterUI()
      FOREVER_WIN.shown = not FOREVER_WIN.shown
      if FOREVER_WIN.shown and FOREVER_WIN.hooks.OnShow then FOREVER_WIN.hooks.OnShow(FOREVER_WIN) end
    end
  end
"""


def _forever_presses(lua, ns):
    toggles = {"n": 0}
    ns.Inventory.Toggle = lambda: toggles.__setitem__("n", toggles["n"] + 1)
    g = lua.globals()
    g.ToggleWoWHackCharacterUI()
    assert toggles["n"] == 1 and not g.FOREVER_WIN.shown
    g.STUB_TIME = 200
    g.ToggleWoWHackCharacterUI()
    assert toggles["n"] == 2 and not g.FOREVER_WIN.shown
    # Same press also clicking our key button toggles only once.
    g.STUB_TIME = 300
    b = ns.Inventory.toggleButton
    b.handlers.OnClick(b, "LeftButton", True)
    g.ToggleWoWHackCharacterUI()
    assert toggles["n"] == 3 and not g.FOREVER_WIN.shown


def test_forever_character_window_is_replaced_by_the_unified_window(lua, ns):
    boot(lua, ns, pre=FOREVER_PRE + "DEFINE_FOREVER_TOGGLE()")
    _forever_presses(lua, ns)


# The game's toggle function may only exist after the addon loads.
def test_forever_toggle_defined_late_is_still_replaced(lua, ns):
    boot(lua, ns, pre=FOREVER_PRE)
    lua.execute("DEFINE_FOREVER_TOGGLE()")
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    _forever_presses(lua, ns)


# Equipment slots glow blue on hover, like the default character sheet.
def test_equipment_slots_glow_on_hover(lua, ns):
    boot(lua, ns, pre="""
      HIGHLIGHTS = {}
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        f.SetHighlightTexture = function(self, tex, mode) HIGHLIGHTS[#HIGHLIGHTS + 1] = tex .. "|" .. mode end
        return f
      end
    """)
    hl = lua.globals().HIGHLIGHTS
    assert len(hl) >= len(list(ns.Inventory.slotButtons.values()))
    assert hl[1] == "Interface\\Buttons\\ButtonHilight-Square|ADD"


# The bag scroll bar sits on the rail painted in the window art; its own art is hidden.
def test_bag_scroll_bar_sits_on_the_painted_rail(lua, ns):
    boot(lua, ns, pre="""
      local cf = CreateFrame
      function CreateFrame(kind, name, parent, template)
        local f = cf(kind, name, parent, template)
        if template == "UIPanelScrollFrameTemplate" then
          local function part()
            local p = cf()
            p.points = {}
            p.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
            p.ClearAllPoints = function(self) self.points = {} end
            p.SetSize = function(self, w, h) self.w, self.h = w, h end
            p.tex = { SetAlpha = function(t, a) t.alpha = a end }
            p.GetNormalTexture = function(self) return self.tex end
            p.GetPushedTexture = function(self) return self.tex end
            p.GetDisabledTexture = function(self) return self.tex end
            p.SetHighlightTexture = function(self, t) self.hl = t end
            return p
          end
          f.ScrollBar = part()
          f.ScrollBar.ScrollUpButton = part()
          f.ScrollBar.ScrollDownButton = part()
          local thumb = { SetTexture = function(t, file) t.file = file end, SetTexCoord = function() end,
            SetSize = function(t, w, h) t.w, t.h = w, h end }
          f.ScrollBar.GetThumbTexture = function() return thumb end
          BAG_SCROLL = f
        end
        return f
      end
    """)
    ns.Inventory.Layout()
    g = lua.globals()
    bar = g.BAG_SCROLL.ScrollBar
    S = ns.Data.INV.scroll
    ux, uy = 1920 / ns.Data.INV.w, 1080 / ns.Data.INV.h
    assert bar.points[1][4] == S.track.x * ux and bar.points[1][5] == -S.track.y * uy
    assert abs(bar.w - S.track.w * ux) < 1e-6
    up = bar.ScrollUpButton
    assert up.points[1][4] == S.up.x * ux and up.tex.alpha == 0
    assert bar.ScrollDownButton.points[1][5] == -S.down.y * uy
    assert "scroll_thumb" in bar.GetThumbTexture().file


# The character key runs ToggleCharacter("PaperDollFrame"). The page is flagged hidden (only
# ToggleCharacter reads the flag, and then does nothing) and a post-hook opens the unified
# window instead. Nothing hides Blizzard's sheet from addon code (that tainted the menus);
# the secure wrap tried before does not act on unprotected frames.
def test_character_key_opens_the_unified_window_instead_of_the_sheet(lua, ns):
    boot(lua, ns, pre="""
      SHEET = 0
      PaperDollFrame = CreateFrame()
      ReputationFrame = CreateFrame()
      ReputationFrame.hidden = false
      function ToggleCharacter(tab)
        local sub = _G[tab]
        if sub and not sub.hidden then SHEET = SHEET + 1 end
      end
    """)
    toggles = {"n": 0}
    ns.Inventory.Toggle = lambda: toggles.__setitem__("n", toggles["n"] + 1)
    g = lua.globals()
    g.ToggleCharacter("PaperDollFrame")
    assert toggles["n"] == 1 and g.SHEET == 0
    g.STUB_TIME = 200
    g.ToggleCharacter("ReputationFrame")
    assert toggles["n"] == 1 and g.SHEET == 1


# In game PLAYER_TITLE_CHANGED does not exist: registering it raised an error and the rest of
# Window.lua (character key, login check) never loaded. Unknown events are skipped.
def test_unknown_event_does_not_stop_loading(lua, ns):
    lua.execute("""
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        f.RegisterEvent = function(self, ev)
          if ev == "PLAYER_TITLE_CHANGED" or ev == "NO_SUCH_EVENT" then error("unknown event " .. ev) end
          STUB_EVENTS[#STUB_EVENTS + 1] = { frame = self, event = ev }
        end
        return f
      end
    """)
    boot(lua, ns)
    ns.On("NO_SUCH_EVENT", lambda *a: None)
    assert ns.Inventory.toggleButton is not None


def test_addon_registers_no_title_changed_event():
    import re
    from conftest import ROOT
    for f in (ROOT / "ObsidianUI").rglob("*.lua"):
        assert "PLAYER_TITLE_CHANGED" not in f.read_text(encoding="utf-8"), f


# In game the user found the unit frames and the cast bar too big: about 20% smaller.
def test_unit_frames_and_castbar_about_20_percent_smaller(lua, ns):
    boot(lua, ns)
    K = ns.UnitFrames.KINDS
    assert K.large.width <= 0.29 and K.small.width <= 0.16 and K.tiny.width <= 0.14
    H = lua.eval("select(2, UIParent:GetSize())")
    assert ns.CastBar.HalfWidth() <= 0.38 * H / 2


# In game the Reputation and Currency buttons did nothing: in this client (camelot) the
# character frame's pages are side tabs, plain Frames named CharacterFrameModeTab2/5 that open
# their page on mouse up, which a secure click cannot press. While the character frame is
# closed, the real tab lies invisible over our button (the user clicks Blizzard's own tab, no
# taint); it goes back home when the frame opens.
MODE_TABS_PRE = """
  local function fake()
    local f = CreateFrame()
    f.shown, f.alpha, f.points = false, 1, {}
    f.IsShown = function(self) return self.shown end
    f.SetParent = function(self, p) self.parent = p end
    f.GetParent = function(self) return self.parent end
    f.SetAlpha = function(self, a) self.alpha = a end
    f.ClearAllPoints = function(self) self.points = {} end
    f.SetPoint = function(self, ...) table.insert(self.points, { ... }) end
    f.SetAllPoints = function(self, r) self.points = { { "ALL", r } } end
    f.GetNumPoints = function(self) return #self.points end
    f.GetPoint = function(self, i) return unpack(self.points[i]) end
    return f
  end
  CharacterFrame = fake()
  CharacterFrameModeTabs = fake()
  for i = 1, 6 do
    local t = fake()
    t.parent = CharacterFrameModeTabs
    t:SetPoint("TOPLEFT", CharacterFrameModeTabs, "TOPLEFT", 0, -i)
    _G["CharacterFrameModeTab" .. i] = t
  end
"""


def test_reputation_and_currency_lend_the_real_character_tabs(lua, ns):
    boot(lua, ns, pre=MODE_TABS_PRE)
    same = lua.eval("rawequal")
    g = lua.globals()
    pairs_ = (("repButton", g.CharacterFrameModeTab2, -2), ("tokenButton", g.CharacterFrameModeTab5, -5))
    for key, tab, _ in pairs_:
        b = ns.Inventory[key]
        assert same(tab.parent, b) and tab.alpha == 0
        assert tab.points[1][1] == "ALL" and same(tab.points[1][2], b)
    # The character frame opens: the tabs go home, and Blizzard lays them out as usual.
    g.CharacterFrame.shown = True
    g.CharacterFrame.hooks.OnShow(g.CharacterFrame)
    for key, tab, y in pairs_:
        assert same(tab.parent, g.CharacterFrameModeTabs) and tab.alpha == 1
        assert tab.points[1][1] == "TOPLEFT" and tab.points[1][5] == y
        tab.SetPoint(tab, "TOPLEFT", g.CharacterFrameModeTabs, "TOPLEFT", 0, -9)
        assert tab.points[2][5] == -9  # not pulled back onto our button
    # It closes: lent again.
    g.CharacterFrame.shown = False
    g.CharacterFrame.hooks.OnHide(g.CharacterFrame)
    for key, tab, _ in pairs_:
        assert same(tab.parent, ns.Inventory[key]) and tab.alpha == 0


# With the new unit frame art, the target's debuffs sit under the frame (not on its bottom
# edge) and the target's cast bar under the debuffs.
def test_target_debuffs_and_castbar_sit_under_the_frame(lua, ns):
    boot(lua, ns, pre="""
      local cf = CreateFrame
      function CreateFrame(...)
        local f = cf(...)
        f.SetPoint = function(self, p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
        return f
      end
      TargetFrameSpellBar = CreateFrame()
    """)
    t = ns.UnitFrames.frames.target
    D = ns.Data.UNIT
    below = t.GetHeight(t) * (D.h - D.health.y - D.health.h) / D.h  # health bottom to frame bottom
    b = ns.UnitFrames.debuffs[1]
    assert b.point[1] == "TOPLEFT" and -b.point[5] >= below
    bar = lua.globals().TargetFrameSpellBar
    assert -bar.point[5] >= below + t.GetHeight(t) * 0.22  # the debuff row


POINTS_PRE = """
  local cf = CreateFrame
  function CreateFrame(...)
    local f = cf(...)
    f.SetPoint = function(self, p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
    return f
  end
"""


# In the preview the user found the unit frames off-center and the purple glow around an
# elite's portrait ugly: no glow, the frames lined up with each other.
def test_elite_target_has_no_glow_ring(lua, ns):
    boot(lua, ns, pre='function UnitClassification() return "elite" end function UnitExists() return true end')
    lua.execute('STUB_FIRE("PLAYER_TARGET_CHANGED")')
    assert lua.eval("rawget")(ns.UnitFrames.frames.target, "ring") is None  # stubs invent missing fields


def test_unit_frames_line_up(lua, ns):
    boot(lua, ns, pre=POINTS_PRE)
    same = lua.eval("rawequal")
    F = ns.UnitFrames.frames
    focus, tot, pet = F.focus.point, F.targettarget.point, F.pet.point
    assert (focus[1], focus[3], focus[4]) == ("TOPLEFT", "BOTTOMLEFT", 0) and same(focus[2], F.target)
    assert (tot[1], tot[3], tot[5]) == ("LEFT", "RIGHT", 0) and same(tot[2], F.target)
    s = 1080 / 900
    assert pet[1] == "BOTTOMLEFT" and pet[5] >= ns.HUD.h + 20 * s  # clear of the orb cap's crest


# In the preview the target's name, level and classification ran out of the name plate: the
# texts follow the frame size, the level sits at the plate's right end, and a long name is cut
# instead of wrapping.
FONTS_PRE = """
  local cf = CreateFrame
  local function text()
    local t = cf()
    t.size = 14
    t.SetFont = function(self, path, size, flags) self.size = size end
    t.GetFont = function(self) return "FRIZQT__.TTF", self.size, "" end
    t.SetWordWrap = function(self, v) self.wrap = v end
    t.SetJustifyH = function(self, j) self.justify = j end
    t.SetText = function(self, s) self.text = s end
    t.SetHeight = function(self, h) self.h = h end
    t.SetSize = function(self, w, h) self.w, self.h = w, h end
    return t
  end
  function CreateFrame(...)
    local f = cf(...)
    f.CreateFontString = function() return text() end
    return f
  end
  function UnitClassification() return "elite" end
  function UnitLevel() return 62 end
  function UnitName() return "Ravenfang Alpha" end
  function UnitExists() return true end
"""


def test_target_name_and_level_fit_the_name_plate(lua, ns):
    boot(lua, ns, pre=FONTS_PRE)
    lua.execute('STUB_FIRE("PLAYER_TARGET_CHANGED")')
    t = ns.UnitFrames.frames.target
    assert t.name.text == "Ravenfang Alpha"
    assert "62" in t.levelText.text and "Elite" in t.levelText.text and t.levelText.justify == "RIGHT"
    assert t.name.wrap is False
    plate = t.name.h
    assert 0.45 * plate <= t.name.size <= 0.7 * plate
    assert t.levelText.size <= t.name.size
