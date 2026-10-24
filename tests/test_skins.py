"""Blizzard windows (HUD/Skins.lua) in the Moderno look: black panel, flat tabs, plain close button."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# Windows shaped like ButtonFrameTemplate / PortraitFrameTemplate with PanelTabButtonTemplate tabs.
WINDOWS = r"""
  HOOKS = {}
  local hsf = hooksecurefunc
  function hooksecurefunc(a, b, c) if type(a) == "string" then HOOKS[a] = b else return hsf(a, b, c) end end
  function PanelTemplates_SelectTab(tab) tab:Disable() end
  function QuestFrame_SetTextColor() end
  function QuestFrame_SetTitleTextColor() end
  function QuestInfo_Display() end
  function QuestFrame_SetMaterial() end
  function PanelTemplates_DeselectTab(tab) tab:Enable() end
  function MakeWindow(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(400, 300); f:SetPoint("CENTER")
    f.NineSlice = CreateFrame("Frame", nil, f)
    f.Bg = f:CreateTexture(nil, "BACKGROUND")
    f.TopTileStreaks = f:CreateTexture(nil, "BACKGROUND")
    f.PortraitContainer = CreateFrame("Frame", nil, f)
    f.TitleContainer = CreateFrame("Frame", nil, f)
    f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.TitleContainer.TitleText:SetText(name)
    f.CloseButton = CreateFrame("Button", nil, f)
    f.CloseButton:SetSize(24, 24)
    f.CloseButton.NORMAL = f.CloseButton:CreateTexture(nil, "ARTWORK")
    function f.CloseButton:GetNormalTexture() return self.NORMAL end
    f.Inset = CreateFrame("Frame", nil, f)
    f.Inset.NineSlice = CreateFrame("Frame", nil, f.Inset)
    f.Inset.Bg = f.Inset:CreateTexture(nil, "BACKGROUND")
    f.Tabs = {}
    for i = 1, 2 do
      local t = CreateFrame("Button", name .. "Tab" .. i, f)
      t:SetSize(90, 30)
      t.TabTextures = {}
      for k, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
        t[key] = t:CreateTexture(nil, "BACKGROUND"); t.TabTextures[k] = t[key]
      end
      t.Text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      t.ENABLED = true
      function t:Enable() self.ENABLED = true end
      function t:Disable() self.ENABLED = false end
      function t:IsEnabled() return self.ENABLED end
      f.Tabs[i] = t
    end
    return f
  end
  MakeWindow("CharacterFrame")
  MakeWindow("MerchantFrame")
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=WINDOWS)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def visible(region):
    return bool(region.IsVisible(region))


def test_window_art_gone_and_black_panel_on():
    _, ns, g = preview()
    f = g.MerchantFrame
    for key in ("NineSlice", "Bg", "TopTileStreaks", "PortraitContainer"):
        assert f[key].alpha == 0, key
    assert f.Inset.NineSlice.alpha == 0 and f.Inset.Bg.alpha == 0
    assert f.obFill is not None and f.Inset.obFill is not None
    r, gg, b = f.TitleContainer.TitleText.GetTextColor(f.TitleContainer.TitleText)
    assert r > 0.9 and gg > 0.9


def test_close_button_plain():
    _, ns, g = preview()
    c = g.MerchantFrame.CloseButton
    assert c.NORMAL.alpha == 0 and c.obText.text == "X"


def test_flat_tabs_and_selected_one_white():
    _, ns, g = preview()
    t1, t2 = g.MerchantFrame.Tabs[1], g.MerchantFrame.Tabs[2]
    assert all(t.alpha == 0 for t in t1.TabTextures.values())
    g.PanelTemplates_SelectTab(t1); g.HOOKS.PanelTemplates_SelectTab(t1)
    g.PanelTemplates_DeselectTab(t2); g.HOOKS.PanelTemplates_DeselectTab(t2)
    r1 = t1.Text.GetTextColor(t1.Text)
    r2 = t2.Text.GetTextColor(t2.Text)
    assert r1 > r2


def test_windows_loaded_later_get_the_look():
    rt, ns, g = preview()
    rt.execute('MakeWindow("CollectionsJournal"); PREVIEW_FIRE("ADDON_LOADED", "Blizzard_Collections")')
    assert g.CollectionsJournal.NineSlice.alpha == 0 and g.CollectionsJournal.obFill is not None


def test_world_map_border():
    rt, ns, g = preview()
    rt.execute('WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent); '
               'WorldMapFrame.BorderFrame = MakeWindow("WorldMapBorder"); '
               'PREVIEW_FIRE("ADDON_LOADED", "Blizzard_WorldMap")')
    assert g.WorldMapFrame.BorderFrame.NineSlice.alpha == 0


def test_switched_off():
    _, ns, g = preview({"skins_on": False})
    assert (g.MerchantFrame.NineSlice.alpha or 1) == 1 and g.MerchantFrame.obFill is None


def test_panel_page():
    _, ns, g = preview()
    ns.Panel.Open("skins")
    labels = [r.row.label for r in ns.Panel.rows.values() if r.row is not None]
    assert "Usar o visual da ObsidianUI" in labels


def test_dark_parchment_fonts_turn_light():
    # Quest and gossip text uses fonts made for parchment: dark brown on the black panel.
    rt, ns, g = preview()
    rt.execute("""
      QuestFont = { c = { 0.18, 0.12, 0.06 } }
      function QuestFont:SetTextColor(r, gg, b) self.c = { r, gg, b } end
      function QuestFont:GetTextColor() return self.c[1], self.c[2], self.c[3] end
      PREVIEW_FIRE("PLAYER_LOGIN")
    """)
    assert g.QuestFont.c[1] > 0.5


def test_dark_text_inside_windows_turns_light():
    rt, ns, g = preview()
    rt.execute("""
      local f = MakeWindow("GossipFrame")
      local inner = CreateFrame("Frame", nil, f)
      DARK = inner:CreateFontString(nil, "OVERLAY")
      DARK:SetTextColor(0.18, 0.12, 0.06)
      RED = inner:CreateFontString(nil, "OVERLAY")
      RED:SetTextColor(1, 0.1, 0.1)
    """)
    ns.Skins.Lighten(g.GossipFrame)
    assert g.DARK.GetTextColor(g.DARK)[0] > 0.5
    r, gg, b = g.RED.GetTextColor(g.RED)
    assert (r, gg, b) == (1, 0.1, 0.1)


def test_quest_text_recoloured_after_the_game_sets_it():
    rt, ns, g = preview()
    rt.execute("""
      QUEST_TEXT = UIParent:CreateFontString(nil, "OVERLAY")
      QUEST_TEXT:SetTextColor(0.18, 0.12, 0.06)
    """)
    g.HOOKS.QuestFrame_SetTextColor(g.QUEST_TEXT, "Parchment")
    assert g.QUEST_TEXT.GetTextColor(g.QUEST_TEXT)[0] > 0.5


def test_quest_page_parchment_hidden():
    rt, ns, g = preview()
    rt.execute("""
      PAGE = CreateFrame("Frame", nil, UIParent)
      for _, k in ipairs({ "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "Bg" }) do
        PAGE[k] = PAGE:CreateTexture(nil, "BACKGROUND")
      end
    """)
    g.HOOKS.QuestFrame_SetMaterial(g.PAGE, "Parchment")
    assert g.PAGE.Bg.alpha == 0 and g.PAGE.MaterialTopLeft.alpha == 0
