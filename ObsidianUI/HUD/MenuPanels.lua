local _, ns = ...

-- Menu buttons: game windows via Blizzard's micro buttons (secure "click" so protected panels
-- still open), the bags and the character window. The Moderno row (Data.MODERN_MENU) shows them.
local HUD = ns.HUD
local M = ns.MediaManifest
local GOLD = { 0.91, 0.77, 0.42 }
local MenuPanels = { buttons = {}, byId = {} }
ns.MenuPanels = MenuPanels

local function toggleInventory()
  if ns.Inventory and ns.Inventory.Toggle then ns.Inventory.Toggle() else ToggleAllBags() end
end

local function tooltip(button, text)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.invSlot then GameTooltip:SetInventoryItem("player", self.invSlot) else GameTooltip:SetText(text) end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

local INSET = 3
local function setInset(icon, button, inset)
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function iconOf(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  setInset(icon, button, INSET)
  return icon
end

-- Active look while the button's window is open: icon slightly sunk, gold frame and glow.
local function setActive(b, on)
  b.obActive = on
  b.obActiveArt:SetShown(on)
  setInset(b.obIcon, b, on and INSET + 1 or INSET)
end

-- Hover glow; the icon sinks and dims while the button is held down.
local function pressFeedback(b, icon)
  b.obPress, b.obIcon, b.obActive, b.obInventory, b.obMicro = true, icon, false, false, false
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(b)
  glow:SetColorTexture(1, 0.85, 0.5, 0.12)
  local active = CreateFrame("Frame", nil, b)
  active:SetAllPoints(b)
  active:SetFrameLevel(b:GetFrameLevel() + 2)
  local fill = active:CreateTexture(nil, "ARTWORK")
  fill:SetAllPoints(active)
  fill:SetColorTexture(1, 0.8, 0.4, 0.14)
  local frame = active:CreateTexture(nil, "OVERLAY")
  frame:SetAllPoints(active)
  frame:SetTexture(M.aura_border.file)
  frame:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
  b.obActiveArt = active
  active:Hide()
  b:HookScript("OnMouseDown", function()
    setInset(icon, b, INSET + 2)
    icon:SetAlpha(0.7)
  end)
  b:HookScript("OnMouseUp", function()
    setInset(icon, b, b.obActive and INSET + 1 or INSET)
    icon:SetAlpha(1)
  end)
  MenuPanels.buttons[#MenuPanels.buttons + 1] = b
end

-- Mirror the micro button's pushed state: Blizzard pushes it while its window is open.
local function followMicro(b, micro)
  b.obMicro = micro
  if type(micro.SetPushed) == "function" then
    hooksecurefunc(micro, "SetPushed", function() setActive(b, true) end)
  end
  if type(micro.SetNormal) == "function" then
    hooksecurefunc(micro, "SetNormal", function() setActive(b, false) end)
  end
  if type(micro.GetButtonState) == "function" then setActive(b, micro:GetButtonState() == "PUSHED") end
end

local function goldIcon(icon)
  icon:SetDesaturated(true)
  icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
end

local function copyMicroIcon(icon, micro)
  local normal = micro.GetNormalTexture and micro:GetNormalTexture()
  if not normal then return end
  local atlas = normal.GetAtlas and normal:GetAtlas()
  if atlas then icon:SetAtlas(atlas) else icon:SetTexture(normal:GetTexture()); icon:SetTexCoord(normal:GetTexCoord()) end
  goldIcon(icon)
end

local function setIcon(icon, entry, micro)
  if entry.icon then
    icon:SetTexture(entry.icon)
    goldIcon(icon)
  elseif micro then
    copyMicroIcon(icon, micro)
  end
end

local function microButton(entry)
  local micro = ns.Resolve.First(entry.candidates)
  local b = CreateFrame("Button", nil, HUD.over, "SecureActionButtonTemplate")
  -- Secure buttons fire on the edge chosen by the ActionButtonUseKeyDown CVar (on by default):
  -- registered for "AnyUp" only, they never fired.
  b:RegisterForClicks("AnyUp", "AnyDown")
  local icon = iconOf(b)
  if micro then
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", micro)
  elseif not entry.icon then
    b:Hide()
  end
  setIcon(icon, entry, micro)
  tooltip(b, entry.label)
  pressFeedback(b, icon)
  if micro then followMicro(b, micro) end
  return b
end

-- The game menu micro button opens the menu only when the mouse is over it (its OnClick checks
-- IsMouseOver), so a proxy click does nothing: the real button moves into the slot instead,
-- with its own art hidden under our icon.
local MICRO_ART = { "MainMenuBarPerformanceBar", "Background", "PushedBackground", "FlashBorder", "FlashContent",
  "NotificationOverlay" }
local function realMicroButton(entry)
  local micro = ns.Resolve.First(entry.candidates)
  if not micro then return end
  local slot = CreateFrame("Frame", nil, HUD.over)
  local icon = micro:CreateTexture(nil, "OVERLAY", nil, 7)
  setInset(icon, micro, INSET)
  setIcon(icon, entry, micro)
  for _, t in ipairs({ micro:GetNormalTexture(), micro:GetPushedTexture(), micro:GetHighlightTexture(),
    micro:GetDisabledTexture() }) do
    if t then t:SetAlpha(0) end
  end
  for _, key in ipairs(MICRO_ART) do
    local region = micro[key]
    if region and region.SetAlpha then region:SetAlpha(0) end
  end
  micro:SetParent(HUD.over)
  micro:SetFrameLevel(HUD.over:GetFrameLevel() + 3)
  ns.Pin(micro, function(f)
    f:ClearAllPoints()
    f:SetAllPoints(slot)
  end)
  micro:Show()
  pressFeedback(micro, icon)
  followMicro(micro, micro)
  return slot
end

-- Character: the player's portrait in a circle, like the default micro button.
local portraitIcon
local function characterButton(entry)
  local b = CreateFrame("Button", nil, HUD.over)
  local icon = iconOf(b)
  local mask = b:CreateMaskTexture()
  mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(icon)
  icon:AddMaskTexture(mask)
  SetPortraitTexture(icon, "player")
  portraitIcon = icon
  b:SetScript("OnClick", toggleInventory)
  tooltip(b, entry.label)
  pressFeedback(b, icon)
  b.obInventory = true
  return b
end

local bagButtons = {}

local function bagButton(entry)
  local b = CreateFrame("Button", nil, HUD.over)
  b.bag = entry.bag
  b.icon = iconOf(b)
  if entry.bag > 0 then b.invSlot = C_Container.ContainerIDToInventoryID(entry.bag) end
  b:SetScript("OnClick", toggleInventory)
  b:SetScript("OnReceiveDrag", function(self)
    if self.bag == 0 then PutItemInBackpack() else PutItemInBag(self.invSlot) end
  end)
  tooltip(b, entry.label)
  pressFeedback(b, b.icon)
  b.obInventory = true
  bagButtons[#bagButtons + 1] = b
  return b
end

local function updateBagIcons()
  for _, b in ipairs(bagButtons) do
    local tex = b.bag == 0 and "Interface\\Buttons\\Button-Backpack-Up" or GetInventoryItemTexture("player", b.invSlot)
    b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
  end
end

local function build()
  for _, entry in ipairs(ns.Data.MENU_LEFT) do
    if entry.id == "gamemenu" then
      MenuPanels.byId[entry.id] = realMicroButton(entry)
    else
      MenuPanels.byId[entry.id] = entry.id == "character" and characterButton(entry) or microButton(entry)
    end
  end
  for _, entry in ipairs(ns.Data.MENU_RIGHT) do
    MenuPanels.byId[entry.id] = entry.bag and bagButton(entry) or microButton(entry)
  end
  updateBagIcons()
  MenuPanels.LayoutModern()

  -- Character and bag buttons are active while the inventory window is open.
  local inv = ns.Inventory and ns.Inventory.frame
  if inv then
    local function follow(open)
      for _, b in ipairs(MenuPanels.buttons) do
        if b.obInventory then setActive(b, open) end
      end
    end
    inv:HookScript("OnShow", function() follow(true) end)
    inv:HookScript("OnHide", function() follow(false) end)
  end
end

-- Moderno: one row of buttons on a dark band at the bottom right (its rounded ends at their own
-- size, the plain middle stretched), the money beside it. Light grey icons.
local band = CreateFrame("Frame", "ObsidianUIModernMenu", UIParent)
band:SetFrameStrata("LOW")
band:Hide()
local bandLeft, bandMid = band:CreateTexture(nil, "BACKGROUND"), band:CreateTexture(nil, "BACKGROUND")
-- the right end closes with the left cap mirrored, instead of the stretched middle stopping short
local bandRight = band:CreateTexture(nil, "BACKGROUND")
MenuPanels.band, MenuPanels.bandFrame, MenuPanels.bandRight = bandMid, band, bandRight
local money = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
local MENU_W, MENU_H, CAP = 620, 92, 40 -- mod_menu texture px; CAP: the rounded left end

local function updateMoney()
  if not pcall(function() money:SetText(GetMoneyString(GetMoney(), true)) end) then money:SetText("") end
end

-- The band's visible edges inside its frame (l, t, r, b px), for pieces lined up with it.
function MenuPanels.BandEdges()
  return ns.Layout.Edges(ns.Data.ART_EDGE.menu, MENU_W, band:GetHeight() * MENU_W / MENU_H)
end

function MenuPanels.LayoutModern()
  if not next(MenuPanels.byId) then return end
  local _, H = UIParent:GetSize()
  local s = H / 1080 * (ns.db.scale or 1) * ns.Movers.Scale("menu")
  local list = ns.Data.MODERN_MENU
  local size, step, k = 28 * s, 34 * s, 0.5 * s
  local w = (2 * CAP + 8) * k + #list * step
  band:SetSize(w, MENU_H * k)
  ns.Movers.Register("menu", "Menu", band, function(f)
    f:ClearAllPoints()
    -- the band's visible right end and foot at the screen margin
    local _, _, r, b = MenuPanels.BandEdges()
    local m = ns.Layout.MARGIN * H / 1080
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(m - r), m - b)
  end, { ownScale = true })
  ns.Movers.Place("menu")
  local tex = ns.ModernTex("mod_menu")
  bandLeft:ClearAllPoints()
  bandLeft:SetPoint("TOPLEFT", band, "TOPLEFT")
  bandLeft:SetSize(CAP * k, MENU_H * k)
  ns.Media.ApplyRange(bandLeft, tex, false, 0, CAP / MENU_W)
  bandMid:ClearAllPoints()
  bandRight:ClearAllPoints()
  bandRight:SetPoint("TOPRIGHT", band, "TOPRIGHT")
  bandRight:SetSize(CAP * k, MENU_H * k)
  ns.Media.ApplyRange(bandRight, tex, true, 0, CAP / MENU_W)
  bandMid:SetPoint("TOPLEFT", bandLeft, "TOPRIGHT")
  bandMid:SetPoint("BOTTOMRIGHT", bandRight, "BOTTOMLEFT")
  ns.Media.ApplyRange(bandMid, tex, false, CAP / MENU_W, 1 - CAP / MENU_W)
  band:Show()
  local wanted = {}
  local pad = (w - #list * step) / 2 -- the row centred in the band
  for i, id in ipairs(list) do
    wanted[id] = true
    local b = MenuPanels.byId[id]
    if b then
      b:ClearAllPoints()
      b:SetPoint("LEFT", band, "LEFT", pad + (i - 1) * step + (step - size) / 2, 0)
      b:SetSize(size, size)
      if b.obIcon and id ~= "character" then b.obIcon:SetVertexColor(0.86, 0.87, 0.89) end
      b:Show()
    end
  end
  for id, b in pairs(MenuPanels.byId) do
    if not wanted[id] then b:Hide() end
  end
  -- the money left of the band, one grid gap from its visible end (under it, the band would push
  -- it off the screen now that the band keeps the screen margin)
  local bl = MenuPanels.BandEdges()
  money:ClearAllPoints()
  money:SetPoint("RIGHT", band, "LEFT", bl - ns.Layout.GAP * H / 1080, 0)
  money:SetJustifyH("RIGHT")
  ns.Look.SetType(money, "label", s)
  -- the info bar lines up with the band: place it again now that the band has its size
  if ns.Movers.items.info then ns.Movers.Place("info") end
  updateMoney()
end
table.insert(HUD.onResize, function() ns.RunOutOfCombat(MenuPanels.LayoutModern) end)
ns.On("PLAYER_MONEY", updateMoney)

ns.On("PLAYER_LOGIN", function() ns.RunOutOfCombat(build) end)
ns.On("BAG_UPDATE_DELAYED", updateBagIcons)
ns.On("PLAYER_EQUIPMENT_CHANGED", updateBagIcons)
ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit)
  if unit == "player" and portraitIcon then SetPortraitTexture(portraitIcon, "player") end
end)
ns.On("PLAYER_ENTERING_WORLD", function() if portraitIcon then SetPortraitTexture(portraitIcon, "player") end end)
