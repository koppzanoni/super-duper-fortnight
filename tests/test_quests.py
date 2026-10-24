"""Quest tracker (HUD/QuestTracker.lua) in the Moderno look: headers, place, combat and instances."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# ObjectiveTrackerFrame shaped like the game's (container + module headers).
TRACKER = r"""
  HOOKS = {}
  local hsf = hooksecurefunc
  function hooksecurefunc(a, b, c)
    if type(a) == "table" and b == "Update" then a.UPDATE_HOOK = c; return end
    if type(a) == "table" then return hsf(a, b, c) end
  end
  local function header(parent, text)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(260, 26)
    h.Background = h:CreateTexture(nil, "BACKGROUND")
    h.Text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.Text:SetText(text)
    h.MinimizeButton = CreateFrame("Button", nil, h)
    return h
  end
  local t = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
  t:SetSize(260, 400)
  t.NineSlice = CreateFrame("Frame", nil, t)
  t.Header = header(t, "Objetivos")
  t.Header:SetPoint("TOPLEFT", t, "TOPLEFT")
  t.modules = {}
  for i, name in ipairs({ "Missões", "Campanha" }) do
    local m = CreateFrame("Frame", nil, t)
    m.Header = header(m, name)
    m.Header:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -40 * i)
    t.modules[i] = m
  end
  function t:SetCollapsed(c) self.collapsed = c end
  function t:IsCollapsed() return self.collapsed == true end
  function t:Update() end
  INSTANCE = false
  function IsInInstance() return INSTANCE, INSTANCE and "party" or "none" end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=TRACKER)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def test_headers_in_the_look():
    _, ns, g = preview()
    t = g.ObjectiveTrackerFrame
    assert t.NineSlice.alpha == 0 and t.Header.Background.alpha == 0
    for m in t.modules.values():
        assert m.Header.Background.alpha == 0 and visible(m.Header.obLine)
    r, gg, b = t.Header.Text.GetTextColor(t.Header.Text)
    assert r > 0.9 and gg > 0.9


def test_new_modules_get_the_look_on_update():
    rt, ns, g = preview()
    rt.execute("""
      local m = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
      m.Header = CreateFrame("Frame", nil, m)
      m.Header.Background = m.Header:CreateTexture(nil, "BACKGROUND")
      m.Header.Text = m.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      ObjectiveTrackerFrame.modules[3] = m
      ObjectiveTrackerFrame.UPDATE_HOOK(ObjectiveTrackerFrame)
    """)
    assert g.ObjectiveTrackerFrame.modules[3].Header.Background.alpha == 0


def test_tracker_follows_its_holder_and_moves_in_edit_mode():
    _, ns, g = preview()
    t, holder = g.ObjectiveTrackerFrame, ns.QuestTracker.holder
    assert abs(rect(t)[0] + rect(t)[2] - (rect(holder)[0] + rect(holder)[2])) < 0.5
    ns.EditMode.Start()
    ns.EditMode.MoveTo("quests", 300, 700)
    assert abs(rect(holder)[0] - 300) < 1 and abs(rect(t)[0] + rect(t)[2] - (rect(holder)[0] + rect(holder)[2])) < 0.5


def test_collapses_in_combat_and_opens_after():
    rt, ns, g = preview()
    t = g.ObjectiveTrackerFrame
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_DISABLED")')
    assert t.collapsed is True
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_ENABLED")')
    assert t.collapsed is False
    _, ns, g = preview({"questCombat": False})
    rt2 = g
    g.PREVIEW_FIRE("PLAYER_REGEN_DISABLED")
    assert g.ObjectiveTrackerFrame.collapsed is not True


def test_collapsed_in_instances_when_asked():
    rt, ns, g = preview({"questInstance": True})
    rt.execute('INSTANCE = true; PREVIEW_FIRE("PLAYER_ENTERING_WORLD")')
    assert g.ObjectiveTrackerFrame.collapsed is True
    rt.execute('INSTANCE = false; PREVIEW_FIRE("PLAYER_ENTERING_WORLD")')
    assert g.ObjectiveTrackerFrame.collapsed is False


def test_player_collapse_is_kept():
    rt, ns, g = preview()
    t = g.ObjectiveTrackerFrame
    t.collapsed = True                                                   # the player closed it
    rt.execute('PREVIEW_FIRE("PLAYER_REGEN_DISABLED"); PREVIEW_FIRE("PLAYER_REGEN_ENABLED")')
    assert t.collapsed is True


def test_switched_off():
    _, ns, g = preview({"quest_on": False})
    assert (g.ObjectiveTrackerFrame.Header.Background.alpha or 1) == 1


def test_panel_page():
    _, ns, g = preview()
    ns.Panel.Open("quests")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    assert "Recolher em combate" in labels and "Recolher em instâncias" in labels
