local _, ns = ...

-- Health (left) and resource (right) orbs. Values go straight into a vertical StatusBar and
-- FontStrings: no Lua math on unit values (they can be secret in combat).
local D = ns.Data.HUD
local HUD = ns.HUD
local M = ns.MediaManifest

ns.Orbs = {}

local function makeOrb(x)
  local well = CreateFrame("Frame", nil, HUD.under)
  HUD.Place(well, x, D.orb.y, D.orb.w, D.orb.h)

  local mask = well:CreateMaskTexture()
  mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(well)

  local bg = well:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(well)
  bg:SetColorTexture(0.02, 0.024, 0.031, 1)
  bg:AddMaskTexture(mask)

  local bar = CreateFrame("StatusBar", nil, well)
  bar:SetAllPoints(well)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture(M.liquid.file)
  bar:GetStatusBarTexture():AddMaskTexture(mask)
  local fill = bar:GetStatusBarTexture()

  -- Slowly moving texture inside the liquid only.
  local swirl = bar:CreateTexture(nil, "ARTWORK", nil, 2)
  swirl:SetTexture(M.swirl.file, "REPEAT", "REPEAT")
  swirl:SetAllPoints(fill)
  swirl:SetBlendMode("ADD")
  swirl:SetAlpha(0.22)
  swirl:AddMaskTexture(mask)

  -- Wavy surface anchored to the top of the fill: follows the value without any math.
  local wave = bar:CreateTexture(nil, "ARTWORK", nil, 3)
  wave:SetTexture(M.wave.file, "REPEAT", "CLAMP")
  wave:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", 0, -1)
  wave:SetPoint("BOTTOMRIGHT", fill, "TOPRIGHT", 0, -1)
  wave:AddMaskTexture(mask)

  local shade = bar:CreateTexture(nil, "OVERLAY")
  shade:SetAllPoints(well)
  shade:SetTexture(M.vignette.file)
  shade:AddMaskTexture(mask)

  local textHolder = CreateFrame("Frame", nil, HUD.over)
  HUD.Place(textHolder, x, D.orb.y, D.orb.w, D.orb.h)
  local pct = textHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pct:SetPoint("CENTER", 0, 6)
  pct:SetTextColor(1, 1, 1)
  pct:SetShadowOffset(1, -1)
  local val = textHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  val:SetPoint("TOP", pct, "BOTTOM", 0, -1)

  local offset = 0
  well:SetScript("OnUpdate", function(_, elapsed)
    offset = (offset + elapsed * 0.05) % 1
    wave:SetTexCoord(offset, offset + 1, 0, 1)
    swirl:SetTexCoord(offset * 0.5, offset * 0.5 + 1, offset * 0.3, offset * 0.3 + 1)
  end)

  table.insert(HUD.onResize, function(u)
    wave:SetHeight(math.max(2, 10 * u))
  end)

  local orb = { well = well, bg = bg, bar = bar, wave = wave, pct = pct, val = val }
  function orb:SetColor(r, g, b)
    -- The empty part reads as dark tinted glass, not a black hole.
    self.bg:SetColorTexture(0.02 + r * 0.10, 0.02 + g * 0.10, 0.03 + b * 0.10, 1)
    self.bar:SetStatusBarColor(r, g, b)
    self.wave:SetVertexColor(math.min(1, r * 1.25), math.min(1, g * 1.25), math.min(1, b * 1.25))
  end
  return orb
end

-- Text through C-side formatting so secret values are never touched by Lua.
-- percentFn may be nil (API missing). Everything that touches a possibly-secret value runs in pcall.
local function setTexts(orb, cur, max, percentFn)
  local ok = percentFn and pcall(function() orb.pct:SetFormattedText("%.0f%%", percentFn()) end)
  if not ok then orb.pct:SetText("") end
  if not pcall(function() orb.val:SetFormattedText("%s / %s", AbbreviateNumbers(cur), AbbreviateNumbers(max)) end) then
    orb.val:SetText("")
  end
end

local function curve()
  return CurveConstants and CurveConstants.ScaleTo100
end

local health = makeOrb(D.orb.x)
local power = makeOrb(ns.Layout.MirrorX(D.width, D.orb.x, D.orb.w))
ns.Orbs.health, ns.Orbs.power = health, power
health:SetColor(ns.Data.ORB_COLORS.HEALTH.r, ns.Data.ORB_COLORS.HEALTH.g, ns.Data.ORB_COLORS.HEALTH.b)

local function updateHealth()
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  health.bar:SetMinMaxValues(0, max)
  health.bar:SetValue(cur)
  setTexts(health, cur, max, UnitHealthPercent and function() return UnitHealthPercent("player", true, curve()) end)
end

local function updatePower()
  local pType = UnitPowerType("player")
  local cur, max = UnitPower("player", pType), UnitPowerMax("player", pType)
  power.bar:SetMinMaxValues(0, max)
  power.bar:SetValue(cur)
  setTexts(power, cur, max, UnitPowerPercent and function() return UnitPowerPercent("player", pType, true, curve()) end)
end

local function updatePowerColor()
  local _, token = UnitPowerType("player")
  power:SetColor(ns.Data.PowerColor(token))
  updatePower()
end

-- Numbers on the orbs (setting "orbText").
function ns.Orbs.ApplyTextVisibility()
  local on = not (ns.db and ns.db.orbText == false)
  for _, orb in ipairs({ health, power }) do
    orb.pct:SetShown(on)
    orb.val:SetShown(on)
  end
end

local function forPlayer(fn)
  return function(_, unit) if unit == "player" then fn() end end
end

ns.On("PLAYER_ENTERING_WORLD", function() updateHealth(); updatePowerColor(); ns.Orbs.ApplyTextVisibility() end)
ns.On("UNIT_HEALTH", forPlayer(updateHealth))
ns.On("UNIT_MAXHEALTH", forPlayer(updateHealth))
ns.On("UNIT_POWER_FREQUENT", forPlayer(updatePower))
ns.On("UNIT_MAXPOWER", forPlayer(updatePower))
ns.On("UNIT_DISPLAYPOWER", forPlayer(updatePowerColor))
ns.On("UPDATE_SHAPESHIFT_FORM", updatePowerColor)
