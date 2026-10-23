local _, ns = ...

-- Health (left) and resource (right) orbs: a slow PoE2-style liquid (flipbook of flowing wisps,
-- tools/orb_fluid.py) inside the glass; transparent above the liquid. Values go straight into a
-- vertical StatusBar and FontStrings: no Lua math on unit values (they can be secret in combat).
-- The liquid follows the level through a clip frame anchored to the top of the fill.
local D = ns.Data.HUD
local Data = ns.Data
local HUD = ns.HUD
local M = ns.MediaManifest

ns.Orbs = {}

local FRAMES = 64
local SPARKS = 6
local WAVE_SPEED = 0.025
local SHIELD = { 0.45, 0.85, 1.0 } -- energy shield blue
local SHIELD_WISP = 0.7

local function clamp(v) return math.min(1, v) end

local function makeOrb(x)
  local well = CreateFrame("Frame", nil, HUD.under)
  HUD.Place(well, x, D.orb.y, D.orb.w, D.orb.h)

  local mask = well:CreateMaskTexture()
  mask:SetTexture(M.mask_circle.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(well)
  local function masked(t) t:AddMaskTexture(mask); return t end

  -- Body: dark sphere tinted with the palette, cut at the level by the status bar.
  local bar = CreateFrame("StatusBar", nil, well)
  bar:SetAllPoints(well)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture(M.liquid.file)
  local fill = bar:GetStatusBarTexture()
  masked(fill)

  -- Everything of the liquid lives in this frame, which ends at the top of the fill.
  local clip = CreateFrame("Frame", nil, well)
  clip:SetFrameLevel(bar:GetFrameLevel() + 1)
  clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
  clip:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
  clip:SetPoint("BOTTOMLEFT", well, "BOTTOMLEFT")
  clip:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT")
  clip:SetClipsChildren(true)

  -- Two textures per wisp layer, crossfading between consecutive flipbook frames.
  local function wispPair(sublevel)
    local pair = {}
    for i = 1, 2 do
      local t = masked(clip:CreateTexture(nil, "ARTWORK", nil, sublevel))
      t:SetPoint("CENTER", well, "CENTER")
      t:SetBlendMode("ADD")
      pair[i] = t
    end
    return pair
  end
  local wisp2 = wispPair(1)
  local wisp = wispPair(2)

  local core = masked(clip:CreateTexture(nil, "ARTWORK", nil, 3))
  core:SetTexture(M.orb_spark.file)
  core:SetPoint("CENTER", well, "CENTER")
  core:SetBlendMode("ADD")

  local sparks = {}
  for i = 1, SPARKS do
    local s = masked(clip:CreateTexture(nil, "ARTWORK", nil, 4))
    s:SetTexture(M.orb_spark.file)
    s:SetBlendMode("ADD")
    -- Fixed lane and pace per spark: a slow rise over 12-20 s.
    s.obX, s.obPhase, s.obPeriod = 0.2 + 0.6 * ((i * 0.37) % 1), i * 2.3, 12 + (i * 1.7) % 8
    sparks[i] = s
  end

  -- Deeper toward the glass (deep tone of the palette, inside the liquid only).
  local rim = masked(clip:CreateTexture(nil, "ARTWORK", nil, 5))
  rim:SetAllPoints(well)
  rim:SetTexture(M.orb_depth.file)

  -- Deeper toward the bottom of the liquid.
  local depth = masked(clip:CreateTexture(nil, "ARTWORK", nil, 5))
  depth:SetAllPoints(well)
  depth:SetColorTexture(1, 1, 1, 1)
  if CreateColor then depth:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0)) end

  -- Above the liquid: surface, rim shadow and glass.
  local top = CreateFrame("Frame", nil, well)
  top:SetAllPoints(well)
  top:SetFrameLevel(clip:GetFrameLevel() + 3) -- the health orb's shield sits in between

  -- Wavy surface anchored to the top of the fill: follows the value without any math. A thin
  -- glow added on the liquid (a solid band looked like a stripe of paint).
  local wave = masked(top:CreateTexture(nil, "ARTWORK"))
  wave:SetTexture(M.wave.file, "REPEAT", "CLAMP")
  wave:SetBlendMode("ADD")
  wave:SetAlpha(0.45)
  wave:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", 0, -1)
  wave:SetPoint("BOTTOMRIGHT", fill, "TOPRIGHT", 0, -1)

  local shade = masked(top:CreateTexture(nil, "OVERLAY"))
  shade:SetAllPoints(well)
  shade:SetTexture(M.vignette.file)

  local glass = masked(top:CreateTexture(nil, "OVERLAY", nil, 1))
  glass:SetAllPoints(well)
  glass:SetTexture(M.orb_glass.file)
  glass:SetBlendMode("ADD")
  glass:SetAlpha(0.8)

  local textHolder = CreateFrame("Frame", nil, HUD.over)
  HUD.Place(textHolder, x, D.orb.y, D.orb.w, D.orb.h)
  local pct = textHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  pct:SetPoint("CENTER", 0, 6)
  pct:SetTextColor(1, 1, 1)
  pct:SetShadowOffset(1, -1)
  local val = textHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  val:SetPoint("TOP", pct, "BOTTOM", 0, -1)

  local orb = { well = well, bar = bar, fill = fill, clip = clip, wisp = wisp, wisp2 = wisp2, core = core,
    sparks = sparks, depth = depth, rim = rim, wave = wave, glass = glass, pct = pct, val = val, t = 0, waveOffset = 0,
    masked = masked, wispPair = wispPair }

  table.insert(HUD.onResize, function(u)
    wave:SetHeight(math.max(2, 5 * u))
    local w = well:GetWidth()
    for i = 1, 2 do
      wisp[i]:SetSize(w * 1.08, w * 1.08)
      wisp2[i]:SetSize(w * 1.25, w * 1.25)
    end
    core:SetSize(w * 0.6, w * 0.6)
    for _, s in ipairs(sparks) do s:SetSize(8 * u, 8 * u) end
    if orb.shield then
      for i = 1, 2 do orb.shield.wisp[i]:SetSize(w * 1.08, w * 1.08) end
      orb.shield.edge:SetWidth(math.max(1, 3 * u))
    end
  end)

  -- One wisp layer at flipbook position f (frames, may be fractional), crossfaded.
  local function showFrame(pair, f, alpha, angle)
    local i = math.floor(f)
    local k = f - i
    pair[1]:SetTexCoord(Data.FlipbookCoords(i))
    pair[2]:SetTexCoord(Data.FlipbookCoords(i + 1))
    pair[1]:SetAlpha(alpha * (1 - k))
    pair[2]:SetAlpha(alpha * k)
    pair[1]:SetRotation(angle)
    pair[2]:SetRotation(angle)
  end

  -- Advance the animation (OnUpdate of every style but the still one).
  function orb:Step(elapsed)
    local st = self.styleDef
    self.t = self.t + elapsed
    local t = self.t
    local f = (t * st.fps) % FRAMES
    showFrame(self.wisp, f, st.wisp, t * st.spin)
    if st.wisp2 > 0 then showFrame(self.wisp2, (f + FRAMES / 2) % FRAMES, st.wisp2, t * st.spin2) end
    if st.core > 0 then self.core:SetAlpha(st.core * (0.6 + 0.4 * math.sin(t * 0.8))) end
    if st.sparks then
      local w, h = self.well:GetWidth(), self.well:GetHeight()
      for _, s in ipairs(self.sparks) do
        local rise = ((t + s.obPhase) / s.obPeriod) % 1
        s:ClearAllPoints()
        s:SetPoint("CENTER", self.well, "BOTTOMLEFT", s.obX * w + math.sin(t * 2 + s.obPhase) * 3, rise * h)
      end
    end
    if self.shield then showFrame(self.shield.wisp, (f + FRAMES / 4) % FRAMES, SHIELD_WISP, -t * st.spin) end
    self.waveOffset = (self.waveOffset + elapsed * WAVE_SPEED) % 1
    self.wave:SetTexCoord(self.waveOffset, self.waveOffset + 1, 0, 1)
  end

  function orb:SetStyle(key)
    local st = Data.ORB_STYLES[key]
    self.style, self.styleDef = key, st
    local file = M[st.sheet].file
    for i = 1, 2 do
      self.wisp[i]:SetTexture(file)
      self.wisp2[i]:SetTexture(file)
      self.wisp2[i]:SetShown(st.wisp2 > 0)
    end
    self.core:SetShown(st.core > 0)
    for _, s in ipairs(self.sparks) do s:SetShown(st.sparks) end
    if st.still then
      self.well:SetScript("OnUpdate", nil)
      showFrame(self.wisp, st.stillFrame, st.wisp, 0)
      showFrame(self.wisp2, st.stillFrame + FRAMES / 2, st.wisp2, 0)
    else
      self.well:SetScript("OnUpdate", function(_, elapsed) self:Step(elapsed) end)
      self:Step(0)
    end
  end

  function orb:SetPalette(pal)
    self.palette = pal
    local body, wispC, line = pal.body, pal.wisp, pal.line
    self.bar:SetStatusBarColor(body[1], body[2], body[3])
    for i = 1, 2 do
      self.wisp[i]:SetVertexColor(wispC[1], wispC[2], wispC[3])
      self.wisp2[i]:SetVertexColor(clamp(body[1] * 1.8), clamp(body[2] * 1.8), clamp(body[3] * 1.8))
    end
    self.core:SetVertexColor(wispC[1], wispC[2], wispC[3])
    for _, s in ipairs(self.sparks) do s:SetVertexColor(line[1], line[2], line[3]) end
    self.wave:SetVertexColor(line[1], line[2], line[3])
    self.rim:SetVertexColor(pal.deep[1], pal.deep[2], pal.deep[3])
  end

  orb:SetStyle(Data.OrbStyle(nil))
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

-- PoE2-style energy shield on the health orb: the player's absorbs as a blue crescent filling
-- the orb from the right (absorb / max health of its width), swirling like the liquid.
local function makeShield(orb)
  local bar = CreateFrame("StatusBar", nil, orb.well)
  bar:SetAllPoints(orb.well)
  bar:SetFrameLevel(orb.clip:GetFrameLevel() + 1)
  bar:SetOrientation("HORIZONTAL")
  bar:SetReverseFill(true)
  bar:SetStatusBarTexture(M.liquid.file)
  bar:SetStatusBarColor(SHIELD[1] * 0.45, SHIELD[2] * 0.45, SHIELD[3] * 0.45, 0.85)
  local fill = orb.masked(bar:GetStatusBarTexture())
  local clip = CreateFrame("Frame", nil, bar)
  clip:SetFrameLevel(bar:GetFrameLevel() + 1)
  clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
  clip:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
  clip:SetPoint("TOPRIGHT", orb.well, "TOPRIGHT")
  clip:SetPoint("BOTTOMRIGHT", orb.well, "BOTTOMRIGHT")
  clip:SetClipsChildren(true)
  local wisp = {}
  for i = 1, 2 do
    local t = orb.masked(clip:CreateTexture(nil, "ARTWORK", nil, 1))
    t:SetPoint("CENTER", orb.well, "CENTER")
    t:SetBlendMode("ADD")
    t:SetTexture(M.fluid_a.file)
    t:SetVertexColor(SHIELD[1], SHIELD[2], SHIELD[3])
    wisp[i] = t
  end
  -- Bright line where the shield meets the life.
  local edge = orb.masked(clip:CreateTexture(nil, "ARTWORK", nil, 2))
  edge:SetPoint("TOPLEFT", clip, "TOPLEFT")
  edge:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT")
  edge:SetColorTexture(1, 1, 1, 1)
  edge:SetBlendMode("ADD")
  edge:SetVertexColor(SHIELD[1], SHIELD[2], SHIELD[3], 0.8)
  orb.shield = { bar = bar, fill = fill, clip = clip, wisp = wisp, edge = edge }
  bar:Hide()
end

local health = makeOrb(D.orb.x)
makeShield(health)
local power = makeOrb(ns.Layout.MirrorX(D.width, D.orb.x, D.orb.w))
ns.Orbs.health, ns.Orbs.power = health, power
health:SetPalette(Data.OrbPalette("HEALTH"))
power:SetPalette(Data.OrbPalette("MANA"))

-- Both orbs share the style (setting "orbStyle"); an unknown saved value falls back to "a".
function ns.Orbs.SetStyle(key)
  key = Data.OrbStyle(key)
  if ns.db then ns.db.orbStyle = key end
  health:SetStyle(key)
  power:SetStyle(key)
end

local function updateHealth()
  local cur, max = UnitHealth("player"), UnitHealthMax("player")
  health.bar:SetMinMaxValues(0, max)
  health.bar:SetValue(cur)
  setTexts(health, cur, max, UnitHealthPercent and function() return UnitHealthPercent("player", true, curve()) end)
end

-- Absorbs may be secret values: the StatusBar takes them as they are; only the show/hide test
-- compares, in pcall (shown when it cannot tell).
local function updateShield()
  local bar = health.shield.bar
  if not UnitGetTotalAbsorbs then bar:Hide(); return end
  local absorb = UnitGetTotalAbsorbs("player")
  bar:SetMinMaxValues(0, UnitHealthMax("player"))
  bar:SetValue(absorb or 0)
  local ok, has = pcall(function() return absorb > 0 end)
  bar:SetShown(not ok or has)
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
  power:SetPalette(Data.OrbPalette(token or "MANA"))
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

ns.On("PLAYER_ENTERING_WORLD", function()
  ns.Orbs.SetStyle(ns.db and ns.db.orbStyle)
  updateHealth()
  updateShield()
  updatePowerColor()
  ns.Orbs.ApplyTextVisibility()
end)
ns.On("UNIT_HEALTH", forPlayer(updateHealth))
ns.On("UNIT_MAXHEALTH", forPlayer(function() updateHealth(); updateShield() end))
ns.On("UNIT_ABSORB_AMOUNT_CHANGED", forPlayer(updateShield))
ns.On("UNIT_POWER_FREQUENT", forPlayer(updatePower))
ns.On("UNIT_MAXPOWER", forPlayer(updatePower))
ns.On("UNIT_DISPLAYPOWER", forPlayer(updatePowerColor))
ns.On("UPDATE_SHAPESHIFT_FORM", updatePowerColor)
