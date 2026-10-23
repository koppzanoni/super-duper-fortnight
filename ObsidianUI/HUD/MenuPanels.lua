local _, ns = ...

-- 3x3 menu panels beside the orbs (spec 4.4). Left: game windows via Blizzard's micro buttons
-- (secure "click" so protected panels still open). Right: bags, then social / LFG / PvP.
local D = ns.Data.HUD
local HUD = ns.HUD
local GOLD = { 0.91, 0.77, 0.42 }

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

local function iconOf(button)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", -3, 3)
  return icon
end

local function copyMicroIcon(icon, micro)
  local normal = micro.GetNormalTexture and micro:GetNormalTexture()
  if not normal then return end
  local atlas = normal.GetAtlas and normal:GetAtlas()
  if atlas then icon:SetAtlas(atlas) else icon:SetTexture(normal:GetTexture()); icon:SetTexCoord(normal:GetTexCoord()) end
  icon:SetDesaturated(true)
  icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
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
    copyMicroIcon(icon, micro)
  else
    b:Hide()
  end
  tooltip(b, entry.label)
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
    local b
    if entry.id == "character" then
      b = CreateFrame("Button", nil, HUD.over)
      local icon = iconOf(b)
      local micro = ns.Resolve.First(entry.candidates)
      if micro then copyMicroIcon(icon, micro) end
      b:SetScript("OnClick", toggleInventory)
      tooltip(b, entry.label)
    else
      b = microButton(entry)
    end
    HUD.Place(b, D.menuCols[c], D.menuRows[r], D.menuSlot.w, D.menuSlot.h)
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
