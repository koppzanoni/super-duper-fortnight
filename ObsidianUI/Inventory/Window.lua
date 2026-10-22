local _, ns = ...

-- Unified inventory window: 3D player model, 8+8 equipment slots, 3 square weapon slots,
-- collapsible stats column. The bag grid is added by BagGrid.lua into Inventory.gridArea (spec 4.10).
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
title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
local titleText = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetAllPoints(title)
titleText:SetText("PERSONAGEM")
titleText:SetTextColor(0.91, 0.77, 0.42)

-- 3D model of the player, transparent background, drag to rotate, wheel to zoom.
local model = CreateFrame("PlayerModel", nil, frame)
model:EnableMouse(true)
model:EnableMouseWheel(true)
local zoom, dragging, lastX = 0, false, 0
model:SetScript("OnShow", function(self) self:SetUnit("player"); self:SetPortraitZoom(zoom) end)
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

-- Collapsible stats column.
local stats = CreateFrame("Frame", nil, frame, "BackdropTemplate")
stats:SetWidth(180)
stats:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, -40)
stats:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -4, 40)
if stats.SetBackdrop then
  stats:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  stats:SetBackdropColor(0.086, 0.09, 0.106, 0.95)
  stats:SetBackdropBorderColor(0.54, 0.43, 0.23)
end
stats:Hide()
local statsText = stats:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
statsText:SetPoint("TOPLEFT", 10, -10)
statsText:SetPoint("RIGHT", -10, 0)
statsText:SetJustifyH("LEFT")
statsText:SetSpacing(4)

local STAT_NAMES = { "Força", "Agilidade", "Vigor", "Intelecto", "Espírito" }
local function updateStats()
  local lines = {}
  for i = 1, 5 do
    local ok, value = pcall(UnitStat, "player", i)
    if ok and value then lines[#lines + 1] = STAT_NAMES[i] .. ": |cffffffff" .. value .. "|r" end
  end
  local okA, _, armor = pcall(UnitArmor, "player")
  if okA and armor then lines[#lines + 1] = "Armadura: |cffffffff" .. armor .. "|r" end
  if GetCritChance then lines[#lines + 1] = string.format("Crítico: |cffffffff%.1f%%|r", GetCritChance()) end
  if GetHaste then lines[#lines + 1] = string.format("Aceleração: |cffffffff%.1f%%|r", GetHaste()) end
  if GetMasteryEffect then lines[#lines + 1] = string.format("Maestria: |cffffffff%.1f%%|r", (GetMasteryEffect())) end
  statsText:SetText(table.concat(lines, "\n"))
end

local function smallButton(label, onClick)
  local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  b:SetText(label)
  b:SetSize(84, 20)
  b:SetScript("OnClick", onClick)
  return b
end
local statsButton = smallButton("Atributos", function() stats:SetShown(not stats:IsShown()); updateStats() end)
local repButton = smallButton("Reputação", function() ToggleCharacter("ReputationFrame") end)
local tokenButton = smallButton("Moedas", function() ToggleCharacter("TokenFrame") end)
statsButton:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 8, 2)
repButton:SetPoint("LEFT", statsButton, "RIGHT", 4, 0)
tokenButton:SetPoint("LEFT", repButton, "RIGHT", 4, 0)

-- Area the bag grid fills (8 columns x 6 visible rows).
Inventory.gridArea = CreateFrame("Frame", nil, frame)

function Inventory.Layout()
  local _, H = UIParent:GetSize()
  local h = 0.72 * H
  frame:SetSize(h * S.w / S.h, h)
  if not frame.obPlaced then
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -0.12 * H, 0)
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

function Inventory.Open()
  Inventory.Layout()
  frame:Show()
  updateEquipment()
  if Inventory.onOpen then Inventory.onOpen() end
end

function Inventory.Close() frame:Hide() end

function Inventory.Toggle()
  if frame:IsShown() then Inventory.Close() else Inventory.Open() end
end

ns.On("PLAYER_EQUIPMENT_CHANGED", function() if frame:IsShown() then updateEquipment(); model:SetUnit("player") end end)
ns.On("UNIT_MODEL_CHANGED", function(_, unit) if unit == "player" and frame:IsShown() then model:SetUnit("player") end end)
ns.On("UNIT_STATS", function(_, unit) if unit == "player" and stats:IsShown() then updateStats() end end)

-- C opens the unified window instead of the default character sheet (other tabs stay Blizzard's).
hooksecurefunc("ToggleCharacter", function(tab)
  if tab == "PaperDollFrame" then
    if CharacterFrame and CharacterFrame:IsShown() then HideUIPanel(CharacterFrame) end
    Inventory.Toggle()
  end
end)
