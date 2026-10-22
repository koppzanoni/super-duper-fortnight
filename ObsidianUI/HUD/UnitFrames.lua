local _, ns = ...

-- Target (large), focus (small), target-of-target and pet (tiny). Static 2D portraits (user's choice).
local M = ns.MediaManifest
local UnitFrames = { frames = {} }
ns.UnitFrames = UnitFrames

local KINDS = {
  large = { spec = ns.Data.TARGET, tex = "target_frame", width = 0.46 },
  small = { spec = ns.Data.FOCUS, tex = "focus_frame", width = 0.20 },
  tiny = { spec = ns.Data.UNIT_SMALL, tex = "unit_small", width = 0.17 },
}
local CLASS_RING = { elite = { 0.64, 0.21, 0.93 }, worldboss = { 0.64, 0.21, 0.93 },
  rare = { 0.75, 0.75, 0.75 }, rareelite = { 0.75, 0.75, 0.75 } }
local CLASS_LABEL = { elite = "Elite", worldboss = "Chefe", rare = "Raro", rareelite = "Raro Elite" }

local function statusBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture(M.bar_fill.file)
  bar:SetMinMaxValues(0, 1)
  return bar
end

local function setRect(region, owner, spec, rect, w, h)
  local x, y, rw, rh = ns.Layout.Rect(spec.w, spec.h, w, h, rect.x, rect.y, rect.w, rect.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", owner, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
end

function UnitFrames.Create(unit, kind)
  local k = KINDS[kind]
  local f = CreateFrame("Button", "ObsidianUI_" .. unit, UIParent, "SecureUnitButtonTemplate")
  f:SetFrameStrata("LOW")
  f:SetAttribute("unit", unit)
  f:SetAttribute("type1", "target")
  f:SetAttribute("type2", "togglemenu")
  f:RegisterForClicks("AnyUp")
  f.unit, f.kind = unit, kind

  local mask = f:CreateMaskTexture()
  mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  f.portrait = f:CreateTexture(nil, "BACKGROUND")
  f.portrait:AddMaskTexture(mask)
  f.portraitMask = mask

  f.art = f:CreateTexture(nil, "ARTWORK")
  f.art:SetAllPoints(f)
  ns.Media.Apply(f.art, k.tex)

  f.ring = f:CreateTexture(nil, "OVERLAY")
  f.ring:SetTexture(M.ring_glow.file)
  f.ring:SetBlendMode("ADD")
  f.ring:Hide()

  f.health = statusBar(f)
  f.health:SetFrameLevel(f:GetFrameLevel() + 2)
  f.health:SetStatusBarColor(0.78, 0.16, 0.12)
  f.power = statusBar(f)
  f.power:SetFrameLevel(f:GetFrameLevel() + 2)

  f.name = f.health:CreateFontString(nil, "OVERLAY", kind == "large" and "GameFontNormal" or "GameFontNormalSmall")
  f.name:SetTextColor(0.91, 0.77, 0.42)
  f.name:SetJustifyH("LEFT")
  f.hpText = f.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hpText:SetPoint("CENTER", f.health)
  if kind ~= "large" then f.hpText:Hide() end

  function f:Resize(screenH)
    local w = k.width * screenH
    local h = w * k.spec.h / k.spec.w
    self:SetSize(w, h)
    setRect(self.portrait, self, k.spec, k.spec.portrait, w, h)
    self.portraitMask:SetAllPoints(self.portrait)
    self.ring:SetPoint("TOPLEFT", self.portrait, "TOPLEFT", -3, 3)
    self.ring:SetPoint("BOTTOMRIGHT", self.portrait, "BOTTOMRIGHT", 3, -3)
    setRect(self.health, self, k.spec, k.spec.health, w, h)
    setRect(self.power, self, k.spec, k.spec.power, w, h)
    setRect(self.name, self, k.spec, k.spec.name, w, h)
  end

  f:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if GameTooltip:SetUnit(self.unit) then GameTooltip:Show() end
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)

  RegisterUnitWatch(f)
  UnitFrames.frames[unit] = f
  return f
end

local function healthColor(unit)
  local classColor
  if UnitIsPlayer(unit) then
    local _, classToken = UnitClass(unit)
    classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  end
  return ns.Data.HealthColor(UnitIsTapDenied(unit), classColor, UnitReaction(unit, "player"))
end

local function updateValues(f)
  local unit = f.unit
  if not UnitExists(unit) then return end
  -- Unit flags can be secret on some units: keep the last color instead of erroring.
  local ok, r, g, b = pcall(healthColor, unit)
  if ok and type(r) == "number" then f.health:SetStatusBarColor(r, g, b) end
  f.health:SetMinMaxValues(0, UnitHealthMax(unit))
  f.health:SetValue(UnitHealth(unit))
  local pType, token = UnitPowerType(unit)
  f.power:SetMinMaxValues(0, UnitPowerMax(unit, pType))
  f.power:SetValue(UnitPower(unit, pType))
  f.power:SetStatusBarColor(ns.Data.PowerColor(token))
  if f.kind == "large" then
    local curveTo100 = CurveConstants and CurveConstants.ScaleTo100
    local ok = UnitHealthPercent and pcall(function()
      f.hpText:SetFormattedText("%.0f%% · %s", UnitHealthPercent(unit, true, curveTo100), AbbreviateNumbers(UnitHealth(unit)))
    end)
    if not ok and not pcall(function() f.hpText:SetText(AbbreviateNumbers(UnitHealth(unit))) end) then
      f.hpText:SetText("")
    end
  end
end

local function updateAll(f)
  local unit = f.unit
  if not UnitExists(unit) then return end
  SetPortraitTexture(f.portrait, unit)
  local name = UnitName(unit) or ""
  if f.kind == "large" then
    local class = UnitClassification(unit)
    local level = UnitLevel(unit)
    local label = CLASS_LABEL[class]
    f.name:SetText(name .. "  |cffb9ad95Nv " .. (level and level > 0 and level or "??") .. (label and (" · " .. label) or "") .. "|r")
    local ring = CLASS_RING[class]
    if ring then f.ring:SetVertexColor(ring[1], ring[2], ring[3]); f.ring:Show() else f.ring:Hide() end
  else
    f.name:SetText(f.unit == "focus" and ("Foco: " .. name) or name)
  end
  updateValues(f)
end
UnitFrames.Update = updateAll

-- Debuffs the player applied on the target, in a row right under the target bars.
local debuffs = {}
local function debuffButton(parent, i)
  local b = CreateFrame("Frame", nil, parent)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAllPoints(b)
  b.border:SetTexture(M.aura_border.file)
  b.border:SetVertexColor(0.77, 0.15, 0.11)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  b.count:SetPoint("BOTTOMRIGHT", 1, 0)
  debuffs[i] = b
  return b
end

local function updateTargetDebuffs()
  local target = UnitFrames.frames.target
  if not target then return end
  local size = target:GetHeight() * 0.22
  for i = 1, 8 do
    local b = debuffs[i] or debuffButton(target, i)
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", target.health, "BOTTOMLEFT", (i - 1) * (size + 3), -target:GetHeight() * 0.2)
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
    if aura then
      b.icon:SetTexture(aura.icon)
      if not pcall(function() b.count:SetText(aura.applications > 1 and aura.applications or "") end) then
        b.count:SetText("")
      end
      local ok = false
      if C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
        local dur = C_UnitAuras.GetAuraDuration("target", aura.auraInstanceID)
        ok = dur ~= nil and pcall(b.cd.SetCooldownFromDurationObject, b.cd, dur)
      end
      if not ok then
        pcall(function() b.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration) end)
      end
      b:Show()
    else
      b:Hide()
    end
  end
end

-- Blizzard's target/focus cast bars (secret-aware timing) lived inside the frames we hide:
-- move them under ours and keep them there when Blizzard re-anchors them.
local castbars = {}
local function placeCastbar(bar, f)
  bar.obApplying = true
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -f:GetHeight() * (f.kind == "large" and 0.46 or 0.30))
  bar:SetSize(f.health:GetWidth(), math.max(8, f:GetHeight() * 0.08))
  bar.obApplying = false
end

local function adoptCastbar(key, f)
  local bar = ns.Resolve.First(ns.Data.FRAME_CANDIDATES[key])
  if not bar or not f then return end
  if not castbars[key] then
    castbars[key] = { bar = bar, frame = f }
    bar:SetParent(f)
    if bar.SetFrameLevel then bar:SetFrameLevel(f:GetFrameLevel() + 4) end
    hooksecurefunc(bar, "SetPoint", function(self)
      if self.obApplying then return end
      placeCastbar(self, f)
    end)
    -- Dark well with a thin bronze edge, like the other bars.
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetColorTexture(0.54, 0.43, 0.23, 1)
    local well = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    well:SetPoint("TOPLEFT", -1, 1)
    well:SetPoint("BOTTOMRIGHT", 1, -1)
    well:SetColorTexture(0.02, 0.024, 0.031, 1)
    if ns.CastBar and ns.CastBar.Reskin then
      ns.CastBar.Reskin(bar)
      bar:HookScript("OnEvent", ns.CastBar.Reskin)
      bar:HookScript("OnShow", ns.CastBar.Reskin)
    end
  end
  placeCastbar(bar, f)
end

local function layout()
  local W, H = UIParent:GetSize()
  local s = H / 900
  local target, focus = UnitFrames.frames.target, UnitFrames.frames.focus
  local tot, pet = UnitFrames.frames.targettarget, UnitFrames.frames.pet
  for _, f in pairs(UnitFrames.frames) do f:Resize(H) end
  target:ClearAllPoints(); target:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0.012 * W, -0.02 * H)
  focus:ClearAllPoints(); focus:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 20 * s, -34 * s)
  tot:ClearAllPoints(); tot:SetPoint("TOPLEFT", target, "TOPRIGHT", 8 * s, -18 * s)
  pet:ClearAllPoints(); pet:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.012 * W, (ns.HUD.h or 0) + 6 * s)
  adoptCastbar("targetcastbar", target)
  adoptCastbar("focuscastbar", focus)
end

-- Fill every frame now: after /reload or a zone change no "target changed" event comes.
local function refreshAll()
  for _, f in pairs(UnitFrames.frames) do updateAll(f) end
  updateTargetDebuffs()
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    UnitFrames.Create("target", "large")
    UnitFrames.Create("focus", "small")
    UnitFrames.Create("targettarget", "tiny")
    UnitFrames.Create("pet", "tiny")
    layout()
    refreshAll()
    table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
  end)
end)
ns.On("PLAYER_ENTERING_WORLD", refreshAll)

local function refresh(unit) local f = UnitFrames.frames[unit]; if f then updateAll(f) end end
ns.On("PLAYER_TARGET_CHANGED", function() refresh("target"); refresh("targettarget"); updateTargetDebuffs() end)
ns.On("PLAYER_FOCUS_CHANGED", function() refresh("focus") end)
ns.On("UNIT_PET", function(_, unit) if unit == "player" then refresh("pet") end end)
ns.On("UNIT_TARGET", function(_, unit) if unit == "target" then refresh("targettarget") end end)
for _, ev in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
  ns.On(ev, function(_, unit) local f = UnitFrames.frames[unit]; if f then updateValues(f) end end)
end
ns.On("UNIT_NAME_UPDATE", function(_, unit) refresh(unit) end)
ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit) refresh(unit) end)
ns.On("UNIT_CLASSIFICATION_CHANGED", function(_, unit) refresh(unit) end)
ns.On("UNIT_FACTION", function(_, unit) local f = UnitFrames.frames[unit]; if f then updateValues(f) end end)
ns.On("UNIT_AURA", function(_, unit) if unit == "target" then updateTargetDebuffs() end end)

-- Target-of-target has no reliable events; poll it gently.
local elapsedTotal = 0
CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
  elapsedTotal = elapsedTotal + elapsed
  if elapsedTotal < 0.25 then return end
  elapsedTotal = 0
  local f = UnitFrames.frames.targettarget
  if f and f:IsShown() then updateAll(f) end
end)
