local _, ns = ...

-- Warrior: a swing timer (your melee swings from the combat log, only while the game lets addons
-- read it; Heroic Strike and Cleave land on the swing too), an alert when Overpower or Execute
-- can be used (the game's own spell glow, Execute also when usable on an enemy), Blizzard's
-- stance bar under the player frame (option; HUD/SpecialBars.lua asks Classes.StanceOnPlayer),
-- and the rage as a big number where other classes have their gems.
local Warrior = {}
ns.Warrior = Warrior

local W = ns.Widgets
local NEXT_SWING = { [78] = true, [845] = true } -- Heroic Strike, Cleave
local OVERPOWER = { 7384 }
local EXECUTE = { 5308, 163201, 280735 }

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("WARRIOR") end
local function secret(v) return issecretvalue and issecretvalue(v) end

local frame = CreateFrame("Frame", nil, UIParent)
Warrior.frame = frame

-- Swing timer -----------------------------------------------------------------------------------
local swing = ns.Classes.NewSwing("ObsidianUIWarriorSwing", "warswing", "Ataque automático (Guerreiro)", { 0.85, 0.85, 0.88 })
Warrior.swing = swing.bar

local function restricted()
  return C_CombatLog and C_CombatLog.IsCombatLogRestricted and C_CombatLog.IsCombatLogRestricted()
end

local function stopSwing() swing:Stop() end
local function startSwing() swing:Start(UnitAttackSpeed("player")) end

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

-- Overpower / Execute -------------------------------------------------------------------------
local alert = ns.Classes.NewAlert()
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
  alert:Set(id)
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
  swing:Place()
  frame:SetScript("OnUpdate", function() swing:Tick() end)
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
ns.On("UNIT_ATTACK_SPEED", function(_, unit) if unit == "player" then swing:Rescale(UnitAttackSpeed("player")) end end)
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
