"""Click-casting on the group and raid frames (HUD/ClickCast.lua): a spell per modifier + mouse button,
as secure attributes, set out of combat only."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

PRE = """
COMBAT = false
function InCombatLockdown() return COMBAT end
"""


def preview(db=None, group=("raid", 10)):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=PRE)
    g = rt.globals()
    g.PREVIEW_ROSTER(*group)
    return rt, g.PREVIEW_NS, g


def attr(f, name):
    return f.attrs[name]


def test_spells_on_every_raid_cell():
    _, ns, g = preview({"clickcast": {"shift-1": "Renovar", "3": "Prece de Cura"}})
    for c in ns.GroupFrames.raid.values():
        assert attr(c, "shift-type1") == "spell" and attr(c, "shift-spell1") == "Renovar"
        assert attr(c, "type3") == "spell" and attr(c, "spell3") == "Prece de Cura"
        assert attr(c, "ctrl-type1") is None


def test_party_frames_and_you_too():
    _, ns, g = preview({"clickcast": {"alt-2": "Dissipar Magia"}}, group=("party", 4))
    owners = [ns.GroupFrames.me] + list(ns.GroupFrames.party.values()) + list(ns.GroupFrames.partyCells.values())
    for f in owners:
        assert attr(f, "alt-type2") == "spell" and attr(f, "alt-spell2") == "Dissipar Magia"


def test_left_and_right_click_keep_target_and_menu():
    _, ns, g = preview({"clickcast": {"shift-1": "Renovar"}})
    c = ns.GroupFrames.raid[1]
    assert attr(c, "type1") != "spell" and attr(c, "type2") != "spell"


def test_changes_wait_for_combat_to_end():
    _, ns, g = preview()
    g.COMBAT = True
    ns.ClickCast.Set("ctrl-1", "Cura Relâmpago")
    c = ns.GroupFrames.raid[1]
    assert attr(c, "ctrl-spell1") is None                     # protected frames: not in combat
    g.COMBAT = False
    g.PREVIEW_FIRE("PLAYER_REGEN_ENABLED")
    assert attr(c, "ctrl-spell1") == "Cura Relâmpago"


def test_clearing_a_binding():
    _, ns, g = preview({"clickcast": {"shift-1": "Renovar"}})
    ns.ClickCast.Set("shift-1", "  ")
    c = ns.GroupFrames.raid[1]
    assert attr(c, "shift-type1") is None and attr(c, "shift-spell1") is None
    assert "shift-1" not in list((ns.db.clickcast or {}).keys())


def test_panel_page_with_text_rows():
    _, ns, g = preview()
    ns.Panel.Open("clickcast")
    rows = {r.row.label: r for r in ns.Panel.rows.values() if r.row is not None}
    for label in ("Shift + esquerdo", "Ctrl + esquerdo", "Alt + esquerdo", "Shift + direito", "Botão do meio", "Botão 5"):
        assert label in rows, label
    box = rows["Shift + esquerdo"].control
    box.SetText(box, "Renovar")
    box.GetScript(box, "OnEnterPressed")(box)
    assert ns.db.clickcast["shift-1"] == "Renovar"
    assert attr(ns.GroupFrames.raid[1], "shift-spell1") == "Renovar"
