local _, ns = ...

-- First load only: move the default frames that stay on screen away from the HUD.
-- Afterwards the user and Edit Mode own their positions.
-- Edit Mode puts the chat back on every login, so it is moved whenever it overlaps the HUD.
local function moveChat()
  local W, H = UIParent:GetSize()
  local s = H / 900
  local hudTop = ns.HUD.h or 0.25 * H
  local chat = ChatFrame1
  if not chat or type(chat.GetBottom) ~= "function" then return end
  local bottom = chat:GetBottom()
  if bottom and bottom >= hudTop + 10 then return end
  chat:ClearAllPoints()
  chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.012 * W, hudTop + 80 * s)
  if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(chat) end
end

local function apply()
  local W, H = UIParent:GetSize()

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

-- /obui reset: forget the dragged inventory spot and put the default frames back.
function ns.ResetPositions()
  if not ns.db then return end
  ns.db.invPos = nil
  ns.RunOutOfCombat(function()
    apply()
    ns.db.positioned = true
    moveChat()
    if ns.Inventory then
      ns.Inventory.frame.obPlaced = false
      ns.Inventory.Layout()
    end
  end)
end

ns.On("PLAYER_ENTERING_WORLD", function()
  ns.RunOutOfCombat(moveChat)
  if not ns.db or ns.db.positioned then return end
  ns.RunOutOfCombat(function()
    apply()
    ns.db.positioned = true
  end)
end)
