local _, ns = ...

-- One XP bar, inside the groove at the bottom of the HUD (spec 4.2).
local D = ns.Data.HUD
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

table.insert(HUD.onResize, function(u, _, W)
  local left = ns.Layout.MapX(D.xp.x, W, u)
  for _, bar in ipairs({ rested, xp }) do
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", HUD.frame, "TOPLEFT", left, -D.xp.y * u)
    bar:SetSize(W - 2 * left, D.xp.h * u)
  end
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
