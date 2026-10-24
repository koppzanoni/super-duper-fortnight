"""Cooldown numbers on icons (HUD/Cooldowns.lua): the game's own countdown, sized and styled."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def preview(db=None, inventory=False):
    rt = preview_render.run_addon(vbars=False, inventory=inventory, db=dict({"installed": True}, **(db or {})))
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def action_cds(ns):
    return [b.cooldown for b in ns.ActionBars.buttons.values()]


def test_action_buttons_show_the_games_numbers():
    _, ns = preview()
    cds = action_cds(ns)
    assert cds and all(cd.hideNumbers is False for cd in cds)
    assert all(cd.minCountdown == 1500 for cd in cds)                 # the global cooldown stays quiet
    assert all(cd.msThreshold == 3 for cd in cds)                     # tenths in the last 3 s


def test_number_size_follows_the_icon():
    _, ns = preview()
    b = ns.ActionBars.buttons[1]
    fs = b.cooldown.GetCountdownFontString(b.cooldown)
    assert 10 <= fs.fsize <= 28 and fs.fsize > 0.3 * rect(b)[2] / (1080 / 900)


def test_settings_change_live():
    _, ns = preview({"cdMin": 3, "cdDecimals": False})
    cd = action_cds(ns)[0]
    assert cd.minCountdown == 3000 and cd.msThreshold == 0
    ns.db.cd_on = False
    ns.Cooldowns.Refresh()
    assert cd.hideNumbers is True


def test_auras_and_target_debuffs_too():
    _, ns = preview()
    buffs = [b for b in ns.Auras.rows.HELPFUL.buttons.values()]
    assert buffs and buffs[0].cd.hideNumbers is False
    deb = [b for b in ns.UnitFrames.debuffs.values()]
    assert deb and deb[0].cd.hideNumbers is False
    _, ns = preview({"cdAuras": False})
    assert [b for b in ns.Auras.rows.HELPFUL.buttons.values()][0].cd.hideNumbers is True


def test_bag_items_too():
    _, ns = preview(inventory=True)
    b = [x for x in ns.Inventory.bagButtons().values()][0]
    assert b.Cooldown.hideNumbers is False


def test_panel_page():
    _, ns = preview()
    ns.Panel.Open("cooldowns")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Só a partir de")
    row.control.plus.GetScript(row.control.plus, "OnClick")(row.control.plus)
    assert ns.db.cdMin == 2 and action_cds(ns)[0].minCountdown == 2000
