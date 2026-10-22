local _, ns = ...

-- Bag grid inside the inventory window: one grid of 8 columns for all bags, filter tabs,
-- inner scrolling, equipped bag slots and gold in the footer. Replaces the default bag frames.
local S = ns.Data.INV
local M = ns.MediaManifest
local Inventory = ns.Inventory
local frame = Inventory.frame
local COLS = 8
local BAGS = { 0, 1, 2, 3, 4, 5 }

local scroll = CreateFrame("ScrollFrame", "ObsidianUIBagScroll", Inventory.gridArea, "UIPanelScrollFrameTemplate")
scroll:SetAllPoints(Inventory.gridArea)
local child = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(child)

local bagFrames, buttons = {}, {}
for _, bag in ipairs(BAGS) do
  local f = CreateFrame("Frame", "ObsidianUIBag" .. bag, child)
  f:SetID(bag)
  f:SetAllPoints(child)
  bagFrames[bag] = f
  buttons[bag] = {}
end

local activeTab = "all"
local unit = 1 -- screen units per texture pixel, set on layout

local function newButton(bag, slot)
  local name = "ObsidianUIBag" .. bag .. "Slot" .. slot
  local ok, b = pcall(CreateFrame, "ItemButton", name, bagFrames[bag], "ContainerFrameItemButtonTemplate")
  if not ok then b = CreateFrame("Button", name, bagFrames[bag], "ContainerFrameItemButtonTemplate") end
  b:SetID(slot)
  b.obBorder = b:CreateTexture(nil, "OVERLAY", nil, 7)
  b.obBorder:SetAllPoints(b)
  b.obBorder:SetTexture(M.aura_border.file)
  local normal = b.GetNormalTexture and b:GetNormalTexture()
  if normal then normal:SetAlpha(0) end
  b:Hide()
  buttons[bag][slot] = b
  return b
end

local function ensureButtons()
  for _, bag in ipairs(BAGS) do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      if not buttons[bag][slot] then newButton(bag, slot) end
    end
  end
end

local function refreshButton(b, bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  SetItemButtonTexture(b, info and info.iconFileID or nil)
  SetItemButtonCount(b, info and info.stackCount or 0)
  if SetItemButtonDesaturated then SetItemButtonDesaturated(b, info and info.isLocked) end
  local q = info and info.quality
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c and q > 0 then b.obBorder:SetVertexColor(c.r, c.g, c.b); b.obBorder:Show()
  elseif info then b.obBorder:SetVertexColor(0.62, 0.62, 0.62); b.obBorder:Show()
  else b.obBorder:Hide() end
end

local function collectSlots()
  local list = {}
  for _, bag in ipairs(BAGS) do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, n do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local classID
      if info and info.itemID then classID = select(6, C_Item.GetItemInfoInstant(info.itemID)) end
      list[#list + 1] = { bag = bag, slot = slot, classID = classID or (info and 15) or nil }
    end
  end
  return list
end

local function relayout()
  ensureButtons()
  local pitchX = (S.gridCols[2] - S.gridCols[1]) * unit
  local pitchY = S.gridPitchY * unit
  local size = S.gridSlot * unit
  for _, bag in ipairs(BAGS) do
    for _, b in pairs(buttons[bag]) do b:Hide() end
  end
  local visible = ns.GridModel.Build(collectSlots(), activeTab)
  for index, s in ipairs(visible) do
    local b = buttons[s.bag][s.slot]
    if b then
      local col, row = ns.GridModel.Pos(index, COLS)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", child, "TOPLEFT", (col - 1) * pitchX, -(row - 1) * pitchY)
      b:SetSize(size, size)
      refreshButton(b, s.bag, s.slot)
      b:Show()
    end
  end
  child:SetSize(Inventory.gridArea:GetWidth(), ns.GridModel.Rows(#visible, COLS) * pitchY)
end

local function refreshVisuals()
  for _, bag in ipairs(BAGS) do
    for slot, b in pairs(buttons[bag]) do
      if b:IsShown() then refreshButton(b, bag, slot) end
    end
  end
end

-- Filter tabs.
local tabs = {}
local function setTab(tab)
  activeTab = tab
  for _, t in ipairs(tabs) do
    if t.tab == tab then t.text:SetTextColor(1, 0.82, 0) else t.text:SetTextColor(0.73, 0.68, 0.58) end
  end
  ns.RunOutOfCombat(relayout)
end
for i, tab in ipairs(ns.Filters.TABS) do
  local t = CreateFrame("Button", nil, frame)
  t.tab = tab
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.text:SetAllPoints(t)
  t.text:SetText(ns.Filters.LABELS[tab])
  t:SetScript("OnClick", function() setTab(tab) end)
  tabs[i] = t
end

-- Footer: equipped bags (drop a bag here to equip it) and gold.
local footerBags = {}
for i = 1, 5 do
  local bag = i - 1
  local b = CreateFrame("Button", nil, frame)
  b.bag = bag
  if bag > 0 then b.invSlot = C_Container.ContainerIDToInventoryID(bag) end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 4, -4)
  b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  b:SetScript("OnReceiveDrag", function(self)
    if self.bag == 0 then PutItemInBackpack() else PutItemInBag(self.invSlot) end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.invSlot then GameTooltip:SetInventoryItem("player", self.invSlot) else GameTooltip:SetText("Mochila") end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  footerBags[i] = b
end
local gold = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

local function updateFooter()
  for _, b in ipairs(footerBags) do
    local tex = b.bag == 0 and "Interface\\Buttons\\Button-Backpack-Up" or GetInventoryItemTexture("player", b.invSlot)
    b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
  end
  gold:SetText(GetMoneyString(GetMoney(), true))
end

local function place(region, x, y, w, h)
  local fw, fh = frame:GetSize()
  local rx, ry, rw, rh = ns.Layout.Rect(S.w, S.h, fw, fh, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", rx, ry)
  region:SetSize(rw, rh)
end

Inventory.onLayout = function()
  unit = frame:GetWidth() / S.w
  for i, t in ipairs(tabs) do place(t, S.tabs[i], S.tabY, S.tabW, S.tabH) end
  for i, b in ipairs(footerBags) do place(b, S.bags[i], S.bagY, S.bagW, S.bagH) end
  place(gold, S.gold.x, S.gold.y, S.gold.w, S.gold.h)
end
Inventory.onOpen = function()
  setTab(activeTab)
  updateFooter()
end

ns.On("BAG_UPDATE_DELAYED", function()
  if not frame:IsShown() then return end
  refreshVisuals()
  ns.RunOutOfCombat(relayout)
  updateFooter()
end)
ns.On("ITEM_LOCK_CHANGED", function() if frame:IsShown() then refreshVisuals() end end)
ns.On("PLAYER_MONEY", function() if frame:IsShown() then updateFooter() end end)
ns.On("PLAYER_LOGIN", function() ns.RunOutOfCombat(ensureButtons) end)

-- Default bag frames stay hidden; every bag toggle opens/closes this window instead.
-- Toggle functions call Open/Close internally, so ignore a second action in the same instant.
local last = 0
local function guarded(fn)
  return function()
    local now = GetTime()
    if now - last < 0.05 then return end
    last = now
    fn()
  end
end
for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
  if _G[name] then hooksecurefunc(name, guarded(Inventory.Toggle)) end
end
for _, name in ipairs({ "OpenAllBags", "OpenBackpack" }) do
  if _G[name] then hooksecurefunc(name, guarded(Inventory.Open)) end
end
for _, name in ipairs({ "CloseAllBags", "CloseBackpack" }) do
  if _G[name] then hooksecurefunc(name, guarded(Inventory.Close)) end
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES.combinedbags)))
    for i = 1, 13 do
      local f = _G["ContainerFrame" .. i]
      if f then f:SetParent(ns.hiddenParent) end
    end
  end)
end)
