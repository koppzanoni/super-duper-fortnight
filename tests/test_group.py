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
