local _, ns = ...

-- Chat in the Moderno look: each chat window sits on a black translucent panel with a thin rim
-- (the game's border and background turn invisible), flat tabs with the selected one in white,
-- the edit box on its own panel right under the chat, the side buttons hidden (menu, channels,
-- quick join, the scroll button column), messages fading after a chosen time, and a copy button
-- that lists the window's lines as plain text. Only looks change: no chat setting is touched.
-- Switched off, the chat stays as the game draws it (after a reload when it was on).
local Chat = {}
ns.Chat = Chat

local W = ns.Widgets
local BORDER = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
  "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
local TAB_ART = { "Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft",
  "HighlightMiddle", "HighlightRight" }
local EDIT_ART = { "Left", "Right", "Mid", "FocusLeft", "FocusRight", "FocusMid" }
local BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
  "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }
local PAD, TAB_ROOM = 6, 28
local COPY_ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end

-- Globals read with rawget: a missing one stays nil.
local function global(name) return name and rawget(_G, name) end

local function invisible(region)
  if region and region.SetAlpha then region:SetAlpha(0) end
end

-- ------------------------------------------------------------------ copy box
local box = CreateFrame("Frame", "ObsidianUIChatCopy", UIParent)
box:SetSize(560, 360)
box:SetPoint("CENTER")
box:SetFrameStrata("DIALOG")
box:EnableMouse(true)
box:Hide()
W.Panel(box, 0.95)
Chat.copyBox = box
table.insert(UISpecialFrames, "ObsidianUIChatCopy")
local boxTitle = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
boxTitle:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
boxTitle:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
boxTitle:SetText("Copiar o chat (Ctrl+C)")
local scroll = CreateFrame("ScrollFrame", "ObsidianUIChatCopyScroll", box, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -36)
scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -32, 14)
local edit = CreateFrame("EditBox", nil, scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject("ChatFontNormal")
edit:SetWidth(510)
edit:SetScript("OnEscapePressed", function() box:Hide() end)
scroll:SetScrollChild(edit)
box.edit = edit
local close = W.Button(box, "X", function() box:Hide() end)
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)

-- Links and colour codes out, the visible text kept: "|Hplayer:x|h[Lyra]|h" -> "[Lyra]".
local function plain(text)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
  return text
end

function Chat.Copy(cf)
  local lines = {}
  for i = 1, cf:GetNumMessages() do
    -- a line the game keeps from addons (secret) is left out
    local ok, text = pcall(function()
      local t = cf:GetMessageInfo(i)
      if issecretvalue and issecretvalue(t) then return nil end
      return t and plain(t)
    end)
    if ok and text then lines[#lines + 1] = text end
  end
  edit:SetText(table.concat(lines, "\n"))
  box:Show()
  edit:SetFocus()
  edit:HighlightText()
end

-- ------------------------------------------------------------------ one window
local function skinTab(tab)
  if not tab or tab.obSkinned then return end
  tab.obSkinned = true
  for _, k in ipairs(TAB_ART) do invisible(rawget(tab, k)) end
  tab.obLine = tab:CreateTexture(nil, "ARTWORK")
  tab.obLine:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 6, 2)
  tab.obLine:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, 2)
  tab.obLine:SetHeight(2)
  tab.obLine:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.9)
  tab.obLine:Hide()
end

-- Selected tab: white text and the arcane line under it; the others dim.
-- The game fades the other tabs to a fifth when the mouse is away: their text stays light.
local function colourTab(tab, selected)
  if not tab or not tab.obSkinned then return end
  local text = rawget(tab, "Text") or (tab.GetFontString and tab:GetFontString())
  local c = selected and W.WHITE or W.TEXT
  if text then text:SetTextColor(c[1], c[2], c[3]) end
  tab.obLine:SetShown(selected and true or false)
end

local function skinEditBox(cf, eb)
  if not eb or eb.obPanel then return end
  local name = eb:GetName()
  for _, k in ipairs(EDIT_ART) do invisible(global(name and name .. k)) end
  eb.obPanel = CreateFrame("Frame", nil, eb)
  eb.obPanel:SetAllPoints(eb)
  eb.obPanel:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
  W.Panel(eb.obPanel, 0.85)
  -- right under the chat's panel, as wide as it
  local function place(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", cf.obPanel, "BOTTOMLEFT", 0, -4)
    f:SetPoint("TOPRIGHT", cf.obPanel, "BOTTOMRIGHT", 0, -4)
  end
  place(eb)
  if ns.Pin then ns.Pin(eb, place) end
end

local function skin(cf)
  if not cf or cf.obPanel then return end
  local name = cf:GetName()
  for _, k in ipairs(BORDER) do invisible(global(name and name .. k)) end
  -- the panel takes the tabs in too, like one piece, and the scroll bar the game puts right of
  -- the messages
  local bar = rawget(cf, "ScrollBar")
  local barW = bar and bar.GetWidth and bar:GetWidth() or 0
  if type(barW) ~= "number" then barW = 0 end
  local panel = CreateFrame("Frame", nil, cf)
  panel:SetPoint("TOPLEFT", cf, "TOPLEFT", -PAD, PAD + TAB_ROOM)
  panel:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", PAD + (barW > 0 and barW + 2 or 0), -PAD)
  panel:SetFrameStrata("BACKGROUND")
  W.Panel(panel, 0.6)
  cf.obPanel = panel
  -- a hairline under the tabs: the top message, cut by the scroll, reads as scrolled away
  local r, g, b = W.Rim()
  panel.obLine = panel:CreateTexture(nil, "BORDER")
  panel.obLine:SetColorTexture(r, g, b, 0.18)
  panel.obLine:SetHeight(1)
  panel.obLine:SetPoint("TOPLEFT", cf, "TOPLEFT", -PAD, 1)
  panel.obLine:SetPoint("TOPRIGHT", cf, "TOPRIGHT", PAD + (barW > 0 and barW + 2 or 0), 1)
  local copy = CreateFrame("Button", nil, panel)
  copy:SetSize(16, 16)
  copy:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
  copy:SetFrameStrata("MEDIUM")
  copy.icon = copy:CreateTexture(nil, "ARTWORK")
  copy.icon:SetAllPoints(copy)
  copy.icon:SetTexture(COPY_ICON)
  copy.icon:SetVertexColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
  copy:SetScript("OnClick", function() Chat.Copy(cf) end)
  copy:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Copiar o chat")
    GameTooltip:Show()
  end)
  copy:SetScript("OnLeave", GameTooltip_Hide)
  cf.obCopy = copy
  skinTab(global(name and name .. "Tab"))
  skinEditBox(cf, rawget(cf, "editBox") or global(name and name .. "EditBox"))
end

-- ------------------------------------------------------------------ all windows
local function eachWindow(fn)
  local count = global("NUM_CHAT_WINDOWS")
  for i = 1, type(count) == "number" and count or 10 do
    local cf = global("ChatFrame" .. i)
    if cf then fn(cf, i) end
  end
end

-- Settings that can change live: fading and the side buttons.
function Chat.Apply()
  if not on("chat_on") then return end
  local fade = db().chatFade or 120
  eachWindow(function(cf, i)
    skin(cf)
    local selected = global("SELECTED_CHAT_FRAME")
    colourTab(global("ChatFrame" .. i .. "Tab"), cf == selected or (i == 1 and selected == nil))
    if cf.SetFading then cf:SetFading(fade > 0) end
    if fade > 0 and cf.SetTimeVisible then cf:SetTimeVisible(fade) end
    local buttons = rawget(cf, "buttonFrame")
    if buttons then buttons:SetShown(db().chatButtons == true) end
  end)
  for _, n in ipairs(BUTTONS) do
    local b = global(n)
    if b and b.SetShown and not (InCombatLockdown() and b:IsProtected()) then b:SetShown(db().chatButtons == true) end
  end
end

ns.On("PLAYER_LOGIN", function()
  if not on("chat_on") then return end
  Chat.Apply()
  local function hook(name, fn) if type(global(name)) == "function" then hooksecurefunc(name, fn) end end
  hook("FCFTab_UpdateColors", colourTab)
  -- windows opened later (new tabs, whispers in their own window) get the look too
  hook("FCF_OpenNewWindow", Chat.Apply)
  hook("FCF_OpenTemporaryWindow", Chat.Apply)
end)
ns.On("UPDATE_CHAT_WINDOWS", Chat.Apply)
