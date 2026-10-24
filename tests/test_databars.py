"""Data bars (HUD/XPBar.lua): experience with rested and the watched reputation, with options."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# Watching a faction: Honrado (reaction 6), 300 of 6000 into the level.
REP = """
  C_Reputation = { GetWatchedFactionData = function()
    return { name = "Ventobravo", reaction = 6, currentReactionThreshold = 3000,
             nextReactionThreshold = 9000, currentStanding = 3300 }
  end }
"""


def preview(db=None, pre=REP):
    rt = preview_render.run_addon(vbars=False, db=db, pre=pre)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def test_xp_and_reputation_stacked_under_the_action_bar():
    _, ns = preview()
    D = ns.DataBars
    assert visible(D.xp) and visible(D.rep)
    assert D.xp.value == 62 and D.xp.max == 100 and D.rested.value == 72
    assert D.rep.value == 300 and D.rep.max == 6000
    xp, rep = rect(D.xp), rect(D.rep)
    assert rep[1] + rep[3] <= xp[1] + 0.5                       # reputation under the experience


def test_reputation_colour_follows_the_standing():
    _, ns = preview()
    friendly = list(ns.DataBars.rep.GetStatusBarTexture(ns.DataBars.rep).vc.values())[:3]
    _, ns2 = preview(pre=REP.replace("reaction = 6", "reaction = 2"))
    hostile = list(ns2.DataBars.rep.GetStatusBarTexture(ns2.DataBars.rep).vc.values())[:3]
    assert friendly[1] > friendly[0] and hostile[0] > hostile[1]


def test_no_watched_faction_hides_reputation():
    _, ns = preview(pre="C_Reputation = { GetWatchedFactionData = function() return nil end }")
    assert visible(ns.DataBars.xp) and not visible(ns.DataBars.rep)


def test_max_level_hides_experience_and_reputation_moves_up():
    _, ns = preview(pre=REP + "function UnitLevel() return 60 end")
    D = ns.DataBars
    assert not visible(D.xp) and visible(D.rep)
    assert abs(rect(D.rep)[1] + rect(D.rep)[3] - (rect(D.holder)[1] + rect(D.holder)[3])) < 0.5


def test_switches():
    _, ns = preview({"xp_on": False, "rep_on": False})
    assert not visible(ns.DataBars.holder)


def test_text_always_hover_and_never():
    _, ns = preview({"dataText": "always"})
    D = ns.DataBars
    assert visible(D.xp.text) and "62%" in D.xp.text.text
    assert "Ventobravo" in D.rep.text.text and "Honrado" in D.rep.text.text and "5%" in D.rep.text.text
    _, ns = preview({"dataText": "hover"})
    D = ns.DataBars
    assert not visible(D.xp.text)
    D.holder.GetScript(D.holder, "OnEnter")(D.holder)
    assert visible(D.xp.text)
    D.holder.GetScript(D.holder, "OnLeave")(D.holder)
    assert not visible(D.xp.text)
    _, ns = preview({"dataText": "never"})
    ns.DataBars.holder.GetScript(ns.DataBars.holder, "OnEnter")(ns.DataBars.holder)
    assert not visible(ns.DataBars.xp.text)


def test_height_setting():
    _, ns = preview({"dataHeight": 10, "dataText": "never"})
    thin = rect(preview({"dataText": "never"})[1].DataBars.xp)[3]   # default 5
    assert abs(rect(ns.DataBars.xp)[3] - thin * 2) < 0.5


def test_reputation_updates_on_event():
    rt, ns = preview()
    rt.execute('C_Reputation.GetWatchedFactionData = function() return nil end; PREVIEW_FIRE("UPDATE_FACTION")')
    assert not visible(ns.DataBars.rep)


def test_movable_in_edit_mode():
    _, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.MoveTo("databars", 200, 900)
    assert abs(rect(ns.DataBars.holder)[0] - 200) < 1


def test_panel_page_applies_live():
    _, ns = preview()
    ns.Panel.Open("databars")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Reputação")
    row.control.GetScript(row.control, "OnClick")(row.control)
    assert ns.db.rep_on is False and not visible(ns.DataBars.rep)


def test_action_bar_rises_to_keep_tall_data_bars_on_screen():
    _, ns = preview({"dataHeight": 9})
    holder, bar = rect(ns.DataBars.holder), rect(ns.ActionBars.modernFrame)
    assert holder[1] >= 0 and holder[1] + holder[3] < bar[1]
    _, ns1 = preview({"rep_on": False, "dataText": "never"})  # one thin bar: the bar stays put
    assert abs(rect(ns1.ActionBars.modernFrame)[1] - ns1.HUD.modernBar.bottom) < 0.5
    assert abs(ns1.HUD.modernBar.bottom - 14 * ns1.HUD.modernBar.s) < 0.5


def test_bar_drops_back_when_reputation_goes_away():
    rt, ns = preview({"dataHeight": 9})
    high = rect(ns.ActionBars.modernFrame)[1]
    rt.execute('C_Reputation.GetWatchedFactionData = function() return nil end; PREVIEW_FIRE("UPDATE_FACTION")')
    assert rect(ns.ActionBars.modernFrame)[1] < high


def test_text_fits_inside_its_bar():
    for mode in ("always", "hover"):
        _, ns = preview({"dataText": mode})
        D = ns.DataBars
        for bar in (D.xp, D.rep):
            assert bar.text.fsize <= rect(bar)[3], mode
        xp, rep = rect(D.xp), rect(D.rep)
        assert rep[1] + rep[3] <= xp[1]                              # no overlap between the bars
    _, ns = preview({"dataText": "never"})                          # no text: as thin as asked
    assert abs(rect(ns.DataBars.xp)[3] - 5 * ns.HUD.modernBar.s) < 0.5
