local _, ns = ...

-- Hide the default frames the HUD replaces. Cast bar, stance/pet bars and extra buttons are
-- repositioned by their own modules instead.
local HIDE = { "mainbar", "multibl", "multibr", "multir", "multil", "overridebar", "micromenu", "bagsbar", "statusbar",
  "playerframe", "targetframe", "focusframe", "buffframe", "debuffframe" }

local hidden = CreateFrame("Frame")
hidden:Hide()
ns.hiddenParent = hidden

function ns.HideFrame(frame)
  if not frame then return end
  if frame.IsProtected and frame:IsProtected() then
    frame:SetParent(hidden)
  else
    if frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
    frame:Hide()
    frame:SetParent(hidden)
  end
end

ns.On("PLAYER_LOGIN", function()
  ns.RunOutOfCombat(function()
    for _, key in ipairs(HIDE) do
      ns.HideFrame((ns.Resolve.First(ns.Data.FRAME_CANDIDATES[key])))
    end
  end)
end)
