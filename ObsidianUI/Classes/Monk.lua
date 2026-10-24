local _, ns = ...

-- Monk: a stagger bar for brewmasters where the gems would be (green, yellow, red as the damage
-- held back grows; the game's value goes straight into the bar, so it works with secret values,
-- and only the colour waits for a plain one), and chi as gems or as one bar.
local Monk = {}
ns.Monk = Monk

local BREWMASTER = 1
local W, H = 220, 10
local LEVELS = { { 0.3, { 0.35, 0.85, 0.35 } }, { 0.6, { 1, 0.8, 0.2 } }, { math.huge, { 0.9, 0.2, 0.2 } } }
local THROTTLE = 0.1

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local function mine() return ns.Classes.Is("MONK") end
local function secret(v) return issecretvalue and issecretvalue(v) end

ns.ClassResource.ForceBar = function() return mine() and db().c_mon_chi == false end

local frame = CreateFrame("Frame", nil, UIParent)
Monk.frame = frame

local stagger = CreateFrame("StatusBar", nil, UIParent)
stagger:SetSize(W, H)
ns.Widgets.Panel(stagger)
stagger:Hide()
Monk.stagger = stagger
local inCombat = false

local function staggerUpdate()
  local spec = GetSpecialization and GetSpecialization()
  if not (mine() and on("c_mon_stagger") and spec == BREWMASTER and UnitStagger) then stagger:Hide() return end
  local value, max = UnitStagger("player"), UnitHealthMax("player")
  local plain = not secret(value) and not secret(max)
  if plain and value <= 0 and not inCombat then stagger:Hide() return end
  stagger:ClearAllPoints()
  stagger:SetPoint("BOTTOM", ns.Stack.Anchor(), "TOP", 0, 34) -- the gems' spot (brewmasters have none)
  stagger:SetStatusBarTexture(ns.Look.BarTexture())
  stagger:SetMinMaxValues(0, max)
  stagger:SetValue(value)
  if plain and max > 0 then
    for _, l in ipairs(LEVELS) do
      if value / max < l[1] then stagger:SetStatusBarColor(l[2][1], l[2][2], l[2][3]) break end
    end
  end
  stagger:Show()
end

function Monk.Refresh()
  if not mine() then return end
  local since = 0
  frame:SetScript("OnUpdate", function(_, elapsed)
    since = since + (elapsed or 0)
    if since >= THROTTLE then since = 0; staggerUpdate() end
  end)
  ns.ClassResource.Redraw()
  staggerUpdate()
end

ns.On("PLAYER_LOGIN", function() Monk.Refresh() end)
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(Monk.Refresh) end)
ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; if mine() then staggerUpdate() end end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; if mine() then staggerUpdate() end end)
ns.On("PLAYER_SPECIALIZATION_CHANGED", function() if mine() then staggerUpdate() end end)

ns.Classes.Register("MONK", "Monge", {
  { kind = "toggle", label = "Barra de Estagnar", key = "c_mon_stagger", default = true,
    onChange = staggerUpdate, help = "Mestre Cervejeiro: o dano segurado, verde, amarelo ou vermelho." },
  { kind = "toggle", label = "Chi em gemas", key = "c_mon_chi", default = true,
    onChange = function() ns.ClassResource.Redraw() end, help = "Desligado, o Chi aparece como uma barra." },
})
