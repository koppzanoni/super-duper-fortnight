local _, ns = ...

-- Aura timer bars for the class modules (Slice and Dice, Rupture, Judgement...): thin Moderno bars
-- stacked above the cast bar, movable as one element. The game's duration object drives each
-- bar when it can (keeps running in combat with secret times); otherwise the aura's own times.
-- spec: { label, unit = "player"|"target", ids = { spellID... }, color = { r, g, b }, mine = only yours }
local W = ns.Widgets
local BAR_W, BAR_H, BAR_GAP = 220, 11, 4

local Timers = {}
Timers.__index = Timers

function ns.Classes.NewTimers(name, key, label, specs)
  local t = setmetatable({ key = key, label = label, bars = {} }, Timers)
  local holder = CreateFrame("Frame", name, UIParent)
  holder:SetSize(BAR_W, #specs * BAR_H + (#specs - 1) * BAR_GAP)
  t.frame = holder
  for i, spec in ipairs(specs) do
    local b = CreateFrame("StatusBar", nil, holder)
    b:SetSize(BAR_W, BAR_H)
    b:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (BAR_H + BAR_GAP))
    W.Panel(b)
    b:SetStatusBarColor(spec.color[1], spec.color[2], spec.color[3])
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
    b.label:SetText(spec.label)
    b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.time:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.spec = spec
    b:Hide()
    t.bars[i] = b
  end
  return t
end

-- The first of the spec's auras on its unit (yours only when spec.mine).
local function findAura(spec)
  if not UnitExists(spec.unit) then return nil end
  local A = C_UnitAuras
  for _, id in ipairs(spec.ids) do
    local a
    if spec.unit == "player" and A.GetPlayerAuraBySpellID then a = A.GetPlayerAuraBySpellID(id)
    elseif spec.unit ~= "player" and A.GetUnitAuraBySpellID then a = A.GetUnitAuraBySpellID(spec.unit, id) end
    if a then
      local ok, yours = pcall(function() return a.isFromPlayerOrPlayerPet == true end)
      if not spec.mine or (ok and yours) then return a end
    end
  end
end

-- Looks the auras up again (all bars, or only those of `unit`); enabled false hides them.
function Timers:Update(unit, enabled)
  for _, b in ipairs(self.bars) do
    local spec = b.spec
    if not unit or unit == spec.unit then
      local a = enabled and findAura(spec)
      if a then
        b.aura = a
        b.timer = C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(spec.unit, a.auraInstanceID)
        local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil
        b.driven = b.timer and b.SetTimerDuration and pcall(b.SetTimerDuration, b, b.timer, nil, direction) or false
        b:SetStatusBarTexture(ns.Look.BarTexture())
        b:SetStatusBarColor(spec.color[1], spec.color[2], spec.color[3])
        ns.Look.SetFont(b.label, 10)
        ns.Look.SetFont(b.time, 10)
        b:Show()
      else
        b.aura, b.timer = nil, nil
        b:Hide()
      end
    end
  end
end

-- Each frame: seconds left (and the fill when the game's timer does not drive the bar).
function Timers:Tick()
  for _, b in ipairs(self.bars) do
    local a = b.aura
    if a and b:IsShown() then
      local ok, left, total = pcall(function() return a.expirationTime - GetTime(), a.duration end)
      if ok and total and total > 0 then
        if not b.driven then b:SetMinMaxValues(0, total); b:SetValue(math.max(0, left)) end
        b.time:SetText(string.format("%.0f", math.max(0, left)))
      else
        b.time:SetText("")
      end
    end
  end
end

-- Into the edit mode; by default just above the cast bar.
function Timers:Place()
  ns.Movers.Register(self.key, self.label, self.frame, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", ns.CastBar.art or ns.Stack.Anchor(), "TOP", 0, 8)
  end)
  ns.Movers.Place(self.key)
end
