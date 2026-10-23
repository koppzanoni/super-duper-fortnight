"""PoE2-style energy shield on the health orb: the player's absorb shields as a blue crescent
that fills the orb from the right, sized by absorb / max health."""
from test_orbs_liquid import boot, last

SHIELD_PRE = """
  function UnitHealthMax() return 40000 end
  ABSORB = 10000
  function UnitGetTotalAbsorbs(unit) return ABSORB end
  local cf2 = CreateFrame
  function CreateFrame(...)
    local f = cf2(...)
    for _, n in ipairs({ "SetOrientation", "SetReverseFill", "SetMinMaxValues", "SetValue" }) do
      f[n] = function(self, ...) self.last[n] = { ... } end
    end
    return f
  end
"""


def test_shield_fills_the_health_orb_from_the_right(lua, ns):
    boot(lua, ns, pre=SHIELD_PRE)
    s = ns.Orbs.health.shield
    assert last(s.bar, "SetOrientation") == ("HORIZONTAL",)
    assert last(s.bar, "SetReverseFill") == (True,)
    assert last(s.bar, "SetMinMaxValues") == (0, 40000)
    assert last(s.bar, "SetValue") == (10000,)
    assert s.bar.shown is True


def test_shield_follows_absorb_changes(lua, ns):
    boot(lua, ns, pre=SHIELD_PRE)
    s = ns.Orbs.health.shield
    lua.execute('ABSORB = 0; STUB_FIRE("UNIT_ABSORB_AMOUNT_CHANGED", "player")')
    assert s.bar.shown is False
    lua.execute('ABSORB = 4000; STUB_FIRE("UNIT_ABSORB_AMOUNT_CHANGED", "player")')
    assert s.bar.shown is True and last(s.bar, "SetValue") == (4000,)
    lua.execute('ABSORB = 0; STUB_FIRE("UNIT_ABSORB_AMOUNT_CHANGED", "target")')
    assert s.bar.shown is True  # other units are ignored


def test_only_the_health_orb_has_a_shield(lua, ns):
    boot(lua, ns, pre=SHIELD_PRE)
    assert ns.Orbs.power.shield is None


def test_no_absorb_api_hides_the_shield(lua, ns):
    boot(lua, ns, pre=SHIELD_PRE + "UnitGetTotalAbsorbs = false")  # the stub turns nil globals into stubs
    assert ns.Orbs.health.shield.bar.shown is False


# The shield swirls like the liquid, with its own flipbook layer.
def test_shield_swirls_with_the_orb_animation(lua, ns):
    boot(lua, ns, pre=SHIELD_PRE)
    ns.Orbs.SetStyle("a")
    o = ns.Orbs.health
    o.t = 0
    o.Step(o, 1.0)
    w = o.shield.wisp
    assert last(w[1], "SetTexCoord") is not None and last(w[1], "SetAlpha")[0] > 0
