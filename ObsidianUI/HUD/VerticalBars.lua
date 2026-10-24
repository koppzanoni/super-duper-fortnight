local _, ns = ...

-- Optional vertical bars on the right edge: one or two columns of 12 slot frames, in the gap
-- between the minimap and the bottom HUD.
local VerticalBars = { TOP = 0.255, GAP = 0.012 }
ns.VerticalBars = VerticalBars

local container = CreateFrame("Frame", "ObsidianUIVerticalBars", UIParent, "SecureHandlerBaseTemplate")
VerticalBars.container = container
container:SetFrameStrata("LOW")

local bars = { {}, {} }
VerticalBars.bars = bars
for bar = 1, 2 do
  for i = 1, 12 do
    local e = ns.Data.VBAR_ACTIONS[bar][i]
    local b = ns.ActionBars.CreateButton(container, "ObsidianUIVBar" .. bar .. "Button" .. i, e.actionID, e.binding)
    b:SetFrameLevel(container:GetFrameLevel() + 2)
    b.obEnabled = false
    b:Hide()
    bars[bar][i] = b
  end
end

-- Slots as big as the action bar's when they fit.
local function placeModern(on, height)
  -- the action bar's geometry, or the same numbers when it was not laid out yet
  local db = ns.db or {}
  local _, screenH = UIParent:GetSize()
  local g = ns.HUD.modernBar or ns.Layout.ModernBar(screenH, db.scale or 1, db.modernRows or 2, db.modernCols or 12)
  local pitch = math.min(g.slot + g.gap, height / 12)
  local slot = pitch - g.gap
  local inset = slot * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  container:SetSize(#on * pitch - g.gap, 12 * pitch - g.gap)
  for col, buttons in ipairs(on) do
    for i, b in ipairs(buttons) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", container, "TOPLEFT", (col - 1) * pitch + inset, -(i - 1) * pitch - inset)
      b:SetSize(slot - 2 * inset, slot - 2 * inset)
      ns.ActionBars.ModernSlot(b, inset)
      b.obEnabled = true
      b:Show()
    end
  end
end

ns.Movers.Register("vbars", "Barras verticais", container, function(f)
  local _, screenH = UIParent:GetSize()
  f:ClearAllPoints()
  f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -VerticalBars.TOP * screenH)
end)

function VerticalBars.Refresh()
  ns.RunOutOfCombat(function()
    local db = ns.db or {}
    local on = {}
    if db.vbar1 then on[#on + 1] = bars[1] end
    if db.vbar2 then on[#on + 1] = bars[2] end
    for _, list in ipairs(bars) do
      for _, b in ipairs(list) do b.obEnabled = false; b:Hide() end
    end
    if #on == 0 then
      container:Hide()
    else
      local _, screenH = UIParent:GetSize()
      local hudH = ns.HUD.h or 0.25 * screenH
      local height = screenH * (1 - VerticalBars.TOP - VerticalBars.GAP) - hudH
      placeModern(on, height)
      ns.Movers.Place("vbars")
      container:Show()
    end
    ns.ActionBars.UpdateBindings()
    VerticalBars.PlaceTracker()
  end)
end

-- The objective tracker sits left of the bars while they are shown, otherwise under the minimap:
-- the quest tracker module places its holder (movable in the edit mode).
function VerticalBars.PlaceTracker()
  if ns.QuestTracker then ns.QuestTracker.Place() end
end

ns.On("PLAYER_LOGIN", VerticalBars.Refresh)
ns.On("DISPLAY_SIZE_CHANGED", VerticalBars.Refresh)
ns.On("UI_SCALE_CHANGED", VerticalBars.Refresh)

table.insert(ns.HUD.onResize, VerticalBars.Refresh)
