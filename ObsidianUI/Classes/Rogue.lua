local _, ns = ...

-- Rogue: energy tick spark on the player's energy bar (only when energy really comes in 2 s
-- ticks; smooth regeneration shows nothing), combo points under the target (option), Slice and
-- Dice and Rupture timer bars driven by the game's duration objects (they keep running in combat),
-- and the "poisons running out" switch the reminders read. Secret values hide a piece instead
-- of erroring.
local Rogue = { dots = {}, bars = {}, ticking = false }
ns.Rogue = Rogue

local W = ns.Widgets
local TICK = 2          -- seconds between energy ticks
local TICK_JUMP = 15    -- an energy rise this big is a tick
local DOT, DOT_GAP = 16, 4
local BAR_W, BAR_H, BAR_GAP = 220, 11, 4
local TIMERS = {
  { label = "Picar", unit = "player", ids = { 315496, 5171 }, color = { 1, 0.82, 0.2 } },     -- Slice and Dice
  { label = "Rasgar", unit = "target", ids = { 1943 }, color = { 0.8, 0.15, 0.15 }, mine = true }, -- Rupture
}

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("ROGUE") end
local function secret(v) return issecretvalue and issecretvalue(v) end

local frame = CreateFrame("Frame", nil, UIParent)
Rogue.frame = frame

-- Energy tick ---------------------------------------------------------------------------------
local lastEnergy, lastTick, small, energySecret = nil, nil, 0, false

local function energy()
  local v = UnitPower("player", Enum.PowerType.Energy)
  if secret(v) then energySecret = true return end
  energySecret = false
  if lastEnergy and v > lastEnergy then
    local d = v - lastEnergy
    if d >= TICK_JUMP then
      Rogue.ticking, lastTick, small = true, GetTime(), 0
    else
      small = small + 1
      if small >= 3 then Rogue.ticking = false end -- regenerates smoothly: no ticks to show
    end
  end
  lastEnergy = v
end

local function spark()
  local s = Rogue.spark
  if not s then return end
  local bar = s:GetParent()
  local max = UnitPowerMax("player", Enum.PowerType.Energy)
  if not (on("c_rog_tick") and Rogue.ticking and lastTick) or energySecret or secret(max)
    or (lastEnergy or 0) >= (max or 0) then
    s:Hide()
    return
  end
  local p = ((GetTime() - lastTick) % TICK) / TICK
  s:ClearAllPoints()
  s:SetPoint("CENTER", bar, "LEFT", p * bar:GetWidth(), 0)
  s:SetHeight(bar:GetHeight() + 4)
  s:Show()
end

-- Combo points under the target ---------------------------------------------------------------
local combo = CreateFrame("Frame", nil, UIParent)
combo:Hide()
Rogue.combo = combo

local function comboUpdate()
  if not mine() or db().c_rog_ontarget ~= true then combo:Hide() return end
  local cur = UnitPower("player", Enum.PowerType.ComboPoints)
  local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
  local show = mine() and db().c_rog_ontarget == true and UnitExists("target") and UnitCanAttack("player", "target")
    and not secret(cur) and not secret(max) and (max or 0) > 0
  if not show then combo:Hide() return end
  local res = ns.Data.ClassResourceFor("ROGUE")
  local gold = res and { res.color.r, res.color.g, res.color.b } or { 1, 0.76, 0.23 }
  local t = ns.UnitFrames.frames.target
  if not t then combo:Hide() return end -- the unit frames are built after the first layout
  combo:ClearAllPoints()
  combo:SetPoint("BOTTOMLEFT", t.health or t, "TOPLEFT", 2, 26) -- above the name line, clear of debuffs
  combo:SetSize(max * DOT + (max - 1) * DOT_GAP, DOT)
  for i = 1, math.max(max, #Rogue.dots) do
    local d = Rogue.dots[i]
    if not d and i <= max then
      d = combo:CreateTexture(nil, "ARTWORK")
      d:SetSize(DOT, DOT)
      Rogue.dots[i] = d
    end
    if d then
      if i <= max then
        d.lit = i <= cur
        ns.Media.Apply(d, d.lit and "mod_gem_on" or ns.ModernTex("mod_gem_off"))
        if d.lit then d:SetVertexColor(gold[1], gold[2], gold[3]) else d:SetVertexColor(1, 1, 1) end
        d:ClearAllPoints()
        d:SetPoint("LEFT", combo, "LEFT", (i - 1) * (DOT + DOT_GAP), 0)
        d:Show()
      else
        d:Hide()
      end
    end
  end
  combo:Show()
end

-- Slice and Dice / Rupture --------------------------------------------------------------------
local timers = CreateFrame("Frame", "ObsidianUIRogueTimers", UIParent)
timers:SetSize(BAR_W, BAR_H * 2 + BAR_GAP)
Rogue.timers = timers

for i, spec in ipairs(TIMERS) do
  local b = CreateFrame("StatusBar", nil, timers)
  b:SetSize(BAR_W, BAR_H)
  b:SetPoint("TOP", timers, "TOP", 0, -(i - 1) * (BAR_H + BAR_GAP))
  W.Panel(b)
  b:SetStatusBarColor(spec.color[1], spec.color[2], spec.color[3])
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("LEFT", b, "LEFT", 4, 0)
  b.label:SetText(spec.label)
  b.time = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.time:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.spec = spec
  b:Hide()
  Rogue.bars[i] = b
end

local function findAura(spec)
  if not UnitExists(spec.unit) then return nil end
  for _, id in ipairs(spec.ids) do
    local a
    local A = C_UnitAuras
    if spec.unit == "player" and A.GetPlayerAuraBySpellID then a = A.GetPlayerAuraBySpellID(id)
    elseif spec.unit ~= "player" and A.GetUnitAuraBySpellID then a = A.GetUnitAuraBySpellID(spec.unit, id) end
    if a then
      local ok, yours = pcall(function() return a.isFromPlayerOrPlayerPet == true end)
      if not spec.mine or (ok and yours) then return a end
    end
  end
end

local function timerUpdate(unit)
  for _, b in ipairs(Rogue.bars) do
    local spec = b.spec
    if not unit or unit == spec.unit then
      local a = mine() and on("c_rog_snd") and findAura(spec)
      if a then
        b.aura = a
        b.timer = C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(spec.unit, a.auraInstanceID)
        local direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil
        b.driven = b.timer and b.SetTimerDuration and pcall(b.SetTimerDuration, b, b.timer, nil, direction) or false
        b:SetStatusBarTexture(ns.Look.BarTexture())
        b:SetStatusBarColor(spec.color[1], spec.color[2], spec.color[3])
        ns.Look.SetFont(b.label, 10)
        ns.Look.SetFont(b.time, 10)
        b:Show()
      else
        b.aura, b.timer = nil, nil
        b:Hide()
      end
    end
  end
end

-- Without the game's timer: fill and seconds from the aura's own times (when they are plain).
local function timerTick()
  for _, b in ipairs(Rogue.bars) do
    local a = b.aura
    if a and b:IsShown() then
      local ok, left, total = pcall(function() return a.expirationTime - GetTime(), a.duration end)
      if ok and total and total > 0 then
        if not b.driven then b:SetMinMaxValues(0, total); b:SetValue(math.max(0, left)) end
        b.time:SetText(string.format("%.0f", math.max(0, left)))
      else
        b.time:SetText("")
      end
    end
  end
end

-- Setup -----------------------------------------------------------------------------------------
function Rogue.Refresh()
  if not mine() then return end
  local p = ns.UnitFrames.frames.player
  if p and p.power and not Rogue.spark then
    Rogue.spark = p.power:CreateTexture(nil, "OVERLAY")
    Rogue.spark:SetColorTexture(1, 1, 1, 0.9)
    Rogue.spark:SetBlendMode("ADD")
    Rogue.spark:SetWidth(2)
    Rogue.spark:Hide()
  end
  ns.Movers.Register("roguetimers", "Temporizadores (Ladino)", timers, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", ns.CastBar.art or ns.Stack.Anchor(), "TOP", 0, 8)
  end)
  ns.Movers.Place("roguetimers")
  frame:SetScript("OnUpdate", function()
    spark()
    timerTick()
  end)
  comboUpdate()
  timerUpdate()
end

ns.On("PLAYER_LOGIN", function() Rogue.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Rogue.Refresh) end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token)
  if unit ~= "player" or not mine() then return end
  if token == "ENERGY" then energy() elseif token == "COMBO_POINTS" then comboUpdate() end
end)
ns.On("PLAYER_TARGET_CHANGED", function()
  if not mine() then return end
  comboUpdate()
  timerUpdate("target")
end)
ns.On("UNIT_AURA", function(_, unit)
  if mine() and (unit == "player" or unit == "target") then timerUpdate(unit) end
end)

ns.Classes.Register("ROGUE", "Ladino", {
  { kind = "toggle", label = "Tick de energia", key = "c_rog_tick", default = true,
    help = "Uma linha na barra de energia mostra quando chega a próxima (a cada 2 s)." },
  { kind = "toggle", label = "Pontos de combo no alvo", key = "c_rog_ontarget", default = false,
    onChange = function() comboUpdate() end, help = "Gemas pequenas embaixo do quadro do alvo." },
  { kind = "toggle", label = "Duração de Picar e Rasgar", key = "c_rog_snd", default = true,
    onChange = function() timerUpdate() end, help = "Duas barras acima da barra de cast; mova no modo de edição." },
  { kind = "toggle", label = "Venenos acabando", key = "c_rog_poison", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: sem veneno ou com menos de 5 minutos." },
})
