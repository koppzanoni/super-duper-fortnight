local _, ns = ...

-- Data bars under the action bar: experience (with rested) and, below it, the watched reputation
-- coloured by standing. Experience hides at the maximum level and reputation when no faction is
-- watched; the other one moves up. Text always, on mouse over or never; height and each bar
-- on/off from the Data bars page; movable in the edit mode.
local HUD = ns.HUD
local GAP = 2

local holder = CreateFrame("Frame", "ObsidianUIDataBars", UIParent)
holder:SetFrameStrata("LOW")
holder:EnableMouse(true)

local function newBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  -- rounded ends: the track does not stop in a hard cut
  local backing = ns.Widgets.SoftTexture(bar, "BACKGROUND", 0, 0, 0, 0.55, -8)
  backing:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
  backing:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
  return bar
end

local rested = newBar(holder)
local xp = CreateFrame("StatusBar", nil, rested)
xp:SetAllPoints(rested)
xp:SetMinMaxValues(0, 1)
xp:SetValue(0)
xp:SetFrameLevel(rested:GetFrameLevel() + 1)
xp:SetStatusBarColor(0.56, 0.42, 0.95)
rested:SetStatusBarColor(0.17, 0.67, 0.87, 0.45)
local rep = newBar(holder)
for _, bar in ipairs({ xp, rep }) do
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
end

local DataBars = { holder = holder, xp = xp, rested = rested, rep = rep }
ns.DataBars = DataBars
ns.XPBar = DataBars

-- Standing names and colours (the game's when it has them).
local STANDING = { "Odiado", "Hostil", "Inamistoso", "Neutro", "Amistoso", "Honrado", "Reverenciado", "Exaltado" }
local STANDING_COLOR = {
  { 0.8, 0.13, 0.13 }, { 0.8, 0.13, 0.13 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 },
  { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 }, { 0, 0.6, 0.1 },
}
local function standingName(r)
  local name = _G["FACTION_STANDING_LABEL" .. r]
  return type(name) == "string" and name or STANDING[r] or ""
end
local function standingColor(r)
  local c = type(FACTION_BAR_COLORS) == "table" and FACTION_BAR_COLORS[r]
  if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
  c = STANDING_COLOR[r] or STANDING_COLOR[4]
  return c[1], c[2], c[3]
end

local function db() return ns.db or {} end
local function textMode() return db().dataText or "hover" end
local hovering = false

local function pct(cur, max) return math.floor(cur / max * 100 + 0.5) .. "%" end
-- "cur / max (pct)": skipped (no text) when the game hands secret values.
local function amount(cur, max)
  local ok, line = pcall(function()
    return ns.Look.Number(cur) .. " / " .. ns.Look.Number(max) .. "  (" .. pct(cur, max) .. ")"
  end)
  return ok and line or ""
end

local function showText()
  local on = textMode() == "always" or (textMode() == "hover" and hovering)
  xp.text:SetShown(on)
  rep.text:SetShown(on)
end

local function watched()
  return C_Reputation and C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
end

local function showsXP()
  local level, maxLevel = UnitLevel("player"), GetMaxPlayerLevel and GetMaxPlayerLevel() or 60
  return db().xp_on ~= false and level < maxLevel
end
local function shownFaction() return db().rep_on ~= false and watched() end

-- Room (unscaled) the bars need between the action bar and the screen bottom; 0 once moved away.
local MARGIN_TOP, MARGIN_BOTTOM = 7, ns.Layout.MARGIN -- the action slots' gap above, the screen margin under
-- Bars that can show text are at least as tall as it (thinner ones only without text).
local TEXT_MIN = 10
local function barHeight()
  local h = db().dataHeight or 5
  if textMode() ~= "never" then return math.max(h, TEXT_MIN) end
  return h
end
function DataBars.Room()
  if ns.Movers.Saved("databars") then return 0 end
  local n = (showsXP() and 1 or 0) + (shownFaction() and 1 or 0)
  if n == 0 then return 0 end
  local h = barHeight()
  return MARGIN_TOP + n * (h + GAP) - GAP + MARGIN_BOTTOM
end
local laidOutRoom

local function update()
  local d = db()
  -- A bar appeared or went away: the action bar makes room or drops back (out of combat).
  if laidOutRoom and DataBars.Room() ~= laidOutRoom then
    laidOutRoom = nil
    ns.RunOutOfCombat(HUD.Layout)
    return
  end
  local showXP = showsXP()
  if showXP then
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if max == 0 then max = 1 end
    local restedXP = GetXPExhaustion() or 0
    xp:SetMinMaxValues(0, max); xp:SetValue(cur)
    rested:SetMinMaxValues(0, max); rested:SetValue(math.min(max, cur + restedXP))
    local line = amount(cur, max)
    if line ~= "" and restedXP > 0 then line = line .. "  ·  descanso " .. pct(restedXP, max) end
    xp.text:SetText(line)
  end
  local faction = shownFaction()
  if faction then
    local lo, hi = faction.currentReactionThreshold or 0, faction.nextReactionThreshold or 1
    local max, cur = math.max(1, hi - lo), (faction.currentStanding or lo) - lo
    rep:SetMinMaxValues(0, max)
    rep:SetValue(cur)
    rep:SetStatusBarColor(standingColor(faction.reaction))
    rep.text:SetText(faction.name .. ": " .. standingName(faction.reaction) .. "  " .. amount(cur, max))
  end

  -- Stack what is shown from the top of the holder.
  local h = barHeight()
  local g = HUD.modernBar
  local s = g and g.s or 1
  local size = math.max(8, math.min(ns.Look.TYPE.small * s, math.floor((h - 1) * s))) -- small, or what fits
  for _, bar in ipairs({ xp, rep }) do ns.Look.SetFont(bar.text, size) end
  local y = 0
  rested:SetShown(showXP)
  rep:SetShown(faction and true or false)
  for _, bar in ipairs({ rested, rep }) do
    if bar:IsShown() then
      bar:ClearAllPoints()
      bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
      bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -y)
      bar:SetHeight(h * s)
      y = y + (h + GAP) * s
    end
  end
  holder:SetShown(y > 0)
  holder:SetHeight(math.max(1, y - GAP * s))
  showText()
end
DataBars.Update = update

holder:SetScript("OnEnter", function() hovering = true; showText() end)
holder:SetScript("OnLeave", function() hovering = false; showText() end)

table.insert(HUD.onResize, function()
  local g = HUD.modernBar
  for _, bar in ipairs({ rested, xp, rep }) do bar:SetStatusBarTexture(ns.Look.BarTexture()) end
  -- as wide as the slots' visible frames, not the bar's whole box
  local inset = g.slot * ns.Data.MODERN_SLOT.inset / ns.Data.MODERN_SLOT.size
  holder:SetWidth(g.width - 2 * inset + 2)
  laidOutRoom = DataBars.Room()
  ns.Movers.Register("databars", "Barras de dados", holder, function(f)
    f:ClearAllPoints()
    f:SetPoint("TOP", ns.ActionBars.modernFrame, "BOTTOM", 0, -MARGIN_TOP * g.s)
  end)
  ns.Movers.Place("databars")
  update()
end)

ns.On("PLAYER_LOGIN", update)
ns.On("PLAYER_XP_UPDATE", update)
ns.On("UPDATE_EXHAUSTION", update)
ns.On("PLAYER_LEVEL_UP", update)
ns.On("UPDATE_FACTION", update)
