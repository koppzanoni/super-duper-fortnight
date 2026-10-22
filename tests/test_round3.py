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
