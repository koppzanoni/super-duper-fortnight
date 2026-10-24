local _, ns = ...

-- Classes: options of each class on one panel page. The character's class opens first; the
-- other classes can be looked at (and set up for alts). Each class file registers its card with
-- Classes.Register; a class without one shows "em breve".
local Classes = { cards = {}, stanceKeys = {} }
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

-- Whether the player's class wants Blizzard's stance/form bar under the player frame
-- (stanceKeys[class] = the setting that says so).
function Classes.StanceOnPlayer()
  local key = Classes.stanceKeys[Classes.Mine() or ""]
  return key ~= nil and ns.db ~= nil and ns.db[key] == true
end

-- A spell alert in the middle of the screen (icon and gold name): alert:Set(spellID, text) or
-- alert:Set(nil) to hide. Shared by the class modules (Overpower, missing seal...).
function Classes.NewAlert()
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
  function alert:Set(id, text)
    if not id then self:Hide() return end
    self.icon:SetTexture(C_Spell.GetSpellTexture(id))
    ns.Look.SetFont(self.text, 22)
    self.text:SetText(text or ((C_Spell.GetSpellName(id) or "") .. "!"))
    self.text:SetTextColor(1, 0.82, 0.2)
    self:SetWidth(40 + 10 + (tonumber(self.text:GetStringWidth()) or 190)) -- centred on its content
    self:Show()
  end
  return alert
end

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
