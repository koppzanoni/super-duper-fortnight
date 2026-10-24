"""Party and raid frames (HUD/GroupFrames.lua) in the Moderno look, with a test mode."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402


def preview(db=None, group=None, n=0):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})))
    if group:
        rt.execute(f'PREVIEW_ROSTER("{group}", {n})')
    return rt, rt.globals().PREVIEW_NS


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def party(ns):
    return [f for f in ns.GroupFrames.party.values() if visible(f)]


def cells(ns):
    return [c for c in ns.GroupFrames.raid.values() if visible(c)]


# ------------------------------------------------------------------ party
def test_solo_shows_no_group_frames():
    _, ns = preview()
    assert party(ns) == [] and cells(ns) == []


def test_party_frames_stack_down_in_the_moderno_look():
    _, ns = preview(group="party", n=3)
    p = party(ns)
    assert [f.unit for f in p] == ["party1", "party2", "party3"]
    assert p[0].name.text == "Membro 1" and str(p[0].art.file).endswith("mod_unit_black")
    a, b = rect(p[0]), rect(p[1])
    assert abs(a[0] - b[0]) < 0.5 and b[1] + b[3] < a[1]               # same column, the next below
    assert p[0].health.value == 9000 and p[0].health.max == 10000


def test_party_frames_hide_in_a_raid():
    _, ns = preview(group="raid", n=10)
    assert party(ns) == [] and len(cells(ns)) == 10


def test_party_switch():
    _, ns = preview({"party_on": False}, group="party", n=3)
    assert party(ns) == []


# ------------------------------------------------------------------ raid
def test_raid_cells_sit_by_subgroup():
    _, ns = preview(group="raid", n=12)
    c = {x.unit: rect(x) for x in cells(ns)}
    # groups as rows (default): members of a group side by side, the next group below
    assert abs(c["raid1"][1] - c["raid5"][1]) < 0.5 and c["raid2"][0] > c["raid1"][0]
    assert c["raid6"][1] < c["raid1"][1] and abs(c["raid6"][0] - c["raid1"][0]) < 0.5
    assert c["raid11"][1] < c["raid6"][1]


def test_raid_groups_as_columns():
    _, ns = preview({"raidGrowth": "columns"}, group="raid", n=10)
    c = {x.unit: rect(x) for x in cells(ns)}
    assert abs(c["raid1"][0] - c["raid5"][0]) < 0.5 and c["raid2"][1] < c["raid1"][1]
    assert c["raid6"][0] > c["raid1"][0] and abs(c["raid6"][1] - c["raid1"][1]) < 0.5


def test_raid_cell_shows_class_health_name_and_role():
    _, ns = preview(group="raid", n=10)
    c = next(x for x in cells(ns) if x.unit == "raid1")             # warrior tank, 90%
    assert c.health.value == 9000 and c.name.text == "Membro 1"
    r, g, b = list(c.health.GetStatusBarTexture(c.health).vc.values())[:3]
    assert abs(r - 0.78) < 0.01 and abs(g - 0.61) < 0.01             # warrior colour
    assert visible(c.role)


def test_raid_cell_states_dead_offline_and_far():
    _, ns = preview(group="raid", n=10)
    c = {x.unit: x for x in cells(ns)}
    assert c["raid4"].status.text == "Morto"
    assert c["raid7"].status.text == "Desconectado"
    assert c["raid3"].alpha < 1 and (c["raid1"].alpha or 1) == 1      # out of range fades


def test_raid_cell_size_settings():
    _, ns = preview({"raidW": 90, "raidH": 44}, group="raid", n=5)
    w, h = rect(cells(ns)[0])[2:]
    assert abs(w - 90) < 1 and abs(h - 44) < 1


def test_raid_switch():
    _, ns = preview({"raid_on": False}, group="raid", n=10)
    assert cells(ns) == []


def test_health_event_updates_a_cell():
    rt, ns = preview(group="raid", n=5)
    rt.execute('ROSTER.raid2.hp = 2500; PREVIEW_FIRE("UNIT_HEALTH", "raid2")')
    c = next(x for x in cells(ns) if x.unit == "raid2")
    assert c.health.value == 2500


# ------------------------------------------------------------------ test mode
def test_test_mode_shows_fake_party_and_raid_and_ends():
    _, ns = preview()
    G = ns.GroupFrames
    G.Test("party")
    assert len(party(ns)) == 4 and party(ns)[0].name.text != ""
    G.Test("raid")
    assert party(ns) == [] and len(cells(ns)) == 20
    G.Test(None)
    assert party(ns) == [] and cells(ns) == []


def test_test_mode_stops_in_combat():
    rt, ns = preview()
    ns.GroupFrames.Test("raid")
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_DISABLED")')
    assert cells(ns) == [] and ns.GroupFrames.testing is None


def test_edit_mode_shows_the_party_when_solo():
    _, ns = preview()
    ns.EditMode.Start()
    assert len(party(ns)) == 4 and visible(ns.EditMode.boxes["party"])
    ns.EditMode.Stop()
    assert party(ns) == []


def test_slash_command_toggles_test_mode():
    rt, ns = preview()
    rt.globals().SlashCmdList.OBSIDIANUI("teste raide")
    assert len(cells(ns)) == 20
    rt.globals().SlashCmdList.OBSIDIANUI("teste")
    assert cells(ns) == []


def test_movable_in_edit_mode():
    _, ns = preview()
    ns.GroupFrames.Test("raid")
    ns.EditMode.Start()
    ns.EditMode.MoveTo("raid", 400, 700)
    assert abs(rect(ns.GroupFrames.raidHolder)[0] - 400) < 1


def test_panel_pages_apply_live():
    _, ns = preview(group="raid", n=10)
    ns.Panel.Open("raid")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Largura")
    row.control.plus.GetScript(row.control.plus, "OnClick")(row.control.plus)
    assert ns.db.raidW == 76
    assert abs(rect(cells(ns)[0])[2] - 76) < 1
    ns.Panel.Open("party")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Mostrar")
    row.control.GetScript(row.control, "OnClick")(row.control)
    assert ns.db.party_on is False


def test_dead_and_offline_turn_grey_and_text_stays_in_the_cell():
    _, ns = preview(group="raid", n=10)
    c = {x.unit: x for x in cells(ns)}
    for u in ("raid4", "raid7"):
        r, g, b = list(c[u].health.GetStatusBarTexture(c[u].health).vc.values())[:3]
        assert abs(r - g) < 0.05 and r < 0.4, u
        h, st = rect(c[u].health), rect(c[u].status)
        assert st[1] >= h[1] - 0.5, u                                 # status not below the health area


# ------------------------------------------------------------------ you in the party, cell style
def party_cells(ns):
    return [c for c in ns.GroupFrames.partyCells.values() if visible(c)]


def test_you_in_the_party_on_top():
    _, ns = preview({"partyPlayer": True}, group="party", n=2)
    me = ns.GroupFrames.me
    assert visible(me) and me.unit == "player" and me.name.text == "Você"
    first = party(ns)[0]
    assert rect(first)[1] + rect(first)[3] < rect(me)[1]               # the others below you
    _, ns = preview(group="party", n=2)
    assert not visible(ns.GroupFrames.me)                             # off by default


def test_party_as_raid_cells():
    _, ns = preview({"partyStyle": "cells", "partyPlayer": True}, group="party", n=3)
    assert party(ns) == [] and not visible(ns.GroupFrames.me)
    c = party_cells(ns)
    assert [x.unit for x in c] == ["player", "party1", "party2", "party3"]
    assert abs(rect(c[0])[1] - rect(c[1])[1]) < 0.5 and rect(c[1])[0] > rect(c[0])[0]   # side by side
    assert c[1].name.text == "Membro 1"


def test_party_cells_go_down_with_groups_in_columns():
    _, ns = preview({"partyStyle": "cells", "raidGrowth": "columns"}, group="party", n=3)
    c = party_cells(ns)
    assert abs(rect(c[0])[0] - rect(c[1])[0]) < 0.5 and rect(c[1])[1] < rect(c[0])[1]


def test_party_cells_hide_in_a_raid_and_test_mode_uses_them():
    _, ns = preview({"partyStyle": "cells"}, group="raid", n=8)
    assert party_cells(ns) == []
    _, ns = preview({"partyStyle": "cells", "partyPlayer": True})
    ns.GroupFrames.Test("party")
    assert len(party_cells(ns)) == 5 and party(ns) == []


def test_health_event_updates_you_in_the_party():
    rt, ns = preview({"partyPlayer": True}, group="party", n=2)
    rt.execute('HP_SET = true')
    me = ns.GroupFrames.me
    assert me.health.value == 28400


# ------------------------------------------------------------------ debuffs, markers, ready check
def shown_icons(owner):
    return [d for d in owner.debuffs.values() if visible(d)]


def test_cells_show_debuffs():
    _, ns = preview(group="raid", n=10)
    c = {x.unit: x for x in cells(ns)}
    assert len(shown_icons(c["raid5"])) == 2 and shown_icons(c["raid1"]) == []
    assert c["raid5"].debuffs[1].icon.file == "ICON:3"
    _, ns = preview({"groupDebuffs": False}, group="raid", n=10)
    assert all(shown_icons(x) == [] for x in cells(ns))


def test_party_frames_show_debuffs_beside_them():
    _, ns = preview(group="party", n=5)
    p = {x.unit: x for x in ns.GroupFrames.party.values()}
    assert shown_icons(p["party4"]) == []
    rt, ns = preview(group="party", n=4)
    rt.execute('ROSTER.party2.debuffs = 2; PREVIEW_FIRE("UNIT_AURA", "party2")')
    f = {x.unit: x for x in ns.GroupFrames.party.values()}["party2"]
    icons = shown_icons(f)
    assert len(icons) == 2 and rect(icons[0])[0] >= rect(f)[0] + rect(f)[2] - 0.5      # right of the frame


def test_raid_markers():
    rt, ns = preview(group="raid", n=10)
    c = {x.unit: x for x in cells(ns)}
    assert visible(c["raid1"].marker) and c["raid1"].marker.markerIndex == 8
    assert visible(c["raid2"].marker) and not visible(c["raid3"].marker)
    rt.execute('ROSTER.raid1.marker = nil; PREVIEW_FIRE("RAID_TARGET_UPDATE")')
    assert not visible(c["raid1"].marker)
    p = {x.unit: x for x in preview(group="party", n=2)[1].GroupFrames.party.values()}
    assert visible(p["party1"].marker)


def test_ready_check_icons_then_gone():
    rt, ns = preview(group="raid", n=5)
    rt.execute('READY = { raid1 = "ready", raid2 = "notready", raid3 = "waiting" }; PREVIEW_FIRE("READY_CHECK", "raid1", 30)')
    c = {x.unit: x for x in cells(ns)}
    assert c["raid1"].ready.file == "READY" and c["raid2"].ready.file == "NOTREADY"
    assert visible(c["raid3"].ready) and not visible(c["raid4"].ready)
    rt.execute('READY.raid3 = "ready"; PREVIEW_FIRE("READY_CHECK_CONFIRM", "raid3", true)')
    assert c["raid3"].ready.file == "READY"
    rt.execute('PREVIEW_FIRE("READY_CHECK_FINISHED")')
    assert not visible(c["raid1"].ready)


def test_test_mode_shows_markers_and_debuffs():
    _, ns = preview()
    ns.GroupFrames.Test("raid")
    c = cells(ns)
    assert any(visible(x.marker) for x in c) and any(shown_icons(x) for x in c)


def test_cell_debuffs_stay_clear_of_the_name():
    _, ns = preview(group="raid", n=10)
    c = next(x for x in cells(ns) if x.unit == "raid5")
    name, icon = rect(c.name), rect(shown_icons(c)[0])
    assert icon[1] + icon[3] <= name[1] + 0.5                         # icons below the name line


# ------------------------------------------------------------------ raid tools
TOOLS = """
  CALLS = {}
  C_PartyInfo = { DoReadyCheck = function() CALLS[#CALLS + 1] = "ready" end,
                  DoCountdown = function(s) CALLS[#CALLS + 1] = "count" .. s end }
  function SetRaidTarget(u, i) CALLS[#CALLS + 1] = u .. i end
  LEADER = true
  function UnitIsGroupLeader(u) return u == "player" and LEADER end
  function UnitIsGroupAssistant() return false end
"""


def tools_preview(db=None, group=None, n=0):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=TOOLS)
    if group:
        rt.execute(f'PREVIEW_ROSTER("{group}", {n})')
    return rt, rt.globals().PREVIEW_NS


def test_raid_tools_for_the_leader_only():
    _, ns = tools_preview()
    assert not visible(ns.RaidTools.frame)                            # solo
    rt, ns = tools_preview(group="party", n=2)
    assert visible(ns.RaidTools.frame)
    rt.execute('LEADER = false; PREVIEW_FIRE("PARTY_LEADER_CHANGED")')
    assert not visible(ns.RaidTools.frame)
    _, ns = tools_preview({"raidTools": False}, group="raid", n=10)
    assert not visible(ns.RaidTools.frame)


def test_raid_tools_buttons():
    rt, ns = tools_preview(group="raid", n=10)
    T = ns.RaidTools
    for b in (T.readyButton, T.countButton, T.markers[8], T.markers[1], T.clearButton):
        b.GetScript(b, "OnClick")(b)
    assert list(rt.globals().CALLS.values()) == ["ready", "count10", "target8", "target1", "target0"]
    assert len(T.markers) == 8


def test_raid_tools_in_test_mode_and_edit_mode():
    _, ns = tools_preview()
    ns.GroupFrames.Test("raid")
    assert visible(ns.RaidTools.frame)
    ns.GroupFrames.Test(None)
    assert not visible(ns.RaidTools.frame)
    assert ns.Movers['items']['raidtools'] is not None
