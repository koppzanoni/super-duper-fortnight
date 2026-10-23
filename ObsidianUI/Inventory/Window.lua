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
-- The character's name on the title plate.
function Inventory.TitleText()
  return UnitName("player") or "PERSONAGEM"
end
titleText:SetText(Inventory.TitleText())
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
  if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, db.modelDistance or 0.85) end
  if model.SetPosition then pcall(model.SetPosition, model, 0, 0, db.modelHeight or 0) end
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

-- Stats panel, docked left of the window and open with it: sections of label/value rows,
-- then the Reputation and Currency buttons.
local W = ns.Widgets
local PANEL_W, PAD, ROW_H, HEADER_H, BUTTON_H = 200, 12, 16, 24, 22
local stats = CreateFrame("Frame", nil, frame, "BackdropTemplate")
W.Panel(stats)
stats:SetWidth(PANEL_W)
stats:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, -40)
Inventory.statsPanel = stats

local statsTitle = stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statsTitle:SetPoint("TOP", 0, -PAD)
statsTitle:SetText("ATRIBUTOS")
statsTitle:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])

local lines = {}
local function line(i)
  if lines[i] then return lines[i] end
  local l = {}
  l.label = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  l.label:SetJustifyH("LEFT")
  l.value = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  l.value:SetJustifyH("RIGHT")
  l.divider = stats:CreateTexture(nil, "ARTWORK")
  l.divider:SetHeight(1)
  l.divider:SetColorTexture(W.BRONZE[1], W.BRONZE[2], W.BRONZE[3], 0.6)
  lines[i] = l
  return l
end

Inventory.repButton = W.Button(stats, "Reputação", function() ToggleCharacter("ReputationFrame") end)
Inventory.tokenButton = W.Button(stats, "Moedas", function() ToggleCharacter("TokenFrame") end)

local function updateStats()
  local rows = ns.Stats.Rows(ns.Stats.GameAPI())
  local y = PAD + 18
  for i, r in ipairs(rows) do
    local l = line(i)
    l.label:ClearAllPoints()
    l.value:ClearAllPoints()
    l.divider:ClearAllPoints()
    if r.header then
      l.label:SetPoint("TOPLEFT", PAD, -(y + 6))
      l.label:SetText(r.header)
      l.label:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
      l.value:SetText("")
      l.divider:SetPoint("TOPLEFT", PAD, -(y + 20))
      l.divider:SetPoint("TOPRIGHT", -PAD, -(y + 20))
      l.divider:Show()
      y = y + HEADER_H
    else
      l.label:SetPoint("TOPLEFT", PAD, -y)
      l.label:SetText(r.label)
      l.label:SetTextColor(W.TEXT[1], W.TEXT[2], W.TEXT[3])
      l.value:SetPoint("TOPRIGHT", -PAD, -y)
      l.value:SetText(r.value)
      l.divider:Hide()
      y = y + ROW_H
    end
    l.label:Show()
    l.value:Show()
  end
  for i = #rows + 1, #lines do
    lines[i].label:Hide(); lines[i].value:Hide(); lines[i].divider:Hide()
  end

  local bw = (PANEL_W - 2 * PAD - 6) / 2
  local rep, token = Inventory.repButton, Inventory.tokenButton
  rep:ClearAllPoints()
  rep:SetPoint("TOPLEFT", PAD, -(y + 10))
  rep:SetSize(bw, BUTTON_H)
  token:ClearAllPoints()
  token:SetPoint("LEFT", rep, "RIGHT", 6, 0)
  token:SetSize(bw, BUTTON_H)
  stats:SetHeight(y + 10 + BUTTON_H + PAD)
end

-- Area the bag grid fills (8 columns x 6 visible rows).
Inventory.gridArea = CreateFrame("Frame", nil, frame)

-- Default spot: above the bottom HUD and left of the minimap, never under either of them.
-- The window shrinks when a large HUD scale leaves less room.
function Inventory.DefaultPlacement(W, H, hudH)
  local h = math.min(0.72 * H, H - hudH - 0.06 * H)
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
  rect(model, S.model)
  for _, e in ipairs(equipLayout) do rect(e.b, { x = e.x, y = e.y, w = e.size, h = e.size }) end
  local cols, rows = S.gridCols, S.gridRows
  rect(Inventory.gridArea, { x = cols[1], y = rows[1], w = cols[#cols] + S.gridSlot - cols[1],
    h = rows[#rows] + S.gridSlot - rows[1] })
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
ns.On("PLAYER_LOGIN", function() titleText:SetText(Inventory.TitleText()) end)
ns.On("UNIT_NAME_UPDATE", function(_, unit) if unit == "player" then titleText:SetText(Inventory.TitleText()) end end)
ns.On("UNIT_MODEL_CHANGED", function(_, unit) if unit == "player" and frame:IsShown() then refreshModel() end end)
for _, ev in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RESISTANCES" }) do
  ns.On(ev, function(_, unit) if unit == "player" and frame:IsShown() then updateStats() end end)
end
for _, ev in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS" }) do
  ns.On(ev, function() if frame:IsShown() then updateStats() end end)
end

-- C opens the unified window instead of the default character sheet (other tabs stay Blizzard's).
hooksecurefunc("ToggleCharacter", function(tab)
  if tab == "PaperDollFrame" then
    if CharacterFrame and CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
    Inventory.Toggle()
  end
end)
