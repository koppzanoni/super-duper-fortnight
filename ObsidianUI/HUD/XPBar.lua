local _, ns = ...

-- One thin XP bar on a dark backing right under the action bar.
local HUD = ns.HUD

local rested = CreateFrame("StatusBar", nil, HUD.over)
local xp = CreateFrame("StatusBar", nil, HUD.over)
for _, bar in ipairs({ rested, xp }) do
  bar:SetStatusBarTexture(ns.MediaManifest.bar_fill.file)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
end
xp:SetStatusBarColor(0.79, 0.64, 0.29)
rested:SetStatusBarColor(0.0, 0.44, 0.87, 0.6)
xp:SetFrameLevel(rested:GetFrameLevel() + 1)
ns.XPBar = { xp = xp, rested = rested }
local backing = rested:CreateTexture(nil, "BACKGROUND", nil, -8)
backing:SetColorTexture(0, 0, 0, 0.55)
backing:Hide()

table.insert(HUD.onResize, function()
  local g = HUD.modernBar
  for _, bar in ipairs({ rested, xp }) do
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, g.bottom - 9 * g.s)
    bar:SetSize(g.width, 5 * g.s)
  end
  backing:SetPoint("TOPLEFT", rested, "TOPLEFT", -1, 1)
  backing:SetPoint("BOTTOMRIGHT", rested, "BOTTOMRIGHT", 1, -1)
  backing:Show()
end)

local function update()
  local level, maxLevel = UnitLevel("player"), GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
  if level >= maxLevel then
    xp:SetValue(0); rested:SetValue(0)
    return
  end
  local cur, max = UnitXP("player"), UnitXPMax("player")
  if max == 0 then max = 1 end
  local restedXP = GetXPExhaustion() or 0
  xp:SetMinMaxValues(0, max); xp:SetValue(cur)
  rested:SetMinMaxValues(0, max); rested:SetValue(math.min(max, cur + restedXP))
end

ns.On("PLAYER_LOGIN", update)
ns.On("PLAYER_XP_UPDATE", update)
ns.On("UPDATE_EXHAUSTION", update)
ns.On("PLAYER_LEVEL_UP", update)
