"""Info bar (HUD/InfoBar.lua): FPS, latency, durability, bags, gold, friends, guild and clock."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

GAME = """
  FPS = 61.6; HOME, WORLD = 28, 41; DUR = { [1] = { 20, 100 }, [5] = { 90, 100 } }
  function GetFramerate() return FPS end
  function GetNetStats() return 0, 0, HOME, WORLD end
  function GetInventoryItemDurability(slot) local d = DUR[slot]; if d then return d[1], d[2] end end
  function GetMoney() return 1234567 end
  C_FriendList = { GetNumOnlineFriends = function() return 4 end }
  function IsInGuild() return true end
  function GetNumGuildMembers() return 50, 12 end
  function date(fmt) return "10:24" end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=db, pre=GAME)
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def texts(ns):
    return {k: v.text for k, v in ns.InfoBar.texts.items() if visible(v)}


def test_defaults_show_the_everyday_items_above_the_menu():
    _, ns = preview()
    t = texts(ns)
    assert set(t) == {"fps", "ms", "dur", "bags", "friends", "clock"}
    assert "62" in t["fps"] and "41" in t["ms"] and "20%" in t["dur"] and "10:24" in t["clock"]
    assert "4" in t["friends"]
    r, m, bar = rect(ns.InfoBar.frame), rect(ns.MenuPanels.bandFrame), rect(ns.ActionBars.modernFrame)
    assert abs((r[0] + r[2]) - (m[0] + m[2])) < 0.5 and r[1] > m[1] + m[3]
    assert r[0] > bar[0] + bar[2]                            # clear of the action bar


def test_bags_count_free_slots():
    _, ns = preview()
    import re
    m = re.match(r"Bolsas (\d+)/(\d+)$", texts(ns)["bags"])
    assert m and int(m.group(1)) <= int(m.group(2)) and int(m.group(2)) > 0


def test_items_switch_from_the_panel_and_the_bar_resizes():
    _, ns = preview()
    w = rect(ns.InfoBar.frame)[2]
    ns.Panel.Open("infobar")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Ouro")
    row.control.GetScript(row.control, "OnClick")(row.control)
    assert "gold" in texts(ns) and rect(ns.InfoBar.frame)[2] > w
    assert ns.db.profiles["Padrão"].info_gold is True


def test_alert_colours():
    rt, ns = preview()
    dur = ns.InfoBar.texts.dur
    assert list(dur.tcolor.values())[0] > 0.9 and list(dur.tcolor.values())[1] < 0.5   # 20%: red
    rt.globals().FPS = 30
    ns.InfoBar.Update()
    fps = ns.InfoBar.texts.fps
    assert list(fps.tcolor.values())[1] > 0.7 and list(fps.tcolor.values())[2] < 0.5    # yellow


def test_it_is_movable_in_the_edit_mode():
    _, ns = preview()
    ns.EditMode.Start()
    ns.EditMode.MoveTo("info", 800, 500)
    r = rect(ns.InfoBar.frame)
    assert abs(r[0] - 800) < 0.5 and abs(r[1] + r[3] - 500) < 0.5


def test_module_off_hides_it():
    _, ns = preview({"info_on": False})
    assert not visible(ns.InfoBar.frame)
