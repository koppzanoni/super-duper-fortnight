local _, ns = ...

-- The HUD's root: one layer frame for the buttons and texts, and the layout pass every piece hooks
-- into (HUD.onResize). The Moderno HUD (spec 2026-10-23-hud-moderno) is the only HUD: the stone
-- one retired (git tag hud-pedra-final).
-- HUD.modernBar: geometry of the action bar grid; HUD.h: its top above the screen bottom, which
-- the frames placed above the HUD go by.
local HUD = { onResize = {}, modern = true }
ns.HUD = HUD

local root = CreateFrame("Frame", "ObsidianUIHUD", UIParent)
root:SetFrameStrata("LOW")
root:SetFrameLevel(1)
root:SetAllPoints(UIParent)
HUD.frame = root

HUD.over = CreateFrame("Frame", nil, root)
HUD.over:SetAllPoints(root)
HUD.over:SetFrameLevel(root:GetFrameLevel() + 5)

function HUD.Layout()
  local W, H = UIParent:GetSize()
  local db = ns.db or {}
  HUD.W = W
  HUD.modernBar = ns.Layout.ModernBar(H, (db.scale or 1) * ns.Movers.Scale("bar"), db.modernRows or 2, db.modernCols or 12)
  HUD.h = HUD.modernBar.bottom + HUD.modernBar.height
  for _, fn in ipairs(HUD.onResize) do fn() end
end

local function relayout() ns.RunOutOfCombat(HUD.Layout) end
ns.On("PLAYER_LOGIN", relayout)
ns.On("UI_SCALE_CHANGED", relayout)
ns.On("DISPLAY_SIZE_CHANGED", relayout)
