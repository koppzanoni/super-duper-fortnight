local _, ns = ...

-- Class resource (combo points, holy power, runes, soul shards, chi, arcane charges) above the
-- action bar: Moderno gems, or one bar with a line between each point (setting "resStyle"). The
-- bar takes the game's values straight into a StatusBar, so it keeps working when combat makes
-- them secret; the gems need plain numbers and hide instead. Movable and resizable in the edit
-- mode; optionally hidden out of combat while empty. Hidden for classes without one.
local MAX_GEMS = 10
local SIZE, GAP = 0.033, 0.005 -- of the screen height
local ClassResource = { gems = {}, ticks = {} }
ns.ClassResource = ClassResource

-- Half the width of a row of `count` gems, for frames placed beside it.
function ClassResource.HalfWidth(count)
  local _, H = UIParent:GetSize()
  return (count * SIZE + (count - 1) * GAP) * H / 2
end

local holder = CreateFrame("Frame", "ObsidianUIClassResource", UIParent)
holder:SetFrameStrata("LOW")
ClassResource.holder = holder
local gems = ClassResource.gems
for i = 1, MAX_GEMS do gems[i] = holder:CreateTexture(nil, "ARTWORK") end

local bar = CreateFrame("StatusBar", nil, holder)
bar:SetAllPoints(holder)
bar:SetMinMaxValues(0, 1)
local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints(bar)
barBg:SetColorTexture(0, 0, 0, 0.6)
for i = 1, MAX_GEMS - 1 do
  local t = bar:CreateTexture(nil, "OVERLAY")
  t:SetColorTexture(0, 0, 0, 0.85)
  ClassResource.ticks[i] = t
end
ClassResource.bar = bar

local current -- { powerType, token, color }
-- Last drawn state: redraw only what changed (combo/energy events fire many times a second).
local shownCount, litState = nil, {}

local function db() return ns.db or {} end
-- ForceBar: a class module wants its resource as a bar whatever the setting (the monk's chi).
local function barStyle()
  if ClassResource.ForceBar and ClassResource.ForceBar() then return true end
  return db().resStyle == "bar"
end

local function specIndex()
  return GetSpecialization and GetSpecialization() or nil
end

local function color()
  local r, g, b = ns.Look.Color(current.token)
  if r then return r, g, b end
  return current.color.r, current.color.g, current.color.b
end

local function place(count)
  local _, H = UIParent:GetSize()
  local size, gap = SIZE * H, GAP * H
  local total = count * size + (count - 1) * gap
  holder:SetSize(math.max(1, total), barStyle() and size * 0.45 or size)
  ns.Movers.Register("res", "Recurso de classe", holder, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 34)
  end)
  ns.Movers.Place("res")
end

local function layoutGems(count)
  if count == shownCount then return end
  shownCount = count
  place(count)
  local _, H = UIParent:GetSize()
  local size, gap = SIZE * H, GAP * H
  for i, g in ipairs(gems) do
    g:ClearAllPoints()
    g:SetSize(size, size)
    g:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + gap), 0)
    g:SetShown(not barStyle() and i <= count)
  end
  bar:SetShown(barStyle())
  if barStyle() then
    bar:SetStatusBarTexture(ns.Look.BarTexture())
    for i, t in ipairs(ClassResource.ticks) do
      t:ClearAllPoints()
      t:SetWidth(2)
      t:SetPoint("TOP", bar, "TOPLEFT", holder:GetWidth() * i / count, 0)
      t:SetPoint("BOTTOM", bar, "BOTTOMLEFT", holder:GetWidth() * i / count, 0)
      t:SetShown(i < count)
    end
  end
end

local function setLit(i, lit)
  if litState[i] == lit then return end
  litState[i] = lit
  local g = gems[i]
  ns.Media.Apply(g, lit and "mod_gem_on" or ns.ModernTex("mod_gem_off"))
  if not (lit and current) then g:SetVertexColor(1, 1, 1) return end
  local r, gr, b
  if ClassResource.GemColor then r, gr, b = ClassResource.GemColor(i) end -- a class module's colour (rune types)
  if r then g:SetVertexColor(r, gr, b) else g:SetVertexColor(color()) end
end

-- Out of combat and empty: hidden when the setting asks for it.
local function idleHidden(empty)
  return db().resHide and empty and not UnitAffectingCombat("player")
end

local function updateRunes()
  layoutGems(6)
  local ready = 0
  for i = 1, 6 do
    local _, _, r = GetRuneCooldown(i)
    if r then ready = ready + 1 end
    setLit(i, r)
  end
  bar:SetMinMaxValues(0, 6)
  bar:SetValue(ready)
end

local function update()
  if not current or db().res_on == false then holder:Hide(); return end
  if current.powerType == Enum.PowerType.Runes then holder:Show(); updateRunes(); return end
  local value = UnitPower("player", current.powerType)
  local maxValue = UnitPowerMax("player", current.powerType)
  local secret = issecretvalue and (issecretvalue(value) or issecretvalue(maxValue))
  if secret then
    -- Gems cannot count secret values in Lua; the bar takes them as they are.
    if not barStyle() then holder:Hide(); return end
    holder:Show()
    layoutGems(shownCount or 5)
    bar:SetMinMaxValues(0, maxValue)
    bar:SetValue(value)
    return
  end
  local count = math.min(MAX_GEMS, maxValue or 0)
  if count <= 0 or idleHidden(value == 0) then holder:Hide(); return end
  holder:Show()
  layoutGems(count)
  bar:SetStatusBarColor(color())
  bar:SetMinMaxValues(0, count)
  bar:SetValue(value)
  for i = 1, count do setLit(i, i <= value) end
end
ClassResource.Update = update

-- Forget what was drawn (new resource, new colour, new style or new screen size).
local function redraw()
  shownCount, litState = nil, {}
  update()
end
ClassResource.Redraw = redraw

local function refreshResource()
  local _, classToken = UnitClass("player")
  local powerType = UnitPowerType("player")
  -- PowerTypeFor: a class module may read the resource as in another form (the druid's combo points)
  if ClassResource.PowerTypeFor then powerType = ClassResource.PowerTypeFor(classToken, powerType) or powerType end
  current = ns.Data.ClassResourceFor(classToken, specIndex(), powerType)
  redraw()
end
ClassResource.Refresh = refreshResource

local function onPower(_, unit, token)
  if unit ~= "player" or not current then return end
  if token and current.token and token ~= current.token then return end
  update()
end

ns.On("PLAYER_ENTERING_WORLD", refreshResource)
ns.On("PLAYER_SPECIALIZATION_CHANGED", refreshResource)
ns.On("UPDATE_SHAPESHIFT_FORM", refreshResource)
ns.On("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then refreshResource() end end)
ns.On("UNIT_POWER_FREQUENT", onPower)
ns.On("UNIT_MAXPOWER", onPower)
ns.On("RUNE_POWER_UPDATE", update)
ns.On("PLAYER_REGEN_DISABLED", update)
ns.On("PLAYER_REGEN_ENABLED", update)
table.insert(ns.HUD.onResize, redraw)
