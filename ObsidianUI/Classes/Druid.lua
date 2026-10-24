local _, ns = ...

-- Druid: mana as a thin bar under the player's bar while in an animal form, Blizzard's form bar
-- under the player frame (HUD/SpecialBars.lua asks Classes.StanceOnPlayer), the energy tick in
-- cat form (Classes/EnergyTick.lua), combo points only in cat form or in every form, and the
-- five second rule in caster form (Classes/FiveSecond.lua).
local Druid = {}
ns.Druid = Druid

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("DRUID") end

ns.Classes.stanceKeys.DRUID = "c_dru_forms"
ns.Classes.tickKeys.DRUID = "c_dru_tick"
ns.Classes.fiveKeys.DRUID = "c_dru_5sr"

-- Combo points in every form: read the resource as in cat form.
ns.ClassResource.PowerTypeFor = function(classToken)
  if classToken == "DRUID" and db().c_dru_combo == false then return Enum.PowerType.Energy end
end

-- Mana in animal forms ------------------------------------------------------------------------------
local mana = CreateFrame("StatusBar", nil, UIParent)
mana:SetHeight(4)
ns.Widgets.Panel(mana)
mana:Hide()
Druid.mana = mana

local function manaUpdate()
  local power = ns.UnitFrames.frames.player and ns.UnitFrames.frames.player.power
  if not (mine() and on("c_dru_mana") and power) or UnitPowerType("player") == Enum.PowerType.Mana then
    mana:Hide()
    return
  end
  mana:ClearAllPoints()
  mana:SetPoint("TOPLEFT", power, "BOTTOMLEFT", 0, -2)
  mana:SetPoint("TOPRIGHT", power, "BOTTOMRIGHT", 0, -2)
  mana:SetStatusBarTexture(ns.Look.BarTexture())
  mana:SetStatusBarColor(ns.Data.PowerColor("MANA"))
  mana:SetMinMaxValues(0, UnitPowerMax("player", Enum.PowerType.Mana)) -- secret values are fine here
  mana:SetValue(UnitPower("player", Enum.PowerType.Mana))
  mana:Show()
end

function Druid.Refresh()
  if not mine() then return end
  ns.RunOutOfCombat(ns.Stack.PlaceStance) -- the form bar is protected
  manaUpdate()
end

ns.On("PLAYER_LOGIN", function() Druid.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Druid.Refresh) end)
ns.On("UPDATE_SHAPESHIFT_FORM", function() if mine() then manaUpdate() end end)
ns.On("UNIT_DISPLAYPOWER", function(_, unit) if unit == "player" and mine() then manaUpdate() end end)
ns.On("UNIT_POWER_FREQUENT", function(_, unit, token)
  if unit == "player" and token == "MANA" and mine() then manaUpdate() end
end)

local function relayout() ns.RunOutOfCombat(ns.HUD.Layout) end
ns.Classes.Register("DRUID", "Druida", {
  { kind = "toggle", label = "Mana enquanto está em forma animal", key = "c_dru_mana", default = true,
    onChange = manaUpdate, help = "Barra fina de mana embaixo da barra de fúria ou energia." },
  { kind = "toggle", label = "Barra de formas", key = "c_dru_forms", default = true,
    onChange = relayout, help = "Leva a barra de formas para baixo do seu quadro." },
  { kind = "toggle", label = "Tick de energia em Felino", key = "c_dru_tick", default = true,
    help = "Uma linha na barra de energia mostra quando chega a próxima (a cada 2 s)." },
  { kind = "toggle", label = "Pontos de combo só em Felino", key = "c_dru_combo", default = true,
    onChange = function() ns.ClassResource.Refresh() end, help = "Desligado, os pontos de combo ficam à mostra em qualquer forma." },
  { kind = "toggle", label = "Regra dos 5 segundos", key = "c_dru_5sr", default = true,
    help = "Marca na barra de mana: depois dela a mana volta a regenerar." },
})
