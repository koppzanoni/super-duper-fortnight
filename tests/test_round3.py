"""Round 3: overlaps around the HUD center, Blizzard frames left behind, player status, reset."""
from conftest import load_addon_file, new_runtime, toc_files

# Fake Blizzard frames that record every SetPoint as { point, x, y }.
RECORDING = """
  POINTS = {}
  function RecordingFrame(name)
    local f = CreateFrame()
    POINTS[name] = {}
    f.SetPoint = function(_, p, _, _, x, y) table.insert(POINTS[name], { p, x, y }) end
    f.ClearAllPoints = function() end
    _G[name] = f
    return f
  end
"""


def boot(lua, ns, pre=""):
    lua.execute(RECORDING)
    if pre:
        lua.execute(pre)
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


def last_point(lua, name):
    calls = lua.globals().POINTS[name]
    assert calls is not None and len(calls) > 0, name + " never placed"
    c = calls[len(calls)]
    return c[1], c[2], c[3]


# 1. Vehicle exit button sits beside the cast bar, not on it.
def test_vehicle_leave_clears_castbar(lua, ns):
    boot(lua, ns, pre='RecordingFrame("MainMenuBarVehicleLeaveButton")')
    _, x, _ = last_point(lua, "MainMenuBarVehicleLeaveButton")
    assert x >= 0.47 * 1080 / 2


# 4. Stance (left) and pet (right) bars start outside the widest gem row.
def test_stance_and_pet_bars_clear_gems(lua, ns):
    boot(lua, ns, pre='RecordingFrame("StanceBar"); RecordingFrame("PetActionBar")')
    half = ns.ClassResource.HalfWidth(6)
    _, xs, _ = last_point(lua, "StanceBar")
    _, xp, _ = last_point(lua, "PetActionBar")
    assert xs <= -half
    assert xp >= half


# Pin keeps a frame where we put it when Blizzard re-anchors it.
def test_pin_reapplies_after_blizzard_moves_frame(lua, ns):
    boot(lua, ns, pre='RecordingFrame("SomeBlizzardFrame")')
    g = lua.globals()
    f = g.SomeBlizzardFrame
    ns.Pin(f, lua.eval('function(self) self:SetPoint("TOP", nil, nil, 5, 6) end'))
    f.SetPoint(f, "CENTER", None, None, 0, 0)
    assert last_point(lua, "SomeBlizzardFrame") == ("TOP", 5, 6)


def test_pin_waits_for_combat_end_on_protected_frames(lua, ns):
    boot(lua, ns, pre='RecordingFrame("ProtectedFrame")')
    g = lua.globals()
    f = g.ProtectedFrame
    f.IsProtected = lua.eval("function() return true end")
    g.STUB_COMBAT = True
    ns.Pin(f, lua.eval('function(self) self:SetPoint("TOP", nil, nil, 1, 2) end'))
    f.SetPoint(f, "CENTER", None, None, 0, 0)
    f.SetPoint(f, "CENTER", None, None, 0, 0)
    assert last_point(lua, "ProtectedFrame") == ("CENTER", 0, 0)
    g.STUB_COMBAT = False
    lua.execute('STUB_FIRE("PLAYER_REGEN_ENABLED")')
    assert last_point(lua, "ProtectedFrame") == ("TOP", 1, 2)
    assert len(g.POINTS.ProtectedFrame) == 3  # applied once, not once per queued move


# 3. Blizzard frames that lost their home (hidden parents) or land on the HUD get a spot.
def test_left_behind_blizzard_frames_are_placed(lua, ns):
    names = ["DurabilityFrame", "GroupLootContainer", "MirrorTimerContainer", "QueueStatusButton",
             "MiniMapInstanceDifficulty"]
    boot(lua, ns, pre="".join('RecordingFrame("%s");' % n for n in names))
    for n in names:
        last_point(lua, n)


# 2. The grid is laid out while the window is closed, so opening it in combat shows items.
def test_bag_grid_laid_out_while_closed(lua, ns):
    boot(lua, ns)
    ns.Inventory.frame.IsShown = lua.eval("function() return false end")
    calls = {"n": 0}
    orig = ns.GridModel.Build

    def counting(slots, tab):
        calls["n"] += 1
        return orig(slots, tab)
    ns.GridModel.Build = counting
    lua.execute('STUB_FIRE("BAG_UPDATE_DELAYED")')
    assert calls["n"] == 1


# 5. Player status inside the health orb.
def test_player_status_icons():
    rt = new_runtime()
    ns = load_addon_file(rt, "Core/Data.lua", rt.table())
    icons = lambda *a: list(ns.Data.PlayerStatusIcons(*a).values())
    assert icons(True, True, False) == ["combat"]
    assert icons(False, True, True) == ["rest", "leader"]
    assert icons(False, False, True) == ["leader"]
    assert icons(False, False, False) == []


def test_player_status_follows_game_state(lua, ns):
    boot(lua, ns, pre="""
      COMBAT = false
      function UnitAffectingCombat() return COMBAT end
      function IsResting() return true end
      function UnitIsGroupLeader() return false end
    """)
    assert list(ns.PlayerStatus.Current().values()) == ["rest"]
    lua.globals().COMBAT = True
    assert list(ns.PlayerStatus.Current().values()) == ["combat"]


# /obui reset puts the movable things back where they start.
def test_reset_command_forgets_positions(lua, ns):
    boot(lua, ns)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    ns.db.invPos = lua.eval('{ point = "CENTER", relPoint = "CENTER", x = 1, y = 2 }')
    lua.globals().SlashCmdList.OBSIDIANUI("reset")
    assert ns.db.invPos is None
    assert ns.db.positioned is True


# In-game: the HUD art has transparent rows at the bottom; it must sit flush with the screen.
def test_hud_sinks_transparent_bottom_rows_below_screen(lua, ns):
    boot(lua, ns)
    lua.execute("ROOT_Y = nil")
    ns.HUD.frame.SetPoint = lua.eval("function(_, _, _, _, x, y) ROOT_Y = y end")
    ns.HUD.Layout()
    full, u, _ = ns.Layout.HudSize(1920, 1080, 1)
    pad = ns.HUD.BOTTOM_PAD * u
    assert ns.HUD.BOTTOM_PAD == 19
    assert abs(lua.globals().ROOT_Y + pad) < 1e-6
    assert abs(ns.HUD.h - (full - pad)) < 1e-6
    assert abs(ns.Stack.BarTop() - (ns.HUD.h - 87 * u)) < 1e-6


# In-game: action bars 6-8 of the modern client showed up over the HUD.
def test_extra_action_bars_are_hidden(lua, ns):
    boot(lua, ns, pre="""
      HIDDEN = {}
      for _, n in ipairs({ "MultiBar5", "MultiBar6", "MultiBar7" }) do
        local f = CreateFrame()
        f.SetParent = function() HIDDEN[n] = true end
        _G[n] = f
      end
    """)
    for n in ("MultiBar5", "MultiBar6", "MultiBar7"):
        assert lua.globals().HIDDEN[n], n


# In-game: the target frame art was cut at the bottom; its spec must match the exported art.
def test_target_frame_spec_matches_exported_art(lua, ns):
    boot(lua, ns)
    m = ns.MediaManifest.target_frame
    assert (ns.Data.TARGET.w, ns.Data.TARGET.h) == (m.w, m.h)


# In-game: the menu panel buttons did nothing.
def test_menu_secure_buttons_fire_on_key_down_too(lua, ns):
    boot(lua, ns, pre="""
      CLICK_REGS = {}
      CharacterMicroButton = CreateFrame()
      SpellbookMicroButton = CreateFrame()
      local cf = CreateFrame
      function CreateFrame(kind, name, parent, template)
        local f = cf(kind, name, parent, template)
        if template == "SecureActionButtonTemplate" then
          f.RegisterForClicks = function(_, ...) CLICK_REGS[#CLICK_REGS + 1] = table.concat({ ... }, ",") end
        end
        return f
      end
    """)
    regs = list(lua.globals().CLICK_REGS.values())
    assert regs, "no secure menu buttons created"
    for r in regs:
        assert "AnyDown" in r and "AnyUp" in r


def test_chat_pushed_off_hud_when_edit_mode_moves_it_back(lua, ns):
    boot(lua, ns, pre="""
      CHAT_BOTTOM = 20
      CHAT_MOVES = 0
      ChatFrame1 = CreateFrame()
      ChatFrame1.GetBottom = function() return CHAT_BOTTOM end
      ChatFrame1.ClearAllPoints = function() end
      -- Blizzard's own anchor (x = 32) puts it over the HUD; ours lifts it.
      ChatFrame1.SetPoint = function(_, _, _, _, x)
        CHAT_MOVES = CHAT_MOVES + 1
        CHAT_BOTTOM = (x == 32) and 20 or 400
      end
    """)
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    g = lua.globals()
    moves = g.CHAT_MOVES
    g.ChatFrame1.SetPoint(g.ChatFrame1, "BOTTOMLEFT", None, "BOTTOMLEFT", 32, 40)  # Edit Mode
    assert g.CHAT_MOVES == moves + 2  # Blizzard's move, then ours


# In-game: after cancelling and recasting, the cast bar lost its icon and showed Blizzard's
# interrupt sparkles over our fill.
CASTBAR_PRE = """
  ALPHAS = {}
  local function region(name)
    local r = { shown = true }
    r.SetAlpha = function(_, a) ALPHAS[name] = a end
    r.Show = function(self) self.shown = true end
    r.Hide = function(self) self.shown = false end
    r.SetShown = function(self, v) self.shown = v and true or false end
    return setmetatable(r, { __index = function() return function() end end })
  end
  PlayerCastingBarFrame = CreateFrame()
  PlayerCastingBarFrame.Icon = region("Icon")
  for _, k in ipairs({ "Flakes01", "Flakes02", "Flakes03", "Sparkles01", "InterruptGlow", "Shine" }) do
    PlayerCastingBarFrame[k] = region(k)
  end
"""


def test_castbar_icon_stays_after_blizzard_hides_it(lua, ns):
    boot(lua, ns, pre=CASTBAR_PRE)
    icon = lua.globals().PlayerCastingBarFrame.Icon
    icon.Hide(icon)
    assert icon.shown is True
    icon.SetShown(icon, False)
    assert icon.shown is True


def test_castbar_hides_blizzard_cast_effects(lua, ns):
    boot(lua, ns, pre=CASTBAR_PRE)
    alphas = lua.globals().ALPHAS
    for k in ("Flakes01", "Flakes02", "Flakes03", "Sparkles01", "InterruptGlow", "Shine"):
        assert alphas[k] == 0, k


# In-game: recasting in combat, Blizzard re-anchored the cast bar down onto the action bar.
def test_castbar_stays_put_when_blizzard_moves_it_in_combat(lua, ns):
    boot(lua, ns, pre='RecordingFrame("PlayerCastingBarFrame")')
    ours = last_point(lua, "PlayerCastingBarFrame")
    g = lua.globals()
    g.STUB_COMBAT = True
    f = g.PlayerCastingBarFrame
    f.SetPoint(f, "BOTTOM", None, "BOTTOM", 0, 120)
    assert last_point(lua, "PlayerCastingBarFrame") == ours
