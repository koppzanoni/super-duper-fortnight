local _, ns = ...

-- Per-element visibility: always, only in combat, out of combat, with a target (or in combat), on
-- mouseover, or hidden. Done with alpha, which the game allows on protected frames in combat, so
-- it never fights the modules' own show and hide (unit watches, casting, empty resources). The
-- edit mode shows everything. Saved in ns.db.visibility[key] (the edit mode's element keys).
local Visibility = {}
ns.Visibility = Visibility

Visibility.MODES = {
  { "always", "Sempre" }, { "combat", "Só em combate" }, { "nocombat", "Fora de combate" },
  { "target", "Com alvo ou em combate" }, { "mouse", "Ao passar o mouse" }, { "hidden", "Escondido" },
}
-- The elements, in the panel's order: { key, label }.
Visibility.ELEMENTS = {
  { "player", "Jogador" }, { "target", "Alvo" }, { "targettarget", "Alvo do alvo" }, { "focus", "Foco" },
  { "pet", "Pet" }, { "bar", "Barra de ações" }, { "vbars", "Barras verticais" }, { "res", "Recurso de classe" },
  { "buffs", "Buffs e debuffs" }, { "map", "Minimapa" }, { "menu", "Menu" }, { "info", "Barra de informações" },
  { "databars", "Barras de dados" },
}
local THROTTLE = 0.1

local function db() return ns.db or {} end
function Visibility.Mode(key) return (db().visibility or {})[key] or "always" end

-- Every frame of an element: the edit mode's frame, plus the buttons' parents that are not its
-- children (the action bar's secure header, the menu's buttons).
function Visibility.Frames(key)
  local item = ns.Movers.items[key]
  local list = { item and item.frame }
  if key == "bar" then list[#list + 1] = ns.ActionBars.header end
  if key == "menu" then
    for _, b in ipairs(ns.MenuPanels.buttons or {}) do list[#list + 1] = b end
  end
  local out = {}
  for _, f in ipairs(list) do if f then out[#out + 1] = f end end
  return out
end

local function over(frames)
  for _, f in ipairs(frames) do
    if f.IsMouseOver and f:IsVisible() and f:IsMouseOver() == true then return true end
  end
  return false
end

local inCombat = false
local function shown(mode, frames)
  if ns.EditMode and ns.EditMode.active then return true end
  if mode == "combat" then return inCombat end
  if mode == "nocombat" then return not inCombat end
  if mode == "target" then return inCombat or UnitExists("target") end
  if mode == "mouse" then return over(frames) end
  if mode == "hidden" then return false end
  return true
end

-- Sets each element's alpha (only when it changes, so other code's alpha on "always" stays).
local last = {}
function Visibility.Apply()
  for _, e in ipairs(Visibility.ELEMENTS) do
    local key = e[1]
    local mode = Visibility.Mode(key)
    local frames = Visibility.Frames(key)
    local a = shown(mode, frames) and 1 or 0
    if last[key] ~= a or mode ~= "always" then
      for _, f in ipairs(frames) do f:SetAlpha(a) end
      last[key] = a
    end
  end
end

function Visibility.Set(key, mode)
  ns.db.visibility = ns.db.visibility or {}
  ns.db.visibility[key] = mode ~= "always" and mode or nil
  if ns.Profiles and ns.db.profiles then ns.Profiles.Save() end
  Visibility.Apply()
end

local frame = CreateFrame("Frame", nil, UIParent)
Visibility.frame = frame
local since = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  since = since + (elapsed or 0)
  if since >= THROTTLE then since = 0; Visibility.Apply() end -- mouseover and the edit mode
end)

ns.On("PLAYER_LOGIN", function() inCombat = InCombatLockdown() and true or false; Visibility.Apply() end)
ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true; Visibility.Apply() end)
ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false; Visibility.Apply() end)
ns.On("PLAYER_TARGET_CHANGED", Visibility.Apply)
table.insert(ns.HUD.onResize, function() Visibility.Apply() end)

-- The panel page (Settings/Panel.lua builds it when it opens).
function Visibility.Cards()
  local rows = {}
  for i, e in ipairs(Visibility.ELEMENTS) do
    local key = e[1]
    rows[#rows + 1] = { kind = "cycle", label = e[2], key = "vis_" .. key,
      options = function() return Visibility.MODES end,
      get = function() return Visibility.Mode(key) end,
      set = function(v) Visibility.Set(key, v) end,
      help = i == 1 and "Escondido ainda aceita clique; o modo de edição mostra tudo." or nil }
  end
  return { { "Quando aparece", rows } }
end
