"""Smooth status bars (Core/Smooth.lua): a bar's fill eases to new values, snaps on unit change,
and passes secret or non-number values straight through without any arithmetic."""
from conftest import load_addon_file


def make_bar(lua, lo=0, hi=200):
    """A minimal real StatusBar: SetValue/GetValue/GetMinMaxValues actually work."""
    ctor = lua.eval("""
      function(min, max)
        local b = { _v = 0, _min = min, _max = max }
        function b:SetValue(v) self._v = v end
        function b:GetValue() return self._v end
        function b:GetMinMaxValues() return self._min, self._max end
        return b
      end
    """)
    return ctor(lo, hi)


def tick(ns, elapsed):
    driver = ns.Smooth.driver
    driver.handlers.OnUpdate(driver, elapsed)


def load(lua, ns, smooth=True):
    # The stub makes issecretvalue(v) truthy; turn it off so the easing path runs.
    lua.execute("issecretvalue = function() return false end")
    ns.db = lua.table_from({"smoothBars": smooth})
    load_addon_file(lua, "Core/Smooth.lua", ns)
    return ns


def test_setvalue_does_not_jump_but_eases(lua, ns):
    load(lua, ns)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    bar.SetValue(bar, 100)       # from 0 towards 100
    assert bar._v == 0           # nothing shown yet: no jump
    tick(ns, 0.1)
    assert 0 < bar._v < 100      # partway there
    first = bar._v
    tick(ns, 0.1)
    assert first < bar._v < 100  # still climbing


def test_eases_all_the_way_and_stops(lua, ns):
    load(lua, ns)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    bar.SetValue(bar, 100)
    for _ in range(60):          # ~2 s of frames
        tick(ns, 0.05)
    assert abs(bar._v - 100) < 0.2
    # once settled the bar drops out of the active set: a later tick is a no-op, not a drift
    settled = bar._v
    tick(ns, 0.05)
    assert bar._v == settled


def test_snap_lands_at_once(lua, ns):
    load(lua, ns)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    ns.Smooth.Snap(bar)
    bar.SetValue(bar, 80)
    assert bar._v == 80          # no easing after a snap


def test_secret_value_passes_through_without_math(lua, ns):
    load(lua, ns)
    # a "secret" value: a table that errors on arithmetic, like the game's secret numbers
    lua.execute("""
      issecretvalue = function(v) return type(v) == 'table' and v.secret == true end
      SECRET = setmetatable({ secret = true }, { __sub = function() error('no math on secrets') end,
        __add = function() error('no math on secrets') end })
    """)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    secret = lua.eval("SECRET")
    bar.SetValue(bar, secret)    # must not do arithmetic; goes straight to the real SetValue
    assert bar._v.secret is True  # the very table we passed, untouched


def test_disabled_sets_value_instantly(lua, ns):
    load(lua, ns, smooth=False)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    bar.SetValue(bar, 100)
    assert bar._v == 100


def test_wrap_is_idempotent(lua, ns):
    load(lua, ns)
    bar = make_bar(lua)
    ns.Smooth.Wrap(bar)
    first_set = bar.obSet
    ns.Smooth.Wrap(bar)          # second wrap must not re-wrap (would lose the real SetValue)
    assert lua.eval("rawequal")(bar.obSet, first_set)
