local _, ns = ...

-- Player buffs (top row) and debuffs (row below), centered at the top of the screen (spec 4.8).
-- Plain buttons: WoW Forever loads as game type "camelot", where Blizzard's secure aura
-- header (classic only) does not exist. Being insecure, the rows can re-center in combat too;
-- right click cancels a buff out of combat.
local M = ns.MediaManifest
local BRONZE, RED = { 0.54, 0.43, 0.23 }, { 0.77, 0.15, 0.11 }
local SIZE, STEP, WRAP, ROWS, ROW_STEP = 26, 30, 16, 2, 42
local Auras = { count = { HELPFUL = 0, HARMFUL = 0 }, rows = {} }
ns.Auras = Auras

-- x of the i-th of n icons in a row centered on the anchor (wrapping after WRAP).
function Auras.OffsetX(i, n)
  local col = (i - 1) % WRAP
  local inRow = math.min(WRAP, n - (i - 1 - col))
  return ns.Data.AuraRowOffset(inRow, WRAP, STEP) + col * STEP
end

local function makeButton(row)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(SIZE, SIZE)
  b:RegisterForClicks("RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  b.border:SetTexture(M.aura_border.file)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b)
  b.cd:SetReverse(true)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", 1, 0)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if self.auraInstanceID and GameTooltip.SetUnitBuffByAuraInstanceID and self.filter == "HELPFUL" then
      GameTooltip:SetUnitBuffByAuraInstanceID("player", self.auraInstanceID, self.filter)
    elseif self.auraInstanceID and GameTooltip.SetUnitDebuffByAuraInstanceID and self.filter == "HARMFUL" then
      GameTooltip:SetUnitDebuffByAuraInstanceID("player", self.auraInstanceID, self.filter)
    else
      GameTooltip:SetUnitAura("player", self.index, self.filter)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", function(self)
    if self.filter == "HELPFUL" and not InCombatLockdown() and CancelUnitBuff then
      pcall(CancelUnitBuff, "player", self.index, self.filter)
    end
  end)
  return b
end


local function setAura(b, aura, filter, index)
  b.filter, b.index, b.auraInstanceID = filter, index, aura.auraInstanceID
  b.icon:SetTexture(aura.icon)
  local c = filter == "HARMFUL" and RED or BRONZE
  if filter == "HARMFUL" then
    local ok, r, g, bl = pcall(ns.Data.DebuffColor, aura.dispelName)
    if ok then c = { r, g, bl } end
  end
  b.border:SetVertexColor(c[1], c[2], c[3])
  if not pcall(function() b.count:SetText(aura.applications > 1 and aura.applications or "") end) then
    b.count:SetText("")
  end
  local ok = false
  if C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
    local dur = C_UnitAuras.GetAuraDuration("player", aura.auraInstanceID)
    ok = dur ~= nil and pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)
  end
  if not ok and not pcall(function()
    if aura.duration > 0 then b.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration) else b.cd:Clear() end
  end) then
    b.cd:Clear()
  end
end

local function update(filter)
  local row = Auras.rows[filter]
  local list = ns.Data.UnitAuraList("player", filter, WRAP * ROWS)
  for i, aura in ipairs(list) do
    local b = row.buttons[i] or makeButton(row)
    row.buttons[i] = b
    b:ClearAllPoints()
    b:SetPoint("TOP", row, "TOP", Auras.OffsetX(i, #list), -math.floor((i - 1) / WRAP) * ROW_STEP)
    setAura(b, aura, filter, i)
    b:Show()
  end
  for i = #list + 1, #row.buttons do row.buttons[i]:Hide() end
  Auras.count[filter] = #list
end

local function updateAll()
  update("HELPFUL")
  update("HARMFUL")
end

for filter, y in pairs({ HELPFUL = 0.025, HARMFUL = 0.095 }) do
  local row = CreateFrame("Frame", "ObsidianUIAuras" .. filter, UIParent)
  row:SetSize(1, 1)
  row.buttons, row.y = {}, y
  Auras.rows[filter] = row
end

local function layout()
  local _, H = UIParent:GetSize()
  local scale = H / 900
  for _, row in pairs(Auras.rows) do
    row:SetScale(scale)
    row:ClearAllPoints()
    row:SetPoint("TOP", UIParent, "TOP", 0, -row.y * H / scale)
  end
end

ns.On("PLAYER_LOGIN", function() layout(); updateAll() end)
ns.On("PLAYER_ENTERING_WORLD", updateAll)
ns.On("UNIT_AURA", function(_, unit) if unit == "player" then updateAll() end end)
table.insert(ns.HUD.onResize, layout)
