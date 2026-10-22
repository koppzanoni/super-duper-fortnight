import pytest

from conftest import load_addon_file, toc_files


@pytest.fixture
def loaded(lua, ns):
    for f in toc_files():
        load_addon_file(lua, f, ns)
    lua.execute('STUB_FIRE("ADDON_LOADED", "ObsidianUI")')
    return ns


def enabled(ns, bar):
    return [ns.VerticalBars.bars[bar][i].obEnabled for i in range(1, 13)]


@pytest.mark.parametrize("v1,v2,exp1,exp2", [
    (False, False, False, False),
    (True, False, True, False),
    (False, True, False, True),
    (True, True, True, True),
])
def test_refresh_enables_only_chosen_bars(loaded, v1, v2, exp1, exp2):
    loaded.db.vbar1, loaded.db.vbar2 = v1, v2
    loaded.VerticalBars.Refresh()
    assert enabled(loaded, 1) == [exp1] * 12
    assert enabled(loaded, 2) == [exp2] * 12


def test_refresh_in_combat_waits_for_regen(lua, loaded):
    lua.globals().STUB_COMBAT = True
    loaded.db.vbar1 = True
    loaded.VerticalBars.Refresh()
    assert enabled(loaded, 1) == [False] * 12
    lua.globals().STUB_COMBAT = False
    lua.execute('STUB_FIRE("PLAYER_REGEN_ENABLED")')
    assert enabled(loaded, 1) == [True] * 12
