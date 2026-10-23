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
local searchText = ""
local unit = 1 -- screen units per texture pixel, set on layout

local function newButton(bag, slot)
  local name = "ObsidianUIBag" .. bag .. "Slot" .. slot
  local ok, b = pcall(CreateFrame, "ItemButton", name, bagFrames[bag], "ContainerFrameItemButtonTemplate")
  if not ok then b = CreateFrame("Button", name, bagFrames[bag], "ContainerFrameItemButtonTemplate") end
  b:SetID(slot)
  b.Cooldown = b.Cooldown or _G[name .. "Cooldown"]
  b.IconQuestTexture = b.IconQuestTexture or _G[name .. "IconQuestTexture"]
  -- The slot frame scrolls with the button (the window art has no slots in the grid area).
  b.obSlot = b:CreateTexture(nil, "BACKGROUND", nil, -8)
  b.obSlot:SetTexture(M.bag_slot.file)
  b.obSlot:SetTexCoord(0, M.bag_slot.w / M.bag_slot.potW, 0, M.bag_slot.h / M.bag_slot.potH)
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

local SEARCH_ICON = "Interface\\Common\\UI-Searchbox-Icon"
local QUEST_BANG = "Interface\\ContainerFrame\\UI-Icon-QuestBang"
local QUEST_BORDER = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"

local function itemName(info)
  return info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
end

-- The game's own search (SetItemSearch) flags items; older clients get a name match.
local function filteredOut(info)
  if not info or searchText == "" then return false end
  if C_Container.SetItemSearch then return info.isFiltered == true end
  return not ns.Filters.MatchesSearch(searchText, itemName(info))
end

-- Overlays the template has but only Blizzard's bag code fills: cooldown, quest, new, junk.
local function setMarkers(b, bag, slot, info)
  local quest = info and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
  local isNew = info and C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot)
  local m = ns.Filters.Markers(info, quest, isNew)
  if b.JunkIcon then b.JunkIcon:SetShown(m.junk) end
  local qt = b.IconQuestTexture
  if qt then
    if m.questStarter then qt:SetTexture(QUEST_BANG); qt:Show()
    elseif m.quest then qt:SetTexture(QUEST_BORDER); qt:Show()
    else qt:Hide() end
  end
  if b.NewItemTexture then
    if m.new then b.NewItemTexture:SetAtlas("bags-glow-white"); b.NewItemTexture:Show() else b.NewItemTexture:Hide() end
  end
  if b.BattlepayItemTexture then b.BattlepayItemTexture:Hide() end
  local cd = b.Cooldown
  if cd then
    if info and C_Container.GetContainerItemCooldown and CooldownFrame_Set then
      pcall(function() CooldownFrame_Set(cd, C_Container.GetContainerItemCooldown(bag, slot)) end)
    else
      cd:Hide()
    end
  end
end

local function refreshButton(b, bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  setMarkers(b, bag, slot, info)
  b:SetAlpha(filteredOut(info) and 0.25 or 1)
  SetItemButtonTexture(b, info and info.iconFileID or nil)
  -- Empty slot: no Blizzard "empty" picture over our frame.
  local icon = b.icon or _G[b:GetName() .. "IconTexture"]
  if icon and not info then icon:Hide() end
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
      local F = S.gridFrame
      b.obSlot:ClearAllPoints()
      b.obSlot:SetPoint("TOPLEFT", b, "TOPLEFT", F.dx * unit, -F.dy * unit)
      b.obSlot:SetSize(F.w * unit, F.h * unit)
      refreshButton(b, s.bag, s.slot)
      b:Show()
    end
  end
  child:SetSize(Inventory.gridArea:GetWidth(), ns.GridModel.Rows(#visible, COLS) * pitchY)
end

-- Item buttons may only move out of combat: lay out now, or once when combat ends.
local relayoutQueued = false
local function scheduleRelayout()
  if relayoutQueued then return end
  relayoutQueued = true
  ns.RunOutOfCombat(function()
    relayoutQueued = false
    relayout()
  end)
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
    local active = t.tab == tab
    if active then t.text:SetTextColor(1, 0.82, 0) else t.text:SetTextColor(0.73, 0.68, 0.58) end
    t.glow:SetShown(active)
    t.underline:SetShown(active)
  end
  scheduleRelayout()
end
for i, tab in ipairs(ns.Filters.TABS) do
  local t = CreateFrame("Button", nil, frame)
  t.tab = tab
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t.text:SetAllPoints(t)
  t.text:SetText(ns.Filters.LABELS[tab])
  -- Active tab: warm glow and a gold underline on the stone plate (all plates are alike).
  t.glow = t:CreateTexture(nil, "ARTWORK")
  t.glow:SetAllPoints(t)
  t.glow:SetColorTexture(0.91, 0.77, 0.42, 0.10)
  t.underline = t:CreateTexture(nil, "ARTWORK", nil, 1)
  t.underline:SetPoint("BOTTOMLEFT", 6, 2)
  t.underline:SetPoint("BOTTOMRIGHT", -6, 2)
  t.underline:SetHeight(2)
  t.underline:SetColorTexture(0.91, 0.77, 0.42, 0.85)
  local hover = t:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(t)
  hover:SetColorTexture(1, 1, 1, 0.05)
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

-- Bag search on a stone plate in the stats wing, above its buttons; sort button in its plate
-- right after the tabs.
local search = CreateFrame("EditBox", "ObsidianUIBagSearch", Inventory.statsPanel)
search:SetAutoFocus(false)
search:SetFontObject("GameFontHighlight")
search:SetTextColor(0.95, 0.9, 0.8)
search.plate = search:CreateTexture(nil, "BACKGROUND")
search.plate:SetAllPoints(search)
search.plate:SetTexture(M.plate.file)
search.glass = search:CreateTexture(nil, "ARTWORK")
search.glass:SetPoint("LEFT", 10, 0)
search.glass:SetSize(14, 14)
search.glass:SetTexture(SEARCH_ICON)
search.glass:SetVertexColor(0.91, 0.77, 0.42)
search:SetTextInsets(30, 10, 0, 0)
search.hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
search.hint:SetPoint("LEFT", 30, 0)
search.hint:SetText("Buscar...")
search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function(self)
  searchText = self:GetText() or ""
  self.hint:SetShown(searchText == "")
  if C_Container.SetItemSearch then C_Container.SetItemSearch(searchText) end
  refreshVisuals()
end)
Inventory.searchBox = search

local sort = CreateFrame("Button", nil, frame)
sort.icon = sort:CreateTexture(nil, "ARTWORK")
sort.icon:SetPoint("TOPLEFT", 5, -5)
sort.icon:SetPoint("BOTTOMRIGHT", -5, 5)
sort.icon:SetTexture(M.icon_sort.file)
sort.icon:SetVertexColor(0.91, 0.77, 0.42)
local sortHover = sort:CreateTexture(nil, "HIGHLIGHT")
sortHover:SetAllPoints(sort)
sortHover:SetColorTexture(1, 1, 1, 0.06)
sort:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(1, 0.9, 0.6) end)
sort:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(0.91, 0.77, 0.42) end)
sort:SetScript("OnClick", function()
  if C_Container.SortBags then C_Container.SortBags() end
end)
sort:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("Organizar bolsas")
  GameTooltip:Show()
end)
sort:SetScript("OnLeave", GameTooltip_Hide)
Inventory.sortButton = sort

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

-- The scroll bar sits on the rail painted in the window art: the arrow buttons keep only a
-- hover glow over the painted arrows, the thumb is the painted one (erased from the art).
local bar = scroll.ScrollBar
if bar then
  for _, b in ipairs({ bar.ScrollUpButton, bar.ScrollDownButton }) do
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
      local t = b and b[get] and b[get](b)
      if t then t:SetAlpha(0) end
    end
    if b then b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
  end
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  if thumb and M.scroll_thumb then
    thumb:SetTexture(M.scroll_thumb.file)
    thumb:SetTexCoord(0, M.scroll_thumb.w / M.scroll_thumb.potW, 0, M.scroll_thumb.h / M.scroll_thumb.potH)
  end
end
local function placeScrollBar()
  if not bar then return end
  local SC = S.scroll
  place(bar, SC.track.x, SC.track.y, SC.track.w, SC.track.h)
  if bar.ScrollUpButton then place(bar.ScrollUpButton, SC.up.x, SC.up.y, SC.up.w, SC.up.h) end
  if bar.ScrollDownButton then place(bar.ScrollDownButton, SC.down.x, SC.down.y, SC.down.w, SC.down.h) end
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  local fw, fh = frame:GetSize()
  if thumb then thumb:SetSize(SC.track.w * fw / S.w, SC.thumbH * fh / S.h) end
end

Inventory.onLayout = function()
  unit = frame:GetWidth() / S.w
  for i, t in ipairs(tabs) do place(t, S.tabs[i], S.tabY, S.tabW, S.tabH) end
  place(sort, S.sort.x, S.sort.y, S.sort.w, S.sort.h)
  local SR = S.wing.search
  Inventory.PlaceInWing(search, SR.x, SR.y, SR.w, SR.h)
  for i, b in ipairs(footerBags) do place(b, S.bags[i], S.bagY, S.bagW, S.bagH) end
  place(gold, S.gold.x, S.gold.y, S.gold.w, S.gold.h)
  placeScrollBar()
  -- Item buttons follow the new size right away (they were only placed on open).
  scheduleRelayout()
end
Inventory.onOpen = function()
  setTab(activeTab)
  updateFooter()
end

-- The grid stays laid out while the window is closed, so opening it in combat (when item
-- buttons cannot move) still shows every item.
ns.On("BAG_UPDATE_DELAYED", function()
  scheduleRelayout()
  if not frame:IsShown() then return end
  refreshVisuals()
  updateFooter()
end)
ns.On("ITEM_LOCK_CHANGED", function() if frame:IsShown() then refreshVisuals() end end)
ns.On("BAG_UPDATE_COOLDOWN", function() if frame:IsShown() then refreshVisuals() end end)
ns.On("INVENTORY_SEARCH_UPDATE", function() if frame:IsShown() then refreshVisuals() end end)
ns.On("PLAYER_MONEY", function() if frame:IsShown() then updateFooter() end end)
ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    Inventory.Layout()
    scheduleRelayout()
  end)
end)

-- Default bag frames stay hidden; every bag toggle opens/closes this window instead.
-- The window is the source of truth: opening/closing it also tells Blizzard, so B never needs
-- two presses. Toggle functions call Open/Close internally, so ignore a second action in the
-- same instant, and ignore the hooks fired by our own sync calls.
local last, syncing = 0, false
local function syncBlizzard(fn)
  if syncing or type(fn) ~= "function" then return end
  syncing = true
  pcall(fn)
  syncing = false
end
local baseOpen, baseClose = Inventory.Open, Inventory.Close
function Inventory.Open() baseOpen(); syncBlizzard(OpenAllBags) end
function Inventory.Close()
  baseClose()
  syncBlizzard(CloseAllBags)
  -- Items stop being "new" once the player has seen the bags, like the default bags.
  if C_NewItems and C_NewItems.ClearAll then pcall(C_NewItems.ClearAll) end
end

local function guarded(method)
  return function()
    if syncing then return end
    local now = GetTime()
    if now - last < 0.05 then return end
    last = now
    Inventory[method]()
  end
end
for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
  if _G[name] then hooksecurefunc(name, guarded("Toggle")) end
end
for _, name in ipairs({ "OpenAllBags", "OpenBackpack" }) do
  if _G[name] then hooksecurefunc(name, guarded("Open")) end
end
for _, name in ipairs({ "CloseAllBags", "CloseBackpack" }) do
  if _G[name] then hooksecurefunc(name, guarded("Close")) end
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
