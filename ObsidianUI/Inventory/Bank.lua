local _, ns = ...

-- Bank in the Moderno look. The game's bank (Personagem and Conta, tabs bought like bank bags,
-- each tab a container) is shown in one bank pane: Personagem/Conta, deposit and sort on top, the
-- items in the inventory's slot frames, the bank bags and free slots at the foot. Setting
-- "bankStyle" places the pane: window (its own window left of the inventory, both shrink to fit),
-- side (over the character half of the inventory), inside (the inventory gets Bolsas / Banco /
-- Conta in its head; away from the banker it shows what was there on the last visit).
-- Blizzard's bank window stays open, invisible and off screen: the game's right click on a bag
-- item deposits into its active bank type, so Personagem/Conta switch that window's tab.
local S = ns.Data.INV
local B = ns.Data.BANK
local W = ns.Widgets
local Inventory = ns.Inventory
local inv = Inventory.frame
local Bank = {}
ns.Bank = Bank

Bank.STYLES = ns.Data.BANK_STYLES
Bank.open = false -- at a banker
Bank.view = "bags" -- inside style: bags, bank or account

local function bankType(name) return Enum and Enum.BankType and Enum.BankType[name] end
local CHARACTER, ACCOUNT = bankType("Character") or 0, bankType("Account") or 2
Bank.type = CHARACTER

function Bank.Style()
  local s = ns.db and ns.db.bankStyle
  return (s == "window" or s == "inside") and s or "side"
end

local function canView(t)
  if not (C_Bank and C_Bank.CanViewBank) then return t == CHARACTER end
  local ok, v = pcall(C_Bank.CanViewBank, t)
  return ok and v == true
end

-- The purchased tabs of a bank type: { ID = container, name, icon }.
function Bank.Tabs(t)
  if not (C_Bank and C_Bank.FetchPurchasedBankTabData) then return {} end
  local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, t)
  return ok and type(data) == "table" and data or {}
end

-- ------------------------------------------------------------------ the bank window (window style)
local win = CreateFrame("Frame", "ObsidianUIBank", UIParent)
win:SetFrameStrata("HIGH")
win:SetToplevel(true)
win:EnableMouse(true)
win:Hide()
W.Panel(win, 0.94)
Bank.window = win
table.insert(UISpecialFrames, "ObsidianUIBank")
win.title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
win.title:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
win.title:SetText("Banco")
win.hairline = win:CreateTexture(nil, "BORDER")
win.close = W.Button(win, "X", function() win:Hide() end)

-- ------------------------------------------------------------------ the pane
local pane = CreateFrame("Frame", "ObsidianUIBankPane", inv)
pane:Hide()
Bank.pane = pane
local unit = 1

local function place(region, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", pane, "TOPLEFT", x * unit, -y * unit)
  if w then region:SetSize(w * unit, h * unit) end
end

local kindButtons = {}
local function setType(t)
  Bank.type = t
  -- the game's bank window follows, so a right click on a bag item deposits here
  local bf = rawget(_G, "BankFrame")
  if Bank.open and bf and bf.GetTabIDForBankType and EventRegistry then
    pcall(function()
      local id = bf:GetTabIDForBankType(t)
      if id and bf:GetActiveBankType() ~= t then EventRegistry:TriggerEvent("BankPanelMixin.TriggerSetTabEffects", id) end
    end)
  end
  Bank.Refresh()
end
Bank.SetType = setType
for i, kind in ipairs({ { CHARACTER, "Personagem" }, { ACCOUNT, "Conta" } }) do
  local b = W.Button(pane, kind[2], function() setType(kind[1]) end)
  b.bankType = kind[1]
  kindButtons[i] = b
end
Bank.kindButtons = kindButtons

pane.deposit = W.Button(pane, "Depositar tudo", function()
  if C_Bank and C_Bank.AutoDepositItemsIntoBank then pcall(C_Bank.AutoDepositItemsIntoBank, Bank.type) end
end)
pane.deposit:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("Guarda neste banco tudo o que o jogo deixa guardar de uma vez.")
  GameTooltip:Show()
end)
pane.deposit:SetScript("OnLeave", GameTooltip_Hide)

pane.sort = W.Button(pane, "")
pane.sort.icon = pane.sort:CreateTexture(nil, "ARTWORK")
pane.sort.icon:SetPoint("TOPLEFT", 7, -7)
pane.sort.icon:SetPoint("BOTTOMRIGHT", -7, 7)
pane.sort.icon:SetTexture(ns.MediaManifest.icon_sort.file)
pane.sort.icon:SetVertexColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
pane.sort:SetScript("OnClick", function()
  local fn = C_Container and (Bank.type == ACCOUNT and C_Container.SortAccountBankBags or C_Container.SortBankBags)
  if fn then pcall(fn) end
end)
pane.sort:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("Organizar banco")
  GameTooltip:Show()
end)
pane.sort:SetScript("OnLeave", GameTooltip_Hide)

-- the grid, scrolling like the bags
pane.area = CreateFrame("Frame", nil, pane)
local scroll = CreateFrame("ScrollFrame", "ObsidianUIBankScroll", pane.area, "UIPanelScrollFrameTemplate")
scroll:SetAllPoints(pane.area)
local child = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(child)
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

local bagFrames, buttons = {}, {}
local function itemButton(bag, slot)
  if not bagFrames[bag] then
    local f = CreateFrame("Frame", nil, child)
    f:SetID(bag)
    f:SetAllPoints(child)
    bagFrames[bag], buttons[bag] = f, {}
  end
  local b = buttons[bag][slot]
  if not b then
    b = Inventory.NewItemButton(bagFrames[bag], "ObsidianUIBank" .. tostring(bag):gsub("-", "m") .. "Slot" .. slot, slot)
    buttons[bag][slot] = b
  end
  return b
end

-- Every bank item button made so far (for tests and tools).
function Bank.Buttons()
  local list = {}
  for _, slots in pairs(buttons) do
    for _, b in pairs(slots) do list[#list + 1] = b end
  end
  return list
end

-- What was in the bank on the last visit: plain slots, the tooltip from the item link.
local cached = {}
local function cacheButton(i)
  local b = cached[i]
  if b then return b end
  b = CreateFrame("Button", nil, child)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  ns.Media.Apply(b.border, ns.ModernTex("mod_slot"))
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -4, 4)
  b:SetScript("OnEnter", function(self)
    if not self.link then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  cached[i] = b
  return b
end
Bank.cacheButtons = cached

-- foot: the bank bags (or tabs), one "+" to buy the next, free slots
local bagSlots = {}
Bank.bagSlots = bagSlots
local function bagIndex(t)
  local E = Enum and Enum.BagIndex
  if not E then return nil end
  return t == ACCOUNT and E.Accountbanktab or E.Characterbanktab
end
local function bagSlot(i)
  if bagSlots[i] then return bagSlots[i] end
  local b = CreateFrame("Button", nil, pane)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.frame = b:CreateTexture(nil, "OVERLAY")
  b.frame:SetAllPoints(b)
  ns.Media.Apply(b.frame, ns.ModernTex("mod_slot"))
  b.plus = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.plus:SetPoint("CENTER")
  b.plus:SetText("+")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local function pickup(self)
    local bag = bagIndex(self.bankType)
    if self.isBag and bag and C_Container.PickupContainerItem then C_Container.PickupContainerItem(bag, self.slot) end
  end
  b:SetScript("OnClick", function(self)
    if self.buy then
      StaticPopup_Show("CONFIRM_BUY_BANK_TAB", nil, nil, { bankType = self.bankType })
    else
      pickup(self)
    end
  end)
  b:SetScript("OnDragStart", pickup)
  b:SetScript("OnReceiveDrag", pickup)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local bag = bagIndex(self.bankType)
    if self.buy then
      GameTooltip:SetText(self.bankType == ACCOUNT and "Comprar aba da conta" or "Comprar espaço de bolsa no banco")
      local ok, data = pcall(C_Bank.FetchNextPurchasableBankTabData, self.bankType)
      if ok and data and data.tabCost then GameTooltip:AddLine(GetMoneyString(data.tabCost, true), 1, 1, 1) end
    elseif not (self.isBag and bag and GameTooltip:SetBagItem(bag, self.slot)) then
      GameTooltip:SetText(self.tabName or "Bolsa do banco")
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  bagSlots[i] = b
  return b
end

pane.free = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
pane.free:SetJustifyH("LEFT")
pane.free:SetTextColor(W.DIM[1], W.DIM[2], W.DIM[3])

-- ------------------------------------------------------------------ cache of the last visit
local function charKey()
  return (UnitName("player") or "?") .. " - " .. ((GetRealmName and GetRealmName()) or "?")
end
local function cacheFor(t)
  local db = ns.db
  if not db then return nil end
  db.bankCache = db.bankCache or {}
  local key = t == ACCOUNT and "account" or charKey()
  return db.bankCache, key
end

local function slotsOf(t)
  local list = {}
  for _, tab in ipairs(Bank.Tabs(t)) do
    for slot = 1, C_Container.GetContainerNumSlots(tab.ID) or 0 do list[#list + 1] = { bag = tab.ID, slot = slot } end
  end
  return list
end

local function remember(t)
  local store, key = cacheFor(t)
  if not store then return end
  local items = {}
  for i, s in ipairs(slotsOf(t)) do
    local info = C_Container.GetContainerItemInfo(s.bag, s.slot)
    items[i] = info and { icon = info.iconFileID, count = info.stackCount, quality = info.quality, link = info.hyperlink } or false
  end
  store[key] = items
end

-- ------------------------------------------------------------------ layout and contents
local cols = 9

local function layoutPane(w, h)
  local x = 0
  local showKinds = Bank.Style() ~= "inside"
  for _, b in ipairs(kindButtons) do
    local shown = showKinds and (b.bankType == CHARACTER or canView(ACCOUNT))
    b:SetShown(shown)
    if shown then
      place(b, x, 0, B.kindW, B.bar)
      x = x + B.kindW + 6
      W.SetSelected(b, b.bankType == Bank.type)
    end
  end
  local canDeposit = Bank.open and C_Bank and C_Bank.DoesBankTypeSupportAutoDeposit
    and select(2, pcall(C_Bank.DoesBankTypeSupportAutoDeposit, Bank.type)) == true
  pane.deposit:SetShown(canDeposit)
  place(pane.deposit, w - B.bar - 6 - B.depositW, 0, B.depositW, B.bar)
  pane.sort:SetShown(Bank.open)
  place(pane.sort, w - B.bar, 0, B.bar, B.bar)
  local G = S.grid
  local pitch = G.slot + G.gap
  cols = math.max(1, math.floor((w + G.gap) / pitch))
  local top = B.bar + B.gap
  place(pane.area, 0, top, cols * pitch - G.gap, h - top - B.gap - B.foot)
  if bar then
    place(bar, w, top, S.scroll.w, h - top - B.gap - B.foot)
    local thumb = bar.GetThumbTexture and bar:GetThumbTexture()
    if thumb then thumb:SetSize(S.scroll.w * unit, S.scroll.thumbH * unit) end
  end
end

local function fillGrid()
  local G = S.grid
  local pitch, size = (G.slot + G.gap) * unit, G.slot * unit
  for _, slots in pairs(buttons) do
    for _, b in pairs(slots) do b:Hide() end
  end
  for _, b in ipairs(cached) do b:Hide() end
  local n = 0
  local function at(b)
    local col, row = ns.GridModel.Pos(n, cols)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", child, "TOPLEFT", (col - 1) * pitch, -(row - 1) * pitch)
  end
  if Bank.open then
    for _, s in ipairs(slotsOf(Bank.type)) do
      n = n + 1
      local b = itemButton(s.bag, s.slot)
      at(b)
      Inventory.SizeItemButton(b, size)
      Inventory.FillItemButton(b, s.bag, s.slot)
      b:Show()
    end
  else
    local store, key = cacheFor(Bank.type)
    for _, item in ipairs(store and store[key] or {}) do
      n = n + 1
      local b = cacheButton(n)
      at(b)
      b:SetSize(size, size)
      local px = size * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
      b.icon:ClearAllPoints()
      b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", px, -px)
      b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px, px)
      b.icon:SetTexture(item and item.icon or nil)
      b.icon:SetShown(item and item.icon ~= nil)
      b.count:SetText(item and item.count and item.count > 1 and item.count or "")
      b.link = item and item.link or nil
      if item then b.border:SetVertexColor(Inventory.QualityColor(item.quality)) else b.border:SetVertexColor(1, 1, 1, 0.6) end
      b:Show()
    end
  end
  child:SetSize(pane.area:GetWidth(), ns.GridModel.Rows(n, cols) * pitch)
end

local function fillFoot(h)
  for _, b in ipairs(bagSlots) do b:Hide() end
  local y = h - B.foot
  local x = 0
  if Bank.open then
    local t = Bank.type
    local tabs = Bank.Tabs(t)
    local bagsInBank = C_Bank and C_Bank.ShouldUsePlayerBagsInBank and C_Bank.ShouldUsePlayerBagsInBank()
    local bag = bagIndex(t)
    local first = bagsInBank and 2 or 1 -- the first bank bag comes with the bank
    local i = 0
    for slot = first, #tabs do
      i = i + 1
      local b = bagSlot(i)
      b.bankType, b.slot, b.buy, b.isBag, b.tabName = t, slot, false, bagsInBank, tabs[slot].name
      local icon = tabs[slot].icon
      if bagsInBank and bag and ItemLocation and C_Item and C_Item.GetItemIcon then
        local ok, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
        local has = ok and loc and C_Item.DoesItemExist and select(2, pcall(C_Item.DoesItemExist, loc)) == true
        icon = has and select(2, pcall(C_Item.GetItemIcon, loc)) or nil
      end
      b.icon:SetTexture(icon or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
      b.icon:Show()
      b.plus:Hide()
      place(b, x, y, B.bag, B.bag)
      b:Show()
      x = x + B.bag + B.bagGap
    end
    local canBuy = C_Bank and C_Bank.CanPurchaseBankTab and select(2, pcall(C_Bank.CanPurchaseBankTab, t)) == true
    local full = C_Bank and C_Bank.HasMaxBankTabs and select(2, pcall(C_Bank.HasMaxBankTabs, t)) == true
    if canBuy and not full then
      i = i + 1
      local b = bagSlot(i)
      b.bankType, b.buy, b.isBag = t, true, false
      b.icon:Hide()
      b.plus:Show()
      place(b, x, y, B.bag, B.bag)
      b:Show()
      x = x + B.bag + B.bagGap
    end
    local free, total = 0, 0
    for _, s in ipairs(slotsOf(t)) do
      total = total + 1
      if not C_Container.GetContainerItemInfo(s.bag, s.slot) then free = free + 1 end
    end
    pane.free:SetText(string.format("Livres: %d / %d", free, total))
  else
    local store, key = cacheFor(Bank.type)
    pane.free:SetText(store and store[key] and "Longe do banqueiro: o que havia na última visita."
      or "Visite um banqueiro para ver o que está guardado aqui.")
  end
  place(pane.free, x + (x > 0 and 8 or 0), y, Bank.open and B.freeW or 520, B.foot)
end

function Bank.Refresh()
  if not pane:IsShown() then return end
  local w, h = pane:GetWidth() / unit, pane:GetHeight() / unit
  layoutPane(w, h)
  ns.RunOutOfCombat(function()
    fillGrid()
    fillFoot(h)
  end)
  if Bank.open then remember(Bank.type) end
end

-- ------------------------------------------------------------------ where the pane goes
local charSide, bagSide = {}, {}
local function collectSides()
  if #charSide > 0 then return end
  for _, r in ipairs({ Inventory.model, Inventory.statsPanel }) do charSide[#charSide + 1] = r end
  for _, r in ipairs(Inventory.slotButtons or {}) do charSide[#charSide + 1] = r end
  for _, r in ipairs(Inventory.charTabs or {}) do charSide[#charSide + 1] = r end
  for _, r in ipairs({ Inventory.sortButton, Inventory.gridArea, Inventory.freeText }) do bagSide[#bagSide + 1] = r end
  for _, r in ipairs(Inventory.filterTabs or {}) do bagSide[#bagSide + 1] = r end
  for _, r in ipairs(Inventory.footerBags or {}) do bagSide[#bagSide + 1] = r end
end
local function showAll(list, on)
  for _, r in ipairs(list) do r:SetShown(on) end
end

-- inside style: Bolsas / Banco / Conta in the inventory's head
local switch = {}
Bank.switch = switch
local VIEWS = { { "bags", "Bolsas" }, { "bank", "Banco" }, { "account", "Conta" } }
local function setView(view)
  Bank.view = view
  if view == "bank" then Bank.type = CHARACTER elseif view == "account" then Bank.type = ACCOUNT end
  if view ~= "bags" then setType(Bank.type) end
  Bank.Arrange()
end
Bank.SetView = setView
for i, v in ipairs(VIEWS) do
  local b = W.Button(inv, v[2], function() setView(v[1]) end)
  b.view = v[1]
  b:Hide()
  switch[i] = b
end

local function invRect(region, r)
  local iw, ih = inv:GetSize()
  local x, y, rw, rh = ns.Layout.Rect(S.w, S.h, iw, ih, r.x, r.y, r.w, r.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", inv, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
end

local function layoutSwitch(on)
  local SW = B.switch
  local shown = {}
  for _, b in ipairs(switch) do
    local visible = on and (b.view ~= "account" or canView(ACCOUNT) or (ns.db and ns.db.bankCache and ns.db.bankCache.account))
    b:SetShown(visible and true or false)
    if visible then shown[#shown + 1] = b end
  end
  local x = SW.right - #shown * SW.w - (#shown - 1) * SW.gap - 40
  for i, b in ipairs(shown) do
    invRect(b, { x = x + (i - 1) * (SW.w + SW.gap), y = (S.head - SW.h) / 2, w = SW.w, h = SW.h })
    W.SetSelected(b, b.view == Bank.view)
  end
end

-- The inventory leaves room on its left for the bank window (Window.lua reads pairW).
local function pairWith(on)
  local w = on and (B.win.w + 10) or nil
  if Inventory.pairW == w then return end
  Inventory.pairW = w
  inv.obPlaced = false
  Inventory.Layout()
end

function Bank.Arrange()
  ns.RunOutOfCombat(function()
    collectSides()
    local style = Bank.Style()
    local onSide = style == "side" and Bank.open
    local onInside = style == "inside" and Bank.view ~= "bags"
    local inWindow = style == "window" and Bank.open
    showAll(charSide, not onSide)
    if not onSide and Inventory.RefreshModel and inv:IsShown() then Inventory.RefreshModel() end
    showAll(bagSide, not onInside)
    layoutSwitch(style == "inside")
    pairWith(inWindow)
    local u = inv:GetWidth() / S.w
    if inWindow then
      local h = inv:GetHeight()
      win:SetSize(B.win.w * u, h)
      win:ClearAllPoints()
      win:SetPoint("TOPRIGHT", inv, "TOPLEFT", -10 * u, 0)
      win.title:ClearAllPoints()
      win.title:SetPoint("LEFT", win, "TOPLEFT", S.title.x * u, -B.win.head / 2 * u)
      win.close:ClearAllPoints()
      win.close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -(S.w - S.close.x - S.close.w) * u, -S.close.y * u)
      win.close:SetSize(S.close.w * u, S.close.h * u)
      win.hairline:ClearAllPoints()
      win.hairline:SetPoint("TOPLEFT", win, "TOPLEFT", 20 * u, -B.win.head * u)
      win.hairline:SetSize((B.win.w - 40) * u, 1)
      local r, g, b = W.Rim()
      win.hairline:SetColorTexture(r, g, b, 0.14)
      win:Show()
    else
      win:Hide()
    end
    local rect = (onSide and B.side) or (onInside and B.inside) or (inWindow and B.win.pane)
    if not rect then
      pane:Hide()
      return
    end
    unit = u
    local host = inWindow and win or inv
    pane:SetParent(host)
    pane:SetFrameLevel(host:GetFrameLevel() + 2)
    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", host, "TOPLEFT", rect.x * u, -rect.y * u)
    pane:SetSize(rect.w * u, rect.h * u)
    pane:Show()
    Bank.Refresh()
  end)
end

-- ------------------------------------------------------------------ opening and closing
local function closeBank()
  if not Bank.open then return end
  if C_Bank and C_Bank.CloseBankFrame then pcall(C_Bank.CloseBankFrame)
  elseif CloseBankFrame then pcall(CloseBankFrame) end
end
Bank.Close = closeBank
win:SetScript("OnHide", function() if Bank.Style() == "window" then closeBank() end end)
inv:HookScript("OnHide", function() if Bank.Style() ~= "window" then closeBank() end end)

local function onBankShown(bf)
  -- invisible and off screen: only its active tab (where right clicks deposit) is used
  bf:SetAlpha(0)
  ns.Pin(bf, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -4000, 0)
  end)
  Bank.open = true
  local ok, t = pcall(function() return bf:GetActiveBankType() end)
  Bank.type = ok and (t == ACCOUNT or t == CHARACTER) and t or CHARACTER
  if not canView(Bank.type) then Bank.type = canView(CHARACTER) and CHARACTER or ACCOUNT end
  if Bank.Style() == "inside" then Bank.view = Bank.type == ACCOUNT and "account" or "bank" end
  Inventory.Open()
  Bank.Arrange()
end

local function onBankHidden()
  Bank.open = false
  if Bank.Style() == "inside" then Bank.view = "bags" end
  Bank.Arrange()
end

local hooked = false
local function hookBankFrame()
  local bf = rawget(_G, "BankFrame")
  if hooked or type(bf) ~= "table" or not bf.HookScript then return end
  hooked = true
  bf:HookScript("OnShow", onBankShown)
  bf:HookScript("OnHide", onBankHidden)
  if bf:IsShown() then onBankShown(bf) end
end
Bank.Hook = hookBankFrame
hookBankFrame()
ns.On("PLAYER_LOGIN", hookBankFrame)
ns.On("ADDON_LOADED", hookBankFrame)

-- The style changed in the panel.
function Bank.ApplyStyle()
  if Bank.Style() == "inside" then
    Bank.view = Bank.open and (Bank.type == ACCOUNT and "account" or "bank") or "bags"
  end
  Bank.Arrange()
end

-- The inventory laid out again (size setting, screen): the pane follows.
local baseLayout = Inventory.onLayout
Inventory.onLayout = function()
  if baseLayout then baseLayout() end
  if Bank.open or Bank.Style() == "inside" then Bank.Arrange() end
end
local baseOpen = Inventory.onOpen
Inventory.onOpen = function()
  if baseOpen then baseOpen() end
  Bank.Arrange()
end

for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "BANK_TABS_CHANGED", "PLAYERBANKSLOTS_CHANGED",
  "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BAG_CONTAINER_UPDATE", "ITEM_LOCK_CHANGED", "INVENTORY_SEARCH_UPDATE",
  "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY" }) do
  ns.On(ev, function() if pane:IsShown() then Bank.Refresh() end end)
end
