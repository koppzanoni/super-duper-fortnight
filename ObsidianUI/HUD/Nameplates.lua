local _, ns = ...

-- Nameplates in the Moderno look, drawn over the game's own plates (whose unit frame turns
-- invisible): a thin health bar on a black backing with a light rim, the name above it, the
-- health percent inside, the raid marker on the left, the player's debuffs above the name and a
-- cast bar under it (blue, grey when it cannot be interrupted). The target gets the arcane purple
-- rim; the others fade a little while there is a target. Plates the game keeps from addons
-- (friendly ones in instances) and your own resource plate stay as the game draws them.
-- Combat may hide values from addons: health goes straight into the bar, the rest runs in pcall
-- and is left out when it cannot be read.
local Nameplates = { plates = {} }
ns.Nameplates = Nameplates

local W = ns.Widgets
local MARKER_TEX = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local CAST_BLUE, CAST_LOCKED = { 0.09, 0.52, 0.96 }, { 0.55, 0.57, 0.6 }
local MAX_DEBUFFS = 4
local targetPlate

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end

-- ------------------------------------------------------------------ building one plate
local function bar(parent)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetMinMaxValues(0, 1)
  b.backing = b:CreateTexture(nil, "BACKGROUND")
  b.backing:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  b.backing:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  b.backing:SetColorTexture(0, 0, 0, 0.75)
  b.rim = W.Rim1(b, "BORDER")
  return b
end

local function build(base)
  local p = CreateFrame("Frame", nil, base)
  p:SetFrameStrata("BACKGROUND")
  p.health = bar(p)
  -- the target's rim: four purple edges just outside the bar
  p.glow = CreateFrame("Frame", nil, p.health)
  p.glow:SetPoint("TOPLEFT", p.health, "TOPLEFT", -2, 2)
  p.glow:SetPoint("BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 2, -2)
  for _, t in ipairs(W.Rim1(p.glow, "OVERLAY")) do t:SetColorTexture(W.ACCENT[1], W.ACCENT[2], W.ACCENT[3], 1) end
  p.glow:Hide()
  p.name = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  p.name:SetPoint("BOTTOM", p.health, "TOP", 0, 3)
  p.name:SetWordWrap(false)
  p.hp = p.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  p.hp:SetPoint("RIGHT", p.health, "RIGHT", -3, 0)
  p.marker = p:CreateTexture(nil, "OVERLAY")
  p.marker:SetTexture(MARKER_TEX)
  p.marker:SetPoint("RIGHT", p.health, "LEFT", -4, 0)
  p.marker:Hide()
  p.cast = bar(p)
  p.cast:SetPoint("TOPLEFT", p.health, "BOTTOMLEFT", 0, -3)
  p.cast:SetPoint("TOPRIGHT", p.health, "BOTTOMRIGHT", 0, -3)
  p.cast.text = p.cast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  p.cast.text:SetPoint("CENTER", p.cast, "CENTER", 0, 0)
  p.cast.icon = p.cast:CreateTexture(nil, "OVERLAY")
  p.cast.icon:SetPoint("RIGHT", p.cast, "LEFT", -2, 0)
  p.cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  p.cast:Hide()
  p.debuffs = {}
  for i = 1, MAX_DEBUFFS do
    local d = CreateFrame("Frame", nil, p)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.border = d:CreateTexture(nil, "OVERLAY")
    d.border:SetAllPoints(d)
    ns.Media.Apply(d.border, ns.ModernTex("mod_slot"))
    d.count = d:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    d.count:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
    d:Hide()
    p.debuffs[i] = d
  end
  return p
end

local function size(p)
  local w, h = db().plateW or 140, db().plateH or 10
  p:SetSize(w, h)
  p.health:ClearAllPoints()
  p.health:SetPoint("CENTER", p, "CENTER", 0, 0)
  p.health:SetSize(w, h)
  p.health:SetStatusBarTexture(ns.Look.BarTexture())
  p.cast:SetHeight(math.max(6, h * 0.8))
  p.cast:SetStatusBarTexture(ns.Look.BarTexture())
  p.cast.icon:SetSize(math.max(6, h * 0.8), math.max(6, h * 0.8))
  ns.Look.SetFont(p.name, math.max(9, h))
  ns.Look.SetFont(p.hp, math.max(8, h * 0.8))
  ns.Look.SetFont(p.cast.text, math.max(8, h * 0.75))
  p.name:SetWidth(w + 20)
  p.marker:SetSize(h * 1.6, h * 1.6)
  local ds = math.max(14, h * 2)
  for i, d in ipairs(p.debuffs) do
    d:SetSize(ds, ds)
    local inset = ds * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
    d.icon:ClearAllPoints()
    d.icon:SetPoint("TOPLEFT", d, "TOPLEFT", inset, -inset)
    d.icon:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -inset, inset)
    d:ClearAllPoints()
    d:SetPoint("BOTTOMLEFT", p.health, "TOPLEFT", (i - 1) * (ds + 2), h + 6)
    ns.Look.SetFont(d.count, math.max(8, ds * 0.42))
  end
end

-- ------------------------------------------------------------------ values
local function healthColor(unit)
  local ok, r, g, b = pcall(function()
    if UnitIsTapDenied(unit) then return 0.5, 0.5, 0.5 end
    if UnitIsPlayer(unit) then
      local _, class = UnitClass(unit)
      local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      if c then return c.r, c.g, c.b end
    end
    local reaction = UnitReaction(unit, "player")
    local key = reaction == 4 and "neutral" or ((reaction or 0) >= 5 and "friendly" or "hostile")
    local lr, lg, lb = ns.Look.Color(key)
    if lr then return lr, lg, lb end
    return ns.Data.HealthColor(false, nil, reaction)
  end)
  if ok and type(r) == "number" then return r, g, b end
end

local function updateHealth(p)
  local unit = p.unit
  p.health:SetMinMaxValues(0, UnitHealthMax(unit))
  p.health:SetValue(UnitHealth(unit))
  local r, g, b = healthColor(unit)
  if r then p.health:SetStatusBarColor(r, g, b) end
  p.hp:SetShown(on("plateHP"))
  local curve = CurveConstants and CurveConstants.ScaleTo100
  if not (UnitHealthPercent and pcall(function() p.hp:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, curve)) end)) then
    p.hp:SetText("")
  end
end

local function updateName(p)
  p.name:SetText(UnitName(p.unit) or "")
end

local function updateMarker(p)
  if not pcall(function()
    local index = GetRaidTargetIndex(p.unit)
    p.marker:SetShown(index ~= nil)
    if index then SetRaidTargetIconTexture(p.marker, index) end
  end) then p.marker:Hide() end
end

local function updateDebuffs(p)
  local list = {}
  if on("plateDebuffs") then
    local ok, got = pcall(ns.Data.UnitAuraList, p.unit, "HARMFUL|PLAYER", MAX_DEBUFFS)
    if ok then list = got end
  end
  for i, d in ipairs(p.debuffs) do
    local aura = list[i]
    d:SetShown(aura ~= nil)
    if aura then
      d.icon:SetTexture(aura.icon)
      if not pcall(function() d.count:SetText((aura.applications or 0) > 1 and aura.applications or "") end) then
        d.count:SetText("")
      end
    end
  end
end

-- Target purple rim; the others a little faded while there is a target.
local function updateTarget(p)
  local isTarget = targetPlate ~= nil and p.base == targetPlate
  p.glow:SetShown(isTarget)
  local fade = on("plateFade") and targetPlate ~= nil and not isTarget
  p:SetAlpha(fade and 0.6 or 1)
end

-- ------------------------------------------------------------------ cast bar
local function castInfo(unit)
  local name, text, tex, startMS, endMS, _, _, locked = UnitCastingInfo(unit)
  if name then return name, text, tex, startMS, endMS, locked, false end
  name, text, tex, startMS, endMS, _, locked = UnitChannelInfo(unit)
  if name then return name, text, tex, startMS, endMS, locked, true end
end

local function castProgress(c)
  if not c.startT then return end
  local v = (GetTime() - c.startT) / (c.endT - c.startT)
  v = math.max(0, math.min(1, v))
  c:SetValue(c.channel and 1 - v or v)
end

local function updateCast(p)
  local c = p.cast
  local name, text, tex, startMS, endMS, locked, channel = castInfo(p.unit)
  if not name or not on("plateCast") then c:Hide(); c.startT = nil; return end
  c.text:SetText(text or name)
  c.icon:SetTexture(tex)
  local okLocked, isLocked = pcall(function() return locked == true end)
  local col = (okLocked and isLocked) and CAST_LOCKED or CAST_BLUE
  c:SetStatusBarColor(col[1], col[2], col[3])
  c.startT, c.channel = nil, channel
  c:SetMinMaxValues(0, 1)
  -- the game's own timer when it takes the duration; else from the cast times; else full
  local duration = channel and UnitChannelDuration and UnitChannelDuration(p.unit)
    or (not channel and UnitCastingDuration and UnitCastingDuration(p.unit))
  local direction = channel and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil
  if not (duration and c.SetTimerDuration and pcall(c.SetTimerDuration, c, duration, nil, direction)) then
    if pcall(function() c.startT, c.endT = startMS / 1000, endMS / 1000 end) then castProgress(c) else c:SetValue(1) end
  end
  c:Show()
end

-- ------------------------------------------------------------------ plates coming and going
local function gameFrame(base) return base and base.UnitFrame end

-- Keep the game's unit frame invisible while ours is on (the game sets its alpha again).
local function hideGame(base)
  local uf = gameFrame(base)
  if not uf then return end
  uf:SetAlpha(0)
  if not uf.obHooked then
    uf.obHooked = true
    hooksecurefunc(uf, "SetAlpha", function(self)
      if self.obSetting or not on("plates_on") then return end
      self.obSetting = true
      self:SetAlpha(0)
      self.obSetting = false
    end)
  end
end

local function showGame(base)
  local uf = gameFrame(base)
  if not uf then return end
  uf.obSetting = true
  uf:SetAlpha(1)
  uf.obSetting = false
end

local function isPersonal(base)
  return C_NamePlate.GetNamePlateForUnit("player") == base
end

local function refreshPlate(p)
  size(p)
  updateName(p)
  updateHealth(p)
  updateMarker(p)
  updateDebuffs(p)
  updateCast(p)
  updateTarget(p)
end

local function added(_, unit)
  local base = C_NamePlate.GetNamePlateForUnit(unit)
  if not base or isPersonal(base) then return end
  if not on("plates_on") then return end
  base.obPlate = base.obPlate or build(base)
  local p = base.obPlate
  p.base, p.unit = base, unit
  p:ClearAllPoints()
  p:SetPoint("CENTER", base, "CENTER", 0, 0)
  Nameplates.plates[unit] = p
  hideGame(base)
  refreshPlate(p)
  p:Show()
end

local function removed(_, unit)
  local p = Nameplates.plates[unit]
  if p then p:Hide(); p.cast.startT = nil end
  Nameplates.plates[unit] = nil
end

-- Settings changed: redraw every plate, or give the game its look back when switched off.
function Nameplates.Refresh()
  for unit, p in pairs(Nameplates.plates) do
    if on("plates_on") then
      hideGame(p.base)
      refreshPlate(p)
    else
      p:Hide()
      showGame(p.base)
      Nameplates.plates[unit] = nil
    end
  end
end

ns.On("NAME_PLATE_UNIT_ADDED", added)
ns.On("NAME_PLATE_UNIT_REMOVED", removed)
ns.On("PLAYER_TARGET_CHANGED", function()
  targetPlate = C_NamePlate.GetNamePlateForUnit("target")
  for _, p in pairs(Nameplates.plates) do updateTarget(p) end
end)
ns.On("RAID_TARGET_UPDATE", function() for _, p in pairs(Nameplates.plates) do updateMarker(p) end end)

local function forUnit(fn)
  return function(_, unit)
    local p = unit and Nameplates.plates[unit]
    if p then fn(p) end
  end
end
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_FACTION", "UNIT_FLAGS" }) do ns.On(ev, forUnit(updateHealth)) end
ns.On("UNIT_NAME_UPDATE", forUnit(updateName))
ns.On("UNIT_AURA", forUnit(updateDebuffs))
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE",
  "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
  ns.On(ev, forUnit(updateCast))
end

-- Cast bars timed from the cast times move here (the game's timer moves on its own).
CreateFrame("Frame"):SetScript("OnUpdate", function()
  for _, p in pairs(Nameplates.plates) do
    if p.cast.startT and p.cast:IsShown() then castProgress(p.cast) end
  end
end)
