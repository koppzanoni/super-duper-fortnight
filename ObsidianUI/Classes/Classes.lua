local _, ns = ...

-- Classes: options of each class on one panel page. The character's class opens first; the
-- other classes can be looked at (and set up for alts). Each class file registers its card with
-- Classes.Register; a class without one shows "em breve".
local Classes = { cards = {} }
ns.Classes = Classes

Classes.LIST = {
  { "WARRIOR", "Guerreiro" }, { "PALADIN", "Paladino" }, { "HUNTER", "Caçador" }, { "ROGUE", "Ladino" },
  { "PRIEST", "Sacerdote" }, { "DEATHKNIGHT", "Cavaleiro da Morte" }, { "SHAMAN", "Xamã" }, { "MAGE", "Mago" },
  { "WARLOCK", "Bruxo" }, { "MONK", "Monge" }, { "DRUID", "Druida" },
}

function Classes.Mine()
  local _, token = UnitClass("player")
  return token
end
function Classes.Is(token) return Classes.Mine() == token end

-- title: the card heading; rows: panel rows ({ kind = "toggle", label, key, default, ... }).
function Classes.Register(token, title, rows) Classes.cards[token] = { title, rows } end

local function name(token)
  for _, c in ipairs(Classes.LIST) do if c[1] == token then return c[2] end end
  return token
end

-- The class chooser: yours first, marked.
local function options()
  local mine, out = Classes.Mine(), {}
  for _, c in ipairs(Classes.LIST) do
    if c[1] == mine then table.insert(out, 1, { c[1], c[2] .. " (sua classe)" }) else out[#out + 1] = { c[1], c[2] } end
  end
  return out
end

-- The page (Settings/Panel.lua builds it each time it opens).
function Classes.Cards()
  local sel = Classes.selected or Classes.Mine()
  Classes.selected = sel
  local chooser = { kind = "cycle", label = "Classe", options = options,
    get = function() return Classes.selected end,
    set = function(v) Classes.selected = v; ns.Panel.Show("classes") end,
    help = "Veja e ajuste as opções de outras classes também (para os seus outros personagens)." }
  local cards = { { "Classe", { chooser } } }
  local card = Classes.cards[sel]
  if card then
    cards[#cards + 1] = card
  else
    cards[#cards + 1] = { "Em breve: " .. name(sel), {} }
  end
  return cards
end
