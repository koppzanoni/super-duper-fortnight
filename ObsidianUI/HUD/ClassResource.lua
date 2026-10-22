local _, ns = ...

-- Class resource gems between the cast bar and the action bar. Hidden for classes without one.
local MAX_GEMS = 10
local holder = CreateFrame("Frame", "ObsidianUIClassResource", UIParent)
holder:SetFrameStrata("LOW")
local gems = {}
for i = 1, MAX_GEMS do
  local g = holder:CreateTexture(nil, "ARTWORK")
  gems[i] = g
end

local current -- { powerType, color }

local function specIndex()
  return GetSpecialization and GetSpecialization() or nil
end

local function layoutGems(count)
  local _, H = UIParent:GetSize()
  local size, gap = 0.033 * H, 0.005 * H
  local total = count * size + (count - 1) * gap
  holder:ClearAllPoints()
  holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, ns.Stack.BarTop() + 34)
  holder:SetSize(math.max(1, total), size)
  for i, g in ipairs(gems) do
    g:ClearAllPoints()
    g:SetSize(size, size)
    g:SetPoint("LEFT", holder, "LEFT", (i - 1) * (size + gap), 0)
    g:SetShown(i <= count)
  end
end

local function setLit(i, lit)
  local g = gems[i]
  ns.Media.Apply(g, lit and "gem_on" or "gem_off")
  if lit and current then g:SetVertexColor(current.color.r, current.color.g, current.color.b) else g:SetVertexColor(1, 1, 1) end
end

local function updateRunes()
  layoutGems(6)
  for i = 1, 6 do
    local _, _, ready = GetRuneCooldown(i)
    setLit(i, ready)
  end
end

local function update()
  if not current then holder:Hide(); return end
  if current.powerType == Enum.PowerType.Runes then holder:Show(); updateRunes(); return end
  local value = UnitPower("player", current.powerType)
  local maxValue = UnitPowerMax("player", current.powerType)
  -- Secret values cannot drive gem counts in Lua; hide instead of erroring (see /obui diag).
  if issecretvalue and (issecretvalue(value) or issecretvalue(maxValue)) then holder:Hide(); return end
  local count = math.min(MAX_GEMS, maxValue or 0)
  if count <= 0 then holder:Hide(); return end
  holder:Show()
  layoutGems(count)
  for i = 1, count do setLit(i, i <= value) end
end

local function refreshResource()
  local _, classToken = UnitClass("player")
  current = ns.Data.ClassResourceFor(classToken, specIndex(), (UnitPowerType("player")))
  update()
end

ns.On("PLAYER_ENTERING_WORLD", refreshResource)
ns.On("PLAYER_SPECIALIZATION_CHANGED", refreshResource)
ns.On("UPDATE_SHAPESHIFT_FORM", refreshResource)
ns.On("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" then refreshResource() end end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit) if unit == "player" then update() end end)
ns.On("UNIT_MAXPOWER", function(_, unit) if unit == "player" then update() end end)
ns.On("RUNE_POWER_UPDATE", update)
table.insert(ns.HUD.onResize, update)
