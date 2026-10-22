from conftest import load_addon_file, toc_files


def test_every_toc_file_loads(lua, ns):
    files = toc_files()
    assert files, "the .toc lists no Lua files"
    for f in files:
        load_addon_file(lua, f, ns)


def test_login_and_resize_run_without_errors(lua, ns):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    lua.execute('STUB_FIRE("DISPLAY_SIZE_CHANGED")')
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    lua.execute('STUB_FIRE("BAG_UPDATE_DELAYED")')
    lua.execute('STUB_FIRE("PLAYER_TARGET_CHANGED")')
    lua.execute('STUB_FIRE("UNIT_AURA", "target")')
    lua.execute('STUB_FIRE("UNIT_HEALTH", "target")')
    for ev in ("UNIT_HEALTH", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UNIT_AURA"):
        lua.execute(f'STUB_FIRE("{ev}", "player")')
    assert ns.HUD.u is not None and ns.HUD.u > 0


def test_default_positions_apply_only_once(lua, ns):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    assert not ns.db.positioned
    lua.execute('STUB_FIRE("PLAYER_ENTERING_WORLD")')
    assert ns.db.positioned is True


def test_inventory_toggle_opens_and_closes(lua, ns):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    shown = {"v": False}
    ns.Inventory.frame.Show = lambda self: shown.__setitem__("v", True)
    ns.Inventory.frame.Hide = lambda self: shown.__setitem__("v", False)
    ns.Inventory.frame.IsShown = lambda self: shown["v"]
    ns.Inventory.Toggle()
    assert shown["v"] is True
    ns.Inventory.Toggle()
    assert shown["v"] is False
