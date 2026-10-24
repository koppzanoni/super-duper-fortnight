local _, ns = ...

-- Reminders: small chips over the screen when something important is missing: your class buff,
-- food and flask in raids, poison or weapon oil running out, low durability, bags almost full.
-- Checked out of combat only (aura data can be secret in combat, and that is when you can act);
-- hidden in combat. Movable in the edit mode.
local Reminders = { chips = {} }
ns.Reminders = Reminders

local W = ns.Widgets
local CHIP_H, ICON, GAP = 30, 22, 8
local LOW_DURABILITY = 0.3
local FEW_SLOTS = 5
local SOON = 5 * 60 -- seconds: a poison or oil with less than this is running out

-- The class buff to cast (first known spell) and every buff that counts (group versions too).
local CLASS_BUFFS = {
  MAGE = { 1459, 23028 },     -- Arcane Intellect, Arcane Brilliance
  PRIEST = { 21562, 1243 },   -- Power Word: Fortitude (two IDs across versions)
  DRUID = { 1126, 21849 },    -- Mark of the Wild, Gift of the Wild
  WARRIOR = { 6673 },         -- Battle Shout
}
local POISONS = { 315584, 2823, 8679, 381664 } -- lethal: Instant, Deadly, Wound, Amplifying
local WELL_FED = 19705
local FOOD_NAMES = { "well fed", "bem alimentado" }
local FLASK_PREFIXES = { "flask", "frasco", "phial", "fiala" }

local ICONS = {
  food = "Interface\\Icons\\INV_Misc_Food_15",
  flask = "Interface\\Icons\\INV_Potion_62",
  oil = "Interface\\Icons\\INV_Potion_100",
  repair = "Interface\\Icons\\Trade_BlackSmithing",
  bags = "Interface\\Icons\\INV_Misc_Bag_08",
}

local function db() return ns.db or {} end
local function on(key) return db()[key] ~= false end
local list = {}
local inCombat = false

local function knows(id)
  if IsPlayerSpell then return IsPlayerSpell(id) == true end
  return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) or false
end
local function spellName(id) return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end

-- The player's buffs by lower-case name: seconds left (math.huge when it does not run out).
local function playerBuffs()
  local out = {}
  for _, a in ipairs(ns.Data.UnitAuraList("player", "HELPFUL", 80)) do
    local name = a.name
    if type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
      local left = math.huge
      if (a.duration or 0) > 0 and (a.expirationTime or 0) > 0 then left = a.expirationTime - GetTime() end
      out[name:lower()] = math.max(out[name:lower()] or 0, left)
    end
  end
  return out
end

local function has(buffs, name) return name and buffs[name:lower()] ~= nil end
local function anyPrefix(buffs, prefixes)
  for name in pairs(buffs) do
    for _, p in ipairs(prefixes) do if name:sub(1, #p) == p then return true end end
  end
  return false
end

local function add(key, icon, text) list[#list + 1] = { key = key, icon = icon, text = text } end
local function minutes(s) return math.max(1, math.floor(s / 60 + 0.5)) .. " min" end

-- Works out what is missing now (out of combat only; in combat the last list stays).
function Reminders.Update()
  if inCombat or InCombatLockdown() then return end
  list = {}
  local buffs = playerBuffs()
  local _, class = UnitClass("player")

  local ids = CLASS_BUFFS[class or ""]
  if on("rmBuff") and ids then
    local cast
    for _, id in ipairs(ids) do if knows(id) then cast = id break end end
    local found = false
    for _, id in ipairs(ids) do if has(buffs, spellName(id)) then found = true end end
    if cast and not found then
      add("buff", C_Spell.GetSpellTexture(cast), "Falta " .. (spellName(cast) or "o buff da classe"))
    end
  end

  if on("rmFood") and IsInRaid() then
    local fed = has(buffs, spellName(WELL_FED))
    for _, n in ipairs(FOOD_NAMES) do fed = fed or buffs[n] ~= nil end
    if not fed then add("food", ICONS.food, "Sem comida") end
    if not anyPrefix(buffs, FLASK_PREFIXES) then add("flask", ICONS.flask, "Sem frasco") end
  end

  if on("rmPoison") then
    local poisonKnown, left = false, nil
    for _, id in ipairs(POISONS) do
      if knows(id) then poisonKnown = true end
      local n = spellName(id)
      if n and buffs[n:lower()] then left = math.max(left or 0, buffs[n:lower()]) end
    end
    if class == "ROGUE" and db().c_rog_poison == false then poisonKnown = false end -- the rogue page's switch
    if poisonKnown and (not left or left < SOON) then
      add("poison", C_Spell.GetSpellTexture(POISONS[1]), left and ("Veneno acabando (" .. minutes(left) .. ")") or "Sem veneno nas armas")
    elseif not poisonKnown and GetWeaponEnchantInfo then
      local hasMain, ms = GetWeaponEnchantInfo()
      if hasMain and ms and ms / 1000 < SOON then add("poison", ICONS.oil, "Óleo de arma acabando (" .. minutes(ms / 1000) .. ")") end
    end
  end

  if on("rmRepair") then
    local low = ns.InfoBar.Durability()
    if low and low < LOW_DURABILITY then
      add("repair", ICONS.repair, string.format("Durabilidade %d%%", math.floor(low * 100 + 0.5)))
    end
  end

  if on("rmBags") then
    local free = ns.InfoBar.FreeSlots()
    if free <= FEW_SLOTS then add("bags", ICONS.bags, free == 1 and "Bolsas: 1 espaço livre" or ("Bolsas: " .. free .. " espaços livres")) end
  end

  for _, source in ipairs(Reminders.sources) do source(add, buffs) end
  Reminders.Draw()
end

function Reminders.List() return list end

-- Reminders from the class modules: source(add, buffs) runs on each check (out of combat);
-- add(key, icon, text), buffs: the player's buffs by lower-case name.
Reminders.sources = {}
function Reminders.AddSource(source) Reminders.sources[#Reminders.sources + 1] = source end
Reminders.Knows, Reminders.SpellName = knows, spellName

-- Frame ---------------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "ObsidianUIReminders", UIParent)
frame:SetSize(240, CHIP_H)
Reminders.frame = frame

local function chip(i)
  local c = Reminders.chips[i]
  if c then return c end
  c = CreateFrame("Frame", nil, frame)
  c:SetHeight(CHIP_H)
  W.Panel(c)
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(ICON, ICON)
  c.icon:SetPoint("LEFT", c, "LEFT", 4, 0)
  c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.text:SetPoint("LEFT", c.icon, "RIGHT", 8, 0)
  c.text:SetJustifyH("LEFT")
  Reminders.chips[i] = c
  return c
end

function Reminders.Draw()
  local widths, total = {}, 0
  for i, e in ipairs(list) do
    local c = chip(i)
    c.icon:SetTexture(e.icon)
    ns.Look.SetFont(c.text, 13)
    c.text:SetTextColor(W.WHITE[1], W.WHITE[2], W.WHITE[3])
    c.text:SetText(e.text)
    widths[i] = 4 + ICON + 8 + math.max(40, tonumber(c.text:GetStringWidth()) or 0) + 12
    total = total + widths[i] + (i > 1 and GAP or 0)
  end
  local x = (frame:GetWidth() - total) / 2
  for i, c in ipairs(Reminders.chips) do
    if list[i] then
      c:SetWidth(widths[i])
      c:ClearAllPoints()
      c:SetPoint("LEFT", frame, "LEFT", x, 0)
      x = x + widths[i] + GAP
      c:Show()
    else
      c:Hide()
    end
  end
end

-- Default: above the middle of the screen, clear of the character and the top buffs.
local function layout()
  ns.Movers.Register("reminders", "Lembretes", frame, function(f)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 230)
  end)
  ns.Movers.Place("reminders")
  Reminders.Update()
end
table.insert(ns.HUD.onResize, function() ns.RunOutOfCombat(layout) end)

ns.On("PLAYER_REGEN_DISABLED", function()
  inCombat = true
  frame:Hide()
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  inCombat = false
  frame:Show()
  Reminders.Update()
end)
ns.On("UNIT_AURA", function(_, unit) if unit == "player" then Reminders.Update() end end)
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "GROUP_ROSTER_UPDATE",
  "UNIT_INVENTORY_CHANGED", "SPELLS_CHANGED" }) do
  ns.On(ev, function() Reminders.Update() end)
end

-- Poisons and oils run out without an event: look again now and then.
local since = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  since = since + (elapsed or 0)
  if since >= 15 then
    since = 0
    Reminders.Update()
  end
end)
