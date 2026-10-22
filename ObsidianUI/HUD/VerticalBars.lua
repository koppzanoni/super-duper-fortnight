local _, ns = ...

-- Optional vertical bars on the right edge (spec 4.5). One enabled: single column art;
-- both enabled: the joined two-column art, with no frame between the columns.
local VerticalBars = {}
ns.VerticalBars = VerticalBars

local container = CreateFrame("Frame", "ObsidianUIVerticalBars", UIParent, "SecureHandlerBaseTemplate")
container:SetFrameStrata("LOW")
local art = container:CreateTexture(nil, "ARTWORK")
art:SetAllPoints(container)

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
      local height = 0.40 * screenH
      container:ClearAllPoints()
      container:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -4, -0.275 * screenH)
      container:SetSize(spec.w * height / spec.h, height)
      ns.Media.Apply(art, #on == 1 and "vbar1" or "vbar2")
      for col, buttons in ipairs(on) do placeColumn(buttons, spec, col, height) end
      container:Show()
    end
    ns.ActionBars.UpdateBindings()
  end)
end

ns.On("PLAYER_LOGIN", VerticalBars.Refresh)
ns.On("DISPLAY_SIZE_CHANGED", VerticalBars.Refresh)
ns.On("UI_SCALE_CHANGED", VerticalBars.Refresh)
