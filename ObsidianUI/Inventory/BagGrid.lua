local _, ns = ...

-- Bag side of the inventory window: search and sort, filter tabs, one grid of 9 columns for all
-- bags (each item in the Moderno slot frame, in its quality colour) with a thin scroll bar, and
-- the footer: equipped bag slots, free slots and gold. Replaces the default bag frames.
local S = ns.Data.INV
local M = ns.MediaManifest
local W = ns.Widgets
local Inventory = ns.Inventory
local frame = Inventory.frame
local COLS = S.grid.cols
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
local unit = 1 -- screen units per design unit, set on layout

-- Every item button made so far (for tests and tools).
function Inventory.bagButtons()
  local list = {}
  for _, bag in ipairs(BAGS) do
    for _, b in pairs(buttons[bag]) do list[#list + 1] = b end
  end
  return list
end

local function newButton(bag, slot)
  local name = "ObsidianUIBag" .. bag .. "Slot" .. slot
  local ok, b = pcall(CreateFrame, "ItemButton", name, bagFrames[bag], "ContainerFrameItemButtonTemplate")
  if not ok then b = CreateFrame("Button", name, bagFrames[bag], "ContainerFrameItemButtonTemplate") end
  b:SetID(slot)
  b.Cooldown = b.Cooldown or _G[name .. "Cooldown"]
  b.IconQuestTexture = b.IconQuestTexture or _G[name .. "IconQuestTexture"]
  -- The action slots' frame around the item, in its quality colour (it scrolls with the button).
  b.obBorder = b:CreateTexture(nil, "OVERLAY", nil, 7)
  b.obBorder:SetAllPoints(b)
  ns.Media.Apply(b.obBorder, ns.ModernTex("mod_slot"))
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
  -- quality colour from green up; plain items and empty slots keep the neutral frame
  if info then b.obBorder:SetVertexColor(Inventory.QualityColor(info.quality))
  else b.obBorder:SetVertexColor(1, 1, 1, 0.6) end
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
  local G = S.grid
  local pitchX = (G.slot + G.gap) * unit
  local pitchY = pitchX
  local size = G.slot * unit
  local inset = size * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
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
      local icon = b.icon or _G[b:GetName() .. "IconTexture"]
      if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
        icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
      end
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

-- Filter tabs: flat buttons, the active one lighter.
local tabs = {}
Inventory.filterTabs = tabs
local function setTab(tab)
  activeTab = tab
  for _, t in ipairs(tabs) do W.SetSelected(t, t.tab == tab) end
  scheduleRelayout()
end
for i, tab in ipairs(ns.Filters.TABS) do
  local t = W.Button(frame, ns.Filters.LABELS[tab], function() setTab(tab) end)
  t.tab = tab
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
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.frame = b:CreateTexture(nil, "OVERLAY")
  b.frame:SetAllPoints(b)
  ns.Media.Apply(b.frame, ns.ModernTex("mod_slot"))
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
Inventory.footerBags = footerBags
local gold = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
gold:SetJustifyH("RIGHT")
Inventory.gold = gold
local freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
freeText:SetJustifyH("LEFT")
freeText:SetTextColor(W.DIM[1], W.DIM[2], W.DIM[3])
Inventory.freeText = freeText

-- Bag search at the top of the bag side, the sort button right after it.
local search = CreateFrame("EditBox", "ObsidianUIBagSearch", frame)
search:SetAutoFocus(false)
search:SetFontObject("GameFontHighlight")
search:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
W.Panel(search, 0.5)
search.glass = search:CreateTexture(nil, "ARTWORK")
search.glass:SetPoint("LEFT", 10, 0)
search.glass:SetSize(14, 14)
search.glass:SetTexture(SEARCH_ICON)
search.glass:SetVertexColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
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

local sort = W.Button(frame, "")
sort.icon = sort:CreateTexture(nil, "ARTWORK")
sort.icon:SetPoint("TOPLEFT", 7, -7)
sort.icon:SetPoint("BOTTOMRIGHT", -7, 7)
sort.icon:SetTexture(M.icon_sort.file)
sort.icon:SetVertexColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
sort:SetScript("OnMouseDown", function(self) self.icon:SetVertexColor(W.WHITE[1], W.WHITE[2], W.WHITE[3]) end)
sort:SetScript("OnMouseUp", function(self) self.icon:SetVertexColor(W.TEXT[1], W.TEXT[2], W.TEXT[3]) end)
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
  local free, total = 0, 0
  for _, bag in ipairs(BAGS) do
    local n = C_Container.GetContainerNumSlots(bag) or 0
    total = total + n
    free = free + (C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bag) or 0)
  end
  freeText:SetText(string.format("Livres: %d / %d", free, total))
end

local function place(region, x, y, w, h)
  local fw, fh = frame:GetSize()
  local rx, ry, rw, rh = ns.Layout.Rect(S.w, S.h, fw, fh, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", rx, ry)
  region:SetSize(rw, rh)
end

-- Thin scroll bar on the right of the grid: a faint track and a light thumb, no arrows.
local bar = scroll.ScrollBar
if bar then
  for _, b in ipairs({ bar.ScrollUpButton, bar.ScrollDownButton }) do
    if b then b:SetAlpha(0); b:EnableMouse(false) end
  end
  bar.track = bar.track or bar:CreateTexture(nil, "BACKGROUND")
  bar.track:SetAllPoints(bar)
  bar.track:SetColorTexture(1, 1, 1, 0.06)
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  if thumb then thumb:SetColorTexture(1, 1, 1, 0.35) end
end
local function placeScrollBar()
  if not bar then return end
  local SC = S.scroll
  place(bar, SC.x, SC.y, SC.w, SC.h)
  local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
  if thumb then thumb:SetSize(SC.w * unit, SC.thumbH * unit) end
end

Inventory.onLayout = function()
  unit = frame:GetWidth() / S.w
  local T = S.tabs
  local tw = (T.w - T.gap * (#tabs - 1)) / #tabs
  for i, t in ipairs(tabs) do place(t, T.x + (i - 1) * (tw + T.gap), T.y, tw, T.h) end
  place(sort, S.sort.x, S.sort.y, S.sort.w, S.sort.h)
  place(search, S.search.x, S.search.y, S.search.w, S.search.h)
  local B = S.bags
  for i, b in ipairs(footerBags) do
    place(b, B.x + (i - 1) * (B.size + B.gap), B.y, B.size, B.size)
    local px = B.size * unit * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", px, -px)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px, px)
  end
  place(freeText, S.free.x, S.free.y, S.free.w, S.free.h)
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
-- The addon never calls the game's bag functions back: OpenAllBags from addon code taints the
-- panel manager (the bank opened off screen, "blocked from an action"). So the game's own idea
-- of "bags open" can drift from this window. A toggle therefore flips this window from what it
-- was before the press, not from the Open/Close the game ran inside the same press.
local baseClose = Inventory.Close
function Inventory.Close()
  baseClose()
  -- Items stop being "new" once the player has seen the bags, like the default bags.
  if C_NewItems and C_NewItems.ClearAll then pcall(C_NewItems.ClearAll) end
end

local stamp, before = nil, false
local function note()
  local now = GetTime()
  if now ~= stamp then stamp, before = now, frame:IsShown() and true or false end
end
local function follow(method)
  return function()
    note()
    if method == "Toggle" then
      if before then Inventory.Close() else Inventory.Open() end
    else
      Inventory[method]()
    end
  end
end
for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
  if _G[name] then hooksecurefunc(name, follow("Toggle")) end
end
for _, name in ipairs({ "OpenAllBags", "OpenBackpack" }) do
  if _G[name] then hooksecurefunc(name, follow("Open")) end
end
for _, name in ipairs({ "CloseAllBags", "CloseBackpack" }) do
  if _G[name] then hooksecurefunc(name, follow("Close")) end
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
