local _, ns = ...

-- Death knight: ready runes in their type's colour (blood, frost, unholy, death; by spec on clients
-- without rune types), the seconds left on each recharging rune, runic power as a thin bar under
-- the runes, and Frost Fever / Blood Plague timers on the target.
local DeathKnight = { cdTexts = {} }
ns.DeathKnight = DeathKnight

local RUNES = 6
local TYPE_COLORS = {
  { 0.85, 0.15, 0.2 },  -- blood
  { 0.3, 0.85, 0.25 },  -- unholy
  { 0.1, 0.75, 0.95 },  -- frost
  { 0.65, 0.3, 0.95 },  -- death
}
local SPEC_TYPE = { 1, 3, 2 } -- Blood, Frost, Unholy specs: the type whose colour they use

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("DEATHKNIGHT") end
local function secret(v) return issecretvalue and issecretvalue(v) end

local frame = CreateFrame("Frame", nil, UIParent)
DeathKnight.frame = frame

-- Rune colours (ClassResource asks for each lit gem) ------------------------------------------------------
ns.ClassResource.GemColor = function(i)
  if not (mine() and on("c_dk_types")) or i > RUNES then return nil end
  local kind = GetRuneType and GetRuneType(i)
  if secret(kind) or not TYPE_COLORS[kind or 0] then
    kind = SPEC_TYPE[GetSpecialization and GetSpecialization() or 0]
  end
  local c = TYPE_COLORS[kind or 0]
  if c then return c[1], c[2], c[3] end
end

-- Seconds left on each rune ---------------------------------------------------------------------
for i = 1, RUNES do
  local t = ns.ClassResource.holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("CENTER", ns.ClassResource.gems[i], "CENTER", 0, 0)
  t:Hide()
  DeathKnight.cdTexts[i] = t
end

local function cooldowns()
  local show = mine() and on("c_dk_cd") and db().resStyle ~= "bar"
  for i, t in ipairs(DeathKnight.cdTexts) do
    local left
    if show then
      local ok, start, duration, ready = pcall(GetRuneCooldown, i)
      if ok and not ready and not secret(start) and not secret(duration) and start and duration and duration > 0 then
        left = start + duration - GetTime()
      end
    end
    if left and left > 0 then
      ns.Look.SetFont(t, 13)
      t:SetText(tostring(math.ceil(left)))
      t:Show()
    else
      t:Hide()
    end
  end
end

-- Runic power -----------------------------------------------------------------------------------
local rp = CreateFrame("StatusBar", nil, UIParent)
rp:SetHeight(5)
ns.Widgets.Panel(rp)
rp:Hide()
DeathKnight.rp = rp

local function runicPower()
  if not (mine() and on("c_dk_rp")) then rp:Hide() return end
  local holder = ns.ClassResource.holder
  rp:ClearAllPoints()
  rp:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -3)
  rp:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -3)
  rp:SetStatusBarTexture(ns.Look.BarTexture())
  rp:SetStatusBarColor(ns.Data.PowerColor("RUNIC_POWER"))
  rp:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.RunicPower)) -- secret values are fine here
  rp:SetValue(UnitPower("player", Enum.PowerType.RunicPower))
  rp:Show()
end

-- Diseases --------------------------------------------------------------------------------------
local timers = ns.Classes.NewTimers("ObsidianUIDeathKnightTimers", "dktimers", "Doenças (Cavaleiro da Morte)", {
  { label = "Febre Gélida", unit = "target", ids = { 55095 }, color = { 0.1, 0.75, 0.95 }, mine = true },
  { label = "Peste Sanguínea", unit = "target", ids = { 55078, 191587 }, color = { 0.3, 0.85, 0.25 }, mine = true },
})
DeathKnight.bars = timers.bars
local function timerUpdate(unit) timers:Update(unit, mine() and on("c_dk_dis")) end

-- Setup -----------------------------------------------------------------------------------------
function DeathKnight.Refresh()
  if not mine() then return end
  timers:Place()
  frame:SetScript("OnUpdate", function()
    timers:Tick()
    cooldowns()
  end)
  ns.ClassResource.Redraw()
  runicPower()
  timerUpdate()
end

ns.On("PLAYER_LOGIN", function() DeathKnight.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(DeathKnight.Refresh) end)
ns.On("RUNE_TYPE_UPDATE", function() if mine() then ns.ClassResource.Redraw() end end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token)
  if unit == "player" and token == "RUNIC_POWER" and mine() then runicPower() end
end)
ns.On("UNIT_MAXPOWER", function(_, unit) if unit == "player" and mine() then runicPower() end end)
ns.On("PLAYER_TARGET_CHANGED", function() if mine() then timerUpdate("target") end end)
ns.On("UNIT_AURA", function(_, unit) if mine() and unit == "target" then timerUpdate(unit) end end)

ns.Classes.Register("DEATHKNIGHT", "Cavaleiro da Morte", {
  { kind = "toggle", label = "Runas por tipo (sangue, gelo, profano)", key = "c_dk_types", default = true,
    onChange = function() ns.ClassResource.Redraw() end, help = "Cada runa pronta na cor do seu tipo." },
  { kind = "toggle", label = "Tempo de recarga em cada runa", key = "c_dk_cd", default = true,
    onChange = cooldowns, help = "Segundos que faltam em cima das runas apagadas." },
  { kind = "toggle", label = "Poder rúnico em barra", key = "c_dk_rp", default = true,
    onChange = runicPower, help = "Barra fina logo abaixo das runas." },
  { kind = "toggle", label = "Doenças no alvo", key = "c_dk_dis", default = true,
    onChange = function() timerUpdate() end, help = "Febre Gélida e Peste Sanguínea, acima da barra de cast." },
})
