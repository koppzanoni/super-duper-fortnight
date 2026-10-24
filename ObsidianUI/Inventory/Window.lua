local _, ns = ...

-- Unified inventory window, Moderno look: one wide black translucent window. Head: the
-- character's name, level and class, close button (the head drags the window). Left: 3D player
-- model with the item level, 8+8 equipment slots, 3 weapon slots, the Attributes / Reputation /
-- Currency tabs and the stats in two columns. Right: the bags, added by BagGrid.lua into
-- Inventory.gridArea. Positions in design units (Data.INV).
local S = ns.Data.INV
local W = ns.Widgets
local Inventory = {}
ns.Inventory = Inventory

local frame = CreateFrame("Frame", "ObsidianUIInventory", UIParent)
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:Hide()
frame.obPlaced = false
Inventory.frame = frame
table.insert(UISpecialFrames, "ObsidianUIInventory")

-- nearly opaque: the HUD under the window would compete with the items
Inventory.backdrop = W.Panel(frame, 0.94)
-- a hairline under the head and a vertical line between the character and the bags
local function line(alpha)
  local t = frame:CreateTexture(nil, "BORDER")
  local r, g, b = W.Rim()
  t:SetColorTexture(r, g, b, alpha)
  return t
end
Inventory.hairline = line(0.14)
Inventory.separator = line(0.1)

local function rect(region, r)
  local w, h = frame:GetSize()
  local x, y, rw, rh = ns.Layout.Rect(S.w, S.h, w, h, r.x, r.y, r.w, r.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
end

-- The head doubles as the drag handle.
local title = CreateFrame("Frame", nil, frame)
title:EnableMouse(true)
title:RegisterForDrag("LeftButton")
title:SetScript("OnDragStart", function() frame:StartMoving() end)
title:SetScript("OnDragStop", function()
  frame:StopMovingOrSizing()
  Inventory.SavePosition()
end)
local titleText = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetJustifyH("LEFT")
Inventory.titleText = titleText
-- level and class beside the name
local subText = title:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
subText:SetPoint("LEFT", titleText, "RIGHT", 14, 0)
subText:SetTextColor(W.DIM[1], W.DIM[2], W.DIM[3])
Inventory.subText = subText
-- The character's full name (with title, like the default character sheet) on the plate;
-- a smaller font when it does not fit.
function Inventory.TitleText()
  local name = UnitPVPName and UnitPVPName("player")
  if type(name) ~= "string" or name == "" then name = UnitName("player") end
  return name or "PERSONAGEM"
end
local function setTitle()
  titleText:SetFontObject("GameFontNormalLarge")
  titleText:SetText(Inventory.TitleText())
  local textW, plateW = titleText:GetStringWidth(), title:GetWidth()
  if type(textW) == "number" and type(plateW) == "number" and textW > plateW * 0.6 then
    titleText:SetFontObject("GameFontNormal")
  end
  local level = UnitLevel("player")
  local className = UnitClass("player")
  subText:SetText(string.format("Nível %s %s", tostring(level or ""), className or ""))
end
setTitle()
titleText:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])

Inventory.closeButton = W.Button(frame, "X", function() Inventory.Close() end)

-- 3D model of the player, transparent background, drag to rotate, wheel to zoom.
local model = CreateFrame("PlayerModel", nil, frame)
model:EnableMouse(true)
model:EnableMouseWheel(true)
local zoom, dragging, lastX = 0, false, 0
-- Camera a bit closer than the default full-body shot, so the character fills the frame.
-- Distance and height can be tuned in game with /obui modelo <distância> <altura>.
local function refreshModel()
  model:SetUnit("player")
  model:SetPortraitZoom(zoom)
  local db = ns.db or {}
  if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, db.modelDistance or 0.9) end
  if model.SetPosition then pcall(model.SetPosition, model, 0, 0, db.modelHeight or -0.12) end
end
Inventory.RefreshModel = refreshModel
model:SetScript("OnShow", refreshModel)
model:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then dragging = true; lastX = GetCursorPosition() end end)
model:SetScript("OnMouseUp", function() dragging = false end)
model:SetScript("OnUpdate", function(self)
  if not dragging then return end
  local x = GetCursorPosition()
  self:SetFacing(self:GetFacing() + (x - lastX) * 0.01)
  lastX = x
end)
model:SetScript("OnMouseWheel", function(self, delta)
  zoom = math.max(0, math.min(0.6, zoom + delta * 0.05))
  self:SetPortraitZoom(zoom)
end)
pcall(model.SetLight, model, true, false, -1, 1, -1, 1, 1, 0.82, 0.62, 1, 0.95, 0.78, 0.55)
Inventory.model = model

-- Item level over the model: a small caption and the equipped average in the arcane purple.
local ilvlCaption = model:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ilvlCaption:SetPoint("TOP", model, "TOP", 0, -8)
ilvlCaption:SetTextColor(W.DIM[1], W.DIM[2], W.DIM[3])
ilvlCaption:SetText("Nível de item")
local itemLevel = model:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
itemLevel:SetPoint("TOP", ilvlCaption, "BOTTOM", 0, -2)
itemLevel:SetTextColor(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3])
Inventory.itemLevel = itemLevel
local function updateItemLevel()
  local ok, _, equipped = pcall(GetAverageItemLevel)
  local shown = ok and type(equipped) == "number" and equipped > 0
  itemLevel:SetText(shown and string.format("%d", math.floor(equipped)) or "")
  ilvlCaption:SetShown(shown)
end

-- Equipment slots.
local slotButtons = {}
Inventory.slotButtons = slotButtons
local function qualityColor(q)
  local c = type(q) == "number" and q > 1 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end
Inventory.QualityColor = qualityColor

local RELIC_TEXTURE = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic"

-- checkRelic: the slot becomes a relic slot for classes that have one (like the default sheet).
local function slotInfo(slotName)
  if type(C_PaperDollInfo) == "table" and type(C_PaperDollInfo.GetInventorySlotInfo) == "function" then
    return pcall(C_PaperDollInfo.GetInventorySlotInfo, slotName)
  end
  return pcall(GetInventorySlotInfo, slotName)
end

local function isRelic(b)
  return b.checkRelic == true and type(UnitHasRelicSlot) == "function" and UnitHasRelicSlot("player") == true
end

local function slotButton(slotName)
  local ok, slotID, emptyTexture, checkRelic = slotInfo(slotName)
  if not ok or not slotID then return nil end
  local b = CreateFrame("Button", nil, frame)
  b.slotID, b.slotName, b.emptyTexture, b.checkRelic = slotID, slotName, emptyTexture, checkRelic
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the action slots' frame, in the item's quality colour
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  ns.Media.Apply(b.border, ns.ModernTex("mod_slot"))
  -- Blue glow on hover, like the default character sheet's slots.
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function(self)
    if IsModifiedClick("CHATLINK") then
      local link = GetInventoryItemLink("player", self.slotID)
      if link then ChatEdit_InsertLink(link) end
    else
      PickupInventoryItem(self.slotID)
    end
  end)
  b:SetScript("OnDragStart", function(self) PickupInventoryItem(self.slotID) end)
  b:SetScript("OnReceiveDrag", function(self) PickupInventoryItem(self.slotID) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not GameTooltip:SetInventoryItem("player", self.slotID) then
      -- The game hides the tooltip when the slot is empty: take it again, then name the slot.
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local text = isRelic(self) and RELICSLOT
      if not text and type(ItemUtil) == "table" and type(ItemUtil.GetEmptyEquipSlotTooltip) == "function" then
        local ok, t = pcall(ItemUtil.GetEmptyEquipSlotTooltip, self.slotID)
        if ok and type(t) == "string" then text = t end
      end
      GameTooltip:SetText(text or _G[slotName:upper()] or slotName)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  slotButtons[#slotButtons + 1] = b
  return b
end

local equipLayout = {}
for col, list in ipairs({ ns.Data.EQUIP_LEFT, ns.Data.EQUIP_RIGHT }) do
  for i, name in ipairs(list) do
    local b = slotButton(name)
    if b then equipLayout[#equipLayout + 1] = { b = b, x = S.equipCols[col] - S.equipSize / 2,
      y = S.equipTop + (i - 1) * S.equipPitch, size = S.equipSize } end
  end
end
for i, name in ipairs(ns.Data.WEAPONS) do
  local b = slotButton(name)
  if b then equipLayout[#equipLayout + 1] = { b = b, x = S.weapons[i], y = S.weaponY, size = S.weaponSize } end
end

local function updateEquipment()
  for _, b in ipairs(slotButtons) do
    -- Empty slots show the game's empty-slot picture, dimmed (like the default sheet).
    local tex = GetInventoryItemTexture("player", b.slotID)
    local empty = isRelic(b) and RELIC_TEXTURE or b.emptyTexture
    b.icon:SetTexture(tex or empty)
    b.icon:SetShown((tex or empty) ~= nil)
    if tex then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.4, 0.4, 0.4) end
    b.icon:SetAlpha(tex and 1 or 0.5)
    if tex then b.border:SetVertexColor(qualityColor(GetInventoryItemQuality("player", b.slotID)))
    else b.border:SetVertexColor(1, 1, 1, 0.6) end
  end
  updateItemLevel()
end

-- Stats panel: a darker box in the character side, under its tabs; rows in two columns.
local ST = S.stats
local stats = CreateFrame("Frame", nil, frame)
W.Panel(stats, 0.3)
Inventory.statsPanel = stats

-- Place a region in the stats panel by design units.
local unit = 1
function Inventory.PlaceStat(region, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", stats, "TOPLEFT", x * unit, -y * unit)
  if w then region:SetSize(w * unit, h * unit) end
end

-- Stat tooltips: the default character sheet's own setters fill a stat frame's tooltip fields
-- (or a custom onEnterFunc); each row's hover area plays that stat frame.
local SETTERS = { stat = "PaperDollFrame_SetStat", armor = "PaperDollFrame_SetArmor",
  attackPower = "PaperDollFrame_SetAttackPower", crit = "PaperDollFrame_SetCritChance",
  spellPower = "PaperDollFrame_SetSpellPower", mastery = "PaperDollFrame_SetMastery",
  dodge = "PaperDollFrame_SetDodge", parry = "PaperDollFrame_SetParry", block = "PaperDollFrame_SetBlock" }

local function showStatTooltip(hover)
  local l = hover.line
  hover.tooltip, hover.tooltip2, hover.tooltip3, hover.onEnterFunc = nil, nil, nil, nil
  local setter = l.key and _G[SETTERS[l.key]]
  if type(setter) == "function" then
    if l.key == "stat" then pcall(setter, hover, "player", l.index) else pcall(setter, hover, "player") end
  end
  if type(hover.onEnterFunc) == "function" and pcall(hover.onEnterFunc, hover) then return end
  if hover.tooltip and type(PaperDollStatTooltip) == "function" then
    PaperDollStatTooltip(hover)
    return
  end
  GameTooltip:SetOwner(hover, "ANCHOR_RIGHT")
  GameTooltip:SetText(l.labelText or "")
  if l.valueText then GameTooltip:AddLine(l.valueText, 1, 1, 1) end
  GameTooltip:Show()
end

local lines = {}
Inventory.statLines = lines
local function statLine(i)
  if lines[i] then return lines[i] end
  local l = {}
  -- Hover area; also the stat frame Blizzard's setters write to (hidden Label/Value).
  l.hover = CreateFrame("Frame", nil, stats)
  l.hover:EnableMouse(true)
  l.hover.line = l
  l.hover.Label = l.hover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  l.hover.Value = l.hover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  l.hover.Label:SetAlpha(0)
  l.hover.Value:SetAlpha(0)
  l.hover:SetScript("OnEnter", showStatTooltip)
  l.hover:SetScript("OnLeave", GameTooltip_Hide)
  l.label = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  l.label:SetJustifyH("LEFT")
  l.label:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
  l.value = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  l.value:SetJustifyH("RIGHT")
  l.value:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
  lines[i] = l
  return l
end

-- Tabs over the stats: Attributes is this page; Reputation and Currency open Blizzard's pages.
Inventory.statsTab = W.Button(frame, "Atributos")
W.SetSelected(Inventory.statsTab, true)
Inventory.repButton = W.Button(frame, "Reputação", nil, "CharacterFrameTab2")
Inventory.tokenButton = W.Button(frame, "Moedas", nil, "CharacterFrameTab3")
Inventory.charTabs = { Inventory.statsTab, Inventory.repButton, Inventory.tokenButton }

-- In this client (camelot) the character frame's pages are side tabs: plain Frames that open
-- their page on mouse up, which a secure click cannot press. While the character frame is
-- closed, the real tab lies invisible over our button, so the click runs Blizzard's own code
-- (like the game menu micro button); it goes back home when the frame opens.
local lent = {}
local function lendTabs(on)
  for _, l in ipairs(lent) do
    local tab = l.tab
    l.on = on
    if on then
      tab:SetParent(l.button)
      tab:SetFrameStrata(l.button:GetFrameStrata())
      tab:SetFrameLevel(l.button:GetFrameLevel() + 2)
      tab:SetAlpha(0)
      tab:ClearAllPoints()
      tab:SetAllPoints(l.button)
    else
      tab:SetParent(l.home.parent)
      tab:SetFrameStrata(l.home.strata)
      tab:SetAlpha(1)
      tab:ClearAllPoints()
      for _, pt in ipairs(l.home.points) do tab:SetPoint(unpack(pt)) end
      l.button:UnlockHighlight()
    end
  end
end

local function lendTab(button, tabName)
  local tab = rawget(_G, tabName)
  if type(tab) ~= "table" then return end
  local home = { parent = tab:GetParent(), strata = tab:GetFrameStrata(), points = {} }
  for i = 1, tab:GetNumPoints() do home.points[i] = { tab:GetPoint(i) } end
  local l = { tab = tab, button = button, home = home }
  lent[#lent + 1] = l
  -- Blizzard lays the tabs out again on some events: kept on our button while lent.
  ns.Pin(tab, function(f)
    if not l.on then return end
    f:ClearAllPoints()
    f:SetAllPoints(button)
  end)
  -- Our button's hover glow and pressed text, for the invisible tab over it.
  tab:HookScript("OnEnter", function() if l.on then button:LockHighlight() end end)
  tab:HookScript("OnLeave", function() button:UnlockHighlight() end)
  tab:HookScript("OnMouseDown", function() if l.on then button.text:SetPoint("CENTER", 1, -1) end end)
  tab:HookScript("OnMouseUp", function() button.text:SetPoint("CENTER") end)
end

local tabsLent = false
local function lendCharacterTabs()
  local owner = rawget(_G, "CharacterFrame")
  if tabsLent or type(owner) ~= "table" or type(rawget(_G, "CharacterFrameModeTab2")) ~= "table" then return end
  tabsLent = true
  lendTab(Inventory.repButton, "CharacterFrameModeTab2")
  lendTab(Inventory.tokenButton, "CharacterFrameModeTab5")
  owner:HookScript("OnShow", function() lendTabs(false) end)
  owner:HookScript("OnHide", function() lendTabs(true) end)
  lendTabs(not owner:IsShown())
end
lendCharacterTabs()
ns.On("PLAYER_LOGIN", lendCharacterTabs)

-- Rows (headers left out) flow down two columns; the row height shrinks when there are many.
local function updateStats()
  local rows = {}
  for _, r in ipairs(ns.Stats.Rows(ns.Stats.GameAPI())) do
    if not r.header then rows[#rows + 1] = r end
  end
  local perCol = math.max(1, math.ceil(#rows / 2))
  local rowH = math.min(ST.maxRow, (ST.h - 2 * ST.padY) / perCol)
  local colW = (ST.w - 2 * ST.padX - ST.colGap) / 2
  for i, r in ipairs(rows) do
    local l = statLine(i)
    local col, n = math.floor((i - 1) / perCol), (i - 1) % perCol
    local x, y = ST.padX + col * (colW + ST.colGap), ST.padY + n * rowH
    l.label:SetText(r.label)
    Inventory.PlaceStat(l.label, x, y + 3)
    l.value:SetText(r.value)
    l.value:ClearAllPoints()
    l.value:SetPoint("TOPRIGHT", stats, "TOPLEFT", (x + colW) * unit, -(y + 3) * unit)
    l.key, l.index, l.labelText, l.valueText = r.key, r.index, r.label, r.value
    Inventory.PlaceStat(l.hover, x, y, colW, rowH)
    l.hover:Show()
    l.label:Show()
    l.value:Show()
  end
  for i = #rows + 1, #lines do
    lines[i].label:Hide(); lines[i].value:Hide(); lines[i].hover:Hide(); lines[i].key = nil
  end
end

local function layoutStats()
  unit = frame:GetWidth() / S.w
  rect(stats, ST)
  local T = S.charTabs
  for i, b in ipairs(Inventory.charTabs) do
    rect(b, { x = T.x + (i - 1) * (T.w + T.gap), y = T.y, w = T.w, h = T.h })
  end
end

-- Area the bag grid fills (9 columns x 7 visible rows).
Inventory.gridArea = CreateFrame("Frame", nil, frame)

-- Default spot: centred above the bottom HUD. The window shrinks when a large HUD scale leaves
-- less room, and never gets wider than the screen allows.
function Inventory.DefaultPlacement(screenW, H, hudH)
  local scale = ns.db and ns.db.invScale or 1
  local h = math.min(0.66 * H, H - hudH - 0.06 * H, 0.9 * screenW * S.h / S.w) * scale
  return "BOTTOM", 0, hudH + 0.02 * H, h
end

-- Where the player dragged the window, kept across sessions.
function Inventory.SavePosition()
  local point, _, relPoint, x, y = frame:GetPoint()
  if not point or not ns.db then return end
  ns.db.invPos = { point = point, relPoint = relPoint or point, x = x, y = y }
end

function Inventory.Layout()
  local W, H = UIParent:GetSize()
  local point, x, y, h = Inventory.DefaultPlacement(W, H, ns.HUD.h or 0.25 * H)
  frame:SetSize(h * S.w / S.h, h)
  if not frame.obPlaced then
    frame:ClearAllPoints()
    local pos = ns.db and ns.db.invPos
    if pos then
      frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
      frame:SetPoint(point, UIParent, point, x, y)
    end
    frame.obPlaced = true
  end
  rect(title, { x = 0, y = 0, w = S.w - 60, h = S.head })
  -- the name as wide as it is, the level and class right after it
  titleText:ClearAllPoints()
  titleText:SetPoint("LEFT", title, "LEFT", S.title.x * frame:GetWidth() / S.w, 0)
  setTitle()
  rect(Inventory.closeButton, S.close)
  rect(Inventory.hairline, { x = 20, y = S.head, w = S.w - 40, h = 1 })
  rect(Inventory.separator, { x = S.sep, y = S.head + 12, w = 1, h = S.h - S.head - 30 })
  rect(model, S.model)
  local inset = S.equipSize * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  for _, e in ipairs(equipLayout) do
    rect(e.b, { x = e.x, y = e.y, w = e.size, h = e.size })
    local px = e.b:GetWidth() * inset / e.size
    e.b.icon:ClearAllPoints()
    e.b.icon:SetPoint("TOPLEFT", e.b, "TOPLEFT", px, -px)
    e.b.icon:SetPoint("BOTTOMRIGHT", e.b, "BOTTOMRIGHT", -px, px)
  end
  local G = S.grid
  rect(Inventory.gridArea, { x = G.x, y = G.y, w = G.cols * (G.slot + G.gap) - G.gap,
    h = G.rows * (G.slot + G.gap) - G.gap })
  layoutStats()
  if Inventory.onLayout then Inventory.onLayout() end
  -- Resized while open (size setting): the stat rows are placed by updateStats.
  if frame:IsShown() then updateStats() end
end

-- The item buttons make the window protected on clients where their template is protected:
-- then it can only open/close out of combat.
local function safely(fn)
  if InCombatLockdown() and frame:IsProtected() then ns.RunOutOfCombat(fn) else fn() end
end

function Inventory.Open()
  safely(function()
    Inventory.Layout()
    frame:Show()
    updateEquipment()
    updateStats()
    stats:Show()
    updateItemLevel()
    if Inventory.onOpen then Inventory.onOpen() end
  end)
end

function Inventory.Close() safely(function() frame:Hide() end) end

function Inventory.Toggle()
  safely(function()
    if frame:IsShown() then Inventory.Close() else Inventory.Open() end
  end)
end

ns.On("PLAYER_EQUIPMENT_CHANGED", function() if frame:IsShown() then updateEquipment(); refreshModel() end end)
ns.On("PLAYER_LOGIN", setTitle)
ns.On("KNOWN_TITLES_UPDATE", setTitle)
ns.On("UNIT_NAME_UPDATE", function(_, unit) if unit == "player" then setTitle() end end)
ns.On("UNIT_MODEL_CHANGED", function(_, unit) if unit == "player" and frame:IsShown() then refreshModel() end end)
for _, ev in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RESISTANCES" }) do
  ns.On(ev, function(_, unit) if unit == "player" and frame:IsShown() then updateStats() end end)
end
for _, ev in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS" }) do
  ns.On(ev, function() if frame:IsShown() then updateStats() end end)
end

-- The keys bound to the character sheet (C) toggle this window instead, through an override
-- binding. The default sheet is never touched from here: hiding it from addon code tainted
-- Blizzard's panel manager and then no menu button could open its window.
-- Registered for both edges (the key may send a click on press, release or both); one toggle
-- per press.
local toggleButton = CreateFrame("Button", "ObsidianUIInventoryToggle", UIParent)
toggleButton:RegisterForClicks("AnyUp", "AnyDown")
local lastToggle = -1
local function toggleOncePerPress()
  local now = GetTime()
  if now - lastToggle < 0.3 then return end
  lastToggle = now
  Inventory.Toggle()
end
-- What each route did, for the character key report below.
local keyTrace = { click = 0, toggleCharacter = 0, forever = 0 }
Inventory.keyTrace = keyTrace
toggleButton:SetScript("OnClick", function() keyTrace.click = keyTrace.click + 1; toggleOncePerPress() end)
Inventory.toggleButton = toggleButton
local bindingOwner = CreateFrame("Frame")
local function bindCharacterKeys()
  ns.RunOutOfCombat(function()
    ClearOverrideBindings(bindingOwner)
    for _, key in ipairs({ GetBindingKey("TOGGLECHARACTER0") }) do
      -- Priority: it must win over any other override on the same key.
      SetOverrideBindingClick(bindingOwner, true, key, "ObsidianUIInventoryToggle")
    end
  end)
end
ns.On("PLAYER_LOGIN", bindCharacterKeys)
ns.On("UPDATE_BINDINGS", bindCharacterKeys)

-- WoW Forever binds the character key (and the character menu button) to its own character
-- window through ToggleWoWHackCharacterUI. Whenever such a window shows, it is hidden again
-- and this window toggles instead (once per press, shared with the key button above).
-- The function and its window may only exist after this file loads, so they are looked for
-- again on login, on every addon load and each time the game toggles the window. Any shown
-- frame named like the Forever character window counts (its exact name is not published).
local foreverHooked, watched, reported = false, {}, false
local function isForeverWindow(f)
  local name = f.GetName and f:GetName()
  return type(name) == "string" and name:find("WoWHack") ~= nil and name:find("Character") ~= nil
end
local function hideForeverWindow(win)
  if InCombatLockdown() and win:IsProtected() then return end
  win:Hide()
  toggleOncePerPress()
end
local function watchForeverWindows()
  local found = false
  local f = type(EnumerateFrames) == "function" and EnumerateFrames()
  while f do
    if not f:IsForbidden() and isForeverWindow(f) then
      found = true
      if not watched[f] then
        watched[f] = true
        f:HookScript("OnShow", hideForeverWindow)
      end
      if f:IsShown() then hideForeverWindow(f) end
    end
    f = EnumerateFrames(f)
  end
  return found
end
-- After the game's toggle: if no Forever window was found, name in chat the character
-- windows that are open, once, so the next fix knows what to hide.
local function afterForeverToggle()
  keyTrace.forever = keyTrace.forever + 1
  if watchForeverWindows() or reported then return end
  local names = {}
  local f = type(EnumerateFrames) == "function" and EnumerateFrames()
  while f do
    local name = not f:IsForbidden() and f:IsVisible() and f:GetName()
    if type(name) == "string" and name:find("Character") and f:GetParent() == UIParent then
      names[#names + 1] = name
    end
    f = EnumerateFrames(f)
  end
  reported = true
  print("|cffe8c46aObsidianUI|r: janela de personagem não identificada. Abertas: "
    .. (#names > 0 and table.concat(names, ", ") or "nenhuma") .. ". Mande este aviso para ajuste.")
end
local function hookForeverToggle()
  if not foreverHooked and type(rawget(_G, "ToggleWoWHackCharacterUI")) == "function" then
    foreverHooked = true
    hooksecurefunc("ToggleWoWHackCharacterUI", afterForeverToggle)
  end
  watchForeverWindows()
end
Inventory.HookForeverToggle = hookForeverToggle
hookForeverToggle()
ns.On("PLAYER_LOGIN", hookForeverToggle)
ns.On("ADDON_LOADED", hookForeverToggle)
ns.On("PLAYER_ENTERING_WORLD", hookForeverToggle)

-- The character key and the character menu button call ToggleCharacter with the character
-- page. That page is flagged "hidden" (only ToggleCharacter reads the flag, and then does
-- nothing), and a post-hook toggles this window instead. Blizzard's sheet is never hidden from
-- here: that tainted the panel manager and broke every menu button. Its other pages
-- (reputation, currency) open normally.
local characterHooked = false
local function claimCharacterPage()
  local page = rawget(_G, "PaperDollFrame")
  if type(page) == "table" then page.hidden = true end
  if not characterHooked and type(rawget(_G, "ToggleCharacter")) == "function" then
    characterHooked = true
    hooksecurefunc("ToggleCharacter", function(tab)
      keyTrace.toggleCharacter = keyTrace.toggleCharacter + 1
      if tab == "PaperDollFrame" then toggleOncePerPress() end
    end)
  end
end
claimCharacterPage()
ns.On("PLAYER_LOGIN", claimCharacterPage)
ns.On("ADDON_LOADED", claimCharacterPage)

-- Once in the world, check the character key really clicks our button; if not, say in chat
-- what holds it (so it can be fixed without the player typing anything).
local checked = false
ns.On("PLAYER_ENTERING_WORLD", function()
  if checked then return end
  checked = true
  C_Timer.After(2, function()
    local expected = "CLICK ObsidianUIInventoryToggle:LeftButton"
    local keys = { GetBindingKey("TOGGLECHARACTER0") }
    if #keys == 0 then
      print("|cffe8c46aObsidianUI|r: nenhuma tecla em TOGGLECHARACTER0 (personagem).")
      return
    end
    for _, key in ipairs(keys) do
      local action = GetBindingAction(key, true)
      if action ~= expected then
        print("|cffe8c46aObsidianUI|r: a tecla " .. tostring(key) .. " ainda abre " .. tostring(action)
          .. " (esperado: inventário do addon). Mande este aviso para ajuste.")
      end
    end
  end)
end)
