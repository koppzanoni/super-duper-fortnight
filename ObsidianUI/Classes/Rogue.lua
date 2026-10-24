local _, ns = ...

-- Rogue: the energy tick (Classes/EnergyTick.lua), combo points above the target (option), Slice
-- and Dice and Rupture timer bars driven by the game's duration objects (they keep running in
-- combat), and the "poisons running out" switch the reminders read. Secret values hide a piece
-- instead of erroring.
local Rogue = { dots = {} }
ns.Rogue = Rogue

ns.Classes.tickKeys.ROGUE = "c_rog_tick"

local DOT, DOT_GAP = 16, 4
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
local timers = ns.Classes.NewTimers("ObsidianUIRogueTimers", "roguetimers", "Temporizadores (Ladino)", TIMERS)
Rogue.timers, Rogue.bars = timers.frame, timers.bars
local function timerUpdate(unit) timers:Update(unit, mine() and on("c_rog_snd")) end

-- Setup -----------------------------------------------------------------------------------------
function Rogue.Refresh()
  if not mine() then return end
  timers:Place()
  frame:SetScript("OnUpdate", function() timers:Tick() end)
  comboUpdate()
  timerUpdate()
end

ns.On("PLAYER_LOGIN", function() Rogue.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Rogue.Refresh) end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token)
  if unit ~= "player" or not mine() then return end
  if token == "COMBO_POINTS" then comboUpdate() end
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
    onChange = function() comboUpdate() end, help = "Gemas pequenas acima da barra de vida do alvo." },
  { kind = "toggle", label = "Duração de Picar e Rasgar", key = "c_rog_snd", default = true,
    onChange = function() timerUpdate() end, help = "Duas barras acima da barra de cast; mova no modo de edição." },
  { kind = "toggle", label = "Venenos acabando", key = "c_rog_poison", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: sem veneno ou com menos de 5 minutos." },
})
