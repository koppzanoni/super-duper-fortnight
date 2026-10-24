local _, ns = ...

-- Paladin: a reminder when no paladin aura is on, a "no seal" alert in combat (only once the game
-- has shown this session that it tells addons about seals in combat, so a hidden answer is never
-- taken for a missing seal), a Judgement timer bar on the target, and a reminder counting group
-- members without a blessing. Only spells the character knows count.
local Paladin = {}
ns.Paladin = Paladin

local AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218, 32223, 183435, 317920 }
local SEALS = { 21084, 20154, 20375, 20164, 20165, 20166, 21082, 31801, 31892 }
local BLESSINGS = { 19740, 19742, 20217, 1038, 19977, 20911, 25782, 25894, 25898, 25895, 25890, 25899 }
local JUDGEMENT = { 197277, 20185, 20186, 20184, 21183 }
local REFRESH = 1 -- seconds: group aura changes are gathered before the reminders look again

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("PALADIN") end

local function firstKnown(list)
  for _, id in ipairs(list) do if ns.Reminders.Knows(id) then return id end end
end

-- Lower-case names of the spells in `list` (for comparing with aura names).
local function names(list)
  local out = {}
  for _, id in ipairs(list) do
    local n = ns.Reminders.SpellName(id)
    if n then out[n:lower()] = true end
  end
  return out
end

-- Reminders: aura and blessings (out of combat) -------------------------------------------------
local function hasAny(buffs, wanted)
  for n in pairs(buffs) do if wanted[n] then return true end end
  return false
end

-- The group members (you included) the blessing check looks at: alive, online, in sight.
local function members()
  local list = { "player" }
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid" .. i
      if UnitExists(u) and not UnitIsUnit(u, "player") then list[#list + 1] = u end
    end
  elseif IsInGroup() then
    for i = 1, 4 do if UnitExists("party" .. i) then list[#list + 1] = "party" .. i end end
  end
  local out = {}
  for _, u in ipairs(list) do
    if UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsVisible(u) then out[#out + 1] = u end
  end
  return out
end

local function unitHas(unit, wanted)
  for _, a in ipairs(ns.Data.UnitAuraList(unit, "HELPFUL", 40)) do
    local n = a.name
    if type(n) == "string" and not (issecretvalue and issecretvalue(n)) and wanted[n:lower()] then return true end
  end
  return false
end

ns.Reminders.AddSource(function(add, buffs)
  if not mine() then return end
  if on("c_pal_aura") then
    local aura = firstKnown(AURAS)
    if aura and not hasAny(buffs, names(AURAS)) then add("palaura", C_Spell.GetSpellTexture(aura), "Sem aura de paladino") end
  end
  if on("c_pal_bless") then
    local blessing = firstKnown(BLESSINGS)
    if blessing then
      local wanted, missing = names(BLESSINGS), 0
      for _, u in ipairs(members()) do if not unitHas(u, wanted) then missing = missing + 1 end end
      if missing > 0 then
        add("bless", C_Spell.GetSpellTexture(blessing),
          IsInGroup() and ("Bênção faltando em " .. missing) or "Sem bênção")
      end
    end
  end
end)

-- Seal (in combat) --------------------------------------------------------------------------------
local alert = ns.Classes.NewAlert()
Paladin.alert = alert
local inCombat, sealsAnswered = false, false

local function sealUpdate()
  local seal = mine() and on("c_pal_aura") and inCombat and UnitExists("target") and UnitCanAttack("player", "target")
    and firstKnown(SEALS)
  if not seal then alert:Set(nil) return end
  local found = false
  if C_UnitAuras.GetPlayerAuraBySpellID then
    for _, id in ipairs(SEALS) do if C_UnitAuras.GetPlayerAuraBySpellID(id) then found = true end end
  end
  if found then sealsAnswered = true end
  if not found and sealsAnswered then alert:Set(seal, "Sem selo!") else alert:Set(nil) end
end

-- Judgement -----------------------------------------------------------------------------------
local timers = ns.Classes.NewTimers("ObsidianUIPaladinTimers", "paltimers", "Temporizadores (Paladino)", {
  { label = "Julgamento", unit = "target", ids = JUDGEMENT, color = { 1, 0.86, 0.45 }, mine = true },
})
Paladin.bars = timers.bars
local function timerUpdate(unit) timers:Update(unit, mine() and on("c_pal_judge")) end

-- Setup -----------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", nil, UIParent)
function Paladin.Refresh()
  if not mine() then return end
  timers:Place()
  frame:SetScript("OnUpdate", function() timers:Tick() end)
  timerUpdate()
  sealUpdate()
end

local pending = false
local function groupAuras()
  if pending then return end
  pending = true
  C_Timer.After(REFRESH, function() pending = false; ns.Reminders.Update() end)
end

ns.On("PLAYER_LOGIN", function() Paladin.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Paladin.Refresh) end)
ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; sealUpdate() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; sealUpdate() end)
ns.On("PLAYER_TARGET_CHANGED", function() if mine() then sealUpdate(); timerUpdate("target") end end)
ns.On("UNIT_AURA", function(_, unit)
  if not mine() then return end
  if unit == "player" then sealUpdate() end
  if unit == "player" or unit == "target" then timerUpdate(unit) end
  if unit and (unit:find("^party") or unit:find("^raid")) and on("c_pal_bless") then groupAuras() end
end)

ns.Classes.Register("PALADIN", "Paladino", {
  { kind = "toggle", label = "Lembrete de aura e selo", key = "c_pal_aura", default = true,
    onChange = function() ns.Reminders.Update(); sealUpdate() end,
    help = "Aura faltando nos Lembretes; \"Sem selo!\" no meio da tela em combate." },
  { kind = "toggle", label = "Duração do julgamento no alvo", key = "c_pal_judge", default = true,
    onChange = function() timerUpdate() end, help = "Barra acima da barra de cast; mova no modo de edição." },
  { kind = "toggle", label = "Bênçãos do grupo faltando", key = "c_pal_bless", default = true,
    onChange = function() ns.Reminders.Update() end, help = "Nos Lembretes: quantos do grupo estão sem bênção." },
})
