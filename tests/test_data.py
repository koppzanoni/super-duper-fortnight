import pytest

from conftest import load_pure

ENUM = """
Enum = { PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
  SoulShards = 7, HolyPower = 9, Chi = 12, ArcaneCharges = 16 } }
PowerBarColor = { FURY = { r = 0.79, g = 0.26, b = 0.99 } }
"""


@pytest.fixture
def D(pure):
    pure.execute(ENUM)
    return load_pure(pure, "Core/Data.lua").Data


def test_action_layout_36_unique(D):
    layout = D.ACTION_LAYOUT
    entries = [layout[r][c] for r in (1, 2) for c in range(1, 19)]
    ids = [e.actionID for e in entries]
    assert len(ids) == 36 and len(set(ids)) == 36
    for c in range(1, 13):
        assert layout[1][c].actionID == c
        assert layout[1][c].binding == f"ACTIONBUTTON{c}"
        assert layout[2][c].actionID == 48 + c
        assert layout[2][c].binding == f"MULTIACTIONBAR2BUTTON{c}"
    extra = [layout[1][c] for c in range(13, 19)] + [layout[2][c] for c in range(13, 19)]
    assert [e.actionID for e in extra] == list(range(61, 73))
    assert [e.binding for e in extra] == [f"MULTIACTIONBAR1BUTTON{i}" for i in range(1, 13)]


def test_vbar_actions(D):
    assert [D.VBAR_ACTIONS[1][i].actionID for i in range(1, 13)] == list(range(25, 37))
    assert D.VBAR_ACTIONS[1][1].binding == "MULTIACTIONBAR3BUTTON1"
    assert [D.VBAR_ACTIONS[2][i].actionID for i in range(1, 13)] == list(range(37, 49))
    assert D.VBAR_ACTIONS[2][12].binding == "MULTIACTIONBAR4BUTTON12"


def test_paging_driver_string(D):
    s = D.PagingDriver()
    order = ["[vehicleui] 12", "[overridebar] 14", "[possessbar] 12", "[shapeshift] 13", "[bonusbar:5] 11",
             "[bonusbar:1] 7", "[bonusbar:2] 8", "[bonusbar:3] 9", "[bonusbar:4] 10"]
    pos = [s.index(p) for p in order]
    assert pos == sorted(pos)
    assert s.rstrip().endswith("1")


def test_class_resource(D, pure):
    P = pure.globals().Enum.PowerType
    assert D.ClassResourceFor("ROGUE").powerType == P.ComboPoints
    assert D.ClassResourceFor("DRUID", None, P.Energy).powerType == P.ComboPoints
    assert D.ClassResourceFor("DRUID", None, P.Mana) is None
    assert D.ClassResourceFor("WARRIOR") is None
    assert D.ClassResourceFor("MAGE", 1).powerType == P.ArcaneCharges
    assert D.ClassResourceFor("MAGE", 2) is None
    assert D.ClassResourceFor("PALADIN").powerType == P.HolyPower
    assert D.ClassResourceFor("WARLOCK").powerType == P.SoulShards
    assert D.ClassResourceFor("DEATHKNIGHT").powerType == P.Runes
    assert D.ClassResourceFor("MONK", 3).powerType == P.Chi
    assert D.ClassResourceFor("MONK", 1) is None


def test_power_colors(D):
    assert D.PowerColor("MANA") == pytest.approx((0.18, 0.39, 0.84))
    assert D.PowerColor("RAGE") == pytest.approx((0.62, 0.08, 0.05))
    assert D.PowerColor("FURY") == pytest.approx((0.79, 0.26, 0.99))
    assert D.ORB_COLORS.HEALTH.r == pytest.approx(0.78)


def test_menus(D):
    left = [D.MENU_LEFT[i] for i in range(1, len(D.MENU_LEFT) + 1)]
    right = [D.MENU_RIGHT[i] for i in range(1, len(D.MENU_RIGHT) + 1)]
    assert len(left) == 9 and len(right) == 9
    ids = [e.id for e in left + right]
    assert len(set(ids)) == 18
    assert left[0].id == "character"


def test_equip_slots(D):
    assert len(D.EQUIP_LEFT) == 8 and len(D.EQUIP_RIGHT) == 8 and len(D.WEAPONS) == 3
    assert D.EQUIP_LEFT[1] == "HeadSlot"
    assert D.WEAPONS[3] == "RangedSlot"


def test_hud_coordinates_from_spec(D):
    H = D.HUD
    assert (H.width, H.height) == (2692, 381)
    assert (H.orb.x, H.orb.y, H.orb.w, H.orb.h) == (68, 52, 249, 256)
    assert list(H.barCols.values()) == [710, 782, 853, 925, 997, 1069, 1140, 1211, 1283]
    assert list(H.barRows.values()) == [114, 215]
    assert list(H.menuCols.values()) == [429, 488, 547]
    assert (H.xp.x, H.xp.y, H.xp.h) == (730, 341, 16)
