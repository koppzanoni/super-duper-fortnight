local _, ns = ...

-- First load only: move the default frames that stay on screen away from the HUD.
-- Afterwards the user and Edit Mode own their positions.
-- Edit Mode puts the chat back on every login, so it is moved whenever it overlaps the HUD.
local movingChat, chatHooked = false, false
local function moveChat()
  if movingChat then return end
  local W, H = UIParent:GetSize()
  local s = H / 900
  local hudTop = ns.HUD.h or 0.25 * H
  local chat = ChatFrame1
  if not chat or type(chat.GetBottom) ~= "function" then return end
  local bottom = chat:GetBottom()
  if bottom and bottom >= hudTop + 10 then return end
  movingChat = true
  chat:ClearAllPoints()
  chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0.012 * W, hudTop + 80 * s)
  if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(chat) end
  movingChat = false
end

-- Edit Mode re-anchors the chat after login (and on layout changes), back over the HUD:
-- check again every time something moves it. A chat the player put elsewhere is left alone.
local function watchChat()
  if chatHooked or not ChatFrame1 or type(ChatFrame1.GetBottom) ~= "function" then return end
  chatHooked = true
  hooksecurefunc(ChatFrame1, "SetPoint", function()
    if not movingChat then ns.RunOutOfCombat(moveChat) end
  end)
end

local function apply()
  local W, H = UIParent:GetSize()

  -- the objective tracker is placed by HUD/QuestTracker.lua (its holder moves in the edit mode)
  if AlertFrame then
    AlertFrame:ClearAllPoints()
    AlertFrame:SetPoint("TOP", UIParent, "TOP", 0, -0.18 * H)
  end
end

-- /obui reset: forget the dragged inventory spot and the edit mode's positions, put the default
-- frames back.
function ns.ResetPositions()
  if not ns.db then return end
  ns.db.invPos = nil
  ns.db.layout = nil -- what the edit mode saved
  ns.RunOutOfCombat(function()
    ns.HUD.Layout()
    for _, key in ipairs(ns.Movers.order) do ns.Movers.Place(key) end
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
  watchChat()
  ns.RunOutOfCombat(moveChat)
  if not ns.db or ns.db.positioned then return end
  ns.RunOutOfCombat(function()
    apply()
    ns.db.positioned = true
  end)
end)
