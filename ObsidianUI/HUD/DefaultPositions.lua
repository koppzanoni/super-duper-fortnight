local _, ns = ...

-- First load only: move the default frames that stay on screen away from the HUD.
-- Afterwards the user and Edit Mode own their positions.
local function apply()
  local W, H = UIParent:GetSize()
  local s = H / 900
  local hudTop = ns.HUD.h or 0.25 * H

  local chat = ChatFrame1
  if chat then
    chat:ClearAllPoints()
    chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.012 * W, hudTop + 80 * s)
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(chat) end
  end

  local tracker = ns.Resolve.First(ns.Data.FRAME_CANDIDATES.objectivetracker)
  if tracker then
    tracker:ClearAllPoints()
    tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -0.11 * H, -0.27 * H)
  end

  if AlertFrame then
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("TOP", UIParent, "TOP", 0, -0.18 * H)
  end
end

ns.On("PLAYER_ENTERING_WORLD", function()
  if not ns.db or ns.db.positioned then return end
  ns.RunOutOfCombat(function()
    apply()
    ns.db.positioned = true
  end)
end)
