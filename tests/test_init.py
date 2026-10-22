from conftest import load_addon_file


def test_combat_queue_defers_until_regen(lua, ns):
    load_addon_file(lua, "Core/Init.lua", ns)
    g = lua.globals()
    g.STUB_COMBAT = True
    calls = []
    ns.RunOutOfCombat(lambda: calls.append(1))
    assert calls == []
    g.STUB_COMBAT = False
    lua.execute('STUB_FIRE("PLAYER_REGEN_ENABLED")')
    assert calls == [1]
    lua.execute('STUB_FIRE("PLAYER_REGEN_ENABLED")')
    assert calls == [1]


def test_run_out_of_combat_runs_immediately(lua, ns):
    load_addon_file(lua, "Core/Init.lua", ns)
    calls = []
    ns.RunOutOfCombat(lambda: calls.append(1))
    assert calls == [1]
