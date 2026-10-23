local _, ns = ...

-- Unified inventory window: 3D player model, 8+8 equipment slots, 3 square weapon slots,
-- stats panel. The bag grid is added by BagGrid.lua into Inventory.gridArea (spec 4.10).
local S = ns.Data.INV
local M = ns.MediaManifest
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

local art = frame:CreateTexture(nil, "BACKGROUND")
art:SetAllPoints(frame)

local function rect(region, r)
  local w, h = frame:GetSize()
  local x, y, rw, rh = ns.Layout.Rect(S.w, S.h, w, h, r.x, r.y, r.w, r.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
end

-- Title plate doubles as the drag handle.
local title = CreateFrame("Frame", nil, frame)
title:EnableMouse(true)
title:RegisterForDrag("LeftButton")
title:SetScript("OnDragStart", function() frame:StartMoving() end)
title:SetScript("OnDragStop", function()
  frame:StopMovingOrSizing()
  Inventory.SavePosition()
end)
local titleText = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetAllPoints(title)
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
  if type(textW) == "number" and type(plateW) == "number" and textW > plateW * 0.9 then
    titleText:SetFontObject("GameFontNormal")
  end
end
setTitle()
titleText:SetTextColor(0.91, 0.77, 0.42)

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

-- Equipment slots.
local slotButtons = {}
local function qualityColor(q)
  local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
  return 0.54, 0.43, 0.23
end

local function slotButton(slotName)
  local ok, slotID = pcall(GetInventorySlotInfo, slotName)
  if not ok or not slotID then return nil end
  local b = CreateFrame("Button", nil, frame)
  b.slotID = slotID
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  b.border:SetTexture(M.aura_border.file)
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
    if not GameTooltip:SetInventoryItem("player", self.slotID) then GameTooltip:SetText(_G[slotName:upper()] or slotName) end
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
  if b then equipLayout[#equipLayout + 1] = { b = b, x = S.weapons[i] + S.weaponInset, y = S.weaponY + S.weaponInset,
    size = S.weaponSize - 2 * S.weaponInset } end
end

local function updateEquipment()
  for _, b in ipairs(slotButtons) do
    local tex = GetInventoryItemTexture("player", b.slotID)
    b.icon:SetTexture(tex)
    b.icon:SetShown(tex ~= nil)
    b.border:SetShown(tex ~= nil)
    if tex then b.border:SetVertexColor(qualityColor(GetInventoryItemQuality("player", b.slotID))) end
  end
end

-- Stats wing: part of the window, on its left (art: tools/inventory_art.py). Its right pillar
-- hides under the window's left pillar. Everything in it is placed in wing art pixels and
-- scales with the window: title plate, sections of label/value rows, then (from BagGrid) the
-- bag search, and the Reputation and Currency buttons at the bottom.
local W = ns.Widgets
local WG = S.wing
local stats = CreateFrame("Frame", nil, frame)
stats:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
local wingArt = stats:CreateTexture(nil, "BACKGROUND")
wingArt:SetAllPoints(stats)
Inventory.statsPanel = stats

-- Place a region in the wing by its art pixels.
local wingUnit = 1
function Inventory.PlaceInWing(region, x, y, w, h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", stats, "TOPLEFT", x * wingUnit, -y * wingUnit)
  if w then region:SetSize(w * wingUnit, h * wingUnit) end
end

local statsTitle = stats:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
statsTitle:SetText("ATRIBUTOS")
statsTitle:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])

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
local function line(i)
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
  l.value = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  l.value:SetJustifyH("RIGHT")
  l.divider = stats:CreateTexture(nil, "ARTWORK")
  l.divider:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 0.7)
  lines[i] = l
  return l
end

Inventory.repButton = W.Button(stats, "Reputação", nil, "CharacterFrameTab2")
Inventory.tokenButton = W.Button(stats, "Moedas", nil, "CharacterFrameTab3")

local function updateStats()
  local R = WG.rows
  local rows = ns.Stats.Rows(ns.Stats.GameAPI())
  local y = R.top
  for i, r in ipairs(rows) do
    local l = line(i)
    if r.header then
      if i > 1 then y = y + R.gap end
      l.label:SetFontObject("GameFontNormalLarge")
      l.label:SetText(r.header)
      l.label:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
      Inventory.PlaceInWing(l.label, R.x0, y)
      l.value:SetText("")
      Inventory.PlaceInWing(l.divider, R.x0, y + R.header - 8, R.x1 - R.x0, 2)
      l.divider:Show()
      l.key, l.index = nil, nil
      l.hover:Hide()
      y = y + R.header
    else
      l.label:SetFontObject("GameFontHighlight")
      l.label:SetText(r.label)
      l.label:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
      Inventory.PlaceInWing(l.label, R.x0, y)
      l.value:SetText(r.value)
      l.value:ClearAllPoints()
      l.value:SetPoint("TOPRIGHT", stats, "TOPLEFT", R.x1 * wingUnit, -y * wingUnit)
      l.divider:Hide()
      l.key, l.index, l.labelText, l.valueText = r.key, r.index, r.label, r.value
      Inventory.PlaceInWing(l.hover, R.x0, y - 4, R.x1 - R.x0, R.row)
      l.hover:Show()
      y = y + R.row
    end
    l.label:Show()
    l.value:Show()
  end
  for i = #rows + 1, #lines do
    lines[i].label:Hide(); lines[i].value:Hide(); lines[i].divider:Hide(); lines[i].hover:Hide()
  end
end

local function layoutWing()
  wingUnit = frame:GetWidth() / S.w
  stats:ClearAllPoints()
  stats:SetPoint("TOPRIGHT", frame, "TOPLEFT", WG.overlap * wingUnit, 0)
  stats:SetSize(WG.w * wingUnit, frame:GetHeight())
  -- Keep the wing on screen too when the window is dragged to the left edge.
  frame:SetClampRectInsets(-(WG.w - WG.overlap) * wingUnit, 0, 0, 0)
  ns.Media.Apply(wingArt, "inventory_wing")
  local T = WG.title
  Inventory.PlaceInWing(statsTitle, T.x, T.y, T.w, T.h)
  local B = WG.buttons
  local bw = (B.x1 - B.x0 - B.gap) / 2
  Inventory.PlaceInWing(Inventory.repButton, B.x0, B.y, bw, B.h)
  Inventory.PlaceInWing(Inventory.tokenButton, B.x0 + bw + B.gap, B.y, bw, B.h)
end

-- Area the bag grid fills (8 columns x 6 visible rows).
Inventory.gridArea = CreateFrame("Frame", nil, frame)

-- Default spot: above the bottom HUD and left of the minimap, never under either of them.
-- The window shrinks when a large HUD scale leaves less room.
function Inventory.DefaultPlacement(W, H, hudH)
  local scale = ns.db and ns.db.invScale or 1
  local h = math.min(0.74 * H, H - hudH - 0.04 * H) * scale
  return "BOTTOMRIGHT", -0.27 * H, hudH + 0.02 * H, h
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
  ns.Media.Apply(art, "inventory")
  rect(title, S.title)
  setTitle()
  rect(model, S.model)
  for _, e in ipairs(equipLayout) do rect(e.b, { x = e.x, y = e.y, w = e.size, h = e.size }) end
  local cols, rows = S.gridCols, S.gridRows
  rect(Inventory.gridArea, { x = cols[1], y = rows[1], w = cols[#cols] + S.gridSlot - cols[1],
    h = rows[#rows] + S.gridSlot - rows[1] })
  layoutWing()
  if Inventory.onLayout then Inventory.onLayout() end
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
ns.On("PLAYER_TITLE_CHANGED", setTitle)
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
toggleButton:SetScript("OnClick", function()
  local now = GetTime()
  if now - lastToggle < 0.3 then return end
  lastToggle = now
  Inventory.Toggle()
end)
Inventory.toggleButton = toggleButton
local bindingOwner = CreateFrame("Frame")
local function bindCharacterKeys()
  ns.RunOutOfCombat(function()
    ClearOverrideBindings(bindingOwner)
    for _, key in ipairs({ GetBindingKey("TOGGLECHARACTER0") }) do
      SetOverrideBindingClick(bindingOwner, false, key, "ObsidianUIInventoryToggle")
    end
  end)
end
ns.On("PLAYER_LOGIN", bindCharacterKeys)
ns.On("UPDATE_BINDINGS", bindCharacterKeys)
