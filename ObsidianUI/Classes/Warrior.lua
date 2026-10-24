local _, ns = ...

-- Warrior: a swing timer (your melee swings from the combat log, only while the game lets addons
-- read it; Heroic Strike and Cleave land on the swing too), an alert when Overpower or Execute
-- can be used (the game's own spell glow, Execute also when usable on an enemy), Blizzard's
-- stance bar under the player frame (option; HUD/SpecialBars.lua asks Classes.StanceOnPlayer),
-- and the rage as a big number where other classes have their gems.
local Warrior = {}
ns.Warrior = Warrior

local W = ns.Widgets
local BAR_W, BAR_H = 220, 9
local NEXT_SWING = { [78] = true, [845] = true } -- Heroic Strike, Cleave
local OVERPOWER = { 7384 }
local EXECUTE = { 5308, 163201, 280735 }
local LINGER = 3 -- seconds a finished swing bar stays when no new swing comes

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("WARRIOR") end
local function secret(v) return issecretvalue and issecretvalue(v) end

local frame = CreateFrame("Frame", nil, UIParent)
Warrior.frame = frame

-- Swing timer -----------------------------------------------------------------------------------
local swing = CreateFrame("StatusBar", "ObsidianUIWarriorSwing", UIParent)
swing:SetSize(BAR_W, BAR_H)
W.Panel(swing)
swing.time = swing:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
swing.time:SetPoint("RIGHT", swing, "RIGHT", -4, 0)
swing:Hide()
Warrior.swing = swing
local swingStart, swingDur

local function restricted()
  return C_CombatLog and C_CombatLog.IsCombatLogRestricted and C_CombatLog.IsCombatLogRestricted()
end

local function stopSwing()
  swingStart = nil
  swing:Hide()
end

local function startSwing()
  local speed = UnitAttackSpeed("player")
  if secret(speed) or not speed or speed <= 0 then stopSwing() return end
  swingStart, swingDur = GetTime(), speed
  swing:SetStatusBarTexture(ns.Look.BarTexture())
  swing:SetStatusBarColor(0.85, 0.85, 0.88)
  swing:SetMinMaxValues(0, speed)
  swing:SetValue(0)
  ns.Look.SetFont(swing.time, 10)
  swing:Show()
end

local function combatLog()
  if not (mine() and on("c_war_swing")) then return end
  if restricted() or not CombatLogGetCurrentEventInfo then stopSwing() return end
  local info = { CombatLogGetCurrentEventInfo() }
  local sub, source = info[2], info[4]
  if secret(source) or source ~= UnitGUID("player") then return end
  if sub == "SWING_DAMAGE" then
    if not info[21] then startSwing() end -- info[21]: off-hand swing
  elseif sub == "SWING_MISSED" then
    if not info[13] then startSwing() end
  elseif (sub == "SPELL_DAMAGE" or sub == "SPELL_MISSED") and NEXT_SWING[info[12]] then
    startSwing()
  end
end

local function swingTick()
  if not swingStart then return end
  local t = GetTime() - swingStart
  if t > swingDur + LINGER then stopSwing() return end
  swing:SetValue(math.min(t, swingDur))
  swing.time:SetText(string.format("%.1f", math.max(0, swingDur - t)))
end

-- Haste changes mid-swing: keep the same fraction done.
local function speedChanged()
  if not swingStart then return end
  local speed = UnitAttackSpeed("player")
  if secret(speed) or not speed or speed <= 0 then return end
  local done = (GetTime() - swingStart) / swingDur
  swingDur = speed
  swingStart = GetTime() - done * speed
  swing:SetMinMaxValues(0, speed)
end

-- Overpower / Execute -------------------------------------------------------------------------
local alert = CreateFrame("Frame", nil, UIParent)
alert:SetSize(240, 44)
alert:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
alert.icon = alert:CreateTexture(nil, "ARTWORK")
alert.icon:SetSize(40, 40)
alert.icon:SetPoint("LEFT", alert, "LEFT", 0, 0)
alert.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
alert.text = alert:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
alert.text:SetPoint("LEFT", alert.icon, "RIGHT", 10, 0)
alert:Hide()
Warrior.alert = alert
local glowing = {}

local function contains(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end

local function executeUsable()
  if not (C_Spell and C_Spell.IsSpellUsable) then return nil end
  for _, id in ipairs(EXECUTE) do
    if IsPlayerSpell and IsPlayerSpell(id) then
      local usable = C_Spell.IsSpellUsable(id)
      if not secret(usable) and usable then return id end
    end
  end
end

local function alertUpdate()
  local id
  if mine() and on("c_war_proc") and UnitExists("target") and UnitCanAttack("player", "target") then
    for _, x in ipairs(EXECUTE) do if glowing[x] then id = x end end
    id = id or executeUsable()
    if not id then for _, x in ipairs(OVERPOWER) do if glowing[x] then id = x end end end
  end
  if not id then alert:Hide() return end
  alert.icon:SetTexture(C_Spell.GetSpellTexture(id))
  ns.Look.SetFont(alert.text, 22)
  alert.text:SetText((C_Spell.GetSpellName(id) or "") .. "!")
  alert.text:SetTextColor(1, 0.82, 0.2)
  alert:Show()
end

local function glow(show, id)
  if secret(id) or not (contains(OVERPOWER, id) or contains(EXECUTE, id)) then return end
  glowing[id] = show or nil
  alertUpdate()
end

-- Rage ------------------------------------------------------------------------------------------
local rage = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
rage:Hide()
Warrior.rage = rage

local function rageUpdate()
  if not (mine() and on("c_war_text")) then rage:Hide() return end
  rage:ClearAllPoints()
  rage:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 34) -- the gems' spot (no gem row for warriors)
  ns.Look.SetFont(rage, 22)
  rage:SetTextColor(ns.Data.PowerColor("RAGE"))
  rage:SetText(UnitPower("player", Enum.PowerType.Rage)) -- the game prints secret numbers too
  rage:Show()
end

-- Setup -----------------------------------------------------------------------------------------
function Warrior.Refresh()
  if not mine() then return end
  ns.Movers.Register("warswing", "Ataque automático (Guerreiro)", swing, function(f)
    f:ClearAllPoints()
    f:SetPoint("BOTTOM", ns.CastBar.art or ns.Stack.Anchor(), "TOP", 0, 8)
  end)
  ns.Movers.Place("warswing")
  frame:SetScript("OnUpdate", swingTick)
  ns.RunOutOfCombat(ns.Stack.PlaceStance) -- the stance bar is protected
  if not on("c_war_swing") then stopSwing() end
  alertUpdate()
  rageUpdate()
end

ns.Classes.stanceKeys.WARRIOR = "c_war_stance"

ns.On("PLAYER_LOGIN", function() Warrior.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Warrior.Refresh) end)
ns.On("COMBAT_LOG_EVENT_UNFILTERED", combatLog)
ns.On("PLAYER_REGEN_ENABLED", stopSwing)
ns.On("UNIT_ATTACK_SPEED", function(_, unit) if unit == "player" then speedChanged() end end)
ns.On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, id) glow(true, id) end)
ns.On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, id) glow(false, id) end)
ns.On("SPELL_UPDATE_USABLE", alertUpdate)
ns.On("PLAYER_TARGET_CHANGED", alertUpdate)
ns.On("UNIT_HEALTH", function(_, unit) if unit == "target" then alertUpdate() end end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token) if unit == "player" and token == "RAGE" then rageUpdate() end end)

local function relayout() ns.RunOutOfCombat(ns.HUD.Layout) end
ns.Classes.Register("WARRIOR", "Guerreiro", {
  { kind = "toggle", label = "Timer do ataque automático (swing)", key = "c_war_swing", default = true,
    onChange = function() Warrior.Refresh() end,
    help = "Barra entre os seus golpes, acima da barra de cast. Some quando o jogo não deixa addons lerem o combate." },
  { kind = "toggle", label = "Aviso de Sobrepujar / Executar disponível", key = "c_war_proc", default = true,
    onChange = function() alertUpdate() end, help = "Ícone e nome no meio da tela enquanto der para usar." },
  { kind = "toggle", label = "Barra de posturas no quadro do jogador", key = "c_war_stance", default = false,
    onChange = relayout, help = "Leva a barra de posturas para baixo do seu quadro." },
  { kind = "toggle", label = "Fúria em texto", key = "c_war_text", default = true,
    onChange = function() rageUpdate() end, help = "O número da fúria no lugar das gemas das outras classes." },
})
