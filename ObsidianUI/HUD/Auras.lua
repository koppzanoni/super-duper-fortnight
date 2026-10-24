local _, ns = ...

-- Player buffs (top row) and debuffs (row below), centered at the top of the screen; movable in
-- the edit mode. Icon size, icons per row and each row on/off come from the Auras page.
-- Plain buttons: WoW Forever loads as game type "camelot", where Blizzard's secure aura
-- header (classic only) does not exist. Being insecure, the rows can re-center in combat too;
-- right click cancels a buff out of combat.
local M = ns.MediaManifest
local NEUTRAL, RED = { 1, 1, 1 }, { 0.77, 0.15, 0.11 }
local ROWS = 2
-- Size of an icon, the step between icons, icons per row, the step between rows: from the settings.
local function dims()
  local db = ns.db or {}
  local size = db.buffSize or 26
  return size, size + 4, db.buffRow or 16, size + 16
end
local function shown(filter)
  local key = filter == "HELPFUL" and "buffs_on" or "debuffs_on"
  return not (ns.db and ns.db[key] == false)
end
local Auras = { count = { HELPFUL = 0, HARMFUL = 0 }, rows = {} }
ns.Auras = Auras

-- x of the i-th of n icons in a row centered on the anchor (wrapping after WRAP).
function Auras.OffsetX(i, n)
  local _, STEP, WRAP = dims()
  local col = (i - 1) % WRAP
  local inRow = math.min(WRAP, n - (i - 1 - col))
  return ns.Data.AuraRowOffset(inRow, WRAP, STEP) + col * STEP
end

local function makeButton(row)
  local b = CreateFrame("Button", nil, row)
  b:RegisterForClicks("RightButtonUp")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the action slots' frame around the icon; debuffs tint it with their dispel type
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  ns.Media.Apply(b.border, ns.ModernTex("mod_slot"))
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
  local c = filter == "HARMFUL" and RED or NEUTRAL
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
  local SIZE, _, WRAP, ROW_STEP = dims()
  local list = shown(filter) and ns.Data.UnitAuraList("player", filter, WRAP * ROWS) or {}
  local inset = SIZE * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  for i, aura in ipairs(list) do
    local b = row.buttons[i] or makeButton(row)
    row.buttons[i] = b
    b:SetSize(SIZE, SIZE)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
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
Auras.Update = updateAll

-- The debuff row hangs under the buff rows (a child: they move and resize together).
local buffs = CreateFrame("Frame", "ObsidianUIAurasHELPFUL", UIParent)
buffs.buttons = {}
local debuffs = CreateFrame("Frame", "ObsidianUIAurasHARMFUL", buffs)
debuffs:SetSize(1, 1)
debuffs.buttons = {}
local function sizeRows()
  local SIZE, STEP, WRAP, ROW_STEP = dims()
  local drop = ROWS * ROW_STEP + 6
  buffs:SetSize(WRAP * STEP, drop + SIZE)
  debuffs:ClearAllPoints()
  debuffs:SetPoint("TOP", buffs, "TOP", 0, -drop)
end
Auras.rows.HELPFUL, Auras.rows.HARMFUL = buffs, debuffs

local function layout()
  local _, H = UIParent:GetSize()
  sizeRows()
  ns.Movers.Register("buffs", "Buffs e debuffs", buffs, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -0.025 * H / f:GetScale())
  end, { base = function() return H / 900 end })
  ns.Movers.Place("buffs")
end

ns.On("PLAYER_LOGIN", function() layout(); updateAll() end)
table.insert(ns.HUD.onResize, function() layout(); updateAll() end)
ns.On("PLAYER_ENTERING_WORLD", updateAll)
ns.On("UNIT_AURA", function(_, unit) if unit == "player" then updateAll() end end)
