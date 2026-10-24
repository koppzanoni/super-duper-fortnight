local _, ns = ...

-- The pet's health (and mana, for demons) as thin bars under the player's resource bar. Status
-- bars take the game's values as they are, so they keep working when combat makes them secret.
local Pet = {}
Pet.__index = Pet

local function bar(r, g, b)
  local s = CreateFrame("StatusBar", nil, UIParent)
  s:SetHeight(4)
  ns.Widgets.Panel(s)
  s.color = { r, g, b }
  s:Hide()
  return s
end

function ns.Classes.NewPetBars(withMana)
  local p = setmetatable({ health = bar(0.38, 0.84, 0.2) }, Pet)
  if withMana then p.mana = bar(ns.Data.PowerColor("MANA")) end
  return p
end

local function fill(s, below, value, max)
  s:ClearAllPoints()
  s:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
  s:SetPoint("TOPRIGHT", below, "BOTTOMRIGHT", 0, -2)
  s:SetStatusBarTexture(ns.Look.BarTexture())
  s:SetStatusBarColor(s.color[1], s.color[2], s.color[3])
  s:SetMinMaxValues(0, max)
  s:SetValue(value)
  s:Show()
end

-- enabled: the class wants the bars now (its class, its setting).
function Pet:Update(enabled)
  local power = ns.UnitFrames.frames.player and ns.UnitFrames.frames.player.power
  if not (enabled and power and UnitExists("pet")) then
    self.health:Hide()
    if self.mana then self.mana:Hide() end
    return
  end
  fill(self.health, power, UnitHealth("pet"), UnitHealthMax("pet"))
  if self.mana then fill(self.mana, self.health, UnitPower("pet"), UnitPowerMax("pet")) end
end
