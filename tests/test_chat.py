"""Chat (HUD/Chat.lua) in the Moderno look: panel, flat tabs, edit box, hidden buttons, copy box."""
import sys

from conftest import ROOT

sys.path.insert(0, str(ROOT / "tools"))
import preview_render  # noqa: E402

# Two chat windows shaped like the game's (FloatingChatFrame.xml / ChatFrameEditBox.xml).
CHAT = r"""
  NUM_CHAT_WINDOWS = 2
  function FCFTab_UpdateColors() end
  function FCF_OpenNewWindow() end
  function FCF_OpenTemporaryWindow() end
  SELECTED_CHAT_FRAME = false
  HOOKED = {}
  local hsf = hooksecurefunc
  function hooksecurefunc(a, b, c)
    if type(a) == "string" then HOOKED[a] = b end
  end
  local BORDER = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
  local TAB = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft",
    "HighlightMiddle", "HighlightRight" }
  for i = 1, 2 do
    local name = "ChatFrame" .. i
    local cf = CreateFrame("ScrollingMessageFrame", name, UIParent)
    cf:SetSize(420, 180)
    cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 120)
    for _, k in ipairs(BORDER) do _G[name .. k] = cf:CreateTexture(name .. k, "BACKGROUND") end
    cf.MESSAGES = { "|cffffd100[Geral]|r Olá", "Bem-vindo a Azeroth", "|Hplayer:Lyra|h[Lyra]|h: oi" }
    function cf:GetNumMessages() return #self.MESSAGES end
    function cf:GetMessageInfo(n) return self.MESSAGES[n] end
    function cf:SetTimeVisible(t) self.timeVisible = t end
    function cf:SetFading(f) self.fading = f end
    cf.buttonFrame = CreateFrame("Frame", name .. "ButtonFrame", cf)
    -- Midnight: a thin scroll bar right of the messages, outside the frame
    cf.ScrollBar = CreateFrame("Frame", nil, cf)
    cf.ScrollBar:SetPoint("TOPLEFT", cf, "TOPRIGHT", 0, 0)
    cf.ScrollBar:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", 0, 0)
    cf.ScrollBar:SetWidth(10)
    local tab = CreateFrame("Button", name .. "Tab", UIParent)
    tab:SetSize(80, 24)
    tab:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", (i - 1) * 84, 4)
    for _, k in ipairs(TAB) do tab[k] = tab:CreateTexture(nil, "BACKGROUND") end
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.Text:SetText(i == 1 and "Geral" or "Combate")
    local eb = CreateFrame("EditBox", name .. "EditBox", cf)
    eb:SetSize(420, 28)
    for _, k in ipairs({ "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }) do
      _G[name .. "EditBox" .. k] = eb:CreateTexture(name .. "EditBox" .. k, "BACKGROUND")
    end
    cf.editBox = eb
  end
  for _, n in ipairs({ "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton" }) do
    _G[n] = CreateFrame("Button", n, UIParent)
  end
"""


def preview(db=None):
    rt = preview_render.run_addon(vbars=False, db=dict({"installed": True}, **(db or {})), pre=CHAT)
    return rt, rt.globals().PREVIEW_NS, rt.globals()


def rect(region):
    return tuple(region.Rect(region).values())


def visible(region):
    return bool(region.IsVisible(region))


def test_panel_replaces_the_games_border():
    _, ns, g = preview()
    cf = g.ChatFrame1
    assert g.ChatFrame1Background.alpha == 0 and g.ChatFrame1TopLeftTexture.alpha == 0
    panel = cf.obPanel
    assert visible(panel)
    p, c = rect(panel), rect(cf)
    assert p[0] < c[0] and p[0] + p[2] > c[0] + c[2] and p[1] < c[1] and p[1] + p[3] > c[1] + c[3]


def test_flat_tabs_selected_in_white():
    _, ns, g = preview()
    tab = g.ChatFrame1Tab
    assert all(tab[k].alpha == 0 for k in ("Left", "Middle", "ActiveLeft", "HighlightRight"))
    g.HOOKED.FCFTab_UpdateColors(tab, True)
    r1 = tab.Text.GetTextColor(tab.Text)
    g.HOOKED.FCFTab_UpdateColors(g.ChatFrame2Tab, False)
    r2 = g.ChatFrame2Tab.Text.GetTextColor(g.ChatFrame2Tab.Text)
    assert r1 > r2


def test_edit_box_in_the_look_under_the_chat():
    _, ns, g = preview()
    eb = g.ChatFrame1EditBox
    assert g.ChatFrame1EditBoxLeft.alpha == 0 and g.ChatFrame1EditBoxFocusMid.alpha == 0
    assert visible(eb.obPanel) or eb.obPanel is not None
    assert rect(eb)[1] + rect(eb)[3] <= rect(g.ChatFrame1.obPanel)[1] + 0.5


def test_buttons_hidden_and_back_on_reload_only():
    _, ns, g = preview()
    assert not visible(g.ChatFrameMenuButton) and not visible(g.QuickJoinToastButton)
    assert not visible(g.ChatFrame1.buttonFrame)
    _, ns, g = preview({"chatButtons": True})
    assert visible(g.ChatFrameMenuButton)


def test_messages_fade_after_the_chosen_time():
    _, ns, g = preview({"chatFade": 45})
    assert g.ChatFrame1.timeVisible == 45 and g.ChatFrame1.fading is True
    ns.db.chatFade = 0
    ns.Chat.Apply()
    assert g.ChatFrame1.fading is False


def test_copy_box_lists_the_messages_as_plain_text():
    _, ns, g = preview()
    ns.Chat.Copy(g.ChatFrame1)
    text = ns.Chat.copyBox.edit.text
    assert visible(ns.Chat.copyBox) and "[Geral] Olá" in text and "[Lyra]: oi" in text and "|c" not in text
    b = g.ChatFrame1.obCopy
    assert visible(b)


def test_new_windows_get_the_look():
    rt, ns, g = preview()
    rt.execute("""
      local cf = CreateFrame("ScrollingMessageFrame", "ChatFrame3", UIParent)
      cf:SetSize(300, 150); cf:SetPoint("CENTER")
      ChatFrame3Background = cf:CreateTexture("ChatFrame3Background", "BACKGROUND")
      NUM_CHAT_WINDOWS = 3
      HOOKED.FCF_OpenNewWindow()
    """)
    assert g.ChatFrame3Background.alpha == 0 and g.ChatFrame3.obPanel is not None


def test_switched_off_leaves_the_chat_alone():
    _, ns, g = preview({"chat_on": False})
    assert g.ChatFrame1.obPanel is None and (g.ChatFrame1Background.alpha or 1) == 1


def test_panel_page():
    _, ns, g = preview()
    ns.Panel.Open("chat")
    row = next(r for r in ns.Panel.rows.values() if r.row is not None and r.row.label == "Mensagens somem depois de")
    row.control.plus.GetScript(row.control.plus, "OnClick")(row.control.plus)
    assert ns.db.chatFade == 130 and g.ChatFrame1.timeVisible == 130


def test_scroll_bar_inside_the_panel():
    _, ns, g = preview()
    p, sb = rect(g.ChatFrame1.obPanel), rect(g.ChatFrame1.ScrollBar)
    assert p[0] + p[2] >= sb[0] + sb[2] + 2


def test_other_tabs_stay_readable():
    _, ns, g = preview()
    g.HOOKED.FCFTab_UpdateColors(g.ChatFrame2Tab, False)
    assert g.ChatFrame2Tab.Text.GetTextColor(g.ChatFrame2Tab.Text)[0] >= 0.7


def test_line_between_tabs_and_messages():
    _, ns, g = preview()
    line, cf = g.ChatFrame1.obPanel.obLine, rect(g.ChatFrame1)
    assert line is not None and abs(rect(line)[1] - (cf[1] + cf[3])) <= 2
