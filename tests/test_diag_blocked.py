"""Blocked actions are named in chat and kept in the saved variables (Core/Diag.lua)."""
from conftest import load_addon_file, toc_files


def boot(lua, ns):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    lua.execute('STUB_FIRE("PLAYER_LOGIN")')
    return ns


def test_blocked_action_is_logged(lua, ns):
    boot(lua, ns)
    lua.execute('STUB_FIRE("ADDON_ACTION_BLOCKED", "ObsidianUI", "Frame:SetPoint()")')
    lua.execute('STUB_FIRE("ADDON_ACTION_BLOCKED", "OtherAddon", "CastSpell()")')
    log = list(ns.db.blockLog.values())
    assert len(log) == 1 and "Frame:SetPoint()" in log[0]
