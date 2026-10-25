local _, ns = ...

-- Player, target (mirrored), target of target (small, mirrored), focus and pet: the Moderno frames.
-- Static 2D portraits (user's choice).
local M = ns.MediaManifest
local UnitFrames = { frames = {} }
ns.UnitFrames = UnitFrames

local KINDS = {
  -- Moderno: player and target, then focus and pet, then the target of target (widths of the
  -- screen height; spec 2026-10-23-hud-moderno).
  modern = { spec = ns.Data.MODERN_UNIT, width = 1 / 3, modern = true },
  -- The small ones have no level circle: at their size it cannot hold a readable number.
  modernSmall = { spec = ns.Data.MODERN_UNIT, width = 0.2, modern = true, noLevel = true },
  modernTiny = { spec = ns.Data.MODERN_UNIT, width = 1 / 6, modern = true, tiny = true, noLevel = true },
}
UnitFrames.KINDS = KINDS

local function statusBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetStatusBarTexture(M.bar_fill.file)
  bar:SetMinMaxValues(0, 1)
  return bar
end

-- Font size follows the frame size (the default fonts ran out of the small name plate).
local function setFontSize(text, size)
  ns.Look.SetFont(text, size) -- the Visual page's font and outline; 9 px minimum, still readable
end

local function setRect(region, owner, spec, rect, w, h)
  local x, y, rw, rh = ns.Layout.Rect(spec.w, spec.h, w, h, rect.x, rect.y, rect.w, rect.h)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", owner, "TOPLEFT", x, y)
  region:SetSize(rw, rh)
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
  ns.Media.Apply(f.art, ns.ModernTex(k.noLevel and "mod_unit_small" or "mod_unit"), mirror)

  -- The player's arcane ring turns slowly over the portrait, under the ring (setting "arcaneRing").
  if unit == "player" then
    f.arcane = f:CreateTexture(nil, "BORDER")
    f.arcane:SetTexture(M.mod_arcane.file)
    f.arcane:SetTexCoord(0, M.mod_arcane.w / M.mod_arcane.potW, 0, M.mod_arcane.h / M.mod_arcane.potH)
    f.arcane:SetBlendMode("ADD")
    f.arcane:SetAlpha(0.5) -- subtle: a hint of motion, not a bright purple halo
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
    ns.Smooth.Wrap(bar)
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
  f.levelText:SetTextColor(0.92, 0.95, 0.99)
  if k.noLevel then f.levelBadge:Hide() end
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
    self.health:SetStatusBarTexture(ns.Look.BarTexture())
    self.power:SetStatusBarTexture(ns.Look.BarTexture())
    setFontSize(self.name, spec.name.h * u * 0.62)
    setFontSize(self.levelText, spec.level.h * u * 0.62)
    setFontSize(self.hpText, spec.health.h * u * 0.62)
    setFontSize(self.powerText, spec.power.h * u * 0.62)
    UnitFrames.Style(self)
  end
end

-- ------------------------------------------------------------------ frame style
-- Setting "frameStyle": flat (the bars as drawn), gloss (light on the bars, a metal rim round the
-- portrait, a glowing level badge), arcane (a blue glowing ring, a gold line under the bars, the
-- level on a gold diamond), plate (portrait and bars on one glass plate).
UnitFrames.STYLES = ns.Widgets.FRAME_STYLES
local STYLE = {
  flat = {},
  -- the level is a clean baked chip now; the old gold glow disc and diamond behind it are gone
  gloss = { shine = 0.45, shade = 0.35, ring = "metal" },
  arcane = { shine = 0.3, ring = "glow", goldLine = true },
  plate = { shine = 0.15, plate = true },
}

local function gradient(t, r, g, b, bottom, top)
  t:SetColorTexture(1, 1, 1, 1)
  if t.SetGradient and CreateColor then
    pcall(t.SetGradient, t, "VERTICAL", CreateColor(r, g, b, bottom), CreateColor(r, g, b, top))
  else
    t:SetColorTexture(r, g, b, (bottom + top) / 2)
  end
end

-- A disc behind a region, out px larger all round, cut round by its own mask.
local function disc(f, layer, sub)
  local t = f:CreateTexture(nil, layer, nil, sub)
  local mask = f:CreateMaskTexture()
  mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(t)
  t:AddMaskTexture(mask)
  return t
end
local function around(t, region, out)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", region, "TOPLEFT", -out, out)
  t:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", out, -out)
end

local function width(region)
  local w = region and region.GetWidth and region:GetWidth()
  return type(w) == "number" and w or 0
end

function UnitFrames.Style(f)
  if not f.portrait then return end
  local st = STYLE[ns.db and ns.db.frameStyle or "gloss"] or STYLE.gloss
  local pw = width(f.portrait)
  -- light on the top half of each bar's fill, shade on its bottom quarter. On the fill only: over
  -- the whole bar they turned the empty groove into a grey shine. The fill texture is replaced
  -- when the bar texture changes, so they are anchored again here.
  for _, key in ipairs({ "health", "power" }) do
    local bar = f[key]
    if bar and not bar.obShine then
      bar.obShine = bar:CreateTexture(nil, "ARTWORK", nil, 7)
      bar.obShade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
    end
    if bar then
      local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or bar
      bar.obShine:ClearAllPoints()
      bar.obShine:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
      bar.obShine:SetPoint("BOTTOMRIGHT", fill, "RIGHT", 0, 0)
      bar.obShade:ClearAllPoints()
      bar.obShade:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
      bar.obShade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
      gradient(bar.obShine, 1, 1, 1, 0, st.shine or 0)
      bar.obShine:SetShown((st.shine or 0) > 0)
      bar.obShade:SetHeight(math.max(1, width(bar) > 0 and (bar.GetHeight and bar:GetHeight() or 4) * 0.3 or 2))
      gradient(bar.obShade, 0, 0, 0, st.shade or 0, 0)
      bar.obShade:SetShown((st.shade or 0) > 0)
    end
  end
  -- the ring behind the portrait's edge
  if st.ring and not f.obRing then f.obRing = disc(f, "BACKGROUND", -2) end
  if f.obRing then
    if st.ring == "metal" then
      around(f.obRing, f.portrait, math.max(2, pw * 0.06))
      f.obRing:SetBlendMode("BLEND")
      gradient(f.obRing, 0.82, 0.85, 0.9, 0.25, 0.95)
    elseif st.ring == "glow" then
      around(f.obRing, f.portrait, math.max(3, pw * 0.1))
      f.obRing:SetBlendMode("ADD")
      gradient(f.obRing, 0.3, 0.55, 1, 0.55, 0.9)
    end
    f.obRing:SetShown(st.ring ~= nil)
  end
  -- the level badge: a gold glow, or a gold diamond under the number
  if f.levelBadge then
    if st.badgeGlow and not f.obBadgeGlow then f.obBadgeGlow = disc(f.levelBadge, "BACKGROUND", -1) end
    if f.obBadgeGlow then
      around(f.obBadgeGlow, f.levelBadge, math.max(2, width(f.levelBadge) * 0.18))
      f.obBadgeGlow:SetBlendMode("ADD")
      f.obBadgeGlow:SetColorTexture(0.95, 0.75, 0.3, 0.45)
      f.obBadgeGlow:SetShown(st.badgeGlow == true)
    end
    if st.diamond and not f.obDiamond and M.mod_gem_on then
      f.obDiamond = f.levelBadge:CreateTexture(nil, "ARTWORK")
      f.obDiamond:SetTexture(M.mod_gem_on.file)
      f.obDiamond:SetTexCoord(0, M.mod_gem_on.w / M.mod_gem_on.potW, 0, M.mod_gem_on.h / M.mod_gem_on.potH)
    end
    if f.obDiamond then
      around(f.obDiamond, f.levelBadge, math.max(2, width(f.levelBadge) * 0.25))
      f.obDiamond:SetShown(st.diamond == true)
    end
  end
  -- leading-edge spark: a thin, faint white glow riding the fill's edge, so a changing bar reads
  -- as alive without covering the value text (setting barSpark). Anchored to the StatusBar's fill
  -- region, it follows the value and is re-anchored here because the fill texture is replaced
  -- when the bar texture changes.
  local sparkOn = not (ns.db and ns.db.barSpark == false)
  for _, key in ipairs({ "health", "power" }) do
    local bar = f[key]
    if bar then
      if not bar.obSpark then
        bar.obSpark = ns.Widgets.SoftTexture(bar, "OVERLAY", 1, 1, 1, 0.22, 2)
        bar.obSpark:SetBlendMode("ADD")
      end
      local h = (bar.GetHeight and bar:GetHeight()) or 0
      if type(h) ~= "number" then h = 0 end
      local fillTex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
      bar.obSpark:ClearAllPoints()
      if fillTex then bar.obSpark:SetPoint("CENTER", fillTex, f.mirror and "LEFT" or "RIGHT", 0, 0) end
      bar.obSpark:SetSize(math.max(2, h * 0.10), math.max(2, h * 0.9))
      bar.obSpark:SetShown(sparkOn and fillTex ~= nil)
    end
  end
  -- a gold line under the bars, fading away from the portrait
  if st.goldLine and not f.obGold and f.power then
    f.obGold = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.obGold:SetHeight(1)
  end
  if f.obGold then
    f.obGold:ClearAllPoints()
    f.obGold:SetPoint("TOPLEFT", f.power, "BOTTOMLEFT", 0, -3)
    f.obGold:SetPoint("TOPRIGHT", f.power, "BOTTOMRIGHT", 0, -3)
    f.obGold:SetColorTexture(1, 1, 1, 1)
    if f.obGold.SetGradient and CreateColor then
      local strong, faint = CreateColor(0.9, 0.76, 0.35, 0.9), CreateColor(0.9, 0.76, 0.35, 0)
      if f.mirror then pcall(f.obGold.SetGradient, f.obGold, "HORIZONTAL", faint, strong)
      else pcall(f.obGold.SetGradient, f.obGold, "HORIZONTAL", strong, faint) end
    end
    f.obGold:SetShown(st.goldLine == true)
  end
  -- one glass plate under portrait and bars
  if st.plate and not f.obPlate then
    f.obPlate = CreateFrame("Frame", nil, f)
    f.obPlate:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
    ns.Widgets.Panel(f.obPlate, 0.6)
  end
  if f.obPlate then
    local pad = math.max(3, pw * 0.08)
    f.obPlate:ClearAllPoints()
    -- as tall as the portrait, from its outer side to the bars' far end
    local side, far = f.mirror and "RIGHT" or "LEFT", f.mirror and "LEFT" or "RIGHT"
    local out = f.mirror and pad or -pad
    f.obPlate:SetPoint("TOP" .. side, f.portrait, "TOP" .. side, out, pad)
    f.obPlate:SetPoint("BOTTOM" .. side, f.portrait, "BOTTOM" .. side, out, -pad)
    f.obPlate:SetPoint(far, f.power, far, -out * 2, 0)
    f.obPlate:SetShown(st.plate == true)
  end
end

function UnitFrames.ApplyStyle()
  for _, f in pairs(UnitFrames.frames) do UnitFrames.Style(f) end
end

-- Fade a frame in when its unit appears (RegisterUnitWatch shows it): a new target or focus
-- eases in instead of popping (setting frameFade). Driven by OnUpdate so it needs no animation
-- API and is frame-rate independent. SetAlpha is allowed on protected frames in combat, and the
-- Visibility module leaves "always" elements' alpha alone, so the two never fight.
local fading = setmetatable({}, { __mode = "k" }) -- frame -> elapsed so far
local FADE = 0.28
local fadeDriver = CreateFrame("Frame")
fadeDriver:SetScript("OnUpdate", function(_, elapsed)
  if type(elapsed) ~= "number" then return end
  for f, t in pairs(fading) do
    t = t + elapsed
    if t >= FADE then f:SetAlpha(1); fading[f] = nil
    else f:SetAlpha(t / FADE); fading[f] = t end
  end
end)
UnitFrames.fadeDriver = fadeDriver
local function fadeIn(f)
  if (ns.db and ns.db.frameFade == false) or (ns.EditMode and ns.EditMode.active) then
    fading[f] = nil; f:SetAlpha(1); return
  end
  f:SetAlpha(0); fading[f] = 0
end
UnitFrames.FadeIn = fadeIn

-- key: a second frame for the same unit (you inside the party) is filed under its own key; the
-- unit events only reach frames filed under the unit itself.
function UnitFrames.Create(unit, kind, mirror, key)
  local k = KINDS[kind]
  key = key or unit
  local f = CreateFrame("Button", "ObsidianUI_" .. key, UIParent, "SecureUnitButtonTemplate")
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

  buildModern(f, k, unit, mirror)

  f:SetScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    if GameTooltip:SetUnit(self.unit) then GameTooltip:Show() end
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)

  f:HookScript("OnShow", fadeIn)
  RegisterUnitWatch(f)
  UnitFrames.frames[key] = f
  return f
end

local function healthColor(unit)
  local classColor
  if UnitIsPlayer(unit) then
    local _, classToken = UnitClass(unit)
    classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
  end
  local reaction = UnitReaction(unit, "player")
  if not UnitIsTapDenied(unit) and not classColor and reaction then
    local key = reaction == 4 and "neutral" or (reaction >= 5 and "friendly" or "hostile")
    local r, g, b = ns.Look.Color(key)
    if r then return r, g, b end
  end
  return ns.Data.HealthColor(UnitIsTapDenied(unit), classColor, reaction)
end

-- "current / max" on a Moderno bar; the current value alone, or nothing, if that fails.
local function barText(text, cur, max)
  if pcall(function() text:SetFormattedText("%s / %s", ns.Look.Number(cur), ns.Look.Number(max)) end) then return end
  if not pcall(function() text:SetText(AbbreviateNumbers(cur)) end) then text:SetText("") end
end

-- The unit's health as a fraction 0..1, or nil when the values are secret (combat) or missing:
-- the pulse never guesses, so a secret value never raises a false "low health" alarm.
local function healthFraction(unit)
  if UnitHealthPercent then
    local ok, p = pcall(UnitHealthPercent, unit, true)
    if ok and type(p) == "number" then return p / 100 end
  end
  local ok, cur, max = pcall(function() return UnitHealth(unit), UnitHealthMax(unit) end)
  if ok and type(cur) == "number" and type(max) == "number" and max > 0 then return cur / max end
  return nil
end

-- A red glow over a frame's health bar that breathes while the unit is low (setting lowHpPulse).
-- Driven by one OnUpdate (a sine), so it works on any client and is the same at any frame rate.
local LOW_HP = 0.35
local pulsing = setmetatable({}, { __mode = "k" }) -- frames currently pulsing
local pulseClock = 0

local function lowGlow(f)
  if f.obLowGlow then return f.obLowGlow end
  local g = f.health:CreateTexture(nil, "ARTWORK", nil, 6) -- over the fill, under the number
  g:SetAllPoints(f.health)
  g.obSoft = ns.Widgets.Soft(g, "soft_fill", 10)
  g:SetBlendMode("ADD")
  ns.Widgets.SetSoftColor(g, 0.95, 0.15, 0.12, 1)
  g:SetAlpha(0)
  g:Hide()
  f.obLowGlow = g
  return g
end

local pulseDriver = CreateFrame("Frame")
pulseDriver:SetScript("OnUpdate", function(_, elapsed)
  if type(elapsed) ~= "number" then return end
  pulseClock = pulseClock + elapsed
  local a = 0.1 + 0.22 * (0.5 + 0.5 * math.sin(pulseClock * 3.4)) -- 0.1 .. 0.32, a slow breath
  for f in pairs(pulsing) do
    if f.obLowGlow then f.obLowGlow:SetAlpha(a) end
  end
end)
UnitFrames.pulseDriver = pulseDriver

-- Show or hide a frame's low-health pulse from its current health fraction.
local function updatePulse(f)
  if KINDS[f.kind].tiny then return end
  local g = lowGlow(f)
  local on = not (ns.db and ns.db.lowHpPulse == false)
  local frac = on and healthFraction(f.unit) or nil
  if frac ~= nil and frac < LOW_HP then
    g:Show()
    pulsing[f] = true
  else
    pulsing[f] = nil
    g:SetAlpha(0); g:Hide()
  end
end
UnitFrames.UpdatePulse = updatePulse

local function updateValues(f)
  local unit = f.unit
  if not UnitExists(unit) then return end
  -- A new unit in this frame: land the bars at once instead of sliding across from the old one.
  local guid = UnitGUID(unit)
  if guid ~= f.obGUID then
    f.obGUID = guid
    ns.Smooth.Snap(f.health); ns.Smooth.Snap(f.power)
  end
  -- Unit flags can be secret on some units: keep the last color instead of erroring.
  local ok, r, g, b = pcall(healthColor, unit)
  if unit == "player" then ok, r, g, b = true, 0.38, 0.84, 0.2 end -- the player's bar: green
  if ok and type(r) == "number" then f.health:SetStatusBarColor(r, g, b) end
  f.health:SetMinMaxValues(0, UnitHealthMax(unit))
  f.health:SetValue(UnitHealth(unit))
  local pType, token = UnitPowerType(unit)
  f.power:SetMinMaxValues(0, UnitPowerMax(unit, pType))
  f.power:SetValue(UnitPower(unit, pType))
  local pr, pg, pb = ns.Look.Color(token)
  if pr then f.power:SetStatusBarColor(pr, pg, pb) else f.power:SetStatusBarColor(ns.Data.PowerColor(token)) end
  -- Values may be secret in combat: they only go into the text API, inside pcall.
  if KINDS[f.kind].tiny then
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if not (UnitHealthPercent and pcall(function()
      f.hpText:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, curve))
    end)) then f.hpText:SetText("") end
  else
    barText(f.hpText, UnitHealth(unit), UnitHealthMax(unit))
    local powerMax = UnitPowerMax(unit, pType)
    -- a unit with no power at all (most NPCs) shows an empty bar, not "0 / 0"
    if not (issecretvalue and issecretvalue(powerMax)) and powerMax == 0 then
      f.powerText:SetText("")
    else
      barText(f.powerText, UnitPower(unit, pType), powerMax)
    end
  end
  updatePulse(f)
end

local function updateAll(f)
  local unit = f.unit
  if not UnitExists(unit) then return end
  SetPortraitTexture(f.portrait, unit)
  local name = UnitName(unit) or ""
  local level = UnitLevel(unit)
  f.name:SetText(f.unit == "focus" and ("Foco: " .. name) or name)
  f.levelText:SetText(level and level > 0 and level or "??")
  updateValues(f)
end
UnitFrames.Update = updateAll
UnitFrames.UpdateValues = updateValues

-- Test mode: stand-in values for a frame whose unit does not exist (d: name, class, level, hp).
function UnitFrames.Fake(f, d)
  f.name:SetText(d.name)
  f.levelText:SetText(d.level or 60)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class]
  if c then f.health:SetStatusBarColor(c.r, c.g, c.b) end
  f.health:SetMinMaxValues(0, 10000); f.health:SetValue(d.hp)
  f.power:SetMinMaxValues(0, 100); f.power:SetValue(d.power or 70)
  f.power:SetStatusBarColor(ns.Data.PowerColor("MANA"))
  f.hpText:SetText(ns.Look.Number(d.hp) .. " / " .. ns.Look.Number(10000))
  f.powerText:SetText((d.power or 70) .. " / 100")
  local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[d.class]
  if coords then
    f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    f.portrait:SetTexCoord(unpack(coords))
  end
end

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
  if f.unit == "target" and tot then
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
  if bar.Text then
    -- a little smaller than the bar, with room at both ends; long names stop short of the edge
    setFontSize(bar.Text, barH * 0.72)
    bar.Text:ClearAllPoints()
    bar.Text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    bar.Text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    if bar.Text.SetWordWrap then bar.Text:SetWordWrap(false) end
  end
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
    -- Dark rounded well with the panels' faint rim, like the other bars (no heavy grey edge).
    local well = ns.Widgets.SoftTexture(bar, "BACKGROUND", 0.02, 0.024, 0.031, 0.9, -7)
    well:SetPoint("TOPLEFT", -2, 2)
    well:SetPoint("BOTTOMRIGHT", 2, -2)
    local rim = ns.Widgets.SoftRim(bar, 1, 1, 1, 0.12)
    for _, t in ipairs(rim) do
      if not t.obSoft then break end -- the flat 1 px rim keeps its own edges
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", -2, 2)
      t:SetPoint("BOTTOMRIGHT", 2, -2)
    end
    if ns.CastBar and ns.CastBar.Reskin then
      ns.CastBar.Reskin(bar)
      bar:HookScript("OnEvent", ns.CastBar.Reskin)
      bar:HookScript("OnShow", ns.CastBar.Reskin)
    end
  end
  placeCastbar(bar, f)
end

local function layout()
  local _, H = UIParent:GetSize()
  local s = H / 1080
  local f = UnitFrames.frames
  for _, frame in pairs(f) do frame:Resize(H) end
  -- Defaults on the screen grid, by the frames' visible edges: the player at the margin of the top
  -- left, the target beside it (two gaps), its target under the target's portrait (one gap, right
  -- edges lined up), focus under the player (two gaps) and pet under the focus (one gap). Each one
  -- can be moved and resized in the edit mode.
  local M, G = ns.Layout.MARGIN * s, ns.Layout.GAP * s
  local function edges(fr)
    local e = ns.Data.ART_EDGE[KINDS[fr.kind].noLevel and "unitSmall" or "unit"]
    return ns.Layout.Edges(e, KINDS[fr.kind].spec.w, fr:GetWidth(), fr.mirror)
  end
  -- fr hangs under `above` with its visible top `gap` below the visible bottom of `above`,
  -- lined up on the side `side` ("LEFT" or "RIGHT")
  local function under(fr, above, gap, side)
    local al, _, ar, ab = edges(above)
    local fl, ft, fr2 = edges(fr)
    local x = side == "LEFT" and (al - fl) or (fr2 - ar)
    fr:SetPoint("TOP" .. side, above, "BOTTOM" .. side, x, ab - gap + ft)
  end
  local defaults = {
    { "player", "Jogador", function(fr)
      local l, t = edges(fr)
      fr:SetPoint("TOPLEFT", UIParent, "TOPLEFT", M - l, -(M - t))
    end },
    { "target", "Alvo", function(fr)
      local _, _, pr = edges(f.player)
      local tl = edges(fr)
      fr:SetPoint("TOPLEFT", f.player, "TOPRIGHT", 2 * G - pr - tl, 0)
    end },
    { "targettarget", "Alvo do alvo", function(fr) under(fr, f.target, G, "RIGHT") end },
    { "focus", "Foco", function(fr) under(fr, f.player, 2 * G, "LEFT") end },
    { "pet", "Pet", function(fr) under(fr, f.focus, G, "LEFT") end },
  }
  for _, d in ipairs(defaults) do
    local unit, label, place = d[1], d[2], d[3]
    ns.Movers.Register(unit, label, f[unit], function(fr) fr:ClearAllPoints(); place(fr) end)
    ns.Movers.Place(unit)
  end
  adoptCastbar("targetcastbar", f.target)
  adoptCastbar("focuscastbar", f.focus)
end

-- Fill every frame now: after /reload or a zone change no "target changed" event comes.
local function refreshAll()
  for _, f in pairs(UnitFrames.frames) do updateAll(f) end
  updateTargetDebuffs()
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    UnitFrames.Create("player", "modern")
    UnitFrames.Create("target", "modern", true)
    UnitFrames.Create("focus", "modernSmall")
    UnitFrames.Create("targettarget", "modernTiny", true)
    UnitFrames.Create("pet", "modernSmall")
    layout()
    refreshAll()
    table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)
  end)
end)
UnitFrames.RefreshAll = refreshAll
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
