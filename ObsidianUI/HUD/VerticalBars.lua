local _, ns = ...

-- Optional vertical bars on the right edge (spec 4.5). One enabled: single column art;
-- both enabled: the joined two-column art, with no frame between the columns.
-- Placed in the gap between the minimap (bottom at 0.242 H) and the bottom HUD.
local VerticalBars = { TOP = 0.255, GAP = 0.012 }
ns.VerticalBars = VerticalBars

local container = CreateFrame("Frame", "ObsidianUIVerticalBars", UIParent, "SecureHandlerBaseTemplate")
VerticalBars.container = container
container:SetFrameStrata("LOW")
local art = container:CreateTexture(nil, "ARTWORK")
art:SetAllPoints(container)
VerticalBars.art = art

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

local function placeColumn(buttons, spec, col, height)
  local u = height / spec.h
  for i, b in ipairs(buttons) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", container, "TOPLEFT", spec.cols[col] * u, -spec.rows[i] * u)
    b:SetSize(spec.slot.w * u, spec.slot.h * u)
    b.obEnabled = true
    b:Show()
  end
end

-- Moderno: columns of slot frames, no art; slots as big as the action bar's when they fit.
local function placeModern(on, height)
  local g = ns.HUD.modernBar
  local pitch = math.min(g.slot + g.gap, height / 12)
  local slot = pitch - g.gap
  local inset = slot * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  container:SetSize(#on * pitch - g.gap, 12 * pitch - g.gap)
  art:Hide()
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
      local spec = #on == 1 and ns.Data.VBAR1 or ns.Data.VBAR2
      local _, screenH = UIParent:GetSize()
      local hudH = ns.HUD.h or 0.25 * screenH
      local height = screenH * (1 - VerticalBars.TOP - VerticalBars.GAP) - hudH
      container:ClearAllPoints()
      container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -VerticalBars.TOP * screenH)
      if ns.HUD.modern then
        placeModern(on, height)
      else
        container:SetSize(spec.w * height / spec.h, height)
        ns.Media.Apply(art, #on == 1 and "vbar1" or "vbar2")
        art:Show()
        for col, buttons in ipairs(on) do placeColumn(buttons, spec, col, height) end
      end
      container:Show()
    end
    ns.ActionBars.UpdateBindings()
    VerticalBars.PlaceTracker()
  end)
end

-- The objective tracker sits left of the bars while they are shown (Edit Mode puts it back on
-- the right edge, over them); otherwise under the minimap on the right.
function VerticalBars.PlaceTracker()
  local tracker = ns.Resolve.First(ns.Data.FRAME_CANDIDATES.objectivetracker)
  if not tracker then return end
  ns.Pin(tracker, function(f)
    local _, screenH = UIParent:GetSize()
    f:ClearAllPoints()
    if container:IsShown() then
      f:SetPoint("TOPRIGHT", container, "TOPLEFT", -10, 0)
    else
      f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -0.012 * screenH, -VerticalBars.TOP * screenH)
    end
  end)
end

ns.On("PLAYER_LOGIN", VerticalBars.Refresh)
ns.On("DISPLAY_SIZE_CHANGED", VerticalBars.Refresh)
ns.On("UI_SCALE_CHANGED", VerticalBars.Refresh)

table.insert(ns.HUD.onResize, VerticalBars.Refresh)
