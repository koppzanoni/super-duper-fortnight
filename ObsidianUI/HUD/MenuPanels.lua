local _, ns = ...

-- 3x3 menu panels beside the orbs (spec 4.4). Left: game windows via Blizzard's micro buttons
-- (secure "click" so protected panels still open). Right: bags, then social / LFG / PvP.
local D = ns.Data.HUD
local HUD = ns.HUD
local M = ns.MediaManifest
local GOLD = { 0.91, 0.77, 0.42 }
local MenuPanels = { buttons = {} }
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

-- Hover glow, and the icon sinks and dims while the button is held down.
local function pressFeedback(b, icon)
  b.obPress = true
  local glow = b:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(b)
  glow:SetColorTexture(1, 0.85, 0.5, 0.12)
  b:HookScript("OnMouseDown", function()
    setInset(icon, b, INSET + 2)
    icon:SetAlpha(0.7)
  end)
  b:HookScript("OnMouseUp", function()
    setInset(icon, b, INSET)
    icon:SetAlpha(1)
  end)
  MenuPanels.buttons[#MenuPanels.buttons + 1] = b
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
  return b
end

-- The game menu micro button opens the menu only when the mouse is over it (its OnClick checks
-- IsMouseOver), so a proxy click does nothing: the real button moves into the slot instead,
-- with its own art hidden under our icon.
local MICRO_ART = { "MainMenuBarPerformanceBar", "Background", "PushedBackground", "FlashBorder", "FlashContent",
  "NotificationOverlay" }
local function realMicroButton(entry, x, y, w, h)
  local micro = ns.Resolve.First(entry.candidates)
  if not micro then return end
  local slot = CreateFrame("Frame", nil, HUD.over)
  HUD.Place(slot, x, y, w, h)
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
  for i, entry in ipairs(ns.Data.MENU_LEFT) do
    local r, c = math.floor((i - 1) / 3) + 1, (i - 1) % 3 + 1
    local x, y, w, h = D.menuCols[c], D.menuRows[r], D.menuSlot.w, D.menuSlot.h
    if entry.id == "gamemenu" then
      realMicroButton(entry, x, y, w, h)
    else
      local b = entry.id == "character" and characterButton(entry) or microButton(entry)
      HUD.Place(b, x, y, w, h)
    end
  end
  for i, entry in ipairs(ns.Data.MENU_RIGHT) do
    local r, c = math.floor((i - 1) / 3) + 1, (i - 1) % 3 + 1
    local b = entry.bag and bagButton(entry) or microButton(entry)
    -- Right panel is the mirror of the left one; keep reading order left to right.
    HUD.Place(b, ns.Layout.MirrorX(D.width, D.menuCols[4 - c], D.menuSlot.w), D.menuRows[r], D.menuSlot.w, D.menuSlot.h)
  end
  updateBagIcons()
end

ns.On("PLAYER_LOGIN", function() ns.RunOutOfCombat(build) end)
ns.On("BAG_UPDATE_DELAYED", updateBagIcons)
ns.On("PLAYER_EQUIPMENT_CHANGED", updateBagIcons)
ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit)
  if unit == "player" and portraitIcon then SetPortraitTexture(portraitIcon, "player") end
end)
ns.On("PLAYER_ENTERING_WORLD", function() if portraitIcon then SetPortraitTexture(portraitIcon, "player") end end)
