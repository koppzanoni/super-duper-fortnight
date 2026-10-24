local _, ns = ...

-- Blizzard windows in the Moderno look. One painter for the game's window templates
-- (ButtonFrameTemplate, PortraitFrameTemplate and kin): their border, rock background, top
-- streaks and round portrait turn invisible, a black translucent panel with a thin rim goes
-- under them, the inset gets a darker box, the title turns white, the close button becomes a
-- plain "X" and the tabs flat (the selected one white with the arcane line). Windows of addons
-- the game loads later are painted when they load. Only looks change: no window is opened,
-- closed or moved from here. Achievements keep their own art.
local Skins = {}
ns.Skins = Skins

local W = ns.Widgets
local ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleBg", "Background" }
local INSETS = { "Inset", "LeftInset", "RightInset", "InsetLeft", "InsetRight", "MainInset" }

-- Windows of the game's own interface, and of the addons it loads on demand.
Skins.WINDOWS = { "CharacterFrame", "FriendsFrame", "PVEFrame", "GossipFrame", "QuestFrame", "MerchantFrame",
  "MailFrame", "DressUpFrame", "TradeFrame", "BankFrame", "AddonList", "LootFrame", "ItemTextFrame",
  "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "TaxiFrame", "QuestLogPopupDetailFrame" }
Skins.LATER = {
  Blizzard_PlayerSpells = { "PlayerSpellsFrame" }, Blizzard_Collections = { "CollectionsJournal" },
  Blizzard_EncounterJournal = { "EncounterJournal" }, Blizzard_Communities = { "CommunitiesFrame" },
  Blizzard_Professions = { "ProfessionsFrame" }, Blizzard_MacroUI = { "MacroFrame" },
  Blizzard_AuctionHouseUI = { "AuctionHouseFrame" }, Blizzard_InspectUI = { "InspectFrame" },
  Blizzard_WorldMap = { "WorldMapFrame" },
}

local function on() return not (ns.db and ns.db.skins_on == false) end
local function global(name) return rawget(_G, name) end
local function invisible(region) if region and region.SetAlpha then region:SetAlpha(0) end end

-- ------------------------------------------------------------------ pieces
local function skinInset(inset)
  if not inset or inset.obFill then return end
  invisible(rawget(inset, "NineSlice"))
  invisible(rawget(inset, "Bg"))
  inset.obFill = W.Panel(inset, 0.35)
end

local function skinClose(b)
  if not b or b.obText then return end
  for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
    local t = b[get] and b[get](b)
    invisible(t)
  end
  b.obText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.obText:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.obText:SetText("X")
  b.obText:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
  b:HookScript("OnEnter", function(self) self.obText:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3]) end)
  b:HookScript("OnLeave", function(self) self.obText:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3]) end)
end

-- A tab's look for selected or not (the game disables the selected tab).
local function colourTab(tab)
  if not tab or not tab.obFill then return end
  local selected = tab.IsEnabled and not tab:IsEnabled()
  local text = rawget(tab, "Text") or (tab.GetFontString and tab:GetFontString())
  local c = selected and W.WHITE or W.DIM
  if text then text:SetTextColor(c[1], c[2], c[3]) end
  tab.obFill:SetColorTexture(selected and 1 or 0, selected and 1 or 0, selected and 1 or 0, selected and 0.1 or 0.35)
  tab.obLine:SetShown(selected and true or false)
end

local function skinTab(tab)
  if not tab or tab.obFill then return end
  for _, t in ipairs(rawget(tab, "TabTextures") or {}) do invisible(t) end
  for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do invisible(rawget(tab, k)) end
  tab.obFill = W.Panel(tab, 0.35)
  tab.obLine = tab:CreateTexture(nil, "ARTWORK")
  tab.obLine:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 1)
  tab.obLine:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 1)
  tab.obLine:SetHeight(2)
  tab.obLine:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 0.9)
  colourTab(tab)
end

-- ------------------------------------------------------------------ one window
function Skins.Window(f)
  if not f or f.obFill then return end
  for _, k in ipairs(ART) do invisible(rawget(f, k)) end
  f.obFill = W.Panel(f, 0.92)
  local title = rawget(f, "TitleContainer")
  local titleText = (title and rawget(title, "TitleText")) or rawget(f, "TitleText")
  if titleText then titleText:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3]) end
  skinClose(rawget(f, "CloseButton"))
  for _, k in ipairs(INSETS) do skinInset(rawget(f, k)) end
  for _, tab in ipairs(rawget(f, "Tabs") or {}) do skinTab(tab) end
  -- the world map paints its frame on a child
  local border = rawget(f, "BorderFrame")
  if border then Skins.Window(border) end
end

local function paint(list)
  for _, name in ipairs(list) do
    -- one broken window must not stop the others
    pcall(Skins.Window, global(name))
  end
end

ns.On("PLAYER_LOGIN", function()
  if not on() then return end
  paint(Skins.WINDOWS)
  for addon, list in pairs(Skins.LATER) do
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) then paint(list) end
  end
  for _, name in ipairs({ "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab" }) do
    if type(global(name)) == "function" then hooksecurefunc(name, colourTab) end
  end
end)
ns.On("ADDON_LOADED", function(_, addon)
  local list = on() and Skins.LATER[addon]
  if list then paint(list) end
end)
