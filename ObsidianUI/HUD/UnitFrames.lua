local _, ns = ...

-- Target (large), focus (small), target-of-target and pet (tiny). Static 2D portraits (user's choice).
local M = ns.MediaManifest
local UnitFrames = { frames = {} }
ns.UnitFrames = UnitFrames

local KINDS = {
  -- Moderno: player and target, then focus and pet, then the target of target (widths of the
  -- screen height; spec 2026-10-23-hud-moderno).
  modern = { spec = ns.Data.MODERN_UNIT, width = 1 / 3, modern = true },
  modernSmall = { spec = ns.Data.MODERN_UNIT, width = 0.2, modern = true },
  modernTiny = { spec = ns.Data.MODERN_UNIT, width = 1 / 6, modern = true, tiny = true },
  large = { spec = ns.Data.UNIT, tex = "unit_frame", width = 0.29 },
  small = { spec = ns.Data.UNIT, tex = "unit_frame", width = 0.16 },
  tiny = { spec = ns.Data.UNIT, tex = "unit_frame", width = 0.14 },
}
UnitFrames.KINDS = KINDS
local CLASS_LABEL = { elite = "Elite", worldboss = "Chefe", rare = "Raro", rareelite = "Raro Elite" }

local function statusBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture(M.bar_fill.file)
  bar:SetMinMaxValues(0, 1)
  return bar
end

-- Font size follows the frame size (the default fonts ran out of the small name plate).
local function setFontSize(text, size)
  local path, _, flags = text:GetFont()
  if path then text:SetFont(path, math.max(9, math.floor(size + 0.5)), flags) end -- 9: still readable
end

local function setRect(region, owner, spec, rect, w, h)
  local x, y, rw, rh = ns.Layout.Rect(spec.w, spec.h, w, h, rect.x, rect.y, rect.w, rect.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", owner, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
end

-- Stone style: the party frame B art, name plate with level, bars in its grooves.
local function buildStone(f, k, kind)
  f.art = f:CreateTexture(nil, "ARTWORK")
  f.art:SetAllPoints(f)
  ns.Media.Apply(f.art, k.tex)

  f.health = statusBar(f)
  f.health:SetFrameLevel(f:GetFrameLevel() + 2)
  f.health:SetStatusBarColor(0.78, 0.16, 0.12)
  f.power = statusBar(f)
  f.power:SetFrameLevel(f:GetFrameLevel() + 2)

  f.name = f.health:CreateFontString(nil, "OVERLAY", kind == "large" and "GameFontNormal" or "GameFontNormalSmall")
  f.name:SetTextColor(0.91, 0.77, 0.42)
  f.name:SetJustifyH("LEFT")
  f.name:SetWordWrap(false) -- a long name is cut, never wraps out of the plate
  -- Target: level and classification at the right end of the name plate.
  if kind == "large" then
    f.levelText = f.health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.levelText:SetTextColor(0.73, 0.68, 0.58)
    f.levelText:SetJustifyH("RIGHT")
    f.levelText:SetWordWrap(false)
  end
  f.hpText = f.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hpText:SetPoint("CENTER", f.health)
  if kind ~= "large" then f.hpText:Hide() end

  function f:Resize(screenH)
    local w = k.width * screenH
    local h = w * k.spec.h / k.spec.w
    self:SetSize(w, h)
    setRect(self.portrait, self, k.spec, k.spec.portrait, w, h)
    self.portraitMask:SetAllPoints(self.portrait)
    setRect(self.health, self, k.spec, k.spec.health, w, h)
    setRect(self.power, self, k.spec, k.spec.power, w, h)
    local n = k.spec.name
    local x, y, rw, rh = ns.Layout.Rect(k.spec.w, k.spec.h, w, h, n.x, n.y, n.w, n.h)
    local pad = rh * 0.25
    self.name:ClearAllPoints()
    self.name:SetPoint("TOPLEFT", self, "TOPLEFT", x + pad, y)
    self.name:SetHeight(rh)
    setFontSize(self.name, rh * 0.52)
    if self.levelText then
      self.levelText:ClearAllPoints()
      self.levelText:SetPoint("TOPRIGHT", self, "TOPLEFT", x + rw - pad, y)
      self.levelText:SetHeight(rh)
      setFontSize(self.levelText, rh * 0.42)
      self.name:SetPoint("RIGHT", self.levelText, "LEFT", -pad, 0)
    else
      self.name:SetWidth(rw - 2 * pad)
    end
    local hp = k.spec.health
    setFontSize(self.hpText, h * hp.h / k.spec.h * 0.62)
  end
end

-- Moderno (spec 2026-10-23-hud-moderno): round portrait, the name above two framed bars, the level
-- in the gold badge, numbers on the bars. Mirrored for the target and its target: portrait on the
-- right, bars filling from it.
local function mirrored(spec, r, mirror)
  if not mirror then return r end
  return { x = ns.Layout.MirrorX(spec.w, r.x, r.w), y = r.y, w = r.w, h = r.h }
end

-- A bar groove, starting at the ring's edge (the ring lies over its first part).
local function fromRing(spec, r)
  local x0 = spec.ring.x + spec.ring.w - 4
  return { x = x0, y = r.y, w = r.x + r.w - x0, h = r.h }
end

local function buildModern(f, k, unit, mirror)
  local spec = k.spec
  f.mirror = mirror
  f.art = f:CreateTexture(nil, "ARTWORK")
  f.art:SetAllPoints(f)
  ns.Media.Apply(f.art, ns.ModernTex("mod_unit"), mirror)

  -- The player's arcane ring turns slowly over the portrait, under the ring (setting "arcaneRing").
  if unit == "player" then
    f.arcane = f:CreateTexture(nil, "BORDER")
    f.arcane:SetTexture(M.mod_arcane.file)
    f.arcane:SetTexCoord(0, M.mod_arcane.w / M.mod_arcane.potW, 0, M.mod_arcane.h / M.mod_arcane.potH)
    f.arcane:SetBlendMode("ADD")
    local spin = f.arcane:CreateAnimationGroup()
    local turn = spin:CreateAnimation("Rotation")
    turn:SetDegrees(-360)
    turn:SetDuration(14)
    spin:SetLooping("REPEAT")
    spin:Play()
    f.arcane:SetShown(not (ns.db and ns.db.arcaneRing == false))
  end

  for _, key in ipairs({ "health", "power" }) do
    local bar = statusBar(f)
    bar:SetStatusBarTexture(M.mod_gloss.file)
    bar:SetFrameLevel(f:GetFrameLevel() + 2)
    bar:SetReverseFill(mirror and true or false)
    f[key] = bar
  end
  f.health:SetStatusBarColor(0.38, 0.84, 0.2)

  f.name = f.health:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.name:SetJustifyH(mirror and "RIGHT" or "LEFT")
  f.name:SetWordWrap(false)
  f.levelBadge = CreateFrame("Frame", nil, f)
  f.levelBadge:SetFrameLevel(f:GetFrameLevel() + 3)
  f.levelText = f.levelBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.levelText:SetPoint("CENTER", f.levelBadge, "CENTER", 0, 1)
  f.levelText:SetTextColor(0.96, 0.82, 0.44)
  f.hpText = f.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.hpText:SetPoint("CENTER", f.health)
  f.powerText = f.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.powerText:SetPoint("CENTER", f.power)
  if k.tiny then f.powerText:Hide() end

  function f:Resize(screenH)
    local w = k.width * screenH
    local h = w * spec.h / spec.w
    self:SetSize(w, h)
    setRect(self.portrait, self, spec, mirrored(spec, spec.portrait, mirror), w, h)
    self.portraitMask:SetAllPoints(self.portrait)
    if self.arcane then self.arcane:SetAllPoints(self.portrait) end
    setRect(self.health, self, spec, mirrored(spec, fromRing(spec, spec.health), mirror), w, h)
    setRect(self.power, self, spec, mirrored(spec, fromRing(spec, spec.power), mirror), w, h)
    setRect(self.name, self, spec, mirrored(spec, spec.name, mirror), w, h)
    self.name:SetWidth(spec.name.w * h / spec.h) -- a long name is cut at the plate's end
    setRect(self.levelBadge, self, spec, mirrored(spec, spec.level, mirror), w, h)
    local u = h / spec.h
    setFontSize(self.name, spec.name.h * u * 0.62)
    setFontSize(self.levelText, spec.level.h * u * 0.42)
    setFontSize(self.hpText, spec.health.h * u * 0.62)
    setFontSize(self.powerText, spec.power.h * u * 0.62)
  end
end

function UnitFrames.Create(unit, kind, mirror)
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

  if k.modern then buildModern(f, k, unit, mirror) else buildStone(f, k, kind) end

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

-- "current / max" on a Moderno bar; the current value alone, or nothing, if that fails.
local function barText(text, cur, max)
  if pcall(function() text:SetFormattedText("%s / %s", AbbreviateNumbers(cur), AbbreviateNumbers(max)) end) then return end
  if not pcall(function() text:SetText(AbbreviateNumbers(cur)) end) then text:SetText("") end
end

local function updateValues(f)
  local unit = f.unit
  if not UnitExists(unit) then return end
  -- Unit flags can be secret on some units: keep the last color instead of erroring.
  local ok, r, g, b = pcall(healthColor, unit)
  if unit == "player" then ok, r, g, b = true, 0.38, 0.84, 0.2 end -- Moderno's player bar: green
  if ok and type(r) == "number" then f.health:SetStatusBarColor(r, g, b) end
  f.health:SetMinMaxValues(0, UnitHealthMax(unit))
  f.health:SetValue(UnitHealth(unit))
  local pType, token = UnitPowerType(unit)
  f.power:SetMinMaxValues(0, UnitPowerMax(unit, pType))
  f.power:SetValue(UnitPower(unit, pType))
  f.power:SetStatusBarColor(ns.Data.PowerColor(token))
  if KINDS[f.kind].modern then
    -- Values may be secret in combat: they only go into the text API, inside pcall.
    if KINDS[f.kind].tiny then
      local curve = CurveConstants and CurveConstants.ScaleTo100
      if not (UnitHealthPercent and pcall(function()
        f.hpText:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, curve))
      end)) then f.hpText:SetText("") end
    else
      barText(f.hpText, UnitHealth(unit), UnitHealthMax(unit))
      barText(f.powerText, UnitPower(unit, pType), UnitPowerMax(unit, pType))
    end
  elseif f.kind == "large" then
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
  if KINDS[f.kind].modern then
    local level = UnitLevel(unit)
    f.name:SetText(f.unit == "focus" and ("Foco: " .. name) or name)
    f.levelText:SetText(level and level > 0 and level or "??")
  elseif f.kind == "large" then
    local class = UnitClassification(unit)
    local level = UnitLevel(unit)
    local label = CLASS_LABEL[class]
    f.name:SetText(name)
    f.levelText:SetText("Nv " .. (level and level > 0 and level or "??") .. (label and (" · " .. label) or ""))
  else
    f.name:SetText(f.unit == "focus" and ("Foco: " .. name) or name)
  end
  updateValues(f)
end
UnitFrames.Update = updateAll

-- Debuffs the player applied on the target, in a row right under the target bars.
local debuffs = {}
UnitFrames.debuffs = debuffs

-- Height from the bottom of a frame's health bar to the bottom of its art.
local function belowHealth(f)
  local spec = KINDS[f.kind].spec
  return f:GetHeight() * (spec.h - spec.health.y - spec.health.h) / spec.h
end
local DEBUFF_SIZE = 0.22 -- of the target frame's height

-- Room under a frame's bars for its debuffs and cast bar: Moderno puts the target's target under
-- the target's portrait, so they stop short of it.
local function underWidth(f)
  local w = f.health:GetWidth()
  local tot = UnitFrames.frames.targettarget
  if f.unit == "target" and KINDS[f.kind].modern and tot then
    w = math.min(w, (tot:GetLeft() or 0) - (f.health:GetLeft() or 0) - 8)
  end
  return math.max(0, w)
end
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
  local size = target:GetHeight() * DEBUFF_SIZE
  local max = math.min(8, math.floor((underWidth(target) + 3) / (size + 3)))
  local list = ns.Data.UnitAuraList("target", "HARMFUL|PLAYER", max)
  for i = 1, 8 do
    local b = debuffs[i] or debuffButton(target, i)
    b:SetSize(size, size)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", target.health, "BOTTOMLEFT", (i - 1) * (size + 3), -belowHealth(target) - 3)
    local aura = list[i]
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
  -- the target's debuffs come first, right under the frame
  local debuffRow = f.unit == "target" and f:GetHeight() * DEBUFF_SIZE + 6 or 0
  bar:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -belowHealth(f) - 4 - debuffRow)
  local barH = math.max(10, f:GetHeight() * 0.11)
  bar:SetSize(underWidth(f), barH)
  if bar.Text then setFontSize(bar.Text, barH * 0.85) end
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
    if KINDS[f.kind].modern then edge:SetColorTexture(0.32, 0.34, 0.37, 1) else edge:SetColorTexture(0.54, 0.43, 0.23, 1) end
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

local function layoutModern()
  local _, H = UIParent:GetSize()
  local s = H / 1080
  local f = UnitFrames.frames
  for _, frame in pairs(f) do frame:Resize(H) end
  f.player:ClearAllPoints(); f.player:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18 * s, -14 * s)
  f.target:ClearAllPoints(); f.target:SetPoint("TOPLEFT", f.player, "TOPRIGHT", 32 * s, 0)
  f.targettarget:ClearAllPoints(); f.targettarget:SetPoint("TOPRIGHT", f.target, "TOPRIGHT", -19 * s, -124 * s)
  f.focus:ClearAllPoints(); f.focus:SetPoint("TOPLEFT", f.player, "BOTTOMLEFT", 0, -40 * s)
  f.pet:ClearAllPoints(); f.pet:SetPoint("TOPLEFT", f.focus, "BOTTOMLEFT", 0, -12 * s)
  adoptCastbar("targetcastbar", f.target)
  adoptCastbar("focuscastbar", f.focus)
end

local function layout()
  if ns.HUD.modern then return layoutModern() end
  local W, H = UIParent:GetSize()
  local s = H / 900
  local target, focus = UnitFrames.frames.target, UnitFrames.frames.focus
  local tot, pet = UnitFrames.frames.targettarget, UnitFrames.frames.pet
  for _, f in pairs(UnitFrames.frames) do f:Resize(H) end
  target:ClearAllPoints(); target:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0.012 * W, -0.02 * H)
  -- Lined up: focus under the target on the same left edge, target-of-target beside it at mid
  -- height, pet on the same left edge above the orb cap's crest.
  focus:ClearAllPoints(); focus:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -48 * s)
  tot:ClearAllPoints(); tot:SetPoint("LEFT", target, "RIGHT", 8 * s, 0)
  pet:ClearAllPoints(); pet:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.012 * W, (ns.HUD.h or 0) + 24 * s)
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
    if ns.HUD.modern then
      UnitFrames.Create("player", "modern")
      UnitFrames.Create("target", "modern", true)
      UnitFrames.Create("focus", "modernSmall")
      UnitFrames.Create("targettarget", "modernTiny", true)
      UnitFrames.Create("pet", "modernSmall")
    else
      UnitFrames.Create("target", "large")
      UnitFrames.Create("focus", "small")
      UnitFrames.Create("targettarget", "tiny")
      UnitFrames.Create("pet", "tiny")
    end
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
