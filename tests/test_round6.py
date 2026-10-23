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
